#requires -Version 7.0

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$sourcePath = Join-Path $projectRoot 'TOOLANG.ps1'
$reportPath = Join-Path $PSScriptRoot 'validation-results.json'
$script:ValidationResults = [System.Collections.Generic.List[object]]::new()
$script:ProjectAst = $null
$script:MapParserLoaded = $false
$script:CSharpCompiled = $false

function Add-ValidationResult {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][ValidateSet('passed', 'failed', 'skipped')][string]$Status,
        [Parameter(Mandatory)][string]$Details
    )

    $script:ValidationResults.Add([pscustomobject]@{
        name = $Name
        status = $Status
        details = $Details
    })
}

function Invoke-ValidationCheck {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][scriptblock]$Test
    )

    try {
        $details = [string](& $Test)
        if ([string]::IsNullOrWhiteSpace($details)) { $details = 'Passed' }
        Add-ValidationResult -Name $Name -Status 'passed' -Details $details
    }
    catch {
        Add-ValidationResult -Name $Name -Status 'failed' -Details $_.Exception.Message
    }
}

function Assert-NumericEqual {
    param(
        [Parameter(Mandatory)][double]$Expected,
        [Parameter(Mandatory)][double]$Actual,
        [Parameter(Mandatory)][string]$Label,
        [double]$Tolerance = 0.000001
    )

    if ([double]::IsNaN($Actual) -or [Math]::Abs($Expected - $Actual) -gt $Tolerance) {
        throw "$Label expected $Expected but received $Actual."
    }
}

Invoke-ValidationCheck -Name 'PowerShell source syntax' -Test {
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw 'TOOLANG.ps1 was not found.'
    }

    $tokens = $null
    $parseErrors = $null
    $script:ProjectAst = [System.Management.Automation.Language.Parser]::ParseFile(
        $sourcePath, [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors.Count -gt 0) {
        $messages = ($parseErrors | ForEach-Object { $_.Message }) -join '; '
        throw "$($parseErrors.Count) parser error(s): $messages"
    }
    '0 parser errors'
}

if ($null -ne $script:ProjectAst) {
    try {
        $mapFunction = $script:ProjectAst.Find({
            param($node)
            $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
            $node.Name -eq 'ConvertTo-WindyMapView'
        }, $true)
        if ($null -eq $mapFunction) { throw 'ConvertTo-WindyMapView was not found.' }
        . ([scriptblock]::Create($mapFunction.Extent.Text))
        $script:MapParserLoaded = $true
        Add-ValidationResult -Name 'Isolate Windy map parser' -Status 'passed' -Details 'Loaded the function AST without running application startup.'
    }
    catch {
        Add-ValidationResult -Name 'Isolate Windy map parser' -Status 'failed' -Details $_.Exception.Message
    }

    Invoke-ValidationCheck -Name 'Embedded C# compilation and type validation' -Test {
        $sourceAssignment = $script:ProjectAst.Find({
            param($node)
            $node -is [System.Management.Automation.Language.AssignmentStatementAst] -and
            $node.Left -is [System.Management.Automation.Language.VariableExpressionAst] -and
            $node.Left.VariablePath.UserPath -eq 'source'
        }, $true)
        if ($null -eq $sourceAssignment -or
            $sourceAssignment.Right -isnot [System.Management.Automation.Language.CommandExpressionAst] -or
            $sourceAssignment.Right.Expression -isnot [System.Management.Automation.Language.StringConstantExpressionAst]) {
            throw 'Could not locate the embedded C# here-string.'
        }

        $csharpSource = $sourceAssignment.Right.Expression.Value
        Add-Type -TypeDefinition $csharpSource -Language CSharp -ErrorAction Stop | Out-Null
        $script:CSharpCompiled = $true
        "Compiled embedded C# source ($($csharpSource.Length) characters)."
    }
}
else {
    Add-ValidationResult -Name 'Isolate Windy map parser' -Status 'skipped' -Details 'Source parsing failed.'
    Add-ValidationResult -Name 'Embedded C# compilation and type validation' -Status 'skipped' -Details 'Source parsing failed.'
}

