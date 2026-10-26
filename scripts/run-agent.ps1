# CLI-CODES — универсальный лаунчер AI-агентов (Windows).
#
#   cli-codes                     меню выбора агента
#   cli-codes <agent> [args…]     меню агента (провайдер → модель → запуск)
#   cli-codes <agent> --last      быстрый старт с последними настройками без меню
#   cli-codes list                таблица агентов: установлен / версия
#   cli-codes models <provider>   список моделей провайдера (динамически, с fallback)
#   cli-codes providers           список провайдеров и наличие ключей
#   cli-codes keys                управление API-ключами
#   cli-codes install [agent…]    установка/обновление агентов (без аргументов — инсталлятор)
#
# Агенты и провайдеры описаны в TXT/agents.txt и TXT/providers.txt.

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\clicodes.ps1")
. (Join-Path $PSScriptRoot "launcher-tui.ps1")
Update-CcPath

function Read-CcSecret([string]$Prompt) {
  Write-Host -NoNewline $Prompt
  $key = ""
  while ($true) {
    $k = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    if ($k.VirtualKeyCode -eq 13) { break }
    if ($k.VirtualKeyCode -eq 27) { $key = ""; break }
    if ($k.VirtualKeyCode -eq 8) {
      if ($key.Length -gt 0) { $key = $key.Substring(0, $key.Length - 1); Write-Host -NoNewline "`b `b" }
    } elseif ([int]$k.Character -ge 32) { $key += $k.Character; Write-Host -NoNewline "*" }
  }
  Write-Host ""
  return $key
}

function Wait-CcEnter { Read-Host "  Enter — продолжить" | Out-Null }

# Show-TuiFramedMenu с items-строками; возвращает 0-based индекс или -1
function Show-CcMenu([string]$Brand, [string]$Title, [string]$Subtitle, [string[]]$Labels) {
  $items = @()
  for ($i = 0; $i -lt $Labels.Count; $i++) { $items += [pscustomobject]@{ Label = $Labels[$i]; Index = $i } }
  $sel = Show-TuiFramedMenu -AppBrand $Brand -Title $Title -Subtitle $Subtitle -Items $items -MaxVisible 18 -EscapeAction Back
  if ($null -eq $sel -or $sel.__menuBack) { return -1 }
  return [int]$sel.Index
}

# ─── Ключи ───────────────────────────────────────────────────────────────────

function Request-CcKey($Provider) {
  Clear-Host
  Write-Host "══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
  Write-Host ("  {0} — API-ключ ({1})" -f $Provider.Name, $Provider.EnvVar) -ForegroundColor White
  Write-Host "══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
  $cur = Get-CcProviderKey $Provider
  if ($cur) { Write-Host ("  Текущий ключ: {0}" -f (Get-CcMasked $cur)) -ForegroundColor Green } else { Write-Host "  Текущий ключ: не задан" -ForegroundColor Yellow }
  Write-Host ("  Получить ключ: {0}" -f $Provider.KeyUrl) -ForegroundColor Cyan
  Write-Host ("  {0}" -f $Provider.Note) -ForegroundColor DarkGray
  Write-Host ""
  $new = Read-CcSecret "  Новый ключ (Enter — отмена, «-» — удалить): "
  if (-not $new) { return $false }
  if ($new -eq "-") { Set-CcKey $Provider.EnvVar ""; Write-Host "  Ключ удалён." -ForegroundColor Yellow; Wait-CcEnter; return $false }
  Set-CcKey $Provider.EnvVar $new
  Write-Host "  Сохранено в пользовательских переменных среды." -ForegroundColor Green
  return $true
}

function Show-CcKeysMenu {
  while ($true) {
    $provs = @($script:CcProviders | Where-Object { $_.EnvVar })
    $labels = @($provs | ForEach-Object {
      $mark = if (Get-CcProviderKey $_) { [char]0x2713 } else { [char]0x00B7 }
      "{0} {1}  [{2}]  {3}" -f $mark, $_.Name, (Get-CcTierBadge $_.Tier), $_.EnvVar
    })
    $i = Show-CcMenu "CLI-CODES" "API-ключи провайдеров" "✓ — ключ сохранён · Enter — изменить · Esc — назад" $labels
    if ($i -lt 0) { return }
    if (Request-CcKey $provs[$i]) { Wait-CcEnter }
  }
}

