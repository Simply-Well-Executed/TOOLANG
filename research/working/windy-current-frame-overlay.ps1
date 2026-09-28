$ErrorActionPreference = 'Stop'

$source = @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

public static class WindyCurrentFrameOverlay
{
    private const int PMv2 = -4;
    private const uint WS_POPUP = 0x80000000;
    private const uint WS_EX_LAYERED = 0x00080000;
    private const uint WS_EX_TRANSPARENT = 0x00000020;
    private const uint WS_EX_TOPMOST = 0x00000008;
    private const uint WS_EX_TOOLWINDOW = 0x00000080;
    private const uint WS_EX_NOACTIVATE = 0x08000000;
    private const uint CS_HREDRAW = 0x0002;
    private const uint CS_VREDRAW = 0x0001;
    private const uint LWA_COLORKEY = 0x00000001;
    private const uint SWP_NOACTIVATE = 0x0010;
    private const uint SWP_SHOWWINDOW = 0x0040;
    private const int SW_SHOWNOACTIVATE = 4;
    private const uint WM_PAINT = 0x000F;
    private const uint WM_ERASEBKGND = 0x0014;
    private const uint WM_DESTROY = 0x0002;
    private const uint WM_HOTKEY = 0x0312;
    private const uint WM_QUIT = 0x0012;
    private const uint MOD_CONTROL = 0x0002;
    private const uint MOD_SHIFT = 0x0004;
    private const uint MOD_NOREPEAT = 0x4000;
    private const uint VK_F12 = 0x7B;
    private const int TRANSPARENT_BK = 1;
    private const int PS_SOLID = 0;
    private const int PS_DASH = 1;
    private const int FW_BOLD = 700;
    private const int DEFAULT_CHARSET = 1;
    private const int OUT_DEFAULT_PRECIS = 0;
    private const int CLIP_DEFAULT_PRECIS = 0;
    private const int DEFAULT_QUALITY = 0;
    private const int DEFAULT_PITCH = 0;
    private const int FF_DONTCARE = 0;
    private const int HOLLOW_BRUSH = 5;
    private const uint TRANSPARENT_KEY = 0x00FF00FF;

    private static readonly string ClassName = "WindyCurrentFrameOverlay_20260928";
    private static WndProcDelegate Proc = WindowProc;
    private static int monitorX, monitorY, monitorW, monitorH;
    private static readonly int CenterX = 1359;
    private static readonly int CenterY = 1268;
    private static readonly int HeadingTipX = 1343;
    private static readonly int HeadingTipY = 1089;
    private static readonly int LandX = 1752;
    private static readonly int LandY = 913;

    [StructLayout(LayoutKind.Sequential)]
    private struct RECT { public int Left, Top, Right, Bottom; }

    [StructLayout(LayoutKind.Sequential)]
    private struct POINT { public int X, Y; public POINT(int x, int y) { X=x; Y=y; } }

    [StructLayout(LayoutKind.Sequential)]
    private struct SIZE { public int Cx, Cy; }

    [StructLayout(LayoutKind.Sequential)]
    private struct PAINTSTRUCT
    {
        public IntPtr hdc;
        public int fErase;
        public RECT rcPaint;
        public int fRestore;
        public int fIncUpdate;
        [MarshalAs(UnmanagedType.ByValArray, SizeConst=32)] public byte[] rgbReserved;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct MONITORINFO
    {
        public int cbSize;
        public RECT rcMonitor;
        public RECT rcWork;
        public uint dwFlags;
    }

