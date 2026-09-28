# TOOLANG — Windy hurricane overlay 🌦️

This PowerShell 7 script draws a click-through GDI overlay over the visible Windy map in Chrome. It combines National Hurricane Center (NHC) current-storm data and GIS forecast products with a local Natural Earth land polygon file. The displayed layers keep current motion, forecast track, forecast uncertainty, wind extent, point probabilities, and the custom nearest-land geometry distinct.

## Requirements

- Windows with PowerShell 7 or later (`pwsh`); the overlay uses Windows UI Automation, Win32, and GDI.
- A visible Windy page in Chrome. If none is available, the script waits for one.
- Internet access to the NHC feed and linked GIS products.
- The included `data\ne_10m_land.shp` file.

## Run

Open a visible PowerShell 7 window, change to this folder, and run:

```powershell
pwsh -NoProfile -File .\TOOLANG.ps1 `
  -StormName Polo `
  -WindyUrl 'https://www.windy.com/?21.584,-113.955,7'
```

`-StormName` accepts an active NHC storm name or ID. `-WindyUrl` supplies the starting map center and zoom. The script requires the `data\ne_10m_land.shp` file kept beside it. Press **Ctrl+Shift+F12** or **Ctrl+C** to stop.

## Project files and contributor information

- `TOOLANG.ps1` contains the PowerShell coordinator and embedded C# overlay.
- `data\` contains the Natural Earth land shapefile and retained source archive.
- `validation\` contains the dependency-free validation runner and its latest JSON result manifest.

See [CONTRIBUTING.md](CONTRIBUTING.md) for development guidance, [VALIDATION.md](VALIDATION.md) for the validation command and its scope, and [SECURITY.md](SECURITY.md) for private vulnerability reporting guidance.

For the project's academic framing, research questions, evidence scope, and material provenance, see the [research guide](research/README.md) and [material register](research/material-register.md).

## Worker scheduling

TOOLANG uses 16 in-process FIFO queues and round-robin dispatch. Two PowerShell worker runspaces handle Windy address-bar reads and NHC feed/GIS refresh work. The queue scheduler keeps at most one pending map poll and one pending NHC refresh, so repeated polling cannot build an unbounded backlog. The GDI window, message loop, and static drawing remain on a dedicated UI thread. It waits in the Windows message loop while idle; workers only read data or publish completed weather state.

Static GDI artwork is rendered into a reusable memory bitmap and reused between updates. When the Windy URL supplies a changed map center or zoom, the state update marks that bitmap dirty and invalidates the overlay. Windows queues `WM_PAINT`, waking the waiting UI thread to rebuild the static layer at the new scale. Chrome surface resize or DPI changes trigger the same full redraw through WinEvent notifications. The fleur animation has its own worker: it advances the angle through cached sprite frames and invalidates only the flower's rectangle. It never draws on a GDI context owned by the UI thread. The console reports map-scale and viewport/DPI wake requests, static rebuilds, sprite frame changes/paints, and total paint messages so the split can be checked in a live run.

The console reports active workers, queued work, peak queue depth, completion/failure counts, and average queue/run times every minute. The current job mix has two independent background tasks; a four-worker pool is not enabled unless runtime measurements show sustained queueing or missed refresh cadence.

## What it draws

- **Light blue arrow:** the current movement direction and speed reported by NHC. This describes the storm's current motion; it is not the forecast track.
- **Mint dashed line and labeled points:** NHC forecast positions and the forecast-track connector from NHC's linked KML. The KML track is experimental, and its connectors are only visual links between discrete forecast points; they are not a forecast for every location between those points.
- **Dashed orange boundary:** NHC forecast cone. The cone summarizes historical forecast-track error around the forecast center. It is not the storm's full wind, rain, surge, or impact footprint.
- **Cyan, orange, and pink outlines:** NHC forecast wind-radius polygons for 34, 50, and 64 kt. These show forecast wind extents at the times represented in the product.
- **Three probability bins in the panel:** NHC 5-day cumulative point probabilities for sustained winds of at least 34, 50, and 64 kt, sampled at the map-center coordinates parsed from the Windy URL. Values are shown as the category supplied by NHC (for example, `20-30%`), alongside the product issue time. The panel also reports how many active-storm records link the same probability grid, so the sample is not presented as uniquely attributable to the selected storm. These are location-specific cumulative probabilities, not deterministic forecasts for the map center.
- **Cyan double triangle:** the storm-to-nearest-land direction and its opposite, shown as a geometric description. It is not a forecast, landfall prediction, or claim about where the storm will go.
- **Gold ring:** the nearest coastline point found in the Natural Earth polygons.
- **Gold dot:** a point along the nearest-coast direction that the same polygon data classifies as land. The console and overlay show both coordinates, distance, and the inland offset. This may be an island or another nearest land feature; it is not necessarily a mainland impact location.
- **TOOLANG compass and ruler:** the eight-direction rose is drawn directly at the projected storm center when that point is visible, with a short dashed leader if it must move away from a viewport edge. The four cardinal points are longer, closed return loops; north/south have the heaviest strokes, east/west medium strokes, and the diagonals remain light. Their size responds to map zoom. The enlarged gold, pink, and mint fleur-de-lis gently swings 45 degrees counter-clockwise and 45 degrees clockwise around north in one 60-second cycle (one cycle per minute, or 1/60 Hz; playfully, one “Hershis” per cycle). Its vector design is rasterized into 91 one-degree GDI sprites at the effective display size, reused between frames, rebuilt only when that size changes, and released when the overlay closes. Use the labeled north axis as the direction reference while the flower moves. The compact scale card compares NHC's current motion bearing to map north and shows a local ground scale bar. Scale recalculates from map center, zoom, latitude, and display DPI; pan/zoom URL changes trigger a redraw. At minimum zoom, the rose expands across the visible map with elliptical globe-loop ornament, long rays, and pink seam ticks. The physical Earth is spherical, but this flat Web Mercator view repeats map tiles horizontally at the longitude seam; the north and south edges approach the poles and do not repeat as the same tiles. TOOLANG reports visible horizontal laps and latitude-adjusted distance per lap, with the promised tail-boop joke. This is a visual map ruler, not a survey instrument or a globe renderer.

If the land point cannot be confirmed, the script stops rather than draw an unverified gold dot.

## Data and evidence limits

- NHC status, advisory number, valid time, center, current motion, intensity, pressure, and links to the matching GIS products come from [`CurrentStorms.json`](https://www.nhc.noaa.gov/CurrentStorms.json). The linked forecast-track, cone, forecast-wind-radii, and 34/50/64-kt wind-probability KMZ files are downloaded into memory and refreshed with the feed every five minutes by default. The script caches recently used KMZ URLs in memory, so an unchanged product is not repeatedly downloaded. The panel identifies the valid and probability-product issue times.
- The NHC wind-probability values are 120-hour cumulative point probabilities for sustained winds at or above each threshold. NHC describes these as probabilities of an event occurring at a specific location during the cumulative forecast period; see [NHC's wind-speed probability graphics description](https://www.nhc.noaa.gov/aboutnhcgraphics.shtml). The feed can link one probability grid from multiple active-storm records; the overlay preserves that shared-link scope rather than implying the value belongs only to the storm selected with `-StormName`. The map-center sample is only as geographically detailed as the NHC GIS grid and its category polygons.
- The cone is a forecast-center uncertainty aid. NHC describes the cone's historical coverage and cautions that hazards can extend well outside it; see [NHC's cone explanation](https://www.nhc.noaa.gov/aboutcone.shtml).
- Coast and land checks use Natural Earth `10m` land polygons in `data\ne_10m_land.shp`. This is generalized map data, not Google Earth, satellite imagery, an official landfall forecast, or ground truth. The point-in-polygon result is only as detailed as that dataset.
- Windy's selectable ECMWF/GFS/ICON/UKM tracks and its satellite, radar, rain, wave, and other rendered layers are not downloaded or read as numeric input by this script. They remain useful visual context on the Windy page, but this overlay's numeric storm layers come from the source-labeled NHC products above. It does not infer meteorological data from map colors or inject code into Chrome.
- Windy map center and zoom are read from the visible address bar. When Windows UI Automation can read Chrome's address bar, the script checks it every two seconds and updates when the URL changes. It also reads the visible page's accessible `Map` bounds relative to its document, then normalizes those bounds to the renderer. This keeps the projection centered on the map when Hurricane Tracker shifts its map canvas beneath a side panel. If the accessible Map region is unavailable or implausible, the overlay falls back to the full renderer bounds. Some Windy interactions may pan the rendered map without updating the address bar; in that case the map projection can become stale. Pass a current `-WindyUrl` and restart if needed.
- The overlay uses the standard north-up Web Mercator projection and the map center and zoom in the URL. The fleur points to map north, a true-enough north reference for this north-up view; it is not a magnetic compass and does not account for a rotated map. The motion comparison is only the angle between NHC's current motion bearing and map north. It does not turn the bowtie or compass into a forecast. The script accepts Chrome's scheme-less address-bar value so map moves continue to update the projection. Page layout changes or a changed Windy map projection can affect alignment. Treat the drawing as a visual aid and compare its displayed coordinates with the map before relying on screen placement.
- The information card sits below Windy's search controls and has a small pink-and-mint sparkle as a decorative accent; it carries no weather meaning. At ordinary zoom, only a compact scale/legend card sits below it; the operational rose stays on the map beside the storm. At minimum zoom, the rose occupies the map center and the compact wrap-distance readout moves to the lower left.

## Window and display behavior

- The GDI overlay attaches to the largest visible Chrome page-rendering surface belonging to a window whose title contains “Windy”. Its window follows that renderer, while geographic marks use the accessible Map rectangle inside the page; tracker side panels therefore do not pull the compass away from the map. It follows the page window across monitors and adapts to the window's DPI. If no matching Windy page is visible when started, the PowerShell console stays open and waits for one instead of exiting.
- It is click-through and does not activate or focus Chrome. It remains attached while the Windy window is visible, even if another window has focus, and hides when Windy is minimized or unavailable.
- It does not capture screenshots, read video frames, inject page JavaScript, or alter the Windy page. It reads the Chrome address-bar value and visible accessibility bounds through Windows UI Automation when available.
- Keep the PowerShell window visible for status and errors. When Chrome's title does not contain “Windy”, the overlay waits. If it cannot identify the page-rendering surface, it stays hidden; if UI Automation cannot read the address bar, map updates use the supplied initial map view.

## Included land data

`data\Natural_Earth_ne_10m_land.zip` is the source archive retained with the extracted shapefile for provenance. Its archive includes Natural Earth's source README. Natural Earth describes its data as public domain and documents the 1:10m land layer on its [10m physical vectors page](https://www.naturalearthdata.com/downloads/10m-physical-vectors/10m-land/).

## Project license

No license is currently specified for the TOOLANG source code or documentation, and no project `LICENSE` file is included. Do not infer permission to reuse or redistribute those materials from their availability in a public repository. The Natural Earth dataset is separate: Natural Earth identifies it as public domain, and its source archive and attribution are retained as described above.
