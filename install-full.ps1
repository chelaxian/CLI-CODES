# CLI-CODES — Windows-инсталлятор AI-агентов (PowerShell 5.1+).
# 1-click: irm https://raw.githubusercontent.com/chelaxian/CLI-CODES/main/install.ps1 | iex
#
# Неинтерактивно:  install-full.ps1 -Agents claude,codex,gemini  |  -All  |  -Update
# Список агентов и способы установки — в TXT/agents.txt (меню строится из него).

param(
  [string[]]$Agents = @(),
  [switch]$All,
  [switch]$Update,
  [string]$RepoUrl = "https://github.com/chelaxian/CLI-CODES.git",
  [string]$InstallDir = ""
)

try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.ServicePointManager]::SecurityProtocol } catch {}
$ErrorActionPreference = "Stop"
try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false) } catch {}

$MinNodeMajor = 20
# Рекомендуемый набор: самые популярные агенты + те, что работают с бесплатными провайдерами
$Recommended = @("claude", "codex", "gemini", "qwen", "opencode", "crush", "copilot", "kilo", "openclaude")

function Write-Status([string]$Text, [string]$Color = "White") { Write-Host $Text -ForegroundColor $Color }
function Write-Step([string]$Title) {
  Write-Host ""
  Write-Status "======================================================================" "Cyan"
  Write-Status $Title "Magenta"
  Write-Status "======================================================================" "Cyan"
}

# Профиль реального пользователя, даже если PowerShell запущен «от имени администратора»
function Get-RealUserProfilePath {
  try {
    $explorer = Get-Process -Name explorer -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($explorer) {
      $wmi = Get-WmiObject Win32_Process -Filter "ProcessId='$($explorer.Id)'" -ErrorAction SilentlyContinue
      $owner = if ($wmi) { $wmi.GetOwner() }
      if ($owner -and $owner.User -and $owner.Domain) {
        $sid = (New-Object System.Security.Principal.NTAccount($owner.Domain, $owner.User)).Translate([System.Security.Principal.SecurityIdentifier]).Value
        $p = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$sid" -ErrorAction SilentlyContinue).ProfileImagePath
        if ($p -and (Test-Path -LiteralPath $p)) { return $p }
      }
    }
  } catch {}
  return $env:USERPROFILE
}

function Update-SessionPath {
  $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
}

function Invoke-Native([scriptblock]$Block) {  # нативные команды пишут в stderr — не превращаем это в исключения
  $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
  try { & $Block } finally { $ErrorActionPreference = $prev }
}

function Get-NodeMajor {
  $n = Get-Command node -ErrorAction SilentlyContinue
  if (-not $n) { return 0 }
  $v = (& node --version) -replace '^v', ''
  return [int]($v.Split('.')[0])
}

function Install-Dependencies {
  Write-Step "СИСТЕМНЫЕ ЗАВИСИМОСТИ"
  $winget = Get-Command winget -ErrorAction SilentlyContinue
  $need = @()
  if (-not (Get-Command git -ErrorAction SilentlyContinue)) { $need += @{ Name = "git"; Id = "Git.Git" } }
  if ((Get-NodeMajor) -lt $MinNodeMajor) { $need += @{ Name = "Node.js LTS"; Id = "OpenJS.NodeJS.LTS" } }
  foreach ($d in $need) {
    if (-not $winget) {
      Write-Status ("  [ERR] {0} не найден, а winget недоступен. Установите вручную: https://nodejs.org / https://git-scm.com" -f $d.Name) "Red"
      return $false
    }
    Write-Status ("  → winget install {0}…" -f $d.Id) "Cyan"
    Invoke-Native { & winget install -e --id $d.Id --accept-source-agreements --accept-package-agreements --silent | Out-Host }
  }
  Update-SessionPath
  foreach ($c in @("git", "node", "npm")) {
    $cmd = Get-Command $c -ErrorAction SilentlyContinue
    if ($cmd) { Write-Status ("  [OK]   {0} → {1}" -f $c, $cmd.Source) "Green" } else { Write-Status "  [MISS] $c (перезапустите терминал после установки)" "Yellow" }
  }
  $py = @("python", "python3") | ForEach-Object { Get-Command $_ -ErrorAction SilentlyContinue } | Where-Object { $_.Source -notlike "*WindowsApps*" } | Select-Object -First 1
  if ($py) { Write-Status "  [OK]   python → $($py.Source)" "Green" }
  else { Write-Status "  [INFO] Python не найден: нужен только для Claude Code с провайдерами без Anthropic API (winget install Python.Python.3.12)" "DarkGray" }
  return ((Get-NodeMajor) -ge $MinNodeMajor)
}

