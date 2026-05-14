[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "launcher-tui.ps1")

function Resolve-FreebuffExe {
  $cmd = Get-Command freebuff.cmd -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  $cmd = Get-Command freebuff -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  foreach ($p in @((Join-Path $env:APPDATA "npm\freebuff.cmd"), (Join-Path $env:APPDATA "npm\freebuff.ps1"))) {
    if (Test-Path -LiteralPath $p) { return $p }
  }
  return ""
}

$items = @(
  [pscustomobject]@{ Id = "deepseek-v4-pro"; Label = "DeepSeek V4 Pro - smartest" },
  [pscustomobject]@{ Id = "deepseek-v4-flash"; Label = "DeepSeek V4 Flash - most efficient" },
  [pscustomobject]@{ Id = "kimi-k2.6"; Label = "Kimi K2.6 - balanced" },
  [pscustomobject]@{ Id = "minimax-m2.7"; Label = "MiniMax M2.7 - fastest" },
  [pscustomobject]@{ Id = "builtin"; Label = "Запустить Freebuff с встроенным выбором модели" }
)

$choice = Show-TuiFramedMenu -AppBrand "Freebuff" -Title "Freebuff - выбор модели" -Subtitle "DeepSeek V4 Pro/Flash · Kimi K2.6 · MiniMax M2.7" -Items $items
if (-not $choice) { return }

$freebuffExe = Resolve-FreebuffExe
if (-not $freebuffExe) { throw "Freebuff CLI не найден. Установите: npm install -g freebuff" }

switch ([string]$choice.Id) {
  "deepseek-v4-pro" { $env:FREEBUFF_MODEL = "deepseek-v4-pro" }
  "deepseek-v4-flash" { $env:FREEBUFF_MODEL = "deepseek-v4-flash" }
  "kimi-k2.6" { $env:FREEBUFF_MODEL = "kimi-k2.6" }
  "minimax-m2.7" { $env:FREEBUFF_MODEL = "minimax-m2.7" }
  default { Remove-Item Env:FREEBUFF_MODEL -ErrorAction SilentlyContinue }
}

Clear-Host
Write-Host "Запуск Freebuff..." -ForegroundColor Cyan
if ($env:FREEBUFF_MODEL) {
  Write-Host "Предпочтительная модель: $env:FREEBUFF_MODEL" -ForegroundColor DarkGray
  Write-Host "Если текущая версия Freebuff игнорирует env, выберите эту модель во встроенном меню." -ForegroundColor DarkGray
}
& $freebuffExe
