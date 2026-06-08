[CmdletBinding()]
param(
  [switch]$Quick
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "ensure-streaming-friendly-terminal.ps1")
. (Join-Path $PSScriptRoot "launcher-tui.ps1")
. (Join-Path $PSScriptRoot "launcher-provider-models.ps1")
. (Join-Path $PSScriptRoot "launcher-custom-model-wizard.ps1")
. (Join-Path $PSScriptRoot "launcher-api-keys.ps1")

$StatePath = Join-Path $PSScriptRoot "qwen-code-launcher-state.json"

function Resolve-QwenExe {
  return (Resolve-CommandOrInstall -CommandName "qwen.cmd" -AltCommandName "qwen" -NpmPackage "qwen-code" -DisplayName "Qwen Code")
}

function Invoke-CliCommand {
  param(
    [Parameter(Mandatory = $true)][string]$ExePath,
    [string[]]$Arguments = @()
  )
  if ($ExePath -like "*.cmd" -or $ExePath -like "*.bat") {
    $allArgs = @("/c", $ExePath) + $Arguments
    & cmd.exe @allArgs
  } else {
    if ($Arguments.Count -gt 0) {
      & $ExePath @Arguments
    } else {
      & $ExePath
    }
  }
}

$script:Profiles = @(
  @{
    Id          = "last"
    Label       = "Запустить с последними настройками (быстрый старт)"
    Description = "Пропуск меню: последний выбранный профиль"
  }
  @{
    Id          = "group:zai"
    Label       = "Z.AI - модели (GLM-5.1 / GLM-4.7 / GLM-4.7-Flash)"
  }
  @{
    Id          = "group:nim"
    Label       = "NVIDIA NIM - 9 бесплатных agentic моделей"
  }
  @{
    Id          = "group:bai"
    Label       = "B.AI - DeepSeek/MiniMax/GLM/Kimi/GPT (OpenAI-compatible)"
  }
  @{
    Id          = "group:openrouter"
    Label       = "OpenRouter - бесплатные модели (text-only)"
  }
  @{
    Id          = "custom-model"
    Label       = "Другая модель… → выбор провайдера и модели"
  }
  @{
    Id          = "native-login"
    Label       = "Нативный логин (Qwen OAuth / Coding Plan)"
  }
  @{
    Id          = "change-api-key"
    Label       = "Сменить ключ API провайдера"
  }
)

# Характеристики B.AI моделей (context window, max_tokens) для run-qwen-code-dynamic.ps1.
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
  # OpenRouter убран из пресетов — используйте «Другая модель…» → OpenRouter.
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
  if ($id -in @(
      "nim-mistral-medium", "nim-glm51", "nim-step-3.5-flash", "nim-mistral-large-3",
      "nim-deepseek-v4-flash", "nim-gemma-4-31b", "nim-qwen3.5-397b", "nim-qwen3-next-80b", "nim-qwen3-coder-480b",
      "zai-glm", "zai-glm51", "zai-flash47", "zai-flash45",
      "openrouter-nemotron", "openrouter-laguna", "openrouter-deepseek-v4-flash", "openrouter-qwen3-coder",
      "custom-qwen-zai", "custom-qwen-zai-general", "custom-qwen-nim", "custom-qwen-groq", "custom-qwen-openrouter", "custom-qwen-bai"
    )) { return $id }
  # B.AI: динамически проверяем по agentic-списку
  if ($id -like "bai-*") {
    $mid = $id.Substring("bai-".Length)
    if ($mid -and ($script:BaiModelSpec.ContainsKey($mid))) { return $id }
  }
  return $null
}

