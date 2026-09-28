<#
.SYNOPSIS
Draws TOOLANG, a source-labeled storm compass and ruler over Windy's visible Chrome map.

.DESCRIPTION
Weather maps bring several kinds of evidence into one view. TOOLANG keeps the
current NHC motion, forecast track and cone, wind radii, probability grids, and
nearest-coast geometry visually distinct so that one mark cannot quietly speak
for another. The Natural Earth land file validates the gold inland point; that
point describes nearby geography, not a predicted landfall.

PowerShell is the steward of inputs and scheduled work. Inline C# owns the
click-through Win32 window and its GDI drawing. Static marks rest in a cached
bitmap until map state or display scale changes. The window thread waits for a
Windows paint message; zoom changes ring that bell and wake it for a full redraw.
The fleur worker advances cached frames and asks for only its own small patch to
be repainted. It does not draw through a GDI context owned by another thread.

The map center and zoom come from the supplied URL and, when Windows UI
Automation is available, the visible Windy Chrome address bar. TOOLANG also
uses the visible page's accessible Map bounds so tracker panels can shift the
geographic projection without shifting the whole overlay window.
Weather values come from NHC's active-storm feed and linked GIS products. The
script does not infer numeric data from Windy's rendered colors, capture the
screen, inject JavaScript, or inspect hidden page content.

.PARAMETER StormName
Active NHC storm name or identifier to follow. The default is Polo.

.PARAMETER WindyUrl
Starting Windy map URL. Its latitude, longitude, and zoom establish the initial
projection until a newer address-bar value is read.

.PARAMETER NHCRefreshSeconds
Seconds between NHC refreshes (15 through 3600). A slower advisory cadence keeps
network work proportional to the source's changing forecast products.

.PARAMETER MapRefreshSeconds
Seconds between visible address-bar checks (1 through 30). The short check lets
the ruler follow zoom and panning without asking the drawing thread to poll.

.EXAMPLE
pwsh -NoProfile -File .\TOOLANG.ps1 -StormName Polo -WindyUrl 'https://www.windy.com/?21.584,-113.955,7'

.NOTES
Requires PowerShell 7 Core on Windows, a visible Windy Chrome window, access to
the NHC HTTPS products, and data\ne_10m_land.shp beside this script. Press
Ctrl+Shift+F12 or Ctrl+C in the PowerShell window to stop the overlay.

The geometric bowtie, map-north compass, and nearest-land marker are visual aids;
none predicts storm motion, landfall, or impact. A map seam is a rendering edge,
not an edge of the Earth.
#>
#requires -Version 7.0
#requires -PSEdition Core

