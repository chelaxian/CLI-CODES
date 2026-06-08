# cloud-code-setup - Windows bootstrap (PowerShell)
# 1-click: irm https://raw.githubusercontent.com/chelaxian/cloud-code-setup/main/install.ps1 | iex
# Or: git clone https://github.com/chelaxian/cloud-code-setup.git && cd cloud-code-setup && .\install.ps1

# TLS 1.2 for PowerShell 5.1
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.ServicePointManager]::SecurityProtocol } catch {}

$ErrorActionPreference = "Stop"

if (-not $RepoUrl) { $RepoUrl = "https://github.com/chelaxian/cloud-code-setup.git" }
if (-not $InstallDir) { $InstallDir = "" }

Write-Host "cloud-code-setup :: starting..." -ForegroundColor Cyan

function Write-Status($Text, $Color = "White") {
    Write-Host $Text -ForegroundColor $Color
}

if (-not $InstallDir) {
    $InstallDir = Join-Path $env:USERPROFILE "cloud-code-setup"
}

try { Clear-Host } catch { }
Write-Status "======================================================================" "Cyan"
Write-Status "" "Cyan"
Write-Status "   ██████╗██╗     ██╗        ██████╗ ██████╗ ██████╗ ███████╗" "Cyan"
Write-Status "  ██╔════╝██║     ██║        ██╔════╝██╔═══██╗██╔══██╗██╔════╝" "Cyan"
Write-Status "  ██║     ██║     ██║ █████╗ ██║     ██║   ██║██║  ██║█████╗  " "Cyan"
Write-Status "  ██║     ██║     ██║ ╚════╝ ██║     ██║   ██║██║  ██║██╔══╝  " "Cyan"
Write-Status "  ╚██████╗███████╗██║        ╚██████╗╚██████╔╝██████╔╝███████╗" "Cyan"
Write-Status "   ╚═════╝╚══════╝╚═╝         ╚═════╝ ╚═════╝ ╚═════╝ ╚══════╝" "Cyan"
Write-Status "" "Cyan"
Write-Status "              C L O U D   C O D E  -  1-click install" "Yellow"
Write-Status "" "Cyan"
Write-Status "  Qwen Code + Claude Code + OpenCode + Freebuff + OpenClaude" "Yellow"
Write-Status "" "Cyan"
Write-Status "======================================================================" "Cyan"
Write-Host ""

Write-Status "Проверка зависимостей..." "Cyan"

$hasWinget = $null -ne (Get-Command winget -ErrorAction SilentlyContinue)
$needRefresh = $false

# --- git ---
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Status "  git не найден, устанавливаем..." "Yellow"
    if ($hasWinget) {
        $prevEAP = $ErrorActionPreference; $ErrorActionPreference = "Continue"
        & winget install -e --id Git.Git --accept-source-agreements --accept-package-agreements 2>&1 | ForEach-Object { Write-Host "    $_" }
        $ErrorActionPreference = $prevEAP
        $needRefresh = $true
    } else {
        Write-Status "  [WARN] winget не найден. Скачайте git вручную: https://git-scm.com/download/win" "Red"
        Read-Host "Нажмите Enter для выхода"
        return
    }
}

# --- node ---
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Status "  Node.js не найден, устанавливаем..." "Yellow"
    if ($hasWinget) {
        $prevEAP = $ErrorActionPreference; $ErrorActionPreference = "Continue"
        & winget install -e --id OpenJS.NodeJS.LTS --accept-source-agreements --accept-package-agreements 2>&1 | ForEach-Object { Write-Host "    $_" }
        $ErrorActionPreference = $prevEAP
        $needRefresh = $true
    } else {
        Write-Status "  [WARN] winget не найден. Скачайте Node.js вручную: https://nodejs.org/" "Red"
        Read-Host "Нажмите Enter для выхода"
        return
    }
}

# --- npm (if node is present but npm missing) ---
if ((Get-Command node -ErrorAction SilentlyContinue) -and -not (Get-Command npm -ErrorAction SilentlyContinue)) {
    Write-Status "  npm не найден, обновляем..." "Yellow"
    $prevEAP = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    & node -e "require('child_process').exec('npm install -g npm@latest', {stdio:'inherit'})" 2>$null
    $ErrorActionPreference = $prevEAP
    $needRefresh = $true
}

# Refresh PATH if we installed something
if ($needRefresh) {
    $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
}

# Final check
$allOk = $true
if (Get-Command git -ErrorAction SilentlyContinue) {
    Write-Status "  [OK] git" "Green"
} else {
    Write-Status "  [WARN] git не найден после установки" "Red"
    $allOk = $false
}
if (Get-Command node -ErrorAction SilentlyContinue) {
    Write-Status "  [OK] node" "Green"
} else {
    Write-Status "  [WARN] node не найден после установки" "Red"
    $allOk = $false
}
if (Get-Command npm -ErrorAction SilentlyContinue) {
    Write-Status "  [OK] npm" "Green"
} else {
    Write-Status "  [WARN] npm не найден после установки" "Red"
    $allOk = $false
}

if (-not $allOk) {
    Write-Host ""
    Write-Host "Не все зависимости удалось установить. Перезапустите терминал и попробуйте снова." -ForegroundColor Red
    Read-Host "Нажмите Enter для выхода"
    return
}
Write-Host ""

if (Test-Path -LiteralPath (Join-Path $InstallDir ".git")) {
    Write-Status "Репозиторий уже клонирован: $InstallDir" "Yellow"
    Write-Status "Обновление…" "Cyan"
    Push-Location $InstallDir
    try {
        $prevPrompt = $env:GIT_TERMINAL_PROMPT
        $prevGcm = $env:GCM_INTERACTIVE
        $env:GIT_TERMINAL_PROMPT = "0"
        $env:GCM_INTERACTIVE = "Never"

        $prevEAP = $ErrorActionPreference; $ErrorActionPreference = "Continue"
        $out = git pull origin main 2>&1
        $code = $LASTEXITCODE
        $ErrorActionPreference = $prevEAP

        if ($code -eq 0) {
            Write-Status "  [OK] Репозиторий обновлён" "Green"
        } else {
            Write-Status "  [WARN] git pull failed (code $code). Using local files." "Yellow"
            if ($out) { Write-Host $out }
        }
    } catch {
        Write-Status "  [WARN] Could not update" "Yellow"
    } finally {
        $env:GIT_TERMINAL_PROMPT = $prevPrompt
        $env:GCM_INTERACTIVE = $prevGcm
        Pop-Location
    }
} else {
    Write-Status "Клонирование репозитория…" "Cyan"
    $prevPrompt = $env:GIT_TERMINAL_PROMPT
    $prevGcm = $env:GCM_INTERACTIVE
    $env:GIT_TERMINAL_PROMPT = "0"
    $env:GCM_INTERACTIVE = "Never"

    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $out = git clone $RepoUrl $InstallDir 2>&1
    $code = $LASTEXITCODE
    $ErrorActionPreference = $prevEAP

    $env:GIT_TERMINAL_PROMPT = $prevPrompt
    $env:GCM_INTERACTIVE = $prevGcm
    if ($code -ne 0) {
        Write-Host "Clone error (code $code). Check access to $RepoUrl" -ForegroundColor Red
        if ($out) { Write-Host $out }
        return
    }
    Write-Status "  [OK] Репозиторий клонирован: $InstallDir" "Green"
}

