[CmdletBinding()]
param(
  [switch]$Quick
)

$ErrorActionPreference = "Stop"
# Native commands (claude.exe) при Ctrl+C возвращают non-zero exit code, что в PS 7.4+
# превращается в исключение и пробрасывается до верха, ломая TUI launcher'а.
# Явно отключаем эту трансформацию — exit code читаем через $LASTEXITCODE сам.
$PSNativeCommandUseErrorActionPreference = $false

. (Join-Path $PSScriptRoot "ensure-streaming-friendly-terminal.ps1")
. (Join-Path $PSScriptRoot "launcher-tui.ps1")
. (Join-Path $PSScriptRoot "launcher-provider-models.ps1")
. (Join-Path $PSScriptRoot "launcher-custom-model-wizard.ps1")
. (Join-Path $PSScriptRoot "launcher-api-keys.ps1")

$StatePath = Join-Path $PSScriptRoot "claude-cloud-launcher-state.json"
$SessionScript = Join-Path $PSScriptRoot "run-claude-cloud-session.ps1"

function Resolve-ClaudeExe {
  return (Resolve-CommandOrInstall -CommandName "claude.cmd" -AltCommandName "claude" -NpmPackage "@anthropic-ai/claude-code" -DisplayName "Claude Code")
}

function Invoke-CliCommand {
  param(
    [Parameter(Mandatory = $true)][string]$ExePath,
    [string[]]$Arguments = @()
  )
  Invoke-ChildCliCatchCtrlC -ExePath $ExePath -Arguments $Arguments
}

if (-not (Test-Path -LiteralPath $SessionScript)) {
  throw "Не найден скрипт: $SessionScript"
}

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
  @{
    Id    = "group:bai"
    Label = "B.AI - DeepSeek/MiniMax/GLM/Kimi/GPT (OpenAI-compatible)"
  }
  @{
    Id    = "group:openrouter"
    Label = "OpenRouter - бесплатные agentic модели"
  }
  @{
    Id    = "group:bai"
    Label = "B.AI - DeepSeek/MiniMax/GLM/Kimi/GPT (OpenAI-compatible)"
  }
  # OpenRouter доступен через «Другая модель» (прямой OpenAI-compat, без proxy).
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
    Label = "Нативный логин (Anthropic OAuth / Console)"
  }
  @{
    Id    = "change-api-key"
    Label = "Сменить ключ API провайдера"
  }
)

# Характеристики B.AI моделей (context window, max_tokens). Только agentic-модели.
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
  "deepseek-v3.2"     = @{ Ctx = 131072;  Max = 8192 }
  "deepseek-v4-pro"   = @{ Ctx = 131072;  Max = 8192 }
  "deepseek-v4-flash" = @{ Ctx = 131072;  Max = 8192 }
  "gemini-3-flash"    = @{ Ctx = 1000000; Max = 8192 }
  "gemini-3.1-pro"    = @{ Ctx = 1000000; Max = 8192 }
  "gemini-3.5-flash"  = @{ Ctx = 1000000; Max = 8192 }
  "glm-5"             = @{ Ctx = 128000;  Max = 8192 }
  "glm-5.1"           = @{ Ctx = 128000;  Max = 8192 }
  "kimi-k2.5"         = @{ Ctx = 131072;  Max = 8192 }
  "minimax-m2.5"      = @{ Ctx = 1000000; Max = 8192 }
  "minimax-m2.7"      = @{ Ctx = 1000000; Max = 8192 }
  "minimax-m3"        = @{ Ctx = 1000000; Max = 8192 }
}

