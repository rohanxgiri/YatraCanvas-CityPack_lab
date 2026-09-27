<#
.SYNOPSIS
  Unified CLI helper for YatraCanvas City Pack Curation Studio.
.DESCRIPTION
  Provides simple one-word commands for contributors: setup, start, test, summary.
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
    [string]$City = "jaipur"
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
        Write-Host "Exporting Certified City Pack for $City to DataFactory & YatraCanvas..." -ForegroundColor Cyan
        python "$PSScriptRoot\tools\export_certified_pack.py" --city $City
    }
    "help" {
        Write-Host "YatraCanvas City Lab Commands:" -ForegroundColor Cyan
        Write-Host "  .\citylab.ps1 setup                 Run initial dependency & asset setup"
        Write-Host "  .\citylab.ps1 start [-Target win|web] Launch Curation Studio (default: windows)"
        Write-Host "  .\citylab.ps1 summary -City <name>  Print / generate PR curation summary"
        Write-Host "  .\citylab.ps1 export -City <name>   Sync certified DB to YatraCanvas app & DataFactory"
        Write-Host "  .\citylab.ps1 test                  Run full automated test suite"
    }
}
