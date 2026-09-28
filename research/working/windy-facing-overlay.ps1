$ErrorActionPreference = 'Stop'
$logPath = Join-Path $PSScriptRoot 'windy-facing-overlay.log'

try {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $source = @'
using System;
using System.Drawing;
using System.Runtime.InteropServices;
using System.Windows.Forms;

public sealed class WindyFacingOverlay : Form
{
    [StructLayout(LayoutKind.Sequential)]
    private struct RECT
    {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct POINT
    {
        public int X;
        public int Y;
        public POINT(int x, int y) { X = x; Y = y; }
    }

    private const int WS_EX_TRANSPARENT = 0x00000020;
    private const int WS_EX_TOOLWINDOW = 0x00000080;
    private const int WS_EX_LAYERED = 0x00080000;
    private const int WS_EX_NOACTIVATE = 0x08000000;
    private const int VK_ESCAPE = 0x1B;
    private const int PS_SOLID = 0;
    private const int PS_DASH = 1;

    private readonly IntPtr _target;
    private readonly IntPtr _console;
    private readonly Timer _timer;

    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern IntPtr FindWindow(string className, string windowName);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool GetWindowRect(IntPtr hwnd, out RECT rect);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern IntPtr GetForegroundWindow();

    [DllImport("kernel32.dll")]
    private static extern IntPtr GetConsoleWindow();

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool IsIconic(IntPtr hwnd);

    [DllImport("user32.dll")]
    private static extern short GetAsyncKeyState(int virtualKey);

    [DllImport("gdi32.dll", SetLastError = true)]
    private static extern IntPtr CreatePen(int style, int width, uint colorRef);

    [DllImport("gdi32.dll", SetLastError = true)]
    private static extern IntPtr CreateSolidBrush(uint colorRef);

    [DllImport("gdi32.dll", SetLastError = true)]
    private static extern IntPtr SelectObject(IntPtr hdc, IntPtr obj);

    [DllImport("gdi32.dll", SetLastError = true)]
    private static extern bool DeleteObject(IntPtr obj);

    [DllImport("gdi32.dll", SetLastError = true)]
    private static extern bool Polyline(IntPtr hdc, [In] POINT[] points, int count);

    [DllImport("gdi32.dll", SetLastError = true)]
    private static extern bool Ellipse(IntPtr hdc, int left, int top, int right, int bottom);

    protected override bool ShowWithoutActivation { get { return true; } }

    protected override CreateParams CreateParams
    {
        get
        {
            CreateParams cp = base.CreateParams;
            cp.ExStyle |= WS_EX_LAYERED | WS_EX_TRANSPARENT | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE;
            return cp;
        }
    }

    public WindyFacingOverlay()
    {
        _target = FindWindow(null, "Windy: Wind map & weather forecast - Google Chrome");
        if (_target == IntPtr.Zero)
            throw new InvalidOperationException("The visible Windy Chrome window was not found.");

        _console = GetConsoleWindow();

        RECT initial;
        if (!GetWindowRect(_target, out initial))
            throw new InvalidOperationException("Could not read the Windy window bounds.");

        Bounds = Rectangle.FromLTRB(initial.Left, initial.Top, initial.Right, initial.Bottom);
        FormBorderStyle = FormBorderStyle.None;
        ShowInTaskbar = false;
        TopMost = true;
        Text = "Windy facing overlay";
        BackColor = Color.Magenta;
        TransparencyKey = Color.Magenta;
        StartPosition = FormStartPosition.Manual;
        DoubleBuffered = true;

        _timer = new Timer();
        _timer.Interval = 120;
        _timer.Tick += UpdateOverlay;
        _timer.Start();
    }

    private void UpdateOverlay(object sender, EventArgs e)
    {
        if ((GetAsyncKeyState(VK_ESCAPE) & 0x8000) != 0)
        {
            Close();
            return;
        }

        IntPtr foreground = GetForegroundWindow();
        if ((foreground != _target && foreground != _console) || IsIconic(_target))
        {
            if (Visible) Hide();
            return;
        }

        RECT current;
        if (!GetWindowRect(_target, out current)) return;

        Rectangle next = Rectangle.FromLTRB(current.Left, current.Top, current.Right, current.Bottom);
        if (Bounds != next) Bounds = next;
        if (!Visible) Show();
        Invalidate();
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        int cx = (int)(Width * 0.482);
        int cy = (int)(Height * 0.501);
        int lx = (int)(Width * 0.580);
        int ly = (int)(Height * 0.360);

        double dx = lx - cx;
        double dy = ly - cy;
        double length = Math.Sqrt(dx * dx + dy * dy);
        double ux = dx / length;
        double uy = dy / length;
        double px = -uy;
        double py = ux;

        POINT[] baseLine = new POINT[] {
            new POINT((int)(cx + px * 28), (int)(cy + py * 28)),
            new POINT((int)(cx - px * 28), (int)(cy - py * 28))
        };
        POINT[] landwardTriangle = new POINT[] {
            baseLine[0], baseLine[1],
            new POINT((int)(cx + ux * 78), (int)(cy + uy * 78)),
            baseLine[0]
        };
        POINT[] seawardTriangle = new POINT[] {
            baseLine[0], baseLine[1],
            new POINT((int)(cx - ux * 78), (int)(cy - uy * 78)),
            baseLine[0]
        };

        int t1x = (int)(cx + ux * 26);
        int t1y = (int)(cy + uy * 26);
        int t2x = (int)(cx - ux * 26);
        int t2y = (int)(cy - uy * 26);

        IntPtr hdc = e.Graphics.GetHdc();
        try
        {
            DrawPolyline(hdc, landwardTriangle, Color.Cyan, 3, PS_SOLID);
            DrawPolyline(hdc, seawardTriangle, Color.Cyan, 3, PS_SOLID);
            DrawPolyline(hdc, new POINT[] { new POINT(t2x, t2y), new POINT(t1x, t1y) }, Color.White, 2, PS_DASH);
            DrawPolyline(hdc, new POINT[] { new POINT(cx, cy), new POINT(lx, ly) }, Color.Gold, 4, PS_SOLID);

            double angle = Math.Atan2(dy, dx);
            double headLength = 20.0;
            DrawPolyline(hdc, new POINT[] {
                new POINT(lx, ly),
                new POINT(lx - (int)(headLength * Math.Cos(angle - Math.PI / 6)), ly - (int)(headLength * Math.Sin(angle - Math.PI / 6)))
            }, Color.Gold, 4, PS_SOLID);
            DrawPolyline(hdc, new POINT[] {
                new POINT(lx, ly),
                new POINT(lx - (int)(headLength * Math.Cos(angle + Math.PI / 6)), ly - (int)(headLength * Math.Sin(angle + Math.PI / 6)))
            }, Color.Gold, 4, PS_SOLID);

            DrawCircle(hdc, t1x, t1y, 7, Color.Cyan);
            DrawCircle(hdc, t2x, t2y, 7, Color.Cyan);
            DrawCircle(hdc, cx, cy, 8, Color.White);
            DrawCircle(hdc, lx, ly, 8, Color.Gold);
        }
        finally
        {
            e.Graphics.ReleaseHdc(hdc);
        }

        using (Font font = new Font("Segoe UI", 12, FontStyle.Bold))
        {
            string caption = "Two-lobe centroid axis (schematic)  |  nearest visible land: NE  |  not a track forecast  |  Esc closes";
            e.Graphics.DrawString(caption, font, Brushes.Black, 432, 111);
            e.Graphics.DrawString(caption, font, Brushes.Yellow, 430, 109);
            e.Graphics.DrawString("T1", font, Brushes.Black, t1x + 8, t1y - 18);
            e.Graphics.DrawString("T1", font, Brushes.Cyan, t1x + 7, t1y - 19);
            e.Graphics.DrawString("T2", font, Brushes.Black, t2x + 8, t2y - 18);
            e.Graphics.DrawString("T2", font, Brushes.Cyan, t2x + 7, t2y - 19);
            e.Graphics.DrawString("nearest Baja coast (visual estimate)", font, Brushes.Black, lx + 12, ly + 9);
            e.Graphics.DrawString("nearest Baja coast (visual estimate)", font, Brushes.Gold, lx + 11, ly + 8);
        }
    }

    private static uint ColorRef(Color c)
    {
        return (uint)(c.R | (c.G << 8) | (c.B << 16));
    }

    private static void DrawPolyline(IntPtr hdc, POINT[] points, Color color, int width, int style)
    {
        IntPtr pen = CreatePen(style, width, ColorRef(color));
        IntPtr old = SelectObject(hdc, pen);
        try { Polyline(hdc, points, points.Length); }
        finally { SelectObject(hdc, old); DeleteObject(pen); }
    }

    private static void DrawCircle(IntPtr hdc, int x, int y, int radius, Color color)
    {
        IntPtr pen = CreatePen(PS_SOLID, 2, ColorRef(color));
        IntPtr brush = CreateSolidBrush(ColorRef(color));
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

    public static void Run()
    {
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);
        Application.Run(new WindyFacingOverlay());
    }
}
'@

    $references = @(
        [System.Windows.Forms.Form].Assembly.Location
        [System.Drawing.Graphics].Assembly.Location
        [System.Drawing.Color].Assembly.Location
        [System.ComponentModel.Component].Assembly.Location
        (Join-Path (Split-Path -Parent [System.Windows.Forms.Form].Assembly.Location) 'System.Private.Windows.Core.dll')
    ) | Sort-Object -Unique
    Add-Type -TypeDefinition $source -ReferencedAssemblies $references
    try {
        $Host.UI.RawUI.WindowTitle = 'Windy facing overlay - press Esc to close'
        $Host.UI.RawUI.BufferSize = [System.Management.Automation.Host.Size]::new(64, 8)
        $Host.UI.RawUI.WindowSize = [System.Management.Automation.Host.Size]::new(64, 8)
    } catch { }
    Write-Host 'Windy overlay is running as your user.' -ForegroundColor Cyan
    Write-Host 'Bring Chrome forward to see the marks. Press Esc to close.' -ForegroundColor Yellow
    [WindyFacingOverlay]::Run()
}
catch {
    $_ | Out-String | Set-Content -LiteralPath $logPath -Encoding UTF8
    exit 1
}