# Подменю для каждой группы провайдера
$script:GroupMenus = @{
  zai = @(
    @{ Id = "claude-zai-glm51";   Label = "Z.AI - GLM-5.1 (paid, tool calling)" }
    @{ Id = "claude-zai";         Label = "Z.AI - GLM-4.7 (paid, tool calling)" }
    @{ Id = "claude-zai-flash47"; Label = "Z.AI - GLM-4.7-Flash (free)" }
  )
  nim = @(
    @{ Id = "claude-nim-mistral-medium";   Label = "NIM - Mistral Medium 3.5 128B (free, tool calling)" }
    @{ Id = "claude-nim-glm51";            Label = "NIM - Z.AI GLM-5.1 (free, tool calling)" }
    @{ Id = "claude-nim-step-3.5-flash";   Label = "NIM - Step 3.5 Flash (free, tool calling)" }
    @{ Id = "claude-nim-mistral-large-3";  Label = "NIM - Mistral Large 3 675B (free, tool calling)" }
    @{ Id = "claude-nim-deepseek-v4-flash"; Label = "NIM - DeepSeek V4 Flash 284B MoE (free)" }
    @{ Id = "claude-nim-gemma-4-31b";      Label = "NIM - Google Gemma-4 31B (free)" }
    @{ Id = "claude-nim-qwen3.5-397b";     Label = "NIM - Qwen 3.5 397B A17B (free)" }
    @{ Id = "claude-nim-qwen3-next-80b";   Label = "NIM - Qwen 3 Next 80B A3B (free)" }
    @{ Id = "claude-nim-qwen3-coder-480b"; Label = "NIM - Qwen 3 Coder 480B A35B (free)" }
  )
  nim = @(
    @{ Id = "claude-nim-mistral-medium";   Label = "NIM - Mistral Medium 3.5 128B (free, tool calling)" }
    @{ Id = "claude-nim-glm51";            Label = "NIM - Z.AI GLM-5.1 (free, tool calling)" }
    @{ Id = "claude-nim-step-3.5-flash";   Label = "NIM - Step 3.5 Flash (free, tool calling)" }
    @{ Id = "claude-nim-mistral-large-3";  Label = "NIM - Mistral Large 3 675B (free, tool calling)" }
    @{ Id = "claude-nim-deepseek-v4-flash"; Label = "NIM - DeepSeek V4 Flash 284B MoE (free)" }
    @{ Id = "claude-nim-gemma-4-31b";      Label = "NIM - Google Gemma-4 31B (free)" }
    @{ Id = "claude-nim-qwen3.5-397b";     Label = "NIM - Qwen 3.5 397B A17B (free)" }
    @{ Id = "claude-nim-qwen3-next-80b";   Label = "NIM - Qwen 3 Next 80B A3B (free)" }
    @{ Id = "claude-nim-qwen3-coder-480b"; Label = "NIM - Qwen 3 Coder 480B A35B (free)" }
  )
  bai = @(
    @{ Id = "claude-bai-gpt-5-nano";        Label = "B.AI - GPT-5 Nano (OpenAI, agentic)" }
    @{ Id = "claude-bai-gpt-5-mini";        Label = "B.AI - GPT-5 Mini (OpenAI, agentic)" }
    @{ Id = "claude-bai-gpt-5.2";           Label = "B.AI - GPT-5.2 (OpenAI, agentic)" }
    @{ Id = "claude-bai-gpt-5.4-nano";      Label = "B.AI - GPT-5.4 Nano (OpenAI, agentic)" }
    @{ Id = "claude-bai-gpt-5.4-mini";      Label = "B.AI - GPT-5.4 Mini (OpenAI, agentic)" }
    @{ Id = "claude-bai-gpt-5.4";           Label = "B.AI - GPT-5.4 (OpenAI, agentic)" }
    @{ Id = "claude-bai-gpt-5.4-pro";       Label = "B.AI - GPT-5.4 Pro (OpenAI, agentic)" }
    @{ Id = "claude-bai-gpt-5.5";           Label = "B.AI - GPT-5.5 (OpenAI, agentic)" }
    @{ Id = "claude-bai-gpt-5.5-instant";   Label = "B.AI - GPT-5.5 Instant (OpenAI, agentic)" }
    @{ Id = "claude-bai-claude-haiku-4.5";  Label = "B.AI - Claude Haiku 4.5 (Anthropic, agentic)" }
    @{ Id = "claude-bai-claude-sonnet-4.5"; Label = "B.AI - Claude Sonnet 4.5 (Anthropic, agentic)" }
    @{ Id = "claude-bai-claude-sonnet-4.6"; Label = "B.AI - Claude Sonnet 4.6 (Anthropic, agentic)" }
    @{ Id = "claude-bai-claude-opus-4.5";   Label = "B.AI - Claude Opus 4.5 (Anthropic, agentic)" }
    @{ Id = "claude-bai-claude-opus-4.6";   Label = "B.AI - Claude Opus 4.6 (Anthropic, agentic)" }
    @{ Id = "claude-bai-claude-opus-4.7";   Label = "B.AI - Claude Opus 4.7 (Anthropic, agentic)" }
    @{ Id = "claude-bai-claude-opus-4.8";   Label = "B.AI - Claude Opus 4.8 (Anthropic, agentic)" }
    @{ Id = "claude-bai-deepseek-v4-pro";   Label = "B.AI - DeepSeek V4 Pro (agentic)" }
    @{ Id = "claude-bai-deepseek-v4-flash"; Label = "B.AI - DeepSeek V4 Flash (agentic)" }
    @{ Id = "claude-bai-gemini-3.1-pro";    Label = "B.AI - Gemini 3.1 Pro (Google, agentic)" }
    @{ Id = "claude-bai-gemini-3.5-flash";  Label = "B.AI - Gemini 3.5 Flash (Google, agentic)" }
    @{ Id = "claude-bai-glm-5";             Label = "B.AI - GLM-5 (Z.AI)" }
    @{ Id = "claude-bai-glm-5.1";           Label = "B.AI - GLM-5.1 (Z.AI)" }
    @{ Id = "claude-bai-kimi-k2.5";         Label = "B.AI - Kimi K2.5 (Moonshot)" }
    @{ Id = "claude-bai-kimi-k2.6";         Label = "B.AI - Kimi K2.6 (Moonshot)" }
    @{ Id = "claude-bai-minimax-m3";        Label = "B.AI - MiniMax M3 (agentic)" }
    @{ Id = "claude-bai-minimax-m2.7";      Label = "B.AI - MiniMax M2.7 (fast)" }
  )
  openrouter = @(
    @{ Id = "claude-openrouter-deepseek-v4-flash"; Label = "OpenRouter - DeepSeek V4 Flash (free, text-only)" }
    @{ Id = "claude-openrouter-qwen3-coder";       Label = "OpenRouter - Qwen3 Coder (free, text-only)" }
    @{ Id = "claude-openrouter-nemotron";          Label = "OpenRouter - Nemotron 3 Super 120B (free, text-only)" }
    @{ Id = "claude-openrouter-laguna";            Label = "OpenRouter - Poolside Laguna M.1 (free, coding, text-only)" }
  )
}

