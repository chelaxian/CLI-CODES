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

$StatePath = Join-Path $PSScriptRoot "claude-cloud-launcher-state.json"
$SessionScript = Join-Path $PSScriptRoot "run-claude-cloud-session.ps1"

function Ensure-NpmBinInPath {
  $npmBin = Join-Path $env:APPDATA "npm"
  if ($npmBin -and (Test-Path -LiteralPath $npmBin)) {
    $parts = @($env:PATH -split ';' | Where-Object { $_ -and $_.Trim().Length -gt 0 })
    if (-not ($parts | Where-Object { $_.TrimEnd('\') -ieq $npmBin.TrimEnd('\') })) {
      $env:PATH = $npmBin + ";" + $env:PATH
    }
  }
}

function Resolve-ClaudeExe {
  Ensure-NpmBinInPath
  $cmd = Get-Command claude.cmd -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  $cmd = Get-Command claude -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  foreach ($p in @(
      (Join-Path $env:APPDATA "npm\claude.cmd"),
      (Join-Path $env:APPDATA "npm\claude.ps1")
    )) {
    if (Test-Path -LiteralPath $p) { return $p }
  }
  return ""
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
    Label = "Z.AI - модели (GLM-5.1 / GLM-4.7 / GLM-4.7-Flash)"
  }
  @{
    Id    = "group:nim"
    Label = "NVIDIA NIM - 9 бесплатных agentic моделей"
  }
  @{
    Id    = "group:openrouter"
    Label = "OpenRouter - бесплатные agentic модели"
  }
  @{
    Id    = "group:bai"
    Label = "B.AI - DeepSeek/MiniMax/GLM/Kimi/GPT (Anthropic-compatible)"
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
    @{ Id = "claude-zai-flash47"; Label = "Z.AI - GLM-4.7-Flash (free, tool calling)" }
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
  openrouter = @(
    @{ Id = "claude-openrouter-deepseek-v4-flash"; Label = "OpenRouter - DeepSeek V4 Flash (free, tool calling)" }
    @{ Id = "claude-openrouter-qwen3-coder";       Label = "OpenRouter - Qwen3 Coder (free, tool calling)" }
    @{ Id = "claude-openrouter-nemotron";          Label = "OpenRouter - Nemotron 3 Super 120B (free, tool calling)" }
    @{ Id = "claude-openrouter-laguna";            Label = "OpenRouter - Poolside Laguna M.1 (free, tool calling, coding)" }
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
    @{ Id = "claude-bai-deepseek-v4-pro";   Label = "B.AI - DeepSeek V4 Pro (agentic) [use OpenClaude]" }
    @{ Id = "claude-bai-deepseek-v4-flash"; Label = "B.AI - DeepSeek V4 Flash (agentic) [use OpenClaude]" }
    @{ Id = "claude-bai-gemini-3.1-pro";    Label = "B.AI - Gemini 3.1 Pro (Google, agentic) [use OpenClaude]" }
    @{ Id = "claude-bai-gemini-3.5-flash";  Label = "B.AI - Gemini 3.5 Flash (Google, agentic) [use OpenClaude]" }
    @{ Id = "claude-bai-glm-5";             Label = "B.AI - GLM-5 (Z.AI) [use OpenClaude]" }
    @{ Id = "claude-bai-glm-5.1";           Label = "B.AI - GLM-5.1 (Z.AI) [use OpenClaude]" }
    @{ Id = "claude-bai-kimi-k2.5";         Label = "B.AI - Kimi K2.5 (Moonshot) [use OpenClaude]" }
    @{ Id = "claude-bai-minimax-m3";        Label = "B.AI - MiniMax M3 (agentic) [use OpenClaude]" }
    @{ Id = "claude-bai-minimax-m2.7";      Label = "B.AI - MiniMax M2.7 (fast) [use OpenClaude]" }
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
    "claude-openrouter-hy3" {
      & $SessionScript -Provider openrouter -ZaiAnthropicModelId "deepseek/deepseek-chat-v3.1:free" -ClaudeTools default `
        -ClaudeMemMaxWaitSec 25 -SkipCommonPreamble
      return
    }
    "claude-openrouter-deepseek-v4-flash" {
      & $SessionScript -Provider openrouter -ZaiAnthropicModelId "deepseek/deepseek-chat-v3.1:free" -ClaudeTools default `
        -ClaudeMemMaxWaitSec 25 -SkipCommonPreamble
      return
    }
    "claude-openrouter-qwen3-coder" {
      & $SessionScript -Provider openrouter -ZaiAnthropicModelId "qwen/qwen3-coder:free" -ClaudeTools default `
        -ClaudeMemMaxWaitSec 25 -SkipCommonPreamble
      return
    }
    "claude-openrouter-nemotron" {
      & $SessionScript -Provider openrouter -ZaiAnthropicModelId "nvidia/nemotron-3-super-120b-a12b:free" -ClaudeTools default `
        -ClaudeMemMaxWaitSec 25 -SkipCommonPreamble
      return
    }
    "claude-openrouter-laguna" {
      & $SessionScript -Provider openrouter -ZaiAnthropicModelId "poolside/laguna-m.1:free" -ClaudeTools default `
        -ClaudeMemMaxWaitSec 25 -SkipCommonPreamble
      return
    }
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
      Write-Host ""
      Write-Host "B.AI в Claude Code не поддерживается." -ForegroundColor Yellow
      Write-Host "Используйте OpenClaude launcher (там работает через нативный provider profile)." -ForegroundColor Cyan
      Write-Host "Нажмите любую клавишу для возврата в меню…" -ForegroundColor DarkGray
      [void][Console]::ReadKey($true)
      return
    }
    default {
      if ($ProfileId -like "claude-bai-*") {
        # B.AI в Claude Code v2.x не поддерживается: native binary не умеет
        # OpenAI-compat, а free-claude-code не имеет b_ai provider и не разрешает
        # переопределять base_url для nvidia_nim/open_router. Используйте OpenClaude.
        Write-Host ""
        Write-Host "B.AI в Claude Code не поддерживается." -ForegroundColor Yellow
        Write-Host "Причина: Claude Code v2.x native binary не умеет OpenAI-compat провайдеры напрямую," -ForegroundColor DarkGray
        Write-Host "        а free-claude-code не имеет provider 'b_ai' и не позволяет переопределить base URL." -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "Запустите лаунчер OpenClaude и выберите B.AI там — там работает." -ForegroundColor Cyan
        Write-Host "Нажмите любую клавишу для возврата в меню…" -ForegroundColor DarkGray
        [void][Console]::ReadKey($true)
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
  Invoke-ClaudeCloudProfile -ProfileId $resolvedId
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

while ($true) {
  $choice = Show-TuiFramedMenu -AppBrand "Claude" -Title "Claude Code (облако) - провайдер" -Subtitle "Z.AI · NIM · OpenRouter · B.AI (через free-claude-code)" -Items $items -InitialIndex $startIdx -MaxVisible 20
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
      "openrouter" { "OpenRouter - бесплатные agentic модели" }
      "bai"        { "B.AI - https://api.b.ai/v1 (OpenAI-compatible)" }
      default      { "" }
    }
    $subChoice = Show-TuiFramedMenu -AppBrand "Claude" -Title ("Claude Code - {0}" -f $groupKey.ToUpper()) -Subtitle $subTitle -Items $groupItems -MaxVisible 16 -EscapeAction Back
    if ($null -eq $subChoice) { continue }
    if ($true -eq $subChoice.__menuBack) { continue }
    $profileId = [string]$subChoice.Id
    Save-LauncherState -ProfileId $profileId
    Invoke-ClaudeCloudProfile -ProfileId $profileId
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
        Invoke-ClaudeCloudProfile -ProfileId "custom-claude-zai"
      }
      "openrouter" {
        Save-LauncherState -ProfileId "custom-claude-openrouter" -Extra @{ customModelId = [string]$w.ModelId }
        Invoke-ClaudeCloudProfile -ProfileId "custom-claude-openrouter"
      }
      "bai" {
        Save-LauncherState -ProfileId "custom-claude-bai" -Extra @{ customModelId = [string]$w.ModelId }
        Invoke-ClaudeCloudProfile -ProfileId "custom-claude-bai"
      }
      default {
        Save-LauncherState -ProfileId "custom-claude-nim" -Extra @{ customNimModel = [string]$w.ClaudeNimModel }
        Invoke-ClaudeCloudProfile -ProfileId "custom-claude-nim"
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

  Invoke-ClaudeCloudProfile -ProfileId $profileId
  continue
}
