$ErrorActionPreference = 'Stop'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$outDir = Join-Path $env:TEMP "WeatherArrow-Live-$stamp"
New-Item -ItemType Directory -Path $outDir -Force | Out-Null

$source = @'
using System;
using System.Collections.Generic;
using System.IO;
using System.IO.Compression;
using System.Runtime.InteropServices;

public static class GdiSnapshot20260928
{
    private const uint SRCCOPY = 0x00CC0020;
    private const uint CAPTUREBLT = 0x40000000;
    private const uint BI_RGB = 0;
    private const uint DIB_RGB_COLORS = 0;

    [StructLayout(LayoutKind.Sequential)]
    private struct RECT { public int Left, Top, Right, Bottom; }
    [StructLayout(LayoutKind.Sequential)]
    private struct MONITORINFO
    {
        public int cbSize;
        public RECT rcMonitor;
        public RECT rcWork;
        public uint dwFlags;
    }
    [StructLayout(LayoutKind.Sequential)]
    private struct BITMAPINFOHEADER
    {
        public uint biSize;
        public int biWidth;
        public int biHeight;
        public ushort biPlanes;
        public ushort biBitCount;
        public uint biCompression;
        public uint biSizeImage;
        public int biXPelsPerMeter;
        public int biYPelsPerMeter;
        public uint biClrUsed;
        public uint biClrImportant;
    }
    [StructLayout(LayoutKind.Sequential)]
    private struct BITMAPINFO { public BITMAPINFOHEADER bmiHeader; public uint bmiColors; }
    private delegate bool MonitorEnumProc(IntPtr monitor, IntPtr dc, IntPtr rect, IntPtr data);

