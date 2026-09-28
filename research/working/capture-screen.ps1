$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing.Common
$source = @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public static class GdiDesktopCapture {
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
  [StructLayout(LayoutKind.Sequential)] public struct MONITORINFO { public int cbSize; public RECT rcMonitor; public RECT rcWork; public uint dwFlags; }
  public delegate bool MonitorEnumProc(IntPtr hMon, IntPtr hdc, ref RECT rect, IntPtr data);
  [DllImport("user32.dll")] static extern bool EnumDisplayMonitors(IntPtr dc, IntPtr clip, MonitorEnumProc cb, IntPtr data);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern bool GetMonitorInfoW(IntPtr hmon, ref MONITORINFO info);
  [DllImport("user32.dll")] static extern int GetSystemMetrics(int index);
  [DllImport("user32.dll")] static extern IntPtr GetDC(IntPtr hwnd);
  [DllImport("user32.dll")] static extern int ReleaseDC(IntPtr hwnd, IntPtr dc);
  [DllImport("gdi32.dll")] static extern IntPtr CreateCompatibleDC(IntPtr dc);
  [DllImport("gdi32.dll")] static extern IntPtr CreateCompatibleBitmap(IntPtr dc, int width, int height);
  [DllImport("gdi32.dll")] static extern IntPtr SelectObject(IntPtr dc, IntPtr obj);
  [DllImport("gdi32.dll")] static extern bool BitBlt(IntPtr dst, int x, int y, int w, int h, IntPtr src, int sx, int sy, uint rop);
  [DllImport("gdi32.dll")] static extern bool DeleteObject(IntPtr obj);
  [DllImport("gdi32.dll")] static extern bool DeleteDC(IntPtr dc);
  [DllImport("user32.dll", SetLastError=true)] static extern bool SetProcessDpiAwarenessContext(IntPtr value);
  public static string Layout { get; private set; }
  public static IntPtr Capture() {
    SetProcessDpiAwarenessContext(new IntPtr(-4));
    List<string> monitors = new List<string>();
    MonitorEnumProc callback = delegate(IntPtr h, IntPtr d, ref RECT r, IntPtr p) {
      MONITORINFO mi = new MONITORINFO(); mi.cbSize = Marshal.SizeOf(typeof(MONITORINFO));
      if (GetMonitorInfoW(h, ref mi)) monitors.Add(String.Format("({0},{1}) {2}x{3}", mi.rcMonitor.Left, mi.rcMonitor.Top, mi.rcMonitor.Right-mi.rcMonitor.Left, mi.rcMonitor.Bottom-mi.rcMonitor.Top));
      return true;
    };
    EnumDisplayMonitors(IntPtr.Zero, IntPtr.Zero, callback, IntPtr.Zero);
    int left=GetSystemMetrics(76), top=GetSystemMetrics(77), width=GetSystemMetrics(78), height=GetSystemMetrics(79);
    Layout = "Monitors: "+String.Join("; ",monitors)+" | Virtual desktop: ("+left+","+top+") "+width+"x"+height+" | GDI BitBlt";
    IntPtr screen=GetDC(IntPtr.Zero), mem=IntPtr.Zero, bitmap=IntPtr.Zero, old=IntPtr.Zero;
    try {
      mem=CreateCompatibleDC(screen); bitmap=CreateCompatibleBitmap(screen,width,height); old=SelectObject(mem,bitmap);
      if (!BitBlt(mem,0,0,width,height,screen,left,top,0x00CC0020u|0x40000000u)) throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error(),"GDI BitBlt failed");
      SelectObject(mem,old); old=IntPtr.Zero;
      return bitmap;
    } catch { if (bitmap!=IntPtr.Zero) DeleteObject(bitmap); throw; }
    finally {
      if (old!=IntPtr.Zero) SelectObject(mem,old);
      if (mem!=IntPtr.Zero) DeleteDC(mem);
      if (screen!=IntPtr.Zero) ReleaseDC(IntPtr.Zero,screen);
    }
  }
  public static void Release(IntPtr bitmap) { if (bitmap!=IntPtr.Zero) DeleteObject(bitmap); }
}
"@
Add-Type -TypeDefinition $source
$imagePath = Join-Path $PWD 'work\screen-check.png'
$bitmapHandle = [GdiDesktopCapture]::Capture()
try {
    $image = [System.Drawing.Image]::FromHbitmap($bitmapHandle)
    try { $image.Save($imagePath, [System.Drawing.Imaging.ImageFormat]::Png) }
    finally { $image.Dispose() }
} finally { [GdiDesktopCapture]::Release($bitmapHandle) }
Write-Output ([GdiDesktopCapture]::Layout)
Write-Output "Saved temporary inspection image: $imagePath"