[CmdletBinding()]
param(
    [string]$StormName = 'Polo',
    [string]$WindyUrl = 'https://www.windy.com/?21.584,-113.955,7',
    [ValidateRange(15, 3600)]
    [int]$NHCRefreshSeconds = 300,
    [ValidateRange(1, 30)]
    [int]$MapRefreshSeconds = 2
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# The coastline check is local and repeatable: keep the source polygons beside
# the script so the gold marker can be tested against land rather than guessed
# from a map color or a hand-placed screen pixel.
$landPath = Join-Path $PSScriptRoot 'data\ne_10m_land.shp'
if (-not (Test-Path -LiteralPath $landPath -PathType Leaf)) {
    throw "Natural Earth land polygons were not found at '$landPath'. Keep the data folder beside this script."
}
$script:NhcKmlCache = [ordered]@{}
$script:NhcProductSignature = ''

# Native drawing belongs in C# because Win32 window ownership and GDI handles
# need one clear lifetime. PowerShell remains the conductor for feeds and work.
$source = @'
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text.RegularExpressions;
using System.Threading;
using System.Xml;
using System.Xml.Linq;

// These small records preserve the meanings of the inputs while they cross the
// boundary from feeds and GIS into rendering. Geometry is never inferred from
// the colors of the underlying weather tiles.
public sealed class WindyLandPoint
{
    public double CoastLatitude;
    public double CoastLongitude;
    public double LandLatitude;
    public double LandLongitude;
    public double CoastDistanceKm;
    public double InlandDistanceKm;
}

internal sealed class WindyGeoPoint
{
    public double Latitude;
    public double Longitude;
}

internal sealed class WindyGeoPath
{
    public string Kind = "";
    public string Label = "";
    public List<WindyGeoPoint> Points = new List<WindyGeoPoint>();
}

internal sealed class WindyForecastPosition
{
    public double Latitude;
    public double Longitude;
    public int ForecastHours;
    public double MaxWindKnots;
}

internal sealed class WindyProbabilityBand
{
    public string Label = "";
    public List<List<WindyGeoPoint>> Polygons = new List<List<WindyGeoPoint>>();
}

internal sealed class WindyLandRecord
{
    public double MinLon, MinLat, MaxLon, MaxLat;
    public List<double[]> Rings = new List<double[]>();
}

internal sealed class WindyOverlayState
{
    public string StormName = "";
    public string Classification = "";
    public string Advisory = "";
    public string AdvisoryUrl = "";
    public string ValidTimeUtc = "";
    public double StormLatitude;
    public double StormLongitude;
    public double MotionBearing;
    public double MotionSpeedMph;
    public double MaxWindKnots;
    public double PressureMb;
    public double MapLatitude;
    public double MapLongitude;
    public double MapZoom;
    public double MapViewportLeft;
    public double MapViewportTop;
    public double MapViewportWidth = 1.0;
    public double MapViewportHeight = 1.0;
    public WindyLandPoint Land = new WindyLandPoint();
    public List<WindyGeoPath> ForecastPaths = new List<WindyGeoPath>();
    public List<WindyForecastPosition> ForecastPositions = new List<WindyForecastPosition>();
    public List<WindyGeoPath> ConePaths = new List<WindyGeoPath>();
    public List<WindyGeoPath> WindRadiusPaths = new List<WindyGeoPath>();
    public List<WindyProbabilityBand> Probability34 = new List<WindyProbabilityBand>();
    public List<WindyProbabilityBand> Probability50 = new List<WindyProbabilityBand>();
    public List<WindyProbabilityBand> Probability64 = new List<WindyProbabilityBand>();
    public string ProbabilityValidTimeUtc = "";
    public int ProbabilityLinkedStormCount;
    public string ProductStatus = "NHC GIS products not loaded";

    public WindyOverlayState Copy()
    {
        return new WindyOverlayState {
            StormName = StormName,
            Classification = Classification,
            Advisory = Advisory,
            AdvisoryUrl = AdvisoryUrl,
            ValidTimeUtc = ValidTimeUtc,
            StormLatitude = StormLatitude,
            StormLongitude = StormLongitude,
            MotionBearing = MotionBearing,
            MotionSpeedMph = MotionSpeedMph,
            MaxWindKnots = MaxWindKnots,
            PressureMb = PressureMb,
            MapLatitude = MapLatitude,
            MapLongitude = MapLongitude,
            MapZoom = MapZoom,
            MapViewportLeft = MapViewportLeft,
            MapViewportTop = MapViewportTop,
            MapViewportWidth = MapViewportWidth,
            MapViewportHeight = MapViewportHeight,
            Land = Land,
            ForecastPaths = ForecastPaths,
            ForecastPositions = ForecastPositions,
            ConePaths = ConePaths,
            WindRadiusPaths = WindRadiusPaths,
            Probability34 = Probability34,
            Probability50 = Probability50,
            Probability64 = Probability64,
            ProbabilityValidTimeUtc = ProbabilityValidTimeUtc,
            ProbabilityLinkedStormCount = ProbabilityLinkedStormCount,
            ProductStatus = ProductStatus
        };
    }
}

internal sealed class WindyRectangle
{
    public int Left, Top, Right, Bottom;
}

internal sealed class WindyLandMask
{
    // A local Natural Earth polygon test gives the marker coordinates that can
    // be checked numerically; it keeps a nearest-coast estimate from becoming
    // a decorative dot floating in open water.
    private const double EarthRadiusKm = 6371.0088;
    private readonly List<WindyLandRecord> _records = new List<WindyLandRecord>();

    private WindyLandMask(string path) { LoadShapefile(path); }

    public static WindyLandMask Load(string path) { return new WindyLandMask(path); }

    private static int ReadInt32BigEndian(byte[] bytes, int offset)
    {
        return (bytes[offset] << 24) | (bytes[offset + 1] << 16) |
               (bytes[offset + 2] << 8) | bytes[offset + 3];
    }

    private static int ReadInt32LittleEndian(byte[] bytes, int offset)
    {
        return BitConverter.ToInt32(bytes, offset);
    }

    private static double ReadDoubleLittleEndian(byte[] bytes, int offset)
    {
        return BitConverter.ToDouble(bytes, offset);
    }

    private void LoadShapefile(string path)
    {
        byte[] bytes = File.ReadAllBytes(path);
        if (bytes.Length < 100 || ReadInt32BigEndian(bytes, 0) != 9994)
            throw new InvalidDataException("The Natural Earth .shp file has an invalid shapefile header.");
        int fileShapeType = ReadInt32LittleEndian(bytes, 32);
        if (fileShapeType != 5)
            throw new InvalidDataException("Expected a Polygon shapefile (shape type 5).");

        int offset = 100;
        while (offset + 8 <= bytes.Length)
        {
            int words = ReadInt32BigEndian(bytes, offset + 4);
            int length = checked(words * 2);
            int content = offset + 8;
            if (length < 4 || content + length > bytes.Length)
                throw new InvalidDataException("The Natural Earth shapefile contains a truncated record.");

            int shapeType = ReadInt32LittleEndian(bytes, content);
            if (shapeType == 5)
            {
                int p = content + 4;
                var record = new WindyLandRecord();
                record.MinLon = ReadDoubleLittleEndian(bytes, p); p += 8;
                record.MinLat = ReadDoubleLittleEndian(bytes, p); p += 8;
                record.MaxLon = ReadDoubleLittleEndian(bytes, p); p += 8;
                record.MaxLat = ReadDoubleLittleEndian(bytes, p); p += 8;
                int partCount = ReadInt32LittleEndian(bytes, p); p += 4;
                int pointCount = ReadInt32LittleEndian(bytes, p); p += 4;
                if (partCount <= 0 || pointCount < 4 || partCount > pointCount)
                {
                    offset = content + length;
                    continue;
                }

                int[] starts = new int[partCount + 1];
                for (int i = 0; i < partCount; i++)
                {
                    starts[i] = ReadInt32LittleEndian(bytes, p);
                    p += 4;
                }
                starts[partCount] = pointCount;
                int pointStart = p;
                int pointBytes = checked(pointCount * 16);
                if (pointStart + pointBytes > content + length)
                    throw new InvalidDataException("A Natural Earth polygon record is incomplete.");

                for (int i = 0; i < partCount; i++)
                {
                    int n = starts[i + 1] - starts[i];
                    if (n < 4) continue;
                    double[] ring = new double[n * 2];
                    for (int j = 0; j < n; j++)
                    {
                        int at = pointStart + (starts[i] + j) * 16;
                        ring[j * 2] = ReadDoubleLittleEndian(bytes, at);
                        ring[j * 2 + 1] = ReadDoubleLittleEndian(bytes, at + 8);
                    }
                    record.Rings.Add(ring);
                }
                if (record.Rings.Count > 0) _records.Add(record);
            }
            else if (shapeType != 0)
            {
                throw new InvalidDataException("Encountered a non-Polygon record in the Natural Earth shapefile.");
            }
            offset = content + length;
        }

        if (_records.Count == 0)
            throw new InvalidDataException("The Natural Earth shapefile contained no land polygons.");
    }

    private static bool OnSegment(double x, double y, double ax, double ay, double bx, double by)
    {
        double lengthSquared = (bx - ax) * (bx - ax) + (by - ay) * (by - ay);
        if (lengthSquared < 1e-24)
            return Math.Abs(x - ax) <= 1e-10 && Math.Abs(y - ay) <= 1e-10;
        double cross = (x - ax) * (by - ay) - (y - ay) * (bx - ax);
        if (Math.Abs(cross) > 1e-10) return false;
        double dot = (x - ax) * (bx - ax) + (y - ay) * (by - ay);
        if (dot < 0) return false;
        return dot <= lengthSquared;
    }

    private static bool RecordContains(WindyLandRecord record, double lon, double lat)
    {
        if (lon < record.MinLon - 1e-9 || lon > record.MaxLon + 1e-9 ||
            lat < record.MinLat - 1e-9 || lat > record.MaxLat + 1e-9) return false;

        bool inside = false;
        for (int r = 0; r < record.Rings.Count; r++)
        {
            double[] ring = record.Rings[r];
            int n = ring.Length / 2;
            for (int i = 0, j = n - 1; i < n; j = i++)
            {
                double xi = ring[i * 2], yi = ring[i * 2 + 1];
                double xj = ring[j * 2], yj = ring[j * 2 + 1];
                if (OnSegment(lon, lat, xi, yi, xj, yj)) return true;
                bool crosses = ((yi > lat) != (yj > lat)) &&
                    (lon < (xj - xi) * (lat - yi) / (yj - yi) + xi);
                if (crosses) inside = !inside;
            }
        }
        return inside;
    }

    private bool IsLand(double lon, double lat)
    {
        for (int i = 0; i < _records.Count; i++)
            if (RecordContains(_records[i], lon, lat)) return true;
        return false;
    }

    private static double NormalizeLongitude(double lon)
    {
        while (lon > 180) lon -= 360;
        while (lon < -180) lon += 360;
        return lon;
    }

    private static void ToLocal(double stormLat, double stormLon, double lon, double lat,
        double cosLat, out double xKm, out double yKm)
    {
        double dLon = NormalizeLongitude(lon - stormLon) * Math.PI / 180.0;
        double dLat = (lat - stormLat) * Math.PI / 180.0;
        xKm = EarthRadiusKm * dLon * cosLat;
        yKm = EarthRadiusKm * dLat;
    }

    // First find the nearest polygon edge, then walk inland and require the
    // candidate itself to pass the same land test. The result is geometry only,
    // not a statement about where the storm will travel.
    public WindyLandPoint FindNearestLand(double stormLat, double stormLon, double maxSearchKm)
    {
        if (IsLand(stormLon, stormLat))
            throw new InvalidOperationException("The NHC storm center falls on Natural Earth land polygons; nearest water-to-land coast is undefined.");

        double cosLat = Math.Cos(stormLat * Math.PI / 180.0);
        if (Math.Abs(cosLat) < 0.05) cosLat = 0.05;
        double bestDistance = maxSearchKm;
        double bestX = 0, bestY = 0;
        bool found = false;

        for (int r = 0; r < _records.Count; r++)
        {
            WindyLandRecord record = _records[r];
            double centerLon = (record.MinLon + record.MaxLon) * 0.5;
            double centerLat = (record.MinLat + record.MaxLat) * 0.5;
            double bx, by;
            ToLocal(stormLat, stormLon, centerLon, centerLat, cosLat, out bx, out by);
            double rough = Math.Sqrt(bx * bx + by * by);
            // Keep the raw extent here. Normalizing a wide or antimeridian-
            // crossing record can make its bounding radius too small and
            // incorrectly prune land that is actually close to the storm.
            double halfWidth = Math.Abs(record.MaxLon - record.MinLon) * Math.PI / 180.0 * EarthRadiusKm * cosLat * 0.5;
            double halfHeight = Math.Abs(record.MaxLat - record.MinLat) * Math.PI / 180.0 * EarthRadiusKm * 0.5;
            if (rough - Math.Sqrt(halfWidth * halfWidth + halfHeight * halfHeight) > bestDistance + 5) continue;

            for (int k = 0; k < record.Rings.Count; k++)
            {
                double[] ring = record.Rings[k];
                int n = ring.Length / 2;
                for (int i = 0, j = n - 1; i < n; j = i++)
                {
                    double ax, ay, bx2, by2;
                    ToLocal(stormLat, stormLon, ring[j * 2], ring[j * 2 + 1], cosLat, out ax, out ay);
                    ToLocal(stormLat, stormLon, ring[i * 2], ring[i * 2 + 1], cosLat, out bx2, out by2);
                    double dx = bx2 - ax, dy = by2 - ay;
                    double denom = dx * dx + dy * dy;
                    double t = denom < 1e-12 ? 0 : -(ax * dx + ay * dy) / denom;
                    if (t < 0) t = 0; else if (t > 1) t = 1;
                    double qx = ax + t * dx, qy = ay + t * dy;
                    double distance = Math.Sqrt(qx * qx + qy * qy);
                    if (distance < bestDistance)
                    {
                        bestDistance = distance;
                        bestX = qx;
                        bestY = qy;
                        found = true;
                    }
                }
            }
        }

        if (!found || bestDistance <= 0.05)
            throw new InvalidOperationException("No usable coastline was found within the configured 3000 km search radius.");

        double coastLat = stormLat + bestY / EarthRadiusKm * 180.0 / Math.PI;
        double coastLon = NormalizeLongitude(stormLon + bestX / (EarthRadiusKm * cosLat) * 180.0 / Math.PI);
        double ux = bestX / bestDistance, uy = bestY / bestDistance;
        double landLat = double.NaN, landLon = double.NaN, inland = 0;

        // Prefer a point 10 km inland, then choose the first verified land
        // point along the nearest-coast normal if local geography is narrow.
        double testX = bestX + ux * 10.0;
        double testY = bestY + uy * 10.0;
        landLon = NormalizeLongitude(stormLon + testX / (EarthRadiusKm * cosLat) * 180.0 / Math.PI);
        landLat = stormLat + testY / EarthRadiusKm * 180.0 / Math.PI;
        if (IsLand(landLon, landLat)) inland = 10.0;
        else
        {
            bool landFound = false;
            for (double d = 1.0; d <= 50.0; d += 1.0)
            {
                testX = bestX + ux * d;
                testY = bestY + uy * d;
                double candidateLon = NormalizeLongitude(stormLon + testX / (EarthRadiusKm * cosLat) * 180.0 / Math.PI);
                double candidateLat = stormLat + testY / EarthRadiusKm * 180.0 / Math.PI;
                if (IsLand(candidateLon, candidateLat))
                {
                    landLon = candidateLon;
                    landLat = candidateLat;
                    inland = d;
                    landFound = true;
                    break;
                }
            }
            if (!landFound)
                throw new InvalidOperationException("The nearest coast was found, but no inland validation point was found within 50 km. No gold marker was drawn.");
        }

        return new WindyLandPoint {
            CoastLatitude = coastLat,
            CoastLongitude = coastLon,
            LandLatitude = landLat,
            LandLongitude = landLon,
            CoastDistanceKm = bestDistance,
            InlandDistanceKm = inland
        };
    }
}

// One owner for the native window, cached GDI surfaces, and paint lifecycle.
// Worker threads publish state or request invalidation; only the window thread
// uses its paint DC. This boundary is the reason the static layer can nap safely.
public static class WindyHurricaneOverlay
{
    private const int PMv2 = -4;
    private const uint WS_POPUP = 0x80000000;
    private const uint WS_EX_LAYERED = 0x00080000;
    private const uint WS_EX_TRANSPARENT = 0x00000020;
    private const uint WS_EX_TOOLWINDOW = 0x00000080;
    private const uint WS_EX_NOACTIVATE = 0x08000000;
    private const uint CS_HREDRAW = 0x0002;
    private const uint CS_VREDRAW = 0x0001;
    private const uint LWA_COLORKEY = 0x00000001;
    private const uint SWP_NOACTIVATE = 0x0010;
    private const uint SWP_NOZORDER = 0x0004;
    private const uint SWP_SHOWWINDOW = 0x0040;
    private const int SW_SHOWNOACTIVATE = 4;
    private const int SW_HIDE = 0;
    private const uint WM_PAINT = 0x000F;
    private const uint WM_ERASEBKGND = 0x0014;
    private const uint WM_DESTROY = 0x0002;
    private const uint WM_CLOSE = 0x0010;
    private const uint WM_HOTKEY = 0x0312;
    private const uint WM_QUIT = 0x0012;
    private const uint EVENT_SYSTEM_FOREGROUND = 0x0003;
    private const uint EVENT_OBJECT_DESTROY = 0x8001;
    private const uint EVENT_OBJECT_SHOW = 0x8002;
    private const uint EVENT_OBJECT_HIDE = 0x8003;
    private const uint EVENT_OBJECT_LOCATIONCHANGE = 0x800B;
    private const uint EVENT_OBJECT_NAMECHANGE = 0x800C;
    private const uint WINEVENT_OUTOFCONTEXT = 0x0000;
    private const uint WINEVENT_SKIPOWNPROCESS = 0x0002;
    private const int OBJID_WINDOW = 0;
    private const int OBJID_CLIENT = -4;
    private const uint MOD_CONTROL = 0x0002;
    private const uint MOD_SHIFT = 0x0004;
    private const uint MOD_NOREPEAT = 0x4000;
    private const uint VK_F12 = 0x7B;
    private const int TRANSPARENT_BK = 1;
    private const int PS_SOLID = 0;
    private const int PS_DASH = 1;
    private const int HOLLOW_BRUSH = 5;
    private const uint TRANSPARENT_KEY = 0x00FF00FF;
    private const int GWLP_HWNDPARENT = -8;
    private const string ClassName = "WindyHurricaneOverlay.Native.2026";

    // StateLock protects weather/map snapshots; FleurLayoutLock protects the
    // tiny handoff between static-layout creation and the sprite clock.
    private static readonly object StateLock = new object();
    private static readonly object FleurLayoutLock = new object();
    private static readonly ManualResetEventSlim Stopped = new ManualResetEventSlim(true);
    private static readonly Stopwatch CompassAnimationClock = Stopwatch.StartNew();
    private sealed class FleurSprite
    {
        public IntPtr Dc;
        public IntPtr Bitmap;
        public IntPtr PreviousBitmap;
        public int Width;
        public int Center;
    }
    private sealed class FleurLayout
    {
        public int X, Y;
        public double Scale;
        public int Unit, LineWidth, Half;
        public bool Visible;
    }
    private static readonly Dictionary<int, FleurSprite> FleurSpriteCache = new Dictionary<int, FleurSprite>();
    private static int FleurSpriteCacheKey = Int32.MinValue;
    private static readonly WndProcDelegate Proc = WindowProc;
    private static readonly WinEventDelegate WinEventProc = HandleWinEvent;
    private static readonly EnumWindowsDelegate TopEnumProc = TopWindowCallback;
    private static readonly EnumChildWindowsDelegate ChildEnumProc = ChildWindowCallback;
    private static WindyOverlayState State = new WindyOverlayState();
    private static WindyLandMask LandMask;
    private static string LandPath = "";
    private static Thread OverlayThread;
    private static Thread SpriteThread;
    private static volatile string LastError = "";
    private static volatile bool Running;
    private static volatile bool SpriteThreadRunning;
    private static int SpriteAngleDegrees;
    private static int StaticLayerDirty = 1;
    private static long StaticLayerBuildCount;
    private static long MapScaleWakeCount;
    private static long ViewportScaleWakeCount;
    private static long SpriteFrameChangeCount;
    private static long SpriteFramePaintCount;
    private static long PaintMessageCount;
    private static readonly FleurLayout CurrentFleurLayout = new FleurLayout();
    private static IntPtr StaticLayerDc;
    private static IntPtr StaticLayerBitmap;
    private static IntPtr StaticLayerPreviousBitmap;
    private static int StaticLayerWidth;
    private static int StaticLayerHeight;
    private static IntPtr WindowHandle;
    private static IntPtr ParentWindowHandle;
    private static IntPtr RendererHandle;
    private static IntPtr InstanceHandle;
    private static WindyRectangle LastBounds;
    private static uint LastParentDpi;
    private static IntPtr ForegroundEventHook;
    private static IntPtr LocationEventHook;
    private static IntPtr VisibilityEventHook;
    private static IntPtr NameEventHook;
    private static IntPtr DestroyEventHook;
    private static bool HotKeyRegistered;

    [StructLayout(LayoutKind.Sequential)]
    private struct RECT { public int Left, Top, Right, Bottom; }

    [StructLayout(LayoutKind.Sequential)]
    private struct POINT { public int X, Y; public POINT(int x, int y) { X = x; Y = y; } }

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
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 32)] public byte[] rgbReserved;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
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
    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    private delegate void WinEventDelegate(IntPtr hook, uint eventType, IntPtr hwnd,
        int idObject, int idChild, uint eventThread, uint eventTime);
    private delegate bool EnumWindowsDelegate(IntPtr hwnd, IntPtr data);
    private delegate bool EnumChildWindowsDelegate(IntPtr hwnd, IntPtr data);

    // Win32 declarations stay together so it is clear which API owns each step:
    // User32 manages visibility and messages; GDI owns the reusable drawing surfaces.
    [DllImport("user32.dll", SetLastError = true)] private static extern bool SetProcessDpiAwarenessContext(IntPtr context);
    [DllImport("user32.dll", SetLastError = true)] private static extern bool EnumWindows(EnumWindowsDelegate callback, IntPtr data);
    [DllImport("user32.dll", SetLastError = true)] private static extern bool EnumChildWindows(IntPtr parent, EnumChildWindowsDelegate callback, IntPtr data);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] private static extern int GetWindowTextW(IntPtr hwnd, System.Text.StringBuilder text, int maxCount);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] private static extern int GetClassNameW(IntPtr hwnd, System.Text.StringBuilder text, int maxCount);
    [DllImport("user32.dll")] private static extern bool IsWindowVisible(IntPtr hwnd);
    [DllImport("user32.dll")] private static extern bool IsIconic(IntPtr hwnd);
    [DllImport("user32.dll")] private static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint processId);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)] private static extern IntPtr GetModuleHandleW(string moduleName);
    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)] private static extern ushort RegisterClassExW(ref WNDCLASSEX wc);
    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)] private static extern IntPtr CreateWindowExW(uint exStyle, string className, string windowName, uint style, int x, int y, int width, int height, IntPtr parent, IntPtr menu, IntPtr instance, IntPtr param);
    [DllImport("user32.dll", SetLastError = true)] private static extern bool SetLayeredWindowAttributes(IntPtr hwnd, uint colorKey, byte alpha, uint flags);
    [DllImport("user32.dll", SetLastError = true)] private static extern bool RegisterHotKey(IntPtr hwnd, int id, uint modifiers, uint key);
    [DllImport("user32.dll")] private static extern bool UnregisterHotKey(IntPtr hwnd, int id);
    [DllImport("user32.dll", SetLastError = true)] private static extern bool SetWindowPos(IntPtr hwnd, IntPtr after, int x, int y, int cx, int cy, uint flags);
    [DllImport("user32.dll", SetLastError = true)] private static extern IntPtr SetWinEventHook(uint eventMin, uint eventMax, IntPtr module, WinEventDelegate callback, uint processId, uint threadId, uint flags);
    [DllImport("user32.dll", SetLastError = true)] private static extern bool UnhookWinEvent(IntPtr hook);
    [DllImport("user32.dll")] private static extern bool ShowWindow(IntPtr hwnd, int command);
    [DllImport("user32.dll")] private static extern bool UpdateWindow(IntPtr hwnd);
    [DllImport("user32.dll")] private static extern int FillRect(IntPtr dc, ref RECT rect, IntPtr brush);
    [DllImport("user32.dll")] private static extern IntPtr BeginPaint(IntPtr hwnd, ref PAINTSTRUCT ps);
    [DllImport("user32.dll")] private static extern bool EndPaint(IntPtr hwnd, ref PAINTSTRUCT ps);
    [DllImport("user32.dll")] private static extern bool GetClientRect(IntPtr hwnd, out RECT rect);
    [DllImport("user32.dll")] private static extern int GetMessageW(out MSG msg, IntPtr hwnd, uint min, uint max);
    [DllImport("user32.dll")] private static extern bool TranslateMessage(ref MSG msg);
    [DllImport("user32.dll")] private static extern IntPtr DispatchMessageW(ref MSG msg);
    [DllImport("user32.dll")] private static extern IntPtr DefWindowProcW(IntPtr hwnd, uint msg, IntPtr wParam, IntPtr lParam);
    [DllImport("user32.dll")] private static extern bool DestroyWindow(IntPtr hwnd);
    [DllImport("user32.dll")] private static extern void PostQuitMessage(int exitCode);
    [DllImport("user32.dll")] private static extern bool PostMessageW(IntPtr hwnd, uint msg, IntPtr wParam, IntPtr lParam);
    [DllImport("user32.dll", EntryPoint = "InvalidateRect")] private static extern bool InvalidateClientRect(IntPtr hwnd, ref RECT rect, bool erase);
    [DllImport("user32.dll")] private static extern uint GetDpiForWindow(IntPtr hwnd);
    [DllImport("user32.dll", SetLastError = true)] private static extern IntPtr SetWindowLongPtrW(IntPtr hwnd, int index, IntPtr value);
    [DllImport("user32.dll", SetLastError = true)] private static extern IntPtr GetWindowLongPtrW(IntPtr hwnd, int index);

    [DllImport("gdi32.dll", SetLastError = true)] private static extern IntPtr CreateSolidBrush(uint color);
    [DllImport("gdi32.dll", SetLastError = true)] private static extern IntPtr CreatePen(int style, int width, uint color);
    [DllImport("gdi32.dll", SetLastError = true)] private static extern IntPtr CreateCompatibleDC(IntPtr dc);
    [DllImport("gdi32.dll", SetLastError = true)] private static extern IntPtr CreateCompatibleBitmap(IntPtr dc, int width, int height);
    [DllImport("gdi32.dll", SetLastError = true)] private static extern bool BitBlt(IntPtr destination, int x, int y, int width, int height, IntPtr source, int sourceX, int sourceY, uint rop);
    [DllImport("gdi32.dll")] private static extern IntPtr SelectObject(IntPtr dc, IntPtr obj);
    [DllImport("gdi32.dll")] private static extern bool DeleteObject(IntPtr obj);
    [DllImport("gdi32.dll")] private static extern bool DeleteDC(IntPtr dc);
    [DllImport("gdi32.dll")] private static extern bool MoveToEx(IntPtr dc, int x, int y, IntPtr oldPoint);
    [DllImport("gdi32.dll")] private static extern bool LineTo(IntPtr dc, int x, int y);
    [DllImport("gdi32.dll")] private static extern bool Ellipse(IntPtr dc, int left, int top, int right, int bottom);
    [DllImport("gdi32.dll")] private static extern bool Polygon(IntPtr dc, [In] POINT[] points, int count);
    [DllImport("gdi32.dll")] private static extern int SetBkMode(IntPtr dc, int mode);
    [DllImport("gdi32.dll")] private static extern uint SetTextColor(IntPtr dc, uint color);
    [DllImport("gdi32.dll", CharSet = CharSet.Unicode)] private static extern IntPtr CreateFontW(int height, int width, int escapement, int orientation, int weight, uint italic, uint underline, uint strikeOut, uint charSet, uint outPrecision, uint clipPrecision, uint quality, uint pitchAndFamily, string faceName);
    [DllImport("gdi32.dll", CharSet = CharSet.Unicode)] private static extern bool GetTextExtentPoint32W(IntPtr dc, string text, int count, out SIZE size);
    [DllImport("gdi32.dll", CharSet = CharSet.Unicode)] private static extern bool TextOutW(IntPtr dc, int x, int y, string text, int count);
    [DllImport("gdi32.dll")] private static extern bool RoundRect(IntPtr dc, int left, int top, int right, int bottom, int ellipseW, int ellipseH);
    [DllImport("gdi32.dll")] private static extern IntPtr GetStockObject(int index);
    [DllImport("msimg32.dll", SetLastError = true)] private static extern bool TransparentBlt(
        IntPtr destination, int x, int y, int width, int height,
        IntPtr source, int sourceX, int sourceY, int sourceWidth, int sourceHeight, uint transparentColor);

    public static bool IsRunning { get { return Running && !Stopped.IsSet; } }
    public static string LastFailure { get { return LastError; } }
    public static string RenderDiagnostics
    {
        get
        {
            WindyOverlayState state = Snapshot();
            return String.Format("static {0} | zoom wake {1} | size/DPI wake {2} | map center {7:P1} × {8:P1}{6}sprite frames {3} | sprite paints {4} | WM_PAINT {5}",
                Interlocked.Read(ref StaticLayerBuildCount), Interlocked.Read(ref MapScaleWakeCount),
                Interlocked.Read(ref ViewportScaleWakeCount), Interlocked.Read(ref SpriteFrameChangeCount),
                Interlocked.Read(ref SpriteFramePaintCount), Interlocked.Read(ref PaintMessageCount),
                Environment.NewLine,
                state.MapViewportLeft + state.MapViewportWidth / 2.0,
                state.MapViewportTop + state.MapViewportHeight / 2.0);
        }
    }

    // Attach to the visible Windy page surface, not whichever window happens to
    // be foreground. That lets the overlay follow the map without stealing focus.
    public static IntPtr FindWindyChromeWindow()
    {
        IntPtr foreground = GetForegroundWindow();
        List<IntPtr> matches = new List<IntPtr>();
        EnumWindows(delegate(IntPtr hwnd, IntPtr unused)
        {
            if (!IsWindowVisible(hwnd) || IsIconic(hwnd)) return true;
            string title = ReadWindowText(hwnd);
            if (title.IndexOf("Windy", StringComparison.OrdinalIgnoreCase) < 0) return true;
            if (ReadClassName(hwnd) != "Chrome_WidgetWin_1") return true;
            uint pid;
            GetWindowThreadProcessId(hwnd, out pid);
            try
            {
                using (Process p = Process.GetProcessById((int)pid))
                    if (!p.ProcessName.Equals("chrome", StringComparison.OrdinalIgnoreCase)) return true;
            }
            catch { return true; }
            matches.Add(hwnd);
            return true;
        }, IntPtr.Zero);
        for (int i = 0; i < matches.Count; i++)
            if (matches[i] == foreground) return foreground;
        return matches.Count > 0 ? matches[0] : IntPtr.Zero;
    }

    private static string ReadWindowText(IntPtr hwnd)
    {
        var text = new System.Text.StringBuilder(512);
        GetWindowTextW(hwnd, text, text.Capacity);
        return text.ToString();
    }

    private static string ReadClassName(IntPtr hwnd)
    {
        var text = new System.Text.StringBuilder(128);
        GetClassNameW(hwnd, text, text.Capacity);
        return text.ToString();
    }

    // Calculate land geometry before publishing one coherent storm snapshot. A
    // failed coastline validation therefore cannot leave half-new storm state
    // beside an old gold marker.
    public static WindyLandPoint ConfigureStorm(string landShapefile, string stormName,
        string classification, string advisory, string advisoryUrl, string validTimeUtc,
        double latitude, double longitude, double bearing, double speedMph,
        double maxWindKnots, double pressureMb)
    {
        if (LandMask == null || !String.Equals(LandPath, landShapefile, StringComparison.OrdinalIgnoreCase))
        {
            LandMask = WindyLandMask.Load(landShapefile);
            LandPath = landShapefile;
        }
        WindyLandPoint point = LandMask.FindNearestLand(latitude, longitude, 3000.0);
        bool changed;
        lock (StateLock)
        {
            changed =
                !String.Equals(State.StormName, stormName ?? "", StringComparison.Ordinal) ||
                !String.Equals(State.Classification, classification ?? "", StringComparison.Ordinal) ||
                !String.Equals(State.Advisory, advisory ?? "", StringComparison.Ordinal) ||
                !String.Equals(State.AdvisoryUrl, advisoryUrl ?? "", StringComparison.Ordinal) ||
                !String.Equals(State.ValidTimeUtc, validTimeUtc ?? "", StringComparison.Ordinal) ||
                State.StormLatitude != latitude || State.StormLongitude != longitude ||
                State.MotionBearing != bearing || State.MotionSpeedMph != speedMph ||
                State.MaxWindKnots != maxWindKnots || State.PressureMb != pressureMb ||
                State.Land.CoastLatitude != point.CoastLatitude ||
                State.Land.CoastLongitude != point.CoastLongitude ||
                State.Land.LandLatitude != point.LandLatitude ||
                State.Land.LandLongitude != point.LandLongitude ||
                State.Land.CoastDistanceKm != point.CoastDistanceKm ||
                State.Land.InlandDistanceKm != point.InlandDistanceKm;
            State.StormName = stormName ?? "";
            State.Classification = classification ?? "";
            State.Advisory = advisory ?? "";
            State.AdvisoryUrl = advisoryUrl ?? "";
            State.ValidTimeUtc = validTimeUtc ?? "";
            State.StormLatitude = latitude;
            State.StormLongitude = longitude;
            State.MotionBearing = bearing;
            State.MotionSpeedMph = speedMph;
            State.MaxWindKnots = maxWindKnots;
            State.PressureMb = pressureMb;
            State.Land = point;
        }
        if (changed) InvalidateOverlay();
        return point;
    }

    // The address bar is the scale contract. A changed center or zoom invalidates
    // the cached projection; InvalidateRect queues WM_PAINT so the waiting window
    // thread wakes only when new geometry needs to be drawn.
    public static void ConfigureMap(double centerLatitude, double centerLongitude, double zoom)
    {
        bool changed, zoomChanged;
        lock (StateLock)
        {
            zoomChanged = State.MapZoom != zoom;
            changed = State.MapLatitude != centerLatitude || State.MapLongitude != centerLongitude ||
                zoomChanged;
            State.MapLatitude = centerLatitude;
            State.MapLongitude = centerLongitude;
            State.MapZoom = zoom;
        }
        if (changed)
        {
            if (zoomChanged) Interlocked.Increment(ref MapScaleWakeCount);
            InvalidateOverlay();
        }
    }

    // Windy can slide its map canvas under a tracker pane while Chrome keeps the
    // same renderer rectangle. Store the accessible canvas as renderer-relative
    // fractions so geographic marks follow the map rather than the browser box.
    public static bool ConfigureMapViewport(double left, double top, double width, double height)
    {
        if (Double.IsNaN(left) || Double.IsInfinity(left) || left < -0.5 || left > 0.5 ||
            Double.IsNaN(top) || Double.IsInfinity(top) || top < -0.5 || top > 0.5 ||
            Double.IsNaN(width) || Double.IsInfinity(width) || width < 0.25 || width > 1.5 ||
            Double.IsNaN(height) || Double.IsInfinity(height) || height < 0.25 || height > 1.5)
            throw new ArgumentOutOfRangeException("map-viewport", "Visible map bounds must be finite and plausible relative to the Chrome renderer.");

        bool changed;
        lock (StateLock)
        {
            changed = Math.Abs(State.MapViewportLeft - left) > 0.0001 ||
                Math.Abs(State.MapViewportTop - top) > 0.0001 ||
                Math.Abs(State.MapViewportWidth - width) > 0.0001 ||
                Math.Abs(State.MapViewportHeight - height) > 0.0001;
            if (changed)
            {
                State.MapViewportLeft = left;
                State.MapViewportTop = top;
                State.MapViewportWidth = width;
                State.MapViewportHeight = height;
            }
        }
        if (changed)
        {
            Interlocked.Increment(ref ViewportScaleWakeCount);
            InvalidateOverlay();
        }
        return changed;
    }

    // Web Mercator shrinks east-west ground distance with latitude. Including
    // both cosine(latitude) and DPI is why the ruler remains meaningful across
    // map zoom levels and monitors instead of merely looking proportional.
    public static double MapMetersPerPixel(double latitude, double zoom, double dpiScale)
    {
        if (Double.IsNaN(latitude) || Double.IsInfinity(latitude) ||
            Double.IsNaN(zoom) || Double.IsInfinity(zoom) ||
            Double.IsNaN(dpiScale) || Double.IsInfinity(dpiScale) || dpiScale <= 0)
            throw new ArgumentOutOfRangeException("map-scale", "Latitude, zoom, and DPI scale must be finite; DPI scale must be positive.");
        latitude = Math.Max(-85.05112878, Math.Min(85.05112878, latitude));
        double circumference = 40075016.68557849;
        return Math.Cos(latitude * Math.PI / 180.0) * circumference /
            (256.0 * Math.Pow(2.0, zoom) * dpiScale);
    }

    // NHC publishes GIS as KML inside KMZ. Parse XML by local element names
    // because namespace prefixes vary; prohibiting DTDs keeps the parser focused
    // on the supplied geometry rather than external entities.
    private static XDocument ParseKml(string text)
    {
        if (String.IsNullOrWhiteSpace(text)) return null;
        XmlReaderSettings settings = new XmlReaderSettings();
        settings.DtdProcessing = DtdProcessing.Prohibit;
        settings.XmlResolver = null;
        settings.MaxCharactersInDocument = 50000000;
        using (StringReader input = new StringReader(text))
        using (XmlReader reader = XmlReader.Create(input, settings))
            return XDocument.Load(reader);
    }

    private static XElement FirstNamed(XContainer parent, string localName)
    {
        return parent == null ? null : parent.Descendants().FirstOrDefault(e => e.Name.LocalName == localName);
    }

    private static string DirectText(XElement parent, string localName)
    {
        XElement child = parent == null ? null : parent.Elements().FirstOrDefault(e => e.Name.LocalName == localName);
        return child == null ? "" : child.Value.Trim();
    }

    private static List<WindyGeoPoint> ParseCoordinates(XElement coordinates)
    {
        List<WindyGeoPoint> points = new List<WindyGeoPoint>();
        if (coordinates == null) return points;
        string[] tuples = coordinates.Value.Split((char[])null, StringSplitOptions.RemoveEmptyEntries);
        for (int i = 0; i < tuples.Length; i++)
        {
            string[] fields = tuples[i].Split(',');
            double lon, lat;
            if (fields.Length < 2 ||
                !Double.TryParse(fields[0], System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out lon) ||
                !Double.TryParse(fields[1], System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out lat) ||
                Double.IsNaN(lon) || Double.IsNaN(lat) || Double.IsInfinity(lon) || Double.IsInfinity(lat) ||
                lat < -90 || lat > 90 || lon < -540 || lon > 540) continue;
            points.Add(new WindyGeoPoint { Latitude = lat, Longitude = lon });
        }
        return points;
    }

    private static string DataValue(XElement placemark, string name)
    {
        if (placemark == null) return "";
        foreach (XElement data in placemark.Descendants().Where(e => e.Name.LocalName == "Data"))
        {
            XAttribute attribute = data.Attribute("name");
            if (attribute != null && String.Equals(attribute.Value, name, StringComparison.OrdinalIgnoreCase))
            {
                XElement value = data.Elements().FirstOrDefault(e => e.Name.LocalName == "value");
                return value == null ? "" : value.Value.Trim();
            }
        }
        return "";
    }

    private static List<WindyGeoPath> ParsePolygons(string kml, string kind, bool usePlacemarkName)
    {
        List<WindyGeoPath> paths = new List<WindyGeoPath>();
        XDocument document = ParseKml(kml);
        if (document == null) return paths;
        foreach (XElement placemark in document.Descendants().Where(e => e.Name.LocalName == "Placemark"))
        {
            string placemarkName = DirectText(placemark, "name");
            foreach (XElement polygon in placemark.Descendants().Where(e => e.Name.LocalName == "Polygon"))
            {
                XElement outer = polygon.Descendants().FirstOrDefault(e => e.Name.LocalName == "outerBoundaryIs");
                XElement coords = (outer ?? polygon).Descendants().FirstOrDefault(e => e.Name.LocalName == "coordinates");
                List<WindyGeoPoint> points = ParseCoordinates(coords);
                if (points.Count < 3) continue;
                paths.Add(new WindyGeoPath {
                    Kind = kind,
                    Label = usePlacemarkName && !String.IsNullOrWhiteSpace(placemarkName) ? placemarkName : kind,
                    Points = points
                });
            }
        }
        return paths;
    }

    // Probability products are geographic bands, not point predictions. Keep
    // each label attached to its polygon so a map-center sample can report the
    // source category, including boundary and out-of-grid cases.
    private static List<WindyProbabilityBand> ParseProbabilityKml(string kml)
    {
        List<WindyProbabilityBand> bands = new List<WindyProbabilityBand>();
        XDocument document = ParseKml(kml);
        if (document == null) return bands;
        Dictionary<string, WindyProbabilityBand> byLabel = new Dictionary<string, WindyProbabilityBand>(StringComparer.OrdinalIgnoreCase);
        foreach (XElement placemark in document.Descendants().Where(e => e.Name.LocalName == "Placemark"))
        {
            string label = DirectText(placemark, "name");
            if (String.IsNullOrWhiteSpace(label)) continue;
            label = label.Trim();
            if (!label.EndsWith("%", StringComparison.Ordinal)) label += "%";
            WindyProbabilityBand band;
            if (!byLabel.TryGetValue(label, out band))
            {
                band = new WindyProbabilityBand { Label = label };
                byLabel.Add(label, band);
                bands.Add(band);
            }
            foreach (XElement polygon in placemark.Descendants().Where(e => e.Name.LocalName == "Polygon"))
            {
                XElement outer = polygon.Descendants().FirstOrDefault(e => e.Name.LocalName == "outerBoundaryIs");
                XElement coords = (outer ?? polygon).Descendants().FirstOrDefault(e => e.Name.LocalName == "coordinates");
                List<WindyGeoPoint> points = ParseCoordinates(coords);
                if (points.Count >= 3) band.Polygons.Add(points);
            }
        }
        return bands;
    }

    // Forecast positions and the connecting path are stored separately: points
    // carry forecast times, while the connector is only a visual link between them.
    private static void ParseForecastTrack(string kml, out List<WindyGeoPath> paths,
        out List<WindyForecastPosition> positions)
    {
        paths = new List<WindyGeoPath>();
        positions = new List<WindyForecastPosition>();
        XDocument document = ParseKml(kml);
        if (document == null) return;
        WindyGeoPath longestTrack = null;
        foreach (XElement placemark in document.Descendants().Where(e => e.Name.LocalName == "Placemark"))
        {
            XElement line = placemark.Descendants().FirstOrDefault(e => e.Name.LocalName == "LineString");
            if (line != null)
            {
                List<WindyGeoPoint> points = ParseCoordinates(FirstNamed(line, "coordinates"));
                if (points.Count >= 2 && (longestTrack == null || points.Count > longestTrack.Points.Count))
                    longestTrack = new WindyGeoPath { Kind = "forecast-track", Label = "NHC official forecast track", Points = points };
            }

            XElement point = placemark.Descendants().FirstOrDefault(e => e.Name.LocalName == "Point");
            if (point == null) continue;
            List<WindyGeoPoint> coordinates = ParseCoordinates(FirstNamed(point, "coordinates"));
            if (coordinates.Count == 0) continue;
            string description = DirectText(placemark, "description");
            Match hoursMatch = Regex.Match(description, @"(?<hours>\d+)\s*hr Forecast", RegexOptions.IgnoreCase);
            Match windMatch = Regex.Match(description, @"Maximum Wind:\s*(?<wind>\d+)\s*knots", RegexOptions.IgnoreCase);
            int hours = 0;
            double wind = 0;
            if (hoursMatch.Success) Int32.TryParse(hoursMatch.Groups["hours"].Value, out hours);
            if (windMatch.Success) Double.TryParse(windMatch.Groups["wind"].Value, System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out wind);
            positions.Add(new WindyForecastPosition {
                Latitude = coordinates[0].Latitude,
                Longitude = coordinates[0].Longitude,
                ForecastHours = hours,
                MaxWindKnots = wind
            });
        }
        if (longestTrack != null) paths.Add(longestTrack);
        positions = positions.OrderBy(p => p.ForecastHours).ToList();
    }

    // Ray casting is performed after longitude unwrapping around the query point;
    // otherwise a polygon crossing the antimeridian can look like a world-wide band.
    private static bool PointInPolygon(double longitude, double latitude, List<WindyGeoPoint> polygon)
    {
        if (polygon == null || polygon.Count < 3) return false;
        bool inside = false;
        for (int i = 0, j = polygon.Count - 1; i < polygon.Count; j = i++)
        {
            double xi = longitude + NormalizeLon(polygon[i].Longitude - longitude);
            double xj = longitude + NormalizeLon(polygon[j].Longitude - longitude);
            double yi = polygon[i].Latitude, yj = polygon[j].Latitude;
            double segmentX = xj - xi, segmentY = yj - yi;
            double lengthSquared = segmentX * segmentX + segmentY * segmentY;
            if (lengthSquared < 1e-24)
            {
                double pointX = longitude - xi, pointY = latitude - yi;
                if (pointX * pointX + pointY * pointY <= 1e-20) return true;
            }
            else
            {
                double cross = (longitude - xi) * segmentY - (latitude - yi) * segmentX;
                double dot = (longitude - xi) * segmentX + (latitude - yi) * segmentY;
                if (Math.Abs(cross) <= 1e-10 && dot >= 0 && dot <= lengthSquared) return true;
            }
            bool crosses = ((yi > latitude) != (yj > latitude)) &&
                (longitude < (xj - xi) * (latitude - yi) / (yj - yi) + xi);
            if (crosses) inside = !inside;
        }
        return inside;
    }

    private static string ProbabilityAt(List<WindyProbabilityBand> bands, double latitude, double longitude)
    {
        if (bands == null || bands.Count == 0) return "no data";
        string match = "";
        for (int i = 0; i < bands.Count; i++)
        {
            bool contains = false;
            for (int p = 0; p < bands[i].Polygons.Count; p++)
            {
                if (PointInPolygon(longitude, latitude, bands[i].Polygons[p])) { contains = true; break; }
            }
            if (!contains) continue;
            if (match.Length > 0 && !String.Equals(match, bands[i].Label, StringComparison.OrdinalIgnoreCase)) return "boundary";
            match = bands[i].Label;
        }
        return match.Length == 0 ? "outside grid" : match;
    }

    // Parse the independent NHC layers first, then publish them together under
    // StateLock. The viewer sees one advisory snapshot instead of a mixture of
    // old and new layers while downloads finish at different times.
    public static string ConfigureNHCProducts(string forecastTrackKml, string coneKml,
        string windRadiiKml, string probability34Kml, string probability50Kml,
        string probability64Kml, string probabilityValidTimeUtc, int probabilityLinkedStormCount)
    {
        List<string> status = new List<string>();
        List<WindyGeoPath> forecastPaths = new List<WindyGeoPath>();
        List<WindyForecastPosition> forecastPositions = new List<WindyForecastPosition>();
        List<WindyGeoPath> conePaths = new List<WindyGeoPath>();
        List<WindyGeoPath> radiiPaths = new List<WindyGeoPath>();
        List<WindyProbabilityBand> probability34 = new List<WindyProbabilityBand>();
        List<WindyProbabilityBand> probability50 = new List<WindyProbabilityBand>();
        List<WindyProbabilityBand> probability64 = new List<WindyProbabilityBand>();
        try { ParseForecastTrack(forecastTrackKml, out forecastPaths, out forecastPositions); }
        catch (Exception ex) { status.Add("track: " + ex.Message); }
        try { conePaths = ParsePolygons(coneKml, "cone", false); }
        catch (Exception ex) { status.Add("cone: " + ex.Message); }
        try { radiiPaths = ParsePolygons(windRadiiKml, "radii", true); }
        catch (Exception ex) { status.Add("wind radii: " + ex.Message); }
        try { probability34 = ParseProbabilityKml(probability34Kml); }
        catch (Exception ex) { status.Add("34 kt probability: " + ex.Message); }
        try { probability50 = ParseProbabilityKml(probability50Kml); }
        catch (Exception ex) { status.Add("50 kt probability: " + ex.Message); }
        try { probability64 = ParseProbabilityKml(probability64Kml); }
        catch (Exception ex) { status.Add("64 kt probability: " + ex.Message); }
        if (forecastPaths.Count == 0 || forecastPositions.Count == 0) status.Add("track unavailable");
        if (conePaths.Count == 0) status.Add("cone unavailable");
        if (radiiPaths.Count == 0) status.Add("wind radii unavailable");
        if (probability34.Count == 0) status.Add("34 kt probability unavailable");
        if (probability50.Count == 0) status.Add("50 kt probability unavailable");
        if (probability64.Count == 0) status.Add("64 kt probability unavailable");
        string result = status.Count == 0 ? "NHC forecast track, cone, wind radii, and wind-probability GIS loaded" : String.Join("; ", status);
        lock (StateLock)
        {
            State.ForecastPaths = forecastPaths;
            State.ForecastPositions = forecastPositions;
            State.ConePaths = conePaths;
            State.WindRadiusPaths = radiiPaths;
            State.Probability34 = probability34;
            State.Probability50 = probability50;
            State.Probability64 = probability64;
            State.ProbabilityValidTimeUtc = probabilityValidTimeUtc ?? "";
            State.ProbabilityLinkedStormCount = probabilityLinkedStormCount;
            State.ProductStatus = result;
        }
        InvalidateOverlay();
        return result;
    }

    // The native window gets its own STA thread because User32 messages and GDI
    // paint DCs have one natural owner. PowerShell can then schedule network work
    // without making the map wait on a feed request.
    public static void Start()
    {
        if (Running) return;
        LastError = "";
        Stopped.Reset();
        Running = true;
        OverlayThread = new Thread(RunWindows);
        OverlayThread.IsBackground = true;
        OverlayThread.Name = "Windy GDI overlay";
        OverlayThread.SetApartmentState(ApartmentState.STA);
        OverlayThread.Start();
    }

    public static void Stop()
    {
        Running = false;
        SpriteThreadRunning = false;
        IntPtr hwnd = WindowHandle;
        if (hwnd != IntPtr.Zero) PostMessageW(hwnd, WM_CLOSE, IntPtr.Zero, IntPtr.Zero);
        if (OverlayThread != null && OverlayThread.IsAlive && Thread.CurrentThread != OverlayThread)
            Stopped.Wait(3000);
        if (SpriteThread != null && SpriteThread.IsAlive && Thread.CurrentThread != SpriteThread)
            SpriteThread.Join(1000);
    }

    // Full invalidation means the map state changed: mark the cached bitmap dirty
    // and ring the window's paint bell. Movement without a scale/data change uses
    // InvalidateWindow instead and reuses the existing bitmap.
    private static void InvalidateOverlay()
    {
        Interlocked.Exchange(ref StaticLayerDirty, 1);
        IntPtr hwnd = WindowHandle;
        if (hwnd != IntPtr.Zero) InvalidateRect(hwnd, IntPtr.Zero, false);
    }

    private static void InvalidateWindow()
    {
        IntPtr hwnd = WindowHandle;
        if (hwnd != IntPtr.Zero) InvalidateRect(hwnd, IntPtr.Zero, false);
    }

    [DllImport("user32.dll")] private static extern bool InvalidateRect(IntPtr hwnd, IntPtr rect, bool erase);

    // Resize, visibility, title, and foreground events replace a polling timer.
    // The message loop can sleep, then follow Chrome only when Windows reports a
    // meaningful window event.
    private static void InstallWindowEventHooks()
    {
        uint flags = WINEVENT_OUTOFCONTEXT | WINEVENT_SKIPOWNPROCESS;
        ForegroundEventHook = SetWinEventHook(EVENT_SYSTEM_FOREGROUND, EVENT_SYSTEM_FOREGROUND,
            IntPtr.Zero, WinEventProc, 0, 0, flags);
        LocationEventHook = SetWinEventHook(EVENT_OBJECT_LOCATIONCHANGE, EVENT_OBJECT_LOCATIONCHANGE,
            IntPtr.Zero, WinEventProc, 0, 0, flags);
        VisibilityEventHook = SetWinEventHook(EVENT_OBJECT_SHOW, EVENT_OBJECT_HIDE,
            IntPtr.Zero, WinEventProc, 0, 0, flags);
        NameEventHook = SetWinEventHook(EVENT_OBJECT_NAMECHANGE, EVENT_OBJECT_NAMECHANGE,
            IntPtr.Zero, WinEventProc, 0, 0, flags);
        DestroyEventHook = SetWinEventHook(EVENT_OBJECT_DESTROY, EVENT_OBJECT_DESTROY,
            IntPtr.Zero, WinEventProc, 0, 0, flags);
        if (ForegroundEventHook == IntPtr.Zero || LocationEventHook == IntPtr.Zero ||
            VisibilityEventHook == IntPtr.Zero || NameEventHook == IntPtr.Zero ||
            DestroyEventHook == IntPtr.Zero)
        {
            UninstallWindowEventHooks();
            throw new InvalidOperationException("Could not install the WinEvent hooks that wake the sleeping overlay thread: " + Marshal.GetLastWin32Error());
        }
    }

    private static void UninstallWindowEventHooks()
    {
        if (ForegroundEventHook != IntPtr.Zero) UnhookWinEvent(ForegroundEventHook);
        if (LocationEventHook != IntPtr.Zero) UnhookWinEvent(LocationEventHook);
        if (VisibilityEventHook != IntPtr.Zero) UnhookWinEvent(VisibilityEventHook);
        if (NameEventHook != IntPtr.Zero) UnhookWinEvent(NameEventHook);
        if (DestroyEventHook != IntPtr.Zero) UnhookWinEvent(DestroyEventHook);
        ForegroundEventHook = IntPtr.Zero;
        LocationEventHook = IntPtr.Zero;
        VisibilityEventHook = IntPtr.Zero;
        NameEventHook = IntPtr.Zero;
        DestroyEventHook = IntPtr.Zero;
    }

    private static void HandleWinEvent(IntPtr hook, uint eventType, IntPtr hwnd,
        int idObject, int idChild, uint eventThread, uint eventTime)
    {
        if (!Running || hwnd == IntPtr.Zero || hwnd == WindowHandle) return;
        if (eventType == EVENT_SYSTEM_FOREGROUND)
        {
            FollowWindyWindow();
            return;
        }
        if (idObject != OBJID_WINDOW && idObject != OBJID_CLIENT) return;
        if (hwnd == ParentWindowHandle || hwnd == RendererHandle) FollowWindyWindow();
    }

    private static void StartSpriteAnimationThread()
    {
        if (SpriteThread != null && SpriteThread.IsAlive) return;
        SpriteThreadRunning = true;
        SpriteThread = new Thread(RunSpriteAnimation);
        SpriteThread.IsBackground = true;
        SpriteThread.Name = "TOOLANG fleur sprite clock";
        SpriteThread.Start();
    }

    private static void StopSpriteAnimationThread()
    {
        SpriteThreadRunning = false;
        if (SpriteThread != null && SpriteThread.IsAlive && Thread.CurrentThread != SpriteThread)
            SpriteThread.Join(1000);
    }

    // This worker advances the angle and invalidates only the flower bounds. It
    // never draws: the GDI window thread remains the sole owner of paint contexts.
    private static void RunSpriteAnimation()
    {
        while (Running && SpriteThreadRunning)
        {
            int angleDegrees = (int)Math.Round(CompassAnimationAngleRadians() * 180.0 / Math.PI);
            int previous = Interlocked.Exchange(ref SpriteAngleDegrees, angleDegrees);
            if (previous != angleDegrees)
            {
                Interlocked.Increment(ref SpriteFrameChangeCount);
                FleurLayout layout;
                lock (FleurLayoutLock)
                {
                    layout = new FleurLayout {
                        X = CurrentFleurLayout.X,
                        Y = CurrentFleurLayout.Y,
                        Scale = CurrentFleurLayout.Scale,
                        Unit = CurrentFleurLayout.Unit,
                        LineWidth = CurrentFleurLayout.LineWidth,
                        Half = CurrentFleurLayout.Half,
                        Visible = CurrentFleurLayout.Visible
                    };
                }
                IntPtr hwnd = WindowHandle;
                if (layout.Visible && hwnd != IntPtr.Zero && IsWindowVisible(hwnd))
                {
                    RECT dirty = new RECT {
                        Left = layout.X - layout.Half - 2,
                        Top = layout.Y - layout.Half - 2,
                        Right = layout.X + layout.Half + 3,
                        Bottom = layout.Y + layout.Half + 3
                    };
                    InvalidateClientRect(hwnd, ref dirty, false);
                }
            }
            Thread.Sleep(33);
        }
    }

    // Set up the native window, hooks, and first paint here. Afterward GetMessage
    // blocks instead of polling; state invalidation or a sprite patch wakes it.
    private static void RunWindows()
    {
        try
        {
            if (!SetProcessDpiAwarenessContext(new IntPtr(PMv2)))
            {
                int error = Marshal.GetLastWin32Error();
                if (error != 5) throw new InvalidOperationException("SetProcessDpiAwarenessContext failed: " + error);
            }
            InstanceHandle = GetModuleHandleW(null);
            WNDCLASSEX wc = new WNDCLASSEX();
            wc.cbSize = (uint)Marshal.SizeOf(typeof(WNDCLASSEX));
            wc.style = CS_HREDRAW | CS_VREDRAW;
            wc.lpfnWndProc = Proc;
            wc.hInstance = InstanceHandle;
            wc.lpszClassName = ClassName;
            if (RegisterClassExW(ref wc) == 0)
                throw new InvalidOperationException("RegisterClassExW failed: " + Marshal.GetLastWin32Error());

            RECT bounds = new RECT();
            IntPtr renderer = IntPtr.Zero;
            bool foundSurface = false;
            Console.WriteLine("Waiting for a visible Chrome page titled Windy; the overlay will attach when it is available.");
            while (Running && !foundSurface)
            {
                ParentWindowHandle = FindWindyChromeWindow();
                if (ParentWindowHandle != IntPtr.Zero)
                {
                    renderer = FindWindyRenderer(ParentWindowHandle);
                    if (renderer != IntPtr.Zero && GetWindowRect(renderer, out bounds) &&
                        bounds.Right > bounds.Left && bounds.Bottom > bounds.Top)
                        foundSurface = true;
                    else
                        ParentWindowHandle = IntPtr.Zero;
                }
                if (!foundSurface && Running) Thread.Sleep(1000);
            }
            if (!Running) return;
            if (!foundSurface) throw new InvalidOperationException("Could not find the visible Windy page rendering surface in Chrome.");
            RendererHandle = renderer;
            LastBounds = ToManagedRect(bounds);

            uint exStyle = WS_EX_LAYERED | WS_EX_TRANSPARENT | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE;
            WindowHandle = CreateWindowExW(exStyle, ClassName, "Windy hurricane geometry overlay", WS_POPUP,
                bounds.Left, bounds.Top, bounds.Right - bounds.Left, bounds.Bottom - bounds.Top,
                ParentWindowHandle, IntPtr.Zero, InstanceHandle, IntPtr.Zero);
            if (WindowHandle == IntPtr.Zero)
                throw new InvalidOperationException("CreateWindowExW failed: " + Marshal.GetLastWin32Error());
            if (!SetLayeredWindowAttributes(WindowHandle, TRANSPARENT_KEY, 0, LWA_COLORKEY))
                throw new InvalidOperationException("SetLayeredWindowAttributes failed: " + Marshal.GetLastWin32Error());
            if (!RegisterHotKey(WindowHandle, 1, MOD_CONTROL | MOD_SHIFT | MOD_NOREPEAT, VK_F12))
                throw new InvalidOperationException("Could not register Ctrl+Shift+F12: " + Marshal.GetLastWin32Error());
            HotKeyRegistered = true;
            LastParentDpi = GetDpiForWindow(ParentWindowHandle);
            InstallWindowEventHooks();

            ShowWindow(WindowHandle, SW_SHOWNOACTIVATE);
            UpdateWindow(WindowHandle);
            StartSpriteAnimationThread();
            Console.WriteLine("GDI overlay attached to the Windy page surface. It is click-through and follows the page window across monitors.");
            Console.WriteLine("Static GDI layer is cached; GetMessage waits while idle. Zoom/map or size/DPI changes dirty the cache and queue WM_PAINT to wake the UI thread.");
            Console.WriteLine("Fleur worker only advances cached sprite angles and invalidates the flower rectangle; it never draws through the UI thread's GDI context.");
            Console.WriteLine("Initial render: " + RenderDiagnostics);
            Console.WriteLine("Close with Ctrl+Shift+F12 or Ctrl+C in this PowerShell window.");

            MSG msg;
            int result;
            while ((result = GetMessageW(out msg, IntPtr.Zero, 0, 0)) > 0)
            {
                TranslateMessage(ref msg);
                DispatchMessageW(ref msg);
            }
            if (result < 0) throw new InvalidOperationException("GetMessageW failed: " + Marshal.GetLastWin32Error());
        }
        catch (Exception ex)
        {
            LastError = ex.Message;
            Console.Error.WriteLine("Overlay stopped: " + ex.Message);
        }
        finally
        {
            StopSpriteAnimationThread();
            UninstallWindowEventHooks();
            ReleaseStaticLayer();
            ReleaseFleurSprites();
            if (WindowHandle != IntPtr.Zero)
            {
                if (HotKeyRegistered) UnregisterHotKey(WindowHandle, 1);
                DestroyWindow(WindowHandle);
            }
            if (InstanceHandle != IntPtr.Zero) UnregisterClassW(ClassName, InstanceHandle);
            WindowHandle = IntPtr.Zero;
            RendererHandle = IntPtr.Zero;
            ParentWindowHandle = IntPtr.Zero;
            HotKeyRegistered = false;
            Running = false;
            Stopped.Set();
            Console.WriteLine("Windy overlay closed.");
        }
    }

    // Window movement only repositions the overlay. A size or DPI change alters
    // its coordinate scale, so it dirties the static cache and requests a rebuild.
    private static void FollowWindyWindow()
    {
        IntPtr parent = FindWindyChromeWindow();
        if (parent == IntPtr.Zero || IsIconic(parent))
        {
            if (WindowHandle != IntPtr.Zero && IsWindowVisible(WindowHandle))
                ShowWindow(WindowHandle, SW_HIDE);
            RendererHandle = IntPtr.Zero;
            return;
        }
        IntPtr renderer = FindWindyRenderer(parent);
        RECT rect;
        if (renderer == IntPtr.Zero || !GetWindowRect(renderer, out rect) || rect.Right <= rect.Left || rect.Bottom <= rect.Top)
        {
            if (WindowHandle != IntPtr.Zero && IsWindowVisible(WindowHandle))
                ShowWindow(WindowHandle, SW_HIDE);
            RendererHandle = IntPtr.Zero;
            return;
        }

        bool wasVisible = IsWindowVisible(WindowHandle);
        if (parent != ParentWindowHandle)
        {
            SetWindowLongPtrW(WindowHandle, GWLP_HWNDPARENT, parent);
            ParentWindowHandle = parent;
        }
        WindyRectangle next = ToManagedRect(rect);
        uint nextDpi = GetDpiForWindow(parent);
        bool sizeChanged = LastBounds.Right - LastBounds.Left != next.Right - next.Left ||
            LastBounds.Bottom - LastBounds.Top != next.Bottom - next.Top;
        bool dpiChanged = LastParentDpi != 0 && nextDpi != 0 && LastParentDpi != nextDpi;
        bool changed = RendererHandle != renderer || LastBounds.Left != next.Left || LastBounds.Top != next.Top ||
            LastBounds.Right != next.Right || LastBounds.Bottom != next.Bottom;
        RendererHandle = renderer;
        if (changed)
        {
            SetWindowPos(WindowHandle, IntPtr.Zero, next.Left, next.Top, next.Right - next.Left,
                next.Bottom - next.Top, SWP_NOACTIVATE | SWP_NOZORDER | SWP_SHOWWINDOW);
            LastBounds = next;
            if (sizeChanged || dpiChanged)
            {
                Interlocked.Increment(ref ViewportScaleWakeCount);
                InvalidateOverlay();
            }
            else InvalidateWindow();
        }
        else
        {
            ShowWindow(WindowHandle, SW_SHOWNOACTIVATE);
            if (!wasVisible) InvalidateWindow();
        }
        LastParentDpi = nextDpi;
    }

    private static WindyRectangle ToManagedRect(RECT rect)
    {
        return new WindyRectangle { Left = rect.Left, Top = rect.Top, Right = rect.Right, Bottom = rect.Bottom };
    }

    private static IntPtr FindWindyRenderer(IntPtr parent)
    {
        IntPtr best = IntPtr.Zero;
        long bestArea = 0;
        EnumChildWindows(parent, delegate(IntPtr child, IntPtr unused)
        {
            if (!IsWindowVisible(child) || ReadClassName(child) != "Chrome_RenderWidgetHostHWND") return true;
            RECT r;
            if (!GetWindowRect(child, out r)) return true;
            long area = (long)Math.Max(0, r.Right - r.Left) * Math.Max(0, r.Bottom - r.Top);
            if (area > bestArea) { bestArea = area; best = child; }
            return true;
        }, IntPtr.Zero);
        return best;
    }

    private static bool TopWindowCallback(IntPtr hwnd, IntPtr data) { return true; }
    private static bool ChildWindowCallback(IntPtr hwnd, IntPtr data) { return true; }

    private static IntPtr WindowProc(IntPtr hwnd, uint msg, IntPtr wParam, IntPtr lParam)
    {
        if (msg == WM_PAINT)
        {
            PAINTSTRUCT ps = new PAINTSTRUCT();
            ps.rgbReserved = new byte[32];
            IntPtr dc = BeginPaint(hwnd, ref ps);
            try { PaintCachedLayer(dc, hwnd, ps.rcPaint); }
            catch (Exception ex) { LastError = ex.Message; }
            finally { EndPaint(hwnd, ref ps); }
            return IntPtr.Zero;
        }
        if (msg == WM_ERASEBKGND) return new IntPtr(1);
        if (msg == WM_HOTKEY || msg == WM_CLOSE)
        {
            DestroyWindow(hwnd);
            return IntPtr.Zero;
        }
        if (msg == WM_DESTROY)
        {
            PostQuitMessage(0);
            return IntPtr.Zero;
        }
        return DefWindowProcW(hwnd, msg, wParam, lParam);
    }

    // Keep one compatible memory surface per client size. Reallocating only when
    // dimensions change avoids recreating brushes, lines, and coast paths on every
    // animation tick.
    private static bool EnsureStaticLayer(IntPtr referenceDc, int width, int height)
    {
        if (width <= 0 || height <= 0) return false;
        if (StaticLayerDc != IntPtr.Zero && StaticLayerBitmap != IntPtr.Zero &&
            StaticLayerWidth == width && StaticLayerHeight == height) return true;
        ReleaseStaticLayer();
        IntPtr dc = CreateCompatibleDC(referenceDc);
        if (dc == IntPtr.Zero) return false;
        IntPtr bitmap = CreateCompatibleBitmap(referenceDc, width, height);
        if (bitmap == IntPtr.Zero) { DeleteDC(dc); return false; }
        IntPtr previous = SelectObject(dc, bitmap);
        if (previous == IntPtr.Zero || previous == new IntPtr(-1))
        {
            DeleteObject(bitmap);
            DeleteDC(dc);
            return false;
        }
        StaticLayerDc = dc;
        StaticLayerBitmap = bitmap;
        StaticLayerPreviousBitmap = previous;
        StaticLayerWidth = width;
        StaticLayerHeight = height;
        Interlocked.Exchange(ref StaticLayerDirty, 1);
        return true;
    }

    private static void ReleaseStaticLayer()
    {
        if (StaticLayerDc != IntPtr.Zero && StaticLayerPreviousBitmap != IntPtr.Zero)
            SelectObject(StaticLayerDc, StaticLayerPreviousBitmap);
        if (StaticLayerBitmap != IntPtr.Zero) DeleteObject(StaticLayerBitmap);
        if (StaticLayerDc != IntPtr.Zero) DeleteDC(StaticLayerDc);
        StaticLayerDc = IntPtr.Zero;
        StaticLayerBitmap = IntPtr.Zero;
        StaticLayerPreviousBitmap = IntPtr.Zero;
        StaticLayerWidth = 0;
        StaticLayerHeight = 0;
        Interlocked.Exchange(ref StaticLayerDirty, 1);
    }

    // A WM_PAINT is cheap when nothing is dirty: blit the stored map marks and
    // redraw only the animated fleur over its transparent color key. Full work is
    // reserved for a real state/scale change.
    private static void PaintCachedLayer(IntPtr targetDc, IntPtr hwnd, RECT dirty)
    {
        Interlocked.Increment(ref PaintMessageCount);
        RECT client;
        if (!GetClientRect(hwnd, out client)) return;
        int width = client.Right - client.Left;
        int height = client.Bottom - client.Top;
        if (!EnsureStaticLayer(targetDc, width, height))
        {
            DrawStaticLayer(targetDc, hwnd);
            DrawAnimatedFleur(targetDc);
            return;
        }

        if (Interlocked.Exchange(ref StaticLayerDirty, 0) != 0)
        {
            try
            {
                DrawStaticLayer(StaticLayerDc, hwnd);
                Interlocked.Increment(ref StaticLayerBuildCount);
            }
            catch
            {
                Interlocked.Exchange(ref StaticLayerDirty, 1);
                throw;
            }
        }

        int copyWidth = dirty.Right - dirty.Left;
        int copyHeight = dirty.Bottom - dirty.Top;
        if (copyWidth <= 0 || copyHeight <= 0)
        {
            dirty = client;
            copyWidth = width;
            copyHeight = height;
        }
        if (!BitBlt(targetDc, dirty.Left, dirty.Top, copyWidth, copyHeight,
            StaticLayerDc, dirty.Left, dirty.Top, 0x00CC0020))
            throw new InvalidOperationException("Could not blit the cached TOOLANG layer: " + Marshal.GetLastWin32Error());
        DrawAnimatedFleur(targetDc);
    }

    private static WindyOverlayState Snapshot()
    {
        lock (StateLock) return State.Copy();
    }

    private static uint RGB(byte r, byte g, byte b) { return (uint)(r | (g << 8) | (b << 16)); }

    private static POINT[] ProjectPath(List<WindyGeoPoint> path, WindyOverlayState state,
        double scale, int width, int height, bool closeRing)
    {
        if (path == null || path.Count < 2) return new POINT[0];
        bool closed = closeRing && path.Count > 2 &&
            Math.Abs(path[0].Latitude - path[path.Count - 1].Latitude) < 1e-7 &&
            Math.Abs(NormalizeLon(path[0].Longitude - path[path.Count - 1].Longitude)) < 1e-7;
        POINT[] points = new POINT[path.Count + (closeRing && !closed ? 1 : 0)];
        for (int i = 0; i < path.Count; i++)
            points[i] = Project(path[i].Latitude, path[i].Longitude, state, scale, width, height);
        if (closeRing && !closed) points[points.Length - 1] = points[0];
        return points;
    }

    // Separate colors and line styles preserve each NHC product's identity: cone,
    // radii, forecast connector, and time-stamped forecast points are not synonyms.
    private static void DrawNHCProducts(IntPtr dc, WindyOverlayState state,
        double scale, int width, int height)
    {
        uint cone = RGB(255, 180, 70);
        uint forecast = RGB(170, 255, 220);
        uint radius34 = RGB(105, 220, 255);
        uint radius50 = RGB(255, 150, 65);
        uint radius64 = RGB(255, 90, 125);
        int thin = Math.Max(1, (int)Math.Round(2 * scale));

        for (int i = 0; i < state.ConePaths.Count; i++)
            DrawPolyline(dc, ProjectPath(state.ConePaths[i].Points, state, scale, width, height, true), cone, thin, PS_DASH);

        for (int i = 0; i < state.WindRadiusPaths.Count; i++)
        {
            WindyGeoPath path = state.WindRadiusPaths[i];
            uint color = path.Label.StartsWith("64", StringComparison.Ordinal) ? radius64 :
                path.Label.StartsWith("50", StringComparison.Ordinal) ? radius50 : radius34;
            DrawPolyline(dc, ProjectPath(path.Points, state, scale, width, height, true), color, thin, PS_SOLID);
        }

        for (int i = 0; i < state.ForecastPaths.Count; i++)
            DrawPolyline(dc, ProjectPath(state.ForecastPaths[i].Points, state, scale, width, height, false), forecast, thin, PS_DASH);

        for (int i = 0; i < state.ForecastPositions.Count; i++)
        {
            WindyForecastPosition position = state.ForecastPositions[i];
            if (position.ForecastHours <= 0) continue;
            POINT p = Project(position.Latitude, position.Longitude, state, scale, width, height);
            DrawDot(dc, p.X, p.Y, Math.Max(3, (int)Math.Round(4 * scale)), forecast);
            string label = "+" + position.ForecastHours + "h";
            if (position.MaxWindKnots > 0) label += " " + position.MaxWindKnots.ToString("0", System.Globalization.CultureInfo.InvariantCulture) + "kt";
            DrawSmallText(dc, p.X + (int)Math.Round(6 * scale), p.Y - (int)Math.Round(13 * scale), label, forecast, (int)Math.Round(13 * scale));
        }
    }

    // Sample probabilities only at the URL's map center, and print that location
    // beside the categories so a broad grid is not mistaken for a storm-specific
    // deterministic forecast.
    private static string MapCenterProbability(WindyOverlayState state)
    {
        return String.Format(System.Globalization.CultureInfo.InvariantCulture,
            "5-day wind probabilities at {0:F2}, {1:F2} (34/50/64 kt): {2} / {3} / {4}",
            state.MapLatitude, state.MapLongitude,
            ProbabilityAt(state.Probability34, state.MapLatitude, state.MapLongitude),
            ProbabilityAt(state.Probability50, state.MapLatitude, state.MapLongitude),
            ProbabilityAt(state.Probability64, state.MapLatitude, state.MapLongitude));
    }

    private static string MotionOffsetFromNorth(WindyOverlayState state)
    {
        double signed = ((state.MotionBearing % 360.0) + 540.0) % 360.0 - 180.0;
        if (Math.Abs(signed) < 0.5) return "aligned";
        if (Math.Abs(Math.Abs(signed) - 180.0) < 0.5) return "opposite";
        return Math.Abs(signed).ToString("0", System.Globalization.CultureInfo.InvariantCulture) +
            (signed < 0 ? "\u00B0 W" : "\u00B0 E");
    }

    private static double NiceScaleDistance(double maximumMeters)
    {
        if (Double.IsNaN(maximumMeters) || Double.IsInfinity(maximumMeters) || maximumMeters <= 0) return 0;
        double exponent = Math.Floor(Math.Log10(maximumMeters));
        for (int e = (int)exponent; e >= (int)exponent - 2; e--)
        {
            double unit = Math.Pow(10.0, e);
            if (5.0 * unit <= maximumMeters) return 5.0 * unit;
            if (2.0 * unit <= maximumMeters) return 2.0 * unit;
            if (1.0 * unit <= maximumMeters) return 1.0 * unit;
        }
        return maximumMeters;
    }

    private static string FormatScaleDistance(double meters)
    {
        if (meters >= 1000.0)
        {
            double km = meters / 1000.0;
            return km >= 100.0 ? km.ToString("N0", System.Globalization.CultureInfo.InvariantCulture) + " km" :
                km.ToString("0.#", System.Globalization.CultureInfo.InvariantCulture) + " km";
        }
        if (meters >= 1.0) return meters.ToString("N0", System.Globalization.CultureInfo.InvariantCulture) + " m";
        if (meters >= 0.01) return (meters * 100.0).ToString("0.#", System.Globalization.CultureInfo.InvariantCulture) + " cm";
        return (meters * 1000.0).ToString("0.#", System.Globalization.CultureInfo.InvariantCulture) + " mm";
    }

    // The scale bar converts screen distance back to ground distance. At world
    // wrap, repeated map seams are called out as a projection effect, not an edge
    // or circumference of the Earth in every direction.
    private static void DrawMapRuler(IntPtr dc, WindyOverlayState state,
        double scale, int width, int height, uint cyan)
    {
        bool wrapped = state.MapZoom <= 0.5;
        int left = (int)Math.Round(14 * scale);
        int cardWidth = Math.Min((int)Math.Round((wrapped ? 470 : 440) * scale), Math.Max(1, width - left * 2));
        int cardHeight = (int)Math.Round((wrapped ? 86 : 132) * scale);
        int x = left;
        int y = wrapped ? height - cardHeight - (int)Math.Round(12 * scale) :
            (int)Math.Round(80 * scale + 10 * 20 * scale + 30 * scale);
        if (y + cardHeight > height - (int)Math.Round(8 * scale))
            y = Math.Max((int)Math.Round(8 * scale), height - cardHeight - (int)Math.Round(8 * scale));

        RECT card = new RECT { Left = x, Top = y, Right = x + cardWidth, Bottom = y + cardHeight };
        IntPtr bg = CreateSolidBrush(RGB(12, 20, 30));
        IntPtr border = CreatePen(PS_SOLID, Math.Max(1, (int)Math.Round(2 * scale)), cyan);
        if (bg != IntPtr.Zero && border != IntPtr.Zero)
        {
            IntPtr oldBrush = SelectObject(dc, bg);
            IntPtr oldPen = SelectObject(dc, border);
            RoundRect(dc, card.Left, card.Top, card.Right, card.Bottom,
                (int)Math.Round(12 * scale), (int)Math.Round(12 * scale));
            SelectObject(dc, oldPen);
            SelectObject(dc, oldBrush);
            DeleteObject(border);
            DeleteObject(bg);
        }
        else
        {
            if (border != IntPtr.Zero) DeleteObject(border);
            if (bg != IntPtr.Zero) DeleteObject(bg);
        }

        double metersPerPixel = MapMetersPerPixel(state.MapLatitude, state.MapZoom, scale);
        if (wrapped)
        {
            double visibleKm = metersPerPixel * state.MapViewportWidth * width / 1000.0;
            double wrapKm = 40075.01668557849 * Math.Cos(Math.Max(-85.05112878, Math.Min(85.05112878,
                state.MapLatitude)) * Math.PI / 180.0);
            double laps = wrapKm <= 0 ? 0 : visibleKm / wrapKm;
            DrawSmallText(dc, x + (int)Math.Round(14 * scale), y + (int)Math.Round(10 * scale),
                "\u221E  TOOLANG wrap ruler: " + visibleKm.ToString("N0", System.Globalization.CultureInfo.InvariantCulture) +
                " km across  |  " + laps.ToString("0.0", System.Globalization.CultureInfo.InvariantCulture) + " laps",
                RGB(255, 178, 218), (int)Math.Round(14 * scale));
            DrawSmallText(dc, x + (int)Math.Round(14 * scale), y + (int)Math.Round(38 * scale),
                "Latitude lap " + wrapKm.ToString("N0", System.Globalization.CultureInfo.InvariantCulture) +
                " km  |  sphere loops all bearings; map seam ticks repeat east-west",
                RGB(225, 235, 245), (int)Math.Round(12 * scale));
            DrawSmallText(dc, x + (int)Math.Round(14 * scale), y + (int)Math.Round(61 * scale),
                "Motion " + MotionOffsetFromNorth(state) + " of N  |  zoom " +
                state.MapZoom.ToString("0.0", System.Globalization.CultureInfo.InvariantCulture),
                RGB(175, 255, 220), (int)Math.Round(12 * scale));
        }
        else
        {
            int textX = x + (int)Math.Round(14 * scale);
            DrawSmallText(dc, textX, y + (int)Math.Round(10 * scale),
                "TOOLANG  |  storm-anchored fleur compass", RGB(175, 255, 220), (int)Math.Round(15 * scale));
            DrawSmallText(dc, textX, y + (int)Math.Round(39 * scale),
                "N/S bold  |  E/W medium  |  diagonal light  |  rays scale with zoom",
                RGB(225, 235, 245), (int)Math.Round(12 * scale));
            DrawSmallText(dc, textX, y + (int)Math.Round(63 * scale),
                "NHC motion " + MotionOffsetFromNorth(state) + " of N  |  zoom " +
                state.MapZoom.ToString("0.0", System.Globalization.CultureInfo.InvariantCulture),
                RGB(200, 220, 235), (int)Math.Round(12 * scale));

            int barX = textX;
            int barY = y + (int)Math.Round(106 * scale);
            double distanceMeters = NiceScaleDistance(metersPerPixel * 150.0 * scale);
            int barWidth = Math.Max(24, (int)Math.Round(distanceMeters / metersPerPixel));
            DrawSmallText(dc, barX + (int)Math.Round(204 * scale), y + (int)Math.Round(91 * scale),
                FormatScaleDistance(distanceMeters) + " / " +
                (distanceMeters / 1852.0).ToString("0.#", System.Globalization.CultureInfo.InvariantCulture) + " nmi",
                RGB(255, 255, 255), (int)Math.Round(12 * scale));
            DrawPolyline(dc, new POINT[] { new POINT(barX, barY), new POINT(barX + barWidth, barY) },
                RGB(255, 210, 20), Math.Max(2, (int)Math.Round(4 * scale)), PS_SOLID);
            int tick = (int)Math.Round(9 * scale);
            DrawPolyline(dc, new POINT[] { new POINT(barX, barY - tick), new POINT(barX, barY + tick) },
                RGB(255, 210, 20), Math.Max(1, (int)Math.Round(2 * scale)), PS_SOLID);
            DrawPolyline(dc, new POINT[] { new POINT(barX + barWidth, barY - tick), new POINT(barX + barWidth, barY + tick) },
                RGB(255, 210, 20), Math.Max(1, (int)Math.Round(2 * scale)), PS_SOLID);
        }
    }

    private static double CompassZoomMultiplier(WindyOverlayState state, double scale, int width, int height)
    {
        double factor = Math.Max(0.55, Math.Min(2.4, Math.Pow(2.0, state.MapZoom - 4.0)));
        double fitLimit = Math.Min(width, height) / (2.0 * scale) - 54.0;
        if (fitLimit > 0) factor = Math.Min(factor, fitLimit / 160.0);
        return Math.Max(0.4, factor);
    }

    // Anchor the compass to the storm when space permits; if the viewport edge
    // would clip it, move it inward and draw a leader back to the storm center.
    private static void DrawStormCompass(IntPtr dc, WindyOverlayState state, POINT storm,
        double scale, int width, int height)
    {
        double zoomFactor = CompassZoomMultiplier(state, scale, width, height);
        int margin = (int)Math.Ceiling((160.0 * zoomFactor + 55.0 * Math.Sqrt(zoomFactor) + 14.0) * scale);
        int viewportLeft = Math.Max(0, Math.Min(width, (int)Math.Floor(state.MapViewportLeft * width)));
        int viewportTop = Math.Max(0, Math.Min(height, (int)Math.Floor(state.MapViewportTop * height)));
        int viewportRight = Math.Max(viewportLeft, Math.Min(width,
            (int)Math.Ceiling((state.MapViewportLeft + state.MapViewportWidth) * width)));
        int viewportBottom = Math.Max(viewportTop, Math.Min(height,
            (int)Math.Ceiling((state.MapViewportTop + state.MapViewportHeight) * height)));
        int viewportCenterX = (int)Math.Round((state.MapViewportLeft + state.MapViewportWidth / 2.0) * width);
        int viewportCenterY = (int)Math.Round((state.MapViewportTop + state.MapViewportHeight / 2.0) * height);
        int minX = Math.Min(viewportCenterX, viewportLeft + margin);
        int maxX = Math.Max(viewportCenterX, viewportRight - margin);
        int minY = Math.Min(viewportCenterY, viewportTop + margin);
        int maxY = Math.Max(viewportCenterY, viewportBottom - margin);
        int cx, cy;
        bool stormVisible = storm.X >= 0 && storm.X < width && storm.Y >= 0 && storm.Y < height;
        if (stormVisible)
        {
            cx = Math.Max(minX, Math.Min(maxX, storm.X));
            cy = Math.Max(minY, Math.Min(maxY, storm.Y));
        }
        else
        {
            cx = viewportCenterX;
            cy = viewportCenterY;
        }

        if (Math.Abs(cx - storm.X) + Math.Abs(cy - storm.Y) > 4)
            DrawPolyline(dc, new POINT[] { storm, new POINT(cx, cy) },
                RGB(215, 230, 245), Math.Max(1, (int)Math.Round(scale)), PS_DASH);
        DrawCompassRose(dc, cx, cy, scale, false, width, height,
            state, RGB(255, 210, 20), RGB(175, 255, 220), RGB(255, 178, 218));
    }

    // Length classes and line weights follow the requested visual hierarchy.
    // The north arrow is map-north for this north-up projection, not magnetic
    // heading or a forecast direction.
    private static void DrawCompassRose(IntPtr dc, int cx, int cy, double scale,
        bool worldWrap, int width, int height, WindyOverlayState state,
        uint northSouth, uint eastWest, uint diagonal)
    {
        double zoomFactor = worldWrap ? 1.0 : CompassZoomMultiplier(state, scale, width, height);
        double detailScale = scale * Math.Sqrt(zoomFactor);
        int northSouthLength = worldWrap ? Math.Max(24, height / 2 - (int)Math.Round(48 * scale)) : (int)Math.Round(160 * scale * zoomFactor);
        int eastWestLength = worldWrap ? Math.Max(24, width / 2 - (int)Math.Round(44 * scale)) : (int)Math.Round(140 * scale * zoomFactor);
        int diagonalLength = worldWrap ? (int)Math.Round(Math.Min(width, height) * 0.33) : (int)Math.Round(78 * scale * zoomFactor);
        int nsWidth = Math.Max(5, (int)Math.Round((worldWrap ? 10 : 9) * detailScale));
        int ewWidth = Math.Max(3, (int)Math.Round((worldWrap ? 7 : 6) * detailScale));
        int diagWidth = Math.Max(2, (int)Math.Round(3 * detailScale));
        int majorHead = Math.Max(10, (int)Math.Round(17 * detailScale));
        int minorHead = Math.Max(7, (int)Math.Round(11 * detailScale));

        if (worldWrap)
        {
            DrawEllipseRing(dc, cx - eastWestLength, cy - northSouthLength,
                cx + eastWestLength, cy + northSouthLength, RGB(105, 220, 255), Math.Max(1, (int)Math.Round(2 * scale)));
            DrawEllipseRing(dc, cx - (int)Math.Round(eastWestLength * 0.56), cy - northSouthLength,
                cx + (int)Math.Round(eastWestLength * 0.56), cy + northSouthLength, RGB(255, 178, 218), Math.Max(1, (int)Math.Round(2 * scale)));
            DrawEllipseRing(dc, cx - eastWestLength, cy - (int)Math.Round(northSouthLength * 0.48),
                cx + eastWestLength, cy + (int)Math.Round(northSouthLength * 0.48), RGB(175, 255, 220), Math.Max(1, (int)Math.Round(1 * scale)));
        }

        DrawArrow(dc, cx, cy, cx - diagonalLength, cy - diagonalLength, diagonal, diagWidth, minorHead);
        DrawArrow(dc, cx, cy, cx + diagonalLength, cy - diagonalLength, diagonal, diagWidth, minorHead);
        DrawArrow(dc, cx, cy, cx - diagonalLength, cy + diagonalLength, diagonal, diagWidth, minorHead);
        DrawArrow(dc, cx, cy, cx + diagonalLength, cy + diagonalLength, diagonal, diagWidth, minorHead);
        int nsLoopHalfWidth = Math.Max(10, (int)Math.Round((worldWrap ? 34 : 23) * detailScale));
        int ewLoopHalfWidth = Math.Max(8, (int)Math.Round((worldWrap ? 25 : 17) * detailScale));
        DrawCardinalLoop(dc, cx, cy, -1, 0, eastWestLength, ewLoopHalfWidth,
            eastWest, ewWidth, Math.Max(2, ewWidth - 2), majorHead);
        DrawCardinalLoop(dc, cx, cy, 1, 0, eastWestLength, ewLoopHalfWidth,
            eastWest, ewWidth, Math.Max(2, ewWidth - 2), majorHead);
        DrawCardinalLoop(dc, cx, cy, 0, -1, northSouthLength, nsLoopHalfWidth,
            northSouth, nsWidth, Math.Max(3, nsWidth - 2), majorHead);
        DrawCardinalLoop(dc, cx, cy, 0, 1, northSouthLength, nsLoopHalfWidth,
            northSouth, nsWidth, Math.Max(3, nsWidth - 2), majorHead);

        int ring = Math.Max(12, (int)Math.Round((worldWrap ? 42 : 38) * detailScale));
        DrawRing(dc, cx, cy, ring, RGB(105, 220, 255), Math.Max(1, (int)Math.Round(2 * detailScale)));
        DrawRing(dc, cx, cy, ring + (int)Math.Round(9 * detailScale), RGB(255, 178, 218), Math.Max(1, (int)Math.Round(1 * detailScale)));
        DrawDot(dc, cx, cy, Math.Max(4, (int)Math.Round(6 * detailScale)), RGB(255, 245, 220));

        DrawSmallText(dc, cx - (int)Math.Round(8 * detailScale), cy - northSouthLength - (int)Math.Round(24 * detailScale),
            "N", RGB(255, 255, 255), (int)Math.Round(18 * detailScale));
        DrawSmallText(dc, cx - (int)Math.Round(8 * detailScale), cy + northSouthLength + (int)Math.Round(4 * detailScale),
            "S", RGB(255, 255, 255), (int)Math.Round(18 * detailScale));
        DrawSmallText(dc, cx - eastWestLength - (int)Math.Round(28 * detailScale), cy - (int)Math.Round(8 * detailScale),
            "W", RGB(255, 255, 255), (int)Math.Round(16 * detailScale));
        DrawSmallText(dc, cx + eastWestLength + (int)Math.Round(8 * detailScale), cy - (int)Math.Round(8 * detailScale),
            "E", RGB(255, 255, 255), (int)Math.Round(16 * detailScale));
        DrawSmallText(dc, cx - diagonalLength - (int)Math.Round(25 * detailScale), cy - diagonalLength - (int)Math.Round(15 * detailScale),
            "NW", RGB(225, 235, 245), (int)Math.Round(12 * detailScale));
        DrawSmallText(dc, cx + diagonalLength + (int)Math.Round(4 * detailScale), cy - diagonalLength - (int)Math.Round(15 * detailScale),
            "NE", RGB(225, 235, 245), (int)Math.Round(12 * detailScale));
        DrawSmallText(dc, cx - diagonalLength - (int)Math.Round(25 * detailScale), cy + diagonalLength + (int)Math.Round(2 * detailScale),
            "SW", RGB(225, 235, 245), (int)Math.Round(12 * detailScale));
        DrawSmallText(dc, cx + diagonalLength + (int)Math.Round(4 * detailScale), cy + diagonalLength + (int)Math.Round(2 * detailScale),
            "SE", RGB(225, 235, 245), (int)Math.Round(12 * detailScale));

        int flowerOffset = worldWrap ?
            Math.Min((int)Math.Round(northSouthLength * 0.48), (int)Math.Round(94 * detailScale)) :
            Math.Min((int)Math.Round(northSouthLength * 0.62), (int)Math.Round(78 * detailScale));
        SetFleurLayout(cx, cy - flowerOffset, 3.4 * detailScale);

        if (worldWrap)
        {
            double world = 256.0 * Math.Pow(2.0, state.MapZoom) * scale;
            double centerWorldX = (NormalizeLon(state.MapLongitude) + 180.0) / 360.0 * world;
            double mapWidth = state.MapViewportWidth * width;
            double mapCenterX = (state.MapViewportLeft + state.MapViewportWidth / 2.0) * width;
            long first = (long)Math.Ceiling((centerWorldX - mapWidth / 2.0) / world);
            long last = (long)Math.Floor((centerWorldX + mapWidth / 2.0) / world);
            for (long worldIndex = first; worldIndex <= last && worldIndex - first < 256; worldIndex++)
            {
                int seamX = (int)Math.Round(mapCenterX + worldIndex * world - centerWorldX);
                DrawPolyline(dc, new POINT[] {
                    new POINT(seamX, cy - (int)Math.Round(23 * scale)),
                    new POINT(seamX, cy + (int)Math.Round(23 * scale))
                }, RGB(255, 178, 218), Math.Max(2, (int)Math.Round(3 * scale)), PS_SOLID);
                DrawSmallText(dc, seamX - (int)Math.Round(8 * scale), cy + (int)Math.Round(26 * scale),
                    "\u221E", RGB(255, 178, 218), (int)Math.Round(15 * scale));
            }
        }
    }

    // This is the still frame: data panels, coast geometry, triangles, ruler, and
    // compass are composed once into the cache. The fleur is deliberately omitted
    // so its motion never forces the whole map illustration to be rebuilt.
    private static void DrawStaticLayer(IntPtr dc, IntPtr hwnd)
    {
        SetFleurLayout(0, 0, 1.0, false);
        RECT client;
        GetClientRect(hwnd, out client);
        IntPtr clear = CreateSolidBrush(TRANSPARENT_KEY);
        FillRect(dc, ref client, clear);
        DeleteObject(clear);

        WindyOverlayState s = Snapshot();
        int width = client.Right - client.Left;
        int height = client.Bottom - client.Top;
        uint dpi = ParentWindowHandle != IntPtr.Zero ? GetDpiForWindow(ParentWindowHandle) : 96;
        double scale = dpi == 0 ? 1.0 : dpi / 96.0;
        int mapCenterX = (int)Math.Round((s.MapViewportLeft + s.MapViewportWidth / 2.0) * width);
        int mapCenterY = (int)Math.Round((s.MapViewportTop + s.MapViewportHeight / 2.0) * height);
        POINT storm = Project(s.StormLatitude, s.StormLongitude, s, scale, width, height);
        POINT coast = Project(s.Land.CoastLatitude, s.Land.CoastLongitude, s, scale, width, height);
        POINT land = Project(s.Land.LandLatitude, s.Land.LandLongitude, s, scale, width, height);

        uint cyan = RGB(20, 245, 255);
        uint official = RGB(145, 210, 255);
        uint gold = RGB(255, 210, 20);
        uint white = RGB(245, 250, 255);

        if (s.MapZoom <= 0.5)
            DrawCompassRose(dc, mapCenterX, mapCenterY, scale, true, width, height,
                s, gold, RGB(175, 255, 220), RGB(255, 178, 218));

        DrawNHCProducts(dc, s, scale, width, height);
        if (s.MapZoom > 0.5) DrawStormCompass(dc, s, storm, scale, width, height);
        DrawDoubleTriangle(dc, storm.X, storm.Y, land.X, land.Y, cyan, (int)Math.Round(3 * scale));
        DrawArrow(dc, storm.X, storm.Y, coast.X, coast.Y, gold, (int)Math.Round(5 * scale), (int)Math.Round(20 * scale));
        double bearingRad = s.MotionBearing * Math.PI / 180.0;
        int headingLength = (int)Math.Round(150 * scale);
        int headingX = storm.X + (int)Math.Round(Math.Sin(bearingRad) * headingLength);
        int headingY = storm.Y - (int)Math.Round(Math.Cos(bearingRad) * headingLength);
        DrawArrow(dc, storm.X, storm.Y, headingX, headingY, official, (int)Math.Round(5 * scale), (int)Math.Round(18 * scale));

        DrawRing(dc, storm.X, storm.Y, (int)Math.Round(15 * scale), cyan, (int)Math.Round(4 * scale));
        DrawDot(dc, storm.X, storm.Y, (int)Math.Round(5 * scale), cyan);
        DrawRing(dc, coast.X, coast.Y, (int)Math.Round(10 * scale), gold, (int)Math.Round(3 * scale));
        DrawDot(dc, land.X, land.Y, (int)Math.Round(7 * scale), gold);

        DrawInfoPanel(dc, s, scale, white, cyan, official, gold);
        DrawMapRuler(dc, s, scale, width, height, cyan);
    }

    // Project into the visible Web Mercator world around Windy's accessible Map
    // center, which can differ from the renderer center when tracker panels slide
    // the canvas. Choosing the shorter wrapped longitude delta keeps nearby points
    // together across the antimeridian.
    private static POINT Project(double lat, double lon, WindyOverlayState state,
        double dpiScale, int width, int height)
    {
        double maxLat = 85.05112878;
        lat = Math.Max(-maxLat, Math.Min(maxLat, lat));
        double centerLat = Math.Max(-maxLat, Math.Min(maxLat, state.MapLatitude));
        double world = 256.0 * Math.Pow(2.0, state.MapZoom) * dpiScale;
        double x0 = (NormalizeLon(state.MapLongitude) + 180.0) / 360.0 * world;
        double x1 = (NormalizeLon(lon) + 180.0) / 360.0 * world;
        double dx = x1 - x0;
        if (dx > world / 2) dx -= world;
        if (dx < -world / 2) dx += world;
        double y0 = MercatorY(centerLat, world);
        double y1 = MercatorY(lat, world);
        double viewportCenterX = (state.MapViewportLeft + state.MapViewportWidth / 2.0) * width;
        double viewportCenterY = (state.MapViewportTop + state.MapViewportHeight / 2.0) * height;
        return new POINT((int)Math.Round(viewportCenterX + dx), (int)Math.Round(viewportCenterY + y1 - y0));
    }

    private static double NormalizeLon(double lon)
    {
        while (lon > 180) lon -= 360;
        while (lon < -180) lon += 360;
        return lon;
    }

    private static double MercatorY(double lat, double world)
    {
        double r = lat * Math.PI / 180.0;
        double y = 0.5 - Math.Log(Math.Tan(Math.PI / 4.0 + r / 2.0)) / (2.0 * Math.PI);
        return y * world;
    }

    // The bowtie points along the storm-to-nearest-land line and back. It is a
    // geometric description of the current coastline relation, not a predictor.
    private static void DrawDoubleTriangle(IntPtr dc, int cx, int cy, int lx, int ly, uint color, int width)
    {
        double dx = lx - cx, dy = ly - cy;
        double length = Math.Sqrt(dx * dx + dy * dy);
        if (length < 1) return;
        double ux = dx / length, uy = dy / length;
        double px = -uy, py = ux;
        int cross = Math.Max(24, Math.Min(50, width * 14));
        int depth = Math.Max(70, Math.Min(150, width * 40));
        POINT a = new POINT((int)Math.Round(cx + px * cross), (int)Math.Round(cy + py * cross));
        POINT b = new POINT((int)Math.Round(cx - px * cross), (int)Math.Round(cy - py * cross));
        POINT landTip = new POINT((int)Math.Round(cx + ux * depth), (int)Math.Round(cy + uy * depth));
        POINT seaTip = new POINT((int)Math.Round(cx - ux * depth), (int)Math.Round(cy - uy * depth));
        DrawPolyline(dc, new POINT[] { a, b, landTip, a }, color, width, PS_SOLID);
        DrawPolyline(dc, new POINT[] { a, b, seaTip, a }, color, width, PS_SOLID);
        int t1x = (a.X + b.X + landTip.X) / 3;
        int t1y = (a.Y + b.Y + landTip.Y) / 3;
        int t2x = (a.X + b.X + seaTip.X) / 3;
        int t2y = (a.Y + b.Y + seaTip.Y) / 3;
        DrawSmallText(dc, t1x + 8, t1y - 18, "T1", color, width * 9);
        DrawSmallText(dc, t2x + 8, t2y + 2, "T2", color, width * 9);
    }

    private static void DrawPolyline(IntPtr dc, POINT[] points, uint color, int width, int style)
    {
        if (points == null || points.Length < 2) return;
        IntPtr pen = CreatePen(style, Math.Max(1, width), color);
        if (pen == IntPtr.Zero) return;
        IntPtr oldPen = SelectObject(dc, pen);
        MoveToEx(dc, points[0].X, points[0].Y, IntPtr.Zero);
        for (int i = 1; i < points.Length; i++) LineTo(dc, points[i].X, points[i].Y);
        SelectObject(dc, oldPen);
        DeleteObject(pen);
    }

    private static void DrawArrow(IntPtr dc, int x1, int y1, int x2, int y2, uint color, int width, int head)
    {
        DrawPolyline(dc, new POINT[] { new POINT(x1, y1), new POINT(x2, y2) }, color, width, PS_SOLID);
        double angle = Math.Atan2(y2 - y1, x2 - x1);
        POINT[] tri = new POINT[3];
        tri[0] = new POINT(x2, y2);
        tri[1] = new POINT((int)Math.Round(x2 - head * Math.Cos(angle - Math.PI / 6)), (int)Math.Round(y2 - head * Math.Sin(angle - Math.PI / 6)));
        tri[2] = new POINT((int)Math.Round(x2 - head * Math.Cos(angle + Math.PI / 6)), (int)Math.Round(y2 - head * Math.Sin(angle + Math.PI / 6)));
        IntPtr pen = CreatePen(PS_SOLID, 1, color);
        IntPtr brush = CreateSolidBrush(color);
        if (pen == IntPtr.Zero || brush == IntPtr.Zero) { if (pen != IntPtr.Zero) DeleteObject(pen); if (brush != IntPtr.Zero) DeleteObject(brush); return; }
        IntPtr oldPen = SelectObject(dc, pen);
        IntPtr oldBrush = SelectObject(dc, brush);
        Polygon(dc, tri, 3);
        SelectObject(dc, oldBrush);
        SelectObject(dc, oldPen);
        DeleteObject(brush);
        DeleteObject(pen);
    }

    private static void DrawCardinalLoop(IntPtr dc, int cx, int cy, int dirX, int dirY,
        int length, int halfWidth, uint color, int outlineWidth, int shaftWidth, int head)
    {
        if (length < 2 || halfWidth < 1) return;
        double dx = dirX;
        double dy = dirY;
        double px = -dy;
        double py = dx;
        const int segments = 28;
        POINT[] loop = new POINT[segments * 2 + 2];
        int at = 0;
        for (int i = 0; i <= segments; i++)
        {
            double t = (double)i / segments;
            double spread = halfWidth * Math.Pow(Math.Sin(Math.PI * t), 0.82);
            loop[at++] = new POINT(
                (int)Math.Round(cx + dx * length * t + px * spread),
                (int)Math.Round(cy + dy * length * t + py * spread));
        }
        for (int i = segments; i >= 0; i--)
        {
            double t = (double)i / segments;
            double spread = halfWidth * Math.Pow(Math.Sin(Math.PI * t), 0.82);
            loop[at++] = new POINT(
                (int)Math.Round(cx + dx * length * t - px * spread),
                (int)Math.Round(cy + dy * length * t - py * spread));
        }
        DrawPolyline(dc, loop, color, outlineWidth, PS_SOLID);
        DrawArrow(dc, cx, cy, cx + dirX * length, cy + dirY * length,
            color, shaftWidth, head);
    }

    // One 60-second sine cycle carries the fleur from -45 degrees to +45 and back.
    // Smooth phase belongs to the worker; cached integer-degree sprites keep the
    // GDI paint path light.
    private static double CompassAnimationAngleRadians()
    {
        double phase = (CompassAnimationClock.Elapsed.TotalSeconds % 60.0) / 60.0;
        double angleDegrees = -45.0 * Math.Sin(2.0 * Math.PI * phase);
        return angleDegrees * Math.PI / 180.0;
    }

    private static void SetFleurLayout(int x, int y, double scale, bool visible = true)
    {
        int unit = Math.Max(1, (int)Math.Round(scale));
        int lineWidth = Math.Max(1, (int)Math.Round(2 * scale));
        lock (FleurLayoutLock)
        {
            CurrentFleurLayout.X = x;
            CurrentFleurLayout.Y = y;
            CurrentFleurLayout.Scale = scale;
            CurrentFleurLayout.Unit = unit;
            CurrentFleurLayout.LineWidth = lineWidth;
            CurrentFleurLayout.Half = 22 * unit + lineWidth + 2;
            CurrentFleurLayout.Visible = visible;
        }
    }

    private static void DrawAnimatedFleur(IntPtr dc)
    {
        FleurLayout layout;
        lock (FleurLayoutLock)
        {
            if (!CurrentFleurLayout.Visible) return;
            layout = new FleurLayout {
                X = CurrentFleurLayout.X,
                Y = CurrentFleurLayout.Y,
                Scale = CurrentFleurLayout.Scale,
                Unit = CurrentFleurLayout.Unit,
                LineWidth = CurrentFleurLayout.LineWidth,
                Half = CurrentFleurLayout.Half,
                Visible = CurrentFleurLayout.Visible
            };
        }
        int angle = Interlocked.CompareExchange(ref SpriteAngleDegrees, 0, 0);
        DrawFleurDeLis(dc, layout.X, layout.Y, layout.Scale, angle * Math.PI / 180.0);
        Interlocked.Increment(ref SpriteFramePaintCount);
    }

    private static POINT[] TransformFleurPoints(int cx, int cy, POINT[] localPoints, double cos, double sin)
    {
        POINT[] transformed = new POINT[localPoints.Length];
        for (int i = 0; i < localPoints.Length; i++)
        {
            double x = localPoints[i].X;
            double y = localPoints[i].Y;
            transformed[i] = new POINT(
                cx + (int)Math.Round(x * cos - y * sin),
                cy + (int)Math.Round(x * sin + y * cos));
        }
        return transformed;
    }

    private static void DrawFleurDeLis(IntPtr dc, int cx, int cy, double scale, double angleRadians)
    {
        int u = Math.Max(1, (int)Math.Round(scale));
        int lineWidth = Math.Max(1, (int)Math.Round(2 * scale));
        int angleDegrees = (int)Math.Round(angleRadians * 180.0 / Math.PI);
        FleurSprite sprite;
        if (!EnsureFleurSpriteCache(dc, u, lineWidth) || !FleurSpriteCache.TryGetValue(angleDegrees, out sprite))
        {
            DrawFleurDeLisVector(dc, cx, cy, u, lineWidth, angleDegrees * Math.PI / 180.0);
            return;
        }
        if (!TransparentBlt(dc, cx - sprite.Center, cy - sprite.Center, sprite.Width, sprite.Width,
            sprite.Dc, 0, 0, sprite.Width, sprite.Width, TRANSPARENT_KEY))
            DrawFleurDeLisVector(dc, cx, cy, u, lineWidth, angleDegrees * Math.PI / 180.0);
    }

    // Rasterize the 91 integer-angle variants once for this size. Reusing these
    // sprites trades a small, bounded cache for lighter paints and steadier motion.
    private static bool EnsureFleurSpriteCache(IntPtr referenceDc, int u, int lineWidth)
    {
        int key = checked(u * 100 + lineWidth);
        if (FleurSpriteCacheKey == key && FleurSpriteCache.Count == 91) return true;
        ReleaseFleurSprites();
        int half = 22 * u + lineWidth + 2;
        int size = 2 * half + 1;
        for (int angleDegrees = -45; angleDegrees <= 45; angleDegrees++)
        {
            IntPtr spriteDc = CreateCompatibleDC(referenceDc);
            if (spriteDc == IntPtr.Zero) { ReleaseFleurSprites(); return false; }
            IntPtr bitmap = CreateCompatibleBitmap(referenceDc, size, size);
            if (bitmap == IntPtr.Zero) { DeleteDC(spriteDc); ReleaseFleurSprites(); return false; }
            IntPtr previous = SelectObject(spriteDc, bitmap);
            if (previous == IntPtr.Zero || previous == new IntPtr(-1))
            {
                DeleteObject(bitmap);
                DeleteDC(spriteDc);
                ReleaseFleurSprites();
                return false;
            }
            IntPtr background = CreateSolidBrush(TRANSPARENT_KEY);
            if (background == IntPtr.Zero)
            {
                SelectObject(spriteDc, previous);
                DeleteObject(bitmap);
                DeleteDC(spriteDc);
                ReleaseFleurSprites();
                return false;
            }
            RECT bounds = new RECT { Left = 0, Top = 0, Right = size, Bottom = size };
            int fillResult = FillRect(spriteDc, ref bounds, background);
            DeleteObject(background);
            if (fillResult == 0)
            {
                SelectObject(spriteDc, previous);
                DeleteObject(bitmap);
                DeleteDC(spriteDc);
                ReleaseFleurSprites();
                return false;
            }
            DrawFleurDeLisVector(spriteDc, half, half, u, lineWidth, angleDegrees * Math.PI / 180.0);
            FleurSpriteCache.Add(angleDegrees, new FleurSprite {
                Dc = spriteDc, Bitmap = bitmap, PreviousBitmap = previous, Width = size, Center = half
            });
        }
        FleurSpriteCacheKey = key;
        return true;
    }

    private static void ReleaseFleurSprites()
    {
        foreach (FleurSprite sprite in FleurSpriteCache.Values)
        {
            if (sprite.Dc != IntPtr.Zero && sprite.PreviousBitmap != IntPtr.Zero)
                SelectObject(sprite.Dc, sprite.PreviousBitmap);
            if (sprite.Bitmap != IntPtr.Zero) DeleteObject(sprite.Bitmap);
            if (sprite.Dc != IntPtr.Zero) DeleteDC(sprite.Dc);
        }
        FleurSpriteCache.Clear();
        FleurSpriteCacheKey = Int32.MinValue;
    }

    private static void DrawFleurDeLisVector(IntPtr dc, int cx, int cy, int u,
        int lineWidth, double angleRadians)
    {
        double cos = Math.Cos(angleRadians);
        double sin = Math.Sin(angleRadians);
        uint gold = RGB(255, 210, 20);
        uint pink = RGB(255, 178, 218);
        uint mint = RGB(175, 255, 220);
        POINT[] centerLeaf = TransformFleurPoints(cx, cy, new POINT[] {
            new POINT(0, -22 * u), new POINT(5 * u, -16 * u),
            new POINT(4 * u, -10 * u), new POINT(0, -5 * u),
            new POINT(-4 * u, -10 * u), new POINT(-5 * u, -16 * u),
            new POINT(0, -22 * u)
        }, cos, sin);
        POINT[] leftPetal = TransformFleurPoints(cx, cy, new POINT[] {
            new POINT(-2 * u, -5 * u), new POINT(-8 * u, -12 * u),
            new POINT(-15 * u, -14 * u), new POINT(-20 * u, -10 * u),
            new POINT(-17 * u, -4 * u), new POINT(-12 * u, 1 * u),
            new POINT(-5 * u, 2 * u), new POINT(-2 * u, -2 * u)
        }, cos, sin);
        POINT[] rightPetal = TransformFleurPoints(cx, cy, new POINT[] {
            new POINT(2 * u, -5 * u), new POINT(8 * u, -12 * u),
            new POINT(15 * u, -14 * u), new POINT(20 * u, -10 * u),
            new POINT(17 * u, -4 * u), new POINT(12 * u, 1 * u),
            new POINT(5 * u, 2 * u), new POINT(2 * u, -2 * u)
        }, cos, sin);
        DrawPolyline(dc, leftPetal, pink, lineWidth, PS_SOLID);
        DrawPolyline(dc, rightPetal, pink, lineWidth, PS_SOLID);
        DrawPolyline(dc, centerLeaf, gold, lineWidth, PS_SOLID);
        DrawPolyline(dc, TransformFleurPoints(cx, cy, new POINT[] { new POINT(0, -6 * u), new POINT(0, 11 * u) }, cos, sin),
            mint, lineWidth, PS_SOLID);
        DrawPolyline(dc, TransformFleurPoints(cx, cy, new POINT[] { new POINT(-11 * u, 4 * u), new POINT(11 * u, 4 * u) }, cos, sin),
            gold, lineWidth, PS_SOLID);
        DrawPolyline(dc, TransformFleurPoints(cx, cy, new POINT[] {
            new POINT(-9 * u, 7 * u), new POINT(-6 * u, 11 * u),
            new POINT(6 * u, 11 * u), new POINT(9 * u, 7 * u)
        }, cos, sin), gold, lineWidth, PS_SOLID);
        POINT accent = TransformFleurPoints(cx, cy, new POINT[] { new POINT(0, 4 * u) }, cos, sin)[0];
        DrawDot(dc, accent.X, accent.Y, Math.Max(1, u), mint);
    }

    private static void DrawRing(IntPtr dc, int x, int y, int radius, uint color, int width)
    {
        IntPtr pen = CreatePen(PS_SOLID, Math.Max(1, width), color);
        if (pen == IntPtr.Zero) return;
        IntPtr oldPen = SelectObject(dc, pen);
        IntPtr oldBrush = SelectObject(dc, GetStockObject(HOLLOW_BRUSH));
        Ellipse(dc, x - radius, y - radius, x + radius, y + radius);
        SelectObject(dc, oldBrush);
        SelectObject(dc, oldPen);
        DeleteObject(pen);
    }

    private static void DrawEllipseRing(IntPtr dc, int left, int top, int right, int bottom,
        uint color, int width)
    {
        IntPtr pen = CreatePen(PS_SOLID, Math.Max(1, width), color);
        if (pen == IntPtr.Zero) return;
        IntPtr oldPen = SelectObject(dc, pen);
        IntPtr oldBrush = SelectObject(dc, GetStockObject(HOLLOW_BRUSH));
        Ellipse(dc, left, top, right, bottom);
        SelectObject(dc, oldBrush);
        SelectObject(dc, oldPen);
        DeleteObject(pen);
    }

    private static void DrawDot(IntPtr dc, int x, int y, int radius, uint color)
    {
        IntPtr brush = CreateSolidBrush(color);
        IntPtr pen = CreatePen(PS_SOLID, 1, color);
        if (brush == IntPtr.Zero || pen == IntPtr.Zero) { if (brush != IntPtr.Zero) DeleteObject(brush); if (pen != IntPtr.Zero) DeleteObject(pen); return; }
        IntPtr oldBrush = SelectObject(dc, brush);
        IntPtr oldPen = SelectObject(dc, pen);
        Ellipse(dc, x - radius, y - radius, x + radius, y + radius);
        SelectObject(dc, oldPen);
        SelectObject(dc, oldBrush);
        DeleteObject(pen);
        DeleteObject(brush);
    }

    private static void DrawSmallText(IntPtr dc, int x, int y, string text, uint color, int fontHeight)
    {
        IntPtr font = CreateFontW(-Math.Max(16, fontHeight), 0, 0, 0, 700, 0, 0, 0, 1, 0, 0, 0, 0, "Segoe UI");
        if (font == IntPtr.Zero) return;
        IntPtr oldFont = SelectObject(dc, font);
        SetBkMode(dc, TRANSPARENT_BK);
        SetTextColor(dc, RGB(10, 18, 25));
        TextOutW(dc, x + 1, y + 1, text, text.Length);
        SetTextColor(dc, color);
        TextOutW(dc, x, y, text, text.Length);
        SelectObject(dc, oldFont);
        DeleteObject(font);
    }

    // The text panel states provenance and limits next to the marks. In a busy
    // weather scene, a short label can prevent a geometric cue from being read as
    // a forecast claim.
    private static void DrawInfoPanel(IntPtr dc, WindyOverlayState s, double scale,
        uint white, uint cyan, uint official, uint gold)
    {
        int fontH = (int)Math.Round(15 * scale);
        IntPtr font = CreateFontW(-fontH, 0, 0, 0, 700, 0, 0, 0, 1, 0, 0, 0, 0, "Segoe UI");
        if (font == IntPtr.Zero) return;
        IntPtr oldFont = SelectObject(dc, font);
        SetBkMode(dc, TRANSPARENT_BK);
        string[] lines = new string[] {
            s.StormName + "  |  " + s.Classification + "  |  NHC #" + s.Advisory,
            String.Format(System.Globalization.CultureInfo.InvariantCulture, "Center {0:F2}, {1:F2}  |  {2:F0} kt  |  {3:F0} mb", s.StormLatitude, s.StormLongitude, s.MaxWindKnots, s.PressureMb),
            String.Format(System.Globalization.CultureInfo.InvariantCulture, "Current motion {0:F0} deg at {1:F0} mph  |  not forecast", s.MotionBearing, s.MotionSpeedMph),
            "Forecast track + cone + wind radii (34 / 50 / 64 kt)",
            MapCenterProbability(s),
            "5-day cumulative grid shared by " + s.ProbabilityLinkedStormCount + " active record(s)  |  issue " + (String.IsNullOrWhiteSpace(s.ProbabilityValidTimeUtc) ? "unavailable" : s.ProbabilityValidTimeUtc),
            String.Format(System.Globalization.CultureInfo.InvariantCulture, "Nearest coast {0:F3}, {1:F3}  |  {2:F0} km from center", s.Land.CoastLatitude, s.Land.CoastLongitude, s.Land.CoastDistanceKm),
            String.Format(System.Globalization.CultureInfo.InvariantCulture, "Gold land pin {0:F3}, {1:F3}  |  {2:F0} km inland (Natural Earth)", s.Land.LandLatitude, s.Land.LandLongitude, s.Land.InlandDistanceKm),
            "Cyan bowtie = nearest-land geometry only; not a forecast",
            "NHC feed + GIS  |  center valid " + s.ValidTimeUtc + "  |  " + s.ProductStatus
        };
        int maxWidth = 0;
        SIZE size;
        for (int i = 0; i < lines.Length; i++)
        {
            GetTextExtentPoint32W(dc, lines[i], lines[i].Length, out size);
            if (size.Cx > maxWidth) maxWidth = size.Cx;
        }
        int padding = (int)Math.Round(10 * scale);
        int lineH = (int)Math.Round(20 * scale);
        int x = (int)Math.Round(14 * scale), y = (int)Math.Round(80 * scale);
        RECT box = new RECT { Left = x, Top = y, Right = x + maxWidth + padding * 2, Bottom = y + lineH * lines.Length + padding };
        IntPtr bg = CreateSolidBrush(RGB(12, 20, 30));
        IntPtr border = CreatePen(PS_SOLID, Math.Max(1, (int)Math.Round(2 * scale)), cyan);
        if (bg != IntPtr.Zero && border != IntPtr.Zero)
        {
            IntPtr oldBrush = SelectObject(dc, bg);
            IntPtr oldPen = SelectObject(dc, border);
            RoundRect(dc, box.Left, box.Top, box.Right, box.Bottom, 12, 12);
            SelectObject(dc, oldPen);
            SelectObject(dc, oldBrush);
            DeleteObject(border);
            DeleteObject(bg);
        }
        uint[] colors = new uint[] { white, white, official, RGB(170, 255, 220), RGB(180, 255, 170), white, gold, gold, cyan, white };
        for (int i = 0; i < lines.Length; i++)
        {
            SetTextColor(dc, RGB(5, 10, 16));
            TextOutW(dc, x + padding + 1, y + padding + i * lineH + 1, lines[i], lines[i].Length);
            SetTextColor(dc, colors[i]);
            TextOutW(dc, x + padding, y + padding + i * lineH, lines[i], lines[i].Length);
        }
        int sparkleX = box.Right - padding - (int)Math.Round(5 * scale);
        int sparkleY = y + padding / 2;
        int sparkleSize = Math.Max(4, (int)Math.Round(5 * scale));
        DrawPolyline(dc, new POINT[] {
            new POINT(sparkleX, sparkleY - sparkleSize), new POINT(sparkleX + 2, sparkleY),
            new POINT(sparkleX, sparkleY + sparkleSize), new POINT(sparkleX - 2, sparkleY),
            new POINT(sparkleX, sparkleY - sparkleSize)
        }, RGB(255, 178, 218), Math.Max(1, (int)Math.Round(2 * scale)), PS_SOLID);
        DrawDot(dc, sparkleX, sparkleY, Math.Max(1, (int)Math.Round(1 * scale)), RGB(175, 255, 220));
        SelectObject(dc, oldFont);
        DeleteObject(font);
    }

    [DllImport("user32.dll", SetLastError = true)] private static extern bool GetWindowRect(IntPtr hwnd, out RECT rect);
    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)] private static extern bool UnregisterClassW(string className, IntPtr instance);
}
'@

