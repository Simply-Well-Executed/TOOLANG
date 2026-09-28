# Development

TOOLANG is a Windows PowerShell 7 application. PowerShell coordinates NHC data retrieval and worker scheduling; the embedded C# implements the Win32/GDI overlay.

## Requirements

- Windows
- PowerShell 7 or later (`pwsh`)
- A visible Chrome window with Windy for live operation
- Network access to the NHC feed and linked GIS products for live operation

There is no dependency manifest or project package-install step. The validation runner uses PowerShell and .NET APIs provided by PowerShell 7.

## Project layout

- `TOOLANG.ps1` - application entry point and embedded C# implementation
- `data\ne_10m_land.shp` - local Natural Earth land polygons used by the application
- `data\Natural_Earth_ne_10m_land.zip` - retained source archive and source README
- `validation\validate.ps1` - focused offline validation runner
- `validation\validation-results.json` - latest generated validation result

Preserve source attribution when changing bundled land data. Keep external data sources distinct in the UI and documentation; do not present the overlay as an official landfall or impact forecast.

## Before submitting changes

From the project root, run the checks documented in [VALIDATION.md](VALIDATION.md):

```powershell
pwsh -NoProfile -File .\validation\validate.ps1
```

Review the generated manifest and include it when retaining a new validation result. Do not add credentials, local machine paths, browser profiles, logs, or unreviewed screen captures to a change. No project license is currently specified; see the notice in [README.md](README.md).
