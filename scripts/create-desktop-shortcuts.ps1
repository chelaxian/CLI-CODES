# Создаёт ярлыки на рабочем столе для всех УСТАНОВЛЕННЫХ агентов из TXT/agents.txt
# и команду `cli-codes` (CLI-CODES\bin\cli-codes.cmd, добавляется в пользовательский PATH).
#
# Каждый ярлык открывает универсальный лаунчер: run-agent.ps1 <agent-key>.
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\create-desktop-shortcuts.ps1 [-RepoRoot <dir>] [-DesktopPath <dir>]

[CmdletBinding()]
param(
  [string]$RepoRoot = "",
  [string]$DesktopPath = ""
)

$ErrorActionPreference = "Continue"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) { $RepoRoot = Split-Path -Parent $PSScriptRoot }
. (Join-Path $RepoRoot "scripts\lib\clicodes.ps1")
Update-CcPath

# Рабочий стол реального пользователя (а не администратора, если инсталлятор запущен «от имени администратора»)
if ([string]::IsNullOrWhiteSpace($DesktopPath)) {
  try {
    $explorer = Get-Process -Name explorer -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($explorer) {
      $wmi = Get-CimInstance Win32_Process -Filter "ProcessId='$($explorer.Id)'" -ErrorAction SilentlyContinue
      $owner = if ($wmi) { $wmi | Invoke-CimMethod -MethodName GetOwner -ErrorAction SilentlyContinue }
      if ($owner -and $owner.User) {
        $sid = (New-Object System.Security.Principal.NTAccount($owner.Domain, $owner.User)).Translate([System.Security.Principal.SecurityIdentifier]).Value
        $profilePath = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$sid" -ErrorAction SilentlyContinue).ProfileImagePath
        if ($profilePath) { $DesktopPath = Join-Path $profilePath "Desktop" }
      }
    }
  } catch {}
  if (-not $DesktopPath -or -not (Test-Path -LiteralPath $DesktopPath)) { $DesktopPath = [Environment]::GetFolderPath("Desktop") }
}

$launcher = Join-Path $RepoRoot "scripts\run-agent.ps1"
$cmdExe = Join-Path $env:SystemRoot "System32\cmd.exe"
$pwsh = Get-Command pwsh.exe -ErrorAction SilentlyContinue
$psExe = if ($pwsh) { $pwsh.Source } else { (Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe") }

# ── Команда cli-codes ──
$binDir = Join-Path $RepoRoot "bin"
if (-not (Test-Path -LiteralPath $binDir)) { New-Item -ItemType Directory -Path $binDir -Force | Out-Null }
$cmdText = "@echo off`r`nchcp 65001 >nul 2>&1`r`nset `"PS=powershell`"`r`nwhere pwsh >nul 2>&1 && set `"PS=pwsh`"`r`n%PS% -NoProfile -ExecutionPolicy Bypass -File `"$launcher`" %*`r`n"
[System.IO.File]::WriteAllText((Join-Path $binDir "cli-codes.cmd"), $cmdText, (New-Object System.Text.UTF8Encoding($false)))
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if (($userPath -split ';') -notcontains $binDir) {
  [Environment]::SetEnvironmentVariable("Path", (($userPath.TrimEnd(';') + ";" + $binDir).TrimStart(';')), "User")
  Write-Host "[shortcuts] cli-codes добавлен в PATH (откройте новый терминал)" -ForegroundColor Green
}

if (-not (Test-Path -LiteralPath $DesktopPath)) {
  Write-Host "[shortcuts] Рабочий стол не найден: $DesktopPath" -ForegroundColor Yellow
  return
}

# Старые версии хранили технические .cmd/.lnk в скрытой папке «Cloud Launchers» — больше не нужна
$legacyFolder = Join-Path $DesktopPath "Cloud Launchers"
if (Test-Path -LiteralPath $legacyFolder) { Remove-Item -LiteralPath $legacyFolder -Recurse -Force -ErrorAction SilentlyContinue }

try { $ws = New-Object -ComObject WScript.Shell } catch {
  Write-Host "[shortcuts] WScript.Shell недоступен: $($_.Exception.Message)" -ForegroundColor Red
  return
}

$okCount = 0
foreach ($a in $script:CcAgents) {
  if (-not (Test-CcAgentInstalled $a)) { continue }
  try {
    $lnkPath = Join-Path $DesktopPath ($a.Name + ".lnk")
    if (Test-Path -LiteralPath $lnkPath) { (Get-Item -LiteralPath $lnkPath -Force).Attributes = [System.IO.FileAttributes]::Normal }
    $s = $ws.CreateShortcut($lnkPath)
    $s.TargetPath = $cmdExe
    $s.Arguments = "/c chcp 65001 >nul & `"$psExe`" -NoProfile -ExecutionPolicy Bypass -File `"$launcher`" $($a.Key)"
    $s.WorkingDirectory = $env:USERPROFILE
    $s.Description = $a.Desc
    $exe = Resolve-CcCommand $a.Cmd
    if ($exe -and $exe.EndsWith(".exe")) { $s.IconLocation = "$exe,0" } else { $s.IconLocation = "$psExe,0" }
    $s.WindowStyle = 1
    $s.Save()
    $okCount++
    Write-Host "[shortcuts] OK: $($a.Name)" -ForegroundColor Green
  } catch {
    Write-Host "[shortcuts] ERROR $($a.Name): $($_.Exception.Message)" -ForegroundColor Red
  }
}
Write-Host "[shortcuts] Ярлыков: $okCount" -ForegroundColor Cyan