Add-Type -TypeDefinition $source -Language CSharp

# A map coordinate is useful only when it is both recognizable and finite.
# Reject malformed or out-of-projection values at the boundary, before they
# can stretch the ruler into an answer the source never gave us.
function ConvertTo-WindyMapView {
    param([Parameter(Mandatory)][string]$Url)

    if ($Url -notmatch '(?i)^(?:https?://)?(?:www\.)?windy\.com/') { return $null }
    $match = [regex]::Match($Url, '(?<lat>-?\d+(?:\.\d+)?),(?<lon>-?\d+(?:\.\d+)?),(?<zoom>\d+(?:\.\d+)?)')
    if (-not $match.Success) { return $null }
    $lat = [double]::Parse($match.Groups['lat'].Value, [Globalization.CultureInfo]::InvariantCulture)
    $lon = [double]::Parse($match.Groups['lon'].Value, [Globalization.CultureInfo]::InvariantCulture)
    $zoom = [double]::Parse($match.Groups['zoom'].Value, [Globalization.CultureInfo]::InvariantCulture)
    if ($lat -lt -85.05112878 -or $lat -gt 85.05112878 -or $lon -lt -180 -or $lon -gt 180 -or $zoom -lt 0 -or $zoom -gt 22) { return $null }
    return [pscustomobject]@{ Latitude = $lat; Longitude = $lon; Zoom = $zoom }
}

