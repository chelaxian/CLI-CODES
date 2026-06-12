# Creates desktop shortcuts: hidden "Cloud Launchers" folder with technical files,
# and visible shortcuts on desktop (Qwen Code, Claude Code, OpenCode, Freebuff, OpenClaude, MiMo Code).
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

Write-Host "[shortcuts] RepoRoot = $RepoRoot" -ForegroundColor DarkGray

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

Write-Host "[shortcuts] DesktopPath = $DesktopPath" -ForegroundColor DarkGray

if (-not (Test-Path -LiteralPath $DesktopPath)) {
  Write-Host "[shortcuts] ERROR: Desktop not found: $DesktopPath" -ForegroundColor Red
  return
}

$scriptsDir = Join-Path $RepoRoot "scripts"
if (-not (Test-Path -LiteralPath $scriptsDir)) {
  Write-Host "[shortcuts] ERROR: scripts dir not found: $scriptsDir" -ForegroundColor Red
  return
}

$cmdExe = try { (Get-Command cmd.exe -ErrorAction Stop).Source } catch { "$env:SystemRoot\System32\cmd.exe" }
$psExe  = try {
  $p = Get-Command pwsh.exe -ErrorAction SilentlyContinue
  if ($p) { $p.Source } else { (Get-Command powershell.exe -ErrorAction Stop).Source }
} catch { "powershell.exe" }

Write-Host "[shortcuts] cmdExe = $cmdExe, psExe = $psExe" -ForegroundColor DarkGray

try { $ws = New-Object -ComObject WScript.Shell } catch {
  Write-Host "[shortcuts] ERROR: WScript.Shell COM failed: $($_.Exception.Message)" -ForegroundColor Red
  return
}

$cloudFolder = Join-Path $DesktopPath "Cloud Launchers"
if (-not (Test-Path -LiteralPath $cloudFolder)) {
  New-Item -ItemType Directory -Path $cloudFolder -Force | Out-Null
}

try {
  $fi = Get-Item -LiteralPath $cloudFolder -Force
  $fi.Attributes = $fi.Attributes -bor [System.IO.FileAttributes]::Hidden
} catch {}

$cloudBaseNames = @("Qwen Code (cloud)", "Claude Code (cloud)", "OpenCode (cloud)", "Freebuff (cloud)", "OpenClaude (cloud)", "MiMo Code (cloud)")
foreach ($baseName in $cloudBaseNames) {
  foreach ($ext in @(".cmd", ".lnk")) {
    $oldPath = Join-Path $DesktopPath "$baseName$ext"
    $newPath = Join-Path $cloudFolder "$baseName$ext"
    if ((Test-Path -LiteralPath $oldPath) -and -not (Test-Path -LiteralPath $newPath)) {
      Move-Item -LiteralPath $oldPath -Destination $newPath -Force -ErrorAction SilentlyContinue
    }
  }
}

function Unlock-File($Path) {
  try {
    if (Test-Path -LiteralPath $Path) {
      $item = Get-Item -LiteralPath $Path -Force
      $item.Attributes = [System.IO.FileAttributes]::Normal
    }
  } catch {}
}

$launchers = @(
  @{ Name = "Qwen Code (cloud)";   Script = "run-qwen-code-launcher.ps1";       DeskName = "Qwen Code" },
  @{ Name = "Claude Code (cloud)"; Script = "run-claude-cloud-launcher.ps1";    DeskName = "Claude Code" },
  @{ Name = "OpenCode (cloud)";    Script = "run-opencode-launcher.ps1";        DeskName = "OpenCode" },
  @{ Name = "Freebuff (cloud)";    Script = "run-freebuff-launcher.ps1";        DeskName = "Freebuff" },
  @{ Name = "OpenClaude (cloud)";  Script = "run-openclaude-launcher.ps1";      DeskName = "OpenClaude" },
  @{ Name = "MiMo Code (cloud)";   Script = "run-mimo-launcher.ps1";            DeskName = "MiMo Code" }
)

$okCount = 0
foreach ($entry in $launchers) {
  try {
    $launcher = Join-Path $scriptsDir $entry.Script
    if (-not (Test-Path -LiteralPath $launcher)) {
      Write-Host "[shortcuts] SKIP $($entry.Name): $($entry.Script) not found" -ForegroundColor Yellow
      continue
    }

    $cmdPath = Join-Path $cloudFolder "$($entry.Name).cmd"
    Unlock-File $cmdPath
    $cmdContent = "@echo off`r`nchcp 65001 >nul 2>`&1`r`nset `"PS=powershell`"`r`nwhere pwsh >nul 2>`&1 && set `"PS=pwsh`"`r`n%PS% -NoProfile -ExecutionPolicy Bypass -Command `"& '$launcher'`"`r`nif %ERRORLEVEL% neq 0 pause"
    [System.IO.File]::WriteAllText($cmdPath, $cmdContent, (New-Object System.Text.UTF8Encoding($false)))

    $lnkPath = Join-Path $cloudFolder "$($entry.Name).lnk"
    Unlock-File $lnkPath
    $s = $ws.CreateShortcut($lnkPath)
    $s.TargetPath = $cmdExe
    $s.Arguments = "/k chcp 65001 >nul & `"$psExe`" -NoProfile -ExecutionPolicy Bypass -File `"$launcher`""
    $s.WorkingDirectory = $RepoRoot
    $s.WindowStyle = 1
    $s.Save()

    $deskLnk = Join-Path $DesktopPath "$($entry.DeskName).lnk"
    Unlock-File $deskLnk
    $d = $ws.CreateShortcut($deskLnk)
    $d.TargetPath = $cmdExe
    $d.Arguments = "/c chcp 65001 >nul & `"$psExe`" -NoProfile -ExecutionPolicy Bypass -File `"$launcher`""
    $d.WorkingDirectory = $RepoRoot
    $d.WindowStyle = 1
    $d.Save()

    $deskItem = Get-Item -LiteralPath $deskLnk -Force
    $deskItem.Attributes = $deskItem.Attributes -band (-bnot [System.IO.FileAttributes]::Hidden)

    $okCount++
    Write-Host "[shortcuts] OK: $($entry.DeskName)" -ForegroundColor Green
  } catch {
    Write-Host "[shortcuts] ERROR $($entry.Name): $($_.Exception.Message)" -ForegroundColor Red
  }
}

try {
  Get-ChildItem -LiteralPath $cloudFolder -Force -ErrorAction SilentlyContinue | ForEach-Object {
    $_.Attributes = $_.Attributes -bor [System.IO.FileAttributes]::Hidden
  }
} catch {}

Write-Host ""
Write-Host "[shortcuts] Created: $okCount / $($launchers.Count)" -ForegroundColor $(if ($okCount -gt 0) { "Green" } else { "Red" })
