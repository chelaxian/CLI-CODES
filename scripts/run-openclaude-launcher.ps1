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

# Главное меню (8 пунктов — Z.AI на первом месте как наиболее совместимый).
$script:Profiles = @(
  @{ Id = "group:zai";        Label = "Z.AI - Anthropic (GLM-5.1 / GLM-4.7 / Flash) — работает через env" }
  @{ Id = "group:nim";        Label = "NVIDIA NIM - agentic модели (требует /provider setup)" }
  @{ Id = "group:bai";        Label = "B.AI - agentic модели (требует /provider setup)" }
  @{ Id = "group:openrouter"; Label = "OpenRouter - бесплатные agentic (требует /provider setup)" }
  @{ Id = "custom-model";     Label = "Другая модель (каталог Z.AI / NIM / B.AI / OpenRouter)" }
  @{ Id = "provider-setup";   Label = "OpenClaude /provider setup (интерактивный выбор)" }
  @{ Id = "vanilla";          Label = "Запустить OpenClaude без presetа" }
  @{ Id = "change-api-key";   Label = "Сменить ключ API провайдера" }
)

# Подменю для каждой группы провайдера
$script:GroupMenus = @{
  zai = @(
    @{ Id = "zai-glm51";   Label = "Z.AI - GLM-5.1 (paid, Anthropic-compatible, full tool support)" }
    @{ Id = "zai-glm47";   Label = "Z.AI - GLM-4.7 (paid, Anthropic-compatible, tool support)" }
    @{ Id = "zai-flash47"; Label = "Z.AI - GLM-4.7-Flash (free, Anthropic-compatible)" }
  )
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
    @{ Id = "openrouter-laguna";     Label = "OpenRouter - Poolside Laguna M.1 (free, coding)" }
    @{ Id = "openrouter-qwen3-coder"; Label = "OpenRouter - Qwen3 Coder (free)" }
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

  $exe = Resolve-OpenClaudeExe
  if (-not $exe) { throw "OpenClaude CLI не найден. Установите: npm install -g @gitlawb/openclaude" }

  Clear-Host
  Write-Host "Запуск OpenClaude (Z.AI)..." -ForegroundColor Cyan
  Write-Host "Model: $($zSpec.Model) | Endpoint: https://api.z.ai/api/anthropic" -ForegroundColor DarkGray
  & $exe
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

  $exe = Resolve-OpenClaudeExe
  if (-not $exe) { throw "OpenClaude CLI не найден. Установите: npm install -g @gitlawb/openclaude" }

  Clear-Host
  Write-Host "Запуск OpenClaude..." -ForegroundColor Cyan
  Write-Host "Provider: $($spec.Base) | Model: $($spec.Model)" -ForegroundColor DarkGray
  Write-Host "Подсказка: если OpenClaude не увидел preset, запустите /provider setup внутри CLI" -ForegroundColor Yellow
  & $exe
}