    [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
    private struct WNDCLASSEX
    {
        public uint cbSize;
        public uint style;
        public WndProcDelegate lpfnWndProc;
        public int cbClsExtra;
        public int cbWndExtra;
        public IntPtr hInstance;
        public IntPtr hIcon;
        public IntPtr hCursor;
        public IntPtr hbrBackground;
        public string lpszMenuName;
        public string lpszClassName;
        public IntPtr hIconSm;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct MSG
    {
        public IntPtr hwnd;
        public uint message;
        public UIntPtr wParam;
        public IntPtr lParam;
        public uint time;
        public POINT pt;
        public uint lPrivate;
    }

    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    private delegate IntPtr WndProcDelegate(IntPtr hwnd, uint msg, IntPtr wParam, IntPtr lParam);
    private delegate bool MonitorEnumProc(IntPtr monitor, IntPtr dc, IntPtr rect, IntPtr data);

    [DllImport("user32.dll", SetLastError=true)] private static extern bool SetProcessDpiAwarenessContext(IntPtr context);
    [DllImport("user32.dll", SetLastError=true)] private static extern bool EnumDisplayMonitors(IntPtr dc, IntPtr clip, MonitorEnumProc callback, IntPtr data);
    [DllImport("user32.dll", SetLastError=true)] private static extern bool GetMonitorInfo(IntPtr monitor, ref MONITORINFO info);
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode)] private static extern IntPtr GetModuleHandle(string moduleName);
    [DllImport("user32.dll", CharSet=CharSet.Unicode, SetLastError=true)] private static extern ushort RegisterClassEx(ref WNDCLASSEX wc);
    [DllImport("user32.dll", CharSet=CharSet.Unicode, SetLastError=true)] private static extern IntPtr CreateWindowEx(uint exStyle, string className, string windowName, uint style, int x, int y, int width, int height, IntPtr parent, IntPtr menu, IntPtr instance, IntPtr param);
    [DllImport("user32.dll", SetLastError=true)] private static extern bool SetLayeredWindowAttributes(IntPtr hwnd, uint colorKey, byte alpha, uint flags);
    [DllImport("user32.dll", SetLastError=true)] private static extern bool RegisterHotKey(IntPtr hwnd, int id, uint modifiers, uint key);
    [DllImport("user32.dll")] private static extern bool UnregisterHotKey(IntPtr hwnd, int id);
    [DllImport("user32.dll", SetLastError=true)] private static extern bool SetWindowPos(IntPtr hwnd, IntPtr after, int x, int y, int cx, int cy, uint flags);
    [DllImport("user32.dll")] private static extern bool ShowWindow(IntPtr hwnd, int command);
    [DllImport("user32.dll")] private static extern bool UpdateWindow(IntPtr hwnd);
    [DllImport("user32.dll")] private static extern int FillRect(IntPtr dc, ref RECT rect, IntPtr brush);
    [DllImport("user32.dll")] private static extern IntPtr BeginPaint(IntPtr hwnd, ref PAINTSTRUCT ps);
    [DllImport("user32.dll")] private static extern bool EndPaint(IntPtr hwnd, ref PAINTSTRUCT ps);
    [DllImport("user32.dll")] private static extern bool GetClientRect(IntPtr hwnd, out RECT rect);
    [DllImport("user32.dll")] private static extern int GetMessage(out MSG msg, IntPtr hwnd, uint min, uint max);
    [DllImport("user32.dll")] private static extern bool TranslateMessage(ref MSG msg);
    [DllImport("user32.dll")] private static extern IntPtr DispatchMessage(ref MSG msg);
    [DllImport("user32.dll")] private static extern IntPtr DefWindowProc(IntPtr hwnd, uint msg, IntPtr wParam, IntPtr lParam);
    [DllImport("user32.dll")] private static extern bool DestroyWindow(IntPtr hwnd);
    [DllImport("user32.dll")] private static extern void PostQuitMessage(int exitCode);
    [DllImport("user32.dll", SetLastError=true)] private static extern bool UnregisterClass(string className, IntPtr instance);