if ($script:MapParserLoaded) {
    Invoke-ValidationCheck -Name 'Windy map parser accepts HTTPS coordinates' -Test {
        $map = ConvertTo-WindyMapView -Url 'https://www.windy.com/?21.584,-113.955,7'
        if ($null -eq $map) { throw 'Expected a parsed map view.' }
        Assert-NumericEqual -Expected 21.584 -Actual $map.Latitude -Label 'Latitude'
        Assert-NumericEqual -Expected -113.955 -Actual $map.Longitude -Label 'Longitude'
        Assert-NumericEqual -Expected 7 -Actual $map.Zoom -Label 'Zoom'
        'Parsed latitude, longitude, and zoom.'
    }

    Invoke-ValidationCheck -Name 'Windy map parser accepts scheme-less address-bar URLs' -Test {
        $map = ConvertTo-WindyMapView -Url 'www.windy.com/?-12.5,179.75,8.25'
        if ($null -eq $map) { throw 'Expected a parsed scheme-less map view.' }
        Assert-NumericEqual -Expected -12.5 -Actual $map.Latitude -Label 'Latitude'
        Assert-NumericEqual -Expected 179.75 -Actual $map.Longitude -Label 'Longitude'
        Assert-NumericEqual -Expected 8.25 -Actual $map.Zoom -Label 'Zoom'
        'Parsed scheme-less latitude, longitude, and zoom.'
    }

    Invoke-ValidationCheck -Name 'Windy map parser accepts projection boundaries' -Test {
        $map = ConvertTo-WindyMapView -Url 'https://windy.com/?85.05112878,180,22'
        if ($null -eq $map) { throw 'Expected inclusive projection limits to be accepted.' }
        Assert-NumericEqual -Expected 85.05112878 -Actual $map.Latitude -Label 'Maximum latitude'
        Assert-NumericEqual -Expected 180 -Actual $map.Longitude -Label 'Maximum longitude'
        Assert-NumericEqual -Expected 22 -Actual $map.Zoom -Label 'Maximum zoom'
        'Accepted inclusive latitude, longitude, and zoom limits.'
    }

    foreach ($case in @(
        [pscustomobject]@{ Name = 'foreign host'; Url = 'https://example.com/?21,-113,7' },
        [pscustomobject]@{ Name = 'latitude outside Web Mercator'; Url = 'https://www.windy.com/?90,0,7' },
        [pscustomobject]@{ Name = 'longitude outside range'; Url = 'https://www.windy.com/?0,181,7' },
        [pscustomobject]@{ Name = 'zoom outside range'; Url = 'https://www.windy.com/?0,0,23' },
        [pscustomobject]@{ Name = 'malformed coordinates'; Url = 'https://www.windy.com/?north,west,zoom' }
    )) {
        $caseName = $case.Name
        $caseUrl = $case.Url
        Invoke-ValidationCheck -Name "Windy map parser rejects $caseName" -Test {
            $map = ConvertTo-WindyMapView -Url $caseUrl
            if ($null -ne $map) { throw "Unexpectedly accepted $caseUrl." }
            "Rejected $caseName."
        }
    }
}
else {
    Add-ValidationResult -Name 'Windy map parser unit checks' -Status 'skipped' -Details 'Map parser could not be isolated.'
}

if ($script:CSharpCompiled) {
    Invoke-ValidationCheck -Name 'C# map scale at equator and zoom zero' -Test {
        $actual = [WindyHurricaneOverlay]::MapMetersPerPixel(0.0, 0.0, 1.0)
        $expected = 40075016.68557849 / 256.0
        Assert-NumericEqual -Expected $expected -Actual $actual -Label 'Equatorial map scale' -Tolerance 0.0001
        "$actual meters per pixel."
    }

    Invoke-ValidationCheck -Name 'C# map scale adjusts for latitude' -Test {
        $equator = [WindyHurricaneOverlay]::MapMetersPerPixel(0.0, 0.0, 1.0)
        $sixtyDegrees = [WindyHurricaneOverlay]::MapMetersPerPixel(60.0, 0.0, 1.0)
        Assert-NumericEqual -Expected 0.5 -Actual ($sixtyDegrees / $equator) -Label '60-degree scale ratio' -Tolerance 0.000000000001
        '60-degree scale is half the equatorial scale.'
    }

    Invoke-ValidationCheck -Name 'C# map scale adjusts for zoom and DPI' -Test {
        $base = [WindyHurricaneOverlay]::MapMetersPerPixel(0.0, 0.0, 1.0)
        $zoomed = [WindyHurricaneOverlay]::MapMetersPerPixel(0.0, 1.0, 1.0)
        $highDpi = [WindyHurricaneOverlay]::MapMetersPerPixel(0.0, 0.0, 2.0)
        Assert-NumericEqual -Expected 0.5 -Actual ($zoomed / $base) -Label 'Zoom scale ratio' -Tolerance 0.000000000001
        Assert-NumericEqual -Expected 0.5 -Actual ($highDpi / $base) -Label 'DPI scale ratio' -Tolerance 0.000000000001
        'One zoom level and 2x DPI each halve meters per pixel.'
    }

    Invoke-ValidationCheck -Name 'C# map scale clamps latitude to projection limit' -Test {
        $atLimit = [WindyHurricaneOverlay]::MapMetersPerPixel(85.05112878, 0.0, 1.0)
        $beyondLimit = [WindyHurricaneOverlay]::MapMetersPerPixel(90.0, 0.0, 1.0)
        Assert-NumericEqual -Expected $atLimit -Actual $beyondLimit -Label 'Clamped latitude scale' -Tolerance 0.000000001
        'Latitudes beyond the projection limit are clamped.'
    }

    Invoke-ValidationCheck -Name 'C# map scale rejects nonpositive DPI' -Test {
        $threwExpectedException = $false
        try {
            [WindyHurricaneOverlay]::MapMetersPerPixel(0.0, 0.0, 0.0) | Out-Null
        }
        catch {
            $exception = $_.Exception
            while ($null -ne $exception -and
                $exception -isnot [System.ArgumentOutOfRangeException]) {
                $exception = $exception.InnerException
            }
            if ($null -eq $exception) { throw }
            $threwExpectedException = $true
        }
        if (-not $threwExpectedException) { throw 'Expected ArgumentOutOfRangeException for dpiScale=0.' }
        'Rejected zero DPI scale with ArgumentOutOfRangeException.'
    }
}
else {
    Add-ValidationResult -Name 'C# map-scale unit checks' -Status 'skipped' -Details 'Embedded C# did not compile.'
}