function Get-LauncherState {
  if (-not (Test-Path -LiteralPath $StatePath)) { return $null }
  try {
    return (Get-Content -LiteralPath $StatePath -Raw -Encoding UTF8 | ConvertFrom-Json)
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
      "claude-zai", "claude-zai-glm51", "claude-zai-flash47", "claude-zai-flash45",
      "claude-nim-mistral-medium", "claude-nim-glm51", "claude-nim-step-3.5-flash",
      "claude-nim-mistral-large-3", "claude-nim-deepseek-v4-flash", "claude-nim-gemma-4-31b",
      "claude-nim-qwen3.5-397b", "claude-nim-qwen3-next-80b", "claude-nim-qwen3-coder-480b",
      "claude-openrouter-hy3", "claude-openrouter-nemotron", "claude-openrouter-laguna",
      "claude-openrouter-deepseek-v4-flash", "claude-openrouter-qwen3-coder",
      "custom-claude-zai", "custom-claude-nim", "custom-claude-openrouter", "custom-claude-bai"
    )) { return $id }
  # B.AI Claude: динамически проверяем по agentic-списку
  if ($id -like "claude-bai-*") {
    $mid = $id.Substring("claude-bai-".Length)
    if ($mid -and ($script:BaiModelSpec.ContainsKey($mid))) { return $id }
  }
  return $null
}

