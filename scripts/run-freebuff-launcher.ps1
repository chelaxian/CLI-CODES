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

$freebuffExe = Resolve-FreebuffExe
if (-not $freebuffExe) { throw "Freebuff CLI не найден. Установите: npm install -g freebuff" }

function Invoke-FreebuffRun {
  param([string]$ModelId)

  # Сбрасываем env от предыдущих запусков
  Remove-Item Env:FREEBUFF_MODEL -ErrorAction SilentlyContinue

  if ($ModelId -and $ModelId -ne "builtin") {
    $env:FREEBUFF_MODEL = $ModelId
  }

  # Подавляем авто-обновление freebuff CLI / Codebuff. ECONNRESET при старте
  # обычно означает, что freebuff пытается скачать обновление агентов/моделей.
  # Эти env переменные попытка отключить HTTP-проверки обновлений.
  $env:CODEBUFF_AUTO_UPDATE_DISABLED = "1"
  $env:CODEBUFF_SKIP_UPDATE = "1"
  $env:FREEBUFF_SKIP_UPDATE = "1"
  $env:NPM_CONFIG_UPDATE_NOTIFIER = "true"
  $env:NPM_CONFIG_FUND = "false"

  Clear-Host
  Write-Host "Запуск Freebuff..." -ForegroundColor Cyan
  if ($env:FREEBUFF_MODEL) {
    Write-Host "Предпочтительная модель: $env:FREEBUFF_MODEL" -ForegroundColor DarkGray
    Write-Host "Freebuff автоматически выбирает модель под задачу (file picker, planner, editor)." -ForegroundColor DarkGray
    Write-Host "Если текущая версия Freebuff игнорирует FREEBUFF_MODEL, используйте встроенный выбор." -ForegroundColor DarkGray
  }

  # Обёртка с retry для сетевых ошибок (ECONNRESET и подобных).
  $maxRetries = 2
  $attempt = 0
  while ($true) {
    $attempt++
    & $freebuffExe
    $exitCode = $LASTEXITCODE

    if ($exitCode -eq 0) { return $true }

    # Не network-ошибка — не retry
    if ($attempt -ge $maxRetries) {
      Write-Host ""
      Write-Host "Freebuff завершился с кодом $exitCode." -ForegroundColor Yellow
      Write-Host "Если была сетевая ошибка (ECONNRESET/timeout) — проверьте интернет и попробуйте снова." -ForegroundColor Yellow
      Write-Host "Помочь может ручное обновление Freebuff: npm i -g freebuff@latest" -ForegroundColor DarkGray
      return $false
    }

    Write-Host ""
    Write-Host "Freebuff завершился с кодом $exitCode. Повторная попытка ($attempt/$maxRetries) через 3 секунды..." -ForegroundColor Yellow
    Start-Sleep -Seconds 3
  }
}

while ($true) {
  $choice = Show-TuiFramedMenu -AppBrand "Freebuff" -Title "Freebuff - выбор модели" -Subtitle "DeepSeek V4 Pro/Flash (main) · GPT-5.4 (deep thinking с ChatGPT)" -Items $items
  if (-not $choice) { exit 0 }

  $ok = Invoke-FreebuffRun -ModelId ([string]$choice.Id)
  if (-not $ok) {
    # После ошибки предлагаем повтор или возврат в меню
    Write-Host ""
    $retryItems = @(
      [pscustomobject]@{ Id = "retry";  Label = "Повторить запуск с этой же моделью" },
      [pscustomobject]@{ Id = "menu";   Label = "Вернуться в меню выбора модели" },
      [pscustomobject]@{ Id = "exit";   Label = "Выход" }
    )
    $retryChoice = Show-TuiFramedMenu -AppBrand "Freebuff" -Title "Freebuff - ошибка запуска" -Subtitle "Что дальше?" -Items $retryItems
    if (-not $retryChoice) { exit 0 }
    switch ([string]$retryChoice.Id) {
      "retry" { $null = Invoke-FreebuffRun -ModelId ([string]$choice.Id); exit 0 }
      "menu"  { continue }
      "exit"  { exit 0 }
    }
  }
  exit 0
}