    [DllImport("gdi32.dll", SetLastError=true)] private static extern IntPtr CreateSolidBrush(uint color);
    [DllImport("gdi32.dll", SetLastError=true)] private static extern IntPtr CreatePen(int style, int width, uint color);
    [DllImport("gdi32.dll")] private static extern IntPtr SelectObject(IntPtr dc, IntPtr obj);
    [DllImport("gdi32.dll")] private static extern bool DeleteObject(IntPtr obj);
    [DllImport("gdi32.dll")] private static extern bool MoveToEx(IntPtr dc, int x, int y, IntPtr oldPoint);
    [DllImport("gdi32.dll")] private static extern bool LineTo(IntPtr dc, int x, int y);
    [DllImport("gdi32.dll")] private static extern bool Ellipse(IntPtr dc, int left, int top, int right, int bottom);
    [DllImport("gdi32.dll")] private static extern bool Polygon(IntPtr dc, [In] POINT[] points, int count);
    [DllImport("gdi32.dll")] private static extern int SetBkMode(IntPtr dc, int mode);
    [DllImport("gdi32.dll")] private static extern uint SetTextColor(IntPtr dc, uint color);
    [DllImport("gdi32.dll", CharSet=CharSet.Unicode)] private static extern IntPtr CreateFontW(int height, int width, int escapement, int orientation, int weight, uint italic, uint underline, uint strikeOut, uint charSet, uint outPrecision, uint clipPrecision, uint quality, uint pitchAndFamily, string faceName);
    [DllImport("gdi32.dll", CharSet=CharSet.Unicode)] private static extern bool GetTextExtentPoint32W(IntPtr dc, string text, int count, out SIZE size);
    [DllImport("gdi32.dll", CharSet=CharSet.Unicode)] private static extern bool TextOutW(IntPtr dc, int x, int y, string text, int count);
    [DllImport("gdi32.dll")] private static extern bool RoundRect(IntPtr dc, int left, int top, int right, int bottom, int ellipseW, int ellipseH);
    [DllImport("gdi32.dll")] private static extern IntPtr GetStockObject(int index);

    private static uint RGB(byte r, byte g, byte b) { return (uint)(r | (g << 8) | (b << 16)); }

    private static void FindSecondMonitor()
    {
        List<RECT> found = new List<RECT>();
        MonitorEnumProc callback = delegate(IntPtr monitor, IntPtr dc, IntPtr rect, IntPtr data)
        {
            MONITORINFO info = new MONITORINFO();
            info.cbSize = Marshal.SizeOf(typeof(MONITORINFO));
            if (!GetMonitorInfo(monitor, ref info)) throw new InvalidOperationException("GetMonitorInfo failed: " + Marshal.GetLastWin32Error());
            found.Add(info.rcMonitor);
            return true;
        };
        if (!EnumDisplayMonitors(IntPtr.Zero, IntPtr.Zero, callback, IntPtr.Zero))
            throw new InvalidOperationException("EnumDisplayMonitors failed: " + Marshal.GetLastWin32Error());
        if (found.Count < 2) throw new InvalidOperationException("The Windy overlay needs the second display to be active.");
        found.Sort(delegate(RECT a, RECT b) { int c=a.Left.CompareTo(b.Left); return c != 0 ? c : a.Top.CompareTo(b.Top); });
        RECT target = found[1];
        monitorX = target.Left; monitorY = target.Top;
        monitorW = target.Right-target.Left; monitorH = target.Bottom-target.Top;
        if (monitorX != 3440 || monitorY != 0 || monitorW != 3840 || monitorH != 2160)
            throw new InvalidOperationException("Display 2 changed since calibration; overlay cancelled to prevent a misplaced drawing. Current Display 2: " + monitorX + "," + monitorY + " " + monitorW + "x" + monitorH);
    }

