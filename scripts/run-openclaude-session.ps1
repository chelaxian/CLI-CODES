[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$ExePath,
  [string]$ArgumentsJson = "[]"
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $false

. (Join-Path $PSScriptRoot "launcher-tui.ps1")

$args = $ArgumentsJson | ConvertFrom-Json

try {
  if ($ExePath -like "*.cmd" -or $ExePath -like "*.bat") {
    $allArgs = @("/c", $ExePath) + $args
    & cmd.exe @allArgs
  } elseif ($args.Count -gt 0) {
    & $ExePath @args
  } else {
    & $ExePath
  }
} catch {}
