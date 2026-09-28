param(
    [Parameter(Mandatory)][string]$OutputRaw,
    [Parameter(Mandatory)][string]$OutputMetadata
)

$ErrorActionPreference = 'Stop'
$captureSource = @'
using System;
using System.Collections.Generic;
using System.IO;
using System.Runtime.InteropServices;

public static class VisionGdiCapture
{
    [StructLayout(LayoutKind.Sequential)] private struct RECT { public int Left, Top, Right, Bottom; }
    [StructLayout(LayoutKind.Sequential)] private struct MONITORINFO { public int cbSize; public RECT rcMonitor; public RECT rcWork; public uint dwFlags; }
    [StructLayout(LayoutKind.Sequential)] private struct BITMAPINFOHEADER
    {
        public uint biSize; public int biWidth; public int biHeight; public ushort biPlanes; public ushort biBitCount;
        public uint biCompression; public uint biSizeImage; public int biXPelsPerMeter; public int biYPelsPerMeter;
        public uint biClrUsed; public uint biClrImportant;
    }
    private delegate bool MonitorEnumProc(IntPtr monitor, IntPtr dc, ref RECT rect, IntPtr data);
    private const int SM_XVIRTUALSCREEN = 76, SM_YVIRTUALSCREEN = 77, SM_CXVIRTUALSCREEN = 78, SM_CYVIRTUALSCREEN = 79;
    private const uint BI_RGB = 0, SRCCOPY = 0x00CC0020, CAPTUREBLT = 0x40000000;
    [DllImport("user32.dll")] private static extern int GetSystemMetrics(int index);
    [DllImport("user32.dll")] private static extern IntPtr GetDC(IntPtr hwnd);
    [DllImport("user32.dll")] private static extern int ReleaseDC(IntPtr hwnd, IntPtr dc);
    [DllImport("user32.dll", SetLastError=true)] private static extern bool EnumDisplayMonitors(IntPtr dc, IntPtr clip, MonitorEnumProc callback, IntPtr data);
    [DllImport("user32.dll", CharSet=CharSet.Auto, SetLastError=true)] private static extern bool GetMonitorInfo(IntPtr monitor, ref MONITORINFO info);
    [DllImport("gdi32.dll", SetLastError=true)] private static extern IntPtr CreateCompatibleDC(IntPtr dc);
    [DllImport("gdi32.dll", SetLastError=true)] private static extern IntPtr CreateDIBSection(IntPtr dc, ref BITMAPINFOHEADER info, uint usage, out IntPtr bits, IntPtr section, uint offset);
    [DllImport("gdi32.dll", SetLastError=true)] private static extern IntPtr SelectObject(IntPtr dc, IntPtr obj);
    [DllImport("gdi32.dll", SetLastError=true)] private static extern bool BitBlt(IntPtr dst, int x, int y, int width, int height, IntPtr src, int srcX, int srcY, uint operation);
    [DllImport("gdi32.dll")] private static extern bool DeleteObject(IntPtr obj);
    [DllImport("gdi32.dll")] private static extern bool DeleteDC(IntPtr dc);
    public static string[] EnumerateMonitors()
    {
        var result = new List<string>();
        MonitorEnumProc cb = delegate(IntPtr h, IntPtr dc, ref RECT r, IntPtr d) {
            var i = new MONITORINFO(); i.cbSize = Marshal.SizeOf(typeof(MONITORINFO));
            if (GetMonitorInfo(h, ref i)) result.Add(String.Format("monitor {0}: x={1}, y={2}, width={3}, height={4}; primary={5}", result.Count+1, i.rcMonitor.Left, i.rcMonitor.Top, i.rcMonitor.Right-i.rcMonitor.Left, i.rcMonitor.Bottom-i.rcMonitor.Top, (i.dwFlags & 1) != 0));
            return true;
        };
        if (!EnumDisplayMonitors(IntPtr.Zero, IntPtr.Zero, cb, IntPtr.Zero)) throw new InvalidOperationException("EnumDisplayMonitors failed: " + Marshal.GetLastWin32Error());
        return result.ToArray();
    }
    public static void Capture(string path, out int left, out int top, out int width, out int height)
    {
        left=GetSystemMetrics(SM_XVIRTUALSCREEN); top=GetSystemMetrics(SM_YVIRTUALSCREEN);
        width=GetSystemMetrics(SM_CXVIRTUALSCREEN); height=GetSystemMetrics(SM_CYVIRTUALSCREEN);
        if(width<=0 || height<=0) throw new InvalidOperationException("Virtual desktop bounds are empty.");
        long size=(long)width*height*4L; if(size>Int32.MaxValue) throw new InvalidOperationException("Virtual desktop capture exceeds supported buffer size.");
        IntPtr src=GetDC(IntPtr.Zero); if(src==IntPtr.Zero) throw new InvalidOperationException("GetDC failed.");
        IntPtr mem=IntPtr.Zero, dib=IntPtr.Zero, old=IntPtr.Zero, bits=IntPtr.Zero;
        try {
            mem=CreateCompatibleDC(src); if(mem==IntPtr.Zero) throw new InvalidOperationException("CreateCompatibleDC failed: "+Marshal.GetLastWin32Error());
            var bi=new BITMAPINFOHEADER { biSize=(uint)Marshal.SizeOf(typeof(BITMAPINFOHEADER)), biWidth=width, biHeight=-height, biPlanes=1, biBitCount=32, biCompression=BI_RGB, biSizeImage=(uint)size };
            dib=CreateDIBSection(src, ref bi, 0, out bits, IntPtr.Zero, 0); if(dib==IntPtr.Zero || bits==IntPtr.Zero) throw new InvalidOperationException("CreateDIBSection failed: "+Marshal.GetLastWin32Error());
            old=SelectObject(mem,dib); if(old==IntPtr.Zero || old==new IntPtr(-1)) throw new InvalidOperationException("SelectObject failed: "+Marshal.GetLastWin32Error());
            if(!BitBlt(mem,0,0,width,height,src,left,top,SRCCOPY|CAPTUREBLT)) throw new InvalidOperationException("GDI BitBlt failed: "+Marshal.GetLastWin32Error());
            var raw=new byte[(int)size]; Marshal.Copy(bits,raw,0,raw.Length); File.WriteAllBytes(path,raw);
        }
        finally { if(old!=IntPtr.Zero && old!=new IntPtr(-1)) SelectObject(mem,old); if(dib!=IntPtr.Zero) DeleteObject(dib); if(mem!=IntPtr.Zero) DeleteDC(mem); ReleaseDC(IntPtr.Zero,src); }
    }
}
'@
Add-Type -TypeDefinition $captureSource -Language CSharp
$monitors = [VisionGdiCapture]::EnumerateMonitors()
$left=0; $top=0; $width=0; $height=0
[VisionGdiCapture]::Capture($OutputRaw,[ref]$left,[ref]$top,[ref]$width,[ref]$height)
@{ x=$left; y=$top; width=$width; height=$height; monitors=$monitors } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $OutputMetadata -Encoding utf8
$monitors
"Captured GDI virtual desktop {0}x{1} at ({2},{3})" -f $width,$height,$left,$top
