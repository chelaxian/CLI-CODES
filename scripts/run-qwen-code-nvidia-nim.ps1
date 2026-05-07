[CmdletBinding()]
param(
  [string]$Model = "nim-glm-4.7-tools"
)
$ErrorActionPreference = "Stop"

$ProgressPreference = "SilentlyContinue"

. (Join-Path $PSScriptRoot "ensure-streaming-friendly-terminal.ps1")

function Ensure-NpmBinInPath {
  $npmBin = Join-Path $env:APPDATA "npm"
  if (Test-Path -LiteralPath $npmBin) {
    $env:PATH = $npmBin + ";" + $env:PATH
  }
}

function Resolve-QwenExe {
  $cmd = Get-Command qwen -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  foreach ($p in @(
      (Join-Path $env:APPDATA "npm\qwen.cmd"),
      (Join-Path $env:APPDATA "npm\qwen.ps1")
    )) {
    if (Test-Path -LiteralPath $p) { return $p }
  }
  return ""
}

function Resolve-QwenNimSessionRoot([string]$ModelId) {
  return Join-Path (Split-Path -Parent $PSScriptRoot) "qwen-sessions\_shared"
}

function Resolve-NimApiKey {
  $k = [Environment]::GetEnvironmentVariable("NVIDIA_NIM_API_KEY", "User")
  if ([string]::IsNullOrWhiteSpace($k)) { $k = $env:NVIDIA_NIM_API_KEY }
  if (-not [string]::IsNullOrWhiteSpace($k)) { return $k.Trim() }

  $path = Join-Path $env:USERPROFILE ".qwen\settings.json"
  if (-not (Test-Path -LiteralPath $path)) { return "" }
  try {
    $cfg = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
    $mps = $cfg.modelProviders.openai
    if (-not $mps) { return "" }
    foreach ($entry in @($mps)) {
      $mid = [string]$entry.id
      if ($mid -match "^nim-") {
        $ek = [string]$entry.envKey
        if ([string]::IsNullOrWhiteSpace($ek)) { continue }
        $val = $cfg.env.$ek
        if ([string]::IsNullOrWhiteSpace($val)) { $val = [Environment]::GetEnvironmentVariable($ek, "User") }
        if ([string]::IsNullOrWhiteSpace($val)) { $val = [Environment]::GetEnvironmentVariable($ek, "Process") }
        if (-not [string]::IsNullOrWhiteSpace($val)) { return $val.Trim() }
      }
    }
  } catch {
    return ""
  }
  return ""
}

Remove-Item Env:ANTHROPIC_BASE_URL -ErrorAction SilentlyContinue
Remove-Item Env:ANTHROPIC_API_KEY -ErrorAction SilentlyContinue
Remove-Item Env:ANTHROPIC_AUTH_TOKEN -ErrorAction SilentlyContinue

$apiKey = Resolve-NimApiKey
if ([string]::IsNullOrWhiteSpace($apiKey)) {
  throw "NVIDIA NIM API key: задайте переменную пользователя NVIDIA_NIM_API_KEY или ключ в %USERPROFILE%\.qwen\settings.json для NIM моделей."
}

$env:OPENAI_API_KEY = $apiKey
$env:OPENAI_BASE_URL = "https://integrate.api.nvidia.com/v1"

Remove-Item Env:OPENAI_MODEL -ErrorAction SilentlyContinue

$sessionRoot = Resolve-QwenNimSessionRoot $Model
$qwenDir = Join-Path $sessionRoot ".qwen"
if (-not (Test-Path -LiteralPath $qwenDir)) { New-Item -ItemType Directory -Path $qwenDir -Force | Out-Null }

$settingsJson = @{
  modelProviders = @{
    openai = @(
      @{
        id = $Model
        name = "NVIDIA NIM - $($Model -replace '^nim-','')"
        envKey = "OPENAI_API_KEY"
        baseUrl = "https://integrate.api.nvidia.com/v1"
        generationConfig = @{
          timeout = 600000
          maxRetries = 4
          contextWindowSize = 131072
          samplingParams = @{
            temperature = 0.6
            top_p = 0.95
            max_tokens = 81920
          }
        }
      }
    )
  }
  security = @{
    auth = @{
      selectedType = "openai"
    }
  }
  model = @{
    name = $Model
  }
  '$version' = 3
} | ConvertTo-Json -Depth 10

[System.IO.File]::WriteAllText((Join-Path $qwenDir "settings.json"), $settingsJson, (New-Object System.Text.UTF8Encoding($false)))

$env:QWEN_CODE_MAX_OUTPUT_TOKENS = "81920"
$env:QWEN_CODE_EMIT_TOOL_USE_SUMMARIES = "1"
$env:API_TIMEOUT_MS = "600000"

Ensure-NpmBinInPath
$qwenExe = Resolve-QwenExe
if (-not $qwenExe) {
  throw "Qwen Code CLI not found. Reinstall with: npm install -g @qwen-code/qwen-code@latest"
}

Write-Host "Launching Qwen Code (NVIDIA NIM, $Model - direct API) ..." -ForegroundColor Cyan

Push-Location $sessionRoot
try {
  & $qwenExe
} finally {
  Pop-Location
}
