# Dot-source из лаунчеров: списки моделей по API-ключу (Z.AI Coding, NVIDIA NIM).

function Test-TcpPortListening([int]$Port) {
  try {
    $c = @(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Where-Object { $_.LocalAddress -eq "127.0.0.1" -and $_.LocalPort -eq $Port })
    return ($c.Count -gt 0)
  } catch {
    return $false
  }
}

function Get-LauncherFreeTcpPort {
  param(
    [int]$Min = 8090,
    [int]$Max = 8140
  )
  for ($p = $Min; $p -le $Max; $p++) {
    if (-not (Test-TcpPortListening -Port $p)) { return $p }
  }
  throw "Не найден свободный TCP-порт на 127.0.0.1 в диапазоне $Min..$Max"
}

function Invoke-LauncherJsonGet {
  param(
    [Parameter(Mandatory = $true)][string]$Uri,
    [hashtable]$Headers = @{},
    [int]$TimeoutSec = 25
  )
  $iwr = Get-Command Invoke-WebRequest -ErrorAction Stop
  $useBasic = $iwr.Parameters.ContainsKey("UseBasicParsing")
  $params = @{
    Uri             = $Uri
    Method          = "Get"
    TimeoutSec      = $TimeoutSec
    ErrorAction     = "Stop"
  }
  if ($Headers.Count -gt 0) { $params.Headers = $Headers }
  if ($useBasic) { $params.UseBasicParsing = $true }
  $resp = Invoke-WebRequest @params
  return ($resp.Content | ConvertFrom-Json)
}

# У NVIDIA NIM (integrate OpenAI) нативный tool calling в Qwen Code имеет смысл только для моделей,
# явно помеченных в каталоге как Tool Calling / strict function calling (по списку пользователя).
# Для всех остальных NIM-моделей: в run-qwen-code-dynamic.ps1 — tool_choice=none, локальный прокси
# nim-integrate-string-content-proxy.mjs (content → string, trim messages по ctx tier), model.skipStartupContext; эвристика tier
# micro/standard/large (contextWindowSize + max_tokens) в run-qwen-code-dynamic.ps1; в free-claude-code
# providers/nvidia_nim/request.py — tool_choice=none, flatten content, cap max_tokens по тем же tier; custom Claude NIM —
# в run-claude-cloud-launcher.ps1 --tools minimal. Префикс nvidia_nim/ учитывается в Test-NvidiaNimOpenAiNativeToolCalling.
# чтобы не слать tool_choice=auto (ошибка vLLM 400 про --enable-auto-tool-choice).
function Test-NvidiaNimOpenAiNativeToolCalling {
  param([Parameter(Mandatory = $true)][string]$ModelId)
  $norm = $ModelId.Trim().ToLowerInvariant()
  while ($norm.StartsWith("nvidia_nim/")) {
    $norm = $norm.Substring("nvidia_nim/".Length)
  }
  foreach ($id in @(
      "z-ai/glm4.7"
      "qwen/qwen3.5-122b-a10b"
      "deepseek-ai/deepseek-v3.1-terminus"
    )) {
    if ($norm -eq $id) { return $true }
  }
  return $false
}