# ─── Провайдер и модель ──────────────────────────────────────────────────────

function Select-CcProvider($Agent) {
  $provs = @($script:CcProviders | Where-Object { Test-CcAdapterSupports $Agent.Adapter $_ })
  if (-not $provs) { return $null }
  $labels = @($provs | ForEach-Object {
    $status = switch ($_.Auth) {
      "none"     { "без ключа" }
      "optional" { "ключ не обязателен" }
      default    { if (Test-CcProviderReady $_) { "✓ ключ" } else { "нет ключа" } }
    }
    "{0} [{1}] · {2} — {3}" -f $_.Name, (Get-CcTierBadge $_.Tier), $status, $_.Note
  })
  $sub = "Бесплатные и с бесплатной квотой — вверху списка"
  if ($Agent.Adapter -eq "codex") { $sub = "Codex работает только с провайдерами, поддерживающими Responses API" }
  if ($Agent.Adapter -eq "claude") { $sub = "Нет нативного Anthropic API → автоматически поднимается локальный прокси" }
  $i = Show-CcMenu $Agent.Name ("Провайдер для " + $Agent.Name) $sub $labels
  if ($i -lt 0) { return $null }
  $p = $provs[$i]
  if (-not (Test-CcProviderReady $p)) { if (-not (Request-CcKey $p)) { return $null } }
  return $p
}

function Select-CcModel($Agent, $Provider) {
  $filter = ""; $refresh = $false
  while ($true) {
    Show-TuiWaitFrame -AppBrand $Agent.Name -Message ("Загрузка моделей {0}…" -f $Provider.Name)
    $res = Get-CcModels $Provider -Refresh:$refresh
    $refresh = $false
    # IndexOf, а не -like: символы [ ] * ? в фильтре не должны ломать wildcard-шаблон
    $models = @($res.Models | Where-Object { -not $filter -or ($_.Id + " " + $_.Label).IndexOf($filter, [StringComparison]::OrdinalIgnoreCase) -ge 0 })
    $labels = @("✎ Ввести ID модели вручную…", ("🔍 Фильтр по названию…" + $(if ($filter) { " (сейчас: $filter)" } else { "" })), "↻ Обновить список из API")
    $labels += @($models | ForEach-Object { "{0}  · {1}" -f $_.Label, $_.Id })
    $src = switch ($res.Source) { "api" { "живой список из API" } "cache" { "кэш API (до 6 ч)" } default { "статический каталог" } }
    $i = Show-CcMenu $Agent.Name ("Модель · " + $Provider.Name) ("{0} моделей · {1} · ★ — рекомендуемые" -f $models.Count, $src) $labels
    switch ($i) {
      -1 { return $null }
      0  { $m = Read-Host "  ID модели"; if ($m) { return $m.Trim() } }
      1  { $filter = Read-Host "  Подстрока (пусто — сбросить)" }
      2  { $refresh = $true }
      default { return $models[$i - 3].Id }
    }
  }
}

# ─── Меню агента ─────────────────────────────────────────────────────────────

function Get-CcWorkdir {
  $f = Join-Path $script:CcStateDir "workdir"
  if (Test-Path -LiteralPath $f) {
    $d = (Get-Content -LiteralPath $f -TotalCount 1 -Encoding UTF8)
    if ($d -and (Test-Path -LiteralPath $d)) { return $d }
  }
  $cwd = (Get-Location).Path
  if ($cwd -like "$($script:CcRoot)*" -or $cwd -like "$env:SystemRoot*") { return $env:USERPROFILE }
  return $cwd
}

