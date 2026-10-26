# clicodes.ps1 — общее ядро CLI-CODES для Windows (dot-source). Совместимо с PowerShell 5.1+.
#
#   * реестры TXT/agents.txt и TXT/providers.txt
#   * API-ключи в пользовательских переменных среды (User scope)
#   * динамический каталог моделей с кэшем и статическим fallback (TXT/models/<provider>.txt)
#   * установка агентов (npm / uv / irm-скрипты)
#   * адаптеры запуска агентов с выбранными провайдером и моделью
#
# Linux/macOS-аналог: scripts/lib/clicodes.sh (тот же формат реестров).

$script:CcLibDir   = $PSScriptRoot
$script:CcRoot     = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$script:CcTxt      = Join-Path $script:CcRoot "TXT"
$script:CcConfig   = Join-Path $env:APPDATA "cli-codes"
$script:CcStateDir = Join-Path $script:CcConfig "state"
$script:CcCacheDir = Join-Path $env:LOCALAPPDATA "cli-codes"
$script:CcModelsTtlHours = 6

try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.ServicePointManager]::SecurityProtocol } catch {}

# ─── Реестры ─────────────────────────────────────────────────────────────────

function Read-CcRows([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) { return @() }
  $rows = @()
  foreach ($raw in [System.IO.File]::ReadAllLines($Path, (New-Object System.Text.UTF8Encoding $false))) {
    $line = $raw.Trim()
    if ($line -eq "" -or $line.StartsWith("#")) { continue }
    $cols = @($line -split '\|' | ForEach-Object { $v = $_.Trim(); if ($v -eq "-") { "" } else { $v } })
    $rows += ,$cols
  }
  return ,$rows  # запятая: не дать PowerShell развернуть единственную строку в массив полей
}

$script:CcAgents = @()
foreach ($c in (Read-CcRows (Join-Path $script:CcTxt "agents.txt"))) {
  $script:CcAgents += [pscustomobject]@{
    Key = $c[0]; Name = $c[1]; Cmd = $c[2]; Linux = $c[3]; Windows = $c[4]
    Adapter = $c[5]; Legacy = $c[6]; Url = $c[7]; Desc = $c[8]
  }
}

$script:CcProviders = @()
foreach ($c in (Read-CcRows (Join-Path $script:CcTxt "providers.txt"))) {
  if ($c.Count -lt 11) { continue }
  $script:CcProviders += [pscustomobject]@{
    Key = $c[0]; Name = $c[1]; KeyUrl = $c[2]; EnvVar = $c[3]; BaseUrl = $c[4]; ModelsUrl = $c[5]
    Auth = $c[6]; Tier = $c[7]; AnthropicUrl = $c[8]; Responses = ($c[9] -eq "yes"); Note = $c[10]
  }
}

function Get-CcAgent([string]$Key)    { $script:CcAgents    | Where-Object { $_.Key -eq $Key } | Select-Object -First 1 }
function Get-CcProvider([string]$Key) { $script:CcProviders | Where-Object { $_.Key -eq $Key } | Select-Object -First 1 }

function Get-CcTierBadge([string]$Tier) {
  switch ($Tier) { "free" { "FREE" } "freemium" { "FREE-квота" } "local" { "LOCAL" } default { "PAID" } }
}

function Get-CcPython {
  foreach ($n in @("python", "python3", "py")) {
    $c = Get-Command $n -ErrorAction SilentlyContinue
    # Заглушка WindowsApps\python.exe открывает Microsoft Store — пропускаем её
    if ($c -and $c.Source -notlike "*WindowsApps*") { return $c.Source }
  }
  return $null
}

# ─── API-ключи ───────────────────────────────────────────────────────────────