# Список free / preview NIM (вручную по каталогу build.nvidia.com, nim_type_preview).
# Обновляйте при необходимости: https://build.nvidia.com/models?filters=nimType%3Anim_type_preview
function Get-NvidiaNimBundledFreeModelIds {
  $raw = @(
    "z-ai/glm4.7"
    "z-ai/glm5"
    "z-ai/glm-5.1"
    "nvidia/nemotron-3-content-safety"
    "nvidia/synthetic-video-detector"
    "nvidia/active-speaker-detection"
    "minimaxai/minimax-m2.7"
    "nvidia/nemotron-voicechat"
    "nvidia/gliner-pii"
    "nvidia/cosmos-transfer2.5-2b"
    "stepfun-ai/step-3.5-flash"
    "nvidia/nemotron-content-safety-reasoning-4b"
    "deepseek-ai/deepseek-v3.2"
    "nvidia/riva-translate-4b-instruct-v1.1"
    "mistralai/devstral-2-123b-instruct-2512"
    "moonshotai/kimi-k2-thinking"
    "mistralai/mistral-large-3-675b-instruct-2512"
    "nvidia/streampetr"
    "nvidia/llama-3.1-nemotron-safety-guard-8b-v3"
    "deepseek-ai/deepseek-v3.1-terminus"
    "moonshotai/kimi-k2-instruct-0905"
    "bytedance/seed-oss-36b-instruct"
    "qwen/qwen3-coder-480b-a35b-instruct"
    "nvidia/llama-3_2-nemoretriever-300m-embed-v1"
    "moonshotai/kimi-k2-instruct"
    "mistralai/magistral-small-2506"
    "meta/llama-guard-4-12b"
    "google/gemma-3n-e4b-it"
    "google/gemma-3n-e2b-it"
    "nvidia/cosmos-transfer1-7b"
    "mistralai/mistral-nemotron"
    "nvidia/magpie-tts-zeroshot"
    "mistralai/mistral-medium-3-instruct"
    "meta/llama-4-maverick-17b-128e-instruct"
    "nvidia/cosmos-predict1-5b"
    "nvidia/sparsedrive"
    "nvidia/bevformer"
    "nvidia/nv-embedcode-7b-v1"
    "google/gemma-3-27b-it"
    "microsoft/phi-4-multimodal-instruct"
    "nvidia/usdcode"
    "nvidia/studiovoice"
    "abacusai/dracarys-llama-3.1-70b-instruct"
    "meta/esm2-650m"
    "nvidia/nemotron-mini-4b-instruct"
    "google/gemma-2-2b-it"
    "nvidia/usdvalidate"
    "nvidia/nv-embed-v1"
    "upstage/solar-10.7b-instruct"
    "google/paligemma"
    "nvidia/rerank-qa-mistral-4b"
    "meta/esmfold"
  )
  return ($raw | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Sort-Object -Unique)
}

function Get-NvidiaNimModelIdsFromApi {
  param(
    [Parameter(Mandatory = $true)][string]$ApiKey,
    # Оставить только те ID, что есть и в ответе API, и во встроенном каталоге free/preview.
    [switch]$FilterToBundledFreeCatalog
  )
  $h = @{ Authorization = "Bearer $($ApiKey.Trim())" }
  $j = Invoke-LauncherJsonGet -Uri "https://integrate.api.nvidia.com/v1/models" -Headers $h
  if (-not $j.data) { return @() }
  $ids = [System.Collections.Generic.List[string]]::new()
  foreach ($row in @($j.data)) {
    $id = [string]$row.id
    if (-not [string]::IsNullOrWhiteSpace($id)) { $ids.Add($id.Trim()) | Out-Null }
  }
  $out = $ids | Sort-Object -Unique
  if ($FilterToBundledFreeCatalog) {
    $allow = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($x in @(Get-NvidiaNimBundledFreeModelIds)) { [void]$allow.Add($x) }
    $out = $out | Where-Object { $allow.Contains($_) }
  }
  return $out
}

function Get-ZaiCodingModelIdsFromApi {
  param([Parameter(Mandatory = $true)][string]$ApiKey)
  $h = @{ Authorization = "Bearer $($ApiKey.Trim())" }
  $uris = @(
    "https://api.z.ai/api/coding/paas/v4/models",
    "https://api.z.ai/api/paas/v4/models"
  )
  foreach ($u in $uris) {
    try {
      $j = Invoke-LauncherJsonGet -Uri $u -Headers $h -TimeoutSec 20
      if ($j.data) {
        $ids = [System.Collections.Generic.List[string]]::new()
        foreach ($row in @($j.data)) {
          $id = [string]$row.id
          if (-not [string]::IsNullOrWhiteSpace($id)) { $ids.Add($id.Trim()) | Out-Null }
        }
        if ($ids.Count -gt 0) { return ($ids | Sort-Object -Unique) }
      }
    } catch {
      continue
    }
  }
  return @(
    "glm-4.7", "glm-4.7-flash", "glm-4.7-flashx",
    "glm-4.6", "glm-4.6v", "glm-4.5", "glm-4.5-air", "glm-4.5-flash", "glm-4.5v",
    "glm-5", "glm-5-turbo", "glm-5.1", "glm-5v-turbo"
  )
}

function Resolve-NvidiaNimFreeClaudeModel {
  param([Parameter(Mandatory = $true)][string]$OpenAiModelId)
  $m = $OpenAiModelId.Trim().Trim("/")
  if ($m.StartsWith("nvidia_nim/", [StringComparison]::OrdinalIgnoreCase)) { return $m }
  return ("nvidia_nim/{0}" -f $m)
}