function Invoke-QwenProfile {
  param([string]$ProfileId)

  switch ($ProfileId) {
    "nim-mistral-medium" {
      & (Join-Path $PSScriptRoot "run-qwen-code-nvidia-nim.ps1") -Model "mistralai/mistral-medium-3.5-128b"
      return
    }
    "nim-glm51" {
      & (Join-Path $PSScriptRoot "run-qwen-code-nvidia-nim.ps1") -Model "z-ai/glm-5.1"
      return
    }
    "nim-step-3.5-flash" {
      & (Join-Path $PSScriptRoot "run-qwen-code-nvidia-nim.ps1") -Model "stepfun-ai/step-3.5-flash"
      return
    }
    "nim-mistral-large-3" {
      & (Join-Path $PSScriptRoot "run-qwen-code-nvidia-nim.ps1") -Model "mistralai/mistral-large-3-675b-instruct-2512"
      return
    }
    "nim-deepseek-v4-flash" {
      & (Join-Path $PSScriptRoot "run-qwen-code-nvidia-nim.ps1") -Model "deepseek-ai/deepseek-v4-flash"
      return
    }
    "nim-gemma-4-31b" {
      & (Join-Path $PSScriptRoot "run-qwen-code-nvidia-nim.ps1") -Model "google/gemma-4-31b-it"
      return
    }
    "nim-qwen3.5-397b" {
      & (Join-Path $PSScriptRoot "run-qwen-code-nvidia-nim.ps1") -Model "qwen/qwen3.5-397b-a17b"
      return
    }
    "nim-qwen3-next-80b" {
      & (Join-Path $PSScriptRoot "run-qwen-code-nvidia-nim.ps1") -Model "qwen/qwen3-next-80b-a3b-instruct"
      return
    }
    "nim-qwen3-coder-480b" {
      & (Join-Path $PSScriptRoot "run-qwen-code-nvidia-nim.ps1") -Model "qwen/qwen3-coder-480b-a35b-instruct"
      return
    }
    "zai-glm" {
      & (Join-Path $PSScriptRoot "run-qwen-code-cloud-zai-glm47.ps1")
      return
    }
    "zai-glm51" {
      & (Join-Path $PSScriptRoot "run-qwen-code-dynamic.ps1") -Provider zai -ModelId "glm-5.1"
      return
    }
    "zai-flash47" {
      & (Join-Path $PSScriptRoot "run-qwen-code-dynamic.ps1") -Provider zai -ModelId "glm-4.7-flash"
      return
    }
    "zai-flash45" {
      & (Join-Path $PSScriptRoot "run-qwen-code-dynamic.ps1") -Provider zai -ModelId "glm-4.5-flash"
      return
    }
    # OpenRouter пресеты убраны — используйте «Другая модель…» → OpenRouter.
    "custom-qwen-zai" {
      $st = Get-LauncherState
      $mid = [string]$st.customModelId
      if ([string]::IsNullOrWhiteSpace($mid)) {
        throw "В qwen-code-launcher-state.json нет customModelId для custom-qwen-zai. Выберите модель в пункте «Другая модель»."
      }
      & (Join-Path $PSScriptRoot "run-qwen-code-dynamic.ps1") -Provider zai -ModelId $mid.Trim()
      return
    }
    "custom-qwen-zai-general" {
      $st = Get-LauncherState
      $mid = [string]$st.customModelId
      if ([string]::IsNullOrWhiteSpace($mid)) {
        throw "Нет customModelId для custom-qwen-zai-general."
      }
      & (Join-Path $PSScriptRoot "run-qwen-code-dynamic.ps1") -Provider zai-general -ModelId $mid.Trim()
      return
    }
    "custom-qwen-nim" {
      $st = Get-LauncherState
      $mid = [string]$st.customModelId
      if ([string]::IsNullOrWhiteSpace($mid)) {
        throw "В qwen-code-launcher-state.json нет customModelId для custom-qwen-nim."
      }
      & (Join-Path $PSScriptRoot "run-qwen-code-dynamic.ps1") -Provider nim -ModelId $mid.Trim()
      return
    }
    "custom-qwen-groq" {
      $st = Get-LauncherState
      $mid = [string]$st.customModelId
      if ([string]::IsNullOrWhiteSpace($mid)) {
        throw "Нет customModelId для custom-qwen-groq. Выберите модель в «Другая модель»."
      }
      & (Join-Path $PSScriptRoot "run-qwen-code-dynamic.ps1") -Provider groq -ModelId $mid.Trim()
      return
    }
    "custom-qwen-openrouter" {
      $st = Get-LauncherState
      $mid = [string]$st.customModelId
      if ([string]::IsNullOrWhiteSpace($mid)) {
        throw "Нет customModelId для custom-qwen-openrouter. Выберите модель в «Другая модель»."
      }
      & (Join-Path $PSScriptRoot "run-qwen-code-dynamic.ps1") -Provider openrouter -ModelId $mid.Trim()
      return
    }
    "custom-qwen-bai" {
      $st = Get-LauncherState
      $mid = [string]$st.customModelId
      if ([string]::IsNullOrWhiteSpace($mid)) {
        throw "Нет customModelId для custom-qwen-bai. Выберите модель в «Другая модель»."
      }
      & (Join-Path $PSScriptRoot "run-qwen-code-dynamic.ps1") -Provider bai -ModelId $mid.Trim()
      return
    }
    default {
      if ($ProfileId -like "bai-*") {
        $mid = $ProfileId.Substring("bai-".Length)
        $spec = $script:BaiModelSpec[$mid]
        if (-not $spec) { throw "Неизвестная B.AI модель: $mid" }
        & (Join-Path $PSScriptRoot "run-qwen-code-dynamic.ps1") -Provider bai -ModelId $mid -ContextLength $spec.Ctx -MaxTokens $spec.Max
        return
      }
      throw "Неизвестный профиль: $ProfileId"
    }
  }
}