$existingUnitTests = @(
    Get-ChildItem -LiteralPath $projectRoot -Filter '*.Tests.ps1' -File -Recurse |
        ForEach-Object { $_.FullName.Substring($projectRoot.Length).TrimStart('\') }
)
$limitations = @(
    'No pre-existing project unit-test or type-check command or unit-test files were configured; focused checks are provided by this runner.'
    'No static PowerShell type checker is configured; the script was parser-validated and its embedded C# was compiled.'
)
$passedCount = @($script:ValidationResults | Where-Object status -eq 'passed').Count
$failedCount = @($script:ValidationResults | Where-Object status -eq 'failed').Count
$skippedCount = @($script:ValidationResults | Where-Object status -eq 'skipped').Count
$overallStatus = if ($failedCount -gt 0) {
    'failed'
} elseif ($skippedCount -gt 0 -or $limitations.Count -gt 0) {
    'passed_with_limitations'
} else {
    'passed'
}
$scriptHash = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
$report = [pscustomobject][ordered]@{
    schemaVersion = 1
    project = 'TOOLANG'
    generatedAtUtc = [DateTimeOffset]::UtcNow.ToString('O')
    status = $overallStatus
    command = 'pwsh -NoProfile -File .\validation\validate.ps1'
    toolVersions = [pscustomobject][ordered]@{
        powerShell = $PSVersionTable.PSVersion.ToString()
        powerShellEdition = $PSVersionTable.PSEdition
        dotNetRuntime = [System.Runtime.InteropServices.RuntimeInformation]::FrameworkDescription
    }
    projectCommands = [pscustomobject][ordered]@{
        unitTests = $null
        typeCheck = $null
        notes = 'No pre-existing unit-test files or unit/type-check commands are configured.'
    }
    coverage = [pscustomobject][ordered]@{
        supported = $false
        notes = 'No project coverage or test-reporting tooling is configured.'
    }
    typeValidation = [pscustomobject][ordered]@{
        powerShell = 'Parser validation only; no static PowerShell type-check command is configured.'
        embeddedCSharp = if ($script:CSharpCompiled) { 'passed: compiled with PowerShell Add-Type' } else { 'failed or skipped' }
    }
    source = [pscustomobject][ordered]@{
        path = 'TOOLANG.ps1'
        sha256 = $scriptHash
    }
    summary = [pscustomobject][ordered]@{
        passed = $passedCount
        failed = $failedCount
        skipped = $skippedCount
    }
    limitations = $limitations
    existingUnitTestFiles = $existingUnitTests
    artifactPaths = @(
        'validation\validate.ps1',
        'validation\validation-results.json'
    )
    checks = @($script:ValidationResults)
}

$json = ConvertTo-Json -InputObject $report -Depth 8
[System.IO.File]::WriteAllText($reportPath, $json + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))

Write-Host "Validation result: $overallStatus ($passedCount passed, $failedCount failed, $skippedCount skipped)"
Write-Host 'Artifact: validation\validation-results.json'
if ($failedCount -gt 0) { exit 1 }
