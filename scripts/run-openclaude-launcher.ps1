[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "launcher-tui.ps1")
. (Join-Path $PSScriptRoot "launcher-api-keys.ps1")
. (Join-Path $PSScriptRoot "launcher-provider-models.ps1")
. (Join-Path $PSScriptRoot "launcher-custom-model-wizard.ps1")

function Resolve-OpenClaudeExe {
  $cmd = Get-Command openclaude.cmd -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  $cmd = Get-Command openclaude -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  foreach ($p in @((Join-Path $env:APPDATA "npm\openclaude.cmd"), (Join-Path $env:APPDATA "npm\openclaude.ps1"))) {
    if (Test-Path -LiteralPath $p) { return $p }
  }
  return ""
}

# Главное меню (8 пунктов — аналогично Qwen/Claude/OpenCode).
$script:Profiles = @(
  @{ Id = "nim-qwen";            Label = "NVIDIA NIM - Qwen3.5-122B-A10B (бесплатный preset)" }
  @{ Id = "group:nim";           Label = "NVIDIA NIM - agentic модели (free)" }
  @{ Id = "group:bai";           Label = "B.AI - agentic модели (api.b.ai/v1)" }
  @{ Id = "group:openrouter";    Label = "OpenRouter - бесплатные agentic" }
  @{ Id = "custom-model";        Label = "Другая модель (каталог Z.AI / NIM / B.AI / OpenRouter)" }
  @{ Id = "provider-setup";      Label = "OpenClaude /provider setup (интерактивный выбор)" }
  @{ Id = "vanilla";             Label = "Запустить OpenClaude без presetа" }
  @{ Id = "change-api-key";      Label = "Сменить ключ API провайдера" }
)

# Подменю для каждой группы провайдера
$script:GroupMenus = @{
  nim = @(
    @{ Id = "nim-qwen3.5-122b";    Label = "NIM - Qwen3.5-122B-A10B (free, baseline)" }
    @{ Id = "nim-mistral-medium";  Label = "NIM - Mistral Medium 3.5 128B (free, agentic)" }
    @{ Id = "nim-glm51";           Label = "NIM - Z.AI GLM-5.1 (free, agentic)" }
    @{ Id = "nim-deepseek-v4";     Label = "NIM - DeepSeek V4 Flash 284B MoE (free)" }
  )
  bai = @(
    @{ Id = "bai-gpt-5.5";           Label = "B.AI - GPT-5.5 (OpenAI, agentic)" }
    @{ Id = "bai-claude-sonnet-4.6"; Label = "B.AI - Claude Sonnet 4.6 (Anthropic, agentic)" }
    @{ Id = "bai-deepseek-v4-pro";   Label = "B.AI - DeepSeek V4 Pro (agentic)" }
    @{ Id = "bai-glm-5.1";           Label = "B.AI - GLM-5.1 (Z.AI)" }
    @{ Id = "bai-kimi-k2.6";         Label = "B.AI - Kimi K2.6 (Moonshot)" }
  )
  openrouter = @(
    @{ Id = "openrouter-laguna"; Label = "OpenRouter - Poolside Laguna M.1 (free, coding)" }
    @{ Id = "openrouter-qwen3-coder"; Label = "OpenRouter - Qwen3 Coder (free)" }
  )
}