    public static void Run()
    {
        if (!SetProcessDpiAwarenessContext(new IntPtr(PMv2)))
            throw new InvalidOperationException("Could not enable per-monitor DPI awareness: " + Marshal.GetLastWin32Error());
        FindSecondMonitor();
        IntPtr instance = GetModuleHandle(null);
        WNDCLASSEX wc = new WNDCLASSEX();
        wc.cbSize = (uint)Marshal.SizeOf(typeof(WNDCLASSEX));
        wc.style = CS_HREDRAW | CS_VREDRAW;
        wc.lpfnWndProc = Proc;
        wc.hInstance = instance;
        wc.lpszClassName = ClassName;
        if (RegisterClassEx(ref wc) == 0) throw new InvalidOperationException("RegisterClassEx failed: " + Marshal.GetLastWin32Error());

        IntPtr hwnd = CreateWindowEx(WS_EX_LAYERED | WS_EX_TRANSPARENT | WS_EX_TOPMOST | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE,
            ClassName, "Windy advisory overlay", WS_POPUP, monitorX, monitorY, monitorW, monitorH,
            IntPtr.Zero, IntPtr.Zero, instance, IntPtr.Zero);
        if (hwnd == IntPtr.Zero) throw new InvalidOperationException("CreateWindowEx failed: " + Marshal.GetLastWin32Error());
        if (!SetLayeredWindowAttributes(hwnd, TRANSPARENT_KEY, 0, LWA_COLORKEY)) throw new InvalidOperationException("SetLayeredWindowAttributes failed: " + Marshal.GetLastWin32Error());
        if (!RegisterHotKey(hwnd, 1, MOD_CONTROL | MOD_SHIFT | MOD_NOREPEAT, VK_F12)) throw new InvalidOperationException("Could not register Ctrl+Shift+F12 to close the overlay: " + Marshal.GetLastWin32Error());
        if (!SetWindowPos(hwnd, new IntPtr(-1), monitorX, monitorY, monitorW, monitorH, SWP_NOACTIVATE | SWP_SHOWWINDOW)) throw new InvalidOperationException("SetWindowPos failed: " + Marshal.GetLastWin32Error());
        ShowWindow(hwnd, SW_SHOWNOACTIVATE);
        UpdateWindow(hwnd);
        Console.WriteLine("GDI overlay active on Display 2 ({0},{1} {2}x{3}). Windy 5 PM MST / NHC Advisory 29A.", monitorX, monitorY, monitorW, monitorH);
        Console.WriteLine("Cyan: NHC movement heading 355 degrees north at 12 mph. Gold: nearest validated mainland pin, 10 km inside land.");
        Console.WriteLine("Move or refresh Windy only after closing this frame overlay. Close with Ctrl+Shift+F12.");
        MSG msg;
        int result;
        while ((result = GetMessage(out msg, IntPtr.Zero, 0, 0)) > 0)
        {
            TranslateMessage(ref msg);
            DispatchMessage(ref msg);
        }
        UnregisterHotKey(hwnd, 1);
        UnregisterClass(ClassName, instance);
        Console.WriteLine("Overlay closed.");
    }

    private static IntPtr WindowProc(IntPtr hwnd, uint msg, IntPtr wParam, IntPtr lParam)
    {
        if (msg == WM_PAINT)
        {
            PAINTSTRUCT ps = new PAINTSTRUCT();
            ps.rgbReserved = new byte[32];
            IntPtr dc = BeginPaint(hwnd, ref ps);
            try { Draw(dc, hwnd); }
            finally { EndPaint(hwnd, ref ps); }
            return IntPtr.Zero;
        }
        if (msg == WM_ERASEBKGND) return new IntPtr(1);
        if (msg == WM_HOTKEY)
        {
            DestroyWindow(hwnd);
            return IntPtr.Zero;
        }
        if (msg == WM_DESTROY)
        {
            PostQuitMessage(0);
            return IntPtr.Zero;
        }
        return DefWindowProc(hwnd, msg, wParam, lParam);
    }

