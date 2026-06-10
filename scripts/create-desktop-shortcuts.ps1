# Создаёт ярлыки на рабочем столе: скрытая папка "Cloud Launchers" с техническими файлами,
# и ровно 5 видимых ярлыков на рабочем столе (Qwen Code, Claude Code, OpenCode, Freebuff, OpenClaude).
# При повторном запуске перемещает старые файлы проекта из корня рабочего стола в скрытую папку.
# Запуск: powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\create-desktop-shortcuts.ps1 -RepoRoot "D:\qwen-local-setup"

[CmdletBinding()]
param(
  [string]$RepoRoot = "",
  [string]$DesktopPath = ""
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
  $RepoRoot = Split-Path -Parent $PSScriptRoot
}
if ([string]::IsNullOrWhiteSpace($DesktopPath)) {
  try {
    $explorer = Get-Process -Name explorer -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -ne $explorer) {
      $wmiProc = Get-WmiObject Win32_Process -Filter "ProcessId='$($explorer.Id)'" -ErrorAction SilentlyContinue
      if ($wmiProc) {
        $owner = $wmiProc.GetOwner()
        if ($owner -and $owner.User -and $owner.Domain) {
          $acct = New-Object System.Security.Principal.NTAccount($owner.Domain, $owner.User)
          $sid = $acct.Translate([System.Security.Principal.SecurityIdentifier]).Value
          $profilePath = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$sid" -ErrorAction SilentlyContinue).ProfileImagePath
          if ($profilePath) { $DesktopPath = Join-Path $profilePath "Desktop" }
        }
      }
    }
  } catch {}
  if (-not $DesktopPath -or -not (Test-Path -LiteralPath $DesktopPath)) {
    $DesktopPath = [Environment]::GetFolderPath("Desktop")
  }
  if (-not $DesktopPath -or -not (Test-Path -LiteralPath $DesktopPath)) {
    $DesktopPath = Join-Path $env:USERPROFILE "Desktop"
  }
}

$cmdExe = (Get-Command cmd.exe -ErrorAction Stop).Source
$psExe  = if (Get-Command pwsh.exe -ErrorAction SilentlyContinue) { (Get-Command pwsh.exe -ErrorAction SilentlyContinue).Source } else { (Get-Command powershell.exe -ErrorAction Stop).Source }
$ws = New-Object -ComObject WScript.Shell

$launcherClaude = Join-Path $RepoRoot "scripts\run-claude-cloud-launcher.ps1"
$launcherQwen = Join-Path $RepoRoot "scripts\run-qwen-code-launcher.ps1"
$launcherOpenCode = Join-Path $RepoRoot "scripts\run-opencode-launcher.ps1"
$launcherFreebuff = Join-Path $RepoRoot "scripts\run-freebuff-launcher.ps1"
$launcherOpenClaude = Join-Path $RepoRoot "scripts\run-openclaude-launcher.ps1"

foreach ($p in @($launcherClaude, $launcherQwen, $launcherOpenCode, $launcherFreebuff, $launcherOpenClaude)) {
  if (-not (Test-Path -LiteralPath $p)) { throw "Не найден файл: $p" }
}

$cloudFolder = Join-Path $DesktopPath "Cloud Launchers"
if (-not (Test-Path -LiteralPath $cloudFolder)) {
  New-Item -ItemType Directory -Path $cloudFolder -Force | Out-Null
}
$folderItem = Get-Item -LiteralPath $cloudFolder
$folderItem.Attributes = $folderItem.Attributes -bor [System.IO.FileAttributes]::Hidden

# Migrate ALL old cloud-related files from desktop root to hidden folder
$cloudBaseNames = @("Qwen Code (cloud)", "Claude Code (cloud)", "OpenCode (cloud)", "Freebuff (cloud)", "OpenClaude (cloud)")
foreach ($baseName in $cloudBaseNames) {
  foreach ($ext in @(".cmd", ".lnk")) {
    $oldPath = Join-Path $DesktopPath "$baseName$ext"
    $newPath = Join-Path $cloudFolder "$baseName$ext"
    if ((Test-Path -LiteralPath $oldPath) -and -not (Test-Path -LiteralPath $newPath)) {
      Move-Item -LiteralPath $oldPath -Destination $newPath -Force -ErrorAction SilentlyContinue
    }
  }
}

