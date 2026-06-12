param(
    [string]$AddonsPath
)

$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$Source = Join-Path $RepoRoot "DailyPlaner"
$ConfigPath = Join-Path $RepoRoot "deploy.local.json"

if (-not $AddonsPath -and (Test-Path $ConfigPath)) {
    $config = Get-Content $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $AddonsPath = $config.addonsPath
}

if (-not $AddonsPath) {
    Write-Host "AddOns path is not set." -ForegroundColor Red
    Write-Host ""
    Write-Host "Create deploy.local.json in the project root (see deploy.local.json.example)"
    Write-Host "or run: .\scripts\deploy.ps1 -AddonsPath 'F:\...\Interface\AddOns'"
    exit 1
}

if (-not (Test-Path $Source)) {
    Write-Error "Addon source not found: $Source"
}

if (-not (Test-Path $AddonsPath)) {
    Write-Error "AddOns folder not found: $AddonsPath"
}

$Target = Join-Path $AddonsPath "DailyPlaner"

Write-Host "Deploying Daily Planer" -ForegroundColor Cyan
Write-Host "  from: $Source"
Write-Host "  to:   $Target"
Write-Host ""

if (Test-Path $Target) {
    Remove-Item $Target -Recurse -Force
}

Copy-Item $Source $Target -Recurse -Force

Write-Host "Done. Reload UI in game: /reload" -ForegroundColor Green
