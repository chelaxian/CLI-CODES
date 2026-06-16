# Single source of truth for model presets used by both Qwen Code and Claude Code launchers.
# Dot-source from run-qwen-code-launcher.ps1 / run-claude-cloud-launcher.ps1.
#
# Two-tier source:
#   1) TXT/catalogs/<provider>.txt   (preferred — human-editable, see TXT/README.txt)
#   2) inline arrays below           (fallback for installs without TXT/ — older builds)
#
# Schema — every entry has at least:
#   InternalId : canonical name without provider prefix ("glm51", "gpt-5-nano", "mistral-medium")
#   Label      : human description used in TUI menu
#   APIModelId : raw API model id sent to provider (may equal InternalId)
#   Ctx        : context window size in tokens (BAI only)
#   Max        : max output tokens (BAI only)
#
# Provider prefixes are added by Get-CatalogMenuItems based on the launcher brand:
#   Qwen    → "zai-", "nim-", "bai-", "openrouter-"
#   Claude  → "claude-zai-", "claude-nim-", "claude-bai-", "claude-openrouter-"
#
# Edit TXT/catalogs/*.txt to modify without touching this file or any launcher.

. (Join-Path $PSScriptRoot "launcher-text-resolver.ps1")

$txtZai        = Get-TextCatalog -Provider zai
$txtNim        = Get-TextCatalog -Provider nim
$txtBai        = Get-TextCatalog -Provider bai
$txtOpenRouter = Get-TextCatalog -Provider openrouter

$script:CatalogZai = if ($txtZai)        { $txtZai }  else {
  @(
    [pscustomobject]@{ InternalId = "glm51";   Label = "GLM-5.1 (paid, tool calling)";       APIModelId = "glm-5.1"       }
    [pscustomobject]@{ InternalId = "glm";     Label = "GLM-4.7 (paid, tool calling)";       APIModelId = "glm-4.7"       }
    [pscustomobject]@{ InternalId = "flash47"; Label = "GLM-4.7-Flash (free)";               APIModelId = "glm-4.7-flash" }
  )
}

$script:CatalogNim = if ($txtNim)        { $txtNim }  else {
  @(
    [pscustomobject]@{ InternalId = "mistral-medium";    Label = "Mistral Medium 3.5 128B (free, tool calling)";      APIModelId = "mistralai/mistral-medium-3.5-128b"           }
    [pscustomobject]@{ InternalId = "glm51";             Label = "Z.AI GLM-5.1 (free, tool calling)";                 APIModelId = "z-ai/glm-5.1"                                }
    [pscustomobject]@{ InternalId = "step-3.5-flash";    Label = "Step 3.5 Flash (free, tool calling)";               APIModelId = "stepfun-ai/step-3.5-flash"                   }
    [pscustomobject]@{ InternalId = "mistral-large-3";   Label = "Mistral Large 3 675B (free, tool calling)";         APIModelId = "mistralai/mistral-large-3-675b-instruct-2512" }
    [pscustomobject]@{ InternalId = "deepseek-v4-flash"; Label = "DeepSeek V4 Flash 284B MoE (free)";                 APIModelId = "deepseek-ai/deepseek-v4-flash"               }
    [pscustomobject]@{ InternalId = "gemma-4-31b";       Label = "Google Gemma-4 31B (free)";                         APIModelId = "google/gemma-4-31b-it"                       }
    [pscustomobject]@{ InternalId = "qwen3.5-397b";      Label = "Qwen 3.5 397B A17B (free)";                         APIModelId = "qwen/qwen3.5-397b-a17b"                      }
    [pscustomobject]@{ InternalId = "qwen3-next-80b";    Label = "Qwen 3 Next 80B A3B (free)";                        APIModelId = "qwen/qwen3-next-80b-a3b-instruct"             }
    [pscustomobject]@{ InternalId = "qwen3-coder-480b";  Label = "Qwen 3 Coder 480B A35B (free)";                     APIModelId = "qwen/qwen3-coder-480b-a35b-instruct"          }
  )
}

