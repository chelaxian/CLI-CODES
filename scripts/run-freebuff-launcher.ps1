[CmdletBinding()]
param()

# Freebuff launcher — прямой запуск без TUI-меню.
# Причина: встроенное псевдографическое меню Freebuff некорректно отрисовывается,
# если сначала отрисовать наш TUI-лаунчер. Поэтому сразу делируем управление
# Freebuff CLI, который сам покажет свой interactive picker.
$PSNativeCommandUseErrorActionPreference = $false
$ErrorActionPreference = "Stop"

function Resolve-FreebuffExe {
  # Prefer the npm .cmd wrapper: it spawns the Node CLI which drives the
  # interactive pseudo-graphical TUI. Calling the underlying native binary
  # (~/.config/manicode/freebuff.exe) directly bypasses Node's TTY handling
  # and the Freebuff TUI never renders.
  $cmd = Get-Command freebuff.cmd -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  $cmd = Get-Command freebuff -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  foreach ($p in @((Join-Path $env:APPDATA "npm\freebuff.cmd"), (Join-Path $env:APPDATA "npm\freebuff.ps1"))) {
    if (Test-Path -LiteralPath $p) { return $p }
  }
  return ""
}

$freebuffExe = Resolve-FreebuffExe
if (-not $freebuffExe) { throw "Freebuff CLI не найден. Установите: npm install -g freebuff" }

# Suppress auto-update checks so Freebuff doesn't try to dial home
# (which can cause ECONNRESET behind CDN-blocking regions).
$env:CODEBUFF_AUTO_UPDATE_DISABLED = "1"
$env:CODEBUFF_SKIP_UPDATE = "1"
$env:FREEBUFF_SKIP_UPDATE = "1"
$env:NPM_CONFIG_UPDATE_NOTIFIER = "false"
$env:NPM_CONFIG_FUND = "false"

$binPath = Join-Path $env:USERPROFILE ".config\manicode\freebuff.exe"
if (-not (Test-Path -LiteralPath $binPath)) {
  Write-Host "ВНИМАНИЕ: binary Freebuff (~50MB) отсутствует. Сейчас будет попытка скачивания" -ForegroundColor Yellow
  Write-Host "с https://codebuff.com. Если через 30 сек нет прогресса — CDN-блокировка;" -ForegroundColor Yellow
  Write-Host "включите VPN и повторите (binary качается один раз)." -ForegroundColor Yellow
  Write-Host ""
}

try {
  & $freebuffExe
} catch {
  # Ctrl+C / pipeline stopped — exit silently
  exit 0
}
exit 0