    private static void Draw(IntPtr dc, IntPtr hwnd)
    {
        RECT client;
        GetClientRect(hwnd, out client);
        IntPtr clear = CreateSolidBrush(TRANSPARENT_KEY);
        FillRect(dc, ref client, clear);
        DeleteObject(clear);

        uint cyan = RGB(20, 245, 255);
        uint gold = RGB(255, 210, 20);
        uint white = RGB(245, 250, 255);

        // Reuse the earlier double-triangle construction: a shared cross-axis,
        // opposing tips along the center-to-land bearing, and T1/T2 centroids.
        double dx = LandX - CenterX;
        double dy = LandY - CenterY;
        double length = Math.Sqrt(dx * dx + dy * dy);
        double ux = dx / length;
        double uy = dy / length;
        double px = -uy;
        double py = ux;
        POINT p1 = new POINT((int)Math.Round(CenterX + px * 50), (int)Math.Round(CenterY + py * 50));
        POINT p2 = new POINT((int)Math.Round(CenterX - px * 50), (int)Math.Round(CenterY - py * 50));
        POINT landTip = new POINT((int)Math.Round(CenterX + ux * 140), (int)Math.Round(CenterY + uy * 140));
        POINT seaTip = new POINT((int)Math.Round(CenterX - ux * 140), (int)Math.Round(CenterY - uy * 140));
        int t1x = (p1.X + p2.X + landTip.X) / 3;
        int t1y = (p1.Y + p2.Y + landTip.Y) / 3;
        int t2x = (p1.X + p2.X + seaTip.X) / 3;
        int t2y = (p1.Y + p2.Y + seaTip.Y) / 3;

        DrawPolyline(dc, new POINT[] { p1, p2, landTip, p1 }, cyan, 3, PS_SOLID);
        DrawPolyline(dc, new POINT[] { p1, p2, seaTip, p1 }, cyan, 3, PS_SOLID);
        DrawPolyline(dc, new POINT[] { new POINT(t2x, t2y), new POINT(t1x, t1y) }, white, 2, PS_DASH);

        DrawArrow(dc, CenterX, CenterY, LandX, LandY, gold, 7, 28);
        DrawArrow(dc, CenterX, CenterY, HeadingTipX, HeadingTipY, cyan, 7, 25);
        DrawRing(dc, CenterX, CenterY, 18, cyan, 5);
        DrawDot(dc, t1x, t1y, 7, cyan);
        DrawDot(dc, t2x, t2y, 7, cyan);
        DrawRing(dc, LandX, LandY, 19, gold, 6);
        DrawDot(dc, LandX, LandY, 5, gold);

        Label(dc, HeadingTipX - 560, HeadingTipY - 54, "NHC 29A: 355 degrees north  |  12 mph", cyan);
        DrawSmallText(dc, t1x + 10, t1y - 28, "T1", cyan);
        DrawSmallText(dc, t2x + 10, t2y + 7, "T2", cyan);
        Label(dc, LandX + 26, LandY - 61, "Nearest mainland pin  |  10 km inland", gold);
        Label(dc, LandX + 26, LandY - 24, "24.663 N, 111.748 W", white);
    }

    private static void DrawPolyline(IntPtr dc, POINT[] points, uint color, int width, int style)
    {
        if (points == null || points.Length < 2) return;
        IntPtr pen = CreatePen(style, width, color);
        IntPtr oldPen = SelectObject(dc, pen);
        MoveToEx(dc, points[0].X, points[0].Y, IntPtr.Zero);
        for (int i = 1; i < points.Length; i++) LineTo(dc, points[i].X, points[i].Y);
        SelectObject(dc, oldPen);
        DeleteObject(pen);
    }

    private static void DrawSmallText(IntPtr dc, int x, int y, string text, uint color)
    {
        IntPtr font = CreateFontW(-27, 0, 0, 0, FW_BOLD, 0, 0, 0, DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, DEFAULT_QUALITY, DEFAULT_PITCH | FF_DONTCARE, "Segoe UI");
        IntPtr oldFont = SelectObject(dc, font);
        SetBkMode(dc, TRANSPARENT_BK);
        SetTextColor(dc, RGB(10, 18, 25));
        TextOutW(dc, x + 2, y + 2, text, text.Length);
        SetTextColor(dc, color);
        TextOutW(dc, x, y, text, text.Length);
        SelectObject(dc, oldFont);
        DeleteObject(font);
    }