if ($Quick -or $env:QWEN_CODE_LAUNCHER_QUICK -eq "1") {
  $st = Get-LauncherState
  $resolvedId = Resolve-ProfileFromState $st
  if (-not $resolvedId) {
    Write-Host "Нет сохранённого профиля. Один раз выберите модель в меню или уберите -Quick." -ForegroundColor Yellow
    Start-Sleep -Seconds 3
    exit 2
  }
  Invoke-QwenProfile -ProfileId $resolvedId
  exit $LASTEXITCODE
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

$updateHint = Test-LauncherUpdates -AgentNpmPackage "qwen-code" -AgentDisplayName "Qwen Code"

# Build provider group menus dynamically from API (with static fallback).
# "Загрузка моделей..." briefly shown while API calls run.
Write-Host "`nЗагрузка списков моделей..." -ForegroundColor DarkGray
$staticZai = @(
  @{ Id = "zai-glm51";   Label = "Z.AI - GLM-5.1 (paid, tool calling)" }
  @{ Id = "zai-glm";     Label = "Z.AI - GLM-4.7 (paid, tool calling)" }
  @{ Id = "zai-flash47"; Label = "Z.AI - GLM-4.7-Flash (free, tool calling)" }
)
$staticNim = @(
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
$staticBai = @(
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
$staticOr = @(
  @{ Id = "openrouter-deepseek-v4-flash"; Label = "OpenRouter - DeepSeek V4 Flash (free, text-only)" }
  @{ Id = "openrouter-qwen3-coder";       Label = "OpenRouter - Qwen3 Coder (free, text-only)" }
  @{ Id = "openrouter-nemotron";          Label = "OpenRouter - Nemotron 3 Super 120B (free, text-only)" }
  @{ Id = "openrouter-laguna";            Label = "OpenRouter - Poolside Laguna M.1 (free, text-only, coding)" }
)
$zaiMap = @{ "glm-5.1" = "zai-glm51"; "glm-4.7" = "zai-glm"; "glm-4.7-flash" = "zai-flash47" }
$zaiRes = Build-GroupMenuItems -Provider "zai" -StaticItems $staticZai -ApiKeyEnv "ZAI_API_KEY" -FetchScript "Get-ZaiCodingModelIdsFromApi" -IdPrefix "zai-" -ApiIdToPresetId $zaiMap
$nimRes = Build-GroupMenuItems -Provider "nim" -StaticItems $staticNim -ApiKeyEnv "NVIDIA_NIM_API_KEY" -FetchScript "Get-NvidiaNimModelIdsFromApi" -FilterToBundled -IdPrefix "nim-"
$baiRes = Build-GroupMenuItems -Provider "bai" -StaticItems $staticBai -ApiKeyEnv "BAI_API_KEY" -FetchScript "Get-BaiModelIdsFromApi" -IdPrefix "bai-"
$orRes  = Build-GroupMenuItems -Provider "openrouter" -StaticItems $staticOr -ApiKeyEnv "OPENROUTER_API_KEY" -FetchScript "Get-OpenRouterModelIdsFromApi" -IdPrefix "openrouter-"
$script:GroupMenus = @{
  zai        = $zaiRes.Items
  nim        = $nimRes.Items
  bai        = $baiRes.Items
  openrouter = $orRes.Items
}
$groupHints = @()
if ($zaiRes.Source -eq "static")  { $groupHints += "Z.AI: статический список" }
if ($nimRes.Source -eq "static")  { $groupHints += "NIM: статический список" }
if ($baiRes.Source -eq "static")  { $groupHints += "B.AI: статический список" }
if ($orRes.Source -eq "static")   { $groupHints += "OpenRouter: статический список" }
if ($groupHints.Count -gt 0) {
  $updateHint = "$updateHint | ($($groupHints -join ', '))"
}

while ($true) {
  $choice = Show-TuiFramedMenu -AppBrand "Qwen" -Title "Qwen Code - выбор провайдера" -Subtitle "Z.AI · NIM · OpenRouter · B.AI" -Items $items -InitialIndex $startIdx -MaxVisible 20 -UpdateHint $updateHint
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
      "nim"        { "NVIDIA NIM - 9 бесплатных agentic моделей" }
      "bai"        { "B.AI - https://api.b.ai/v1 (OpenAI-compatible)" }
      "openrouter" { "OpenRouter - бесплатные модели (text-only)" }
      default      { "" }
    }
    $subChoice = Show-TuiFramedMenu -AppBrand "Qwen" -Title ("Qwen Code - {0}" -f $groupKey.ToUpper()) -Subtitle $subTitle -Items $groupItems -MaxVisible 16 -EscapeAction Back
    if ($null -eq $subChoice) { continue }
    if ($true -eq $subChoice.__menuBack) { continue }
    $profileId = [string]$subChoice.Id
    Save-LauncherState -ProfileId $profileId
    Invoke-QwenProfile -ProfileId $profileId
    continue
  }

  if ($profileId -eq "custom-model") {
    $w = Invoke-LauncherCustomModelWizard -App "Qwen"
    if ($null -eq $w) {
      Write-Host "Отменено." -ForegroundColor Yellow
      continue
    }
    if ($true -eq $w.__menuBack) { continue }
    $newId = switch ($w.Provider) {
      "zai" { "custom-qwen-zai" }
      "zai-general" { "custom-qwen-zai-general" }
      "groq" { "custom-qwen-groq" }
      "openrouter" { "custom-qwen-openrouter" }
      "bai" { "custom-qwen-bai" }
      default { "custom-qwen-nim" }
    }
    Save-LauncherState -ProfileId $newId -Extra @{ customModelId = [string]$w.ModelId }
    Invoke-QwenProfile -ProfileId $newId
    continue
  }

  if ($profileId -eq "native-login") {
    $qwenExe = Resolve-QwenExe
    if (-not $qwenExe) {
      Write-Host "Qwen Code CLI не найден (qwen). Установите: npm install -g @qwen-code/qwen-code@latest" -ForegroundColor Red
      Write-Host "Нажмите любую клавишу для возврата в меню…" -ForegroundColor Green
      $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
      continue
    }
    $loginItems = @(
      @{ Id = "qwen-oauth"; Label = "Qwen OAuth (браузер, подписка Qwen)" }
      @{ Id = "coding-plan"; Label = "Alibaba Cloud Coding Plan (API-ключ)" }
      @{ Id = "vanilla"; Label = "Запуск Qwen Code (ванильный запуск)" }
    )
    $loginChoice = Show-TuiFramedMenu -AppBrand "Qwen" -Title "Нативный логин Qwen Code" -Subtitle "Выберите способ авторизации" -Items $loginItems -MaxVisible 10
    if (-not $loginChoice) { continue }
    switch ([string]$loginChoice.Id) {
      "qwen-oauth" {
        Clear-Host
        Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host "  Qwen OAuth - авторизация через браузер" -ForegroundColor Cyan
        Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  Откроется браузер. Завершите авторизацию в нём." -ForegroundColor Yellow
        Write-Host "  Для этого нужна подписка Qwen (qwen.ai)." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  Запуск..." -ForegroundColor Cyan
        Invoke-CliCommand -ExePath $qwenExe -Arguments @("auth", "qwen-oauth")
        Write-Host ""
        Write-Host "  Текущий статус:" -ForegroundColor Green
        Invoke-CliCommand -ExePath $qwenExe -Arguments @("auth", "status")
        Write-Host ""
        Write-Host "Нажмите любую клавишу для возврата в меню…" -ForegroundColor Green
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
      }
      "coding-plan" {
        Clear-Host
        Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host "  Alibaba Cloud Coding Plan" -ForegroundColor Cyan
        Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  Регион: china или global" -ForegroundColor Yellow
        Write-Host "  Потребуется API-ключ от Alibaba Cloud." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  Запуск..." -ForegroundColor Cyan
        Invoke-CliCommand -ExePath $qwenExe -Arguments @("auth", "coding-plan")
        Write-Host ""
        Write-Host "  Текущий статус:" -ForegroundColor Green
        Invoke-CliCommand -ExePath $qwenExe -Arguments @("auth", "status")
        Write-Host ""
        Write-Host "Нажмите любую клавишу для возврата в меню…" -ForegroundColor Green
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
      }
      "vanilla" {
        Clear-Host
        Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host "  Запуск Qwen Code (ванильный запуск)" -ForegroundColor Cyan
        Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  Команда: qwen" -ForegroundColor Yellow
        Write-Host ""
        Invoke-CliCommand -ExePath $qwenExe
        Write-Host ""
        Write-Host "Нажмите любую клавишу для возврата в меню…" -ForegroundColor Green
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
      }
    }
    continue
  }

  if ($profileId -eq "change-api-key") {
    Show-ApiKeyChangeMenu -AppBrand "Qwen"
    continue
  }

  if ($profileId -eq "last") {
    $st = Get-LauncherState
    $profileId = Resolve-ProfileFromState $st
    if (-not $profileId) {
      Write-Host "Сохранённый профиль не найден. Выберите пресет или «Другая модель» один раз." -ForegroundColor Red
      Write-Host "Нажмите любую клавишу..."
      $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
      continue
    }
  } else {
    Save-LauncherState -ProfileId $profileId
  }

  Invoke-QwenProfile -ProfileId $profileId
  continue
}
