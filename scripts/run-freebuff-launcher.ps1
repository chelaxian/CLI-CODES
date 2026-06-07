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

# Согласно Freebuff FAQ (https://github.com/CodebuffAI/codebuff/blob/main/freebuff/README.md):
#   "DeepSeek V4 Pro (smartest) or DeepSeek V4 Flash as the main coding agent.
#    Gemini 3.1 Flash Lite handles file finding and research,
#    GPT-5.4 handles deep thinking if you connect your ChatGPT subscription."
# ПРИМЕЧАНИЕ: Freebuff CLI не документирует env-переменную FREEBUFF_MODEL — presetы ниже
# основаны на названиях моделей из FAQ и могут не влиять на реальный выбор (Freebuff автоматически
# подбирает модель под задачу). В случае игнорирования Freebuff просто использует свой default.
$items = @(
  [pscustomobject]@{ Id = "deepseek-v4-pro";   Label = "DeepSeek V4 Pro - smartest (основной agent)" },
  [pscustomobject]@{ Id = "deepseek-v4-flash"; Label = "DeepSeek V4 Flash - most efficient (основной agent)" },
  [pscustomobject]@{ Id = "gpt-5.4";           Label = "GPT-5.4 - deep thinking (нужна подписка ChatGPT)" },
  [pscustomobject]@{ Id = "builtin";           Label = "Запустить Freebuff с встроенным выбором модели" }
)

$choice = Show-TuiFramedMenu -AppBrand "Freebuff" -Title "Freebuff - выбор модели" -Subtitle "DeepSeek V4 Pro/Flash (main) · GPT-5.4 (deep thinking с ChatGPT)" -Items $items
if (-not $choice) { return }

$freebuffExe = Resolve-FreebuffExe
if (-not $freebuffExe) { throw "Freebuff CLI не найден. Установите: npm install -g freebuff" }

switch ([string]$choice.Id) {
  "deepseek-v4-pro"   { $env:FREEBUFF_MODEL = "deepseek-v4-pro" }
  "deepseek-v4-flash" { $env:FREEBUFF_MODEL = "deepseek-v4-flash" }
  "gpt-5.4"           { $env:FREEBUFF_MODEL = "gpt-5.4" }
  default             { Remove-Item Env:FREEBUFF_MODEL -ErrorAction SilentlyContinue }
}

Clear-Host
Write-Host "Запуск Freebuff..." -ForegroundColor Cyan
if ($env:FREEBUFF_MODEL) {
  Write-Host "Предпочтительная модель: $env:FREEBUFF_MODEL" -ForegroundColor DarkGray
  Write-Host "Freebuff автоматически выбирает модель под задачу (file picker, planner, editor)." -ForegroundColor DarkGray
  Write-Host "Если текущая версия Freebuff игнорирует FREEBUFF_MODEL, используйте встроенный выбор." -ForegroundColor DarkGray
}
& $freebuffExe
