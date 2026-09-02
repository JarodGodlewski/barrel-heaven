# Tail Godot play log. Run this, then play from the editor. Ctrl+C to stop.

$log = Join-Path $env:APPDATA "Godot\app_userdata\Barrel Heaven\logs\godot.log"
$qa = Join-Path $env:APPDATA "Godot\app_userdata\Barrel Heaven\qa_errors.log"
Write-Host "Tailing $log"
if (-not (Test-Path -LiteralPath $log)) {
  New-Item -ItemType File -Path $log -Force | Out-Null
}
Get-Content -LiteralPath $log -Wait -Tail 30 | ForEach-Object {
  if ($_ -match "SCRIPT ERROR|Parse Error|Invalid access|ERROR:") {
    Write-Host $_ -ForegroundColor Red
  } elseif ($_ -match "WARNING:") {
    Write-Host $_ -ForegroundColor Yellow
  } else {
    Write-Host $_
  }
}
