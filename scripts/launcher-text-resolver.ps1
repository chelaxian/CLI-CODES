# Single source of truth for STATIC UI text. Reads TXT/ first; falls back
# to inline defaults only when TXT/missing or file empty.
#
# Why this exists:  owners want to edit menu labels, ASCII banners,
# model catalogs, and provider names without re-running any code through
# an AI. They edit .txt files in TXT/ and the next launcher launch picks
# them up.
#
# Backward compatibility:  if TXT/<file> is missing OR has no non-comment
# lines, functions return $null and call-sites fall back to their inline
# arrays. So removing TXT/ entirely does NOT break anything.
#
# Functions:
#   Get-TextLogo(brand)             -> string[]  (banner lines)
#   Get-TextCatalog(provider)       -> object[]  (CatalogEntry-shaped rows)
#   Get-TextProviders()             -> hashtable provider->info
#   Get-TextMenuMap(fileKey)        -> hashtable key->value
#   Test-TextFileHasContent(fileKey)-> bool       (file exists & non-empty)

$script:TextRepoRoot = $null
if ($PSScriptRoot) {
  $script:TextRepoRoot = Split-Path $PSScriptRoot -Parent
}
if (-not $script:TextRepoRoot) {
  $script:TextRepoRoot = (Get-Location).Path
}

# Resolve TXT/ relative to either repo root OR scripts/ directory.
$script:TextRoot = $null
foreach ($candidate in @(
  (Join-Path $script:TextRepoRoot "TXT"),
  (Join-Path $PSScriptRoot "..\TXT"),
  (Join-Path $PSScriptRoot "../TXT")
)) {
  if (Test-Path -LiteralPath $candidate) {
    $script:TextRoot = (Resolve-Path -LiteralPath $candidate).Path
    break
  }
}

# Hard-coded map: file-key -> relative path under TXT/. Used by readers.
$script:TextFileMap = @{
  "logo-qwen"                 = "logos\qwen.txt"
  "logo-claude"               = "logos\claude.txt"
  "logo-opencode"             = "logos\opencode.txt"
  "logo-freebuff"             = "logos\freebuff.txt"
  "logo-openclaude"           = "logos\openclaude.txt"
  "logo-llamacpp"             = "logos\llamacpp.txt"
  "logo-lmstudio"             = "logos\lmstudio.txt"
  "logo-installer"            = "logos\installer.txt"
  "catalog-zai"               = "catalogs\zai.txt"
  "catalog-nim"               = "catalogs\nim.txt"
  "catalog-bai"               = "catalogs\bai.txt"
  "catalog-openrouter"        = "catalogs\openrouter.txt"
  "providers"                 = "providers.txt"
  "menu-installer"            = "menus\installer.txt"
  "menu-subtitles"            = "menus\subtitles.txt"
  "menu-claude-top"           = "menus\claude-top.txt"
}

function Test-TextFileHasContent {
  param([Parameter(Mandatory=$true)][string]$FileKey)
  if (-not $script:TextRoot) { return $false }
  $rel = $script:TextFileMap[$FileKey]
  if (-not $rel) { return $false }
  $full = Join-Path $script:TextRoot $rel
  if (-not (Test-Path -LiteralPath $full)) { return $false }
  # Use System.IO.File.ReadAllLines with explicit UTF-8 no-BOM encoding.
  # PS5.1 Get-Content -Encoding UTF8 can mis-decode BOM-less Cyrillic/box-drawing;
  # raw I/O is the safe path on legacy hosts.
  $allLines = [System.IO.File]::ReadAllLines($full, (New-Object System.Text.UTF8Encoding $false))
  foreach ($ln in $allLines) {
    $t = if ($null -eq $ln) { "" } else { [string]$ln }
    if ($t.Trim() -ne "" -and -not $t.TrimStart().StartsWith("#")) { return $true }
  }
  return $false
}

