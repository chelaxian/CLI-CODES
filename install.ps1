# cloud-code-setup — Windows bootstrap (PowerShell)
# Запуск: irm https://raw.githubusercontent.com/chelaxian/cloud-code-setup/main/install.ps1 | iex
# Или: git clone + .\install.ps1

[CmdletBinding()]
param(
    [string]$RepoUrl = "https://github.com/chelaxian/cloud-code-setup.git",
    [string]$InstallDir = ""
)

$ErrorActionPreference = "Stop"

function Write-Status($Text, $Color = "White") {
    Write-Host $Text -ForegroundColor $Color
}

# ─── Определение путей ───────────────────────────────────────────────────────

if (-not $InstallDir) {
    $InstallDir = Join-Path $env:USERPROFILE "cloud-code-setup"
}

# ─── Заголовок ───────────────────────────────────────────────────────────────

Clear-Host
Write-Status "════════════════════════════════════════════════════════════════════════════════" "Cyan"
Write-Status "" "Cyan"
Write-Status "  ██████╗ ██╗    ██╗███████╗███╗   ██╗           +  CLI-CODE" "Cyan"
Write-Status " ██╔═══██╗██║    ██║██╔════╝████╗  ██║" "Cyan"
Write-Status " ██║   ██║██║ █╗ ██║█████╗  ██╔██╗ ██║            CLOUD SETUP" "Cyan"
Write-Status " ██║▄▄ ██║██║███╗██║██╔══╝  ██║╚██╗██║" "Cyan"
Write-Status " ╚██████╔╝╚███╔███╔╝███████╗██║ ╚████║           1-click install" "Cyan"
Write-Status "  ╚══▀▀═╝  ╚══╝╚══╝ ╚══════╝╚═╝  ╚═══╝" "Cyan"
Write-Status "" "Cyan"
Write-Status "  Qwen Code + Claude Code + OpenCode" "Yellow"
Write-Status "" "Cyan"
Write-Status "════════════════════════════════════════════════════════════════════════════════" "Cyan"
Write-Host ""

# ─── Проверка зависимостей ───────────────────────────────────────────────────

Write-Status "Проверка зависимостей…" "Cyan"

$missing = @()

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    $missing += "git (https://git-scm.com/download/win)"
}
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    $missing += "Node.js LTS (https://nodejs.org/)"
}
if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
    $missing += "npm (ставится вместе с Node.js)"
}

if ($missing.Count -gt 0) {
    Write-Status "Отсутствуют необходимые инструменты:" "Red"
    foreach ($m in $missing) {
        Write-Status "  - $m" "Yellow"
    }
    Write-Host ""
    Write-Status "Установите их и запустите инсталлятор заново." "Yellow"
    Write-Host ""
    Read-Host "Нажмите Enter для выхода"
    exit 1
}

Write-Status "  [OK] git" "Green"
Write-Status "  [OK] node" "Green"
Write-Status "  [OK] npm" "Green"
Write-Host ""

# ─── Клонирование репозитория ────────────────────────────────────────────────

if (Test-Path -LiteralPath (Join-Path $InstallDir ".git")) {
    Write-Status "Репозиторий уже клонирован: $InstallDir" "Yellow"
    Write-Status "Обновление (git pull)…" "Cyan"
    Push-Location $InstallDir
    try {
        git pull origin main 2>$null
        Write-Status "  [OK] Репозиторий обновлён" "Green"
    } catch {
        Write-Status "  [WARN] Не удалось обновить: $_" "Yellow"
    } finally {
        Pop-Location
    }
} else {
    Write-Status "Клонирование репозитория…" "Cyan"
    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    git clone $RepoUrl $InstallDir 2>$null
    $ErrorActionPreference = $prevEAP
    if ($LASTEXITCODE -ne 0) {
        Write-Status "Ошибка клонирования. Проверьте доступ к $RepoUrl" "Red"
        exit 1
    }
    Write-Status "  [OK] Репозиторий клонирован: $InstallDir" "Green"
}