function Invoke-ClaudeCloudProfile {
  param(
    [Parameter(Mandatory = $true)][string]$ProfileId
  )

  Clear-Host
  Write-Host "Запуск сессии Claude Code (облако)…" -ForegroundColor Cyan
  Write-Host "Профиль: $ProfileId" -ForegroundColor DarkGray
  [Console]::Out.Flush()

  switch ($ProfileId) {
    "claude-zai" {
      & $SessionScript -Provider zai -ClaudeTools default `
        -ClaudeMemMaxWaitSec 60 -SkipCommonPreamble
      return
    }
    "claude-zai-glm51" {
      & $SessionScript -Provider zai -ZaiAnthropicModelId "glm-5.1" -ClaudeTools default `
        -ClaudeMemMaxWaitSec 60 -SkipCommonPreamble
      return
    }
    "claude-zai-flash47" {
      & $SessionScript -Provider zai -ZaiAnthropicModelId "glm-4.7-flash" -ClaudeTools default `
        -ClaudeMemMaxWaitSec 60 -SkipCommonPreamble
      return
    }
    "claude-zai-flash45" {
      & $SessionScript -Provider zai -ZaiAnthropicModelId "glm-4.5-flash" -ClaudeTools default `
        -ClaudeMemMaxWaitSec 60 -SkipCommonPreamble
      return
    }
    "claude-nim-mistral-medium" {
      & $SessionScript -Provider nim -NimModel "nvidia_nim/mistralai/mistral-medium-3.5-128b" -ClaudeTools default `
        -ClaudeMemMaxWaitSec 60 -SkipCommonPreamble
      return
    }
    "claude-nim-glm51" {
      & $SessionScript -Provider nim -NimModel "nvidia_nim/z-ai/glm-5.1" -ClaudeTools default `
        -ClaudeMemMaxWaitSec 60 -SkipCommonPreamble
      return
    }
    "claude-nim-step-3.5-flash" {
      & $SessionScript -Provider nim -NimModel "nvidia_nim/stepfun-ai/step-3.5-flash" -ClaudeTools default `
        -ClaudeMemMaxWaitSec 60 -SkipCommonPreamble
      return
    }
    "claude-nim-mistral-large-3" {
      & $SessionScript -Provider nim -NimModel "nvidia_nim/mistralai/mistral-large-3-675b-instruct-2512" -ClaudeTools default `
        -ClaudeMemMaxWaitSec 60 -SkipCommonPreamble
      return
    }
    "claude-nim-deepseek-v4-flash" {
      & $SessionScript -Provider nim -NimModel "nvidia_nim/deepseek-ai/deepseek-v4-flash" -ClaudeTools minimal `
        -ClaudeMemMaxWaitSec 60 -SkipCommonPreamble
      return
    }
    "claude-nim-gemma-4-31b" {
      & $SessionScript -Provider nim -NimModel "nvidia_nim/google/gemma-4-31b-it" -ClaudeTools minimal `
        -ClaudeMemMaxWaitSec 60 -SkipCommonPreamble
      return
    }
    "claude-nim-qwen3.5-397b" {
      & $SessionScript -Provider nim -NimModel "nvidia_nim/qwen/qwen3.5-397b-a17b" -ClaudeTools minimal `
        -ClaudeMemMaxWaitSec 60 -SkipCommonPreamble
      return
    }
    "claude-nim-qwen3-next-80b" {
      & $SessionScript -Provider nim -NimModel "nvidia_nim/qwen/qwen3-next-80b-a3b-instruct" -ClaudeTools minimal `
        -ClaudeMemMaxWaitSec 60 -SkipCommonPreamble
      return
    }
    "claude-nim-qwen3-coder-480b" {
      & $SessionScript -Provider nim -NimModel "nvidia_nim/qwen/qwen3-coder-480b-a35b-instruct" -ClaudeTools minimal `
        -ClaudeMemMaxWaitSec 60 -SkipCommonPreamble
      return
    }
    # OpenRouter пресеты убраны — используйте «Другая модель…» → OpenRouter.
    "custom-claude-zai" {
      $st = Get-LauncherState
      $mid = [string]$st.customModelId
      if ([string]::IsNullOrWhiteSpace($mid)) {
        throw "Нет customModelId в claude-cloud-launcher-state.json. Выберите модель в «Другая модель»."
      }
      & $SessionScript -Provider zai -ZaiAnthropicModelId $mid.Trim() -ClaudeTools default `
        -ClaudeMemMaxWaitSec 25 -SkipCommonPreamble
      return
    }
    "custom-claude-nim" {
      $st = Get-LauncherState
      $full = [string]$st.customNimModel
      if ([string]::IsNullOrWhiteSpace($full)) {
        throw "Нет customNimModel в claude-cloud-launcher-state.json."
      }
      $catalog = $full.Trim().ToLowerInvariant()
      while ($catalog.StartsWith("nvidia_nim/")) {
        $catalog = $catalog.Substring("nvidia_nim/".Length)
      }
      $claudeTools = if (Test-NvidiaNimOpenAiNativeToolCalling $catalog) { "default" } else { "minimal" }
      $port = Get-LauncherFreeTcpPort
      & $SessionScript -Provider nim -NimModel $full.Trim() -ProxyPort $port -ClaudeTools $claudeTools `
        -ClaudeMemMaxWaitSec 25 -SkipCommonPreamble
      return
    }
    "custom-claude-openrouter" {
      $st = Get-LauncherState
      $mid = [string]$st.customModelId
      if ([string]::IsNullOrWhiteSpace($mid)) {
        throw "Нет customModelId для custom-claude-openrouter. Выберите модель в «Другая модель»."
      }
      & $SessionScript -Provider openrouter -ZaiAnthropicModelId $mid.Trim() -ClaudeTools default `
        -ClaudeMemMaxWaitSec 25 -SkipCommonPreamble
      return
    }
    "custom-claude-bai" {
      $st = Get-LauncherState
      $mid = [string]$st.customModelId
      if ([string]::IsNullOrWhiteSpace($mid)) {
        throw "Нет customModelId в claude-cloud-launcher-state.json. Выберите модель в «Другая модель»."
      }
      $baiKey = Resolve-ApiKeyOrPrompt -CurrentKey $null -ProviderName "B.AI" -HelpUrl "https://chat.b.ai/key"
      if ([string]::IsNullOrWhiteSpace($baiKey)) { return }
      $env:OPENAI_API_KEY = $baiKey
      $env:OPENAI_BASE_URL = "https://api.b.ai/v1"
      $env:OPENAI_MODEL = $mid.Trim()
      $env:CLAUDE_CODE_USE_OPENAI = "1"
      $claudeExe = Resolve-ClaudeExe
      if (-not $claudeExe) { throw "Claude Code CLI не найден." }
      Invoke-CliCommand -ExePath $claudeExe
      return
    }
    default {
      if ($ProfileId -like "claude-bai-*") {
        $mid = $ProfileId.Substring("claude-bai-".Length)
        $baiKey = Resolve-ApiKeyOrPrompt -CurrentKey $null -ProviderName "B.AI" -HelpUrl "https://chat.b.ai/key"
        if ([string]::IsNullOrWhiteSpace($baiKey)) { return }
        $env:OPENAI_API_KEY = $baiKey
        $env:OPENAI_BASE_URL = "https://api.b.ai/v1"
        $env:OPENAI_MODEL = $mid
        $env:CLAUDE_CODE_USE_OPENAI = "1"
        $claudeExe = Resolve-ClaudeExe
        if (-not $claudeExe) { throw "Claude Code CLI не найден." }
        Invoke-CliCommand -ExePath $claudeExe
        return
      }
      # Dynamic Z.AI dispatch
      if ($ProfileId -like "claude-zai-*") {
        $mid = $ProfileId.Substring("claude-zai-".Length)
        & $SessionScript -Provider zai -ZaiAnthropicModelId $mid -ClaudeTools default `
          -ClaudeMemMaxWaitSec 60 -SkipCommonPreamble
        return
      }
      # Dynamic NIM dispatch
      if ($ProfileId -like "claude-nim-*") {
        $catalog = $ProfileId.Substring("claude-nim-".Length)
        $full = "nvidia_nim/$catalog"
        $claudeTools = if (Test-NvidiaNimOpenAiNativeToolCalling $catalog) { "default" } else { "minimal" }
        & $SessionScript -Provider nim -NimModel $full -ClaudeTools $claudeTools `
          -ClaudeMemMaxWaitSec 60 -SkipCommonPreamble
        return
      }
      # Dynamic OpenRouter dispatch
      if ($ProfileId -like "claude-openrouter-*") {
        $mid = $ProfileId.Substring("claude-openrouter-".Length)
        & $SessionScript -Provider openrouter -ZaiAnthropicModelId $mid -ClaudeTools default `
          -ClaudeMemMaxWaitSec 25 -SkipCommonPreamble
        return
      }
      throw "Неизвестный профиль: $ProfileId"
    }
  }
}

if ($Quick -or $env:CLAUDE_CLOUD_LAUNCHER_QUICK -eq "1") {
  $st = Get-LauncherState
  $resolvedId = Resolve-ProfileFromState $st
  if (-not $resolvedId) {
    Write-Host "Нет сохранённого профиля Claude (облако). Один раз выберите провайдер в меню." -ForegroundColor Yellow
    Start-Sleep -Seconds 3
    exit 2
  }
  try { Invoke-ClaudeCloudProfile -ProfileId $resolvedId } catch { Write-Host "" }
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

$updateHint = Test-LauncherUpdates -AgentNpmPackage "@anthropic-ai/claude-code" -AgentDisplayName "Claude Code"

Write-Host "`nЗагрузка списков моделей..." -ForegroundColor DarkGray
$staticZaiCC = @(
  @{ Id = "claude-zai-glm51";   Label = "Z.AI - GLM-5.1 (paid, tool calling)" }
  @{ Id = "claude-zai";         Label = "Z.AI - GLM-4.7 (paid, tool calling)" }
  @{ Id = "claude-zai-flash47"; Label = "Z.AI - GLM-4.7-Flash (free)" }
)
$staticNimCC = @(
  @{ Id = "claude-nim-mistral-medium";   Label = "NIM - Mistral Medium 3.5 128B (free, tool calling)" }
  @{ Id = "claude-nim-glm51";            Label = "NIM - Z.AI GLM-5.1 (free, tool calling)" }
  @{ Id = "claude-nim-step-3.5-flash";   Label = "NIM - Step 3.5 Flash (free, tool calling)" }
  @{ Id = "claude-nim-mistral-large-3";  Label = "NIM - Mistral Large 3 675B (free, tool calling)" }
  @{ Id = "claude-nim-deepseek-v4-flash"; Label = "NIM - DeepSeek V4 Flash 284B MoE (free)" }
  @{ Id = "claude-nim-gemma-4-31b";      Label = "NIM - Google Gemma-4 31B (free)" }
  @{ Id = "claude-nim-qwen3.5-397b";     Label = "NIM - Qwen 3.5 397B A17B (free)" }
  @{ Id = "claude-nim-qwen3-next-80b";   Label = "NIM - Qwen 3 Next 80B A3B (free)" }
  @{ Id = "claude-nim-qwen3-coder-480b"; Label = "NIM - Qwen 3 Coder 480B A35B (free)" }
)
  @{ Id = "claude-nim-qwen3-coder-480b"; Label = "NIM - Qwen 3 Coder 480B A35B (free)" }
)
$staticBaiCC = @(
  @{ Id = "claude-bai-gpt-5-nano";        Label = "B.AI - GPT-5 Nano (OpenAI, agentic)" }
  @{ Id = "claude-bai-gpt-5-mini";        Label = "B.AI - GPT-5 Mini (OpenAI, agentic)" }
  @{ Id = "claude-bai-gpt-5.2";           Label = "B.AI - GPT-5.2 (OpenAI, agentic)" }
  @{ Id = "claude-bai-gpt-5.4-nano";      Label = "B.AI - GPT-5.4 Nano (OpenAI, agentic)" }
  @{ Id = "claude-bai-gpt-5.4-mini";      Label = "B.AI - GPT-5.4 Mini (OpenAI, agentic)" }
  @{ Id = "claude-bai-gpt-5.4";           Label = "B.AI - GPT-5.4 (OpenAI, agentic)" }
  @{ Id = "claude-bai-gpt-5.4-pro";       Label = "B.AI - GPT-5.4 Pro (OpenAI, agentic)" }
  @{ Id = "claude-bai-gpt-5.5";           Label = "B.AI - GPT-5.5 (OpenAI, agentic)" }
  @{ Id = "claude-bai-gpt-5.5-instant";   Label = "B.AI - GPT-5.5 Instant (OpenAI, agentic)" }
  @{ Id = "claude-bai-claude-haiku-4.5";  Label = "B.AI - Claude Haiku 4.5 (Anthropic, agentic)" }
  @{ Id = "claude-bai-claude-sonnet-4.5"; Label = "B.AI - Claude Sonnet 4.5 (Anthropic, agentic)" }
  @{ Id = "claude-bai-claude-sonnet-4.6"; Label = "B.AI - Claude Sonnet 4.6 (Anthropic, agentic)" }
  @{ Id = "claude-bai-claude-opus-4.5";   Label = "B.AI - Claude Opus 4.5 (Anthropic, agentic)" }
  @{ Id = "claude-bai-claude-opus-4.6";   Label = "B.AI - Claude Opus 4.6 (Anthropic, agentic)" }
  @{ Id = "claude-bai-claude-opus-4.7";   Label = "B.AI - Claude Opus 4.7 (Anthropic, agentic)" }
  @{ Id = "claude-bai-claude-opus-4.8";   Label = "B.AI - Claude Opus 4.8 (Anthropic, agentic)" }
  @{ Id = "claude-bai-deepseek-v4-pro";   Label = "B.AI - DeepSeek V4 Pro (agentic)" }
  @{ Id = "claude-bai-deepseek-v4-flash"; Label = "B.AI - DeepSeek V4 Flash (agentic)" }
  @{ Id = "claude-bai-gemini-3.1-pro";    Label = "B.AI - Gemini 3.1 Pro (Google, agentic)" }
  @{ Id = "claude-bai-gemini-3.5-flash";  Label = "B.AI - Gemini 3.5 Flash (Google, agentic)" }
  @{ Id = "claude-bai-glm-5";             Label = "B.AI - GLM-5 (Z.AI)" }
  @{ Id = "claude-bai-glm-5.1";           Label = "B.AI - GLM-5.1 (Z.AI)" }
  @{ Id = "claude-bai-kimi-k2.5";         Label = "B.AI - Kimi K2.5 (Moonshot)" }
  @{ Id = "claude-bai-kimi-k2.6";         Label = "B.AI - Kimi K2.6 (Moonshot)" }
  @{ Id = "claude-bai-minimax-m3";        Label = "B.AI - MiniMax M3 (agentic)" }
  @{ Id = "claude-bai-minimax-m2.7";      Label = "B.AI - MiniMax M2.7 (fast)" }
)
$staticOrCC = @(
  @{ Id = "claude-openrouter-deepseek-v4-flash"; Label = "OpenRouter - DeepSeek V4 Flash (free, text-only)" }
  @{ Id = "claude-openrouter-qwen3-coder";       Label = "OpenRouter - Qwen3 Coder (free, text-only)" }
  @{ Id = "claude-openrouter-nemotron";          Label = "OpenRouter - Nemotron 3 Super 120B (free, text-only)" }
  @{ Id = "claude-openrouter-laguna";            Label = "OpenRouter - Poolside Laguna M.1 (free, coding, text-only)" }
)
$zaiMapCC = @{ "glm-5.1" = "claude-zai-glm51"; "glm-4.7" = "claude-zai"; "glm-4.7-flash" = "claude-zai-flash47" }
$zaiResCC = Build-GroupMenuItems -Provider "zai" -StaticItems $staticZaiCC -ApiKeyEnv "ZAI_API_KEY" -FetchScript "Get-ZaiCodingModelIdsFromApi" -IdPrefix "claude-zai-" -ApiIdToPresetId $zaiMapCC -ForcedIds @("glm-4.7-flash")
$nimMapCC = @{ "mistralai/mistral-medium-3.5-128b" = "claude-nim-mistral-medium"; "z-ai/glm-5.1" = "claude-nim-glm51"; "stepfun-ai/step-3.5-flash" = "claude-nim-step-3.5-flash"; "mistralai/mistral-large-3-675b-instruct-2512" = "claude-nim-mistral-large-3"; "deepseek-ai/deepseek-v4-flash" = "claude-nim-deepseek-v4-flash"; "deepseek-ai/deepseek-v4-pro" = "claude-nim-deepseek-v4-pro"; "qwen/qwen3.5-397b-a17b" = "claude-nim-qwen3.5-397b"; "qwen/qwen3-next-80b-a3b-instruct" = "claude-nim-qwen3-next-80b"; "qwen/qwen3-coder-480b-a35b-instruct" = "claude-nim-qwen3-coder-480b"; "google/gemma-4-31b-it" = "claude-nim-gemma-4-31b" }
$nimResCC = Build-GroupMenuItems -Provider "nim" -StaticItems $staticNimCC -ApiKeyEnv "NVIDIA_NIM_API_KEY" -FetchScript "Get-NvidiaNimModelIdsFromApi" -AgenticOnly -IdPrefix "claude-nim-" -ApiIdToPresetId $nimMapCC
$orMapCC = @{ "deepseek/deepseek-v4-flash:free" = "claude-openrouter-deepseek-v4-flash"; "qwen/qwen3-coder:free" = "claude-openrouter-qwen3-coder"; "nvidia/nemotron-3-super-120b-a12b:free" = "claude-openrouter-nemotron"; "poolside/laguna-m1:free" = "claude-openrouter-laguna" }
$orResCC = Build-GroupMenuItems -Provider "openrouter" -StaticItems $staticOrCC -ApiKeyEnv "OPENROUTER_API_KEY" -FetchScript "Get-OpenRouterFreeModelIdsFromApi" -IdPrefix "claude-openrouter-" -ApiIdToPresetId $orMapCC
$staticBaiCC = @(
  @{ Id = "claude-bai-gpt-5-nano";        Label = "B.AI - GPT-5 Nano (OpenAI, agentic)" }
  @{ Id = "claude-bai-gpt-5-mini";        Label = "B.AI - GPT-5 Mini (OpenAI, agentic)" }
  @{ Id = "claude-bai-gpt-5.2";           Label = "B.AI - GPT-5.2 (OpenAI, agentic)" }
  @{ Id = "claude-bai-gpt-5.4-nano";      Label = "B.AI - GPT-5.4 Nano (OpenAI, agentic)" }
  @{ Id = "claude-bai-gpt-5.4-mini";      Label = "B.AI - GPT-5.4 Mini (OpenAI, agentic)" }
  @{ Id = "claude-bai-gpt-5.4";           Label = "B.AI - GPT-5.4 (OpenAI, agentic)" }
  @{ Id = "claude-bai-gpt-5.4-pro";       Label = "B.AI - GPT-5.4 Pro (OpenAI, agentic)" }
  @{ Id = "claude-bai-gpt-5.5";           Label = "B.AI - GPT-5.5 (OpenAI, agentic)" }
  @{ Id = "claude-bai-gpt-5.5-instant";   Label = "B.AI - GPT-5.5 Instant (OpenAI, agentic)" }
  @{ Id = "claude-bai-claude-haiku-4.5";  Label = "B.AI - Claude Haiku 4.5 (Anthropic, agentic)" }
  @{ Id = "claude-bai-claude-sonnet-4.5"; Label = "B.AI - Claude Sonnet 4.5 (Anthropic, agentic)" }
  @{ Id = "claude-bai-claude-sonnet-4.6"; Label = "B.AI - Claude Sonnet 4.6 (Anthropic, agentic)" }
  @{ Id = "claude-bai-claude-opus-4.5";   Label = "B.AI - Claude Opus 4.5 (Anthropic, agentic)" }
  @{ Id = "claude-bai-claude-opus-4.6";   Label = "B.AI - Claude Opus 4.6 (Anthropic, agentic)" }
  @{ Id = "claude-bai-claude-opus-4.7";   Label = "B.AI - Claude Opus 4.7 (Anthropic, agentic)" }
  @{ Id = "claude-bai-claude-opus-4.8";   Label = "B.AI - Claude Opus 4.8 (Anthropic, agentic)" }
  @{ Id = "claude-bai-deepseek-v4-pro";   Label = "B.AI - DeepSeek V4 Pro (agentic)" }
  @{ Id = "claude-bai-deepseek-v4-flash"; Label = "B.AI - DeepSeek V4 Flash (agentic)" }
  @{ Id = "claude-bai-gemini-3.1-pro";    Label = "B.AI - Gemini 3.1 Pro (Google, agentic)" }
  @{ Id = "claude-bai-gemini-3.5-flash";  Label = "B.AI - Gemini 3.5 Flash (Google, agentic)" }
  @{ Id = "claude-bai-glm-5";             Label = "B.AI - GLM-5 (Z.AI)" }
  @{ Id = "claude-bai-glm-5.1";           Label = "B.AI - GLM-5.1 (Z.AI)" }
  @{ Id = "claude-bai-kimi-k2.5";         Label = "B.AI - Kimi K2.5 (Moonshot)" }
  @{ Id = "claude-bai-kimi-k2.6";         Label = "B.AI - Kimi K2.6 (Moonshot)" }
  @{ Id = "claude-bai-minimax-m3";        Label = "B.AI - MiniMax M3 (agentic)" }
  @{ Id = "claude-bai-minimax-m2.7";      Label = "B.AI - MiniMax M2.7 (fast)" }
)
$baiMapCC = @{}
$baiResCC = Build-GroupMenuItems -Provider "bai" -StaticItems $staticBaiCC -ApiKeyEnv "BAI_API_KEY" -FetchScript "Get-BaiNonPremiumModelIds" -IdPrefix "claude-bai-" -ApiIdToPresetId $baiMapCC
$groupHintsCC = @()
if ($zaiResCC.Source -eq "static")  { $groupHintsCC += "Z.AI: статический список" }
if ($nimResCC.Source -eq "static")  { $groupHintsCC += "NIM: статический список" }
if ($orResCC.Source -eq "static")   { $groupHintsCC += "OpenRouter: статический список" }
if ($zaiResCC.Source -eq "API")  { $script:GroupMenus.zai = $zaiResCC.Items }
if ($nimResCC.Source -eq "API")  { $script:GroupMenus.nim = $nimResCC.Items }
if ($baiResCC.Source -eq "API")  { $script:GroupMenus.bai = $baiResCC.Items }
if ($orResCC.Source -eq "API")   { $script:GroupMenus.openrouter = $orResCC.Items }
if ($groupHintsCC.Count -gt 0) {
  $updateHint = "$updateHint | ($($groupHintsCC -join ', '))"
}

while ($true) {
  $choice = Show-TuiFramedMenu -AppBrand "Claude" -Title "Claude Code (облако) - провайдер" -Subtitle "Z.AI · NIM · B.AI · OpenRouter (через free-claude-code)" -Items $items -InitialIndex $startIdx -MaxVisible 20 -UpdateHint $updateHint
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
    $subChoice = Show-TuiFramedMenu -AppBrand "Claude" -Title ("Claude Code - {0}" -f $groupKey.ToUpper()) -Subtitle $subTitle -Items $groupItems -MaxVisible 16 -EscapeAction Back
    if ($null -eq $subChoice) { continue }
    if ($true -eq $subChoice.__menuBack) { continue }
    $profileId = [string]$subChoice.Id
    Save-LauncherState -ProfileId $profileId
    try { Invoke-ClaudeCloudProfile -ProfileId $profileId } catch { Write-Host "" }
    continue
  }

  if ($profileId -eq "custom-model") {
    $w = Invoke-LauncherCustomModelWizard -App "Claude"
    if ($null -eq $w) {
      Write-Host "Отменено." -ForegroundColor Yellow
      continue
    }
    if ($true -eq $w.__menuBack) { continue }
    switch ($w.Provider) {
      "zai" {
        Save-LauncherState -ProfileId "custom-claude-zai" -Extra @{ customModelId = [string]$w.ModelId }
        try { Invoke-ClaudeCloudProfile -ProfileId "custom-claude-zai" } catch { Write-Host "" }
      }
      "openrouter" {
        Save-LauncherState -ProfileId "custom-claude-openrouter" -Extra @{ customModelId = [string]$w.ModelId }
        try { Invoke-ClaudeCloudProfile -ProfileId "custom-claude-openrouter" } catch { Write-Host "" }
      }
      "bai" {
        Save-LauncherState -ProfileId "custom-claude-bai" -Extra @{ customModelId = [string]$w.ModelId }
        try { Invoke-ClaudeCloudProfile -ProfileId "custom-claude-bai" } catch { Write-Host "" }
      }
      default {
        Save-LauncherState -ProfileId "custom-claude-nim" -Extra @{ customNimModel = [string]$w.ClaudeNimModel }
        try { Invoke-ClaudeCloudProfile -ProfileId "custom-claude-nim" } catch { Write-Host "" }
      }
    }
    continue
  }

  if ($profileId -eq "native-login") {
    $claudeExe = Resolve-ClaudeExe
    if (-not $claudeExe) {
      Write-Host "Claude Code CLI не найден (claude). Установите: npm install -g @anthropic-ai/claude-code@latest" -ForegroundColor Red
      Write-Host "Нажмите любую клавишу для возврата в меню…" -ForegroundColor Green
      $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
      continue
    }
    $loginItems = @(
      @{ Id = "claude-sub"; Label = "Claude подписка (OAuth, браузер)" }
      @{ Id = "anthropic-console"; Label = "Anthropic Console (API-биллинг, браузер)" }
      @{ Id = "vanilla"; Label = "Запуск Claude Code (ванильный запуск)" }
    )
    $loginChoice = Show-TuiFramedMenu -AppBrand "Claude" -Title "Нативный логин Claude Code" -Subtitle "Anthropic авторизация" -Items $loginItems -MaxVisible 10
    if (-not $loginChoice) { continue }
    switch ([string]$loginChoice.Id) {
      "claude-sub" {
        Clear-Host
        Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host "  Claude OAuth - авторизация через браузер" -ForegroundColor Cyan
        Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  Откроется браузер. Завершите авторизацию в нём." -ForegroundColor Yellow
        Write-Host "  Нужна подписка Claude Pro / Max (claude.ai)." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  Запуск..." -ForegroundColor Cyan
        Invoke-CliCommand -ExePath $claudeExe -Arguments @("auth", "login", "--claudeai")
        Write-Host ""
        Write-Host "  Текущий статус:" -ForegroundColor Green
        Invoke-CliCommand -ExePath $claudeExe -Arguments @("auth", "status")
        Write-Host ""
        Write-Host "Нажмите любую клавишу для возврата в меню…" -ForegroundColor Green
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
      }
      "anthropic-console" {
        Clear-Host
        Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host "  Anthropic Console - авторизация через браузер" -ForegroundColor Cyan
        Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  Откроется браузер. Завершите авторизацию." -ForegroundColor Yellow
        Write-Host "  Нужен аккаунт на console.anthropic.com." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  Запуск..." -ForegroundColor Cyan
        Invoke-CliCommand -ExePath $claudeExe -Arguments @("auth", "login", "--console")
        Write-Host ""
        Write-Host "  Текущий статус:" -ForegroundColor Green
        Invoke-CliCommand -ExePath $claudeExe -Arguments @("auth", "status")
        Write-Host ""
        Write-Host "Нажмите любую клавишу для возврата в меню…" -ForegroundColor Green
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
      }
      "vanilla" {
        Clear-Host
        Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host "  Запуск Claude Code (ванильный запуск)" -ForegroundColor Cyan
        Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  Команда: claude" -ForegroundColor Yellow
        Write-Host ""
        Invoke-CliCommand -ExePath $claudeExe
        Write-Host ""
        Write-Host "Нажмите любую клавишу для возврата в меню…" -ForegroundColor Green
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
      }
    }
    continue
  }

  if ($profileId -eq "change-api-key") {
    Show-ApiKeyChangeMenu -AppBrand "Claude"
    continue
  }

  if ($profileId -eq "last") {
    $st = Get-LauncherState
    $profileId = Resolve-ProfileFromState $st
    if (-not $profileId) {
      Write-Host "Сохранённый профиль не найден. Выберите пункт меню один раз." -ForegroundColor Red
      Write-Host "Нажмите любую клавишу..."
      $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
      continue
    }
  } else {
    Save-LauncherState -ProfileId $profileId
  }

  try { Invoke-ClaudeCloudProfile -ProfileId $profileId } catch { Write-Host "" }
  continue
}