function Get-CcKey([string]$EnvVar) {
  if (-not $EnvVar) { return "" }
  $v = [Environment]::GetEnvironmentVariable($EnvVar, "Process")
  if ([string]::IsNullOrWhiteSpace($v)) { $v = [Environment]::GetEnvironmentVariable($EnvVar, "User") }
  if ([string]::IsNullOrWhiteSpace($v) -or $v -eq "__SET_ME__") { return "" }
  return $v.Trim()
}

function Set-CcKey([string]$EnvVar, [string]$Value) {
  if ([string]::IsNullOrWhiteSpace($Value)) { $Value = $null } else { $Value = $Value.Trim() }
  [Environment]::SetEnvironmentVariable($EnvVar, $Value, "User")
  [Environment]::SetEnvironmentVariable($EnvVar, $Value, "Process")
}

function Import-CcKeys {  # подтянуть ключи из User scope в текущий процесс
  foreach ($p in $script:CcProviders) {
    if ($p.EnvVar -and -not [Environment]::GetEnvironmentVariable($p.EnvVar, "Process")) {
      $v = [Environment]::GetEnvironmentVariable($p.EnvVar, "User")
      if ($v) { [Environment]::SetEnvironmentVariable($p.EnvVar, $v, "Process") }
    }
  }
}

function Get-CcProviderKey($Provider) { return (Get-CcKey $Provider.EnvVar) }

function Test-CcProviderReady($Provider) {
  if ($Provider.Auth -in @("none", "optional")) { return $true }
  return -not [string]::IsNullOrEmpty((Get-CcProviderKey $Provider))
}

function Get-CcMasked([string]$Key) {
  if ($Key.Length -gt 12) { return $Key.Substring(0, 6) + "…" + $Key.Substring($Key.Length - 4) }
  return "***"
}

# ─── Каталог моделей ─────────────────────────────────────────────────────────

$script:CcNonChat = 'embed|rerank|tts|whisper|transcri|speech|audio|voxtral|image|dall-e|sdxl|stable-diffusion|flux|seedance|kling|video|guard|safety|reward|moderation|nemoretriever|parse|nvclip|vila|deplot|kosmos|neva|fuyu|ocr|translate|riva|detector|calibration|bge-|^test$'

function Get-CcModelsFromApi($Provider) {
  $url = $Provider.ModelsUrl
  if ($url -eq "none") { return $null }
  if (-not $url) { $url = $Provider.BaseUrl + "/models" }
  $headers = @{ Accept = "application/json" }
  $key = Get-CcProviderKey $Provider
  if ($key) { $headers["Authorization"] = "Bearer $key" }
  try {
    $resp = Invoke-RestMethod -Uri $url -Headers $headers -TimeoutSec 20 -UseBasicParsing -ErrorAction Stop
  } catch { return $null }

  $items = @()
  if ($resp -is [array]) { $items = $resp }
  elseif ($resp.data) { $items = @($resp.data) }
  elseif ($resp.models) { $items = @($resp.models) }

  $out = @()
  foreach ($m in $items) {
    $id = [string]$m.id
    if (-not $id) { $id = [string]$m.name }
    if (-not $id -or $id -match $script:CcNonChat) { continue }
    # У OpenRouter есть честные метаданные: требуем поддержку tool calling
    if ($Provider.Key -eq "openrouter" -and $m.supported_parameters -and -not ($m.supported_parameters -contains "tools")) { continue }
    $free = $id.EndsWith(":free") -or $id.EndsWith("-free") -or $id -eq "openrouter/free"
    if (-not $free -and $m.pricing) {
      try { $free = ([double]$m.pricing.prompt -eq 0 -and [double]$m.pricing.completion -eq 0) } catch {}
    }
    $label = if ($m.name -and $m.name -ne $id) { [string]$m.name } else { $id }
    $extra = @()
    if ($free -and $label -notmatch 'free') { $extra += "free" }
    $ctx = 0
    if ($m.context_length) { $ctx = [int64]$m.context_length } elseif ($m.context_window) { $ctx = [int64]$m.context_window }
    if ($ctx -gt 0) { $extra += ("{0}k ctx" -f [int]($ctx / 1000)) }
    if ($extra.Count) { $label += " (" + ($extra -join ", ") + ")" }
    $out += [pscustomobject]@{ Id = $id; Label = $label.Replace("|", "/"); Free = $free }
  }
  if ($out.Count -eq 0) { return $null }
  return @($out | Sort-Object @{ Expression = { -not $_.Free } }, @{ Expression = { $_.Id.ToLowerInvariant() } })
}

