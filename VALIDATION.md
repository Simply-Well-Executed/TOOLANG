# Validation

Run the dependency-free validation harness from the project root:

```powershell
pwsh -NoProfile -File .\validation\validate.ps1
```

It parses `TOOLANG.ps1`, extracts and compiles the embedded C# with PowerShell `Add-Type`, and runs focused checks for the Windy map URL parser and the C# map-scale calculation. It does not start the overlay or make network requests.

The runner writes machine-readable results, tool versions, the validated source hash, and artifact paths to [`validation/validation-results.json`](validation/validation-results.json). The runner itself is [`validation/validate.ps1`](validation/validate.ps1).

There were no pre-existing unit-test files or configured unit-test/type-check commands when this harness was added. No static PowerShell type checker or coverage tooling is configured. PowerShell parser success is not a static type check; embedded C# compilation validates the C# types only. Chrome/UI Automation, Win32/GDI rendering, and live NHC network behavior are outside this harness.