# Follow the page the user can see by reading Chrome's visible address bar.
# This keeps the map link legible and avoids turning page internals into a
# second, hidden source of truth.
function Get-WindyAddressBarUrl {
    try {
        $hwnd = [WindyHurricaneOverlay]::FindWindyChromeWindow()
        if ($hwnd -eq [IntPtr]::Zero) { return $null }
        $root = [System.Windows.Automation.AutomationElement]::FromHandle($hwnd)
        $condition = [System.Windows.Automation.PropertyCondition]::new(
            [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
            [System.Windows.Automation.ControlType]::Edit)
        $edits = $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $condition)
        $url = ''
        for ($i = 0; $i -lt $edits.Count; $i++) {
            $element = $edits.Item($i)
            if ($element.Current.Name -notmatch '(?i)address|search bar|omnibox') { continue }
            $pattern = $element.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern)
            $value = $pattern.Current.Value
            if ($value -match '(?i)^(?:https?://)?(?:www\.)?windy\.com/') { $url = [string]$value; break }
        }
        if ([string]::IsNullOrWhiteSpace($url)) { return $null }

        # The tracker can shift Windy's accessible Map canvas inside an unchanged
        # Chrome renderer. Normalize its visible UIA bounds to the page document;
        # ratios survive monitor DPI differences when passed to the GDI window.
        $viewportLeft = 0.0
        $viewportTop = 0.0
        $viewportWidth = 1.0
        $viewportHeight = 1.0
        $documentCondition = [System.Windows.Automation.PropertyCondition]::new(
            [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
            [System.Windows.Automation.ControlType]::Document)
        $document = $root.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $documentCondition)
        if ($null -ne $document) {
            $mapCondition = [System.Windows.Automation.PropertyCondition]::new(
                [System.Windows.Automation.AutomationElement]::NameProperty, 'Map')
            $mapElement = $document.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $mapCondition)
            if ($null -ne $mapElement) {
                $documentBounds = $document.Current.BoundingRectangle
                $mapBounds = $mapElement.Current.BoundingRectangle
                if ($documentBounds.Width -gt 0 -and $documentBounds.Height -gt 0 -and
                    $mapBounds.Width -gt 0 -and $mapBounds.Height -gt 0) {
                    $candidateLeft = ($mapBounds.X - $documentBounds.X) / $documentBounds.Width
                    $candidateTop = ($mapBounds.Y - $documentBounds.Y) / $documentBounds.Height
                    $candidateWidth = $mapBounds.Width / $documentBounds.Width
                    $candidateHeight = $mapBounds.Height / $documentBounds.Height
                    if ($candidateLeft -ge -0.5 -and $candidateLeft -le 0.5 -and
                        $candidateTop -ge -0.5 -and $candidateTop -le 0.5 -and
                        $candidateWidth -ge 0.25 -and $candidateWidth -le 1.5 -and
                        $candidateHeight -ge 0.25 -and $candidateHeight -le 1.5) {
                        $viewportLeft = $candidateLeft
                        $viewportTop = $candidateTop
                        $viewportWidth = $candidateWidth
                        $viewportHeight = $candidateHeight
                    }
                }
            }
        }
        return [pscustomobject]@{
            Url = $url
            MapViewportLeft = $viewportLeft
            MapViewportTop = $viewportTop
            MapViewportWidth = $viewportWidth
            MapViewportHeight = $viewportHeight
        }
    } catch {
        return $null
    }
}

