$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
Add-Type -AssemblyName System.Drawing

$source = @'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public sealed class TickBounds
{
    public int X, Y, Width, Height;
    public string Label;
    public override string ToString() { return Label + " [" + X + "," + Y + " " + Width + "x" + Height + "]"; }
}
public sealed class TickCapture
{
    public int VirtualX, VirtualY, Width, Height, CursorX, CursorY;
    public string Path;
    public bool Success;
}
public static class TickGdi
{
    private delegate bool MonitorEnumProc(IntPtr hMonitor, IntPtr hdcMonitor, IntPtr lprcMonitor, IntPtr dwData);
    [StructLayout(LayoutKind.Sequential)] private struct RECT { public int Left, Top, Right, Bottom; }
    [StructLayout(LayoutKind.Sequential)] private struct MONITORINFO { public int cbSize; public RECT rcMonitor; public RECT rcWork; public uint dwFlags; }
    [StructLayout(LayoutKind.Sequential)] private struct POINT { public int X, Y; }
    [StructLayout(LayoutKind.Sequential)] private struct BITMAPINFOHEADER
    {
        public uint biSize; public int biWidth, biHeight; public ushort biPlanes, biBitCount; public uint biCompression, biSizeImage;
        public int biXPelsPerMeter, biYPelsPerMeter; public uint biClrUsed, biClrImportant;
    }
    [StructLayout(LayoutKind.Sequential)] private struct BITMAPINFO { public BITMAPINFOHEADER bmiHeader; public uint bmiColors; }
    [DllImport("user32.dll")] private static extern bool EnumDisplayMonitors(IntPtr hdc, IntPtr clip, MonitorEnumProc callback, IntPtr data);
    [DllImport("user32.dll", CharSet = CharSet.Auto)] private static extern bool GetMonitorInfo(IntPtr hMonitor, ref MONITORINFO info);
    [DllImport("user32.dll")] private static extern int GetSystemMetrics(int index);
    [DllImport("user32.dll")] private static extern bool GetCursorPos(out POINT point);
    [DllImport("user32.dll")] private static extern IntPtr GetDC(IntPtr hwnd);
    [DllImport("user32.dll")] private static extern int ReleaseDC(IntPtr hwnd, IntPtr dc);
    [DllImport("gdi32.dll")] private static extern IntPtr CreateCompatibleDC(IntPtr dc);
    [DllImport("gdi32.dll")] private static extern bool DeleteDC(IntPtr dc);
    [DllImport("gdi32.dll")] private static extern IntPtr CreateCompatibleBitmap(IntPtr dc, int width, int height);
    [DllImport("gdi32.dll")] private static extern IntPtr SelectObject(IntPtr dc, IntPtr obj);
    [DllImport("gdi32.dll")] private static extern bool DeleteObject(IntPtr obj);
    [DllImport("gdi32.dll")] private static extern bool BitBlt(IntPtr dst, int x, int y, int width, int height, IntPtr src, int sx, int sy, uint rop);
    [DllImport("gdi32.dll")] private static extern int GetDIBits(IntPtr dc, IntPtr bitmap, uint start, uint lines, byte[] bits, ref BITMAPINFO info, uint usage);
    private const uint SRCCOPY = 0x00CC0020, CAPTUREBLT = 0x40000000, DIB_RGB_COLORS = 0;