# Главное меню loop
while ($true) {
  $choice = Show-TuiFramedMenu -AppBrand "OpenClaude" -Title "OpenClaude - выбор профиля" -Subtitle "Z.AI (Anthropic) · NIM/B.AI/OpenRouter (через /provider)" -Items $script:Profiles -MaxVisible 14
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
      "zai"        { "Z.AI - Anthropic-compatible (работает через env без /provider)" }
      "nim"        { "NVIDIA NIM - OpenAI-compatible (нужен /provider setup)" }
      "bai"        { "B.AI - https://api.b.ai/v1 (нужен /provider setup)" }
      "openrouter" { "OpenRouter - бесплатные модели (нужен /provider setup)" }
      default      { "" }
    }
    $subChoice = Show-TuiFramedMenu -AppBrand "OpenClaude" -Title ("OpenClaude - {0}" -f $groupKey.ToUpper()) -Subtitle $subTitle -Items $groupItems -MaxVisible 14 -EscapeAction Back
    if ($null -eq $subChoice) { continue }
    if ($true -eq $subChoice.__menuBack) { continue }
    $subId = [string]$subChoice.Id

    if ($groupKey -eq "zai") {
      Invoke-OpenClaudeZaiPreset -PresetId $subId
    } else {
      Invoke-OpenClaudeOpenAIPreset -PresetId $subId
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
      Remove-Item Env:CLAUDE_CODE_USE_OPENAI, Env:OPENAI_BASE_URL, Env:OPENAI_MODEL, Env:OPENAI_API_KEY -ErrorAction SilentlyContinue
      $env:ANTHROPIC_API_KEY = $key
      Remove-Item Env:ANTHROPIC_AUTH_TOKEN -ErrorAction SilentlyContinue
      $env:ANTHROPIC_BASE_URL = "https://api.z.ai/api/anthropic"
      $env:API_TIMEOUT_MS = "3000000"
      $env:ANTHROPIC_DEFAULT_OPUS_MODEL = $mid
      $env:ANTHROPIC_DEFAULT_SONNET_MODEL = $mid
      $env:ANTHROPIC_DEFAULT_HAIKU_MODEL = $mid

      $exe = Resolve-OpenClaudeExe
      if (-not $exe) { throw "OpenClaude CLI не найден. Установите: npm install -g @gitlawb/openclaude" }
      Clear-Host
      Write-Host "Запуск OpenClaude (Z.AI custom)..." -ForegroundColor Cyan
      Write-Host "Model: $mid | Endpoint: https://api.z.ai/api/anthropic" -ForegroundColor DarkGray
      & $exe
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
      if ([string]::IsNullOrWhiteSpace($key) -or $key -eq "__SET_ME__") {
        $providerName = switch ($w.Provider) { "nim" { "NVIDIA NIM" }; "bai" { "B.AI" }; "openrouter" { "OpenRouter" }; "groq" { "Groq" }; default { "Provider" } }
        $helpUrl = switch ($w.Provider) { "nim" { "https://build.nvidia.com/api-key" }; "bai" { "https://chat.b.ai/key" }; "openrouter" { "https://openrouter.ai/settings/keys" }; "groq" { "https://console.groq.com/keys" }; default { "" } }
        $key = Resolve-ApiKeyOrPrompt -CurrentKey $key -ProviderName $providerName -HelpUrl $helpUrl
      }
      Remove-Item Env:ANTHROPIC_BASE_URL, Env:ANTHROPIC_API_KEY, Env:ANTHROPIC_AUTH_TOKEN -ErrorAction SilentlyContinue
      Remove-Item Env:ANTHROPIC_DEFAULT_OPUS_MODEL, Env:ANTHROPIC_DEFAULT_SONNET_MODEL, Env:ANTHROPIC_DEFAULT_HAIKU_MODEL -ErrorAction SilentlyContinue
      $env:CLAUDE_CODE_USE_OPENAI = "1"
      $env:OPENAI_API_KEY = $key
      $env:OPENAI_BASE_URL = $spec.Base
      $env:OPENAI_MODEL = $mid
      $exe = Resolve-OpenClaudeExe
      if (-not $exe) { throw "OpenClaude CLI не найден. Установите: npm install -g @gitlawb/openclaude" }
      Clear-Host
      Write-Host "Запуск OpenClaude..." -ForegroundColor Cyan
      Write-Host "Provider: $($spec.Base) | Model: $mid" -ForegroundColor DarkGray
      Write-Host "Подсказка: если OpenClaude не увидел preset, запустите /provider setup внутри CLI" -ForegroundColor Yellow
      & $exe
    }
    continue
  }

  if ($profileId -eq "provider-setup") {
    Write-Host "После запуска выполните /provider для настройки профиля." -ForegroundColor Cyan
    Write-Host "Это сохранит выбранный провайдер в конфиг OpenClaude (~/.openclaude/)." -ForegroundColor DarkGray
    Start-Sleep -Seconds 2
    Remove-Item Env:OPENAI_BASE_URL, Env:OPENAI_MODEL, Env:CLAUDE_CODE_USE_OPENAI, Env:ANTHROPIC_BASE_URL, Env:ANTHROPIC_API_KEY -ErrorAction SilentlyContinue
    $exe = Resolve-OpenClaudeExe
    if (-not $exe) { throw "OpenClaude CLI не найден. Установите: npm install -g @gitlawb/openclaude" }
    Clear-Host
    Write-Host "Запуск OpenClaude (vanilla для /provider setup)..." -ForegroundColor Cyan
    & $exe
    continue
  }

  if ($profileId -eq "vanilla") {
    Remove-Item Env:OPENAI_BASE_URL, Env:OPENAI_MODEL, Env:CLAUDE_CODE_USE_OPENAI, Env:OPENAI_API_KEY, Env:ANTHROPIC_BASE_URL, Env:ANTHROPIC_API_KEY, Env:ANTHROPIC_AUTH_TOKEN, Env:ANTHROPIC_DEFAULT_OPUS_MODEL, Env:ANTHROPIC_DEFAULT_SONNET_MODEL, Env:ANTHROPIC_DEFAULT_HAIKU_MODEL -ErrorAction SilentlyContinue
    $exe = Resolve-OpenClaudeExe
    if (-not $exe) { throw "OpenClaude CLI не найден. Установите: npm install -g @gitlawb/openclaude" }
    Clear-Host
    Write-Host "Запуск OpenClaude (vanilla)..." -ForegroundColor Cyan
    & $exe
    continue
  }

  if ($profileId -eq "change-api-key") {
    Show-ApiKeyChangeMenu -AppBrand "OpenClaude"
    continue
  }
}
