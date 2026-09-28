param(
    [long]$TargetWindowHandle = 0
)

$ErrorActionPreference = 'Stop'
$logPath = Join-Path $PSScriptRoot 'windy-native-overlay.log'

try {
    $source = @'
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Threading;

public static class WindyNativeOverlay
{
    private const uint WS_POPUP = 0x80000000;
    private const uint WS_EX_TRANSPARENT = 0x00000020;
    private const uint WS_EX_TOOLWINDOW = 0x00000080;
    private const uint WS_EX_LAYERED = 0x00080000;
    private const uint WS_EX_NOACTIVATE = 0x08000000;
    private const uint LWA_COLORKEY = 0x00000001;
    private const uint SWP_NOACTIVATE = 0x0010;
    private const uint SWP_SHOWWINDOW = 0x0040;
    private const int SW_SHOWNOACTIVATE = 4;
    private const int SW_HIDE = 0;
    private const int PM_REMOVE = 0x0001;
    private const uint WM_PAINT = 0x000F;
    private const uint WM_ERASEBKGND = 0x0014;
    private const uint WM_DESTROY = 0x0002;
    private const uint WM_NCHITTEST = 0x0084;
    private const uint WM_MOUSEACTIVATE = 0x0021;
    private const int MA_NOACTIVATE = 3;
    private const int HTTRANSPARENT = -1;
    private const int VK_ESCAPE = 0x1B;
    private const int VK_LBUTTON = 0x01;
    private const int PS_SOLID = 0;
    private const int PS_DASH = 1;
    private const int COLORKEY = 0x00FF00FF;

    [StructLayout(LayoutKind.Sequential)]
    private struct RECT { public int Left, Top, Right, Bottom; }

    [StructLayout(LayoutKind.Sequential)]
    private struct POINT { public int X, Y; public POINT(int x, int y) { X = x; Y = y; } }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct WNDCLASSEX
    {
        public uint cbSize;
        public uint style;
        public WndProc lpfnWndProc;
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
    private struct PAINTSTRUCT
    {
        public IntPtr hdc;
        public int fErase;
        public RECT rcPaint;
        public int fRestore;
        public int fIncUpdate;
        public ulong reserved0, reserved1, reserved2, reserved3;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct MSG
    {
        public IntPtr hwnd;
        public uint message;
        public IntPtr wParam;
        public IntPtr lParam;
        public uint time;
        public POINT pt;
        public uint lPrivate;
    }

    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    private delegate IntPtr WndProc(IntPtr hwnd, uint message, IntPtr wParam, IntPtr lParam);

    private static readonly WndProc WindowProcDelegate = WindowProc;
    private static IntPtr _target;
    private static IntPtr _console;
    private static IntPtr _overlay;
    private static IntPtr _backgroundBrush;
    private static IntPtr _instance;
    private static string _className;
    private static uint _targetProcessId;
    private static int _width;
    private static int _height;
    private static int _targetLeft;
    private static int _targetTop;
    private static int _centerX = 760;
    private static int _centerY = 835;
    private static int _landX = 1014;
    private static int _landY = 682;
    private static int _lastCursorX;
    private static int _lastCursorY;
    private static bool _leftButtonDown;
    private static bool _mapDragging;
    private static bool _visible;

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool GetWindowRect(IntPtr hwnd, out RECT rect);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll", SetLastError = true)]
    private static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint processId);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool IsIconic(IntPtr hwnd);

    [DllImport("user32.dll")]
    private static extern short GetAsyncKeyState(int virtualKey);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool GetCursorPos(out POINT point);

    [DllImport("user32.dll", EntryPoint = "RegisterClassExW", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern ushort RegisterClassEx(ref WNDCLASSEX windowClass);

    [DllImport("user32.dll", EntryPoint = "UnregisterClassW", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern bool UnregisterClass(string className, IntPtr instance);

    [DllImport("user32.dll", EntryPoint = "CreateWindowExW", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern IntPtr CreateWindowEx(uint exStyle, string className, string windowName, uint style,
        int x, int y, int width, int height, IntPtr parent, IntPtr menu, IntPtr instance, IntPtr parameter);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool SetLayeredWindowAttributes(IntPtr hwnd, uint colorKey, byte alpha, uint flags);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool SetWindowPos(IntPtr hwnd, IntPtr insertAfter, int x, int y, int width, int height, uint flags);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool ShowWindow(IntPtr hwnd, int command);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool DestroyWindow(IntPtr hwnd);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool InvalidateRect(IntPtr hwnd, IntPtr rect, bool erase);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern IntPtr BeginPaint(IntPtr hwnd, out PAINTSTRUCT paint);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool EndPaint(IntPtr hwnd, ref PAINTSTRUCT paint);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool PeekMessage(out MSG message, IntPtr hwnd, uint min, uint max, uint remove);

    [DllImport("user32.dll")]
    private static extern bool TranslateMessage(ref MSG message);

    [DllImport("user32.dll")]
    private static extern IntPtr DispatchMessage(ref MSG message);

    [DllImport("user32.dll")]
    private static extern IntPtr DefWindowProcW(IntPtr hwnd, uint message, IntPtr wParam, IntPtr lParam);

    [DllImport("user32.dll")]
    private static extern void PostQuitMessage(int exitCode);

    [DllImport("user32.dll")]
    private static extern bool SetProcessDPIAware();

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)]
    private static extern IntPtr GetModuleHandle(string moduleName);

    [DllImport("kernel32.dll")]
    private static extern IntPtr GetConsoleWindow();

    [DllImport("gdi32.dll", SetLastError = true)]
    private static extern IntPtr CreateSolidBrush(uint colorRef);

    [DllImport("gdi32.dll", SetLastError = true)]
    private static extern IntPtr CreatePen(int style, int width, uint colorRef);

    [DllImport("gdi32.dll", SetLastError = true)]
    private static extern IntPtr SelectObject(IntPtr hdc, IntPtr obj);

    [DllImport("gdi32.dll", SetLastError = true)]
    private static extern bool DeleteObject(IntPtr obj);

    [DllImport("gdi32.dll", SetLastError = true)]
    private static extern bool Polyline(IntPtr hdc, [In] POINT[] points, int count);

    [DllImport("gdi32.dll", SetLastError = true)]
    private static extern bool Ellipse(IntPtr hdc, int left, int top, int right, int bottom);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern int FillRect(IntPtr hdc, ref RECT rect, IntPtr brush);

    [DllImport("gdi32.dll")]
    private static extern int SetBkMode(IntPtr hdc, int mode);

    [DllImport("gdi32.dll")]
    private static extern uint SetTextColor(IntPtr hdc, uint colorRef);

    [DllImport("gdi32.dll", EntryPoint = "TextOutW", CharSet = CharSet.Unicode)]
    private static extern bool TextOut(IntPtr hdc, int x, int y, string text, int length);

    private static IntPtr WindowProc(IntPtr hwnd, uint message, IntPtr wParam, IntPtr lParam)
    {
        if (message == WM_NCHITTEST) return new IntPtr(HTTRANSPARENT);
        if (message == WM_MOUSEACTIVATE) return new IntPtr(MA_NOACTIVATE);
        if (message == WM_ERASEBKGND) return new IntPtr(1);
        if (message == WM_PAINT)
        {
            PAINTSTRUCT paint;
            IntPtr hdc = BeginPaint(hwnd, out paint);
            if (hdc != IntPtr.Zero)
            {
                RECT client = new RECT { Left = 0, Top = 0, Right = _width, Bottom = _height };
                FillRect(hdc, ref client, _backgroundBrush);
                Paint(hdc, _width, _height);
                EndPaint(hwnd, ref paint);
            }
            return IntPtr.Zero;
        }
        if (message == WM_DESTROY)
        {
            PostQuitMessage(0);
            return IntPtr.Zero;
        }
        return DefWindowProcW(hwnd, message, wParam, lParam);
    }

    private static uint ColorRef(byte r, byte g, byte b)
    {
        return (uint)(r | (g << 8) | (b << 16));
    }

    private static IntPtr FindWindyChromeWindow()
    {
        foreach (Process process in Process.GetProcessesByName("chrome"))
        {
            using (process)
            {
                process.Refresh();
                if (process.MainWindowHandle != IntPtr.Zero &&
                    process.MainWindowTitle.IndexOf("Windy", StringComparison.OrdinalIgnoreCase) >= 0)
                {
                    return process.MainWindowHandle;
                }
            }
        }
        return IntPtr.Zero;
    }

    private static void DrawPolyline(IntPtr hdc, POINT[] points, uint color, int width, int style)
    {
        IntPtr pen = CreatePen(style, width, color);
        IntPtr old = SelectObject(hdc, pen);
        try { Polyline(hdc, points, points.Length); }
        finally { SelectObject(hdc, old); DeleteObject(pen); }
    }

    private static void DrawCircle(IntPtr hdc, int x, int y, int radius, uint color)
    {
        IntPtr pen = CreatePen(PS_SOLID, 2, color);
        IntPtr brush = CreateSolidBrush(color);
        IntPtr oldPen = SelectObject(hdc, pen);
        IntPtr oldBrush = SelectObject(hdc, brush);
        try { Ellipse(hdc, x - radius, y - radius, x + radius, y + radius); }
        finally
        {
            SelectObject(hdc, oldBrush);
            SelectObject(hdc, oldPen);
            DeleteObject(brush);
            DeleteObject(pen);
        }
    }

    private static void DrawText(IntPtr hdc, int x, int y, string text, uint color)
    {
        SetTextColor(hdc, ColorRef(0, 0, 0));
        TextOut(hdc, x + 1, y + 1, text, text.Length);
        SetTextColor(hdc, color);
        TextOut(hdc, x, y, text, text.Length);
    }

    private static void Paint(IntPtr hdc, int width, int height)
    {
        SetBkMode(hdc, 1);
        int cx = _centerX;
        int cy = _centerY;
        int lx = _landX;
        int ly = _landY;

        double dx = lx - cx;
        double dy = ly - cy;
        double length = Math.Sqrt(dx * dx + dy * dy);
        double ux = dx / length;
        double uy = dy / length;
        double px = -uy;
        double py = ux;

        POINT p1 = new POINT((int)(cx + px * 28), (int)(cy + py * 28));
        POINT p2 = new POINT((int)(cx - px * 28), (int)(cy - py * 28));
        POINT landTip = new POINT((int)(cx + ux * 78), (int)(cy + uy * 78));
        POINT seaTip = new POINT((int)(cx - ux * 78), (int)(cy - uy * 78));
        POINT[] towardLand = new POINT[] { p1, p2, landTip, p1 };
        POINT[] awayFromLand = new POINT[] { p1, p2, seaTip, p1 };

        int t1x = (p1.X + p2.X + landTip.X) / 3;
        int t1y = (p1.Y + p2.Y + landTip.Y) / 3;
        int t2x = (p1.X + p2.X + seaTip.X) / 3;
        int t2y = (p1.Y + p2.Y + seaTip.Y) / 3;

        uint cyan = ColorRef(0, 255, 255);
        uint gold = ColorRef(255, 220, 0);
        uint white = ColorRef(255, 255, 255);

        DrawPolyline(hdc, towardLand, cyan, 3, PS_SOLID);
        DrawPolyline(hdc, awayFromLand, cyan, 3, PS_SOLID);
        DrawPolyline(hdc, new POINT[] { new POINT(t2x, t2y), new POINT(t1x, t1y) }, white, 2, PS_DASH);
        DrawPolyline(hdc, new POINT[] { new POINT(cx, cy), new POINT(lx, ly) }, gold, 4, PS_SOLID);

        double angle = Math.Atan2(dy, dx);
        double head = 20.0;
        DrawPolyline(hdc, new POINT[] { new POINT(lx, ly), new POINT(lx - (int)(head * Math.Cos(angle - Math.PI / 6)), ly - (int)(head * Math.Sin(angle - Math.PI / 6))) }, gold, 4, PS_SOLID);
        DrawPolyline(hdc, new POINT[] { new POINT(lx, ly), new POINT(lx - (int)(head * Math.Cos(angle + Math.PI / 6)), ly - (int)(head * Math.Sin(angle + Math.PI / 6))) }, gold, 4, PS_SOLID);

        DrawCircle(hdc, t1x, t1y, 7, cyan);
        DrawCircle(hdc, t2x, t2y, 7, cyan);
        DrawCircle(hdc, cx, cy, 8, white);
        DrawCircle(hdc, lx, ly, 8, gold);

        DrawText(hdc, 430, 180, "T1/T2 centroid axis | Google Earth land pin: 24.038 N, 110.950 W (+27 m) | not a forecast | Esc closes", ColorRef(255, 238, 80));
        DrawCircle(hdc, lx, ly, 10, gold);
        DrawText(hdc, lx + 12, ly + 8, "verified land pin (+27 m)", gold);
        DrawText(hdc, t1x + 9, t1y - 18, "T1", cyan);
        DrawText(hdc, t2x + 9, t2y - 18, "T2", cyan);
    }

    public static void Run(IntPtr targetHandle)
    {
        SetProcessDPIAware();
        _target = targetHandle != IntPtr.Zero ? targetHandle : FindWindyChromeWindow();
        if (_target == IntPtr.Zero) throw new InvalidOperationException("The Windy Chrome window was not found.");
        GetWindowThreadProcessId(_target, out _targetProcessId);

        _console = GetConsoleWindow();
        _instance = GetModuleHandle(null);
        RECT targetRect;
        if (!GetWindowRect(_target, out targetRect)) throw new InvalidOperationException("Could not read Windy window bounds.");
        _targetLeft = targetRect.Left;
        _targetTop = targetRect.Top;
        _width = targetRect.Right - targetRect.Left;
        _height = targetRect.Bottom - targetRect.Top;
        _backgroundBrush = CreateSolidBrush((uint)COLORKEY);

        _className = "WindyFacingOverlay_" + Environment.ProcessId.ToString();
        WNDCLASSEX wc = new WNDCLASSEX();
        wc.cbSize = (uint)Marshal.SizeOf(typeof(WNDCLASSEX));
        wc.lpfnWndProc = WindowProcDelegate;
        wc.hInstance = _instance;
        wc.hbrBackground = _backgroundBrush;
        wc.lpszClassName = _className;
        if (RegisterClassEx(ref wc) == 0) throw new InvalidOperationException("RegisterClassEx failed: " + Marshal.GetLastWin32Error());

        _overlay = CreateWindowEx(WS_EX_LAYERED | WS_EX_TRANSPARENT | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE,
            _className, "Windy facing overlay", WS_POPUP,
            targetRect.Left, targetRect.Top, _width, _height,
            IntPtr.Zero, IntPtr.Zero, _instance, IntPtr.Zero);
        if (_overlay == IntPtr.Zero) throw new InvalidOperationException("CreateWindowEx failed: " + Marshal.GetLastWin32Error());

        if (!SetLayeredWindowAttributes(_overlay, (uint)COLORKEY, 255, LWA_COLORKEY))
            throw new InvalidOperationException("SetLayeredWindowAttributes failed: " + Marshal.GetLastWin32Error());

        SetWindowPos(_overlay, new IntPtr(-1), targetRect.Left, targetRect.Top, _width, _height, SWP_NOACTIVATE | SWP_SHOWWINDOW);
        ShowWindow(_overlay, SW_SHOWNOACTIVATE);
        _visible = true;

        MSG msg;
        bool quit = false;
        while (!quit)
        {
            while (PeekMessage(out msg, IntPtr.Zero, 0, 0, PM_REMOVE))
            {
                if (msg.message == 0x0012) { quit = true; break; }
                TranslateMessage(ref msg);
                DispatchMessage(ref msg);
            }

            if ((GetAsyncKeyState(VK_ESCAPE) & 0x8000) != 0) break;

            TrackMapDrag();

            IntPtr foreground = GetForegroundWindow();
            uint foregroundProcessId;
            GetWindowThreadProcessId(foreground, out foregroundProcessId);
            if (foreground == _target || foregroundProcessId == _targetProcessId || foreground == _console)
            {
                if (!IsIconic(_target) && GetWindowRect(_target, out targetRect))
                {
                    _targetLeft = targetRect.Left;
                    _targetTop = targetRect.Top;
                    _width = targetRect.Right - targetRect.Left;
                    _height = targetRect.Bottom - targetRect.Top;
                    SetWindowPos(_overlay, new IntPtr(-1), targetRect.Left, targetRect.Top, _width, _height, SWP_NOACTIVATE | SWP_SHOWWINDOW);
                    if (!_visible) { ShowWindow(_overlay, SW_SHOWNOACTIVATE); _visible = true; }
                    InvalidateRect(_overlay, IntPtr.Zero, false);
                }
            }
            else if (_visible)
            {
                ShowWindow(_overlay, SW_HIDE);
                _visible = false;
            }

            Thread.Sleep(100);
        }

        if (_overlay != IntPtr.Zero) DestroyWindow(_overlay);
        if (_backgroundBrush != IntPtr.Zero) DeleteObject(_backgroundBrush);
        UnregisterClass(_className, _instance);
    }

    private static void TrackMapDrag()
    {
        POINT cursor;
        if (!GetCursorPos(out cursor)) return;

        bool down = (GetAsyncKeyState(VK_LBUTTON) & 0x8000) != 0;
        if (down)
        {
            if (!_leftButtonDown)
            {
                _leftButtonDown = true;
                _lastCursorX = cursor.X;
                _lastCursorY = cursor.Y;
                int localX = cursor.X - _targetLeft;
                int localY = cursor.Y - _targetTop;
                _mapDragging = localX >= 40 && localX < _width - 260 &&
                    localY >= 88 && localY < _height - 58;
                return;
            }

            if (_mapDragging)
            {
                int dx = cursor.X - _lastCursorX;
                int dy = cursor.Y - _lastCursorY;
                _centerX += dx;
                _centerY += dy;
                _landX += dx;
                _landY += dy;
            }

            _lastCursorX = cursor.X;
            _lastCursorY = cursor.Y;
        }
        else
        {
            _leftButtonDown = false;
            _mapDragging = false;
        }
    }
}
'@

    Add-Type -TypeDefinition $source
    try {
        $Host.UI.RawUI.WindowTitle = 'Windy facing overlay - press Esc to close'
        $Host.UI.RawUI.BufferSize = [System.Management.Automation.Host.Size]::new(64, 8)
        $Host.UI.RawUI.WindowSize = [System.Management.Automation.Host.Size]::new(64, 8)
    } catch { }
    Write-Host 'Windy overlay is running as your user.' -ForegroundColor Cyan
    Write-Host 'Bring Chrome forward to see the marks. Press Esc to close.' -ForegroundColor Yellow
    [WindyNativeOverlay]::Run([IntPtr]$TargetWindowHandle)
}
catch {
    $_ | Out-String | Set-Content -LiteralPath $logPath -Encoding UTF8
    Write-Error $_
    exit 1
}