Write-Host ""

# ─── Выбор инструментов ──────────────────────────────────────────────────────

Write-Status "════════════════════════════════════════════════════════════════════════════════" "Cyan"
Write-Status "ЧТО УСТАНОВИТЬ?" "Magenta"
Write-Status "════════════════════════════════════════════════════════════════════════════════" "Cyan"
Write-Host ""
Write-Status "  [1] Qwen Code (cloud)" "Green"
Write-Status "  [2] Claude Code (cloud)" "Green"
Write-Status "  [3] OpenCode (cloud)" "Green"
Write-Status "  [4] Все три" "Green"
Write-Status "  [0] Выход" "Gray"
Write-Host ""

$installChoice = Read-Host "Ваш выбор [4]"

if ([string]::IsNullOrWhiteSpace($installChoice)) { $installChoice = "4" }

$installQwen = $false
$installClaude = $false
$installOpenCode = $false

switch ($installChoice) {
    "1" { $installQwen = $true }
    "2" { $installClaude = $true }
    "3" { $installOpenCode = $true }
    "4" { $installQwen = $true; $installClaude = $true; $installOpenCode = $true }
    "0" { Write-Status "Выход." "Yellow"; exit 0 }
    default { Write-Status "Неверный выбор. Устанавливаем все три." "Yellow"; $installQwen = $true; $installClaude = $true; $installOpenCode = $true }
}

# ─── Установка CLI ───────────────────────────────────────────────────────────

Write-Host ""
Write-Status "════════════════════════════════════════════════════════════════════════════════" "Cyan"
Write-Status "УСТАНОВКА CLI" "Magenta"
Write-Status "════════════════════════════════════════════════════════════════════════════════" "Cyan"
Write-Host ""

if ($installQwen) {
    Write-Status "Установка Qwen Code CLI…" "Cyan"
    $qwenCmd = Get-Command qwen -ErrorAction SilentlyContinue
    if (-not $qwenCmd) {
        $prevEAP = $ErrorActionPreference; $ErrorActionPreference = "Continue"
        npm install -g @anthropic-ai/qwen-code@latest 2>$null
        if ($LASTEXITCODE -ne 0) {
            npm install -g @qwen-code/qwen-code@latest 2>$null
        }
        $ErrorActionPreference = $prevEAP
        $qwenCmd = Get-Command qwen -ErrorAction SilentlyContinue
    }
    if ($qwenCmd) {
        Write-Status "  [OK] Qwen Code CLI: $($qwenCmd.Source)" "Green"
    } else {
        Write-Status "  [WARN] Qwen Code CLI не установлен. Установите вручную: npm i -g @qwen-code/qwen-code" "Yellow"
    }
}

if ($installClaude) {
    Write-Status "Установка Claude Code CLI…" "Cyan"
    $claudeCmd = Get-Command claude -ErrorAction SilentlyContinue
    if (-not $claudeCmd) {
        $prevEAP = $ErrorActionPreference; $ErrorActionPreference = "Continue"
        npm install -g @anthropic-ai/claude-code@latest 2>$null
        $ErrorActionPreference = $prevEAP
        $claudeCmd = Get-Command claude -ErrorAction SilentlyContinue
    }
    if ($claudeCmd) {
        Write-Status "  [OK] Claude Code CLI: $($claudeCmd.Source)" "Green"
    } else {
        Write-Status "  [WARN] Claude Code CLI не установлен. Установите вручную: npm i -g @anthropic-ai/claude-code" "Yellow"
    }
}

if ($installOpenCode) {
    Write-Status "Установка OpenCode CLI…" "Cyan"
    $ocCmd = Get-Command opencode -ErrorAction SilentlyContinue
    if (-not $ocCmd) {
        $prevEAP = $ErrorActionPreference; $ErrorActionPreference = "Continue"
        npm install -g opencode-ai@latest 2>$null
        $ErrorActionPreference = $prevEAP
        $ocCmd = Get-Command opencode -ErrorAction SilentlyContinue
    }
    if ($ocCmd) {
        Write-Status "  [OK] OpenCode CLI: $($ocCmd.Source)" "Green"
    } else {
        Write-Status "  [WARN] OpenCode CLI не установлен. Установите вручную: npm i -g opencode-ai@latest" "Yellow"
    }
}

