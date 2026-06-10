# Creates desktop shortcuts: hidden "Cloud Launchers" folder with technical files,
# and exactly 5 visible shortcuts on desktop (Qwen Code, Claude Code, OpenCode, Freebuff, OpenClaude).
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\create-desktop-shortcuts.ps1 -RepoRoot "D:\qwen-local-setup"

[CmdletBinding()]
param(
  [string]$RepoRoot = "",
  [string]$DesktopPath = ""
)

$ErrorActionPreference = "Continue"

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
  $RepoRoot = Split-Path -Parent $PSScriptRoot
}

Write-Host "[create-desktop-shortcuts] RepoRoot = $RepoRoot" -ForegroundColor DarkGray

if ([string]::IsNullOrWhiteSpace($DesktopPath)) {
  try {
    $explorer = Get-Process -Name explorer -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -ne $explorer) {
      $wmiProc = Get-CimInstance Win32_Process -Filter "ProcessId='$($explorer.Id)'" -ErrorAction SilentlyContinue
      if ($null -eq $wmiProc) {
        $wmiProc = Get-WmiObject Win32_Process -Filter "ProcessId='$($explorer.Id)'" -ErrorAction SilentlyContinue
      }
      if ($wmiProc) {
        $owner = $wmiProc | Invoke-CimMethod -MethodName GetOwner -ErrorAction SilentlyContinue
        if ($null -eq $owner) { $owner = $wmiProc.GetOwner() }
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

Write-Host "[create-desktop-shortcuts] DesktopPath = $DesktopPath" -ForegroundColor DarkGray

if (-not (Test-Path -LiteralPath $DesktopPath)) {
  Write-Host "[create-desktop-shortcuts] ERROR: Desktop path does not exist: $DesktopPath" -ForegroundColor Red
  return
}

$scriptsDir = Join-Path $RepoRoot "scripts"
if (-not (Test-Path -LiteralPath $scriptsDir)) {
  Write-Host "[create-desktop-shortcuts] ERROR: scripts dir not found: $scriptsDir" -ForegroundColor Red
  return
}

$cmdExe = try { (Get-Command cmd.exe -ErrorAction Stop).Source } catch { "$env:SystemRoot\System32\cmd.exe" }
$psExe  = try {
  $p = Get-Command pwsh.exe -ErrorAction SilentlyContinue
  if ($p) { $p.Source } else { (Get-Command powershell.exe -ErrorAction Stop).Source }
} catch { "powershell.exe" }

Write-Host "[create-desktop-shortcuts] cmdExe = $cmdExe" -ForegroundColor DarkGray
Write-Host "[create-desktop-shortcuts] psExe  = $psExe" -ForegroundColor DarkGray

$ws = $null
try {
  $ws = New-Object -ComObject WScript.Shell
} catch {
  Write-Host "[create-desktop-shortcuts] ERROR: Cannot create WScript.Shell COM object: $($_.Exception.Message)" -ForegroundColor Red
  return
}

$cloudFolder = Join-Path $DesktopPath "Cloud Launchers"
if (-not (Test-Path -LiteralPath $cloudFolder)) {
  New-Item -ItemType Directory -Path $cloudFolder -Force | Out-Null
}
try {
  $folderItem = Get-Item -LiteralPath $cloudFolder -Force
  $folderItem.Attributes = $folderItem.Attributes -bor [System.IO.FileAttributes]::Hidden
} catch {}

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

try {
  Get-ChildItem -LiteralPath $cloudFolder -Filter "*.cmd" -ErrorAction SilentlyContinue | ForEach-Object {
    $_.Attributes = $_.Attributes -bor [System.IO.FileAttributes]::Hidden
  }
  Get-ChildItem -LiteralPath $cloudFolder -Filter "*.lnk" -ErrorAction SilentlyContinue | ForEach-Object {
    $_.Attributes = $_.Attributes -bor [System.IO.FileAttributes]::Hidden
  }
} catch {}

$launchers = @(
  @{ Name = "Qwen Code (cloud)";   ScriptFile = "run-qwen-code-launcher.ps1" },
  @{ Name = "Claude Code (cloud)"; ScriptFile = "run-claude-cloud-launcher.ps1" },
  @{ Name = "OpenCode (cloud)";    ScriptFile = "run-opencode-launcher.ps1" },
  @{ Name = "Freebuff (cloud)";    ScriptFile = "run-freebuff-launcher.ps1" },
  @{ Name = "OpenClaude (cloud)";  ScriptFile = "run-openclaude-launcher.ps1" }
)

foreach ($entry in $launchers) {
  try {
    $launcher = Join-Path $scriptsDir $entry.ScriptFile
    if (-not (Test-Path -LiteralPath $launcher)) {
      Write-Host "[create-desktop-shortcuts] SKIP $($entry.Name): $($entry.ScriptFile) not found" -ForegroundColor Yellow
      continue
    }

    $cmdPath = Join-Path $cloudFolder "$($entry.Name).cmd"
    $cmdContent = "@echo off`r`nchcp 65001 >nul 2>`&1`r`nset `"PS=powershell`"`r`nwhere pwsh >nul 2>`&1 && set `"PS=pwsh`"`r`n%PS% -NoProfile -ExecutionPolicy Bypass -Command `"& '$launcher'`"`r`nif %ERRORLEVEL% neq 0 pause"
    [System.IO.File]::WriteAllText($cmdPath, $cmdContent, (New-Object System.Text.UTF8Encoding($false)))

    $lnkPath = Join-Path $cloudFolder "$($entry.Name).lnk"
    $s = $ws.CreateShortcut($lnkPath)
    $s.TargetPath = $cmdExe
    $s.Arguments = "/k chcp 65001 >nul & `"$psExe`" -NoProfile -ExecutionPolicy Bypass -File `"$launcher`""
    $s.WorkingDirectory = $RepoRoot
    $s.WindowStyle = 1
    $s.Save()

    Write-Host "[create-desktop-shortcuts] OK: $($entry.Name) (.cmd + .lnk in Cloud Launchers)" -ForegroundColor Green
  } catch {
    Write-Host "[create-desktop-shortcuts] ERROR creating $($entry.Name): $($_.Exception.Message)" -ForegroundColor Red
  }
}

$visibleLinks = @(
  @{ Name = "Qwen Code";   CmdName = "Qwen Code (cloud).cmd" },
  @{ Name = "Claude Code"; CmdName = "Claude Code (cloud).cmd" },
  @{ Name = "OpenCode";    CmdName = "OpenCode (cloud).cmd" },
  @{ Name = "Freebuff";    CmdName = "Freebuff (cloud).cmd" },
  @{ Name = "OpenClaude";  CmdName = "OpenClaude (cloud).cmd" }
)

$createdCount = 0
foreach ($link in $visibleLinks) {
  try {
    $cmdTarget = Join-Path $cloudFolder $link.CmdName
    if (-not (Test-Path -LiteralPath $cmdTarget)) {
      Write-Host "[create-desktop-shortcuts] SKIP desktop shortcut $($link.Name): $($link.CmdName) not found" -ForegroundColor Yellow
      continue
    }

    $linkPath = Join-Path $DesktopPath "$($link.Name).lnk"
    $s = $ws.CreateShortcut($linkPath)
    $s.TargetPath = $cmdTarget
    $s.WorkingDirectory = $RepoRoot
    $s.WindowStyle = 1
    $s.Save()

    $item = Get-Item -LiteralPath $linkPath -Force
    $item.Attributes = $item.Attributes -band (-bnot [System.IO.FileAttributes]::Hidden)

    $createdCount++
    Write-Host "[create-desktop-shortcuts] DESKTOP: $($link.Name).lnk" -ForegroundColor Green
  } catch {
    Write-Host "[create-desktop-shortcuts] ERROR creating desktop shortcut $($link.Name): $($_.Exception.Message)" -ForegroundColor Red
  }
}

Write-Host ""
Write-Host "[create-desktop-shortcuts] Desktop shortcuts created: $createdCount / $($visibleLinks.Count)" -ForegroundColor $(if ($createdCount -gt 0) { "Green" } else { "Red" })
Write-Host "[create-desktop-shortcuts] Cloud folder: $cloudFolder" -ForegroundColor DarkGray