function Start-CcAgentRun($Agent, $Provider, [string]$Model, [string[]]$AgentArgs) {
  Set-Location -LiteralPath (Get-CcWorkdir)
  Clear-Host
  if ($Provider) {
    Set-CcState $Agent.Key $Provider.Key $Model
    Write-Host ("▶ {0} · {1} · {2}" -f $Agent.Name, $Provider.Name, $Model) -ForegroundColor Cyan -NoNewline
  } else {
    Write-Host ("▶ {0}" -f $Agent.Name) -ForegroundColor Cyan -NoNewline
  }
  Write-Host ("  ({0})" -f (Get-Location).Path) -ForegroundColor DarkGray
  Invoke-CcAgent -Agent $Agent -Provider $Provider -Model $Model -AgentArgs $AgentArgs
  exit $LASTEXITCODE
}

function Show-CcAgentMenu($Agent, [string[]]$AgentArgs) {
  if (-not (Test-CcAgentInstalled $Agent)) {
    $i = Show-CcMenu $Agent.Name ($Agent.Name + " не установлен") $Agent.Desc @("Установить сейчас", "Отмена")
    if ($i -ne 0) { return }
    Clear-Host; Write-Host ("Установка {0}…" -f $Agent.Name) -ForegroundColor Cyan
    if (-not (Install-CcAgent $Agent)) { Write-Host "  [ERR] не удалось установить" -ForegroundColor Red; Wait-CcEnter; return }
  }

  if ($AgentArgs.Count -gt 0 -and $AgentArgs[0] -eq "--last") {
    $rest = @($AgentArgs | Select-Object -Skip 1)
    $st = Get-CcState $Agent.Key
    $p = if ($st) { Get-CcProvider $st.Provider } else { $null }
    Start-CcAgentRun $Agent $p $(if ($st) { $st.Model } else { "" }) $rest
  }

  while ($true) {
    $labels = @(); $acts = @()
    $st = Get-CcState $Agent.Key
    $lastP = if ($st) { Get-CcProvider $st.Provider } else { $null }
    if ($Agent.Adapter -eq "env") {
      $labels += "▶ Запустить $($Agent.Name)"; $acts += "run"
    } else {
      if ($lastP) { $labels += ("▶ Быстрый старт: {0} · {1}" -f $lastP.Name, $st.Model); $acts += "last" }
      $labels += "Выбрать провайдера и модель…"; $acts += "pick"
      $labels += "Нативный запуск ($($Agent.Name) со своим логином/конфигом)"; $acts += "run"
    }
    if ($Agent.Legacy -and (Test-Path -LiteralPath (Join-Path $PSScriptRoot "$($Agent.Legacy).ps1"))) {
      $labels += "Классический лаунчер (пресеты прошлых версий)"; $acts += "legacy"
    }
    $labels += "API-ключи провайдеров…"; $acts += "keys"
    $labels += "Рабочая папка: $(Get-CcWorkdir)"; $acts += "workdir"
    $labels += "Обновить $($Agent.Name)"; $acts += "update"

    $i = Show-CcMenu $Agent.Name $Agent.Name $Agent.Desc $labels
    if ($i -lt 0) { return }
    switch ($acts[$i]) {
      "last"   { Start-CcAgentRun $Agent $lastP $st.Model $AgentArgs }
      "pick"   {
        $p = Select-CcProvider $Agent
        if ($p) { $m = Select-CcModel $Agent $p; if ($m) { Start-CcAgentRun $Agent $p $m $AgentArgs } }
      }
      "run"    { Start-CcAgentRun $Agent $null "" $AgentArgs }
      "legacy" { & (Join-Path $PSScriptRoot "$($Agent.Legacy).ps1"); exit $LASTEXITCODE }
      "keys"   { Show-CcKeysMenu }
      "workdir" {
        $d = Read-Host "  Папка проекта (пусто — текущая)"
        if (-not (Test-Path -LiteralPath $script:CcStateDir)) { New-Item -ItemType Directory -Path $script:CcStateDir -Force | Out-Null }
        $f = Join-Path $script:CcStateDir "workdir"
        if (-not $d) { Remove-Item -LiteralPath $f -ErrorAction SilentlyContinue }
        elseif (Test-Path -LiteralPath $d) { [System.IO.File]::WriteAllText($f, (Resolve-Path -LiteralPath $d).Path, (New-Object System.Text.UTF8Encoding $false)) }
        else { Write-Host "  Нет такой папки: $d" -ForegroundColor Red; Wait-CcEnter }
      }
      "update" {
        Clear-Host; Write-Host ("Обновление {0}…" -f $Agent.Name) -ForegroundColor Cyan
        if (Install-CcAgent $Agent) { Write-Host ("  [OK] {0}" -f (Get-CcAgentVersion $Agent)) -ForegroundColor Green }
        else { Write-Host "  [ERR] обновление не удалось" -ForegroundColor Red }
        Wait-CcEnter
      }
    }
  }
}