Write-Host ""

# ─── API ключи ───────────────────────────────────────────────────────────────

Write-Status "════════════════════════════════════════════════════════════════════════════════" "Cyan"
Write-Status "НАСТРОЙКА API КЛЮЧЕЙ" "Magenta"
Write-Status "════════════════════════════════════════════════════════════════════════════════" "Cyan"
Write-Host ""
Write-Status "Оставьте пустым, чтобы пропустить. Ключи можно изменить позже через меню лаунчера." "Yellow"
Write-Host ""

function Read-Secret($Prompt) {
    $sec = Read-Host -Prompt $Prompt -AsSecureString
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
    try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) } finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}

# NVIDIA NIM
$nimKey = Read-Secret "NVIDIA NIM API ключ (Enter = пропуск): "
if (-not [string]::IsNullOrWhiteSpace($nimKey)) {
    [Environment]::SetEnvironmentVariable("NVIDIA_NIM_API_KEY", $nimKey.Trim(), "User")
    Write-Status "  [OK] NVIDIA_NIM_API_KEY сохранён" "Green"
} else {
    Write-Status "  [SKIP] NVIDIA_NIM_API_KEY пропущен" "Yellow"
}

Write-Host ""

# Z.AI
$zaiKey = Read-Secret "Z.AI API ключ (Enter = пропуск): "
if (-not [string]::IsNullOrWhiteSpace($zaiKey)) {
    [Environment]::SetEnvironmentVariable("ZAI_API_KEY", $zaiKey.Trim(), "User")
    Write-Status "  [OK] ZAI_API_KEY сохранён" "Green"
} else {
    Write-Status "  [SKIP] ZAI_API_KEY пропущен" "Yellow"
}

Write-Host ""

# Groq
$groqKey = Read-Secret "Groq API ключ (Enter = пропуск): "
if (-not [string]::IsNullOrWhiteSpace($groqKey)) {
    [Environment]::SetEnvironmentVariable("GROQ_API_KEY", $groqKey.Trim(), "User")
    Write-Status "  [OK] GROQ_API_KEY сохранён" "Green"
} else {
    Write-Status "  [SKIP] GROQ_API_KEY пропущен" "Yellow"
}

Write-Host ""

# OpenRouter
$orKey = Read-Secret "OpenRouter API ключ (Enter = пропуск): "
if (-not [string]::IsNullOrWhiteSpace($orKey)) {
    [Environment]::SetEnvironmentVariable("OPENROUTER_API_KEY", $orKey.Trim(), "User")
    Write-Status "  [OK] OPENROUTER_API_KEY сохранён" "Green"
} else {
    Write-Status "  [SKIP] OPENROUTER_API_KEY пропущен" "Yellow"
}

Write-Host ""

# ─── Настройка сессий Qwen ───────────────────────────────────────────────────

if ($installQwen) {
    Write-Status "════════════════════════════════════════════════════════════════════════════════" "Cyan"
    Write-Status "НАСТРОЙКА СЕССИЙ QWEN CODE" "Magenta"
    Write-Status "════════════════════════════════════════════════════════════════════════════════" "Cyan"
    Write-Host ""

    # Единое пространство для /resume (все модели в одной директории)
    $sharedDir = Join-Path $InstallDir "qwen-sessions\_shared\.qwen"
    if (-not (Test-Path -LiteralPath $sharedDir)) {
        New-Item -ItemType Directory -Path $sharedDir -Force | Out-Null
    }
    Write-Status "  [OK] qwen-sessions/_shared/ — единое пространство /resume" "Green"

    Write-Host ""
}

# ─── Создание ярлыков ────────────────────────────────────────────────────────