# ─── Репозиторий ─────────────────────────────────────────────────────────────

if (-not $InstallDir) {
  # Запущен из клона репозитория (в любой папке) → работаем с ним; иначе стандартный ~\CLI-CODES
  if ($PSScriptRoot -and (Test-Path -LiteralPath (Join-Path $PSScriptRoot "scripts\lib\clicodes.ps1"))) { $InstallDir = $PSScriptRoot }
  else { $InstallDir = Join-Path (Get-RealUserProfilePath) "CLI-CODES" }
}

# UTF-8 BOM, нужный PS 5.1 для кириллицы, хранится прямо в git (проверяется в CI), поэтому
# файлы на машине пользователя мы НЕ переписываем: старые версии дописывали BOM сами, рабочая
# копия становилась «изменённой», и git pull переставал обновлять проект.
function Sync-Repo {
  $env:GIT_TERMINAL_PROMPT = "0"; $env:GCM_INTERACTIVE = "Never"
  if (Test-Path -LiteralPath (Join-Path $InstallDir ".git")) {
    $before = Invoke-Native { (& git -C $InstallDir rev-parse --short HEAD) }
    Invoke-Native { & git -C $InstallDir fetch -q origin main }
    if ($LASTEXITCODE -ne 0) { Write-Status "  [WARN] git fetch не удался, работаю с локальной копией ($before)" "Yellow"; return }
    # Локальные правки (например, в TXT/) не теряем: откладываем в stash, их можно вернуть
    $dirty = Invoke-Native { & git -C $InstallDir status --porcelain --untracked-files=no }
    if ($dirty) {
      Invoke-Native { & git -C $InstallDir stash push -q -m ("cli-codes autostash " + (Get-Date -Format "yyyy-MM-dd HH:mm")) }
      Write-Status "  [INFO] Локальные изменения отложены: git -C `"$InstallDir`" stash list" "DarkGray"
    }
    Invoke-Native { & git -C $InstallDir reset -q --hard origin/main }
    $after = Invoke-Native { (& git -C $InstallDir rev-parse --short HEAD) }
    if ($before -eq $after) { Write-Status "  [OK] Репозиторий актуален ($after)" "Green" } else { Write-Status "  [OK] Репозиторий обновлён ($before → $after)" "Green" }
  } else {
    Invoke-Native { & git clone -q $RepoUrl $InstallDir }
    if (-not (Test-Path -LiteralPath (Join-Path $InstallDir ".git"))) { throw "Ошибка клонирования $RepoUrl" }
    Write-Status "  [OK] Репозиторий клонирован: $InstallDir" "Green"
  }
}

# Запуск из временной копии (irm | iex) → готовим репозиторий и перезапускаемся из него,
# чтобы скрипт и реестры TXT/ всегда были одной версии.
$selfInRepo = $PSCommandPath -and ((Split-Path -Parent $PSCommandPath) -eq $InstallDir)
if (-not $selfInRepo) {
  if (-not (Get-Command git -ErrorAction SilentlyContinue)) { [void](Install-Dependencies) }
  Write-Step "РЕПОЗИТОРИЙ"
  Sync-Repo
  $psExe = (Get-Process -Id $PID).Path
  $fwd = @()
  if ($Agents.Count) { $fwd += @("-Agents", ($Agents -join ",")) }
  if ($All) { $fwd += "-All" }
  if ($Update) { $fwd += "-Update" }
  & $psExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $InstallDir "install-full.ps1") -InstallDir $InstallDir @fwd
  exit $LASTEXITCODE
}

. (Join-Path $InstallDir "scripts\lib\clicodes.ps1")
Update-CcPath

# ─── Действия ────────────────────────────────────────────────────────────────

function Install-Agents([string[]]$Keys) {
  Write-Step "УСТАНОВКА АГЕНТОВ"
  $ok = 0; $fail = 0
  foreach ($k in $Keys) {
    $a = Get-CcAgent $k
    if (-not $a) { Write-Status "  [WARN] неизвестный агент: $k" "Yellow"; continue }
    if (-not (Test-CcAgentSupported $a)) { Write-Status ("  [SKIP] {0}: только Linux/macOS (используйте WSL)" -f $a.Name) "DarkGray"; continue }
    Write-Host -NoNewline ("  {0,-22} " -f $a.Name)
    if (Install-CcAgent $a) { Write-Status ("OK {0}" -f (Get-CcAgentVersion $a)) "Green"; $ok++ }
    else { Write-Status ("FAIL  ({0})" -f $a.Windows) "Red"; $fail++ }
  }
  Write-Status ("`n  Установлено: {0}, ошибок: {1}" -f $ok, $fail) "Cyan"
}

function Update-Shortcuts {
  Write-Step "ЯРЛЫКИ И КОМАНДА cli-codes"
  & (Join-Path $InstallDir "scripts\create-desktop-shortcuts.ps1") -RepoRoot $InstallDir
}

function Update-All {
  Write-Step "ОБНОВЛЕНИЕ"
  Sync-Repo
  $installed = @($script:CcAgents | Where-Object { Test-CcAgentInstalled $_ } | ForEach-Object { $_.Key })
  if ($installed.Count) { Install-Agents $installed } else { Write-Status "  Установленных агентов нет" "Yellow" }
  $fcc = Join-Path $env:USERPROFILE ".free-claude-code"
  if (Test-Path -LiteralPath (Join-Path $fcc ".git")) {  # прокси для классического Claude-лаунчера
    Invoke-Native { & git -C $fcc pull -q }
    Write-Status "  [OK] free-claude-code обновлён" "Green"
  }
  Update-Shortcuts
}

function Select-Agents {
  Write-Host ""
  for ($i = 0; $i -lt $script:CcAgents.Count; $i++) {
    $a = $script:CcAgents[$i]
    $mark = if (-not (Test-CcAgentSupported $a)) { "n/a" } elseif (Test-CcAgentInstalled $a) { " ✓ " } else { "   " }
    Write-Host ("  {0,2} " -f ($i + 1)) -ForegroundColor Yellow -NoNewline
    Write-Host ("{0} {1,-20} " -f $mark, $a.Name) -NoNewline
    Write-Host $a.Desc -ForegroundColor DarkGray
  }
  $sel = Read-Host "`nНомера через пробел/запятую (например: 1 2 5 или 1-6)"
  $keys = @()
  foreach ($tok in ($sel -split '[ ,]+' | Where-Object { $_ })) {
    if ($tok -match '^(\d+)-(\d+)$') { foreach ($n in [int]$Matches[1]..[int]$Matches[2]) { if ($n -ge 1 -and $n -le $script:CcAgents.Count) { $keys += $script:CcAgents[$n - 1].Key } } }
    elseif ($tok -match '^\d+$' -and [int]$tok -ge 1 -and [int]$tok -le $script:CcAgents.Count) { $keys += $script:CcAgents[[int]$tok - 1].Key }
  }
  return $keys
}

function Uninstall-All {
  Write-Step "ПОЛНОЕ УДАЛЕНИЕ"
  Write-Status "Будут удалены: установленные через CLI-CODES агенты (npm/uv), $InstallDir," "Red"
  Write-Status "API-ключи провайдеров из переменных среды, ярлыки агентов и команда cli-codes." "Red"
  Write-Status "Конфиги самих агентов (~/.claude, ~/.codex, …) не трогаем." "DarkGray"
  if ((Read-Host "Введите 'yes' для подтверждения") -ne "yes") { Write-Status "Отмена." "Yellow"; return }
  $desk = Join-Path (Get-RealUserProfilePath) "Desktop"
  foreach ($a in $script:CcAgents) {
    if (Test-CcAgentInstalled $a) { Uninstall-CcAgent $a; Write-Status "  [OK] удалён $($a.Name)" "Green" }
    Remove-Item -LiteralPath (Join-Path $desk ($a.Name + ".lnk")) -Force -ErrorAction SilentlyContinue
  }
  foreach ($p in $script:CcProviders) { if ($p.EnvVar -and $p.EnvVar -ne "OPENAI_API_KEY" -and $p.EnvVar -ne "ANTHROPIC_API_KEY") { [Environment]::SetEnvironmentVariable($p.EnvVar, $null, "User") } }
  $binDir = Join-Path $InstallDir "bin"
  $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
  [Environment]::SetEnvironmentVariable("Path", ((($userPath -split ';') | Where-Object { $_ -and $_ -ne $binDir }) -join ';'), "User")
  Remove-Item -LiteralPath (Join-Path $env:APPDATA "cli-codes"), (Join-Path $env:LOCALAPPDATA "cli-codes") -Recurse -Force -ErrorAction SilentlyContinue
  Set-Location $env:USERPROFILE
  Remove-Item -LiteralPath $InstallDir -Recurse -Force -ErrorAction SilentlyContinue
  Write-Status "Готово. Перезапустите терминал." "Green"
}

function Show-Summary {
  Write-Step "ГОТОВО"
  Write-Status "  Ярлыки агентов — на рабочем столе. В терминале:" "White"
  Write-Status "    cli-codes              меню всех агентов" "Green"
  Write-Status "    cli-codes <агент>      например: cli-codes claude, cli-codes codex" "Green"
  Write-Status "    cli-codes keys         API-ключи (бесплатные: OpenRouter, NIM, Gemini, Zen, Groq…)" "Green"
  Write-Status "    cli-codes list         что установлено" "Green"
  Write-Status "`n  Откройте новый терминал, чтобы обновился PATH." "Yellow"
}

# ─── main ────────────────────────────────────────────────────────────────────

if ($All -or $Agents.Count -or $Update) {
  if ($Update) { Update-All }
  else {
    if (-not (Install-Dependencies)) { exit 1 }
    $keys = if ($All) { @($script:CcAgents | ForEach-Object { $_.Key }) } else { @($Agents -split ',' | Where-Object { $_ }) }
    Install-Agents $keys; Update-Shortcuts
  }
  Show-Summary
  exit 0
}

try { Clear-Host } catch {}
Write-Status "======================================================================" "Cyan"
$logo = Join-Path $script:CcTxt "logos\installer.txt"
if (Test-Path -LiteralPath $logo) { Get-Content -LiteralPath $logo -Encoding UTF8 | Where-Object { $_.Trim() } | ForEach-Object { Write-Status $_ "Cyan" } }
Write-Status ("     1-click установка AI-агентов для терминала · {0} агентов · {1} провайдеров" -f $script:CcAgents.Count, $script:CcProviders.Count) "Yellow"
$ver = Invoke-Native { & git -C $InstallDir rev-parse --short HEAD 2>$null }
Write-Status ("     версия: {0}" -f $(if ($ver) { $ver } else { "local" })) "DarkGray"
Write-Status "======================================================================" "Cyan"

while ($true) {
  Write-Step "ЧТО ДЕЛАЕМ?"
  Write-Status ("  [1] Рекомендуемый набор ({0})  ← по умолчанию" -f ($Recommended -join ", ")) "Yellow"
  Write-Status ("  [2] ВСЕ агенты ({0})" -f $script:CcAgents.Count) "Green"
  Write-Status "  [3] Выбрать агентов вручную…" "Green"
  Write-Status "  [4] Обновить репозиторий и все установленные агенты" "Cyan"
  Write-Status "  [5] API-ключи провайдеров (бесплатные: OpenRouter, NIM, Gemini, Zen, Groq, Cerebras…)" "Cyan"
  Write-Status "  [6] Пересоздать ярлыки и команду cli-codes" "Cyan"
  Write-Status "  [0] Только системные зависимости (git, Node.js ≥ $MinNodeMajor)" "Cyan"
  Write-Status "  [9] Полное удаление" "Red"
  Write-Status "  [X] Выход" "Gray"
  $choice = (Read-Host "`nВаш выбор [1]").Trim().ToUpper()
  if (-not $choice) { $choice = "1" }
  # break/continue внутри switch в PowerShell относятся к самому switch, поэтому выход из цикла — через флаг
  $done = $true
  switch ($choice) {
    "1" { if (Install-Dependencies) { Install-Agents $Recommended; Update-Shortcuts; Show-Summary } }
    "2" { if (Install-Dependencies) { Install-Agents @($script:CcAgents | ForEach-Object { $_.Key }); Update-Shortcuts; Show-Summary } }
    "3" { $sel = @(Select-Agents); if ($sel.Count -and (Install-Dependencies)) { Install-Agents $sel; Update-Shortcuts; Show-Summary } else { $done = $false } }
    "4" { Update-All; Show-Summary }
    "5" { & (Join-Path $InstallDir "scripts\run-agent.ps1") keys; $done = $false }
    "6" { Update-Shortcuts; $done = $false }
    "0" { [void](Install-Dependencies); $done = $false }
    "9" { Uninstall-All }
    "X" { exit 0 }
    "Q" { exit 0 }
    default { Write-Status "Неверный выбор" "Yellow"; $done = $false }
  }
  if ($done) { break }
}
Read-Host "`nНажмите Enter для выхода" | Out-Null
