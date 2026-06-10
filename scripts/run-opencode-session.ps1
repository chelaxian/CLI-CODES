[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$ConfigPath,
  [string]$ExePath = "",
  [string]$SubCommand = ""
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $false

$npmBin = Join-Path $env:APPDATA "npm"
if ($npmBin -and (Test-Path -LiteralPath $npmBin)) {
  $parts = @($env:PATH -split ';' | Where-Object { $_ -and $_.Trim().Length -gt 0 })
  if (-not ($parts | Where-Object { $_.TrimEnd('\') -ieq $npmBin.TrimEnd('\') })) {
    $env:PATH = $npmBin + ";" + $env:PATH
  }
}

function Find-OpenCodeExe {
  foreach ($name in @("opencode.cmd", "opencode")) {
    $cmd = Get-Command $name -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
  }
  foreach ($p in @((Join-Path $npmBin "opencode.cmd"), (Join-Path $npmBin "opencode.ps1"))) {
    if (Test-Path -LiteralPath $p) { return $p }
  }
  return ""
}

if (-not [string]::IsNullOrWhiteSpace($ExePath)) {
  $opencodeExe = $ExePath
} else {
  $opencodeExe = Find-OpenCodeExe
}
if (-not $opencodeExe) {
  throw "OpenCode CLI not found. npm install -g opencode-ai@latest"
}

if ($ConfigPath -eq "__SUBCOMMAND__") {
  $args = $SubCommand -split ' '
  try {
    if ($opencodeExe -like "*.cmd" -or $opencodeExe -like "*.bat") {
      $allArgs = @("/c", $opencodeExe) + $args
      & cmd.exe @allArgs
    } else {
      & $opencodeExe @args
    }
  } catch {}
  return
}

if ($ConfigPath -eq "__VANILLA__") {
  Remove-Item -Path env:OPENCODE_CONFIG -ErrorAction SilentlyContinue
  try {
    if ($opencodeExe -like "*.cmd" -or $opencodeExe -like "*.bat") {
      & cmd.exe /c $opencodeExe
    } else {
      & $opencodeExe
    }
  } catch {}
  return
}

$env:OPENCODE_CONFIG = $ConfigPath

try {
  if ($opencodeExe -like "*.cmd" -or $opencodeExe -like "*.bat") {
    & cmd.exe /c $opencodeExe
  } else {
    & $opencodeExe
  }
} catch {}
