
. (Join-Path $PSScriptRoot "ensure-streaming-friendly-terminal.ps1")
. (Join-Path $PSScriptRoot "launcher-tui.ps1")
. (Join-Path $PSScriptRoot "launcher-provider-models.ps1")
. (Join-Path $PSScriptRoot "launcher-custom-model-wizard.ps1")
. (Join-Path $PSScriptRoot "launcher-api-keys.ps1")

function Resolve-ApiKeyOrPrompt {
  param(
    [string]$CurrentKey,
    [string]$ProviderName,
    [string]$HelpUrl
  )
  if (-not [string]::IsNullOrWhiteSpace($CurrentKey) -and $CurrentKey -ne "__SET_ME__") {
    return $CurrentKey
  }
  Write-Host "$ProviderName API ключ не задан." -ForegroundColor Yellow
  Write-Host "Получить ключ: $HelpUrl" -ForegroundColor DarkCyan
  return (Read-SecretText "Введите $ProviderName API key")
}

$StatePath = Join-Path $PSScriptRoot "opencode-launcher-state.json"

$script:Profiles = @(
  @{
    Id    = "last"
    Label = "Запустить с последними настройками (быстрый старт)"
  }
  @{
    Id    = "group:zai"
    Label = "Z.AI - GLM-5.1 / GLM-4.7 / GLM-4.7-Flash"
  }
  @{
    Id    = "group:nim"
    Label = "NVIDIA NIM - бесплатные agentic модели"
  }
  # OpenRouter убран из пресетов: free endpoints rate-limited (429 Venice).
  # Используйте «Другая модель…» → OpenRouter для ручного выбора.
  @{
    Id    = "group:bai"
    Label = "B.AI - DeepSeek/MiniMax/GLM/Kimi/GPT (OpenAI-compatible)"
  }
  @{
    Id    = "group:openrouter"
    Label = "OpenRouter - бесплатные agentic модели"
  }
  @{
    Id    = "custom-model"
    Label = "Другая модель… → выбор провайдера и модели"
  }
  @{
    Id    = "native-login"
    Label = "Нативный логин (OpenCode Providers)"
  }
  @{
    Id    = "change-api-key"
    Label = "Сменить ключ API провайдера"
  }
)

# Характеристики B.AI моделей для Write-OpenCodeConfig (context window, max_tokens).
# Только agentic-модели — соответствуют $script:GroupMenus.bai (26 штук).
$script:BaiModelSpec = @{
  "gpt-5-nano"        = @{ Ctx = 128000;  Max = 16384 }
  "gpt-5-mini"        = @{ Ctx = 128000;  Max = 16384 }
  "gpt-5.2"           = @{ Ctx = 200000;  Max = 16384 }
  "gpt-5.4-nano"      = @{ Ctx = 200000;  Max = 16384 }
  "gpt-5.4-mini"      = @{ Ctx = 200000;  Max = 16384 }
  "gpt-5.4"           = @{ Ctx = 200000;  Max = 16384 }
  "gpt-5.4-pro"       = @{ Ctx = 200000;  Max = 16384 }
  "gpt-5.5"           = @{ Ctx = 200000;  Max = 16384 }
  "gpt-5.5-instant"   = @{ Ctx = 200000;  Max = 16384 }
  "claude-haiku-4.5"  = @{ Ctx = 200000;  Max = 8192 }
  "claude-sonnet-4.5" = @{ Ctx = 200000;  Max = 8192 }
  "claude-sonnet-4.6" = @{ Ctx = 200000;  Max = 8192 }
  "claude-opus-4.5"   = @{ Ctx = 200000;  Max = 8192 }
  "claude-opus-4.6"   = @{ Ctx = 200000;  Max = 8192 }
  "claude-opus-4.7"   = @{ Ctx = 200000;  Max = 8192 }
  "claude-opus-4.8"   = @{ Ctx = 200000;  Max = 8192 }
  "deepseek-v4-pro"   = @{ Ctx = 131072;  Max = 8192 }
  "deepseek-v4-flash" = @{ Ctx = 131072;  Max = 8192 }
  "gemini-3.1-pro"    = @{ Ctx = 1000000; Max = 8192 }
  "gemini-3.5-flash"  = @{ Ctx = 1000000; Max = 8192 }
  "glm-5"             = @{ Ctx = 128000;  Max = 8192 }
  "glm-5.1"           = @{ Ctx = 128000;  Max = 8192 }
  "kimi-k2.5"         = @{ Ctx = 131072;  Max = 8192 }
  "kimi-k2.6"         = @{ Ctx = 131072;  Max = 8192 }
  "minimax-m3"        = @{ Ctx = 1000000; Max = 8192 }
  "minimax-m2.7"      = @{ Ctx = 1000000; Max = 8192 }
}

# Подменю для каждой группы провайдера
$script:GroupMenus = @{
  zai = @(
    @{ Id = "zai-glm51";   Label = "Z.AI - GLM-5.1 (paid, tool calling)" }
    @{ Id = "zai-glm";     Label = "Z.AI - GLM-4.7 (paid, tool calling)" }
    @{ Id = "zai-flash47"; Label = "Z.AI - GLM-4.7-Flash (free, tool calling)" }
  )
  nim = @(
    @{ Id = "nim-mistral-medium";   Label = "NIM - Mistral Medium 3.5 128B (free, tool calling)" }
    @{ Id = "nim-glm51";            Label = "NIM - Z.AI GLM-5.1 (free, tool calling)" }
    @{ Id = "nim-step-3.5-flash";   Label = "NIM - Step 3.5 Flash (free, tool calling)" }
    @{ Id = "nim-mistral-large-3";  Label = "NIM - Mistral Large 3 675B (free, tool calling)" }
    @{ Id = "nim-deepseek-v4-flash"; Label = "NIM - DeepSeek V4 Flash 284B MoE (free)" }
    @{ Id = "nim-gemma-4-31b";      Label = "NIM - Google Gemma-4 31B (free)" }
    @{ Id = "nim-qwen3.5-397b";     Label = "NIM - Qwen 3.5 397B A17B (free)" }
    @{ Id = "nim-qwen3-next-80b";   Label = "NIM - Qwen 3 Next 80B A3B (free)" }
    @{ Id = "nim-qwen3-coder-480b"; Label = "NIM - Qwen 3 Coder 480B A35B (free)" }
  )
  openrouter = @(
    @{ Id = "openrouter-deepseek-v4-flash"; Label = "OpenRouter - DeepSeek V4 Flash (free, text-only — no images)" }
    @{ Id = "openrouter-qwen3-coder";       Label = "OpenRouter - Qwen3 Coder (free, text-only — no images)" }
    @{ Id = "openrouter-nemotron";          Label = "OpenRouter - Nemotron 3 Super 120B (free, text-only — no images)" }
    @{ Id = "openrouter-laguna";            Label = "OpenRouter - Poolside Laguna M.1 (free, text-only — no images, coding)" }
  )
  bai = @(
    @{ Id = "bai-gpt-5-nano";        Label = "B.AI - GPT-5 Nano (OpenAI, agentic)" }
    @{ Id = "bai-gpt-5-mini";        Label = "B.AI - GPT-5 Mini (OpenAI, agentic)" }
    @{ Id = "bai-gpt-5.2";           Label = "B.AI - GPT-5.2 (OpenAI, agentic)" }
    @{ Id = "bai-gpt-5.4-nano";      Label = "B.AI - GPT-5.4 Nano (OpenAI, agentic)" }
    @{ Id = "bai-gpt-5.4-mini";      Label = "B.AI - GPT-5.4 Mini (OpenAI, agentic)" }
    @{ Id = "bai-gpt-5.4";           Label = "B.AI - GPT-5.4 (OpenAI, agentic)" }
    @{ Id = "bai-gpt-5.4-pro";       Label = "B.AI - GPT-5.4 Pro (OpenAI, agentic)" }
    @{ Id = "bai-gpt-5.5";           Label = "B.AI - GPT-5.5 (OpenAI, agentic)" }
    @{ Id = "bai-gpt-5.5-instant";   Label = "B.AI - GPT-5.5 Instant (OpenAI, agentic)" }
    @{ Id = "bai-claude-haiku-4.5";  Label = "B.AI - Claude Haiku 4.5 (Anthropic, agentic)" }
    @{ Id = "bai-claude-sonnet-4.5"; Label = "B.AI - Claude Sonnet 4.5 (Anthropic, agentic)" }
    @{ Id = "bai-claude-sonnet-4.6"; Label = "B.AI - Claude Sonnet 4.6 (Anthropic, agentic)" }
    @{ Id = "bai-claude-opus-4.5";   Label = "B.AI - Claude Opus 4.5 (Anthropic, agentic)" }
    @{ Id = "bai-claude-opus-4.6";   Label = "B.AI - Claude Opus 4.6 (Anthropic, agentic)" }
    @{ Id = "bai-claude-opus-4.7";   Label = "B.AI - Claude Opus 4.7 (Anthropic, agentic)" }
    @{ Id = "bai-claude-opus-4.8";   Label = "B.AI - Claude Opus 4.8 (Anthropic, agentic)" }
    @{ Id = "bai-deepseek-v4-pro";   Label = "B.AI - DeepSeek V4 Pro (agentic)" }
    @{ Id = "bai-deepseek-v4-flash"; Label = "B.AI - DeepSeek V4 Flash (agentic)" }
    @{ Id = "bai-gemini-3.1-pro";    Label = "B.AI - Gemini 3.1 Pro (Google, agentic)" }
    @{ Id = "bai-gemini-3.5-flash";  Label = "B.AI - Gemini 3.5 Flash (Google, agentic)" }
    @{ Id = "bai-glm-5";             Label = "B.AI - GLM-5 (Z.AI)" }
    @{ Id = "bai-glm-5.1";           Label = "B.AI - GLM-5.1 (Z.AI)" }
    @{ Id = "bai-kimi-k2.5";         Label = "B.AI - Kimi K2.5 (Moonshot)" }
    @{ Id = "bai-kimi-k2.6";         Label = "B.AI - Kimi K2.6 (Moonshot)" }
    @{ Id = "bai-minimax-m3";        Label = "B.AI - MiniMax M3 (agentic)" }
    @{ Id = "bai-minimax-m2.7";      Label = "B.AI - MiniMax M2.7 (fast)" }
  )
}

