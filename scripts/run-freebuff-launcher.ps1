[CmdletBinding()]
param()

# In PS 7.4+ $PSNativeCommandUseErrorActionPreference defaults to $true, which converts
# any native command with non-zero exit code into a terminating error when EAP="Stop".
# Freebuff may exit with non-zero code (auto-update check, CDN block, Ctrl+C, etc),
# so we disable this behaviour for the launcher — we'll inspect $LASTEXITCODE manually.
$PSNativeCommandUseErrorActionPreference = $false
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "launcher-tui.ps1")

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

# Согласно Freebuff FAQ (https://github.com/CodebuffAI/codebuff/blob/main/freebuff/README.md):
#   "DeepSeek V4 Pro (smartest) or DeepSeek V4 Flash as the main coding agent.
#    Gemini 3.1 Flash Lite handles file finding and research,
#    GPT-5.4 handles deep thinking if you connect your ChatGPT subscription."
# ПРИМЕЧАНИЕ: Freebuff CLI не документирует env-переменную FREEBUFF_MODEL — presetы ниже
# основаны на названиях моделей из FAQ и могут не влиять на реальный выбор (Freebuff автоматически
# подбирает модель под задачу). В случае игнорирования Freebuff просто использует свой default.
$items = @(
  [pscustomobject]@{ Id = "vanilla"; Label = "Запустить Freebuff (встроенный выбор модели)" }
)

$freebuffExe = Resolve-FreebuffExe
if (-not $freebuffExe) { throw "Freebuff CLI не найден. Установите: npm install -g freebuff" }

function Invoke-FreebuffRun {
  param([string]$ModelId)

  # Сбрасываем env от предыдущих запусков — запускаем ванильный freebuff
  Remove-Item Env:FREEBUFF_MODEL -ErrorAction SilentlyContinue

  $env:CODEBUFF_AUTO_UPDATE_DISABLED = "1"
  $env:CODEBUFF_SKIP_UPDATE = "1"
  $env:FREEBUFF_SKIP_UPDATE = "1"
  $env:NPM_CONFIG_UPDATE_NOTIFIER = "true"
  $env:NPM_CONFIG_FUND = "false"

  Clear-Host
  Write-Host "Запуск Freebuff (ванильный)..." -ForegroundColor Cyan
  Write-Host "Freebuff сам выберет модель под задачу (file picker, planner, editor)." -ForegroundColor DarkGray

  $binPath = Join-Path $env:USERPROFILE ".config\manicode\freebuff.exe"
  if (-not (Test-Path -LiteralPath $binPath)) {
    Write-Host ""
    Write-Host "ВНИМАНИЕ: binary Freebuff (~50MB) отсутствует. Сейчас будет попытка скачивания" -ForegroundColor Yellow
    Write-Host "с https://codebuff.com. Если через 30 сек нет прогресса — у вас CDN-блокировка" -ForegroundColor Yellow
    Write-Host "РКН/TLS-SNI в регионе. ВКЛЮЧИТЕ VPN и повторите (binary качается один раз," -ForegroundColor Yellow
    Write-Host "далее работает офлайн)." -ForegroundColor Yellow
    Write-Host ""
  }

  $maxRetries = 2
  $attempt = 0
  while ($true) {
    $attempt++
    $null = Invoke-ChildCliSafe -ExePath $freebuffExe
    $exitCode = $LASTEXITCODE

    if ($exitCode -eq 0) { return $true }

    if ($attempt -ge $maxRetries) {
      Write-Host ""
      Write-Host "Freebuff завершился с кодом $exitCode." -ForegroundColor Yellow
      Write-Host "Причина: freebuff при первом запуске пытается скачать binary (~50MB) с" -ForegroundColor Cyan
      Write-Host "        https://codebuff.com/api/releases/download/… и получает ECONNRESET." -ForegroundColor Cyan
      Write-Host "        Это CDN-блокировка в вашем регионе, лечится только VPN/HTTPS_PROXY." -ForegroundColor Cyan
      Write-Host ""
      Write-Host "Решения:" -ForegroundColor Cyan
      Write-Host "  1) Включите VPN и запустите снова (binary качается один раз в" -ForegroundColor DarkGray
      Write-Host "     ~/.config/manicode/freebuff.exe, потом работает без интернета)." -ForegroundColor DarkGray
      Write-Host "  2) Установите HTTPS_PROXY перед запуском:" -ForegroundColor DarkGray
      Write-Host '       $env:HTTPS_PROXY = "http://127.0.0.1:7890"' -ForegroundColor DarkGray
      Write-Host "       (замените 7890 на порт вашего proxy/VPN-клиента)" -ForegroundColor DarkGray
      Write-Host "  3) Скачать binary вручную через curl и положить в" -ForegroundColor DarkGray
      Write-Host "     $env:USERPROFILE\.config\manicode\freebuff.exe" -ForegroundColor DarkGray
      Write-Host "  4) Скипнуть Freebuff — он опциональный, агента дают и OpenClaude/Claude Code." -ForegroundColor DarkGray
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