# PS 5.1: ConvertFrom-Json отдаёт JSON-массив ОДНИМ объектом Object[] — разворачиваем через конвейер
function Read-CcModelCache([string]$Path) {
  return @((Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json) | ForEach-Object { $_ })
}

# Возвращает @{ Models = [Id, Label][]; Source = api|cache|static }
# Порядок: «★ рекомендуемые» из TXT/models/<provider>.txt, затем остальные из API.
function Get-CcModels($Provider, [switch]$Refresh) {
  $cacheDir = Join-Path $script:CcCacheDir "models"
  if (-not (Test-Path -LiteralPath $cacheDir)) { New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null }
  $cache = Join-Path $cacheDir ($Provider.Key + ".json")
  $dyn = $null; $source = "static"

  $fresh = (Test-Path -LiteralPath $cache) -and ((Get-Item -LiteralPath $cache).LastWriteTime -gt (Get-Date).AddHours(-$script:CcModelsTtlHours))
  if (-not $Refresh -and $fresh) {
    $dyn = Read-CcModelCache $cache; $source = "cache"
  } else {
    $dyn = Get-CcModelsFromApi $Provider
    if ($dyn) {
      [System.IO.File]::WriteAllText($cache, (ConvertTo-Json -InputObject @($dyn) -Depth 3 -Compress), (New-Object System.Text.UTF8Encoding $false))
      $source = "api"
    } elseif (Test-Path -LiteralPath $cache) {
      $dyn = Read-CcModelCache $cache; $source = "cache"
    }
  }

  $result = New-Object System.Collections.ArrayList
  $seen = @{}
  $dynIds = @{}
  if ($dyn) { foreach ($m in $dyn) { $dynIds[$m.Id] = $true } }
  foreach ($c in (Read-CcRows (Join-Path $script:CcTxt ("models\" + $Provider.Key + ".txt")))) {
    if (-not $c[0]) { continue }
    if ($dyn -and -not $dynIds.ContainsKey($c[0])) { continue }  # рекомендованной модели уже нет у провайдера
    $seen[$c[0]] = $true
    $lbl = if ($c.Count -gt 1 -and $c[1]) { $c[1] } else { $c[0] }
    [void]$result.Add([pscustomobject]@{ Id = $c[0]; Label = "★ " + $lbl })
  }
  if ($dyn) {
    foreach ($m in $dyn) {
      if ($seen.ContainsKey($m.Id)) { continue }
      $seen[$m.Id] = $true
      [void]$result.Add([pscustomobject]@{ Id = $m.Id; Label = $m.Label })
    }
  }
  return @{ Models = @($result); Source = $source }
}

# ─── State ───────────────────────────────────────────────────────────────────

function Get-CcState([string]$Agent) {  # → @{ Provider; Model } или $null
  $f = Join-Path $script:CcStateDir $Agent
  if (-not (Test-Path -LiteralPath $f)) { return $null }
  $line = (Get-Content -LiteralPath $f -TotalCount 1 -Encoding UTF8)
  if (-not $line -or $line -notmatch '\|') { return $null }
  $parts = $line -split '\|', 2
  return @{ Provider = $parts[0]; Model = $parts[1] }
}

function Set-CcState([string]$Agent, [string]$Provider, [string]$Model) {
  if (-not (Test-Path -LiteralPath $script:CcStateDir)) { New-Item -ItemType Directory -Path $script:CcStateDir -Force | Out-Null }
  [System.IO.File]::WriteAllText((Join-Path $script:CcStateDir $Agent), "$Provider|$Model`n", (New-Object System.Text.UTF8Encoding $false))
}

# ─── Установка агентов ───────────────────────────────────────────────────────

function Update-CcPath {
  $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
  foreach ($d in @((Join-Path $env:USERPROFILE ".local\bin"), (Join-Path $env:APPDATA "npm"))) {
    if ((Test-Path -LiteralPath $d) -and ($env:Path -notlike "*$d*")) { $env:Path = "$d;$env:Path" }
  }
}

function Resolve-CcCommand([string]$Name) {
  $c = Get-Command $Name -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($c) { return $c.Source }
  foreach ($p in @((Join-Path $env:APPDATA "npm\$Name.cmd"), (Join-Path $env:USERPROFILE ".local\bin\$Name.exe"))) {
    if (Test-Path -LiteralPath $p) { return $p }
  }
  return $null
}

function Test-CcAgentInstalled($Agent) { return [bool](Resolve-CcCommand $Agent.Cmd) }
function Test-CcAgentSupported($Agent) { return [bool]$Agent.Windows }

function Install-CcUv {
  if (Resolve-CcCommand "uv") { return $true }
  Write-Host "  → установка uv (менеджер Python-инструментов)…" -ForegroundColor DarkGray
  try { & powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "irm https://astral.sh/uv/install.ps1 | iex" *> $null } catch {}
  Update-CcPath
  return [bool](Resolve-CcCommand "uv")
}

function Install-CcAgent($Agent) {
  $spec = $Agent.Windows
  if (-not $spec) { Write-Host ("  [SKIP] {0}: не поддерживается на Windows (используйте WSL)" -f $Agent.Name) -ForegroundColor DarkGray; return $false }
  $kind, $target = $spec -split ':', 2
  $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
  try {
    switch ($kind) {
      "npm" { & npm.cmd install -g "$target@latest" *> $null }
      "uv"  {
        if (Install-CcUv) {
          $uv = Resolve-CcCommand "uv"
          if ($target -eq "aider-chat") { & $uv tool install --force --python 3.12 aider-chat *> $null }
          else { & $uv tool install --force $target *> $null }
        }
      }
      # Out-Host: иначе вывод установщика попадает в возвращаемое значение функции и маскирует $false
      "ps"  { & powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "irm '$target' -TimeoutSec 120 | iex" | Out-Host }
      default { Write-Host "  [ERR] неизвестный способ установки: $spec" -ForegroundColor Red }
    }
  } finally { $ErrorActionPreference = $prev }
  Update-CcPath
  return (Test-CcAgentInstalled $Agent)
}

function Uninstall-CcAgent($Agent) {
  if (-not $Agent.Windows) { return }
  $kind, $target = $Agent.Windows -split ':', 2
  $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
  switch ($kind) {
    "npm" { & npm.cmd uninstall -g $target *> $null }
    "uv"  { $uv = Resolve-CcCommand "uv"; if ($uv) { & $uv tool uninstall $target *> $null } }
  }
  $ErrorActionPreference = $prev
}

function Get-CcAgentVersion($Agent) {
  $kind, $target = ([string]$Agent.Windows) -split ':', 2
  if ($kind -eq "npm") {
    try {
      $json = (& npm.cmd ls -g $target --depth=0 --json 2>$null) -join ""
      $dep = ($json | ConvertFrom-Json).dependencies.PSObject.Properties[$target]
      if ($dep -and $dep.Value.version) { return [string]$dep.Value.version }
    } catch {}
  }
  return ""
}

# ─── Адаптеры запуска ────────────────────────────────────────────────────────

function Test-CcAdapterSupports([string]$Adapter, $Provider) {
  switch ($Adapter) {
    "env"    { return $false }
    "gemini" { return $Provider.Key -eq "gemini" }
    "codex"  { return $Provider.Responses }
    "claude" { return ([bool]$Provider.AnthropicUrl -or [bool](Get-CcPython)) }
    default  { return $true }
  }
}

function Start-CcProxy([string]$BaseUrl, [string]$ApiKey, [string]$Model) {
  $py = Get-CcPython
  if (-not $py) { throw "Для этого провайдера нужен Python 3 (локальный прокси Anthropic→OpenAI): winget install Python.Python.3.12" }
  $l = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, 0)
  $l.Start(); $port = $l.LocalEndpoint.Port; $l.Stop()
  if (-not (Test-Path -LiteralPath $script:CcCacheDir)) { New-Item -ItemType Directory -Path $script:CcCacheDir -Force | Out-Null }
  # одноразовый токен: без него прокси не примет запросы от других локальных процессов
  $token = -join ((1..48) | ForEach-Object { '{0:x}' -f (Get-Random -Maximum 16) })
  $log = Join-Path $script:CcCacheDir "anthropic-proxy.log"
  # Start-Process наследует окружение в момент запуска → задаём переменные только на время старта,
  # чтобы ключ провайдера не унаследовал сам агент (и его shell-инструменты)
  $vars = @{ UPSTREAM_BASE_URL = $BaseUrl; UPSTREAM_API_KEY = $ApiKey; UPSTREAM_MODEL = $Model; PROXY_TOKEN = $token; PROXY_LOG = $log }
  foreach ($k in $vars.Keys) { Set-Item "Env:$k" $vars[$k] }
  try {
    $proc = Start-Process -FilePath $py -ArgumentList @("`"$(Join-Path $script:CcLibDir 'anthropic-proxy.py')`"", $port) -WindowStyle Hidden -PassThru
  } finally {
    foreach ($k in $vars.Keys) { Remove-Item "Env:$k" -ErrorAction SilentlyContinue }
  }
  foreach ($i in 1..50) {
    try { Invoke-WebRequest -Uri "http://127.0.0.1:$port/" -UseBasicParsing -TimeoutSec 1 | Out-Null; return @{ Port = $port; Process = $proc; Token = $token } } catch { Start-Sleep -Milliseconds 100 }
  }
  try { $proc.Kill() } catch {}
  throw "Прокси не стартовал, см. $log"
}

# Invoke-CcAgent -Agent <obj> [-Provider <obj> -Model <id>] [-AgentArgs @()]
function Invoke-CcAgent {
  param($Agent, $Provider = $null, [string]$Model = "", [string[]]$AgentArgs = @())
  $exe = Resolve-CcCommand $Agent.Cmd
  if (-not $exe) { throw ("{0} не установлен (команда {1}). Запустите инсталлятор." -f $Agent.Name, $Agent.Cmd) }
  Import-CcKeys
  if ($Agent.Adapter -eq "env" -or -not $Provider) { & $exe @AgentArgs; return }

  $base = $Provider.BaseUrl
  $key = Get-CcProviderKey $Provider
  if (-not $key -and $Provider.Auth -ne "key") { $key = "cli-codes" }
  $m = $Model
  $proxy = $null
  $cmdArgs = @()

  switch ($Agent.Adapter) {
    "claude" {
      foreach ($v in @("ANTHROPIC_API_KEY", "ANTHROPIC_AUTH_TOKEN", "ANTHROPIC_BASE_URL", "CLAUDE_CODE_USE_BEDROCK", "CLAUDE_CODE_USE_VERTEX", "CLAUDE_CODE_USE_FOUNDRY")) { Remove-Item "Env:$v" -ErrorAction SilentlyContinue }
      if ($Provider.Key -eq "anthropic") { $env:ANTHROPIC_API_KEY = $key }
      elseif ($Provider.AnthropicUrl) { $env:ANTHROPIC_BASE_URL = $Provider.AnthropicUrl; $env:ANTHROPIC_AUTH_TOKEN = $key }
      else {
        $proxy = Start-CcProxy -BaseUrl $base -ApiKey $key -Model $m
        $env:ANTHROPIC_BASE_URL = "http://127.0.0.1:$($proxy.Port)"; $env:ANTHROPIC_AUTH_TOKEN = $proxy.Token
      }
      $env:ANTHROPIC_MODEL = $m
      if ($Provider.Key -ne "anthropic") {
        # все «слоты» Claude Code (opus/sonnet/haiku/субагенты) → выбранная модель
        $env:ANTHROPIC_DEFAULT_OPUS_MODEL = $m; $env:ANTHROPIC_DEFAULT_SONNET_MODEL = $m; $env:ANTHROPIC_DEFAULT_FABLE_MODEL = $m
        $env:ANTHROPIC_DEFAULT_HAIKU_MODEL = $m; $env:CLAUDE_CODE_SUBAGENT_MODEL = $m
        $env:CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1"; $env:API_TIMEOUT_MS = "600000"
      }
    }
    "openclaude" {
      $env:CLAUDE_CODE_USE_OPENAI = "1"; $env:OPENAI_BASE_URL = $base; $env:OPENAI_API_KEY = $key; $env:OPENAI_MODEL = $m
    }
    "qwen" {
      $env:OPENAI_API_KEY = $key
      $cmdArgs = @("--auth-type", "openai", "--openai-base-url", $base, "-m", $m)
    }
    "opencode" {
      if (-not (Test-Path -LiteralPath $script:CcStateDir)) { New-Item -ItemType Directory -Path $script:CcStateDir -Force | Out-Null }
      $cfg = Join-Path $script:CcStateDir "opencode.json"
      $env:CC_OPENCODE_API_KEY = $key  # ключ не пишется в файл: opencode подставляет {env:VAR}
      $models = @{}; $models[$m] = @{ name = $m }
      $obj = [ordered]@{
        '$schema' = "https://opencode.ai/config.json"
        provider  = @{ cc = [ordered]@{ npm = "@ai-sdk/openai-compatible"; name = $Provider.Name
                                        options = @{ baseURL = $base; apiKey = "{env:CC_OPENCODE_API_KEY}" }; models = $models } }
        model     = "cc/$m"
      }
      [System.IO.File]::WriteAllText($cfg, ($obj | ConvertTo-Json -Depth 6), (New-Object System.Text.UTF8Encoding $false))
      $env:OPENCODE_CONFIG = $cfg
    }
    "codex" {
      if ($Provider.Key -eq "openai") { $env:OPENAI_API_KEY = $key; $cmdArgs = @("-m", $m) }
      else {
        $env:CC_CODEX_API_KEY = $key
        # TOML literal strings ('…'): PS 5.1 не экранирует вложенные " при вызове нативных программ
        $cmdArgs = @("-c", "model_provider='cc'",
                     "-c", ("model_providers.cc={{ name = '{0}', base_url = '{1}', env_key = 'CC_CODEX_API_KEY', wire_api = 'responses' }}" -f $Provider.Name, $base),
                     "-m", $m)
      }
    }
    "gemini" { $env:GEMINI_API_KEY = $key; $cmdArgs = @("-m", $m) }
    "aider"  { $env:OPENAI_API_BASE = $base; $env:OPENAI_API_KEY = $key; $cmdArgs = @("--model", "openai/$m") }
    "goose"  {
      $u = [Uri]$base
      $env:GOOSE_PROVIDER = "openai"; $env:OPENAI_HOST = $u.GetLeftPart([UriPartial]::Authority)
      $env:OPENAI_BASE_PATH = ($u.AbsolutePath.Trim("/") + "/chat/completions").TrimStart("/")
      $env:OPENAI_API_KEY = $key; $env:GOOSE_MODEL = $m
      $cmdArgs = @("session")
    }
  }

  try { & $exe @cmdArgs @AgentArgs }
  finally { if ($proxy) { try { $proxy.Process.Kill() } catch {} } }
}