# The NHC feed is the source for the storm snapshot. Requiring coordinates and
# motion fields together makes a partial record stop here instead of allowing
# an old position to dress itself up as today's advisory.
function Get-NhcStorm {
    param([Parameter(Mandatory)][string]$Name)

    $feed = Invoke-RestMethod -Uri 'https://www.nhc.noaa.gov/CurrentStorms.json' -TimeoutSec 20 -Headers @{ 'User-Agent' = 'TOOLANG/1.2' }
    $storms = @($feed.activeStorms)
    $matches = @($storms | Where-Object { $_.name -ieq $Name -or $_.id -ieq $Name })
    if ($matches.Count -eq 0) {
        $available = if ($storms.Count) { ($storms | ForEach-Object { '{0} ({1}, {2})' -f $_.name,$_.id,$_.classification }) -join '; ' } else { 'none currently active' }
        throw "NHC has no active storm matching '$Name'. Active storms: $available"
    }
    if ($matches.Count -gt 1) { throw "More than one active storm matched '$Name'; use its NHC ID instead." }
    $s = $matches[0]
    foreach ($field in @('latitudeNumeric','longitudeNumeric','movementDir','movementSpeed','lastUpdate')) {
        if ($null -eq $s.$field) { throw "NHC record for '$Name' is missing '$field'; refusing to draw stale geometry." }
    }
    $probabilityValidTime = ''
    if ($s.windSpeedProbabilitiesGIS -and $s.windSpeedProbabilitiesGIS.issuance) {
        $probabilityValidTime = ([DateTimeOffset]::Parse([string]$s.windSpeedProbabilitiesGIS.issuance).ToUniversalTime().ToString('yyyy-MM-dd HH:mm UTC'))
    }
    $probabilityLinkCount = 0
    $forecastTrackUrl = if ($s.forecastTrack) { [string]$s.forecastTrack.kmzFile } else { '' }
    $coneUrl = if ($s.trackCone) { [string]$s.trackCone.kmzFile } else { '' }
    $windRadiiUrl = if ($s.forecastWindRadiiGIS) { [string]$s.forecastWindRadiiGIS.kmzFile } else { '' }
    $probability34Url = ''
    $probability50Url = ''
    $probability64Url = ''
    if ($s.windSpeedProbabilitiesGIS) {
        $probability34Url = [string]$s.windSpeedProbabilitiesGIS.kmzFile34kt
        $probability50Url = [string]$s.windSpeedProbabilitiesGIS.kmzFile50kt
        $probability64Url = [string]$s.windSpeedProbabilitiesGIS.kmzFile64kt
    }
    if (-not [string]::IsNullOrWhiteSpace($probability34Url)) {
        $probabilityLinkCount = @($storms | Where-Object {
            $_.windSpeedProbabilitiesGIS -and [string]$_.windSpeedProbabilitiesGIS.kmzFile34kt -ceq $probability34Url
        }).Count
    }
    return [pscustomobject]@{
        Name = [string]$s.name
        Classification = [string]$s.classification
        Advisory = [string]$s.publicAdvisory.advNum
        AdvisoryUrl = [string]$s.publicAdvisory.url
        ValidTimeUtc = ([DateTimeOffset]::Parse([string]$s.lastUpdate).ToUniversalTime().ToString('yyyy-MM-dd HH:mm UTC'))
        Latitude = [double]$s.latitudeNumeric
        Longitude = [double]$s.longitudeNumeric
        Bearing = [double]$s.movementDir
        SpeedMph = [double]$s.movementSpeed
        MaxWindKnots = [double]$s.intensity
        PressureMb = [double]$s.pressure
        ForecastTrackUrl = $forecastTrackUrl
        ConeUrl = $coneUrl
        WindRadiiUrl = $windRadiiUrl
        Probability34Url = $probability34Url
        Probability50Url = $probability50Url
        Probability64Url = $probability64Url
        ProbabilityValidTimeUtc = $probabilityValidTime
        ProbabilityLinkedStormCount = $probabilityLinkCount
    }
}