# 26 BAI agentic models. Mirrors Get-BaiBundledAgenticModelIds in launcher-provider-models.ps1.
# Order matches $staticBai in run-{qwen,claude}-launcher.ps1 (kept stable for menu UX).
$script:CatalogBai = if ($txtBai) { $txtBai } else {
@(
  [pscustomobject]@{ InternalId = "gpt-5-nano";        Label = "GPT-5 Nano (OpenAI, agentic)";        Ctx = 128000;  Max = 16384 }
  [pscustomobject]@{ InternalId = "gpt-5-mini";        Label = "GPT-5 Mini (OpenAI, agentic)";        Ctx = 128000;  Max = 16384 }
  [pscustomobject]@{ InternalId = "gpt-5.2";           Label = "GPT-5.2 (OpenAI, agentic)";           Ctx = 200000;  Max = 16384 }
  [pscustomobject]@{ InternalId = "gpt-5.4-nano";      Label = "GPT-5.4 Nano (OpenAI, agentic)";      Ctx = 200000;  Max = 16384 }
  [pscustomobject]@{ InternalId = "gpt-5.4-mini";      Label = "GPT-5.4 Mini (OpenAI, agentic)";      Ctx = 200000;  Max = 16384 }
  [pscustomobject]@{ InternalId = "gpt-5.4";           Label = "GPT-5.4 (OpenAI, agentic)";           Ctx = 200000;  Max = 16384 }
  [pscustomobject]@{ InternalId = "gpt-5.4-pro";       Label = "GPT-5.4 Pro (OpenAI, agentic)";       Ctx = 200000;  Max = 16384 }
  [pscustomobject]@{ InternalId = "gpt-5.5";           Label = "GPT-5.5 (OpenAI, agentic)";           Ctx = 200000;  Max = 16384 }
  [pscustomobject]@{ InternalId = "gpt-5.5-instant";   Label = "GPT-5.5 Instant (OpenAI, agentic)";   Ctx = 200000;  Max = 16384 }
  [pscustomobject]@{ InternalId = "claude-haiku-4.5";  Label = "Claude Haiku 4.5 (Anthropic, agentic)";  Ctx = 200000;  Max = 8192 }
  [pscustomobject]@{ InternalId = "claude-sonnet-4.5"; Label = "Claude Sonnet 4.5 (Anthropic, agentic)"; Ctx = 200000;  Max = 8192 }
  [pscustomobject]@{ InternalId = "claude-sonnet-4.6"; Label = "Claude Sonnet 4.6 (Anthropic, agentic)"; Ctx = 200000;  Max = 8192 }
  [pscustomobject]@{ InternalId = "claude-opus-4.5";   Label = "Claude Opus 4.5 (Anthropic, agentic)";   Ctx = 200000;  Max = 8192 }
  [pscustomobject]@{ InternalId = "claude-opus-4.6";   Label = "Claude Opus 4.6 (Anthropic, agentic)";   Ctx = 200000;  Max = 8192 }
  [pscustomobject]@{ InternalId = "claude-opus-4.7";   Label = "Claude Opus 4.7 (Anthropic, agentic)";   Ctx = 200000;  Max = 8192 }
  [pscustomobject]@{ InternalId = "claude-opus-4.8";   Label = "Claude Opus 4.8 (Anthropic, agentic)";   Ctx = 200000;  Max = 8192 }
  [pscustomobject]@{ InternalId = "deepseek-v4-pro";   Label = "DeepSeek V4 Pro (agentic)";            Ctx = 131072;  Max = 8192 }
  [pscustomobject]@{ InternalId = "deepseek-v4-flash"; Label = "DeepSeek V4 Flash (agentic)";          Ctx = 131072;  Max = 8192 }
  [pscustomobject]@{ InternalId = "gemini-3.1-pro";    Label = "Gemini 3.1 Pro (Google, agentic)";     Ctx = 1000000; Max = 8192 }
  [pscustomobject]@{ InternalId = "gemini-3.5-flash";  Label = "Gemini 3.5 Flash (Google, agentic)";   Ctx = 1000000; Max = 8192 }
  [pscustomobject]@{ InternalId = "glm-5";             Label = "GLM-5 (Z.AI)";                         Ctx = 128000;  Max = 8192 }
  [pscustomobject]@{ InternalId = "glm-5.1";           Label = "GLM-5.1 (Z.AI)";                       Ctx = 128000;  Max = 8192 }
  [pscustomobject]@{ InternalId = "kimi-k2.5";         Label = "Kimi K2.5 (Moonshot)";                Ctx = 131072;  Max = 8192 }
  [pscustomobject]@{ InternalId = "kimi-k2.6";         Label = "Kimi K2.6 (Moonshot)";                Ctx = 131072;  Max = 8192 }
  [pscustomobject]@{ InternalId = "minimax-m3";        Label = "MiniMax M3 (agentic)";                Ctx = 1000000; Max = 8192 }
  [pscustomobject]@{ InternalId = "minimax-m2.7";      Label = "MiniMax M2.7 (fast)";                 Ctx = 1000000; Max = 8192 }
)
}