function Get-LauncherState {
  if (-not (Test-Path -LiteralPath $StatePath)) { return $null }
  try {
    $raw = Get-Content -LiteralPath $StatePath -Raw -Encoding UTF8
    return ($raw | ConvertFrom-Json)
  } catch {
    return $null
  }
}

function Save-LauncherState {
  param(
    [Parameter(Mandatory = $true)][string]$ProfileId,
    [hashtable]$Extra = @{}
  )
  $obj = [ordered]@{
    profileId = $ProfileId
    updatedAt = (Get-Date).ToString("o")
  }
  foreach ($k in $Extra.Keys) {
    $obj[$k] = $Extra[$k]
  }
  ($obj | ConvertTo-Json -Compress) | Set-Content -LiteralPath $StatePath -Encoding UTF8
}

function Resolve-ProfileFromState($state) {
  if (-not $state -or [string]::IsNullOrWhiteSpace($state.profileId)) { return $null }
  $id = [string]$state.profileId
  if ($id -in @("zai-glm", "zai-glm51", "zai-flash47", "zai-flash45",
      "nim-mistral-medium", "nim-glm51", "nim-step-3.5-flash", "nim-mistral-large-3",
      "nim-deepseek-v4-flash", "nim-gemma-4-31b", "nim-qwen3.5-397b", "nim-qwen3-next-80b", "nim-qwen3-coder-480b",
      "openrouter-hy3", "openrouter-nemotron", "openrouter-laguna", "openrouter-deepseek-v4-flash", "openrouter-qwen3-coder",
      "custom-opencode-zai", "custom-opencode-nim", "custom-opencode-groq", "custom-opencode-openrouter", "custom-opencode-bai")) { return $id }
  # B.AI: динамически проверяем по agentic-списку
  if ($id -like "bai-*") {
    $mid = $id.Substring("bai-".Length)
    if ($mid -and ($script:BaiModelSpec.ContainsKey($mid))) { return $id }
  }
  return $null
}

function Resolve-OpenCodeExe {
  return (Resolve-CommandOrInstall -CommandName "opencode.cmd" -AltCommandName "opencode" -NpmPackage "opencode-ai" -DisplayName "OpenCode")
}

function Invoke-CliCommand {
  param(
    [Parameter(Mandatory = $true)][string]$ExePath,
    [string[]]$Arguments = @()
  )
  Invoke-ChildCliCatchCtrlC -ExePath $ExePath -Arguments $Arguments
}

function Write-OpenCodeConfig {
  param(
    [Parameter(Mandatory = $true)][string]$Provider,
    [Parameter(Mandatory = $true)][string]$Model,
    [Parameter(Mandatory = $true)][string]$BaseURL,
    [string]$ApiKey = "",
    [int]$MaxTokens = 8192,
    [int]$ContextLength = 131072,
    [switch]$UseBuiltInApi
  )

  $configDir = Join-Path $PSScriptRoot "opencode-sessions"
  if (-not (Test-Path -LiteralPath $configDir)) {
    New-Item -ItemType Directory -Path $configDir | Out-Null
  }

  $config = [ordered]@{
    '$schema' = "https://opencode.ai/config.json"
    provider  = [ordered]@{}
  }

  if ($UseBuiltInApi) {
    $providerConf = [ordered]@{
      api = $BaseURL
    }
  } else {
    $providerConf = [ordered]@{
      npm     = "@ai-sdk/openai-compatible"
      name    = $Provider
      options = [ordered]@{
        baseURL = $BaseURL
      }
      models  = [ordered]@{}
    }

    if (-not [string]::IsNullOrWhiteSpace($ApiKey)) {
      $providerConf.options["apiKey"] = $ApiKey
    }

    $providerConf.models[$Model] = [ordered]@{
      name          = $Model
      maxTokens     = $MaxTokens
      contextLength = $ContextLength
    }
  }

  $config.provider[$Provider] = $providerConf
  $config["model"] = "${Provider}/${Model}"

  $configPath = Join-Path $configDir "opencode.json"
  $json = ($config | ConvertTo-Json -Depth 10)
  [System.IO.File]::WriteAllText($configPath, $json, (New-Object System.Text.UTF8Encoding($false)))

  return $configPath
}

