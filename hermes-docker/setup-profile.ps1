# Copy XAI_API_KEY from the default Hermes home into the barrel-heaven profile.
# Does not copy OpenRouter, Discord, or other keys.

$ErrorActionPreference = "Stop"
$src = Join-Path $env:LOCALAPPDATA "hermes\.env"
$dstDir = Join-Path $env:LOCALAPPDATA "hermes\profiles\barrel-heaven"
$dst = Join-Path $dstDir ".env"

if (-not (Test-Path -LiteralPath $src)) {
  throw "Missing $src"
}
if (-not (Test-Path -LiteralPath $dstDir)) {
  throw "Missing profile dir $dstDir"
}

$line = Select-String -LiteralPath $src -Pattern '^XAI_API_KEY=' | Select-Object -First 1
if ($null -eq $line) {
  throw "XAI_API_KEY not found in $src"
}

@(
  "# Barrel Heaven Hermes profile - xAI + local Ollama only"
  $line.Line
) | Set-Content -LiteralPath $dst -Encoding utf8

Write-Host "Wrote $dst (XAI_API_KEY only)"