Write-Host ""

Write-Status "======================================================================" "Cyan"
Write-Status "ЧТО УСТАНАВЛИВАЕМ?" "Magenta"
Write-Status "======================================================================" "Cyan"
Write-Host ""
Write-Status "  [0] Установка системных зависимостей (git, node, npm, curl)" "Cyan"
Write-Status "  [1] Установка сразу ВСЕХ агентов  ← рекомендуется" "Yellow"
Write-Status "  [2] Только Qwen Code" "Green"
Write-Status "  [3] Только Claude Code" "Green"
Write-Status "  [4] Только OpenCode" "Green"
Write-Status "  [5] Только Freebuff" "Green"
Write-Status "  [6] Только OpenClaude" "Green"
Write-Status "  [7] Обновление ВСЕХ компонентов (проверяет актуальность)" "Yellow"
Write-Status "  [8] Полное удаление проекта с ПК (uninstall)" "Red"
Write-Status "  [9] Обновить ярлыки на рабочем столе (актуализация, скрытие скриптов)" "Cyan"
Write-Status "  [X] Выход из мастера установки" "Gray"
Write-Host ""

$installChoice = Read-Host "Ваш выбор [1]"

if ([string]::IsNullOrWhiteSpace($installChoice)) { $installChoice = "1" }
$installChoice = $installChoice.Trim().ToUpper()

# ─── [0] Установка системных зависимостей ─────────────────────────────────────
function Install-SystemDependencies {
    Write-Host ""
    Write-Status "======================================================================" "Cyan"
    Write-Status "УСТАНОВКА СИСТЕМНЫХ ЗАВИСИМОСТЕЙ" "Magenta"
    Write-Status "======================================================================" "Cyan"
    Write-Host ""

    $missing = @()
    $pkgs = @(
        @{ Name = "git";   Cmd = "git";   MinVer = "2.30" },
        @{ Name = "node";  Cmd = "node";  MinVer = "18.0" },
        @{ Name = "npm";   Cmd = "npm";   MinVer = "9.0"  },
        @{ Name = "curl";  Cmd = "curl";  MinVer = "7.0"  }
    )
    foreach ($p in $pkgs) {
        $c = Get-Command $p.Cmd -ErrorAction SilentlyContinue
        if ($c) {
            Write-Status "  [OK]   $($p.Name) → $($c.Source)" "Green"
        } else {
            Write-Status "  [MISS] $($p.Name) — не найден" "Yellow"
            $missing += $p.Name
        }
    }

    if ($missing.Count -eq 0) {
        Write-Host ""
        Write-Status "Все необходимые зависимости уже установлены." "Green"
        return
    }

    Write-Host ""
    Write-Status "Отсутствуют: $($missing -join ', ')" "Yellow"
    Write-Status "Попытка установки через доступный пакетный менеджер..." "Cyan"
    Write-Host ""

    # Определяем пакетный менеджер: winget > choco > scoop
    $pm = $null
    if (Get-Command winget -ErrorAction SilentlyContinue) { $pm = "winget" }
    elseif (Get-Command choco -ErrorAction SilentlyContinue) { $pm = "choco" }
    elseif (Get-Command scoop -ErrorAction SilentlyContinue) { $pm = "scoop" }

    if (-not $pm) {
        Write-Status "Не найден winget/choco/scoop. Установите один из них или пакеты вручную:" "Red"
        Write-Status "  winget: https://github.com/microsoft/winget-cli/releases" "Yellow"
        Write-Status "  choco:  https://chocolatey.org/install" "Yellow"
        Write-Status "  scoop:  https://scoop.sh" "Yellow"
        return
    }

    Write-Status "Используется пакетный менеджер: $pm" "Cyan"
    $wingetMap = @{ git = "Git.Git"; node = "OpenJS.NodeJS.LTS"; npm = "OpenJS.NodeJS.LTS"; curl = "cURL.cURL" }
    $chocoMap  = @{ git = "git"; node = "nodejs-lts"; npm = "nodejs-lts"; curl = "curl" }
    $scoopMap  = @{ git = "git"; node = "nodejs-lts"; npm = "nodejs-lts"; curl = "curl" }

    foreach ($pkg in $missing) {
        $pkgId = switch ($pm) {
            "winget" { $wingetMap[$pkg] }
            "choco"  { $chocoMap[$pkg] }
            "scoop"  { $scoopMap[$pkg] }
        }
        if (-not $pkgId) { continue }
        Write-Status "  Установка $pkg ($pm → $pkgId)..." "Cyan"
        try {
            switch ($pm) {
                "winget" { & winget install --id $pkgId --silent --accept-source-agreements --accept-package-agreements 2>&1 | Out-Null }
                "choco"  { & choco install $pkgId -y 2>&1 | Out-Null }
                "scoop"  { & scoop install $pkgId 2>&1 | Out-Null }
            }
        } catch {
            Write-Status "  [WARN] $pkg не установлен: $($_.Exception.Message)" "Yellow"
        }
    }

    # Обновляем PATH для текущей сессии
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

    Write-Host ""
    Write-Status "Проверка после установки:" "Cyan"
    foreach ($p in $pkgs) {
        $c = Get-Command $p.Cmd -ErrorAction SilentlyContinue
        if ($c) { Write-Status "  [OK]   $($p.Name)" "Green" }
        else    { Write-Status "  [MISS] $($p.Name) — установите вручную или перезапустите терминал" "Yellow" }
    }
}

if ($installChoice -eq "0") {
    Install-SystemDependencies
    Write-Host ""
    Write-Status "Готово. Перезапустите терминал и запустите install.ps1 снова для установки инструментов." "Cyan"
    return
}