$script:CatalogOpenRouter = if ($txtOpenRouter) { $txtOpenRouter } else {
@(
  # InternalId          Label                                              APIModelId
  [pscustomobject]@{ InternalId = "deepseek-v4-flash"; Label = "DeepSeek V4 Flash (free, tool calling)";         APIModelId = "deepseek/deepseek-chat-v3.1:free"        }
  [pscustomobject]@{ InternalId = "qwen3-coder";       Label = "Qwen3 Coder (free, tool calling)";              APIModelId = "qwen/qwen3-coder:free"                   }
  [pscustomobject]@{ InternalId = "nemotron";          Label = "Nemotron 3 Super 120B (free, tool calling)";   APIModelId = "nvidia/nemotron-3-super-120b-a12b:free"  }
  [pscustomobject]@{ InternalId = "laguna";            Label = "Poolside Laguna M.1 (free, tool calling, coding)"; APIModelId = "poolside/laguna-m.1:free"            }
)
}

# ─── Provider config lookup ─────────────────────────────────────────────────
$script:CatalogProviderEnv = @{
  "zai"        = "ZAI_API_KEY"
  "nim"        = "NVIDIA_NIM_API_KEY"
  "bai"        = "BAI_API_KEY"
  "openrouter" = "OPENROUTER_API_KEY"
}
# Provider display-name / get-key-url overrides from TXT/providers.txt (human-editable).
# Apply only if TXT was loaded -- keeps env-var lookup table above as the
# authoritative (script-anchored) source.
$txtProviders = Get-TextProviders
if ($txtProviders) {
  $script:CatalogProviderDisplay = @{}
  $script:CatalogProviderGetKeyUrl = @{}
  foreach ($k in @("zai", "nim", "bai", "openrouter")) {
    $row = $txtProviders[$k]
    if ($row) {
      $script:CatalogProviderDisplay[$k]    = [string]$row.DisplayName
      $script:CatalogProviderGetKeyUrl[$k]  = [string]$row.GetKeyUrl
    }
  }
} else {
  $script:CatalogProviderDisplay    = @{ "zai" = "Z.AI"; "nim" = "NIM"; "bai" = "B.AI"; "openrouter" = "OpenRouter" }
  $script:CatalogProviderGetKeyUrl  = @{ "zai" = "https://z.ai/manage-apikey/apikey-create"; "nim" = "https://build.nvidia.com/settings/secrets"; "bai" = "https://api.b.ai"; "openrouter" = "https://openrouter.ai/keys" }
}