    private static void DrawArrow(IntPtr dc, int x1, int y1, int x2, int y2, uint color, int width, int head)
    {
        IntPtr pen = CreatePen(PS_SOLID, width, color);
        IntPtr oldPen = SelectObject(dc, pen);
        MoveToEx(dc, x1, y1, IntPtr.Zero);
        LineTo(dc, x2, y2);
        SelectObject(dc, oldPen);
        DeleteObject(pen);

        double angle = Math.Atan2(y2-y1, x2-x1);
        POINT[] tri = new POINT[3];
        tri[0] = new POINT(x2, y2);
        tri[1] = new POINT((int)Math.Round(x2-head*Math.Cos(angle-Math.PI/6)), (int)Math.Round(y2-head*Math.Sin(angle-Math.PI/6)));
        tri[2] = new POINT((int)Math.Round(x2-head*Math.Cos(angle+Math.PI/6)), (int)Math.Round(y2-head*Math.Sin(angle+Math.PI/6)));
        pen = CreatePen(PS_SOLID, 1, color);
        IntPtr brush = CreateSolidBrush(color);
        oldPen = SelectObject(dc, pen);
        IntPtr oldBrush = SelectObject(dc, brush);
        Polygon(dc, tri, 3);
        SelectObject(dc, oldBrush);
        SelectObject(dc, oldPen);
        DeleteObject(brush);
        DeleteObject(pen);
    }

    private static void DrawRing(IntPtr dc, int x, int y, int radius, uint color, int width)
    {
        IntPtr pen = CreatePen(PS_SOLID, width, color);
        IntPtr oldPen = SelectObject(dc, pen);
        IntPtr hollow = GetStockObject(HOLLOW_BRUSH);
        IntPtr oldBrush = SelectObject(dc, hollow);
        Ellipse(dc, x-radius, y-radius, x+radius, y+radius);
        SelectObject(dc, oldBrush);
        SelectObject(dc, oldPen);
        DeleteObject(pen);
    }

    private static void DrawDot(IntPtr dc, int x, int y, int radius, uint color)
    {
        IntPtr brush = CreateSolidBrush(color);
        IntPtr oldBrush = SelectObject(dc, brush);
        IntPtr pen = CreatePen(PS_SOLID, 1, color);
        IntPtr oldPen = SelectObject(dc, pen);
        Ellipse(dc, x-radius, y-radius, x+radius, y+radius);
        SelectObject(dc, oldPen);
        SelectObject(dc, oldBrush);
        DeleteObject(pen);
        DeleteObject(brush);
    }

    private static void Label(IntPtr dc, int x, int y, string text, uint color)
    {
        IntPtr font = CreateFontW(-29, 0, 0, 0, FW_BOLD, 0, 0, 0, DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, DEFAULT_QUALITY, DEFAULT_PITCH | FF_DONTCARE, "Segoe UI");
        IntPtr oldFont = SelectObject(dc, font);
        SIZE size;
        GetTextExtentPoint32W(dc, text, text.Length, out size);
        RECT box = new RECT { Left=x-10, Top=y-7, Right=x+size.Cx+10, Bottom=y+size.Cy+7 };
        IntPtr bg = CreateSolidBrush(RGB(19, 26, 36));
        IntPtr border = CreatePen(PS_SOLID, 2, color);
        IntPtr oldBrush = SelectObject(dc, bg);
        IntPtr oldPen = SelectObject(dc, border);
        RoundRect(dc, box.Left, box.Top, box.Right, box.Bottom, 14, 14);
        SelectObject(dc, oldPen);
        SelectObject(dc, oldBrush);
        SetBkMode(dc, TRANSPARENT_BK);
        SetTextColor(dc, color);
        TextOutW(dc, x, y, text, text.Length);
        SelectObject(dc, oldFont);
        DeleteObject(border);
        DeleteObject(bg);
        DeleteObject(font);
    }
}
'@

Add-Type -TypeDefinition $source
[WindyCurrentFrameOverlay]::Run()
