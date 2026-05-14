# Создаёт ярлыки на рабочем столе: Claude/Qwen Code (cloud), OpenCode, Freebuff, OpenClaude.
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
  $DesktopPath = [Environment]::GetFolderPath("Desktop")
}

$cmdExe = (Get-Command cmd.exe -ErrorAction Stop).Source
$psExe  = (Get-Command powershell.exe -ErrorAction Stop).Source
$ws = New-Object -ComObject WScript.Shell

$launcherClaude = Join-Path $RepoRoot "scripts\run-claude-cloud-launcher.ps1"
$launcherQwen = Join-Path $RepoRoot "scripts\run-qwen-code-launcher.ps1"
$launcherOpenCode = Join-Path $RepoRoot "scripts\run-opencode-launcher.ps1"
$launcherFreebuff = Join-Path $RepoRoot "scripts\run-freebuff-launcher.ps1"
$launcherOpenClaude = Join-Path $RepoRoot "scripts\run-openclaude-launcher.ps1"

foreach ($p in @($launcherClaude, $launcherQwen, $launcherOpenCode, $launcherFreebuff, $launcherOpenClaude)) {
  if (-not (Test-Path -LiteralPath $p)) { throw "Не найден файл: $p" }
}

function New-Shortcut {
  param(
    [string]$LinkPath,
    [string]$TargetPath,
    [string]$Arguments,
    [string]$WorkingDirectory,
    [string]$Description
  )
  $s = $ws.CreateShortcut($LinkPath)
  $s.TargetPath = $TargetPath
  $s.Arguments = $Arguments
  $s.WorkingDirectory = $WorkingDirectory
  $s.WindowStyle = 1
  if ($Description) { $s.Description = $Description }
  $s.Save()

  $item = Get-Item -LiteralPath $LinkPath
  $item.Attributes = $item.Attributes -band (-bnot [System.IO.FileAttributes]::Hidden)
}

New-Shortcut `
  -LinkPath (Join-Path $DesktopPath "Claude Code (cloud).lnk") `
  -TargetPath $cmdExe `
  -Arguments ('/k chcp 65001 >nul & ' + $psExe + ' -NoProfile -ExecutionPolicy Bypass -File "' + $launcherClaude + '"') `
  -WorkingDirectory $RepoRoot `
  -Description "Claude Code: Z.AI или NIM через free-claude-code - меню."

New-Shortcut `
  -LinkPath (Join-Path $DesktopPath "Qwen Code (cloud).lnk") `
  -TargetPath $cmdExe `
  -Arguments ('/k chcp 65001 >nul & ' + $psExe + ' -NoProfile -ExecutionPolicy Bypass -File "' + $launcherQwen + '"') `
  -WorkingDirectory $RepoRoot `
  -Description "Qwen Code: Z.AI Coding / NVIDIA NIM - меню."

New-Shortcut `
  -LinkPath (Join-Path $DesktopPath "OpenCode (cloud).lnk") `
  -TargetPath $cmdExe `
  -Arguments ('/k chcp 65001 >nul & ' + $psExe + ' -NoProfile -ExecutionPolicy Bypass -File "' + $launcherOpenCode + '"') `
  -WorkingDirectory $RepoRoot `
  -Description "OpenCode: Z.AI / NIM / OpenRouter - меню выбора модели."

New-Shortcut `
  -LinkPath (Join-Path $DesktopPath "Freebuff (cloud).lnk") `
  -TargetPath $cmdExe `
  -Arguments ('/k chcp 65001 >nul & ' + $psExe + ' -NoProfile -ExecutionPolicy Bypass -File "' + $launcherFreebuff + '"') `
  -WorkingDirectory $RepoRoot `
  -Description "Freebuff: free coding agent - меню выбора модели."

New-Shortcut `
  -LinkPath (Join-Path $DesktopPath "OpenClaude (cloud).lnk") `
  -TargetPath $cmdExe `
  -Arguments ('/k chcp 65001 >nul & ' + $psExe + ' -NoProfile -ExecutionPolicy Bypass -File "' + $launcherOpenClaude + '"') `
  -WorkingDirectory $RepoRoot `
  -Description "OpenClaude: OpenAI-compatible coding-agent workflow."

foreach ($p in @($launcherClaude, $launcherQwen, $launcherOpenCode, $launcherFreebuff, $launcherOpenClaude)) {
  $item = Get-Item -LiteralPath $p
  $item.Attributes = $item.Attributes -bor [System.IO.FileAttributes]::Hidden
}

Get-ChildItem -LiteralPath $DesktopPath -Filter "*.cmd" | ForEach-Object {
  $_.Attributes = $_.Attributes -bor [System.IO.FileAttributes]::Hidden
}

$shortcutNames = @("Claude Code (cloud)", "Qwen Code (cloud)", "OpenCode (cloud)", "Freebuff (cloud)", "OpenClaude (cloud)")
Write-Host ("Shortcuts created on desktop: " + ($shortcutNames -join ", ")) -ForegroundColor Green
Write-Host "RepoRoot=$RepoRoot  Desktop=$DesktopPath" -ForegroundColor DarkGray
