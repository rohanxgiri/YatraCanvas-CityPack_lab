<#
.SYNOPSIS
  Setup script for YatraCanvas City Pack Curation Studio.
.DESCRIPTION
  Verifies development environment, Flutter installation, project dependencies,
  and local City Pack assets for YatraCanvas-CityPack-Lab.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  YatraCanvas City Pack Curation Studio - Setup Script   " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Check Git
Write-Host "[1/5] Checking Git installation..." -ForegroundColor Yellow
try {
    $gitVersion = git --version
    Write-Host "  OK: $gitVersion" -ForegroundColor Green
} catch {
    Write-Error "Git is not installed or not in PATH. Please install Git: https://git-scm.com/"
    exit 1
}

# 2. Check Flutter
Write-Host "[2/5] Checking Flutter SDK..." -ForegroundColor Yellow
try {
    $flutterVersion = flutter --version | Select-Object -First 1
    Write-Host "  OK: $flutterVersion" -ForegroundColor Green
} catch {
    Write-Error "Flutter is not installed or not in PATH. Please install Flutter SDK: https://flutter.dev/docs/get-started/install"
    exit 1
}

# 3. Check Connected Devices
Write-Host "[3/5] Checking available execution targets..." -ForegroundColor Yellow
$devices = flutter devices
Write-Host "$devices"
if ($devices -match "windows") {
    Write-Host "  Target available: Windows Desktop (Recommended)" -ForegroundColor Green
} elseif ($devices -match "chrome") {
    Write-Host "  Target available: Google Chrome Web" -ForegroundColor Green
} else {
    Write-Host "  Warning: Neither Windows Desktop nor Chrome were detected." -ForegroundColor DarkYellow
    Write-Host "  Run 'flutter doctor' to configure your environment." -ForegroundColor DarkYellow
}

# 4. Resolve Flutter Dependencies
Write-Host "[4/5] Installing Flutter project dependencies..." -ForegroundColor Yellow
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to run 'flutter pub get'. Please resolve package dependencies."
    exit $LASTEXITCODE
}
Write-Host "  OK: Dependencies up to date." -ForegroundColor Green

# 5. Verify City Pack Assets
Write-Host "[5/5] Verifying local City Pack assets..." -ForegroundColor Yellow
$assetPacksPath = Join-Path $PSScriptRoot "..\assets\city_packs"
if (-not (Test-Path $assetPacksPath)) {
    Write-Error "Missing assets/city_packs directory! Please run 'python tools/sync_city_packs.py' to sync packs from DataFactory."
    exit 1
}

$packs = Get-ChildItem -Path $assetPacksPath -Directory
if ($packs.Count -eq 0) {
    Write-Warning "No city packs found in $assetPacksPath. Run 'python tools/sync_city_packs.py --cities Jaipur' to sync."
} else {
    Write-Host "  Found $($packs.Count) city pack(s):" -ForegroundColor Green
    foreach ($pack in $packs) {
        $dbFile = Join-Path $pack.FullName "yatracanvas.db"
        $manifest = Join-Path $pack.FullName "manifest.json"
        $curationDir = Join-Path $pack.FullName "curation"
        
        $hasDb = Test-Path $dbFile
        $hasManifest = Test-Path $manifest
        $hasCuration = Test-Path $curationDir
        
        if ($hasDb -and $hasManifest) {
            Write-Host "    - $($pack.Name) [DB: OK, Manifest: OK, Curation: $(if ($hasCuration) {'Present'} else {'None'})]" -ForegroundColor Green
        } else {
            Write-Host "    - $($pack.Name) [INCOMPLETE: DB=$hasDb, Manifest=$hasManifest]" -ForegroundColor Red
        }
    }
}

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  Setup completed successfully!                           " -ForegroundColor Green
Write-Host "  Launch City Lab by running:                             " -ForegroundColor White
Write-Host "    .\scripts\start-city-lab.ps1                          " -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Cyan
