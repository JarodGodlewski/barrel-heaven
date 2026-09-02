$ErrorActionPreference = "Stop"
$src = Join-Path $env:LOCALAPPDATA "hermes\.env"
$line = Select-String -LiteralPath $src -Pattern '^XAI_API_KEY=' | Select-Object -First 1
if ($null -eq $line) { throw "XAI_API_KEY missing in $src" }
$env:XAI_API_KEY = $line.Line.Substring("XAI_API_KEY=".Length)

$compose = Join-Path $PSScriptRoot "docker-compose.yml"
Write-Host "Recreating barrel-hermes on xAI + Ollama..."
docker compose -f $compose up -d --force-recreate
if ($LASTEXITCODE -ne 0) { throw "docker compose failed" }

$deadline = (Get-Date).AddSeconds(90)
do {
  Start-Sleep -Seconds 3
  $st = docker inspect barrel-hermes --format "{{.State.Health.Status}}"
  Write-Host "health: $st"
} while ($st -ne "healthy" -and (Get-Date) -lt $deadline)

docker cp (Join-Path $PSScriptRoot "patch_studio_config.py") barrel-hermes:/tmp/patch_studio_config.py
docker exec barrel-hermes python3 /tmp/patch_studio_config.py
docker cp (Join-Path $PSScriptRoot "patch_dashboard_sso.py") barrel-hermes:/tmp/patch_dashboard_sso.py
docker exec barrel-hermes python3 /tmp/patch_dashboard_sso.py
docker exec barrel-hermes pkill -f "hermes dashboard" | Out-Null
Write-Host "Studio recreated. Dashboard: http://127.0.0.1:9119/login  user=barrel"