    [DllImport("user32.dll", SetLastError = true)] private static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context);
    [DllImport("user32.dll", SetLastError = true)] private static extern bool EnumDisplayMonitors(IntPtr dc, IntPtr clip, MonitorEnumProc callback, IntPtr data);
    [DllImport("user32.dll", SetLastError = true)] private static extern bool GetMonitorInfo(IntPtr monitor, ref MONITORINFO info);
    [DllImport("user32.dll")] private static extern IntPtr GetDC(IntPtr hwnd);
    [DllImport("user32.dll")] private static extern int ReleaseDC(IntPtr hwnd, IntPtr dc);
    [DllImport("gdi32.dll", SetLastError = true)] private static extern IntPtr CreateCompatibleDC(IntPtr dc);
    [DllImport("gdi32.dll", SetLastError = true)] private static extern bool DeleteDC(IntPtr dc);
    [DllImport("gdi32.dll", SetLastError = true)] private static extern IntPtr CreateDIBSection(IntPtr dc, ref BITMAPINFO info, uint usage, out IntPtr bits, IntPtr section, uint offset);
    [DllImport("gdi32.dll", SetLastError = true)] private static extern IntPtr SelectObject(IntPtr dc, IntPtr obj);
    [DllImport("gdi32.dll", SetLastError = true)] private static extern bool DeleteObject(IntPtr obj);
    [DllImport("gdi32.dll", SetLastError = true)] private static extern bool BitBlt(IntPtr dst, int x, int y, int width, int height, IntPtr src, int srcX, int srcY, uint rop);

    private sealed class MonitorItem
    {
        public string Name;
        public int X, Y, Width, Height;
    }

    public static string[] CaptureAll(string outDir)
    {
        SetThreadDpiAwarenessContext(new IntPtr(-4)); // PER_MONITOR_AWARE_V2
        List<MonitorItem> monitors = new List<MonitorItem>();
        MonitorEnumProc callback = delegate(IntPtr h, IntPtr dc, IntPtr r, IntPtr d)
        {
            MONITORINFO info = new MONITORINFO();
            info.cbSize = Marshal.SizeOf(typeof(MONITORINFO));
            if (!GetMonitorInfo(h, ref info)) throw new InvalidOperationException("GetMonitorInfo failed: " + Marshal.GetLastWin32Error());
            monitors.Add(new MonitorItem {
                Name = "Display" + (monitors.Count + 1),
                X = info.rcMonitor.Left,
                Y = info.rcMonitor.Top,
                Width = info.rcMonitor.Right - info.rcMonitor.Left,
                Height = info.rcMonitor.Bottom - info.rcMonitor.Top
            });
            return true;
        };
        if (!EnumDisplayMonitors(IntPtr.Zero, IntPtr.Zero, callback, IntPtr.Zero))
            throw new InvalidOperationException("EnumDisplayMonitors failed: " + Marshal.GetLastWin32Error());
        if (monitors.Count == 0) throw new InvalidOperationException("No active monitors were returned.");
        monitors.Sort(delegate(MonitorItem a, MonitorItem b) { int c = a.X.CompareTo(b.X); return c != 0 ? c : a.Y.CompareTo(b.Y); });

        List<string> result = new List<string>();
        IntPtr screen = GetDC(IntPtr.Zero);
        try
        {
            int n = 0;
            foreach (MonitorItem m in monitors)
            {
                n++;
                string path = Path.Combine(outDir, "monitor-" + n + ".png");
                CaptureOne(screen, m, path);
                result.Add(string.Join("|", n, m.Name, m.X, m.Y, m.Width, m.Height, path));
            }
        }
        finally { ReleaseDC(IntPtr.Zero, screen); }
        return result.ToArray();
    }

    private static void CaptureOne(IntPtr screen, MonitorItem m, string path)
    {
        IntPtr memory = CreateCompatibleDC(screen);
        BITMAPINFO info = new BITMAPINFO();
        info.bmiHeader.biSize = (uint)Marshal.SizeOf(typeof(BITMAPINFOHEADER));
        info.bmiHeader.biWidth = m.Width;
        info.bmiHeader.biHeight = -m.Height;
        info.bmiHeader.biPlanes = 1;
        info.bmiHeader.biBitCount = 32;
        info.bmiHeader.biCompression = BI_RGB;
        IntPtr bits;
        IntPtr bitmap = CreateDIBSection(screen, ref info, DIB_RGB_COLORS, out bits, IntPtr.Zero, 0);
        if (memory == IntPtr.Zero || bitmap == IntPtr.Zero || bits == IntPtr.Zero)
            throw new InvalidOperationException("CreateDIBSection failed: " + Marshal.GetLastWin32Error());
        IntPtr old = SelectObject(memory, bitmap);
        try
        {
            if (!BitBlt(memory, 0, 0, m.Width, m.Height, screen, m.X, m.Y, SRCCOPY | CAPTUREBLT))
                throw new InvalidOperationException("BitBlt failed: " + Marshal.GetLastWin32Error());
            int byteCount = checked(m.Width * m.Height * 4);
            byte[] bgra = new byte[byteCount];
            Marshal.Copy(bits, bgra, 0, byteCount);
            WritePng(path, m.Width, m.Height, bgra);
        }
        finally
        {
            SelectObject(memory, old);
            DeleteObject(bitmap);
            DeleteDC(memory);
        }
    }

    private static void WritePng(string path, int width, int height, byte[] bgra)
    {
        byte[] scanlines = new byte[checked(height * (1 + width * 4))];
        int dest = 0;
        for (int y = 0; y < height; y++)
        {
            scanlines[dest++] = 0;
            int src = y * width * 4;
            for (int x = 0; x < width; x++)
            {
                scanlines[dest++] = bgra[src + 2];
                scanlines[dest++] = bgra[src + 1];
                scanlines[dest++] = bgra[src];
                scanlines[dest++] = 255;
                src += 4;
            }
        }
        byte[] compressed;
        using (MemoryStream ms = new MemoryStream())
        {
            using (ZLibStream zs = new ZLibStream(ms, CompressionLevel.Fastest, true)) zs.Write(scanlines, 0, scanlines.Length);
            compressed = ms.ToArray();
        }
        using (FileStream fs = new FileStream(path, FileMode.Create, FileAccess.Write, FileShare.None))
        {
            byte[] signature = new byte[] { 137, 80, 78, 71, 13, 10, 26, 10 };
            fs.Write(signature, 0, signature.Length);
            byte[] ihdr = new byte[13];
            Put32(ihdr, 0, (uint)width); Put32(ihdr, 4, (uint)height);
            ihdr[8] = 8; ihdr[9] = 6;
            WriteChunk(fs, "IHDR", ihdr);
            WriteChunk(fs, "IDAT", compressed);
            WriteChunk(fs, "IEND", new byte[0]);
        }
    }

    private static void WriteChunk(Stream stream, string type, byte[] data)
    {
        byte[] t = System.Text.Encoding.ASCII.GetBytes(type);
        byte[] len = new byte[4]; Put32(len, 0, (uint)data.Length); stream.Write(len, 0, 4);
        stream.Write(t, 0, 4); if (data.Length > 0) stream.Write(data, 0, data.Length);
        uint crc = 0xffffffff;
        for (int i = 0; i < 4; i++) crc = CrcByte(crc, t[i]);
        for (int i = 0; i < data.Length; i++) crc = CrcByte(crc, data[i]);
        byte[] tail = new byte[4]; Put32(tail, 0, crc ^ 0xffffffff); stream.Write(tail, 0, 4);
    }
    private static uint CrcByte(uint crc, byte b)
    {
        crc ^= b;
        for (int i = 0; i < 8; i++) crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xedb88320 : crc >> 1;
        return crc;
    }
    private static void Put32(byte[] b, int o, uint v)
    { b[o]=(byte)(v>>24); b[o+1]=(byte)(v>>16); b[o+2]=(byte)(v>>8); b[o+3]=(byte)v; }
}
'@

Add-Type -TypeDefinition $source
"OUT=$outDir"
[GdiSnapshot20260928]::CaptureAll($outDir)