# Характеристики моделей для OPENAI_BASE_URL / OPENAI_MODEL env preset.
$script:PresetSpec = @{
  "nim-qwen3.5-122b" = @{ Base = "https://integrate.api.nvidia.com/v1"; Model = "qwen/qwen3.5-122b-a10b";        KeyEnv = "NVIDIA_NIM_API_KEY" }
  "nim-mistral-medium" = @{ Base = "https://integrate.api.nvidia.com/v1"; Model = "mistralai/mistral-medium-3.5-128b"; KeyEnv = "NVIDIA_NIM_API_KEY" }
  "nim-glm51" = @{ Base = "https://integrate.api.nvidia.com/v1"; Model = "z-ai/glm-5.1";                          KeyEnv = "NVIDIA_NIM_API_KEY" }
  "nim-deepseek-v4" = @{ Base = "https://integrate.api.nvidia.com/v1"; Model = "deepseek-ai/deepseek-v4-flash";    KeyEnv = "NVIDIA_NIM_API_KEY" }
  "bai-gpt-5.5" = @{ Base = "https://api.b.ai/v1"; Model = "gpt-5.5";                                              KeyEnv = "BAI_API_KEY" }
  "bai-claude-sonnet-4.6" = @{ Base = "https://api.b.ai/v1"; Model = "claude-sonnet-4.6";                          KeyEnv = "BAI_API_KEY" }
  "bai-deepseek-v4-pro" = @{ Base = "https://api.b.ai/v1"; Model = "deepseek-v4-pro";                              KeyEnv = "BAI_API_KEY" }
  "bai-glm-5.1" = @{ Base = "https://api.b.ai/v1"; Model = "glm-5.1";                                              KeyEnv = "BAI_API_KEY" }
  "bai-kimi-k2.6" = @{ Base = "https://api.b.ai/v1"; Model = "kimi-k2.6";                                          KeyEnv = "BAI_API_KEY" }
  "openrouter-laguna" = @{ Base = "https://openrouter.ai/api/v1"; Model = "poolside/laguna-m.1:free";              KeyEnv = "OPENROUTER_API_KEY" }
  "openrouter-qwen3-coder" = @{ Base = "https://openrouter.ai/api/v1"; Model = "qwen/qwen3-coder:free";            KeyEnv = "OPENROUTER_API_KEY" }
  # Обратная совместимость
  "nim-qwen" = @{ Base = "https://integrate.api.nvidia.com/v1"; Model = "qwen/qwen3.5-122b-a10b"; KeyEnv = "NVIDIA_NIM_API_KEY" }
}

function Invoke-OpenClaudeExe {
  param([string]$PresetId = "")
  $exe = Resolve-OpenClaudeExe
  if (-not $exe) { throw "OpenClaude CLI не найден. Установите: npm install -g @gitlawb/openclaude" }

  if ([string]::IsNullOrWhiteSpace($PresetId)) {
    Clear-Host
    Write-Host "Запуск OpenClaude (vanilla)..." -ForegroundColor Cyan
    & $exe
    return
  }

  $spec = $script:PresetSpec[$PresetId]
  if (-not $spec) {
    Write-Host "Неизвестный preset: $PresetId" -ForegroundColor Red
    Start-Sleep -Seconds 2
    return
  }

  $key = [Environment]::GetEnvironmentVariable($spec.KeyEnv, "User")
  if ([string]::IsNullOrWhiteSpace($key) -or $key -eq "__SET_ME__") { $key = (Get-ChildItem env: | Where-Object { $_.Name -eq $spec.KeyEnv } | Select-Object -First 1).Value }
  if ([string]::IsNullOrWhiteSpace($key) -or $key -eq "__SET_ME__") {
    $providerName = switch -Wildcard ($spec.KeyEnv) {
      "NVIDIA*" { "NVIDIA NIM" }
      "BAI*"    { "B.AI" }
      "OPENROUTER*" { "OpenRouter" }
      default   { $spec.KeyEnv }
    }
    $helpUrl = switch ($providerName) {
      "NVIDIA NIM" { "https://build.nvidia.com/api-key" }
      "B.AI"       { "https://chat.b.ai/key" }
      "OpenRouter" { "https://openrouter.ai/settings/keys" }
      default      { "" }
    }
    $key = Resolve-ApiKeyOrPrompt -CurrentKey $key -ProviderName $providerName -HelpUrl $helpUrl
  }

  $env:CLAUDE_CODE_USE_OPENAI = "1"
  $env:OPENAI_API_KEY = $key
  $env:OPENAI_BASE_URL = $spec.Base
  $env:OPENAI_MODEL = $spec.Model

  Clear-Host
  Write-Host "Запуск OpenClaude..." -ForegroundColor Cyan
  Write-Host "Provider: $($spec.Base) | Model: $($spec.Model)" -ForegroundColor DarkGray
  & $exe
}