function Invoke-OpenCodeProfile {
  param([string]$ProfileId)

  $opencodeExe = Resolve-OpenCodeExe
  if (-not $opencodeExe) {
    throw "OpenCode CLI not found. Установите: npm install -g opencode-ai@latest"
  }

  $workingDir = Get-Location

  switch ($ProfileId) {
    "zai-glm" {
      $apiKey = [Environment]::GetEnvironmentVariable("ZAI_API_KEY", "User")
      if ([string]::IsNullOrWhiteSpace($apiKey) -or $apiKey -eq "__SET_ME__") {
        $apiKey = $env:ZAI_API_KEY
      }
      if ([string]::IsNullOrWhiteSpace($apiKey) -or $apiKey -eq "__SET_ME__") {
        $apiKey = [Environment]::GetEnvironmentVariable("OPENAI_API_KEY", "User")
      }
      if ([string]::IsNullOrWhiteSpace($apiKey) -or $apiKey -eq "__SET_ME__") {
        $apiKey = $env:OPENAI_API_KEY
      }
      if ([string]::IsNullOrWhiteSpace($apiKey) -or $apiKey -eq "__SET_ME__") {
        $apiKey = Resolve-ApiKeyOrPrompt -CurrentKey $apiKey -ProviderName "Z.AI" -HelpUrl "https://console.z.ai/"
      }

      $configPath = Write-OpenCodeConfig -Provider "zai" -Model "glm-4.7" -BaseURL "https://api.z.ai/api/coding/paas/v4" -ApiKey $apiKey -MaxTokens 8192 -ContextLength 131072
      $env:OPENCODE_CONFIG = $configPath
      Write-Host "Запуск OpenCode (Z.AI GLM-4.7)…" -ForegroundColor Cyan
      & (Join-Path $PSScriptRoot "run-opencode-session.ps1") -ConfigPath $configPath
      return
    }
    "zai-glm51" {
      $apiKey = [Environment]::GetEnvironmentVariable("ZAI_API_KEY", "User")
      if ([string]::IsNullOrWhiteSpace($apiKey) -or $apiKey -eq "__SET_ME__") {
        $apiKey = $env:ZAI_API_KEY
      }
      if ([string]::IsNullOrWhiteSpace($apiKey) -or $apiKey -eq "__SET_ME__") {
        $apiKey = [Environment]::GetEnvironmentVariable("OPENAI_API_KEY", "User")
      }
      if ([string]::IsNullOrWhiteSpace($apiKey) -or $apiKey -eq "__SET_ME__") {
        $apiKey = $env:OPENAI_API_KEY
      }
      if ([string]::IsNullOrWhiteSpace($apiKey) -or $apiKey -eq "__SET_ME__") {
        $apiKey = Resolve-ApiKeyOrPrompt -CurrentKey $apiKey -ProviderName "Z.AI" -HelpUrl "https://console.z.ai/"
      }

      $configPath = Write-OpenCodeConfig -Provider "zai" -Model "glm-5.1" -BaseURL "https://api.z.ai/api/coding/paas/v4" -ApiKey $apiKey -MaxTokens 8192 -ContextLength 131072
      $env:OPENCODE_CONFIG = $configPath
      Write-Host "Запуск OpenCode (Z.AI GLM-5.1)…" -ForegroundColor Cyan
      & (Join-Path $PSScriptRoot "run-opencode-session.ps1") -ConfigPath $configPath
      return
    }
    "zai-flash47" {
      $apiKey = [Environment]::GetEnvironmentVariable("ZAI_API_KEY", "User")
      if ([string]::IsNullOrWhiteSpace($apiKey) -or $apiKey -eq "__SET_ME__") { $apiKey = $env:ZAI_API_KEY }
      if ([string]::IsNullOrWhiteSpace($apiKey) -or $apiKey -eq "__SET_ME__") { $apiKey = [Environment]::GetEnvironmentVariable("OPENAI_API_KEY", "User") }
      if ([string]::IsNullOrWhiteSpace($apiKey) -or $apiKey -eq "__SET_ME__") { $apiKey = $env:OPENAI_API_KEY }
      if ([string]::IsNullOrWhiteSpace($apiKey) -or $apiKey -eq "__SET_ME__") {
        $apiKey = Resolve-ApiKeyOrPrompt -CurrentKey $apiKey -ProviderName "Z.AI" -HelpUrl "https://console.z.ai/"
      }
      $configPath = Write-OpenCodeConfig -Provider "zai" -Model "glm-4.7-flash" -BaseURL "https://api.z.ai/api/coding/paas/v4" -ApiKey $apiKey -MaxTokens 8192 -ContextLength 131072
      $env:OPENCODE_CONFIG = $configPath
      Write-Host "Запуск OpenCode (Z.AI GLM-4.7-Flash)…" -ForegroundColor Cyan
      & (Join-Path $PSScriptRoot "run-opencode-session.ps1") -ConfigPath $configPath
      return
    }
    "zai-flash45" {
      $apiKey = [Environment]::GetEnvironmentVariable("ZAI_API_KEY", "User")
      if ([string]::IsNullOrWhiteSpace($apiKey) -or $apiKey -eq "__SET_ME__") { $apiKey = $env:ZAI_API_KEY }
      if ([string]::IsNullOrWhiteSpace($apiKey) -or $apiKey -eq "__SET_ME__") { $apiKey = [Environment]::GetEnvironmentVariable("OPENAI_API_KEY", "User") }
      if ([string]::IsNullOrWhiteSpace($apiKey) -or $apiKey -eq "__SET_ME__") { $apiKey = $env:OPENAI_API_KEY }
      if ([string]::IsNullOrWhiteSpace($apiKey) -or $apiKey -eq "__SET_ME__") {
        $apiKey = Resolve-ApiKeyOrPrompt -CurrentKey $apiKey -ProviderName "Z.AI" -HelpUrl "https://console.z.ai/"
      }
      $configPath = Write-OpenCodeConfig -Provider "zai" -Model "glm-4.5-flash" -BaseURL "https://api.z.ai/api/coding/paas/v4" -ApiKey $apiKey -MaxTokens 8192 -ContextLength 131072
      $env:OPENCODE_CONFIG = $configPath
      Write-Host "Запуск OpenCode (Z.AI GLM-4.5-Flash)…" -ForegroundColor Cyan
      & (Join-Path $PSScriptRoot "run-opencode-session.ps1") -ConfigPath $configPath
      return
    }
    "nim-mistral-medium" {
      $apiKey = [Environment]::GetEnvironmentVariable("NVIDIA_NIM_API_KEY", "User")
      if ([string]::IsNullOrWhiteSpace($apiKey)) { $apiKey = $env:NVIDIA_NIM_API_KEY }
      if ([string]::IsNullOrWhiteSpace($apiKey)) {
        $apiKey = Resolve-ApiKeyOrPrompt -CurrentKey $apiKey -ProviderName "NVIDIA NIM" -HelpUrl "https://build.nvidia.com/api-key"
      }
      $configPath = Write-OpenCodeConfig -Provider "nvidia-nim" -Model "mistralai/mistral-medium-3.5-128b" -BaseURL "https://integrate.api.nvidia.com/v1" -ApiKey $apiKey -MaxTokens 8192 -ContextLength 131072
      $env:OPENCODE_CONFIG = $configPath
      Write-Host "Запуск OpenCode (NVIDIA NIM Mistral Medium 3.5 128B)…" -ForegroundColor Cyan
      & (Join-Path $PSScriptRoot "run-opencode-session.ps1") -ConfigPath $configPath
      return
    }
    "nim-glm51" {
      $apiKey = [Environment]::GetEnvironmentVariable("NVIDIA_NIM_API_KEY", "User")
      if ([string]::IsNullOrWhiteSpace($apiKey)) { $apiKey = $env:NVIDIA_NIM_API_KEY }
      if ([string]::IsNullOrWhiteSpace($apiKey)) {
        $apiKey = Resolve-ApiKeyOrPrompt -CurrentKey $apiKey -ProviderName "NVIDIA NIM" -HelpUrl "https://build.nvidia.com/api-key"
      }
      $configPath = Write-OpenCodeConfig -Provider "nvidia-nim" -Model "z-ai/glm-5.1" -BaseURL "https://integrate.api.nvidia.com/v1" -ApiKey $apiKey -MaxTokens 8192 -ContextLength 131072
      $env:OPENCODE_CONFIG = $configPath
      Write-Host "Запуск OpenCode (NVIDIA NIM Z.AI GLM-5.1)…" -ForegroundColor Cyan
      & (Join-Path $PSScriptRoot "run-opencode-session.ps1") -ConfigPath $configPath
      return
    }
    "nim-step-3.5-flash" {
      $apiKey = [Environment]::GetEnvironmentVariable("NVIDIA_NIM_API_KEY", "User")
      if ([string]::IsNullOrWhiteSpace($apiKey)) { $apiKey = $env:NVIDIA_NIM_API_KEY }
      if ([string]::IsNullOrWhiteSpace($apiKey)) {
        $apiKey = Resolve-ApiKeyOrPrompt -CurrentKey $apiKey -ProviderName "NVIDIA NIM" -HelpUrl "https://build.nvidia.com/api-key"
      }
      $configPath = Write-OpenCodeConfig -Provider "nvidia-nim" -Model "stepfun-ai/step-3.5-flash" -BaseURL "https://integrate.api.nvidia.com/v1" -ApiKey $apiKey -MaxTokens 8192 -ContextLength 131072
      $env:OPENCODE_CONFIG = $configPath
      Write-Host "Запуск OpenCode (NVIDIA NIM Step 3.5 Flash)…" -ForegroundColor Cyan
      & (Join-Path $PSScriptRoot "run-opencode-session.ps1") -ConfigPath $configPath
      return
    }
    "nim-mistral-large-3" {
      $apiKey = [Environment]::GetEnvironmentVariable("NVIDIA_NIM_API_KEY", "User")
      if ([string]::IsNullOrWhiteSpace($apiKey)) { $apiKey = $env:NVIDIA_NIM_API_KEY }
      if ([string]::IsNullOrWhiteSpace($apiKey)) {
        $apiKey = Resolve-ApiKeyOrPrompt -CurrentKey $apiKey -ProviderName "NVIDIA NIM" -HelpUrl "https://build.nvidia.com/api-key"
      }
      $configPath = Write-OpenCodeConfig -Provider "nvidia-nim" -Model "mistralai/mistral-large-3-675b-instruct-2512" -BaseURL "https://integrate.api.nvidia.com/v1" -ApiKey $apiKey -MaxTokens 8192 -ContextLength 131072
      $env:OPENCODE_CONFIG = $configPath
      Write-Host "Запуск OpenCode (NVIDIA NIM Mistral Large 3 675B)…" -ForegroundColor Cyan
      & (Join-Path $PSScriptRoot "run-opencode-session.ps1") -ConfigPath $configPath
      return
    }
    "nim-deepseek-v4-flash" {
      $apiKey = [Environment]::GetEnvironmentVariable("NVIDIA_NIM_API_KEY", "User")
      if ([string]::IsNullOrWhiteSpace($apiKey)) { $apiKey = $env:NVIDIA_NIM_API_KEY }
      if ([string]::IsNullOrWhiteSpace($apiKey)) {
        $apiKey = Resolve-ApiKeyOrPrompt -CurrentKey $apiKey -ProviderName "NVIDIA NIM" -HelpUrl "https://build.nvidia.com/api-key"
      }
      $configPath = Write-OpenCodeConfig -Provider "nvidia-nim" -Model "deepseek-ai/deepseek-v4-flash" -BaseURL "https://integrate.api.nvidia.com/v1" -ApiKey $apiKey -MaxTokens 8192 -ContextLength 131072
      $env:OPENCODE_CONFIG = $configPath
      Write-Host "Запуск OpenCode (NVIDIA NIM DeepSeek V4 Flash)…" -ForegroundColor Cyan
      & (Join-Path $PSScriptRoot "run-opencode-session.ps1") -ConfigPath $configPath
      return
    }
    "nim-gemma-4-31b" {
      $apiKey = [Environment]::GetEnvironmentVariable("NVIDIA_NIM_API_KEY", "User")
      if ([string]::IsNullOrWhiteSpace($apiKey)) { $apiKey = $env:NVIDIA_NIM_API_KEY }
      if ([string]::IsNullOrWhiteSpace($apiKey)) {
        $apiKey = Resolve-ApiKeyOrPrompt -CurrentKey $apiKey -ProviderName "NVIDIA NIM" -HelpUrl "https://build.nvidia.com/api-key"
      }
      $configPath = Write-OpenCodeConfig -Provider "nvidia-nim" -Model "google/gemma-4-31b-it" -BaseURL "https://integrate.api.nvidia.com/v1" -ApiKey $apiKey -MaxTokens 8192 -ContextLength 131072
      $env:OPENCODE_CONFIG = $configPath
      Write-Host "Запуск OpenCode (NVIDIA NIM Gemma-4 31B)…" -ForegroundColor Cyan
      & (Join-Path $PSScriptRoot "run-opencode-session.ps1") -ConfigPath $configPath
      return
    }
    "nim-qwen3.5-397b" {
      $apiKey = [Environment]::GetEnvironmentVariable("NVIDIA_NIM_API_KEY", "User")
      if ([string]::IsNullOrWhiteSpace($apiKey)) { $apiKey = $env:NVIDIA_NIM_API_KEY }
      if ([string]::IsNullOrWhiteSpace($apiKey)) {
        $apiKey = Resolve-ApiKeyOrPrompt -CurrentKey $apiKey -ProviderName "NVIDIA NIM" -HelpUrl "https://build.nvidia.com/api-key"
      }
      $configPath = Write-OpenCodeConfig -Provider "nvidia-nim" -Model "qwen/qwen3.5-397b-a17b" -BaseURL "https://integrate.api.nvidia.com/v1" -ApiKey $apiKey -MaxTokens 8192 -ContextLength 131072
      $env:OPENCODE_CONFIG = $configPath
      Write-Host "Запуск OpenCode (NVIDIA NIM Qwen 3.5 397B)…" -ForegroundColor Cyan
      & (Join-Path $PSScriptRoot "run-opencode-session.ps1") -ConfigPath $configPath
      return
    }
    "nim-qwen3-next-80b" {
      $apiKey = [Environment]::GetEnvironmentVariable("NVIDIA_NIM_API_KEY", "User")
      if ([string]::IsNullOrWhiteSpace($apiKey)) { $apiKey = $env:NVIDIA_NIM_API_KEY }
      if ([string]::IsNullOrWhiteSpace($apiKey)) {
        $apiKey = Resolve-ApiKeyOrPrompt -CurrentKey $apiKey -ProviderName "NVIDIA NIM" -HelpUrl "https://build.nvidia.com/api-key"
      }
      $configPath = Write-OpenCodeConfig -Provider "nvidia-nim" -Model "qwen/qwen3-next-80b-a3b-instruct" -BaseURL "https://integrate.api.nvidia.com/v1" -ApiKey $apiKey -MaxTokens 8192 -ContextLength 131072
      $env:OPENCODE_CONFIG = $configPath
      Write-Host "Запуск OpenCode (NVIDIA NIM Qwen 3 Next 80B)…" -ForegroundColor Cyan
      & (Join-Path $PSScriptRoot "run-opencode-session.ps1") -ConfigPath $configPath
      return
    }
    "nim-qwen3-coder-480b" {
      $apiKey = [Environment]::GetEnvironmentVariable("NVIDIA_NIM_API_KEY", "User")
      if ([string]::IsNullOrWhiteSpace($apiKey)) { $apiKey = $env:NVIDIA_NIM_API_KEY }
      if ([string]::IsNullOrWhiteSpace($apiKey)) {
        $apiKey = Resolve-ApiKeyOrPrompt -CurrentKey $apiKey -ProviderName "NVIDIA NIM" -HelpUrl "https://build.nvidia.com/api-key"
      }
      $configPath = Write-OpenCodeConfig -Provider "nvidia-nim" -Model "qwen/qwen3-coder-480b-a35b-instruct" -BaseURL "https://integrate.api.nvidia.com/v1" -ApiKey $apiKey -MaxTokens 8192 -ContextLength 131072
      $env:OPENCODE_CONFIG = $configPath
      Write-Host "Запуск OpenCode (NVIDIA NIM Qwen 3 Coder 480B)…" -ForegroundColor Cyan
      & (Join-Path $PSScriptRoot "run-opencode-session.ps1") -ConfigPath $configPath
      return
    }
    "custom-opencode-zai" {
      $st = Get-LauncherState
      $mid = [string]$st.customModelId
      if ([string]::IsNullOrWhiteSpace($mid)) {
        throw "Нет customModelId. Выберите модель в пункте «Другая модель»."
      }
      $apiKey = [Environment]::GetEnvironmentVariable("ZAI_API_KEY", "User")
      if ([string]::IsNullOrWhiteSpace($apiKey) -or $apiKey -eq "__SET_ME__") { $apiKey = $env:ZAI_API_KEY }
      if ([string]::IsNullOrWhiteSpace($apiKey) -or $apiKey -eq "__SET_ME__") { $apiKey = [Environment]::GetEnvironmentVariable("OPENAI_API_KEY", "User") }
      if ([string]::IsNullOrWhiteSpace($apiKey) -or $apiKey -eq "__SET_ME__") { $apiKey = $env:OPENAI_API_KEY }
      if ([string]::IsNullOrWhiteSpace($apiKey) -or $apiKey -eq "__SET_ME__") {
        $apiKey = Resolve-ApiKeyOrPrompt -CurrentKey $apiKey -ProviderName "Z.AI" -HelpUrl "https://console.z.ai/"
      }
      $configPath = Write-OpenCodeConfig -Provider "zai" -Model $mid.Trim() -BaseURL "https://api.z.ai/api/coding/paas/v4" -ApiKey $apiKey
      $env:OPENCODE_CONFIG = $configPath
      Write-Host "Запуск OpenCode (Z.AI custom: $($mid.Trim()))…" -ForegroundColor Cyan
      & (Join-Path $PSScriptRoot "run-opencode-session.ps1") -ConfigPath $configPath
      return
    }
    "custom-opencode-nim" {
      $st = Get-LauncherState
      $mid = [string]$st.customModelId
      if ([string]::IsNullOrWhiteSpace($mid)) {
        throw "Нет customModelId. Выберите модель в пункте «Другая модель»."
      }
      $apiKey = [Environment]::GetEnvironmentVariable("NVIDIA_NIM_API_KEY", "User")
      if ([string]::IsNullOrWhiteSpace($apiKey)) { $apiKey = $env:NVIDIA_NIM_API_KEY }
      if ([string]::IsNullOrWhiteSpace($apiKey)) {
        $apiKey = Resolve-ApiKeyOrPrompt -CurrentKey $apiKey -ProviderName "NVIDIA NIM" -HelpUrl "https://build.nvidia.com/api-key"
      }
      $configPath = Write-OpenCodeConfig -Provider "nvidia-nim" -Model $mid.Trim() -BaseURL "https://integrate.api.nvidia.com/v1" -ApiKey $apiKey
      $env:OPENCODE_CONFIG = $configPath
      Write-Host "Запуск OpenCode (NVIDIA NIM custom: $($mid.Trim()))…" -ForegroundColor Cyan
      & (Join-Path $PSScriptRoot "run-opencode-session.ps1") -ConfigPath $configPath
      return
    }
    "custom-opencode-groq" {
      $st = Get-LauncherState
      $mid = [string]$st.customModelId
      if ([string]::IsNullOrWhiteSpace($mid)) {
        throw "Нет customModelId. Выберите модель в пункте «Другая модель»."
      }
      $apiKey = [Environment]::GetEnvironmentVariable("GROQ_API_KEY", "User")
      if ([string]::IsNullOrWhiteSpace($apiKey)) { $apiKey = $env:GROQ_API_KEY }
      if ([string]::IsNullOrWhiteSpace($apiKey)) {
        $apiKey = Resolve-ApiKeyOrPrompt -CurrentKey $apiKey -ProviderName "Groq" -HelpUrl "https://console.groq.com/keys"
      }
      $configPath = Write-OpenCodeConfig -Provider "groq" -Model $mid.Trim() -BaseURL "https://api.groq.com/openai/v1" -ApiKey $apiKey -MaxTokens 8192 -ContextLength 131072
      $env:OPENCODE_CONFIG = $configPath
      Write-Host "Запуск OpenCode (Groq custom: $($mid.Trim()))…" -ForegroundColor Cyan
      & (Join-Path $PSScriptRoot "run-opencode-session.ps1") -ConfigPath $configPath
      return
    }
    "custom-opencode-openrouter" {
      $st = Get-LauncherState
      $mid = [string]$st.customModelId
      if ([string]::IsNullOrWhiteSpace($mid)) {
        throw "Нет customModelId. Выберите модель в пункте «Другая модель»."
      }
      $apiKey = [Environment]::GetEnvironmentVariable("OPENROUTER_API_KEY", "User")
      if ([string]::IsNullOrWhiteSpace($apiKey)) { $apiKey = $env:OPENROUTER_API_KEY }
      if ([string]::IsNullOrWhiteSpace($apiKey)) {
        $apiKey = Resolve-ApiKeyOrPrompt -CurrentKey $apiKey -ProviderName "OpenRouter" -HelpUrl "https://openrouter.ai/settings/keys"
      }
      $configPath = Write-OpenCodeConfig -Provider "openrouter" -Model $mid.Trim() -BaseURL "https://openrouter.ai/api/v1" -ApiKey $apiKey -MaxTokens 8192 -ContextLength 16384
      $env:OPENCODE_CONFIG = $configPath
      Write-Host "Запуск OpenCode (OpenRouter custom: $($mid.Trim()))…" -ForegroundColor Cyan
      & (Join-Path $PSScriptRoot "run-opencode-session.ps1") -ConfigPath $configPath
      return
    }
    "custom-opencode-bai" {
      $st = Get-LauncherState
      $mid = [string]$st.customModelId
      if ([string]::IsNullOrWhiteSpace($mid)) {
        throw "Нет customModelId. Выберите модель в пункте «Другая модель»."
      }
      $apiKey = [Environment]::GetEnvironmentVariable("BAI_API_KEY", "User")
      if ([string]::IsNullOrWhiteSpace($apiKey) -or $apiKey -eq "__SET_ME__") { $apiKey = $env:BAI_API_KEY }
      if ([string]::IsNullOrWhiteSpace($apiKey) -or $apiKey -eq "__SET_ME__") {
        $apiKey = Resolve-ApiKeyOrPrompt -CurrentKey $apiKey -ProviderName "B.AI" -HelpUrl "https://chat.b.ai/key"
      }
      $configPath = Write-OpenCodeConfig -Provider "bai" -Model $mid.Trim() -BaseURL "https://api.b.ai/v1" -ApiKey $apiKey -MaxTokens 8192 -ContextLength 131072
      $env:OPENCODE_CONFIG = $configPath
      Write-Host "Запуск OpenCode (B.AI custom: $($mid.Trim()))…" -ForegroundColor Cyan
      & (Join-Path $PSScriptRoot "run-opencode-session.ps1") -ConfigPath $configPath
      return
    }
    "openrouter-hy3" {
      $apiKey = [Environment]::GetEnvironmentVariable("OPENROUTER_API_KEY", "User")
      if ([string]::IsNullOrWhiteSpace($apiKey)) { $apiKey = $env:OPENROUTER_API_KEY }
      if ([string]::IsNullOrWhiteSpace($apiKey)) { $apiKey = Resolve-ApiKeyOrPrompt -CurrentKey $apiKey -ProviderName "OpenRouter" -HelpUrl "https://openrouter.ai/settings/keys" }
      $configPath = Write-OpenCodeConfig -Provider "openrouter" -Model "deepseek/deepseek-chat-v3.1:free" -BaseURL "https://openrouter.ai/api/v1" -ApiKey $apiKey -MaxTokens 8192 -ContextLength 1048576
      $env:OPENCODE_CONFIG = $configPath
      Write-Host "Запуск OpenCode (OpenRouter DeepSeek Chat V3.1)…" -ForegroundColor Cyan
      & (Join-Path $PSScriptRoot "run-opencode-session.ps1") -ConfigPath $configPath
      return
    }
    "openrouter-deepseek-v4-flash" {
      $apiKey = [Environment]::GetEnvironmentVariable("OPENROUTER_API_KEY", "User")
      if ([string]::IsNullOrWhiteSpace($apiKey)) { $apiKey = $env:OPENROUTER_API_KEY }
      if ([string]::IsNullOrWhiteSpace($apiKey)) {
        $apiKey = Resolve-ApiKeyOrPrompt -CurrentKey $apiKey -ProviderName "OpenRouter" -HelpUrl "https://openrouter.ai/settings/keys"
      }
      $configPath = Write-OpenCodeConfig -Provider "openrouter" -Model "deepseek/deepseek-chat-v3.1:free" -BaseURL "https://openrouter.ai/api/v1" -ApiKey $apiKey -MaxTokens 8192 -ContextLength 1048576
      $env:OPENCODE_CONFIG = $configPath
      Write-Host "Запуск OpenCode (OpenRouter DeepSeek V4 Flash)…" -ForegroundColor Cyan
      & (Join-Path $PSScriptRoot "run-opencode-session.ps1") -ConfigPath $configPath
      return
    }
    "openrouter-qwen3-coder" {
      $apiKey = [Environment]::GetEnvironmentVariable("OPENROUTER_API_KEY", "User")
      if ([string]::IsNullOrWhiteSpace($apiKey)) { $apiKey = $env:OPENROUTER_API_KEY }
      if ([string]::IsNullOrWhiteSpace($apiKey)) {
        $apiKey = Resolve-ApiKeyOrPrompt -CurrentKey $apiKey -ProviderName "OpenRouter" -HelpUrl "https://openrouter.ai/settings/keys"
      }
      $configPath = Write-OpenCodeConfig -Provider "openrouter" -Model "qwen/qwen3-coder:free" -BaseURL "https://openrouter.ai/api/v1" -ApiKey $apiKey -MaxTokens 8192 -ContextLength 262000
      $env:OPENCODE_CONFIG = $configPath
      Write-Host "Запуск OpenCode (OpenRouter Qwen3 Coder)…" -ForegroundColor Cyan
      & (Join-Path $PSScriptRoot "run-opencode-session.ps1") -ConfigPath $configPath
      return
    }
    "openrouter-nemotron" {
      $apiKey = [Environment]::GetEnvironmentVariable("OPENROUTER_API_KEY", "User")
      if ([string]::IsNullOrWhiteSpace($apiKey)) { $apiKey = $env:OPENROUTER_API_KEY }
      if ([string]::IsNullOrWhiteSpace($apiKey)) { $apiKey = Resolve-ApiKeyOrPrompt -CurrentKey $apiKey -ProviderName "OpenRouter" -HelpUrl "https://openrouter.ai/settings/keys" }
      $configPath = Write-OpenCodeConfig -Provider "openrouter" -Model "nvidia/nemotron-3-super-120b-a12b:free" -BaseURL "https://openrouter.ai/api/v1" -ApiKey $apiKey -MaxTokens 8192 -ContextLength 262144
      $env:OPENCODE_CONFIG = $configPath
      Write-Host "Запуск OpenCode (OpenRouter Nemotron 3 Super)…" -ForegroundColor Cyan
      & (Join-Path $PSScriptRoot "run-opencode-session.ps1") -ConfigPath $configPath
      return
    }
    "openrouter-laguna" {
      $apiKey = [Environment]::GetEnvironmentVariable("OPENROUTER_API_KEY", "User")
      if ([string]::IsNullOrWhiteSpace($apiKey)) { $apiKey = $env:OPENROUTER_API_KEY }
      if ([string]::IsNullOrWhiteSpace($apiKey)) { $apiKey = Resolve-ApiKeyOrPrompt -CurrentKey $apiKey -ProviderName "OpenRouter" -HelpUrl "https://openrouter.ai/settings/keys" }
      $configPath = Write-OpenCodeConfig -Provider "openrouter" -Model "poolside/laguna-m.1:free" -BaseURL "https://openrouter.ai/api/v1" -ApiKey $apiKey -MaxTokens 8192 -ContextLength 131072
      $env:OPENCODE_CONFIG = $configPath
      Write-Host "Запуск OpenCode (OpenRouter Poolside Laguna M.1)…" -ForegroundColor Cyan
      & (Join-Path $PSScriptRoot "run-opencode-session.ps1") -ConfigPath $configPath
      return
    }
    default {
      if ($ProfileId -like "bai-*") {
        $mid = $ProfileId.Substring("bai-".Length)
        $spec = $script:BaiModelSpec[$mid]
        $apiKey = [Environment]::GetEnvironmentVariable("BAI_API_KEY", "User")
        if ($apiKey -or $apiKey -eq "__SET_ME__") { $apiKey = $env:BAI_API_KEY }
        if (-not $apiKey -or $apiKey -eq "__SET_ME__") {
          $apiKey = Resolve-ApiKeyOrPrompt -CurrentKey $apiKey -ProviderName "B.AI" -HelpUrl "https://chat.b.ai/key"
        }
        if ($spec) {
          $configPath = Write-OpenCodeConfig -Provider "bai" -Model $mid -BaseURL "https://api.b.ai/v1" -ApiKey $apiKey -MaxTokens $spec.Max -ContextLength $spec.Ctx
        } else {
          $configPath = Write-OpenCodeConfig -Provider "bai" -Model $mid -BaseURL "https://api.b.ai/v1" -ApiKey $apiKey
        }
        $env:OPENCODE_CONFIG = $configPath
        Write-Host "Запуск OpenCode (B.AI ${mid})…" -ForegroundColor Cyan
        & (Join-Path $PSScriptRoot "run-opencode-session.ps1") -ConfigPath $configPath
        return
      }
      if ($ProfileId -like "openrouter-*") {
        $mid = $ProfileId.Substring("openrouter-".Length)
        $apiKey = [Environment]::GetEnvironmentVariable("OPENROUTER_API_KEY", "User")
        if ($apiKey) { $apiKey = $env:OPENROUTER_API_KEY }
        if (-not $apiKey) {
          $apiKey = Resolve-ApiKeyOrPrompt -CurrentKey $apiKey -ProviderName "OpenRouter" -HelpUrl "https://openrouter.ai/settings/keys"
        }
        $configPath = Write-OpenCodeConfig -Provider "openrouter" -Model $mid -BaseURL "https://openrouter.ai/api/v1" -ApiKey $apiKey
        $env:OPENCODE_CONFIG = $configPath
        Write-Host "Запуск OpenCode (OpenRouter ${mid})…" -ForegroundColor Cyan
        & (Join-Path $PSScriptRoot "run-opencode-session.ps1") -ConfigPath $configPath
        return
      }
      if ($ProfileId -like "nim-*") {
        $mid = $ProfileId.Substring("nim-".Length)
        $apiKey = [Environment]::GetEnvironmentVariable("NVIDIA_NIM_API_KEY", "User")
        if ($apiKey) { $apiKey = $env:NVIDIA_NIM_API_KEY }
        if (-not $apiKey) {
          $apiKey = Resolve-ApiKeyOrPrompt -CurrentKey $apiKey -ProviderName "NVIDIA NIM" -HelpUrl "https://build.nvidia.com/api-key"
        }
        $configPath = Write-OpenCodeConfig -Provider "nvidia-nim" -Model $mid -BaseURL "https://integrate.api.nvidia.com/v1" -ApiKey $apiKey
        $env:OPENCODE_CONFIG = $configPath
        Write-Host "Запуск OpenCode (NVIDIA NIM ${mid})…" -ForegroundColor Cyan
        & (Join-Path $PSScriptRoot "run-opencode-session.ps1") -ConfigPath $configPath
        return
      }
      throw "Неизвестный профиль: $ProfileId"
    }
  }
}