# KMZ is a zipped KML envelope: accept only the NHC host, bound the document
# size, and keep a small cache so a steady advisory does not repeatedly travel
# the network. The cap lets new forecast layers enter without hoarding old ones.
function Get-NhcKmlFromKmz {
    param([Parameter(Mandatory)][string]$Url)

    if ($script:NhcKmlCache.Contains($Url)) { return [string]$script:NhcKmlCache[$Url] }
    $uri = [Uri]$Url
    if ($uri.Scheme -ne 'https' -or $uri.Host -ine 'www.nhc.noaa.gov') {
        throw "Refusing NHC GIS URL outside https://www.nhc.noaa.gov: $Url"
    }
    $response = Invoke-WebRequest -Uri $uri -TimeoutSec 35 -Headers @{ 'User-Agent' = 'TOOLANG/1.2' }
    $bytes = [System.IO.MemoryStream]::new()
    $archive = $null
    $entryStream = $null
    $reader = $null
    try {
        $response.RawContentStream.Position = 0
        $response.RawContentStream.CopyTo($bytes)
        $bytes.Position = 0
        $archive = [System.IO.Compression.ZipArchive]::new($bytes, [System.IO.Compression.ZipArchiveMode]::Read, $true)
        $entry = @($archive.Entries | Where-Object { $_.FullName -match '(?i)\.kml$' } | Select-Object -First 1)
        if ($entry.Count -eq 0) { throw 'KMZ archive did not contain a KML document.' }
        if ($entry[0].Length -gt 20000000) { throw 'KML document exceeded the 20 MB safety limit.' }
        $entryStream = $entry[0].Open()
        $reader = [System.IO.StreamReader]::new($entryStream, [System.Text.Encoding]::UTF8, $true)
        $kmlText = $reader.ReadToEnd()
        $script:NhcKmlCache[$Url] = $kmlText
        while ($script:NhcKmlCache.Count -gt 12) {
            $oldestUrl = $script:NhcKmlCache.Keys[0]
            $script:NhcKmlCache.Remove($oldestUrl)
        }
        return $kmlText
    }
    finally {
        if ($null -ne $reader) { $reader.Dispose() }
        elseif ($null -ne $entryStream) { $entryStream.Dispose() }
        if ($null -ne $archive) { $archive.Dispose() }
        $bytes.Dispose()
        if ($null -ne $response.RawContentStream) { $response.RawContentStream.Dispose() }
    }
}

