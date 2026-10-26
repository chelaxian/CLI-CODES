# CLI-CODES - 1-click Windows installer (bootstrap)
# Usage (PowerShell 5.1+):
#   irm https://raw.githubusercontent.com/chelaxian/CLI-CODES/main/install.ps1 | iex
# If `irm` fails with "Базовое соединение закрыто", use the curl.exe fallback:
#   curl.exe -fsSL https://raw.githubusercontent.com/chelaxian/CLI-CODES/main/install.ps1 | powershell.exe -NoProfile -ExecutionPolicy Bypass -Command -
#
# Этот файл всегда скачивается свежим (irm | iex), поэтому именно он отвечает за то, чтобы
# локальная копия репозитория была актуальной ДО запуска install-full.ps1 из неё.
# NB: файл без BOM - irm | iex не умеет его отбрасывать.

try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.ServicePointManager]::SecurityProtocol } catch {}

$repoUrl = "https://github.com/chelaxian/CLI-CODES.git"
$rawUrl  = "https://raw.githubusercontent.com/chelaxian/CLI-CODES/main/install-full.ps1?t=$([DateTime]::UtcNow.Ticks)"

$localRepo = if ($env:CLI_CODES_DIR) { $env:CLI_CODES_DIR }
             elseif ($PSScriptRoot -and (Test-Path -LiteralPath (Join-Path $PSScriptRoot "install-full.ps1"))) { $PSScriptRoot }
             else { Join-Path $env:USERPROFILE "CLI-CODES" }
$localInstallFull = Join-Path $localRepo "install-full.ps1"

$psExe = if (Get-Command pwsh.exe -ErrorAction SilentlyContinue) { (Get-Command pwsh.exe).Source } else { "powershell.exe" }

# Приводит локальную копию к origin/main. Старые версии инсталлятора сами меняли файлы
# (дописывали BOM), из-за чего `git pull` отказывался обновлять и запускалась устаревшая
# версия. Поэтому: локальные правки откладываем в git stash (их можно вернуть) и делаем
# reset --hard. Возвращает $true, если копия актуальна.
function Update-LocalRepo([string]$Dir) {
    if (-not (Test-Path -LiteralPath (Join-Path $Dir ".git"))) { return $false }
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { return $false }
    $env:GIT_TERMINAL_PROMPT = "0"; $env:GCM_INTERACTIVE = "Never"
    $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    try {
        & git -C $Dir fetch -q origin main 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { Write-Host "  [WARN] git fetch не удался" -ForegroundColor Yellow; return $false }
        $dirty = (& git -C $Dir status --porcelain --untracked-files=no 2>$null)
        if ($dirty) {
            $stamp = Get-Date -Format "yyyy-MM-dd HH:mm"
            & git -C $Dir stash push -q -m "cli-codes autostash $stamp" 2>&1 | Out-Null
            Write-Host "  [INFO] Локальные изменения отложены: git -C `"$Dir`" stash list" -ForegroundColor DarkGray
        }
        & git -C $Dir reset -q --hard origin/main 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { return $false }
        $head = (& git -C $Dir rev-parse --short HEAD 2>$null)
        Write-Host "  [OK] Репозиторий актуален ($head)" -ForegroundColor Green
        return $true
    } finally { $ErrorActionPreference = $prev }
}

Write-Host ""
Write-Host "  CLI-CODES :: 1-click installer" -ForegroundColor Cyan

if (Test-Path -LiteralPath $localInstallFull) {
    if (Update-LocalRepo $localRepo) {
        & $psExe -NoProfile -ExecutionPolicy Bypass -File $localInstallFull -InstallDir $localRepo
        exit $LASTEXITCODE
    }
    Write-Host "  [WARN] Не удалось обновить $localRepo - запускаю актуальный инсталлятор с GitHub" -ForegroundColor Yellow
}

# Нет локальной копии (или её не удалось обновить) → берём свежий install-full.ps1 с GitHub.
# Он сам склонирует/обновит репозиторий и перезапустится из него.
$tmpFile = Join-Path $env:TEMP "CLI-CODES-install-full.ps1"
$downloaded = $false
try {
    Invoke-WebRequest -Uri $rawUrl -OutFile $tmpFile -UseBasicParsing
    $downloaded = $true
} catch {
    Write-Host "  [WARN] Invoke-WebRequest: $($_.Exception.Message) - пробую curl.exe" -ForegroundColor Yellow
}
# Резерв: curl.exe есть в Windows 10 1803+ и не зависит от настроек TLS/прокси .NET Framework
if (-not $downloaded -and (Get-Command curl.exe -ErrorAction SilentlyContinue)) {
    & curl.exe -fsSL --retry 2 -o $tmpFile $rawUrl
    $downloaded = ($LASTEXITCODE -eq 0)
}
if (-not $downloaded) {
    Write-Host "  ERROR: не удалось скачать install-full.ps1" -ForegroundColor Red
    Write-Host "  Вручную: git clone $repoUrl `"$localRepo`"; затем запустите install.ps1 из этой папки" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    return
}
& $psExe -NoProfile -ExecutionPolicy Bypass -File $tmpFile -InstallDir $localRepo -RepoUrl $repoUrl
$exitCode = $LASTEXITCODE
Remove-Item -LiteralPath $tmpFile -Force -ErrorAction SilentlyContinue
exit $exitCode