# ─── Helper: синхронизация ярлыков для уже установленных CLI ────────────────
# Проверяет наличие CLI на диске (через npm-bin в PATH или жёсткий путь %APPDATA%\npm)
# и создаёт недостающие ярлыки на рабочем столе для каждого найденного инструмента.
function Sync-LauncherShortcuts {
    param(
      [string]$RepoDir,
      [switch]$Force
    )

    $desktop = [Environment]::GetFolderPath("Desktop")
    if (-not $desktop -or -not (Test-Path -LiteralPath $desktop)) {
      $desktop = Join-Path $env:USERPROFILE "Desktop"
      if (-not (Test-Path -LiteralPath $desktop)) { $desktop = $env:USERPROFILE }
    }

    $hiddenDir = Join-Path $desktop "Cloud Launchers"
    if (-not (Test-Path -LiteralPath $hiddenDir)) {
      New-Item -ItemType Directory -Path $hiddenDir -Force | Out-Null
    }
    $attrs = (Get-Item -LiteralPath $hiddenDir -Force).Attributes
    if (($attrs -band [System.IO.FileAttributes]::Hidden) -eq 0) {
      (Get-Item -LiteralPath $hiddenDir -Force).Attributes = $attrs -bor [System.IO.FileAttributes]::Hidden
    }

    # Migrate ALL cloud-related files from desktop root to hidden folder
    $cloudBaseNames = @("Qwen Code (cloud)", "Claude Code (cloud)", "OpenCode (cloud)", "Freebuff (cloud)", "OpenClaude (cloud)")
    foreach ($baseName in $cloudBaseNames) {
      foreach ($ext in @(".cmd", ".lnk")) {
        $oldPath = Join-Path $desktop "$baseName$ext"
        $newPath = Join-Path $hiddenDir "$baseName$ext"
        if ((Test-Path -LiteralPath $oldPath) -and -not (Test-Path -LiteralPath $newPath)) {
          Move-Item -LiteralPath $oldPath -Destination $newPath -Force -ErrorAction SilentlyContinue
        }
      }
    }

    # Hide ALL internal files in Cloud Launchers (folder itself is already hidden)
    Get-ChildItem -LiteralPath $hiddenDir -Filter "*.cmd" | ForEach-Object {
      $_.Attributes = $_.Attributes -bor [System.IO.FileAttributes]::Hidden
    }
    Get-ChildItem -LiteralPath $hiddenDir -Filter "*.lnk" | ForEach-Object {
      $_.Attributes = $_.Attributes -bor [System.IO.FileAttributes]::Hidden
    }

    $scriptsDir = Join-Path $RepoDir "scripts"
    $psExe = (Get-Command powershell.exe -ErrorAction SilentlyContinue).Source
    if (-not $psExe) { $psExe = "powershell.exe" }

    function Test-CliInstalled([string]$CmdName) {
      $c = Get-Command $CmdName -ErrorAction SilentlyContinue
      if ($c) { return $true }
      foreach ($p in @(
          (Join-Path $env:APPDATA "npm\$CmdName.cmd"),
          (Join-Path $env:APPDATA "npm\$CmdName.ps1"),
          (Join-Path $env:APPDATA "npm\$CmdName")
      )) {
        if (Test-Path -LiteralPath $p) { return $true }
      }
      return $false
    }

    function Write-CmdFile-Safe {
      param([string]$Path, [string]$Content)
      try {
        if (Test-Path -LiteralPath $Path) {
          $attrs = (Get-Item -LiteralPath $Path -Force).Attributes
          if (($attrs -band [System.IO.FileAttributes]::ReadOnly) -ne 0) {
            (Get-Item -LiteralPath $Path -Force).Attributes = $attrs -bxor [System.IO.FileAttributes]::ReadOnly
          }
        }
        [System.IO.File]::WriteAllText($Path, $Content, (New-Object System.Text.UTF8Encoding($false)))
        return $true
      } catch [System.UnauthorizedAccessException] {
        try {
          $tmp = "$Path.$PID.$(Get-Random).tmp"
          [System.IO.File]::WriteAllText($tmp, $Content, (New-Object System.Text.UTF8Encoding($false)))
          if (Test-Path -LiteralPath $Path) {
            $bak = "$Path.bak"
            if (Test-Path -LiteralPath $bak) { Remove-Item -LiteralPath $bak -Force -ErrorAction SilentlyContinue }
            Rename-Item -LiteralPath $Path -NewName (Split-Path -Leaf $bak) -Force -ErrorAction Stop
          }
          Move-Item -LiteralPath $tmp -Destination $Path -Force -ErrorAction Stop
          return $true
        } catch {
          $newPath = "$Path.new"
          try {
            [System.IO.File]::WriteAllText($newPath, $Content, (New-Object System.Text.UTF8Encoding($false)))
            Write-Status ("    [WARN] Файл заблокирован. Новый записан как: $newPath") "Yellow"
          } catch {}
          return $false
        }
      }
    }

    function New-LauncherShortcutSync {
      param([string]$Name, [string]$ScriptFile)
      $launcher = Join-Path $scriptsDir $ScriptFile
      if (-not (Test-Path -LiteralPath $launcher)) { return $false }

      $cmdPath = Join-Path $hiddenDir "$Name.cmd"
      $lnkPath = Join-Path $hiddenDir "$Name.lnk"
      $created = $false
      $cmdContent = "@echo off`r`nchcp 65001 >nul 2>`&1`r`npowershell -NoProfile -ExecutionPolicy Bypass -Command `"& '$launcher'`"`r`nif ($LASTEXITCODE -ne 0) pause"
      if ($Force -or -not (Test-Path -LiteralPath $cmdPath)) {
        $ok = Write-CmdFile-Safe -Path $cmdPath -Content $cmdContent
        if ($ok) { $created = $true }
      }
      if (-not (Test-Path -LiteralPath $lnkPath)) {
        try {
          $cmdExe = (Get-Command cmd.exe -ErrorAction SilentlyContinue).Source
          if (-not $cmdExe) { $cmdExe = "$env:SystemRoot\System32\cmd.exe" }
          $shell = New-Object -ComObject WScript.Shell -ErrorAction Stop
          $lnk = $shell.CreateShortcut($lnkPath)
          $lnk.TargetPath = $cmdExe
          $lnk.Arguments = "/k chcp 65001 >nul & `"$psExe`" -NoProfile -ExecutionPolicy Bypass -File `"$launcher`""
          $lnk.WorkingDirectory = $RepoDir
          $lnk.WindowStyle = 1
          $lnk.Save()
          $created = $true
        } catch {}
      }
      return $created
    }

    function New-DesktopLaunchShortcut {
      param([string]$Name, [string]$TargetCmd)
      $lnkPath = Join-Path $desktop "$Name.lnk"
      if (Test-Path -LiteralPath $lnkPath) { return $false }
      try {
        $cmdExe = (Get-Command cmd.exe -ErrorAction SilentlyContinue).Source
        if (-not $cmdExe) { $cmdExe = "$env:SystemRoot\System32\cmd.exe" }
        $shell = New-Object -ComObject WScript.Shell -ErrorAction Stop
        $lnk = $shell.CreateShortcut($lnkPath)
        $lnk.TargetPath = $cmdExe
        $lnk.Arguments = "/c `"$TargetCmd`""
        $lnk.WorkingDirectory = $hiddenDir
        $lnk.WindowStyle = 1
        $lnk.Save()
        return $true
      } catch { return $false }
    }

    $map = @(
      @{ Cli = "qwen";       Name = "Qwen Code (cloud)";   Script = "run-qwen-code-launcher.ps1";  ShortName = "Qwen Code" }
      @{ Cli = "claude";     Name = "Claude Code (cloud)"; Script = "run-claude-cloud-launcher.ps1"; ShortName = "Claude Code" }
      @{ Cli = "opencode";   Name = "OpenCode (cloud)";    Script = "run-opencode-launcher.ps1";     ShortName = "OpenCode" }
      @{ Cli = "freebuff";   Name = "Freebuff (cloud)";    Script = "run-freebuff-launcher.ps1";     ShortName = "Freebuff" }
      @{ Cli = "openclaude"; Name = "OpenClaude (cloud)";  Script = "run-openclaude-launcher.ps1";   ShortName = "OpenClaude" }
    )

    $added = 0
    $present = 0
    foreach ($entry in $map) {
      if (-not (Test-CliInstalled -CmdName $entry.Cli)) {
        Write-Status ("  [SKIP] {0} CLI не установлен — ярлык пропущен" -f $entry.Cli) "DarkGray"
        continue
      }

      $hasLnk = Test-Path -LiteralPath (Join-Path $hiddenDir "$($entry.Name).lnk")
      $hasCmd = Test-Path -LiteralPath (Join-Path $hiddenDir "$($entry.Name).cmd")
      if (-not $Force -and ($hasLnk -or $hasCmd)) {
        $present++
      } else {
        $created = New-LauncherShortcutSync -Name $entry.Name -ScriptFile $entry.Script
        if ($created) {
          Write-Status ("  [+] {0}" -f $entry.Name) "Green"
          $added++
        } elseif ($Force) {
          $present++
        }
      }

      $desktopLnk = Join-Path $desktop "$($entry.ShortName).lnk"
      if (-not (Test-Path -LiteralPath $desktopLnk)) {
        $cmdTarget = Join-Path $hiddenDir "$($entry.Name).cmd"
        $ok = New-DesktopLaunchShortcut -Name $entry.ShortName -TargetCmd $cmdTarget
        if ($ok) { $added++ }
      } else {
        $present++
      }
    }

    Write-Host ""
    Write-Status ("Ярлыки: в скрытой папке = {0}, на рабочем столе = 5" -f ($present + $added)) "Cyan"
}

# --- Update all components ---
if ($installChoice -eq "7") {
    Write-Host ""
    Write-Status "======================================================================" "Cyan"
    Write-Status "ОБНОВЛЕНИЕ ВСЕХ КОМПОНЕНТОВ" "Magenta"
    Write-Status "======================================================================" "Cyan"
    Write-Host ""
    if (Test-Path -LiteralPath (Join-Path $InstallDir ".git")) {
        Write-Status "Проверка обновлений репозитория..." "Cyan"
        Push-Location $InstallDir
        try {
            $prevPrompt = $env:GIT_TERMINAL_PROMPT
            $prevGcm = $env:GCM_INTERACTIVE
            $env:GIT_TERMINAL_PROMPT = "0"
            $env:GCM_INTERACTIVE = "Never"

            $headBefore = $null
            try { $headBefore = (& git rev-parse HEAD 2>$null).Trim() } catch {}

            $prevEAP = $ErrorActionPreference; $ErrorActionPreference = "Continue"
            $out = git pull origin main 2>&1
            $code = $LASTEXITCODE
            $ErrorActionPreference = $prevEAP

            $headAfter = $null
            try { $headAfter = (& git rev-parse HEAD 2>$null).Trim() } catch {}

            if ($code -eq 0) {
                if ($headBefore -and $headAfter -and $headBefore -eq $headAfter) {
                    Write-Status "  [OK] Репозиторий уже актуален ($($headAfter.Substring(0,7)))" "DarkGray"
                } else {
                    Write-Status "  [OK] Репозиторий обновлён ($($headBefore.Substring(0,7)) → $($headAfter.Substring(0,7)))" "Green"
                }
            } else {
                Write-Status "  [WARN] git pull failed (code $code)" "Yellow"
                if ($out) { Write-Host $out }
            }
        } catch {
            Write-Status "  [WARN] Не удалось обновить" "Yellow"
        } finally {
            $env:GIT_TERMINAL_PROMPT = $prevPrompt
            $env:GCM_INTERACTIVE = $prevGcm
            Pop-Location
        }
    } else {
        Write-Status "  [SKIP] Репозиторий не найден, пропуск git pull" "Yellow"
    }

    Write-Host ""
    Write-Status "Проверка и обновление npm пакетов..." "Cyan"

    $prevEAP = $ErrorActionPreference; $ErrorActionPreference = "Continue"

    # Helper: get installed version (null if not installed).
    # Сначала пробует npm ls (не запускает binary, не триггерит ECONNRESET у freebuff).
    # Если не получилось — fallback на cmd --version.
    function Get-PkgVersion($cmd, $npmPkg) {
      # Prefer npm ls (быстро, не запускает binary, безопасно для freebuff)
      if ($npmPkg) {
        try {
          $json = (& npm.cmd ls -g $npmPkg --depth=0 --json 2>$null) -join ""
          if ($json) {
            $parsed = $json | ConvertFrom-Json
            $dep = $parsed.dependencies.PSObject.Properties[$npmPkg]
            if ($dep -and $dep.Value.version) {
              return [string]$dep.Value.version
            }
            # Может быть установлен под другим именем (peers/optional deps)
            # fallback ниже.
          }
        } catch {}
      }
      # Fallback: cmd --version. Парсим только SEMVER (до пробела/конца),
      # т.к. claude/openclaude возвращают "2.1.168 (Claude Code)".
      $c = Get-Command $cmd -ErrorAction SilentlyContinue
      if ($c) {
        try {
          $v = (& $cmd --version 2>$null) -join ""
          $v = $v.Trim()
          # Extract leading semver-like token (digits + dots + dashes)
          if ($v -match '(\d+(?:\.\d+)*(?:[-+][0-9A-Za-z.-]*)?)') {
            return $Matches[1]
          }
          return $v
        } catch { return "?" }
      }
      return $null
    }

    # Helper: get latest version from npm registry (null if unknown)
    function Get-LatestNpmVersion([string]$NpmPkg) {
        try {
            $r = & npm.cmd view $NpmPkg version 2>$null
            if ($LASTEXITCODE -eq 0 -and $r) { return ($r -join "").Trim() }
        } catch {}
        return $null
    }

    $pkgs = @(
        @{ Name = "qwen-code";   NpmPkg = "@qwen-code/qwen-code";      Fallback = "@anthropic-ai/qwen-code"; Cmd = "qwen" },
        @{ Name = "claude-code"; NpmPkg = "@anthropic-ai/claude-code"; Fallback = $null;                     Cmd = "claude" },
        @{ Name = "opencode-ai"; NpmPkg = "opencode-ai";               Fallback = $null;                     Cmd = "opencode" },
        @{ Name = "freebuff";    NpmPkg = "freebuff";                  Fallback = $null;                     Cmd = "freebuff" },
        @{ Name = "openclaude";  NpmPkg = "@gitlawb/openclaude";       Fallback = $null;                     Cmd = "openclaude" }
    )

    foreach ($pkg in $pkgs) {
        $before = Get-PkgVersion -cmd $pkg.Cmd -npmPkg $pkg.NpmPkg
        $latest = Get-LatestNpmVersion $pkg.NpmPkg

        # Already installed AND matches latest published version → skip npm install
        if ($before -and $latest -and $before -eq $latest) {
            Write-Status ("  [OK] {0} v{1} (уже актуально)" -f $pkg.Name, $before) "DarkGray"
            continue
        }

        # Installed but no registry info → assume up-to-date (offline / npm registry unreachable)
        if ($before -and -not $latest) {
            Write-Status ("  [OK] {0} v{1} (без проверки registry)" -f $pkg.Name, $before) "DarkGray"
            continue
        }

        # Installed but outdated → upgrade
        if ($before) {
            $target = if ($latest) { $latest } else { "latest" }
            Write-Status ("  → {0}: {1} → {2}" -f $pkg.Name, $before, $target) "Cyan"
        } else {
            Write-Status ("  → Установка {0} (не установлен)" -f $pkg.Name) "Cyan"
        }

        & npm.cmd install -g "$($pkg.NpmPkg)@latest" 2>$null
        if ($LASTEXITCODE -ne 0 -and $pkg.Fallback) {
            & npm.cmd install -g "$($pkg.Fallback)@latest" 2>$null
        }
        $after = Get-PkgVersion -cmd $pkg.Cmd -npmPkg $pkg.NpmPkg
        if ($after) {
            $verInfo = if ($before -and $before -ne $after) { "($before → $after)" } else { "($after)" }
            Write-Status ("  [OK] {0} {1}" -f $pkg.Name, $verInfo) "Green"
        } else {
            Write-Status ("  [SKIP] {0} не установлен после обновления" -f $pkg.Name) "Yellow"
        }
    }

    # free-claude-code proxy update (skip if already up-to-date)
    $fccDir = Join-Path $env:USERPROFILE ".free-claude-code"
    if (Test-Path -LiteralPath (Join-Path $fccDir ".git")) {
        Write-Status "Проверка free-claude-code proxy..." "Cyan"
        Push-Location $fccDir
        try {
            $fccHeadBefore = $null
            try { $fccHeadBefore = (& git rev-parse HEAD 2>$null).Trim() } catch {}

            $prevEAP2 = $ErrorActionPreference; $ErrorActionPreference = "Continue"
            & git pull origin main 2>$null

            $fccHeadAfter = $null
            try { $fccHeadAfter = (& git rev-parse HEAD 2>$null).Trim() } catch {}

            $uvExePath = Join-Path $env:USERPROFILE ".local\bin\uv.exe"
            if ($fccHeadBefore -and $fccHeadAfter -and $fccHeadBefore -ne $fccHeadAfter) {
                Write-Status "  → free-claude-code обновлён, синхронизация Python зависимостей..." "Cyan"
                if (Test-Path -LiteralPath $uvExePath) { & $uvExe sync 2>$null }
                Write-Status "  [OK] free-claude-code обновлён" "Green"
            } elseif ($fccHeadAfter) {
                Write-Status "  [OK] free-claude-code уже актуален ($($fccHeadAfter.Substring(0,7)))" "DarkGray"
            } else {
                if (Test-Path -LiteralPath $uvExePath) { & $uvExe sync 2>$null }
                Write-Status "  [OK] free-claude-code sync выполнен" "Green"
            }
            $ErrorActionPreference = $prevEAP2
        } catch {
            Write-Status "  [WARN] Не удалось обновить free-claude-code" "Yellow"
        } finally {
            Pop-Location
        }
    }

    $ErrorActionPreference = $prevEAP

    # Синхронизация ярлыков: в [7] update всегда переписываем .cmd/.lnk,
    # чтобы в .cmd обновились пути к launcher скриптам после git pull.
    Write-Host ""
    Write-Status "Обновление ярлыков на рабочем столе..." "Cyan"
    Sync-LauncherShortcuts -RepoDir $InstallDir -Force

    Write-Host ""
    Write-Status "======================================================================" "Green"
    Write-Status "ОБНОВЛЕНИЕ ЗАВЕРШЕНО!" "Green"
    Write-Status "======================================================================" "Green"
    Write-Host ""
    Read-Host "Нажмите Enter для выхода"
    return
}

# --- Reorder desktop shortcuts: hide cloud files, keep only 5 launchers visible ---
if ($installChoice -eq "9") {
    Write-Host ""
    Write-Status "======================================================================" "Cyan"
    Write-Status "УПОРЯДОЧЕНИЕ ЯРЛЫКОВ НА РАБОЧЕМ СТОЛЕ" "Magenta"
    Write-Status "======================================================================" "Cyan"
    Write-Host ""

    $desktop = [Environment]::GetFolderPath("Desktop")
    if (-not $desktop -or -not (Test-Path -LiteralPath $desktop)) {
      $desktop = Join-Path $env:USERPROFILE "Desktop"
      if (-not (Test-Path -LiteralPath $desktop)) { $desktop = $env:USERPROFILE }
    }

    $cloudFolder = Join-Path $desktop "Cloud Launchers"
    if (-not (Test-Path -LiteralPath $cloudFolder)) {
      Write-Status "Папка Cloud Launchers не найдена. Сначала запустите установку." "Yellow"
      Read-Host "Нажмите Enter для выхода"
      return
    }

    # Hide Cloud Launchers folder
    $folderItem = Get-Item -LiteralPath $cloudFolder -Force
    $folderItem.Attributes = $folderItem.Attributes -bor [System.IO.FileAttributes]::Hidden

    # Hide all .cmd files in Cloud Launchers
    Get-ChildItem -LiteralPath $cloudFolder -Filter "*.cmd" | ForEach-Object {
      $_.Attributes = $_.Attributes -bor [System.IO.FileAttributes]::Hidden
    }

    # Hide any remaining cloud files on desktop root (legacy cleanup)
    Get-ChildItem -LiteralPath $desktop -Filter "*.cmd" | Where-Object { $_.BaseName -like "* (cloud)" -or $_.BaseName -like "*cloud*" } | ForEach-Object {
      $_.Attributes = $_.Attributes -bor [System.IO.FileAttributes]::Hidden
    }
    Get-ChildItem -LiteralPath $desktop -Filter "*.lnk" | Where-Object { $_.BaseName -like "* (cloud)" -or $_.BaseName -like "*cloud*" } | ForEach-Object {
      $_.Attributes = $_.Attributes -bor [System.IO.FileAttributes]::Hidden
    }

    Write-Host ""
    Write-Status "Готово." "Green"
    Write-Status "  - Папка Cloud Launchers скрыта" "DarkGray"
    Write-Status "  - .cmd файлы в папке скрыты" "DarkGray"
    Write-Status "  - На рабочем столе остались только 5 ярлыков: Qwen Code, Claude Code, OpenCode, Freebuff, OpenClaude" "DarkGray"
    Write-Host ""
    Read-Host "Нажмите Enter для выхода"
    return
}

# --- Uninstall ---
if ($installChoice -eq "8") {
    Write-Host ""
    Write-Status "======================================================================" "Red"
    Write-Status "ПОЛНОЕ УДАЛЕНИЕ" "Red"
    Write-Status "======================================================================" "Red"
    Write-Host ""
    Write-Host "ВНИМАНИЕ: будет удалено:" -ForegroundColor Red
    Write-Host "  - Repository: $InstallDir" -ForegroundColor Red
    Write-Host "  - Session directories (qwen/claude/opencode-sessions)" -ForegroundColor Red
    Write-Host "  - CLI configs (~/.claude, ~/.qwen)" -ForegroundColor Red
    Write-Host "  - free-claude-code proxy (~/.free-claude-code)" -ForegroundColor Red
    Write-Host "  - uv (Python package manager, ~/.local/bin/uv)" -ForegroundColor Red
    Write-Host "  - API keys (user environment variables)" -ForegroundColor Red
    Write-Host "  - Desktop shortcuts (.cmd, .lnk)" -ForegroundColor Red
    Write-Host "  - Global npm packages (qwen-code, claude-code, opencode-ai, freebuff, openclaude)" -ForegroundColor Red
    Write-Host ""
    $confirm = Read-Host "Введите 'yes' для подтверждения удаления"
    if ($confirm -ne "yes") {
        Write-Status "Удаление отменено." "Yellow"
        Read-Host "Нажмите Enter для выхода"
        return
    }

    Write-Host ""
    Write-Status "Удаляю репозиторий..." "Cyan"
    if (Test-Path -LiteralPath $InstallDir) {
        Remove-Item -LiteralPath $InstallDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Status "  [OK] Removed: $InstallDir" "Green"
    } else {
        Write-Status "  [SKIP] $InstallDir not found" "Yellow"
    }

    Write-Status "Удаляю конфиги CLI..." "Cyan"
    foreach ($cfg in @("$env:USERPROFILE\.claude", "$env:USERPROFILE\.qwen", "$env:USERPROFILE\.opencode")) {
        if (Test-Path -LiteralPath $cfg) {
            Remove-Item -LiteralPath $cfg -Recurse -Force -ErrorAction SilentlyContinue
            Write-Status "  [OK] Removed: $cfg" "Green"
        }
    }

    Write-Status "Удаляю API ключи из переменных окружения пользователя..." "Cyan"
    foreach ($var in @("NVIDIA_NIM_API_KEY", "ZAI_API_KEY", "OPENAI_API_KEY", "GROQ_API_KEY", "OPENROUTER_API_KEY", "BAI_API_KEY")) {
        $existing = [Environment]::GetEnvironmentVariable($var, "User")
        if ($existing) {
            [Environment]::SetEnvironmentVariable($var, $null, "User")
            Write-Status "  [OK] Removed: $var" "Green"
        }
    }

    Write-Status "Удаляю ярлыки на рабочем столе..." "Cyan"
    $desktop = [Environment]::GetFolderPath("Desktop")
    if (-not $desktop) { $desktop = Join-Path $env:USERPROFILE "Desktop" }
    foreach ($name in @("Qwen Code (cloud)", "Claude Code (cloud)", "OpenCode (cloud)", "Freebuff (cloud)", "OpenClaude (cloud)", "Claude Mem Start", "Claude Mem Viewer", "Claude Mem Clear", "Obsidian")) {
        foreach ($ext in @(".cmd", ".lnk")) {
            $f = Join-Path $desktop "$name$ext"
            if (Test-Path -LiteralPath $f) {
                Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue
                Write-Status "  [OK] Removed: $f" "Green"
            }
        }
    }

    Write-Status "Удаление глобальных npm пакетов..." "Cyan"
    $prevEAP = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    foreach ($pkg in @("@qwen-code/qwen-code", "@anthropic-ai/qwen-code", "@anthropic-ai/claude-code", "opencode-ai", "freebuff", "@gitlawb/openclaude")) {
        & npm.cmd uninstall -g $pkg 2>$null
        Write-Status "  [OK] Uninstalled: $pkg" "Green"
    }
    $ErrorActionPreference = $prevEAP

    Write-Status "Удаление free-claude-code proxy..." "Cyan"
    $fccDir = Join-Path $env:USERPROFILE ".free-claude-code"
    if (Test-Path -LiteralPath $fccDir) {
        Remove-Item -LiteralPath $fccDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Status "  [OK] Removed: $fccDir" "Green"
    } else {
        Write-Status "  [SKIP] $fccDir not found" "Yellow"
    }

    Write-Status "Удаление uv (Python package manager)..." "Cyan"
    $uvDir = Join-Path $env:USERPROFILE ".local"
    if (Test-Path -LiteralPath $uvDir) {
        Remove-Item -LiteralPath $uvDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Status "  [OK] Removed: $uvDir" "Green"
    } else {
        Write-Status "  [SKIP] $uvDir not found" "Yellow"
    }

    Write-Host ""
    Write-Status "======================================================================" "Green"
    Write-Status "УДАЛЕНИЕ ЗАВЕРШЕНО!" "Green"
    Write-Status "======================================================================" "Green"
    Write-Host ""
    Write-Status "Перезапустите терминал, чтобы переменные окружения применились." "Yellow"
    Write-Host ""
    Read-Host "Нажмите Enter для выхода"
    return
}

$installQwen = $false
$installClaude = $false
$installOpenCode = $false
$installFreebuff = $false
$installOpenClaude = $false

switch ($installChoice) {
    "1" { $installQwen = $true; $installClaude = $true; $installOpenCode = $true; $installFreebuff = $true; $installOpenClaude = $true }
    "2" { $installQwen = $true }
    "3" { $installClaude = $true }
    "4" { $installOpenCode = $true }
    "5" { $installFreebuff = $true }
    "6" { $installOpenClaude = $true }
    "X" { Write-Status "Выход." "Yellow"; return }
    default { Write-Status "Неверный выбор. Устанавливаем все инструменты." "Yellow"; $installQwen = $true; $installClaude = $true; $installOpenCode = $true; $installFreebuff = $true; $installOpenClaude = $true }
}

Write-Host ""
Write-Status "======================================================================" "Cyan"
Write-Status "УСТАНОВКА CLI" "Magenta"
Write-Status "======================================================================" "Cyan"
Write-Host ""

if ($installQwen) {
    Write-Status "Установка Qwen Code CLI..." "Cyan"
    $prevEAP = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    & npm.cmd install -g @qwen-code/qwen-code@latest 2>$null
    if ($LASTEXITCODE -ne 0) {
        & npm.cmd install -g @anthropic-ai/qwen-code@latest 2>$null
    }
    $ErrorActionPreference = $prevEAP
    $qwenCmd = Get-Command qwen -ErrorAction SilentlyContinue
    if ($qwenCmd) {
        Write-Status "  [OK] Qwen Code CLI: $($qwenCmd.Source)" "Green"
    } else {
        Write-Status "  [WARN] Qwen Code CLI not found. Install manually:" "Yellow"
        Write-Status "         npm i -g @qwen-code/qwen-code" "Yellow"
    }
}

if ($installClaude) {
    Write-Status "Установка Claude Code CLI..." "Cyan"
    $prevEAP = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    & npm.cmd install -g @anthropic-ai/claude-code@latest 2>$null
    $ErrorActionPreference = $prevEAP
    $claudeCmd = Get-Command claude -ErrorAction SilentlyContinue
    if ($claudeCmd) {
        Write-Status "  [OK] Claude Code CLI: $($claudeCmd.Source)" "Green"
    } else {
        Write-Status "  [WARN] Claude Code CLI not found. Install manually:" "Yellow"
        Write-Status "         npm i -g @anthropic-ai/claude-code" "Yellow"
    }

    Write-Status "" "Cyan"

    # uv (Python package manager for free-claude-code)
    Write-Status "  Установка uv (Python package manager)..." "Cyan"
    $uvExe = Join-Path $env:USERPROFILE ".local\bin\uv.exe"
    if (-not (Test-Path -LiteralPath $uvExe)) {
        $prevEAP = $ErrorActionPreference; $ErrorActionPreference = "Continue"
        try {
            $uvInstallScript = Join-Path $env:TEMP "uv-install.ps1"
            Invoke-WebRequest -Uri "https://astral.sh/uv/install.ps1" -OutFile $uvInstallScript -UseBasicParsing
            & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $uvInstallScript 2>$null
            Remove-Item -LiteralPath $uvInstallScript -Force -ErrorAction SilentlyContinue
        } catch {
            # Fallback: try with curl
            & curl.exe -LsSf https://astral.sh/uv/install.sh -o "$env:TEMP\uv-install.sh" 2>$null
        }
        $ErrorActionPreference = $prevEAP
    }
    if (Test-Path -LiteralPath $uvExe) {
        Write-Status "  [OK] uv установлен: $uvExe" "Green"
    } else {
        # Check if it was installed to a different location
        $uvCmd = Get-Command uv -ErrorAction SilentlyContinue
        if ($uvCmd) {
            Write-Status "  [OK] uv установлен: $($uvCmd.Source)" "Green"
        } else {
            Write-Status "  [WARN] uv не найден. NIM/OpenRouter для Claude будут недоступны." "Yellow"
        }
    }

    # free-claude-code proxy (for NIM/OpenRouter with Claude Code)
    $fccDir = Join-Path $env:USERPROFILE ".free-claude-code"
    if (-not (Test-Path -LiteralPath $fccDir)) {
        Write-Status "  Клонирование free-claude-code proxy..." "Cyan"
        $prevEAP = $ErrorActionPreference; $ErrorActionPreference = "Continue"
        & git clone https://github.com/Alishahryar1/free-claude-code.git $fccDir 2>$null
        $ErrorActionPreference = $prevEAP
        if (Test-Path -LiteralPath $fccDir) {
            # Pre-install deps
            if (Test-Path -LiteralPath $uvExe) {
                $prevEAP = $ErrorActionPreference; $ErrorActionPreference = "Continue"
                Push-Location $fccDir
                try { & $uvExe sync 2>$null } catch {}
                Pop-Location
                $ErrorActionPreference = $prevEAP
            }
            Write-Status "  [OK] free-claude-code установлен: $fccDir" "Green"
        } else {
            Write-Status "  [WARN] Не удалось клонировать free-claude-code. NIM/OpenRouter для Claude будут недоступны." "Yellow"
        }
    } else {
        Write-Status "  [OK] free-claude-code уже установлен" "Green"
    }
}

if ($installOpenCode) {
    Write-Status "Установка OpenCode CLI..." "Cyan"
    $prevEAP = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    & npm.cmd install -g opencode-ai@latest 2>$null
    $ErrorActionPreference = $prevEAP
    $ocCmd = Get-Command opencode -ErrorAction SilentlyContinue
    if ($ocCmd) {
        Write-Status "  [OK] OpenCode CLI: $($ocCmd.Source)" "Green"
    } else {
        Write-Status "  [WARN] OpenCode CLI not found. Install manually:" "Yellow"
        Write-Status "         npm i -g opencode-ai@latest" "Yellow"
    }
}

if ($installFreebuff) {
    Write-Status "Установка Freebuff CLI..." "Cyan"
    $prevEAP = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    & npm.cmd install -g freebuff@latest 2>$null
    $ErrorActionPreference = $prevEAP
    $fbCmd = Get-Command freebuff -ErrorAction SilentlyContinue
    if ($fbCmd) {
        Write-Status "  [OK] Freebuff CLI: $($fbCmd.Source)" "Green"
    } else {
        Write-Status "  [WARN] Freebuff CLI not found. Install manually:" "Yellow"
        Write-Status "         npm i -g freebuff" "Yellow"
    }
}

if ($installOpenClaude) {
    Write-Status "Установка OpenClaude CLI..." "Cyan"
    $prevEAP = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    & npm.cmd install -g @gitlawb/openclaude@latest 2>$null
    $ErrorActionPreference = $prevEAP
    $oclaudeCmd = Get-Command openclaude -ErrorAction SilentlyContinue
    if ($oclaudeCmd) {
        Write-Status "  [OK] OpenClaude CLI: $($oclaudeCmd.Source)" "Green"
    } else {
        Write-Status "  [WARN] OpenClaude CLI not found. Install manually:" "Yellow"
        Write-Status "         npm i -g @gitlawb/openclaude" "Yellow"
    }
}

Write-Host ""
Write-Status "======================================================================" "Cyan"
Write-Status "НАСТРОЙКА API КЛЮЧЕЙ" "Magenta"
Write-Status "======================================================================" "Cyan"
Write-Host ""
Write-Status "Оставьте пустым чтобы пропустить. Ключи можно поменять позже через меню лаунчера." "Yellow"
Write-Host ""

function Read-Secret($Prompt) {
    Write-Host -NoNewline $Prompt
    $key = ""
    while ($true) {
        $cki = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        if ($cki.Key -eq "Enter" -or [int]$cki.Character -eq 13 -or [int]$cki.Character -eq 10) {
            Write-Host ""
            break
        } elseif ($cki.Key -eq "Backspace") {
            if ($key.Length -gt 0) {
                $key = $key.Substring(0, $key.Length - 1)
                Write-Host -NoNewline "`b `b"
            }
        } elseif ($cki.Key -eq "Escape") {
            Write-Host ""
            return ""
        } elseif ($cki.Character -and [int]$cki.Character -ge 32) {
            $key += $cki.Character
            Write-Host -NoNewline "*"
        }
    }
    return $key
}

$nimKey = Read-Secret "NVIDIA NIM API key (Enter = пропустить): "
if (-not [string]::IsNullOrWhiteSpace($nimKey)) {
    [Environment]::SetEnvironmentVariable("NVIDIA_NIM_API_KEY", $nimKey.Trim(), "User")
    Write-Status "  [OK] NVIDIA_NIM_API_KEY saved" "Green"
} else {
    Write-Status "  [SKIP] NVIDIA_NIM_API_KEY" "Yellow"
}

Write-Host ""

$zaiKey = Read-Secret "Z.AI API key (Enter = пропустить): "
if (-not [string]::IsNullOrWhiteSpace($zaiKey)) {
    [Environment]::SetEnvironmentVariable("ZAI_API_KEY", $zaiKey.Trim(), "User")
    Write-Status "  [OK] ZAI_API_KEY saved" "Green"
} else {
    Write-Status "  [SKIP] ZAI_API_KEY" "Yellow"
}

Write-Host ""

$groqKey = Read-Secret "Groq API key (Enter = пропустить): "
if (-not [string]::IsNullOrWhiteSpace($groqKey)) {
    [Environment]::SetEnvironmentVariable("GROQ_API_KEY", $groqKey.Trim(), "User")
    Write-Status "  [OK] GROQ_API_KEY saved" "Green"
} else {
    Write-Status "  [SKIP] GROQ_API_KEY" "Yellow"
}

Write-Host ""

$orKey = Read-Secret "OpenRouter API key (Enter = пропустить): "
if (-not [string]::IsNullOrWhiteSpace($orKey)) {
    [Environment]::SetEnvironmentVariable("OPENROUTER_API_KEY", $orKey.Trim(), "User")
    Write-Status "  [OK] OPENROUTER_API_KEY saved" "Green"
} else {
    Write-Status "  [SKIP] OPENROUTER_API_KEY" "Yellow"
}

Write-Host ""

$baiKey = Read-Secret "B.AI API key (Enter = пропустить): "
if (-not [string]::IsNullOrWhiteSpace($baiKey)) {
    [Environment]::SetEnvironmentVariable("BAI_API_KEY", $baiKey.Trim(), "User")
    Write-Status "  [OK] BAI_API_KEY saved" "Green"
} else {
    Write-Status "  [SKIP] BAI_API_KEY" "Yellow"
}

Write-Host ""
Write-Status "======================================================================" "Cyan"
Write-Status "НАСТРОЙКА СЕССИЙ (/resume)" "Magenta"
Write-Status "======================================================================" "Cyan"
Write-Host ""

if ($installQwen) {
    $sharedDir = Join-Path $InstallDir "qwen-sessions\_shared\.qwen"
    if (-not (Test-Path -LiteralPath $sharedDir)) { New-Item -ItemType Directory -Path $sharedDir -Force | Out-Null }
    Write-Status "  [OK] qwen-sessions/_shared/" "Green"
}
if ($installClaude) {
    $claudeShared = Join-Path $InstallDir "claude-sessions\_shared"
    if (-not (Test-Path -LiteralPath $claudeShared)) { New-Item -ItemType Directory -Path $claudeShared -Force | Out-Null }
    Write-Status "  [OK] claude-sessions/_shared/" "Green"
}
if ($installOpenCode) {
    $ocShared = Join-Path $InstallDir "opencode-sessions\_shared"
    if (-not (Test-Path -LiteralPath $ocShared)) { New-Item -ItemType Directory -Path $ocShared -Force | Out-Null }
    Write-Status "  [OK] opencode-sessions/_shared/" "Green"
}

Write-Host ""
Write-Status "======================================================================" "Cyan"
Write-Status "СОЗДАНИЕ ЯРЛЫКОВ НА РАБОЧЕМ СТОЛЕ" "Magenta"
Write-Status "======================================================================" "Cyan"
Write-Host ""

$psExe = (Get-Command powershell.exe -ErrorAction SilentlyContinue).Source
if (-not $psExe) { $psExe = "powershell.exe" }
$scriptsDir = Join-Path $InstallDir "scripts"

try {
    $shortcutScript = Join-Path $scriptsDir "create-desktop-shortcuts.ps1"
    if (Test-Path -LiteralPath $shortcutScript) {
        $shortcutArgs = @("-RepoRoot", $InstallDir)
        & $psExe -NoProfile -ExecutionPolicy Bypass -File $shortcutScript @shortcutArgs 2>$null
    }
} catch { }

Write-Host ""
Write-Status "======================================================================" "Cyan"
Write-Status "УСТАНОВКА ЗАВЕРШЕНА!" "Green"
Write-Status "======================================================================" "Cyan"
Write-Host ""
Write-Status "Repository: $InstallDir" "Gray"
Write-Host ""
Write-Status "Ярлыки на рабочем столе:" "Cyan"
if ($installQwen)  { Write-Status "  * Qwen Code (cloud)" "Green" }
if ($installClaude) { Write-Status "  * Claude Code (cloud)" "Green" }
if ($installOpenCode) { Write-Status "  * OpenCode (cloud)" "Green" }
if ($installFreebuff) { Write-Status "  * Freebuff (cloud)" "Green" }
if ($installOpenClaude) { Write-Status "  * OpenClaude (cloud)" "Green" }
Write-Host ""
Write-Status "Перезапустите терминал, чтобы API ключи применились. Запускайте через ярлыки!" "Yellow"
Write-Host ""
Read-Host "Нажмите Enter для выхода"