# ── Быстрый старт ────────────────────────────────────────────────────────────

if ($Quick -or $env:OPENCODE_LAUNCHER_QUICK -eq "1") {
  $st = Get-LauncherState
  $resolvedId = Resolve-ProfileFromState $st
  if (-not $resolvedId) {
    Write-Host "Нет сохранённого профиля. Один раз выберите модель в меню." -ForegroundColor Yellow
    Start-Sleep -Seconds 3
    exit 2
  }
  Invoke-OpenCodeProfile -ProfileId $resolvedId
  exit $LASTEXITCODE
}

# ── Главное меню ─────────────────────────────────────────────────────────────

$updateHint = Test-LauncherUpdates -AgentNpmPackage "opencode-ai" -AgentDisplayName "OpenCode"

# Build provider group menus dynamically from API (with static fallback).
$staticZaiOC = @(
  @{ Id = "zai-glm51";   Label = "Z.AI - GLM-5.1 (paid, tool calling)" }
  @{ Id = "zai-glm";     Label = "Z.AI - GLM-4.7 (paid, tool calling)" }
  @{ Id = "zai-flash47"; Label = "Z.AI - GLM-4.7-Flash (free, tool calling)" }
)
$staticNimOC = @(
  @{ Id = "nim-mistral-medium";   Label = "NIM - Mistral Medium 3.5 128B (free, tool calling)";     NimModel = "nim-mistral-medium-3.5-128b" }
  @{ Id = "nim-glm51";            Label = "NIM - Z.AI GLM-5.1 (free, tool calling)";                 NimModel = "nim-glm-5.1" }
  @{ Id = "nim-step-3.5-flash";   Label = "NIM - Step 3.5 Flash (free, tool calling)";               NimModel = "nim-step-3.5-flash" }
  @{ Id = "nim-mistral-large-3";  Label = "NIM - Mistral Large 3 675B (free, tool calling)";         NimModel = "nim-mistral-large-3-675b" }
  @{ Id = "nim-deepseek-v4-flash"; Label = "NIM - DeepSeek V4 Flash 284B MoE (free)";                NimModel = "nim-deepseek-v4-flash" }
  @{ Id = "nim-gemma-4-31b";      Label = "NIM - Google Gemma-4 31B (free)";                          NimModel = "nim-gemma-4-31b" }
  @{ Id = "nim-qwen3.5-397b";     Label = "NIM - Qwen 3.5 397B A17B (free)";                          NimModel = "nim-qwen3.5-397b-a17b" }
  @{ Id = "nim-qwen3-next-80b";   Label = "NIM - Qwen 3 Next 80B A3B (free)";                         NimModel = "nim-qwen3-next-80b-a3b" }
  @{ Id = "nim-qwen3-coder-480b"; Label = "NIM - Qwen 3 Coder 480B A35B (free)";                      NimModel = "nim-qwen3-coder-480b-a35b" }
)
$staticBaiOC = @(
  @{ Id = "bai-gpt-5-nano";        Label = "B.AI - GPT-5 Nano (OpenAI, agentic)" }
  @{ Id = "bai-gpt-5-mini";        Label = "B.AI - GPT-5 Mini (OpenAI, agentic)" }
  @{ Id = "bai-gpt-5.2";           Label = "B.AI - GPT-5.2 (OpenAI, agentic)" }
  @{ Id = "bai-gpt-5.4-nano";      Label = "B.AI - GPT-5.4 Nano (OpenAI, agentic)" }
  @{ Id = "bai-gpt-5.4-mini";      Label = "B.AI - GPT-5.4 Mini (OpenAI, agentic)" }
  @{ Id = "bai-gpt-5.4";           Label = "B.AI - GPT-5.4 (OpenAI, agentic)" }
  @{ Id = "bai-gpt-5.4-pro";       Label = "B.AI - GPT-5.4 Pro (OpenAI, agentic)" }
  @{ Id = "bai-gpt-5.5";           Label = "B.AI - GPT-5.5 (OpenAI, agentic)" }
  @{ Id = "bai-gpt-5.5-instant";   Label = "B.AI - GPT-5.5 Instant (OpenAI, agentic)" }
  @{ Id = "bai-claude-haiku-4.5";  Label = "B.AI - Claude Haiku 4.5 (Anthropic, agentic)" }
  @{ Id = "bai-claude-sonnet-4.5"; Label = "B.AI - Claude Sonnet 4.5 (Anthropic, agentic)" }
  @{ Id = "bai-claude-sonnet-4.6"; Label = "B.AI - Claude Sonnet 4.6 (Anthropic, agentic)" }
  @{ Id = "bai-claude-opus-4.5";   Label = "B.AI - Claude Opus 4.5 (Anthropic, agentic)" }
  @{ Id = "bai-claude-opus-4.6";   Label = "B.AI - Claude Opus 4.6 (Anthropic, agentic)" }
  @{ Id = "bai-claude-opus-4.7";   Label = "B.AI - Claude Opus 4.7 (Anthropic, agentic)" }
  @{ Id = "bai-claude-opus-4.8";   Label = "B.AI - Claude Opus 4.8 (Anthropic, agentic)" }
  @{ Id = "bai-deepseek-v4-pro";   Label = "B.AI - DeepSeek V4 Pro (agentic)" }
  @{ Id = "bai-deepseek-v4-flash"; Label = "B.AI - DeepSeek V4 Flash (agentic)" }
  @{ Id = "bai-gemini-3.1-pro";    Label = "B.AI - Gemini 3.1 Pro (Google, agentic)" }
  @{ Id = "bai-gemini-3.5-flash";  Label = "B.AI - Gemini 3.5 Flash (Google, agentic)" }
  @{ Id = "bai-glm-5";             Label = "B.AI - GLM-5 (Z.AI)" }
  @{ Id = "bai-glm-5.1";           Label = "B.AI - GLM-5.1 (Z.AI)" }
  @{ Id = "bai-kimi-k2.5";         Label = "B.AI - Kimi K2.5 (Moonshot)" }
  @{ Id = "bai-kimi-k2.6";         Label = "B.AI - Kimi K2.6 (Moonshot)" }
  @{ Id = "bai-minimax-m3";        Label = "B.AI - MiniMax M3 (agentic)" }
  @{ Id = "bai-minimax-m2.7";      Label = "B.AI - MiniMax M2.7 (fast)" }
)
$staticOrOC = @(
  @{ Id = "openrouter-deepseek-v4-flash"; Label = "OpenRouter - DeepSeek V4 Flash (free, text-only)" }
  @{ Id = "openrouter-qwen3-coder";       Label = "OpenRouter - Qwen3 Coder (free, text-only)" }
  @{ Id = "openrouter-nemotron";          Label = "OpenRouter - Nemotron 3 Super 120B (free, text-only)" }
  @{ Id = "openrouter-laguna";            Label = "OpenRouter - Poolside Laguna M.1 (free, text-only, coding)" }
)
$zaiMapOC = @{ "glm-5.1" = "zai-glm51"; "glm-4.7" = "zai-glm"; "glm-4.7-flash" = "zai-flash47" }
$zaiResOC = Build-GroupMenuItems -Provider "zai" -StaticItems $staticZaiOC -ApiKeyEnv "ZAI_API_KEY" -FetchScript "Get-ZaiCodingModelIdsFromApi" -IdPrefix "zai-" -ApiIdToPresetId $zaiMapOC -ForcedIds @("glm-4.7-flash")
$nimMap = @{ "mistralai/mistral-medium-3.5-128b" = "nim-mistral-medium"; "z-ai/glm-5.1" = "nim-glm51"; "stepfun-ai/step-3.5-flash" = "nim-step-3.5-flash"; "mistralai/mistral-large-3-675b-instruct-2512" = "nim-mistral-large-3"; "deepseek-ai/deepseek-v4-flash" = "nim-deepseek-v4-flash"; "deepseek-ai/deepseek-v4-pro" = "nim-deepseek-v4-pro"; "qwen/qwen3.5-397b-a17b" = "nim-qwen3.5-397b"; "qwen/qwen3-next-80b-a3b-instruct" = "nim-qwen3-next-80b"; "qwen/qwen3-coder-480b-a35b-instruct" = "nim-qwen3-coder-480b"; "google/gemma-4-31b-it" = "nim-gemma-4-31b"; "nvidia/llama-3.1-nemotron-70b-instruct" = "nim-nemotron-70b" }
$nimResOC = Build-GroupMenuItems -Provider "nim" -StaticItems $staticNimOC -ApiKeyEnv "NVIDIA_NIM_API_KEY" -FetchScript "Get-NvidiaNimModelIdsFromApi" -AgenticOnly -IdPrefix "nim-" -ApiIdToPresetId $nimMap -ForcedIds @("glm-4.7-flash")
$baiMapOC = @{}
$baiResOC = Build-GroupMenuItems -Provider "bai" -StaticItems $staticBaiOC -ApiKeyEnv "BAI_API_KEY" -FetchScript "Get-BaiNonPremiumModelIds" -IdPrefix "bai-" -ApiIdToPresetId $baiMapOC
$orMapOC = @{}
$orResOC = Build-GroupMenuItems -Provider "openrouter" -StaticItems $staticOrOC -ApiKeyEnv "OPENROUTER_API_KEY" -FetchScript "Get-OpenRouterFreeModelIdsFromApi" -IdPrefix "openrouter-" -ApiIdToPresetId $orMapOC
$groupHintsOC = @()
if ($zaiResOC.Source -eq "static")  { $groupHintsOC += "Z.AI: статический список" }
if ($nimResOC.Source -eq "static")  { $groupHintsOC += "NIM: статический список" }
if ($baiResOC.Source -eq "static")  { $groupHintsOC += "B.AI: статический список" }
if ($orResOC.Source -eq "static")   { $groupHintsOC += "OpenRouter: статический список" }
if ($groupHintsOC.Count -gt 0) {
  $updateHint = "$updateHint | ($($groupHintsOC -join ', '))"
}