    public static TickBounds[] GetMonitorBounds()
    {
        var list = new List<TickBounds>();
        MonitorEnumProc cb = delegate(IntPtr h, IntPtr d, IntPtr r, IntPtr u) {
            var mi = new MONITORINFO(); mi.cbSize = Marshal.SizeOf(typeof(MONITORINFO));
            if (GetMonitorInfo(h, ref mi)) list.Add(new TickBounds { X=mi.rcMonitor.Left, Y=mi.rcMonitor.Top, Width=mi.rcMonitor.Right-mi.rcMonitor.Left, Height=mi.rcMonitor.Bottom-mi.rcMonitor.Top, Label=(mi.dwFlags & 1) != 0 ? "Primary" : "Monitor" });
            return true;
        };
        EnumDisplayMonitors(IntPtr.Zero, IntPtr.Zero, cb, IntPtr.Zero);
        GC.KeepAlive(cb);
        return list.ToArray();
    }
    public static TickBounds GetVirtualBounds()
    {
        return new TickBounds { X=GetSystemMetrics(76), Y=GetSystemMetrics(77), Width=GetSystemMetrics(78), Height=GetSystemMetrics(79), Label="Virtual" };
    }
    public static TickCapture Capture(string path)
    {
        int vx=GetSystemMetrics(76), vy=GetSystemMetrics(77), w=GetSystemMetrics(78), h=GetSystemMetrics(79);
        POINT p; GetCursorPos(out p);
        var result = new TickCapture { VirtualX=vx, VirtualY=vy, Width=w, Height=h, CursorX=p.X, CursorY=p.Y, Path=path, Success=false };
        if (w<=0 || h<=0) return result;
        IntPtr screen=GetDC(IntPtr.Zero), mem=IntPtr.Zero, hbmp=IntPtr.Zero, old=IntPtr.Zero;
        try
        {
            mem=CreateCompatibleDC(screen); hbmp=CreateCompatibleBitmap(screen,w,h); old=SelectObject(mem,hbmp);
            if (!BitBlt(mem,0,0,w,h,screen,vx,vy,SRCCOPY|CAPTUREBLT)) return result;
            SelectObject(mem,old); old=IntPtr.Zero;
            var info = new BITMAPINFO(); info.bmiHeader.biSize=(uint)Marshal.SizeOf(typeof(BITMAPINFOHEADER)); info.bmiHeader.biWidth=w; info.bmiHeader.biHeight=-h; info.bmiHeader.biPlanes=1; info.bmiHeader.biBitCount=32; info.bmiHeader.biCompression=0;
            byte[] pixels=new byte[checked(w*h*4)];
            int got=GetDIBits(screen,hbmp,0,(uint)h,pixels,ref info,DIB_RGB_COLORS);
            if (got != h) return result;
            for (int i=3; i<pixels.Length; i+=4) pixels[i]=255;
            using (var bitmap=new Bitmap(w,h,PixelFormat.Format32bppRgb))
            {
                var data=bitmap.LockBits(new Rectangle(0,0,w,h),ImageLockMode.WriteOnly,PixelFormat.Format32bppRgb);
                try { int rowBytes=w*4; for (int y=0;y<h;y++) Marshal.Copy(pixels,y*rowBytes,IntPtr.Add(data.Scan0,y*data.Stride),rowBytes); }
                finally { bitmap.UnlockBits(data); }
                bitmap.Save(path,ImageFormat.Png);
            }
            result.Success=true; return result;
        }
        finally
        {
            if (old!=IntPtr.Zero) SelectObject(mem,old);
            if (hbmp!=IntPtr.Zero) DeleteObject(hbmp);
            if (mem!=IntPtr.Zero) DeleteDC(mem);
            if (screen!=IntPtr.Zero) ReleaseDC(IntPtr.Zero,screen);
        }
    }
}
'@

Add-Type -TypeDefinition $source -Language CSharp -ReferencedAssemblies @('System.Drawing.Common','System.Drawing.Primitives','System.Private.Windows.GdiPlus','System.Private.Windows.Core','System.Collections','System.Runtime')
$root = Join-Path $PSScriptRoot ('tick-frames-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
[void](New-Item -ItemType Directory -Path $root)
$bounds = [TickGdi]::GetMonitorBounds()
$virtual = [TickGdi]::GetVirtualBounds()
$vx = $virtual.X
$vy = $virtual.Y
$vw = $virtual.Width
$vh = $virtual.Height
Write-Host ("TICK GDI ready | virtual [{0},{1} {2}x{3}] | {4}" -f $vx,$vy,$vw,$vh,(@($bounds | ForEach-Object { $_.ToString() }) -join '; '))
$watch = [System.Diagnostics.Stopwatch]::StartNew()
$start = Get-Date
for ($n = 1; $n -le 10; $n++) {
    $dueMs = $n * 3000
    $remaining = $dueMs - [int]$watch.ElapsedMilliseconds
    if ($remaining -gt 0) { Start-Sleep -Milliseconds $remaining }
    $path = Join-Path $root ('tick-{0:D2}.png' -f $n)
    $capture = [TickGdi]::Capture($path)
    $actual = [math]::Round($watch.Elapsed.TotalSeconds,2)
    $when = (Get-Date).ToString('HH:mm:ss.fff')
    if ($capture.Success) {
        Write-Host ("TICK {0}/10 | {1} | +{2}s | cursor ({3},{4}) | visible desktop {5} | {6}" -f $n,$when,$actual,$capture.CursorX,$capture.CursorY,"[$($capture.VirtualX),$($capture.VirtualY) $($capture.Width)x$($capture.Height)]",$path)
    } else {
        Write-Host ("TICK {0}/10 | {1} | +{2}s | GDI capture failed" -f $n,$when,$actual)
    }
}
$watch.Stop()
Write-Host ("TICK finished | elapsed {0}s | frames {1}" -f [math]::Round($watch.Elapsed.TotalSeconds,2),$root)
