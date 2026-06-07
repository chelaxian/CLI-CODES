# cloud-code-setup - 1-click Windows installer
# Usage (PowerShell 5.1+):
#   [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; irm https://raw.githubusercontent.com/chelaxian/cloud-code-setup/main/install.ps1 | iex
# If `irm` fails with "Базовое соединение закрыто", use the curl.exe fallback:
#   curl.exe -fsSL https://raw.githubusercontent.com/chelaxian/cloud-code-setup/main/install.ps1 | powershell.exe -NoProfile -ExecutionPolicy Bypass -Command -

try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.ServicePointManager]::SecurityProtocol } catch {}

# Cache-buster: ensures GitHub raw CDN returns the latest commit, not a stale
# cached version. Prevents 'install.ps1 ran old code' issues after a fresh push.
$cacheBust = "?t=$([DateTime]::UtcTicks)"

# Prefer the local install-full.ps1 if the repo is cloned — it's always current
# and avoids CDN lag entirely. Only download from GitHub if no local copy exists.
$localRepo = Join-Path $env:USERPROFILE "cloud-code-setup"
$localInstallFull = Join-Path $localRepo "install-full.ps1"

if (Test-Path -LiteralPath $localInstallFull) {
    # Local copy: always up-to-date after `git pull`. Safer than CDN.
    Write-Host ""
    Write-Host "  cloud-code-setup :: запуск локального install-full.ps1" -ForegroundColor Cyan
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $localInstallFull
    exit $LASTEXITCODE
}

# No local copy → bootstrap: download from GitHub.
$tmpFile = Join-Path $env:TEMP "cloud-code-setup-installer.ps1"
$url = "https://raw.githubusercontent.com/chelaxian/cloud-code-setup/main/install-full.ps1$cacheBust"

Write-Host ""
Write-Host "  cloud-code-setup :: downloading installer..." -ForegroundColor Cyan

try {
    Invoke-WebRequest -Uri $url -OutFile $tmpFile -UseBasicParsing
} catch {
    Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "  TLS error? Run this first:" -ForegroundColor Yellow
    Write-Host "  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12" -ForegroundColor White
    Read-Host "Press Enter to exit"
    return
}

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $tmpFile
$exitCode = $LASTEXITCODE
Remove-Item -LiteralPath $tmpFile -Force -ErrorAction SilentlyContinue
exit $exitCode
