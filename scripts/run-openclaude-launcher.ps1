[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $false
. (Join-Path $PSScriptRoot "launcher-tui.ps1")
. (Join-Path $PSScriptRoot "launcher-api-keys.ps1")
. (Join-Path $PSScriptRoot "launcher-provider-models.ps1")
. (Join-Path $PSScriptRoot "launcher-custom-model-wizard.ps1")

function Resolve-OpenClaudeExe {
  return (Resolve-CommandOrInstall -CommandName "openclaude.cmd" -AltCommandName "openclaude" -NpmPackage "@gitlawb/openclaude" -DisplayName "OpenClaude")
}

function Set-OpenClaudeProviderProfile {
  <#
    OpenClaude (форк Claude Code) использует систему provider profiles.
    Global config: ~/.openclaude.json (НЕ ~/.openclaude/settings.json!).
    Там хранятся: providerProfiles[] + activeProviderProfileId.
    При старте вызывается applyProviderProfileToProcessEnv(activeProfile) — это
    ПОЛНОСТЬЮ перезаписывает process env (включая ANTHROPIC_*/OPENAI_*).

    .PARAMETER ProfileId
      Статический ID профиля (для UPSERT — повторный запуск обновит, не дублируя).
    .PARAMETER Provider
      "anthropic" — Anthropic-compatible (Z.AI, Anthropic).
      "openai" — OpenAI-compatible (NIM, B.AI, OpenRouter, Groq).
    .PARAMETER Name
      Human-readable имя профиля.
    .PARAMETER BaseUrl
      API endpoint.
    .PARAMETER ApiKey
      Ключ API.
    .PARAMETER Model
      Идентификатор модели.
  #>
  param(
    [Parameter(Mandatory)][string]$ProfileId,
    [Parameter(Mandatory)][string]$Provider,
    [Parameter(Mandatory)][string]$Name,
    [Parameter(Mandatory)][string]$BaseUrl,
    [Parameter(Mandatory)][string]$ApiKey,
    [Parameter(Mandatory)][string]$Model
  )

  # Global config: ~/.openclaude.json (НЕ ~/.openclaude/settings.json).
  # settings.json хранит user preferences; .openclaude.json хранит runtime state
  # including providerProfiles[] + activeProviderProfileId.
  $path = Join-Path $HOME ".openclaude.json"

  $obj = $null
  if (Test-Path -LiteralPath $path) {
    try { $obj = (Get-Content -Raw -LiteralPath $path | ConvertFrom-Json) } catch { $obj = $null }
  }
  if (-not $obj) { $obj = [pscustomobject]@{} }

  # UPSERT providerProfiles[]
  $profiles = @()
  if ($obj.PSObject.Properties['providerProfiles'] -and $obj.providerProfiles) {
    $profiles = @($obj.providerProfiles)
  }
  $profiles = @($profiles | Where-Object { $_.id -ne $ProfileId })

  $newProfile = [pscustomobject]@{
    id       = $ProfileId
    provider = $Provider
    name     = $Name
    baseUrl  = $BaseUrl
    apiKey   = $ApiKey
    model    = $Model
  }
  $profiles += $newProfile

  $obj | Add-Member -NotePropertyName providerProfiles -NotePropertyValue $profiles -Force
  $obj | Add-Member -NotePropertyName activeProviderProfileId -NotePropertyValue $ProfileId -Force

  $json = ($obj | ConvertTo-Json -Depth 10)
  [System.IO.File]::WriteAllText($path, $json, (New-Object System.Text.UTF8Encoding($false)))
}

function Clear-OpenClaudeProviderProfiles {
  <#
    Удаляет все providerProfiles и activeProviderProfileId из ~/.openclaude.json —
    OpenClaude возвращается к дефолтному Gitlawb Opengateway.
  #>
  param()
  $path = Join-Path $HOME ".openclaude.json"
  if (-not (Test-Path -LiteralPath $path)) { return }

  $obj = $null
  try { $obj = (Get-Content -Raw -LiteralPath $path | ConvertFrom-Json) } catch { return }
  if (-not $obj) { return }

  $obj | Add-Member -NotePropertyName providerProfiles -NotePropertyValue @() -Force
  $obj | Add-Member -NotePropertyName activeProviderProfileId -NotePropertyValue $null -Force

  $json = ($obj | ConvertTo-Json -Depth 10)
  [System.IO.File]::WriteAllText($path, $json, (New-Object System.Text.UTF8Encoding($false)))
}

# ─── Launcher state (quick start) ──────────────────────────────────────────
$StatePath = Join-Path $PSScriptRoot "openclaude-launcher-state.json"

function Get-LauncherState {
  if (-not (Test-Path -LiteralPath $StatePath)) { return $null }
  try {
    $raw = Get-Content -LiteralPath $StatePath -Raw -Encoding UTF8
    return ($raw | ConvertFrom-Json)
  } catch { return $null }
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
  foreach ($k in $Extra.Keys) { $obj[$k] = $Extra[$k] }
  ($obj | ConvertTo-Json -Compress) | Set-Content -LiteralPath $StatePath -Encoding UTF8
}

function Resolve-ProfileFromState($state) {
  if (-not $state -or [string]::IsNullOrWhiteSpace($state.profileId)) { return $null }
  $id = [string]$state.profileId
  $zaiIds = @("zai-glm51", "zai-glm47", "zai-flash47")
  $nimIds = @("nim-mistral-medium", "nim-glm51", "nim-step-3.5-flash", "nim-mistral-large-3",
    "nim-deepseek-v4-flash", "nim-gemma-4-31b", "nim-qwen3.5-397b", "nim-qwen3-next-80b", "nim-qwen3-coder-480b")
  $orIds = @("openrouter-laguna", "openrouter-qwen3-coder", "openrouter-deepseek-v4-flash", "openrouter-nemotron")
  if ($id -in $zaiIds -or $id -in $nimIds -or $id -in $orIds) { return $id }
  if ($id -like "bai-*") {
    $mid = $id.Substring("bai-".Length)
    if ($mid -and $script:PresetSpec.ContainsKey($id)) { return $id }
  }
  if ($id -eq "vanilla") { return $id }
  return $null
}

# ─── Главное меню (унифицированный формат) ──────────────────────────────────
$script:Profiles = @(
  @{ Id = "last";           Label = "Запустить с последними настройками (быстрый старт)" }
  @{ Id = "group:zai";      Label = "Z.AI - GLM-5.1 / GLM-4.7 / GLM-4.7-Flash" }
  @{ Id = "group:nim";      Label = "NVIDIA NIM - бесплатные agentic модели" }
  @{ Id = "group:bai";      Label = "B.AI - DeepSeek/MiniMax/GLM/Kimi/GPT (OpenAI-compatible)" }
  @{ Id = "group:openrouter"; Label = "OpenRouter - бесплатные agentic модели" }
  @{ Id = "custom-model";   Label = "Другая модель… → выбор провайдера и модели" }
  @{ Id = "native-login";   Label = "Нативный запуск (vanilla / Opengateway)" }
  @{ Id = "change-api-key"; Label = "Сменить ключ API провайдера" }
)

# Подменю для каждой группы провайдера
$script:GroupMenus = @{
  zai = @(
    @{ Id = "zai-glm51";   Label = "Z.AI - GLM-5.1 (paid, Anthropic-compatible, full tool support)" }
    @{ Id = "zai-glm47";   Label = "Z.AI - GLM-4.7 (paid, Anthropic-compatible, tool support)" }
    @{ Id = "zai-flash47"; Label = "Z.AI - GLM-4.7-Flash (free, Anthropic-compatible)" }
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
  openrouter = @(
    @{ Id = "openrouter-deepseek-v4-flash"; Label = "OpenRouter - DeepSeek V4 Flash (free, text-only)" }
    @{ Id = "openrouter-qwen3-coder";       Label = "OpenRouter - Qwen3 Coder (free, text-only)" }
    @{ Id = "openrouter-nemotron";          Label = "OpenRouter - Nemotron 3 Super 120B (free, text-only)" }
    @{ Id = "openrouter-laguna";            Label = "OpenRouter - Poolside Laguna M.1 (free, text-only, coding)" }
  )
}

# Характеристики моделей.
# Z.AI использует Anthropic-совместимый transport (env ANTHROPIC_*).
# NIM/BAI/OpenRouter — OpenAI-compatible (env OPENAI_*). Для них также требуется
# один раз запустить /provider внутри OpenClaude и выбрать соответствующий провайдер.
$script:ZaiPresetSpec = @{
  "zai-glm51"   = @{ Model = "glm-5.1" }
  "zai-glm47"   = @{ Model = "glm-4.7" }
  "zai-flash47" = @{ Model = "glm-4.7-flash" }
}

$script:PresetSpec = @{
  "nim-mistral-medium"   = @{ Base = "https://integrate.api.nvidia.com/v1"; Model = "mistralai/mistral-medium-3.5-128b";          KeyEnv = "NVIDIA_NIM_API_KEY" }
  "nim-glm51"            = @{ Base = "https://integrate.api.nvidia.com/v1"; Model = "z-ai/glm-5.1";                                KeyEnv = "NVIDIA_NIM_API_KEY" }
  "nim-step-3.5-flash"   = @{ Base = "https://integrate.api.nvidia.com/v1"; Model = "stepfun-ai/step-3.5-flash";                  KeyEnv = "NVIDIA_NIM_API_KEY" }
  "nim-mistral-large-3"  = @{ Base = "https://integrate.api.nvidia.com/v1"; Model = "mistralai/mistral-large-3-675b-instruct-2512"; KeyEnv = "NVIDIA_NIM_API_KEY" }
  "nim-deepseek-v4-flash" = @{ Base = "https://integrate.api.nvidia.com/v1"; Model = "deepseek-ai/deepseek-v4-flash";             KeyEnv = "NVIDIA_NIM_API_KEY" }
  "nim-gemma-4-31b"      = @{ Base = "https://integrate.api.nvidia.com/v1"; Model = "google/gemma-4-31b-it";                      KeyEnv = "NVIDIA_NIM_API_KEY" }
  "nim-qwen3.5-397b"     = @{ Base = "https://integrate.api.nvidia.com/v1"; Model = "qwen/qwen3.5-397b-a17b";                     KeyEnv = "NVIDIA_NIM_API_KEY" }
  "nim-qwen3-next-80b"   = @{ Base = "https://integrate.api.nvidia.com/v1"; Model = "qwen/qwen3-next-80b-a3b-instruct";           KeyEnv = "NVIDIA_NIM_API_KEY" }
  "nim-qwen3-coder-480b" = @{ Base = "https://integrate.api.nvidia.com/v1"; Model = "qwen/qwen3-coder-480b-a35b-instruct";         KeyEnv = "NVIDIA_NIM_API_KEY" }
  "bai-gpt-5-nano"        = @{ Base = "https://api.b.ai/v1"; Model = "gpt-5-nano";        KeyEnv = "BAI_API_KEY" }
  "bai-gpt-5-mini"        = @{ Base = "https://api.b.ai/v1"; Model = "gpt-5-mini";        KeyEnv = "BAI_API_KEY" }
  "bai-gpt-5.2"           = @{ Base = "https://api.b.ai/v1"; Model = "gpt-5.2";           KeyEnv = "BAI_API_KEY" }
  "bai-gpt-5.4-nano"      = @{ Base = "https://api.b.ai/v1"; Model = "gpt-5.4-nano";      KeyEnv = "BAI_API_KEY" }
  "bai-gpt-5.4-mini"      = @{ Base = "https://api.b.ai/v1"; Model = "gpt-5.4-mini";      KeyEnv = "BAI_API_KEY" }
  "bai-gpt-5.4"           = @{ Base = "https://api.b.ai/v1"; Model = "gpt-5.4";           KeyEnv = "BAI_API_KEY" }
  "bai-gpt-5.4-pro"       = @{ Base = "https://api.b.ai/v1"; Model = "gpt-5.4-pro";       KeyEnv = "BAI_API_KEY" }
  "bai-gpt-5.5"           = @{ Base = "https://api.b.ai/v1"; Model = "gpt-5.5";           KeyEnv = "BAI_API_KEY" }
  "bai-gpt-5.5-instant"   = @{ Base = "https://api.b.ai/v1"; Model = "gpt-5.5-instant";   KeyEnv = "BAI_API_KEY" }
  "bai-claude-haiku-4.5"  = @{ Base = "https://api.b.ai/v1"; Model = "claude-haiku-4.5";  KeyEnv = "BAI_API_KEY" }
  "bai-claude-sonnet-4.5" = @{ Base = "https://api.b.ai/v1"; Model = "claude-sonnet-4.5"; KeyEnv = "BAI_API_KEY" }
  "bai-claude-sonnet-4.6" = @{ Base = "https://api.b.ai/v1"; Model = "claude-sonnet-4.6"; KeyEnv = "BAI_API_KEY" }
  "bai-claude-opus-4.5"   = @{ Base = "https://api.b.ai/v1"; Model = "claude-opus-4.5";   KeyEnv = "BAI_API_KEY" }
  "bai-claude-opus-4.6"   = @{ Base = "https://api.b.ai/v1"; Model = "claude-opus-4.6";   KeyEnv = "BAI_API_KEY" }
  "bai-claude-opus-4.7"   = @{ Base = "https://api.b.ai/v1"; Model = "claude-opus-4.7";   KeyEnv = "BAI_API_KEY" }
  "bai-claude-opus-4.8"   = @{ Base = "https://api.b.ai/v1"; Model = "claude-opus-4.8";   KeyEnv = "BAI_API_KEY" }
  "bai-deepseek-v4-pro"   = @{ Base = "https://api.b.ai/v1"; Model = "deepseek-v4-pro";   KeyEnv = "BAI_API_KEY" }
  "bai-deepseek-v4-flash" = @{ Base = "https://api.b.ai/v1"; Model = "deepseek-v4-flash"; KeyEnv = "BAI_API_KEY" }
  "bai-gemini-3.1-pro"    = @{ Base = "https://api.b.ai/v1"; Model = "gemini-3.1-pro";    KeyEnv = "BAI_API_KEY" }
  "bai-gemini-3.5-flash"  = @{ Base = "https://api.b.ai/v1"; Model = "gemini-3.5-flash";  KeyEnv = "BAI_API_KEY" }
  "bai-glm-5"             = @{ Base = "https://api.b.ai/v1"; Model = "glm-5";             KeyEnv = "BAI_API_KEY" }
  "bai-glm-5.1"           = @{ Base = "https://api.b.ai/v1"; Model = "glm-5.1";           KeyEnv = "BAI_API_KEY" }
  "bai-kimi-k2.5"         = @{ Base = "https://api.b.ai/v1"; Model = "kimi-k2.5";         KeyEnv = "BAI_API_KEY" }
  "bai-kimi-k2.6"         = @{ Base = "https://api.b.ai/v1"; Model = "kimi-k2.6";         KeyEnv = "BAI_API_KEY" }
  "bai-minimax-m3"        = @{ Base = "https://api.b.ai/v1"; Model = "minimax-m3";        KeyEnv = "BAI_API_KEY" }
  "bai-minimax-m2.7"      = @{ Base = "https://api.b.ai/v1"; Model = "minimax-m2.7";      KeyEnv = "BAI_API_KEY" }
  "openrouter-deepseek-v4-flash" = @{ Base = "https://openrouter.ai/api/v1"; Model = "deepseek/deepseek-chat-v3.1:free"; KeyEnv = "OPENROUTER_API_KEY" }
  "openrouter-qwen3-coder"       = @{ Base = "https://openrouter.ai/api/v1"; Model = "qwen/qwen3-coder:free";           KeyEnv = "OPENROUTER_API_KEY" }
  "openrouter-nemotron"          = @{ Base = "https://openrouter.ai/api/v1"; Model = "nvidia/nemotron-3-super-120b-a12b:free"; KeyEnv = "OPENROUTER_API_KEY" }
  "openrouter-laguna"            = @{ Base = "https://openrouter.ai/api/v1"; Model = "poolside/laguna-m.1:free";         KeyEnv = "OPENROUTER_API_KEY" }
}

function Invoke-OpenClaudeZaiPreset {
  param([string]$PresetId)
  $zSpec = $script:ZaiPresetSpec[$PresetId]
  if (-not $zSpec) { throw "Неизвестный Z.AI preset: $PresetId" }

  $key = [Environment]::GetEnvironmentVariable("ZAI_API_KEY", "User")
  if ([string]::IsNullOrWhiteSpace($key) -or $key -eq "__SET_ME__") { $key = $env:ZAI_API_KEY }
  if ([string]::IsNullOrWhiteSpace($key) -or $key -eq "__SET_ME__") {
    $key = Resolve-ApiKeyOrPrompt -CurrentKey $key -ProviderName "Z.AI" -HelpUrl "https://console.z.ai/"
  }

  # Z.AI работает через Anthropic-совместимый transport — это работает с OpenClaude
  # без /provider setup, т.к. OpenClaude (форк Claude Code) понимает ANTHROPIC_*.
  Remove-Item Env:CLAUDE_CODE_USE_OPENAI, Env:OPENAI_BASE_URL, Env:OPENAI_MODEL, Env:OPENAI_API_KEY -ErrorAction SilentlyContinue
  $env:ANTHROPIC_API_KEY = $key
  Remove-Item Env:ANTHROPIC_AUTH_TOKEN -ErrorAction SilentlyContinue
  $env:ANTHROPIC_BASE_URL = "https://api.z.ai/api/anthropic"
  $env:API_TIMEOUT_MS = "3000000"
  $env:ANTHROPIC_DEFAULT_OPUS_MODEL = $zSpec.Model
  $env:ANTHROPIC_DEFAULT_SONNET_MODEL = $zSpec.Model
  $env:ANTHROPIC_DEFAULT_HAIKU_MODEL = $zSpec.Model

  # Записываем provider profile в ~/.openclaude/settings.json.
  # OpenClaude при старте вызывает applyProviderProfileToProcessEnv(profile),
  # что полностью переопределяет process env. Поэтому profiles > env vars.
  Set-OpenClaudeProviderProfile `
    -ProfileId "zai-$($zSpec.Model)-anthropic" `
    -Provider  "anthropic" `
    -Name      "Z.AI $($zSpec.Model)" `
    -BaseUrl   "https://api.z.ai/api/anthropic" `
    -ApiKey    $key `
    -Model     $zSpec.Model

  $exe = Resolve-OpenClaudeExe
  if (-not $exe) { throw "OpenClaude CLI не найден. Установите: npm install -g @gitlawb/openclaude" }

  Clear-Host
  Write-Host "Запуск OpenClaude (Z.AI)..." -ForegroundColor Cyan
  Write-Host "Model: $($zSpec.Model) | Endpoint: https://api.z.ai/api/anthropic" -ForegroundColor DarkGray
  & (Join-Path $PSScriptRoot "run-openclaude-session.ps1") -ExePath $exe -ArgumentsJson '["--bare"]'
}

function Invoke-OpenClaudeOpenAIPreset {
  param([string]$PresetId)
  $spec = $script:PresetSpec[$PresetId]
  if (-not $spec) { throw "Неизвестный preset: $PresetId" }

  $key = [Environment]::GetEnvironmentVariable($spec.KeyEnv, "User")
  if ([string]::IsNullOrWhiteSpace($key) -or $key -eq "__SET_ME__") { $key = (Get-ChildItem env: | Where-Object { $_.Name -eq $spec.KeyEnv } | Select-Object -First 1).Value }
  if ([string]::IsNullOrWhiteSpace($key) -or $key -eq "__SET_ME__") {
    $providerName = switch -Wildcard ($spec.KeyEnv) {
      "NVIDIA*"     { "NVIDIA NIM" }
      "BAI*"        { "B.AI" }
      "OPENROUTER*" { "OpenRouter" }
      default       { $spec.KeyEnv }
    }
    $helpUrl = switch ($providerName) {
      "NVIDIA NIM"  { "https://build.nvidia.com/api-key" }
      "B.AI"        { "https://chat.b.ai/key" }
      "OpenRouter"  { "https://openrouter.ai/settings/keys" }
      default       { "" }
    }
    $key = Resolve-ApiKeyOrPrompt -CurrentKey $key -ProviderName $providerName -HelpUrl $helpUrl
  }

  # OpenAI-compatible env. ВАЖНО: OpenClaude Gitlawb использует собственный
  # конфиг провайдера; для активации этих env необходимо один раз запустить
  # /provider внутри CLI и выбрать "OpenAI" (или соответствующий провайдер).
  Remove-Item Env:ANTHROPIC_BASE_URL, Env:ANTHROPIC_API_KEY, Env:ANTHROPIC_AUTH_TOKEN -ErrorAction SilentlyContinue
  Remove-Item Env:ANTHROPIC_DEFAULT_OPUS_MODEL, Env:ANTHROPIC_DEFAULT_SONNET_MODEL, Env:ANTHROPIC_DEFAULT_HAIKU_MODEL -ErrorAction SilentlyContinue
  $env:CLAUDE_CODE_USE_OPENAI = "1"
  $env:OPENAI_API_KEY = $key
  $env:OPENAI_BASE_URL = $spec.Base
  $env:OPENAI_MODEL = $spec.Model

  # Записываем provider profile (OpenAI-compat) в ~/.openclaude/settings.json.
  # OpenClaude при старте вызывает applyProviderProfileToProcessEnv(profile),
  # что автоматически выставит CLAUDE_CODE_USE_OPENAI + OPENAI_* env vars.
  $profileName = "$providerName $($spec.Model)"
  Set-OpenClaudeProviderProfile `
    -ProfileId "$PresetId-openai" `
    -Provider  "openai" `
    -Name      $profileName `
    -BaseUrl   $spec.Base `
    -ApiKey    $key `
    -Model     $spec.Model

  $exe = Resolve-OpenClaudeExe
  if (-not $exe) { throw "OpenClaude CLI не найден. Установите: npm install -g @gitlawb/openclaude" }

  Clear-Host
  Write-Host "Запуск OpenClaude..." -ForegroundColor Cyan
  Write-Host "Provider: $($spec.Base) | Model: $($spec.Model)" -ForegroundColor DarkGray
  Write-Host "Provider profile записан в ~/.openclaude/settings.json" -ForegroundColor DarkGray
  & (Join-Path $PSScriptRoot "run-openclaude-session.ps1") -ExePath $exe -ArgumentsJson '["--bare"]'
}

# Главное меню loop
$updateHint = Test-LauncherUpdates -AgentNpmPackage "@gitlawb/openclaude" -AgentDisplayName "OpenClaude"

# Build provider group menus dynamically from API (with static fallback).
$staticZaiOC = @(
  @{ Id = "zai-glm51";   Label = "Z.AI - GLM-5.1 (paid, Anthropic-compatible, full tool support)" }
  @{ Id = "zai-glm47";   Label = "Z.AI - GLM-4.7 (paid, Anthropic-compatible, tool support)" }
  @{ Id = "zai-flash47"; Label = "Z.AI - GLM-4.7-Flash (free, Anthropic-compatible)" }
)
$staticNimOC = @(
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
$zaiMapOC = @{ "glm-5.1" = "zai-glm51"; "glm-4.7" = "zai-glm47"; "glm-4.7-flash" = "zai-flash47" }
$zaiResOC = Build-GroupMenuItems -Provider "zai" -StaticItems $staticZaiOC -ApiKeyEnv "ZAI_API_KEY" -FetchScript "Get-ZaiCodingModelIdsFromApi" -IdPrefix "zai-" -ApiIdToPresetId $zaiMapOC -ForcedIds @("glm-4.7-flash")
$nimResOC = Build-GroupMenuItems -Provider "nim" -StaticItems $staticNimOC -ApiKeyEnv "NVIDIA_NIM_API_KEY" -FetchScript "Get-NvidiaNimModelIdsFromApi" -AgenticOnly -IdPrefix "nim-"
$baiResOC = Build-GroupMenuItems -Provider "bai" -StaticItems $staticBaiOC -ApiKeyEnv "BAI_API_KEY" -FetchScript "Get-BaiModelIdsFromApi" -IdPrefix "bai-"
$orResOC  = Build-GroupMenuItems -Provider "openrouter" -StaticItems $staticOrOC -ApiKeyEnv "OPENROUTER_API_KEY" -FetchScript "Get-OpenRouterFreeModelIdsFromApi" -IdPrefix "openrouter-"
$script:GroupMenus = @{
  zai        = $zaiResOC.Items
  nim        = $nimResOC.Items
  bai        = $baiResOC.Items
  openrouter = $orResOC.Items
}
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
    if ($items[$i].Id -eq "last") { $startIdx = $i; break }
  }
} else {
  $startIdx = 1
}

while ($true) {
  $choice = Show-TuiFramedMenu -AppBrand "OpenClaude" -Title "OpenClaude - выбор профиля" -Subtitle "Z.AI · NIM · B.AI · OpenRouter — provider profiles" -Items $items -InitialIndex $startIdx -MaxVisible 20 -UpdateHint $updateHint
  if (-not $choice) {
    Write-Host "Отменено." -ForegroundColor Yellow
    exit 0
  }

  $profileId = [string]$choice.Id

  if ($profileId -like "group:*") {
    $groupKey = $profileId.Substring("group:".Length)
    $groupItems = $script:GroupMenus[$groupKey]
    if (-not $groupItems) {
      Write-Host "Не найдено подменю для группы: $groupKey" -ForegroundColor Red
      Start-Sleep -Seconds 2
      continue
    }
    $subTitle = switch ($groupKey) {
      "zai"        { "Z.AI - Anthropic-compatible" }
      "nim"        { "NVIDIA NIM - OpenAI-compatible" }
      "bai"        { "B.AI - https://api.b.ai/v1" }
      "openrouter" { "OpenRouter - бесплатные модели" }
      default      { "" }
    }
    $subChoice = Show-TuiFramedMenu -AppBrand "OpenClaude" -Title ("OpenClaude - {0}" -f $groupKey.ToUpper()) -Subtitle $subTitle -Items $groupItems -MaxVisible 14 -EscapeAction Back
    if ($null -eq $subChoice) { continue }
    if ($true -eq $subChoice.__menuBack) { continue }
    $subId = [string]$subChoice.Id

    if ($groupKey -eq "zai") {
      Save-LauncherState -ProfileId $subId
      try { Invoke-OpenClaudeZaiPreset -PresetId $subId } catch { Write-Host "" }
    } else {
      Save-LauncherState -ProfileId $subId
      try { Invoke-OpenClaudeOpenAIPreset -PresetId $subId } catch { Write-Host "" }
    }
    continue
  }

  if ($profileId -eq "custom-model") {
    $w = Invoke-LauncherCustomModelWizard -App "OpenCode"
    if ($null -eq $w) {
      Write-Host "Отменено." -ForegroundColor Yellow
      continue
    }
    if ($true -eq $w.__menuBack) { continue }
    $mid = [string]$w.ModelId

    # Z.AI → Anthropic transport; остальные → OpenAI-compatible
    if ($w.Provider -eq "zai") {
      $key = [Environment]::GetEnvironmentVariable("ZAI_API_KEY", "User")
      if ([string]::IsNullOrWhiteSpace($key) -or $key -eq "__SET_ME__") { $key = $env:ZAI_API_KEY }
      if ([string]::IsNullOrWhiteSpace($key) -or $key -eq "__SET_ME__") {
        $key = Resolve-ApiKeyOrPrompt -CurrentKey $key -ProviderName "Z.AI" -HelpUrl "https://console.z.ai/"
      }
  Remove-Item Env:CLAUDE_CODE_USE_OPENAI, Env:OPENAI_BASE_URL, Env:OPENAI_MODEL, Env:OPENAI_API_KEY, Env:OPENGATEWAY_API_KEY -ErrorAction SilentlyContinue
      $env:ANTHROPIC_API_KEY = $key
      Remove-Item Env:ANTHROPIC_AUTH_TOKEN -ErrorAction SilentlyContinue
      $env:ANTHROPIC_BASE_URL = "https://api.z.ai/api/anthropic"
      $env:API_TIMEOUT_MS = "3000000"
      $env:ANTHROPIC_DEFAULT_OPUS_MODEL = $mid
      $env:ANTHROPIC_DEFAULT_SONNET_MODEL = $mid
      $env:ANTHROPIC_DEFAULT_HAIKU_MODEL = $mid

      Set-OpenClaudeProviderProfile `
        -ProfileId "zai-custom-$mid-anthropic" `
        -Provider  "anthropic" `
        -Name      "Z.AI $mid" `
        -BaseUrl   "https://api.z.ai/api/anthropic" `
        -ApiKey    $key `
        -Model     $mid

      $exe = Resolve-OpenClaudeExe
      if (-not $exe) { throw "OpenClaude CLI не найден. Установите: npm install -g @gitlawb/openclaude" }
      Clear-Host
      Write-Host "Запуск OpenClaude (Z.AI custom)..." -ForegroundColor Cyan
      Write-Host "Model: $mid | Endpoint: https://api.z.ai/api/anthropic" -ForegroundColor DarkGray
      & (Join-Path $PSScriptRoot "run-openclaude-session.ps1") -ExePath $exe -ArgumentsJson '["--bare"]'
    } else {
      $spec = switch ($w.Provider) {
        "nim"        { @{ Base = "https://integrate.api.nvidia.com/v1"; KeyEnv = "NVIDIA_NIM_API_KEY" } }
        "openrouter" { @{ Base = "https://openrouter.ai/api/v1";          KeyEnv = "OPENROUTER_API_KEY" } }
        "bai"        { @{ Base = "https://api.b.ai/v1";                    KeyEnv = "BAI_API_KEY" } }
        "groq"       { @{ Base = "https://api.groq.com/openai/v1";         KeyEnv = "GROQ_API_KEY" } }
        default      { @{ Base = "https://integrate.api.nvidia.com/v1";    KeyEnv = "NVIDIA_NIM_API_KEY" } }
      }
      $key = [Environment]::GetEnvironmentVariable($spec.KeyEnv, "User")
      if ([string]::IsNullOrWhiteSpace($key) -or $key -eq "__SET_ME__") { $key = (Get-ChildItem env: | Where-Object { $_.Name -eq $spec.KeyEnv } | Select-Object -First 1).Value }
      $providerName = switch ($w.Provider) { "nim" { "NVIDIA NIM" }; "bai" { "B.AI" }; "openrouter" { "OpenRouter" }; "groq" { "Groq" }; default { "Provider" } }
      if ([string]::IsNullOrWhiteSpace($key) -or $key -eq "__SET_ME__") {
        $helpUrl = switch ($w.Provider) { "nim" { "https://build.nvidia.com/api-key" }; "bai" { "https://chat.b.ai/key" }; "openrouter" { "https://openrouter.ai/settings/keys" }; "groq" { "https://console.groq.com/keys" }; default { "" } }
        $key = Resolve-ApiKeyOrPrompt -CurrentKey $key -ProviderName $providerName -HelpUrl $helpUrl
      }
      Remove-Item Env:ANTHROPIC_BASE_URL, Env:ANTHROPIC_API_KEY, Env:ANTHROPIC_AUTH_TOKEN -ErrorAction SilentlyContinue
      Remove-Item Env:ANTHROPIC_DEFAULT_OPUS_MODEL, Env:ANTHROPIC_DEFAULT_SONNET_MODEL, Env:ANTHROPIC_DEFAULT_HAIKU_MODEL -ErrorAction SilentlyContinue
      $env:CLAUDE_CODE_USE_OPENAI = "1"
      $env:OPENAI_API_KEY = $key
      $env:OPENAI_BASE_URL = $spec.Base
      $env:OPENAI_MODEL = $mid

      $profileId = "$($w.Provider)-custom-$mid-openai"
      Set-OpenClaudeProviderProfile `
        -ProfileId $profileId `
        -Provider  "openai" `
        -Name      "$providerName $mid" `
        -BaseUrl   $spec.Base `
        -ApiKey    $key `
        -Model     $mid

      $exe = Resolve-OpenClaudeExe
      if (-not $exe) { throw "OpenClaude CLI не найден. Установите: npm install -g @gitlawb/openclaude" }
      Clear-Host
      Write-Host "Запуск OpenClaude..." -ForegroundColor Cyan
      Write-Host "Provider: $($spec.Base) | Model: $mid" -ForegroundColor DarkGray
      Write-Host "Provider profile записан в ~/.openclaude.json" -ForegroundColor DarkGray
      & (Join-Path $PSScriptRoot "run-openclaude-session.ps1") -ExePath $exe -ArgumentsJson '["--bare"]'
    }
    continue
  }

  if ($profileId -eq "native-login") {
    $exe = Resolve-OpenClaudeExe
    if (-not $exe) {
      Write-Host "OpenClaude CLI не найден." -ForegroundColor Red
      Write-Host "Нажмите любую клавишу для возврата в меню…" -ForegroundColor Green
      $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
      continue
    }
    $loginItems = @(
      @{ Id = "vanilla"; Label = "Запуск OpenClaude (vanilla / Gitlawb Opengateway)" }
    )
    $loginChoice = Show-TuiFramedMenu -AppBrand "OpenClaude" -Title "Нативный запуск OpenClaude" -Subtitle "Выберите действие" -Items $loginItems -MaxVisible 10
    if (-not $loginChoice) { continue }
    switch ([string]$loginChoice.Id) {
      "vanilla" {
        Remove-Item Env:OPENAI_BASE_URL, Env:OPENAI_MODEL, Env:CLAUDE_CODE_USE_OPENAI, Env:OPENAI_API_KEY, Env:ANTHROPIC_BASE_URL, Env:ANTHROPIC_API_KEY, Env:ANTHROPIC_AUTH_TOKEN, Env:ANTHROPIC_DEFAULT_OPUS_MODEL, Env:ANTHROPIC_DEFAULT_SONNET_MODEL, Env:ANTHROPIC_DEFAULT_HAIKU_MODEL -ErrorAction SilentlyContinue
        Restore-ProcessEnvFromUser -Key "OPENGATEWAY_API_KEY"
        Restore-ProcessEnvFromUser -Key "OPENAI_API_KEY"
        Clear-OpenClaudeProviderProfiles
        Save-LauncherState -ProfileId "vanilla"
        Clear-Host
        Write-Host "Запуск OpenClaude (vanilla)..." -ForegroundColor Cyan
        & (Join-Path $PSScriptRoot "run-openclaude-session.ps1") -ExePath $exe -ArgumentsJson '["--bare"]'
      }
    }
    continue
  }

  if ($profileId -eq "change-api-key") {
    Show-ApiKeyChangeMenu -AppBrand "OpenClaude"
    continue
  }

  if ($profileId -eq "last") {
    $st = Get-LauncherState
    $profileId = Resolve-ProfileFromState $st
    if (-not $profileId) {
      Write-Host "Сохранённый профиль не найден. Выберите провайдер один раз." -ForegroundColor Red
      Write-Host "Нажмите любую клавишу..." -ForegroundColor DarkGray
      $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
      continue
    }
  } else {
    Save-LauncherState -ProfileId $profileId
  }

  # Dispatch profile execution
  if ($profileId -in @("zai-glm51", "zai-glm47", "zai-flash47")) {
    try { Invoke-OpenClaudeZaiPreset -PresetId $profileId } catch { Write-Host "" }
  } elseif ($script:PresetSpec.ContainsKey($profileId)) {
    try { Invoke-OpenClaudeOpenAIPreset -PresetId $profileId } catch { Write-Host "" }
  } elseif ($profileId -eq "vanilla") {
    $exe = Resolve-OpenClaudeExe
    if ($exe) {
      Remove-Item Env:OPENAI_BASE_URL, Env:OPENAI_MODEL, Env:CLAUDE_CODE_USE_OPENAI, Env:OPENAI_API_KEY, Env:ANTHROPIC_BASE_URL, Env:ANTHROPIC_API_KEY, Env:ANTHROPIC_AUTH_TOKEN -ErrorAction SilentlyContinue
      Restore-ProcessEnvFromUser -Key "OPENGATEWAY_API_KEY"
      Clear-OpenClaudeProviderProfiles
      Clear-Host
      Write-Host "Запуск OpenClaude (vanilla)..." -ForegroundColor Cyan
      & (Join-Path $PSScriptRoot "run-openclaude-session.ps1") -ExePath $exe -ArgumentsJson '["--bare"]'
    }
  }
  continue
}
