$ErrorActionPreference = 'Stop'
$scriptPath = (Resolve-Path '.\outputs\WindyHurricaneOverlay\WindyHurricaneOverlay.ps1').Path
$landPath = Join-Path (Split-Path $scriptPath -Parent) 'data\ne_10m_land.shp'
if (-not (Test-Path -LiteralPath $landPath)) { throw "Missing land data: $landPath" }
$tokens = $null; $parseErrors = $null
[System.Management.Automation.Language.Parser]::ParseFile($scriptPath,[ref]$tokens,[ref]$parseErrors) | Out-Null
if ($parseErrors.Count) { throw "PowerShell parse failed: $($parseErrors[0].Message)" }
Write-Host 'PowerShell parser: PASS' -ForegroundColor Green
$scriptText = Get-Content -LiteralPath $scriptPath -Raw
$match = [regex]::Match($scriptText, '(?s)\$source\s*=\s*@''\r?\n(.*?)\r?\n''@\s*Add-Type\s+-TypeDefinition\s+\$source')
if (-not $match.Success) { throw 'Could not isolate the embedded C# source block.' }
Add-Type -TypeDefinition $match.Groups[1].Value -Language CSharp
Write-Host 'Embedded C# compilation: PASS' -ForegroundColor Green
$zipPath = Join-Path (Split-Path $scriptPath -Parent) 'data\Natural_Earth_ne_10m_land.zip'
Add-Type -AssemblyName System.IO.Compression
$archive = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
try {
    $entryCount = $archive.Entries.Count
    foreach ($entry in $archive.Entries) { $stream = $entry.Open(); $stream.CopyTo([System.IO.Stream]::Null); $stream.Dispose() }
    Write-Host "Natural Earth source archive: PASS ($entryCount entries read)" -ForegroundColor Green
} finally { $archive.Dispose() }
$feed = Invoke-RestMethod -Uri 'https://www.nhc.noaa.gov/CurrentStorms.json' -TimeoutSec 20 -Headers @{ 'User-Agent'='WindyHurricaneOverlay/1.1' }
$storm = @($feed.activeStorms | Where-Object { $_.name -ieq 'Polo' -or $_.id -ieq 'ep172026' })
if ($storm.Count -ne 1) { throw "Expected one active Polo record; found $($storm.Count)." }
Write-Host ("Live NHC feed: PASS ({0} {1}, advisory {2}, valid {3}, {4:N2} N {5:N2} W)" -f $storm[0].name,$storm[0].classification,$storm[0].publicAdvisory.advNum,$storm[0].lastUpdate,$storm[0].latitudeNumeric,[Math]::Abs($storm[0].longitudeNumeric)) -ForegroundColor Green
$kmzUrl = [string]$storm[0].forecastTrack.kmzFile
if ($kmzUrl -notmatch '^https://www\.nhc\.noaa\.gov/') { throw 'NHC forecast-track link failed HTTPS host validation.' }
$kmz = Invoke-WebRequest -Uri $kmzUrl -TimeoutSec 35 -Headers @{ 'User-Agent'='WindyHurricaneOverlay/1.1' }
$ms = [System.IO.MemoryStream]::new()
try {
    $kmz.RawContentStream.Position = 0
    $kmz.RawContentStream.CopyTo($ms); $ms.Position = 0
    $kz = [System.IO.Compression.ZipArchive]::new($ms,[System.IO.Compression.ZipArchiveMode]::Read,$true)
    try {
        $kml = @($kz.Entries | Where-Object { $_.FullName -match '(?i)\.kml$' } | Select-Object -First 1)
        if (-not $kml.Count) { throw 'Track KMZ contains no KML.' }
        Write-Host ("Official track KMZ: PASS ({0}; {1:N0} bytes)" -f $kml[0].FullName,$kml[0].Length) -ForegroundColor Green
    } finally { $kz.Dispose() }
} finally { $ms.Dispose(); if ($kmz.RawContentStream) { $kmz.RawContentStream.Dispose() } }
Write-Host 'Preflight complete. No overlay window was started.' -ForegroundColor Cyan

$type = [AppDomain]::CurrentDomain.GetAssemblies() | ForEach-Object { $_.GetTypes() } | Where-Object Name -eq 'WindyLandMask' | Select-Object -First 1`r`n$load = $type.GetMethod('Load',[System.Reflection.BindingFlags] 'Public,Static')`r`n$mask = $load.Invoke($null,@($landPath))
$type = [AppDomain]::CurrentDomain.GetAssemblies() | ForEach-Object { $_.GetTypes() } | Where-Object Name -eq 'WindyLandMask' | Select-Object -First 1
$flags = [System.Reflection.BindingFlags] 'Instance,NonPublic'
$method = $type.GetMethod('IsLand',$flags)
foreach ($point in @(@(-114.0,22.8),@(-113.0,22.8),@(-112.0,22.8),@(-111.0,22.8),@(-110.0,22.8),@(-116.0,32.0),@(-120.0,20.0),@(114.0,22.8))) {
    $isLand = $method.Invoke($mask,@([double]$point[0],[double]$point[1]))
    Write-Host ('land-mask test lon={0:F1}, lat={1:F1}: {2}' -f $point[0],$point[1],$isLand)
}