# Also move any other project-related .cmd/.ps1 files from desktop
Get-ChildItem -LiteralPath $DesktopPath -Filter "*.cmd" | Where-Object { $_.Name -notlike "Qwen Code*" -and $_.Name -notlike "Claude Code*" -and $_.Name -notlike "OpenCode*" -and $_.Name -notlike "Freebuff*" -and $_.Name -notlike "OpenClaude*" } | ForEach-Object {
  $dest = Join-Path $cloudFolder $_.Name
  if (-not (Test-Path -LiteralPath $dest)) {
    Move-Item -LiteralPath $_.FullName -Destination $dest -Force -ErrorAction SilentlyContinue
  }
}

# Hide ALL internal files in Cloud Launchers (folder itself is already hidden)
Get-ChildItem -LiteralPath $cloudFolder -Filter "*.cmd" | ForEach-Object {
  $_.Attributes = $_.Attributes -bor [System.IO.FileAttributes]::Hidden
}
Get-ChildItem -LiteralPath $cloudFolder -Filter "*.lnk" | ForEach-Object {
  $_.Attributes = $_.Attributes -bor [System.IO.FileAttributes]::Hidden
}

function New-LauncherShortcut {
  param(
    [string]$Name,
    [string]$ScriptFile
  )
  $launcher = Join-Path $RepoRoot "scripts" $ScriptFile
  if (-not (Test-Path -LiteralPath $launcher)) { return }

  $cmdPath = Join-Path $cloudFolder "$Name.cmd"
  $cmdContent = "@echo off`r`nchcp 65001 >nul 2>`&1`r`nset `"PS=powershell`"`r`nwhere pwsh >nul 2>`&1 && set `"PS=pwsh`"`r`n%PS% -NoProfile -ExecutionPolicy Bypass -Command `"& '$launcher'`"`r`nif %ERRORLEVEL% neq 0 pause"
  [System.IO.File]::WriteAllText($cmdPath, $cmdContent, (New-Object System.Text.UTF8Encoding($false)))

  $lnkPath = Join-Path $cloudFolder "$Name.lnk"
  $s = $ws.CreateShortcut($lnkPath)
  $s.TargetPath = $cmdExe
  $s.Arguments = "/k chcp 65001 >nul & `"$psExe`" -NoProfile -ExecutionPolicy Bypass -File `"$launcher`""
  $s.WorkingDirectory = $RepoRoot
  $s.WindowStyle = 1
  $s.Save()
  $item = Get-Item -LiteralPath $lnkPath
  $item.Attributes = $item.Attributes -band (-bnot [System.IO.FileAttributes]::Hidden)
}

New-LauncherShortcut -Name "Qwen Code (cloud)" -ScriptFile "run-qwen-code-launcher.ps1"
New-LauncherShortcut -Name "Claude Code (cloud)" -ScriptFile "run-claude-cloud-launcher.ps1"
New-LauncherShortcut -Name "OpenCode (cloud)" -ScriptFile "run-opencode-launcher.ps1"
New-LauncherShortcut -Name "Freebuff (cloud)" -ScriptFile "run-freebuff-launcher.ps1"
New-LauncherShortcut -Name "OpenClaude (cloud)" -ScriptFile "run-openclaude-launcher.ps1"

# Create exactly 5 visible .lnk shortcuts on desktop
$visibleLinks = @(
  @{ Name = "Qwen Code";   Target = (Join-Path $cloudFolder "Qwen Code (cloud).cmd") },
  @{ Name = "Claude Code"; Target = (Join-Path $cloudFolder "Claude Code (cloud).cmd") },
  @{ Name = "OpenCode";    Target = (Join-Path $cloudFolder "OpenCode (cloud).cmd") },
  @{ Name = "Freebuff";    Target = (Join-Path $cloudFolder "Freebuff (cloud).cmd") },
  @{ Name = "OpenClaude";  Target = (Join-Path $cloudFolder "OpenClaude (cloud).cmd") }
)

foreach ($link in $visibleLinks) {
  $linkPath = Join-Path $DesktopPath "$($link.Name).lnk"
  $s = $ws.CreateShortcut($linkPath)
  $s.TargetPath = $link.Target
  $s.WorkingDirectory = $RepoRoot
  $s.WindowStyle = 1
  $s.Save()
  $item = Get-Item -LiteralPath $linkPath
  $item.Attributes = $item.Attributes -band (-bnot [System.IO.FileAttributes]::Hidden)
}

Write-Host ("Shortcuts created: " + ("Qwen Code, Claude Code, OpenCode, Freebuff, OpenClaude" -join ", ")) -ForegroundColor Green
Write-Host ("Cloud folder: " + $cloudFolder) -ForegroundColor DarkGray