# Главное меню loop
while ($true) {
  $choice = Show-TuiFramedMenu -AppBrand "OpenClaude" -Title "OpenClaude - выбор профиля" -Subtitle "NIM · B.AI · OpenRouter (OpenAI-compatible → Anthropic transport)" -Items $script:Profiles -MaxVisible 14
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
      "nim"        { "NVIDIA NIM - бесплатные agentic модели" }
      "bai"        { "B.AI - https://api.b.ai/v1 (OpenAI-compatible)" }
      "openrouter" { "OpenRouter - бесплатные модели (free tier)" }
      default      { "" }
    }
    $subChoice = Show-TuiFramedMenu -AppBrand "OpenClaude" -Title ("OpenClaude - {0}" -f $groupKey.ToUpper()) -Subtitle $subTitle -Items $groupItems -MaxVisible 14 -EscapeAction Back
    if ($null -eq $subChoice) { continue }
    if ($true -eq $subChoice.__menuBack) { continue }
    Invoke-OpenClaudeExe -PresetId ([string]$subChoice.Id)
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
    $spec = switch ($w.Provider) {
      "nim"        { @{ Base = "https://integrate.api.nvidia.com/v1"; Model = $mid; KeyEnv = "NVIDIA_NIM_API_KEY" } }
      "openrouter" { @{ Base = "https://openrouter.ai/api/v1";          Model = $mid; KeyEnv = "OPENROUTER_API_KEY" } }
      "bai"        { @{ Base = "https://api.b.ai/v1";                    Model = $mid; KeyEnv = "BAI_API_KEY" } }
      "groq"       { @{ Base = "https://api.groq.com/openai/v1";         Model = $mid; KeyEnv = "GROQ_API_KEY" } }
      default      { @{ Base = "https://integrate.api.nvidia.com/v1";    Model = $mid; KeyEnv = "NVIDIA_NIM_API_KEY" } }
    }
    $key = [Environment]::GetEnvironmentVariable($spec.KeyEnv, "User")
    if ([string]::IsNullOrWhiteSpace($key) -or $key -eq "__SET_ME__") { $key = (Get-ChildItem env: | Where-Object { $_.Name -eq $spec.KeyEnv } | Select-Object -First 1).Value }
    if ([string]::IsNullOrWhiteSpace($key) -or $key -eq "__SET_ME__") {
      $providerName = switch ($w.Provider) { "nim" { "NVIDIA NIM" }; "bai" { "B.AI" }; "openrouter" { "OpenRouter" }; "groq" { "Groq" }; default { "Provider" } }
      $helpUrl = switch ($w.Provider) { "nim" { "https://build.nvidia.com/api-key" }; "bai" { "https://chat.b.ai/key" }; "openrouter" { "https://openrouter.ai/settings/keys" }; "groq" { "https://console.groq.com/keys" }; default { "" } }
      $key = Resolve-ApiKeyOrPrompt -CurrentKey $key -ProviderName $providerName -HelpUrl $helpUrl
    }
    $env:CLAUDE_CODE_USE_OPENAI = "1"
    $env:OPENAI_API_KEY = $key
    $env:OPENAI_BASE_URL = $spec.Base
    $env:OPENAI_MODEL = $spec.Model
    Clear-Host
    Write-Host "Запуск OpenClaude..." -ForegroundColor Cyan
    Write-Host "Provider: $($spec.Base) | Model: $($spec.Model)" -ForegroundColor DarkGray
    $exe = Resolve-OpenClaudeExe
    if (-not $exe) { throw "OpenClaude CLI не найден. Установите: npm install -g @gitlawb/openclaude" }
    & $exe
    continue
  }

  if ($profileId -eq "provider-setup") {
    Write-Host "После запуска выполните /provider для настройки профиля." -ForegroundColor Cyan
    Start-Sleep -Seconds 1
    Remove-Item Env:OPENAI_BASE_URL, Env:OPENAI_MODEL, Env:CLAUDE_CODE_USE_OPENAI -ErrorAction SilentlyContinue
    Invoke-OpenClaudeExe
    continue
  }

  if ($profileId -eq "vanilla") {
    Remove-Item Env:OPENAI_BASE_URL, Env:OPENAI_MODEL, Env:CLAUDE_CODE_USE_OPENAI -ErrorAction SilentlyContinue
    Invoke-OpenClaudeExe
    continue
  }

  if ($profileId -eq "change-api-key") {
    Show-ApiKeyChangeMenu -AppBrand "OpenClaude"
    continue
  }

  # Прямой preset (включая legacy nim-qwen)
  Invoke-OpenClaudeExe -PresetId $profileId
  continue
}
