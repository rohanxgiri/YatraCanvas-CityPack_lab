<#
.SYNOPSIS
  Launch script for YatraCanvas City Pack Curation Studio.
.DESCRIPTION
  Validates assets and starts the Flutter application on Windows Desktop or Chrome.
.PARAMETER Target
  Device target to run on: 'windows' (default) or 'chrome'.
.EXAMPLE
  .\scripts\start-city-lab.ps1
  .\scripts\start-city-lab.ps1 -Target chrome
#>

[CmdletBinding()]
param(
    [ValidateSet("windows", "chrome")]
    [string]$Target = "windows"
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  Starting YatraCanvas City Pack Curation Studio          " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Check assets directory
$assetPacksPath = Join-Path $PSScriptRoot "..\assets\city_packs"
if (-not (Test-Path $assetPacksPath)) {
    Write-Error "Assets directory not found at $assetPacksPath. Run .\scripts\setup-city-lab.ps1 first."
    exit 1
}

# 2. Check for at least one city pack
$packs = Get-ChildItem -Path $assetPacksPath -Directory
if ($packs.Count -eq 0) {
    Write-Warning "No city packs found in $assetPacksPath. Run 'python tools/sync_city_packs.py --cities Jaipur' first."
    exit 1
}

Write-Host "Found $($packs.Count) city pack(s) ready for curation." -ForegroundColor Green
Write-Host "Selected Target Device: $Target" -ForegroundColor Yellow
Write-Host ""
Write-Host "Launching Flutter..." -ForegroundColor White

if ($Target -eq "windows") {
    flutter run -d windows
} else {
    flutter run -d chrome
}