# Fetch the distinct NHC layers as one refresh. A signature avoids needless
# reparsing when the advisory has not changed; on a partial failure we keep the
# previous signature unset so the next scheduled pass can try again.
function Set-NhcOverlayProducts {
    param([Parameter(Mandatory)]$Storm)

    Add-Type -AssemblyName System.IO.Compression
    $urls = [ordered]@{
        Track = $Storm.ForecastTrackUrl
        Cone = $Storm.ConeUrl
        Radii = $Storm.WindRadiiUrl
        Probability34 = $Storm.Probability34Url
        Probability50 = $Storm.Probability50Url
        Probability64 = $Storm.Probability64Url
    }
    $signatureParts = @($urls.Values)
    $signatureParts += [string]$Storm.ProbabilityValidTimeUtc
    $signatureParts += [string]$Storm.ProbabilityLinkedStormCount
    $signature = $signatureParts -join "`n"
    if ($script:NhcProductSignature -ceq $signature) {
        return 'NHC GIS products unchanged; retaining the parsed advisory layers'
    }
    $products = [ordered]@{}
    $downloadFailed = $false
    foreach ($name in $urls.Keys) {
        $products[$name] = $null
        if ([string]::IsNullOrWhiteSpace([string]$urls[$name])) {
            Write-Warning "NHC did not publish the $name GIS product for this advisory."
            $downloadFailed = $true
            continue
        }
        try {
            $products[$name] = Get-NhcKmlFromKmz -Url ([string]$urls[$name])
        }
        catch {
            Write-Warning ("Could not load the NHC {0} GIS product; that layer will show as unavailable. {1}" -f $name,$_.Exception.Message)
            $downloadFailed = $true
        }
    }
    $result = [WindyHurricaneOverlay]::ConfigureNHCProducts(
        $products.Track, $products.Cone, $products.Radii,
        $products.Probability34, $products.Probability50, $products.Probability64,
        $Storm.ProbabilityValidTimeUtc, [int]$Storm.ProbabilityLinkedStormCount)
    if (-not $downloadFailed) { $script:NhcProductSignature = $signature }
    return $result
}