$state = Get-LauncherState
$lastId = Resolve-ProfileFromState $state
$items = $script:Profiles
$startIdx = 0
if ($lastId) {
  for ($i = 0; $i -lt $items.Count; $i++) {
    if ($items[$i].Id -eq $lastId) { $startIdx = $i; break }
  }
} else {
  $startIdx = 1
}

while ($true) {
  $choice = Show-TuiFramedMenu -AppBrand "OpenCode" -Title "OpenCode - выбор провайдера" -Subtitle "Z.AI · NIM · OpenRouter · B.AI (OpenAI-compatible)" -Items $items -InitialIndex $startIdx -MaxVisible 20 -UpdateHint $updateHint
  if (-not $choice) {
    Write-Host "Отменено." -ForegroundColor Yellow
    exit 0
  }

  $profileId = [string]$choice.Id

  # Подменю для группы провайдера
  if ($profileId -like "group:*") {
    $groupKey = $profileId.Substring("group:".Length)
    $groupItems = $script:GroupMenus[$groupKey]
    if (-not $groupItems) {
      Write-Host "Не найдено подменю для группы: $groupKey" -ForegroundColor Red
      Start-Sleep -Seconds 2
      continue
    }
    $subTitle = switch ($groupKey) {
      "zai"        { "Z.AI Coding (paid) + GLM-4.7-Flash (free)" }
      "nim"        { "NVIDIA NIM - бесплатные agentic модели" }
      "openrouter" { "OpenRouter - бесплатные agentic модели" }
      "bai"        { "B.AI - https://api.b.ai/v1 (OpenAI-compatible)" }
      default      { "" }
    }
    $subChoice = Show-TuiFramedMenu -AppBrand "OpenCode" -Title ("OpenCode - {0}" -f $groupKey.ToUpper()) -Subtitle $subTitle -Items $groupItems -MaxVisible 16 -EscapeAction Back
    if ($null -eq $subChoice) { continue }
    if ($true -eq $subChoice.__menuBack) { continue }
    $profileId = [string]$subChoice.Id
    Save-LauncherState -ProfileId $profileId
    Invoke-OpenCodeProfile -ProfileId $profileId
    continue
  }

  if ($profileId -eq "custom-model") {
    $w = Invoke-LauncherCustomModelWizard -App "OpenCode"
    if ($null -eq $w) {
      Write-Host "Отменено." -ForegroundColor Yellow
      continue
    }
    if ($true -eq $w.__menuBack) { continue }
    $newId = switch ($w.Provider) {
      "zai" { "custom-opencode-zai" }
      "groq" { "custom-opencode-groq" }
      "openrouter" { "custom-opencode-openrouter" }
      "bai" { "custom-opencode-bai" }
      default { "custom-opencode-nim" }
    }
    Save-LauncherState -ProfileId $newId -Extra @{ customModelId = [string]$w.ModelId }
    Invoke-OpenCodeProfile -ProfileId $newId
    continue
  }

  if ($profileId -eq "native-login") {
    $opencodeExe = Resolve-OpenCodeExe
    if (-not $opencodeExe) {
      Write-Host "OpenCode CLI не найден. Установите: npm install -g opencode-ai@latest" -ForegroundColor Red
      Write-Host "Нажмите любую клавишу для возврата в меню…" -ForegroundColor Green
      $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
      continue
    }
    $loginItems = @(
      @{ Id = "providers-login"; Label = "Вход через провайдера (opencode providers login)" }
      @{ Id = "providers-list"; Label = "Показать подключённых провайдеров" }
      @{ Id = "vanilla"; Label = "Запуск OpenCode (ванильный запуск)" }
    )
    $loginChoice = Show-TuiFramedMenu -AppBrand "OpenCode" -Title "Нативный логин OpenCode" -Subtitle "Выберите действие" -Items $loginItems -MaxVisible 10
    if (-not $loginChoice) { continue }
    switch ([string]$loginChoice.Id) {
      "providers-login" {
        Clear-Host
        Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host "  OpenCode - вход через провайдера" -ForegroundColor Cyan
        Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  Выберите провайдера и следуйте инструкциям." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  Запуск..." -ForegroundColor Cyan
        & (Join-Path $PSScriptRoot "run-opencode-session.ps1") -ConfigPath "__SUBCOMMAND__" -ExePath $opencodeExe -SubCommand "providers login"
        Write-Host ""
        Write-Host "Нажмите любую клавишу для возврата в меню…" -ForegroundColor Green
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
      }
      "providers-list" {
        Clear-Host
        Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host "  OpenCode - подключённые провайдеры" -ForegroundColor Cyan
        Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host ""
        & (Join-Path $PSScriptRoot "run-opencode-session.ps1") -ConfigPath "__SUBCOMMAND__" -ExePath $opencodeExe -SubCommand "providers list"
        Write-Host ""
        Write-Host "Нажмите любую клавишу для возврата в меню…" -ForegroundColor Green
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
      }
      "vanilla" {
        Remove-Item -Path env:OPENCODE_CONFIG -ErrorAction SilentlyContinue
        Clear-Host
        Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host "  Запуск OpenCode (ванильный запуск)" -ForegroundColor Cyan
        Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  Команда: opencode" -ForegroundColor Yellow
        Write-Host ""
        & (Join-Path $PSScriptRoot "run-opencode-session.ps1") -ConfigPath "__VANILLA__"
        Write-Host ""
        Write-Host "Нажмите любую клавишу для возврата в меню…" -ForegroundColor Green
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
      }
    }
    continue
  }

  if ($profileId -eq "change-api-key") {
    Show-ApiKeyChangeMenu -AppBrand "OpenCode"
    continue
  }

  if ($profileId -eq "last") {
    $st = Get-LauncherState
    $profileId = Resolve-ProfileFromState $st
    if (-not $profileId) {
      Write-Host "Сохранённый профиль не найден. Выберите провайдер один раз." -ForegroundColor Red
      Write-Host "Нажмите любую клавишу..."
      $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
      continue
    }
  } else {
    Save-LauncherState -ProfileId $profileId
  }

  Invoke-OpenCodeProfile -ProfileId $profileId
  continue
}