# Generic pipe-delimited loader. Returns array of @{} rows where keys
# are 0-based column indices. Uses System.IO.File.ReadAllLines + UTF-8 no-BOM
# for PS 5.1 Cyrillic/box-drawing safety.
function Read-TextPipeRows {
  param([Parameter(Mandatory=$true)][string]$FileKey)
  $rel = $script:TextFileMap[$FileKey]
  $full = Join-Path $script:TextRoot $rel
  $rows = @()
  $allLines = [System.IO.File]::ReadAllLines($full, (New-Object System.Text.UTF8Encoding $false))
  foreach ($raw in $allLines) {
    if ($null -eq $raw) { continue }
    $line = ([string]$raw).Trim()
    if ($line -eq "" -or $line.StartsWith("#")) { continue }
    $cols = $line -split '\|', 0
    for ($i = 0; $i -lt $cols.Count; $i++) { $cols[$i] = $cols[$i].Trim() }
    $rows += [pscustomobject]@{ Cols = $cols }
  }
  return ,@($rows)
}

function Get-TextLogo {
  param([Parameter(Mandatory=$true)][string]$Brand)
  $key = "logo-$($Brand.ToLowerInvariant())"
  if (-not (Test-TextFileHasContent -FileKey $key)) { return $null }
  $rel = $script:TextFileMap[$key]
  $full = Join-Path $script:TextRoot $rel
  $lines = @()
  # System.IO.File.ReadAllLines preserves trailing spaces (some ASCII art
  # uses them for left-side alignment) and decodes BOM-less UTF-8 reliably
  # on PS 5.1.
  $allLines = [System.IO.File]::ReadAllLines($full, (New-Object System.Text.UTF8Encoding $false))
  foreach ($raw in $allLines) {
    if ($null -eq $raw) { continue }
    $t = [string]$raw
    # Drop pure-blank lines but keep space-padded art (art rows have leading
    # spaces -- logical whitespace but not empty after Trim).
    if ($t.Trim() -eq "") { continue }
    # Only strip CR/LF (\r \n) -- preserve any intentional trailing-space
    # padding used for art alignment (e.g., side-by-side banners).
    $lines += $t.TrimEnd([char]13, [char]10)
  }
  if ($lines.Count -eq 0) { return $null }
  return ,@($lines)
}

function Get-TextCatalog {
  param([Parameter(Mandatory=$true)][ValidateSet("zai","nim","bai","openrouter")][string]$Provider)
  $key = "catalog-$Provider"
  if (-not (Test-TextFileHasContent -FileKey $key)) { return $null }
  $rows = Read-TextPipeRows -FileKey $key
  if ($rows.Count -eq 0) { return $null }
  $out = @()
  foreach ($r in $rows) {
    $c = $r.Cols
    if ($c.Count -lt 3) { continue }
    $ctx = 0; $max = 0
    if ($c.Count -ge 4) { [int]::TryParse($c[3], [ref]$ctx) | Out-Null }
    if ($c.Count -ge 5) { [int]::TryParse($c[4], [ref]$max) | Out-Null }
    $out += [pscustomobject]@{
      InternalId = [string]$c[0]
      APIModelId  = [string]$c[1]
      Label       = [string]$c[2]
      Ctx         = $ctx
      Max         = $max
    }
  }
  return ,@($out)
}

function Get-TextProviders {
  if (-not (Test-TextFileHasContent -FileKey "providers")) { return $null }
  $rows = Read-TextPipeRows -FileKey "providers"
  if ($rows.Count -eq 0) { return $null }
  $out = @{}
  foreach ($r in $rows) {
    $c = $r.Cols
    if ($c.Count -lt 4) { continue }
    $out[[string]$c[0]] = [pscustomobject]@{
      Key          = [string]$c[0]
      DisplayName  = [string]$c[1]
      GetKeyUrl    = [string]$c[2]
      EnvVarName   = [string]$c[3]
    }
  }
  return $out
}

function Get-TextMenuMap {
  param([Parameter(Mandatory=$true)][string]$FileKey)
  if (-not (Test-TextFileHasContent -FileKey $FileKey)) { return $null }
  $rows = Read-TextPipeRows -FileKey $FileKey
  if ($rows.Count -eq 0) { return $null }
  $out = @{}
  foreach ($r in $rows) {
    $c = $r.Cols
    if ($c.Count -lt 2) { continue }
    $out[[string]$c[0]] = [string]$c[1]
  }
  return $out
}
