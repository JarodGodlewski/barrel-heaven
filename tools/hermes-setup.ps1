# Birddog Softworks — Barrel Heaven Hermes studio
# From C:\Workspace\barrel-heaven:
#   powershell -File tools\hermes-setup.ps1

$ErrorActionPreference = "Stop"
$Root = Split-Path $PSScriptRoot -Parent
Set-Location $Root

Write-Host "=== Birddog Softworks / Barrel Heaven studio ===" -ForegroundColor Cyan

$compose = Join-Path $Root "hermes-docker\docker-compose.yml"
if (-not (Test-Path $compose)) {
    Write-Host "ERROR: missing $compose" -ForegroundColor Red
    exit 1
}

$Required = @(
    "studio\CONSTITUTION.md",
    "studio\roles\engine-builder.md",
    "studio\skills\pick-up-work\SKILL.md",
    "studio\products\barrel-heaven\profile.yaml",
    "studio\workflows\refill-prompt.txt",
    "studio\workflows\seed-catalog.yaml",
    "studio\workflows\model-policy.yaml"
)
$missing = @()
foreach ($rel in $Required) {
    if (-not (Test-Path (Join-Path $Root $rel))) { $missing += $rel }
}
if ($missing.Count -gt 0) {
    Write-Host "Missing studio files:" -ForegroundColor Red
    $missing | ForEach-Object { Write-Host "  $_" }
    exit 1
}

$running = docker container inspect -f "{{.State.Running}}" barrel-hermes 2>$null
if ($running -ne "true") {
    Write-Host "Starting barrel-hermes..." -ForegroundColor Yellow
    $keyLine = Select-String -LiteralPath (Join-Path $env:LOCALAPPDATA "hermes\.env") -Pattern '^XAI_API_KEY=' | Select-Object -First 1
    if ($null -ne $keyLine) {
        $env:XAI_API_KEY = $keyLine.Line.Substring("XAI_API_KEY=".Length)
    }
    docker compose -f $compose up -d
    if ($LASTEXITCODE -ne 0) { throw "docker compose failed" }
}

docker exec barrel-hermes python3 /workspace/barrel-heaven/tools/studio/install_hermes_studio.py
if ($LASTEXITCODE -ne 0) { throw "plugin install failed" }

docker exec barrel-hermes python3 /workspace/barrel-heaven/tools/studio/seed_kanban.py
if ($LASTEXITCODE -ne 0) { throw "kanban seed failed" }

Write-Host "Dashboard: http://127.0.0.1:9119/login  user=barrel  pass=heaven" -ForegroundColor Green
Write-Host "Board: barrel-heaven  |  Birddog Softworks"
