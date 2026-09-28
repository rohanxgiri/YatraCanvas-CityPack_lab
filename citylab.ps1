<#
.SYNOPSIS
  Unified CLI helper for YatraCanvas City Pack Curation Studio.
.DESCRIPTION
  Provides commands for setup, running, testing, curation summaries, and explicit certification.
.EXAMPLE
  .\citylab.ps1 setup
  .\citylab.ps1 start
  .\citylab.ps1 summary -City jaipur
  .\citylab.ps1 test
#>

[CmdletBinding()]
param(
    [ValidateSet("start", "setup", "test", "summary", "export", "help")]
    [string]$Command = "start",

    [string]$Target = "windows",
    [string]$City = "jaipur",
    [string]$ReleaseEvidence,
    [string]$OutputDir,
    [switch]$ForceDevExport,
    [switch]$Publish
)

$ErrorActionPreference = "Stop"

switch ($Command) {
    "setup" {
        & "$PSScriptRoot\scripts\setup-city-lab.ps1"
    }
    "start" {
        & "$PSScriptRoot\scripts\start-city-lab.ps1" -Target $Target
    }
    "test" {
        Write-Host "Running YatraCanvas City Lab Test Suite..." -ForegroundColor Cyan
        flutter test
    }
    "summary" {
        Write-Host "Generating Curation Summary for $City..." -ForegroundColor Cyan
        python "$PSScriptRoot\tools\summarize_curation.py" --city $City
    }
    "export" {
        if ($ForceDevExport -and $Publish) {
            throw "-ForceDevExport cannot be combined with -Publish."
        }
        if (-not $ForceDevExport -and [string]::IsNullOrWhiteSpace($ReleaseEvidence)) {
            throw "Production certification requires -ReleaseEvidence. Use -ForceDevExport only for local non-certified output."
        }

        $exportArgs = @("$PSScriptRoot\tools\export_certified_pack.py", "--city", $City)
        if (-not [string]::IsNullOrWhiteSpace($ReleaseEvidence)) {
            $exportArgs += @("--release-evidence", $ReleaseEvidence)
        }
        if (-not [string]::IsNullOrWhiteSpace($OutputDir)) {
            $exportArgs += @("--output-dir", $OutputDir)
        }
        if ($ForceDevExport) {
            $exportArgs += "--force-dev-export"
        }
        if ($Publish) {
            $exportArgs += "--publish"
        }

        Write-Host "Running fail-closed certification for $City..." -ForegroundColor Cyan
        & python @exportArgs
        if ($LASTEXITCODE -ne 0) {
            throw "City Pack certification failed with exit code $LASTEXITCODE."
        }
    }
    "help" {
        Write-Host "YatraCanvas City Lab Commands:" -ForegroundColor Cyan
        Write-Host "  .\citylab.ps1 setup                 Run initial dependency & asset setup"
        Write-Host "  .\citylab.ps1 start [-Target win|web] Launch Curation Studio (default: windows)"
        Write-Host "  .\citylab.ps1 summary -City <name>  Print / generate PR curation summary"
        Write-Host "  .\citylab.ps1 export -City <name> -ReleaseEvidence <path> [-OutputDir <path>] [-Publish]"
        Write-Host "  .\citylab.ps1 export -City <name> -ForceDevExport [-OutputDir <path>]"
        Write-Host "  .\citylab.ps1 test                  Run full automated test suite"
    }
}
