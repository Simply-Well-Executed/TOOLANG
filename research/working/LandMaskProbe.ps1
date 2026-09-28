$ErrorActionPreference = 'Stop'
$scriptPath = (Resolve-Path '.\outputs\WindyHurricaneOverlay\WindyHurricaneOverlay.ps1').Path
$scriptText = Get-Content -LiteralPath $scriptPath -Raw
$match = [regex]::Match($scriptText, '(?s)\$source\s*=\s*@''\r?\n(.*?)\r?\n''@\s*Add-Type\s+-TypeDefinition\s+\$source')
if (-not $match.Success) { throw 'Could not isolate C# source.' }
$source = $match.Groups[1].Value.Replace('internal sealed class WindyLandMask','public sealed class WindyLandMask').Replace('private bool IsLand(','public bool IsLand(')
Add-Type -TypeDefinition $source -Language CSharp
$landPath = (Resolve-Path '.\outputs\WindyHurricaneOverlay\data\ne_10m_land.shp').Path
$mask = [WindyLandMask]::Load($landPath)
foreach ($point in @(@(-114.0,22.8),@(-113.0,22.8),@(-112.0,22.8),@(-111.0,22.8),@(-110.0,22.8),@(-116.0,32.0),@(-120.0,20.0),@(114.0,22.8),@(0.0,0.0),@(180.0,0.0),@(-140.0,0.0),@(-40.0,0.0),@(10.0,0.0),@(10.0,40.0))) {
    Write-Host ('land-mask test lon={0:F1}, lat={1:F1}: {2}' -f $point[0],$point[1],$mask.IsLand([double]$point[0],[double]$point[1]))
}

$land = $mask.FindNearestLand(22.8,-114.0,3000.0)
if (-not $mask.IsLand($land.LandLongitude,$land.LandLatitude)) { throw 'Gold point did not validate as land.' }
Write-Host ("Verified Polo water-to-land point: center (22.800,-114.000), coast ({0:F3},{1:F3}), gold land ({2:F3},{3:F3}), coast range {4:F1} km, inland offset {5:F1} km" -f $land.CoastLatitude,$land.CoastLongitude,$land.LandLatitude,$land.LandLongitude,$land.CoastDistanceKm,$land.InlandDistanceKm) -ForegroundColor Green