Write-Status "════════════════════════════════════════════════════════════════════════════════" "Cyan"
Write-Status "СОЗДАНИЕ ЯРЛЫКОВ НА РАБОЧЕМ СТОЛЕ" "Magenta"
Write-Status "════════════════════════════════════════════════════════════════════════════════" "Cyan"
Write-Host ""

$desktop = [Environment]::GetFolderPath("Desktop")
$psExe = (Get-Command powershell.exe -ErrorAction SilentlyContinue).Source
if (-not $psExe) { $psExe = "powershell.exe" }
$shell = New-Object -ComObject WScript.Shell
$scriptsDir = Join-Path $InstallDir "scripts"

if ($installQwen) {
    $launcher = Join-Path $scriptsDir "run-qwen-code-launcher.ps1"
    if (Test-Path -LiteralPath $launcher) {
        $lnk = $shell.CreateShortcut((Join-Path $desktop "Qwen Code (cloud).lnk"))
        $lnk.TargetPath = $psExe
        $lnk.Arguments = "/k chcp 65001 >nul & powershell -NoProfile -ExecutionPolicy Bypass -File `"$launcher`""
        $lnk.WorkingDirectory = $InstallDir
        $lnk.Save()
        Write-Status "  [OK] Qwen Code (cloud).lnk" "Green"
    }
}

if ($installClaude) {
    $launcher = Join-Path $scriptsDir "run-claude-cloud-launcher.ps1"
    if (Test-Path -LiteralPath $launcher) {
        $lnk = $shell.CreateShortcut((Join-Path $desktop "Claude Code (cloud).lnk"))
        $lnk.TargetPath = $psExe
        $lnk.Arguments = "/k chcp 65001 >nul & powershell -NoProfile -ExecutionPolicy Bypass -File `"$launcher`""
        $lnk.WorkingDirectory = $InstallDir
        $lnk.Save()
        Write-Status "  [OK] Claude Code (cloud).lnk" "Green"
    }
}

if ($installOpenCode) {
    $launcher = Join-Path $scriptsDir "run-opencode-launcher.ps1"
    if (Test-Path -LiteralPath $launcher) {
        $lnk = $shell.CreateShortcut((Join-Path $desktop "OpenCode (cloud).lnk"))
        $lnk.TargetPath = $psExe
        $lnk.Arguments = "/k chcp 65001 >nul & powershell -NoProfile -ExecutionPolicy Bypass -File `"$launcher`""
        $lnk.WorkingDirectory = $InstallDir
        $lnk.Save()
        Write-Status "  [OK] OpenCode (cloud).lnk" "Green"
    }
}

Write-Host ""

# ─── Итоги ───────────────────────────────────────────────────────────────────

Write-Status "════════════════════════════════════════════════════════════════════════════════" "Cyan"
Write-Status "УСТАНОВКА ЗАВЕРШЕНА!" "Green"
Write-Status "════════════════════════════════════════════════════════════════════════════════" "Cyan"
Write-Host ""
Write-Status "Репозиторий: $InstallDir" "Gray"
Write-Host ""
Write-Status "Ярлыки на рабочем столе:" "Cyan"
if ($installQwen)  { Write-Status "  * Qwen Code (cloud)" "Green" }
if ($installClaude) { Write-Status "  * Claude Code (cloud)" "Green" }
if ($installOpenCode) { Write-Status "  * OpenCode (cloud)" "Green" }
Write-Host ""
Write-Status "ПРИМЕЧАНИЯ:" "Yellow"
Write-Status "  - Перезапустите терминал, чтобы переменные окружения вступили в силу" "Gray"
Write-Status "  - В меню лаунчеров есть пункт 'Сменить ключ API провайдера'" "Gray"
Write-Status "  - Все сессии Qwen Code хранятся в едином пространстве (/resume)" "Gray"
Write-Status "  - Для NIM пресетов (Qwen) нужен LiteLLM — см. docs/" "Gray"
Write-Host ""
Read-Host "Нажмите Enter для выхода"
