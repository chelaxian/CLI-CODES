[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "ensure-streaming-friendly-terminal.ps1")

function Read-SecretText([string]$Prompt) {
  $sec = Read-Host -Prompt $Prompt -AsSecureString
  $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
  try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) } finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}

function Ensure-NpmBinInPath {
  $npmBin = "C:\Users\chelaxian\AppData\Roaming\npm"
  if (Test-Path -LiteralPath $npmBin) {
    $env:PATH = $npmBin + ";" + $env:PATH
  }
}

function Resolve-QwenExe {
  $cmd = Get-Command qwen -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  $candidates = @(
    "C:\Users\chelaxian\AppData\Roaming\npm\qwen.cmd",
    "C:\Users\chelaxian\AppData\Roaming\npm\qwen.ps1"
  )
  foreach ($p in $candidates) {
    if (Test-Path -LiteralPath $p) { return $p }
  }
  return ""
}

Write-Host "Launching Qwen Code (Z.AI GLM-4.7: thinking + agent tools) ..." -ForegroundColor Cyan

$sessionRoot = Join-Path (Split-Path -Parent $PSScriptRoot) "qwen-sessions\zai-glm47"
if (-not (Test-Path -LiteralPath (Join-Path $sessionRoot ".qwen\settings.json"))) {
  throw "Missing project settings: $(Join-Path $sessionRoot '.qwen\settings.json')"
}

# Do not leak Claude / proxy Anthropic vars into Qwen Code (OpenAI protocol).
Remove-Item Env:ANTHROPIC_BASE_URL -ErrorAction SilentlyContinue
Remove-Item Env:ANTHROPIC_API_KEY -ErrorAction SilentlyContinue
Remove-Item Env:ANTHROPIC_AUTH_TOKEN -ErrorAction SilentlyContinue
Remove-Item Env:ANTHROPIC_DEFAULT_OPUS_MODEL -ErrorAction SilentlyContinue
Remove-Item Env:ANTHROPIC_DEFAULT_SONNET_MODEL -ErrorAction SilentlyContinue
Remove-Item Env:ANTHROPIC_DEFAULT_HAIKU_MODEL -ErrorAction SilentlyContinue

$zaiKey = [Environment]::GetEnvironmentVariable("ZAI_API_KEY","User")
if ([string]::IsNullOrWhiteSpace($zaiKey) -or $zaiKey -eq "__SET_ME__") {
  $zaiKey = $env:ZAI_API_KEY
}
if ([string]::IsNullOrWhiteSpace($zaiKey) -or $zaiKey -eq "__SET_ME__") {
  $zaiKey = [Environment]::GetEnvironmentVariable("OPENAI_API_KEY","User")
}
if ([string]::IsNullOrWhiteSpace($zaiKey) -or $zaiKey -eq "__SET_ME__") {
  $zaiKey = $env:OPENAI_API_KEY
}
if ([string]::IsNullOrWhiteSpace($zaiKey) -or $zaiKey -eq "__SET_ME__") {
  $zaiKey = Read-SecretText "Enter Z.AI API key (will not be saved)"
}

Ensure-NpmBinInPath

# Ключ в OPENAI_API_KEY; endpoint и extra_body (thinking) — в qwen-sessions/zai-glm47/.qwen/settings.json.
$env:OPENAI_API_KEY = $zaiKey
# baseUrl задаётся в qwen-sessions/zai-glm47/.qwen/settings.json (modelProviders), чтобы применить extra_body (thinking).
Remove-Item Env:OPENAI_BASE_URL -ErrorAction SilentlyContinue
Remove-Item Env:OPENAI_MODEL -ErrorAction SilentlyContinue
$env:API_TIMEOUT_MS = "600000"
$env:QWEN_CODE_MAX_OUTPUT_TOKENS = "81920"
$env:QWEN_CODE_EMIT_TOOL_USE_SUMMARIES = "1"

$qwenExe = Resolve-QwenExe
if (-not $qwenExe) {
  throw "Qwen Code CLI not found. Reinstall with: npm install -g @qwen-code/qwen-code@latest"
}

Push-Location $sessionRoot
try {
  & $qwenExe
} finally {
  Pop-Location
}