function Get-CatalogProviderDisplay {
  param([Parameter(Mandatory=$true)][ValidateSet("zai","nim","bai","openrouter")][string]$Provider)
  if ($script:CatalogProviderDisplay -and $script:CatalogProviderDisplay.ContainsKey($Provider)) {
    return [string]$script:CatalogProviderDisplay[$Provider]
  }  return @{ "zai"="Z.AI"; "nim"="NIM"; "bai"="B.AI"; "openrouter"="OpenRouter" }[$Provider]  
}

function Get-CatalogProviderGetKeyUrl {
  param([Parameter(Mandatory=$true)][ValidateSet("zai","nim","bai","openrouter")][string]$Provider)
  if ($script:CatalogProviderGetKeyUrl -and $script:CatalogProviderGetKeyUrl.ContainsKey($Provider)) {
    return [string]$script:CatalogProviderGetKeyUrl[$Provider]
  }
  return @{ "zai"="https://z.ai/manage-apikey/apikey-create"; "nim"="https://build.nvidia.com/settings/secrets"; "bai"="https://api.b.ai"; "openrouter"="https://openrouter.ai/keys" }[$Provider]
}

# ─── Helpers (callable after dot-source) ───────────────────────────────────
function Get-CatalogMenuItems {
  param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("zai", "nim", "bai", "openrouter")]
    [string]$Provider,
    [Parameter(Mandatory = $true)]
    [ValidateSet("Qwen", "Claude")]
    [string]$Brand
  )

  $prefix = switch ("$Brand/$Provider") {
    "Qwen/zai"        { "zai-"              }
    "Qwen/nim"        { "nim-"              }
    "Qwen/bai"        { "bai-"              }
    "Qwen/openrouter" { "openrouter-"       }
    "Claude/zai"      { "claude-zai-"       }
    "Claude/nim"      { "claude-nim-"       }
    "Claude/bai"      { "claude-bai-"       }
    "Claude/openrouter" { "claude-openrouter-" }
    default { throw "Unknown brand/provider combo: $Brand/$Provider" }
  }

  $providerLabel = Get-CatalogProviderDisplay -Provider $Provider

  $items = switch ($Provider) {
    "zai" {
      $script:CatalogZai | ForEach-Object {
        [pscustomobject]@{ Id = "$prefix$($_.InternalId)"; Label = "$providerLabel - $($_.Label)" }
      }
    }
    "nim" {
      $script:CatalogNim | ForEach-Object {
        [pscustomobject]@{ Id = "$prefix$($_.InternalId)"; Label = "$providerLabel - $($_.Label)" }
      }
    }
    "bai" {
      $script:CatalogBai | ForEach-Object {
        [pscustomobject]@{ Id = "$prefix$($_.InternalId)"; Label = "$providerLabel - $($_.Label)" }
      }
    }
    "openrouter" {
      $script:CatalogOpenRouter | ForEach-Object {
        [pscustomobject]@{ Id = "$prefix$($_.InternalId)"; Label = "$providerLabel - $($_.Label)" }
      }
    }
  }
  return ,@($items)
}

function Get-CatalogAPIModelId {
  param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("zai", "nim", "openrouter")]
    [string]$Provider,
    [Parameter(Mandatory = $true)]
    [string]$InternalId
  )
  $src = switch ($Provider) { "zai" { $script:CatalogZai } "nim" { $script:CatalogNim } "openrouter" { $script:CatalogOpenRouter } }
  foreach ($e in $src) { if ($e.InternalId -eq $InternalId) { return $e.APIModelId } }
  return $null
}

function Get-CatalogBaiSpec {
  param([Parameter(Mandatory = $true)][string]$InternalId)
  foreach ($e in $script:CatalogBai) {
    if ($e.InternalId -eq $InternalId) { return @{ Ctx = $e.Ctx; Max = $e.Max } }
  }
  return $null
}

function Test-CatalogBaiInternalId {
  param([Parameter(Mandatory = $true)][string]$InternalId)
  foreach ($e in $script:CatalogBai) { if ($e.InternalId -eq $InternalId) { return $true } }
  return $false
}