function Show-CcMainMenu {
  while ($true) {
    $installed = @($script:CcAgents | Where-Object { Test-CcAgentInstalled $_ })
    $labels = @($installed | ForEach-Object { "{0} — {1}" -f $_.Name, $_.Desc })
    $labels += "＋ Установить / обновить агентов…"
    $labels += "API-ключи провайдеров…"
    $i = Show-CcMenu "CLI-CODES" "Выберите AI-агента" ("Установлено агентов: {0}" -f $installed.Count) $labels
    if ($i -lt 0) { return }
    if ($i -lt $installed.Count) { Show-CcAgentMenu $installed[$i] @() }
    elseif ($i -eq $installed.Count) { & (Join-Path $script:CcRoot "install-full.ps1"); return }
    else { Show-CcKeysMenu }
  }
}

# ─── CLI ─────────────────────────────────────────────────────────────────────

$cmd = if ($args.Count -gt 0) { [string]$args[0] } else { "" }
$rest = @($args | Select-Object -Skip 1 | ForEach-Object { [string]$_ })
switch ($cmd) {
  ""          { Show-CcMainMenu }
  { $_ -in @("-h", "--help", "help") } {
    Get-Content -LiteralPath $PSCommandPath -TotalCount 12 -Encoding UTF8 | Select-Object -Skip 1 | ForEach-Object { $_ -replace '^# ?', '' }
  }
  "list" {
    "{0,-12} {1,-22} {2,-10} {3}" -f "KEY", "NAME", "STATUS", "VERSION"
    foreach ($a in $script:CcAgents) {
      $s = if (-not (Test-CcAgentSupported $a)) { "n/a" } elseif (Test-CcAgentInstalled $a) { "installed" } else { "-" }
      $v = if ($s -eq "installed") { Get-CcAgentVersion $a } else { "" }
      "{0,-12} {1,-22} {2,-10} {3}" -f $a.Key, $a.Name, $s, $v
    }
  }
  "models" {
    $p = Get-CcProvider ($rest | Select-Object -First 1)
    if (-not $p) { Write-Host "Использование: cli-codes models <provider> [--refresh]"; exit 1 }
    Import-CcKeys
    $res = Get-CcModels $p -Refresh:($rest -contains "--refresh")
    [Console]::Error.WriteLine(("# {0}: {1} моделей (источник: {2})" -f $p.Name, $res.Models.Count, $res.Source))
    $res.Models | ForEach-Object { "{0}`t{1}" -f $_.Id, $_.Label }
  }
  "providers" {
    foreach ($p in $script:CcProviders) {
      "{0,-13} {1,-11} {2,-7} {3}" -f $p.Key, (Get-CcTierBadge $p.Tier), $(if (Test-CcProviderReady $p) { "ready" } else { "no-key" }), $p.Name
    }
  }
  "keys" { Show-CcKeysMenu }
  "install" {
    if ($rest.Count -eq 0) { & (Join-Path $script:CcRoot "install-full.ps1"); exit $LASTEXITCODE }
    foreach ($k in $rest) {
      $a = Get-CcAgent $k
      if (-not $a) { Write-Host "Неизвестный агент: $k" -ForegroundColor Red; continue }
      Write-Host -NoNewline ("{0}… " -f $a.Name)
      if (Install-CcAgent $a) { Write-Host ("OK {0}" -f (Get-CcAgentVersion $a)) -ForegroundColor Green } else { Write-Host "FAIL" -ForegroundColor Red }
    }
  }
  default {
    $a = Get-CcAgent $cmd
    if (-not $a) { Write-Host "Неизвестный агент: $cmd. Список: cli-codes list" -ForegroundColor Red; exit 1 }
    Show-CcAgentMenu $a $rest
  }
}