# Workers return records; the UI owner thread applies them. That boundary keeps
# network waits and GIS parsing from holding a drawing surface or GDI handle.
$workerScript = @'
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
$job = $args[0]
$landPath = [string]$args[1]
$previousSignature = [string]$args[2]
$functionSource = [string]$args[3]
$startedUtc = [DateTimeOffset]::UtcNow
try {
    Add-Type -AssemblyName UIAutomationClient -ErrorAction SilentlyContinue
    Add-Type -AssemblyName UIAutomationTypes -ErrorAction SilentlyContinue
    Add-Type -AssemblyName System.IO.Compression
    $script:NhcKmlCache = [ordered]@{}
    $script:NhcProductSignature = $previousSignature
    . ([System.Management.Automation.ScriptBlock]::Create($functionSource))

    if ($job.Kind -eq "MapPoll") {
        $page = Get-WindyAddressBarUrl
        [pscustomobject]@{
            Kind = "MapPoll"
            Id = $job.Id
            Success = $true
            Url = if ($null -ne $page) { [string]$page.Url } else { $null }
            MapViewportLeft = if ($null -ne $page) { [double]$page.MapViewportLeft } else { 0.0 }
            MapViewportTop = if ($null -ne $page) { [double]$page.MapViewportTop } else { 0.0 }
            MapViewportWidth = if ($null -ne $page) { [double]$page.MapViewportWidth } else { 1.0 }
            MapViewportHeight = if ($null -ne $page) { [double]$page.MapViewportHeight } else { 1.0 }
            StartedUtc = $startedUtc
            CompletedUtc = [DateTimeOffset]::UtcNow
        }
        return
    }

    if ($job.Kind -eq "NhcRefresh") {
        $storm = Get-NhcStorm -Name ([string]$job.Payload)
        $land = [WindyHurricaneOverlay]::ConfigureStorm(
            $landPath, $storm.Name, $storm.Classification, $storm.Advisory, $storm.AdvisoryUrl,
            $storm.ValidTimeUtc, $storm.Latitude, $storm.Longitude, $storm.Bearing,
            $storm.SpeedMph, $storm.MaxWindKnots, $storm.PressureMb)
        $productStatus = Set-NhcOverlayProducts -Storm $storm
        [pscustomobject]@{
            Kind = "NhcRefresh"
            Id = $job.Id
            Success = $true
            Storm = $storm
            Land = $land
            ProductStatus = $productStatus
            Signature = $script:NhcProductSignature
            StartedUtc = $startedUtc
            CompletedUtc = [DateTimeOffset]::UtcNow
        }
        return
    }

    throw "Unknown TOOLANG scheduled job kind: $($job.Kind)"
}
catch {
    [pscustomobject]@{
        Kind = [string]$job.Kind
        Id = $job.Id
        Success = $false
        Error = $_.Exception.Message
        StartedUtc = $startedUtc
        CompletedUtc = [DateTimeOffset]::UtcNow
    }
}
'@

$script:ToolangScheduler = $null
$script:ToolangMetrics = $null
$activeJobs = $null
$runspacePool = $null

# Every lane is FIFO, while the dispatcher visits lanes round-robin. The queue
# index is a scheduling class, not a claim of priority or importance; timestamps
# make waiting and execution visible in the periodic diagnostics.
function Add-ToolangWorkItem {
    param(
        [Parameter(Mandatory)][string]$Kind,
        [Parameter(Mandatory)][ValidateRange(0, 15)][int]$QueueIndex,
        [AllowEmptyString()][string]$Payload = ''
    )
    $scheduler = $script:ToolangScheduler
    $scheduler.NextId++
    $item = [pscustomobject]@{
        Id = $scheduler.NextId
        Kind = $Kind
        Payload = $Payload
        QueueIndex = $QueueIndex
        EnqueuedUtc = [DateTimeOffset]::UtcNow
    }
    $scheduler.Queues[$QueueIndex].Enqueue($item)
    $script:ToolangMetrics.Enqueued++
    $depth = 0
    foreach ($queue in $scheduler.Queues) { $depth += $queue.Count }
    if ($depth -gt $script:ToolangMetrics.PeakQueued) { $script:ToolangMetrics.PeakQueued = $depth }
    return $item
}

try {
    # UI Automation reads only the visible address bar. If it is unavailable,
    # the supplied starting URL remains a stable map reference for this run.
    $uIaAvailable = $true
    try {
        Add-Type -AssemblyName UIAutomationClient
        Add-Type -AssemblyName UIAutomationTypes
    } catch {
        $uIaAvailable = $false
        Write-Warning 'Windows UI Automation could not load; map movement will use the supplied -WindyUrl until the script is restarted.'
    }

    $map = ConvertTo-WindyMapView -Url $WindyUrl
    $initialPage = if ($uIaAvailable) { Get-WindyAddressBarUrl } else { $null }
    if ($null -ne $initialPage) {
        $visibleMap = ConvertTo-WindyMapView -Url ([string]$initialPage.Url)
        if ($null -ne $visibleMap) {
            $map = $visibleMap
            $WindyUrl = [string]$initialPage.Url
        }
        [void][WindyHurricaneOverlay]::ConfigureMapViewport(
            [double]$initialPage.MapViewportLeft, [double]$initialPage.MapViewportTop,
            [double]$initialPage.MapViewportWidth, [double]$initialPage.MapViewportHeight)
    }
    if ($null -eq $map) { throw "WindyUrl '$WindyUrl' does not contain a usable Windy map center and zoom." }
    [WindyHurricaneOverlay]::ConfigureMap($map.Latitude, $map.Longitude, $map.Zoom)

    $schedulerQueues = [object[]]::new(16)
    for ($i = 0; $i -lt $schedulerQueues.Length; $i++) {
        $schedulerQueues[$i] = [System.Collections.Generic.Queue[object]]::new()
    }
    $script:ToolangScheduler = [pscustomobject]@{
        Queues = $schedulerQueues
        NextQueue = 0
        NextId = 0
    }
    $script:ToolangMetrics = [ordered]@{
        Enqueued = 0
        Completed = 0
        Failed = 0
        PeakActive = 0
        PeakQueued = 0
        MaxQueueWaitMs = 0.0
        MaxRunMs = 0.0
        TotalQueueWaitMs = 0.0
        TotalRunMs = 0.0
    }

    $initialSessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
    $runspacePool = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspacePool(2, 2, $initialSessionState, $Host)
    $runspacePool.ApartmentState = [System.Threading.ApartmentState]::MTA
    $runspacePool.ThreadOptions = [System.Management.Automation.Runspaces.PSThreadOptions]::ReuseThread
    $runspacePool.Open()
    # A single outstanding poll per source prevents slow network calls from
    # piling up. Two workers can follow the map while an advisory refresh runs;
    # the GDI render loop stays independent of either worker.
    $activeJobs = [System.Collections.Generic.List[object]]::new()
    $lastMapUrl = $WindyUrl
    $mapPollOutstanding = $false
    $nhcRefreshOutstanding = $false
    $lastMapEnqueue = [DateTimeOffset]::MinValue
    $nextNHCRefresh = [DateTimeOffset]::UtcNow
    $lastStatus = [DateTimeOffset]::UtcNow
    $lastWarning = [DateTimeOffset]::MinValue
    $roundRobinQueues = 16

    Write-Host 'TOOLANG map compass + latitude-aware ruler | world-wrap mode gets long, loops, and boops its tail.' -ForegroundColor Magenta
    Write-Host 'Scheduler: 16 FIFO queues, round-robin dispatch, two worker runspaces. Cached GDI drawing stays on its owning UI thread, which waits while idle.' -ForegroundColor DarkCyan
    Write-Host 'NHC retrieval/GIS parsing and Windy address-bar + accessible Map bounds reads run in the workers; the overlay receives atomic state updates.' -ForegroundColor DarkCyan
    Write-Host 'Redraw wake: a changed Windy center/zoom or Chrome surface size/DPI marks the static layer dirty and queues WM_PAINT; sprite ticks invalidate only the fleur.' -ForegroundColor DarkCyan
    Write-Host 'Official motion arrow and the descriptive nearest-land bowtie are drawn separately. The bowtie is not a forecast.'
    Write-Host 'The click-through overlay follows visible Windy pages across monitors without taking focus; it uses GDI without screenshots or page injection.'

    [WindyHurricaneOverlay]::Start()
    $workerFunctionSource = @"
function Get-WindyAddressBarUrl {
$((Get-Command Get-WindyAddressBarUrl).ScriptBlock.ToString())
}
function Get-NhcStorm {
$((Get-Command Get-NhcStorm).ScriptBlock.ToString())
}
function Get-NhcKmlFromKmz {
$((Get-Command Get-NhcKmlFromKmz).ScriptBlock.ToString())
}
function Set-NhcOverlayProducts {
$((Get-Command Set-NhcOverlayProducts).ScriptBlock.ToString())
}
"@

    # The coordinator harvests completed records, enqueues work only when its
    # source cadence is due, then fills available worker slots round-robin.
    # Its short sleep is for orchestration; the idle GDI window thread blocks
    # on Windows messages instead of spending cycles polling for paint work.
    while ([WindyHurricaneOverlay]::IsRunning) {
        if (-not [string]::IsNullOrWhiteSpace([WindyHurricaneOverlay]::LastFailure)) {
            Write-Error ([WindyHurricaneOverlay]::LastFailure)
            break
        }

        for ($i = $activeJobs.Count - 1; $i -ge 0; $i--) {
            $entry = $activeJobs[$i]
            if (-not $entry.Handle.IsCompleted) { continue }
            $result = $null
            try {
                $output = $entry.PowerShell.EndInvoke($entry.Handle)
                if ($output.Count -gt 0) { $result = $output[$output.Count - 1] }
                foreach ($warning in $entry.PowerShell.Streams.Warning) {
                    Write-Warning ([string]$warning.Message)
                }
                if ($null -eq $result) { throw 'Worker completed without a result record.' }

                $now = [DateTimeOffset]::UtcNow
                $queueWaitMs = ($entry.DispatchedUtc - $entry.Item.EnqueuedUtc).TotalMilliseconds
                $runMs = ($now - $entry.DispatchedUtc).TotalMilliseconds
                $script:ToolangMetrics.Completed++
                $script:ToolangMetrics.TotalQueueWaitMs += $queueWaitMs
                $script:ToolangMetrics.TotalRunMs += $runMs
                if ($queueWaitMs -gt $script:ToolangMetrics.MaxQueueWaitMs) { $script:ToolangMetrics.MaxQueueWaitMs = $queueWaitMs }
                if ($runMs -gt $script:ToolangMetrics.MaxRunMs) { $script:ToolangMetrics.MaxRunMs = $runMs }

                if (-not $result.Success) {
                    $script:ToolangMetrics.Failed++
                    if ($result.Kind -eq 'MapPoll') {
                        if (($now - $lastWarning).TotalSeconds -ge 60) {
                            Write-Warning ("Windy map poll failed: {0}" -f $result.Error)
                            $lastWarning = $now
                        }
                    } else {
                        Write-Warning ("NHC refresh failed; retaining the last labeled advisory snapshot. {0}" -f $result.Error)
                        $nextNHCRefresh = $now.AddSeconds(60)
                    }
                } elseif ($result.Kind -eq 'MapPoll') {
                    $nextMap = if ($result.Url) { ConvertTo-WindyMapView -Url ([string]$result.Url) } else { $null }
                    if ($null -ne $nextMap) {
                        $viewportChanged = [WindyHurricaneOverlay]::ConfigureMapViewport(
                            [double]$result.MapViewportLeft, [double]$result.MapViewportTop,
                            [double]$result.MapViewportWidth, [double]$result.MapViewportHeight)
                        if ($viewportChanged) {
                            Write-Host ("Windy map viewport moved within Chrome: left {0:P1}, top {1:P1}, size {2:P1} × {3:P1}" -f `
                                $result.MapViewportLeft,$result.MapViewportTop,$result.MapViewportWidth,$result.MapViewportHeight) -ForegroundColor DarkCyan
                        }
                        if ($result.Url -ne $lastMapUrl) {
                            [WindyHurricaneOverlay]::ConfigureMap($nextMap.Latitude,$nextMap.Longitude,$nextMap.Zoom)
                            $lastMapUrl = [string]$result.Url
                            Write-Host ("Windy map moved: center {0:N3}, {1:N3}, zoom {2:N2}" -f $nextMap.Latitude,$nextMap.Longitude,$nextMap.Zoom) -ForegroundColor DarkCyan
                        }
                    }
                } elseif ($result.Kind -eq 'NhcRefresh') {
                    $script:NhcProductSignature = [string]$result.Signature
                    $nextNHCRefresh = $now.AddSeconds($NHCRefreshSeconds)
                    $storm = $result.Storm
                    $land = $result.Land
                    Write-Host ("NHC {0} {1} | advisory {2} | {3} | motion {4:N0}° at {5:N0} mph" -f $storm.Name,$storm.Classification,$storm.Advisory,$storm.ValidTimeUtc,$storm.Bearing,$storm.SpeedMph) -ForegroundColor Cyan
                    Write-Host ("Nearest coast {0:N3}, {1:N3}; gold marker {2:N3}, {3:N3} ({4:N0} km inland, verified against Natural Earth 10m land)." -f $land.CoastLatitude,$land.CoastLongitude,$land.LandLatitude,$land.LandLongitude,$land.InlandDistanceKm) -ForegroundColor Yellow
                    Write-Host ("NHC structured GIS layers: {0}" -f $result.ProductStatus) -ForegroundColor DarkCyan
                }
            } catch {
                $script:ToolangMetrics.Failed++
                if ($entry.Item.Kind -eq 'MapPoll' -and ($now - $lastWarning).TotalSeconds -ge 60) {
                    Write-Warning ("Windy map worker error: {0}" -f $_.Exception.Message)
                    $lastWarning = $now
                } else {
                    if ($entry.Item.Kind -eq 'NhcRefresh') {
                        Write-Warning ("NHC refresh worker error; retrying in 60 seconds. {0}" -f $_.Exception.Message)
                        $nextNHCRefresh = [DateTimeOffset]::UtcNow.AddSeconds(60)
                    }
                }
            } finally {
                if ($entry.Item.Kind -eq 'MapPoll') { $mapPollOutstanding = $false }
                if ($entry.Item.Kind -eq 'NhcRefresh') { $nhcRefreshOutstanding = $false }
                $entry.PowerShell.Dispose()
                $activeJobs.RemoveAt($i)
            }
        }

        $now = [DateTimeOffset]::UtcNow
        if ($uIaAvailable -and -not $mapPollOutstanding -and
            ($lastMapEnqueue -eq [DateTimeOffset]::MinValue -or ($now - $lastMapEnqueue).TotalSeconds -ge $MapRefreshSeconds)) {
            [void](Add-ToolangWorkItem -Kind 'MapPoll' -QueueIndex 0)
            $mapPollOutstanding = $true
            $lastMapEnqueue = $now
        }
        if (-not $nhcRefreshOutstanding -and $now -ge $nextNHCRefresh) {
            [void](Add-ToolangWorkItem -Kind 'NhcRefresh' -QueueIndex 8 -Payload $StormName)
            $nhcRefreshOutstanding = $true
        }

        while ($activeJobs.Count -lt 2) {
            $item = $null
            for ($offset = 0; $offset -lt $roundRobinQueues; $offset++) {
                $queueIndex = ($script:ToolangScheduler.NextQueue + $offset) % $roundRobinQueues
                $queue = $script:ToolangScheduler.Queues[$queueIndex]
                if ($queue.Count -eq 0) { continue }
                $item = $queue.Dequeue()
                $script:ToolangScheduler.NextQueue = ($queueIndex + 1) % $roundRobinQueues
                break
            }
            if ($null -eq $item) { break }

            $worker = [System.Management.Automation.PowerShell]::Create()
            $worker.RunspacePool = $runspacePool
            [void]$worker.AddScript($workerScript)
            [void]$worker.AddArgument($item)
            [void]$worker.AddArgument($landPath)
            [void]$worker.AddArgument($script:NhcProductSignature)
            [void]$worker.AddArgument($workerFunctionSource)
            $dispatched = [DateTimeOffset]::UtcNow
            $handle = $worker.BeginInvoke()
            $activeJobs.Add([pscustomobject]@{
                Item = $item
                PowerShell = $worker
                Handle = $handle
                DispatchedUtc = $dispatched
            })
            if ($activeJobs.Count -gt $script:ToolangMetrics.PeakActive) {
                $script:ToolangMetrics.PeakActive = $activeJobs.Count
            }
        }

        if (($now - $lastStatus).TotalSeconds -ge 60) {
            $queued = 0
            foreach ($queue in $script:ToolangScheduler.Queues) { $queued += $queue.Count }
            $averageWait = if ($script:ToolangMetrics.Completed) { $script:ToolangMetrics.TotalQueueWaitMs / $script:ToolangMetrics.Completed } else { 0 }
            $averageRun = if ($script:ToolangMetrics.Completed) { $script:ToolangMetrics.TotalRunMs / $script:ToolangMetrics.Completed } else { 0 }
            Write-Host ("RD scheduler: 16 FIFO queues; 2 workers; active {0}/2; queued {1}; completed {2}; failed {3}; peak queued {4}; peak active {5}; avg wait {6:N1} ms; avg run {7:N1} ms." -f $activeJobs.Count,$queued,$script:ToolangMetrics.Completed,$script:ToolangMetrics.Failed,$script:ToolangMetrics.PeakQueued,$script:ToolangMetrics.PeakActive,$averageWait,$averageRun) -ForegroundColor DarkCyan
            Write-Host ("Render: {0}." -f [WindyHurricaneOverlay]::RenderDiagnostics) -ForegroundColor DarkMagenta
            $lastStatus = $now
        }
        Start-Sleep -Milliseconds 100
    }
}
finally {
    # Close producers first, then let the overlay's owning thread release its
    # hooks, bitmaps, and GDI objects. A clean exit keeps the next launch from
    # inheriting stale workers or native handles.
    if ($null -ne $activeJobs) {
        foreach ($entry in @($activeJobs)) {
            try { $entry.PowerShell.Stop() } catch {}
            try { $entry.PowerShell.Dispose() } catch {}
        }
    }
    if ($null -ne $runspacePool) {
        try { $runspacePool.Close() } catch {}
        try { $runspacePool.Dispose() } catch {}
    }
    if ($null -ne $script:ToolangMetrics -and $script:ToolangMetrics.Enqueued -gt 0) {
        $queued = 0
        foreach ($queue in $script:ToolangScheduler.Queues) { $queued += $queue.Count }
        Write-Host ("TOOLANG scheduler stopped: {0} jobs queued, {1} completed, {2} failed; two-worker peak {3}/2; peak queue {4}; maximum run {5:N1} ms." -f $queued,$script:ToolangMetrics.Completed,$script:ToolangMetrics.Failed,$script:ToolangMetrics.PeakActive,$script:ToolangMetrics.PeakQueued,$script:ToolangMetrics.MaxRunMs) -ForegroundColor DarkCyan
    }
    [WindyHurricaneOverlay]::Stop()
}
