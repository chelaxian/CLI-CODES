# TUI-меню для лаунчеров Qwen / Claude (рамки, прокрутка, баннер).
# Баннеры читаются из TXT/logos/<brand>.txt если файл существует;
# в противном случае используются инлайн-fallback (ASCII ниже).
# Смотри TXT/README.txt и scripts/launcher-text-resolver.ps1.

. (Join-Path $PSScriptRoot "launcher-text-resolver.ps1")

function Set-LauncherTuiConsole {
  try {
    [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
  } catch {}
}

function Get-LauncherTuiBox {
  return @{
    TL = [char]0x2554; TR = [char]0x2557; BL = [char]0x255A; BR = [char]0x255D
    H  = [char]0x2550; V  = [char]0x2551
    LJ = [char]0x2560; RJ = [char]0x2563
  }
}

# В PowerShell нельзя писать [char] * N - только ([string][char]) * N
function Repeat-TuiChar {
  param(
    [char]$Ch,
    [int]$Count
  )
  if ($Count -lt 1) { return "" }
  return ([string]$Ch) * $Count
}

function Write-TuiRow {
  param(
    [Parameter(Mandatory = $true)]
    [AllowEmptyString()]
    [string]$Text,
    [Parameter(Mandatory = $true)][int]$InnerWidth,
    [System.ConsoleColor]$Fg = "Gray"
  )
  $b = Get-LauncherTuiBox
  if ($Text.Length -gt $InnerWidth) {
    $Text = $Text.Substring(0, [Math]::Max(0, $InnerWidth - 1)) + [char]0x2026
  } else {
    $Text = $Text.PadRight($InnerWidth)
  }
  Write-Host ($b.V + $Text + $b.V) -ForegroundColor $Fg
}

# Render an array of banner lines through Write-TuiRow with a single color.
# Used by all 7 Write-TuiBanner* wrappers (and after TXT/logos fallback).
function Render-TuiBannerLines {
  param(
    [Parameter(Mandatory = $true)][int]$InnerWidth,
    [Parameter(Mandatory = $true)][string[]]$Lines,
    [System.ConsoleColor]$Fg = "Gray"
  )
  foreach ($ln in $Lines) {
    Write-TuiRow -Text $ln -InnerWidth $InnerWidth -Fg $Fg
  }
}

function Write-TuiBannerQwen {
  param([int]$InnerWidth)
  $txt = Get-TextLogo -Brand "qwen"
  if ($txt) {
    Render-TuiBannerLines -InnerWidth $InnerWidth -Lines $txt -Fg DarkCyan
    return
  }
  # Inline fallback — FIGlet «ANSI Shadow», центрируется вокруг $bannerW=59.
  $raw = @(
    " ██████╗ ██╗    ██╗███████╗███╗   ██╗"
    "██╔═══██╗██║    ██║██╔════╝████╗  ██║"
    "██║   ██║██║ █╗ ██║█████╗  ██╔██╗ ██║"
    "██║▄▄ ██║██║███╗██║██╔══╝  ██║╚██╗██║"
    "╚██████╔╝╚███╔███╔╝███████╗██║ ╚████║"
    " ╚══▀▀═╝  ╚══╝╚══╝ ╚══════╝╚═╝  ╚═══╝"
  )
  $bannerW = 59
  $centered = @()
  foreach ($ln in $raw) {
    $len = $ln.Length
    if ($len -ge $bannerW) {
      $row = $ln.Substring(0, $bannerW)
    } else {
      $padL = [int][Math]::Floor(($bannerW - $len) / 2)
      $padR = $bannerW - $len - $padL
      $row = ((" " * $padL) + $ln + (" " * $padR))
    }
    $centered += $row
  }
  Render-TuiBannerLines -InnerWidth $InnerWidth -Lines $centered -Fg DarkCyan
}

function Write-TuiBannerClaude {
  param([int]$InnerWidth)
  $txt = Get-TextLogo -Brand "claude"
  if ($txt) {
    Render-TuiBannerLines -InnerWidth $InnerWidth -Lines $txt -Fg DarkMagenta
    return
  }
  $lines = @(
    "   ██████╗██╗      █████╗ ██╗   ██╗██████╗ ███████╗",
    "  ██╔════╝██║     ██╔══██╗██║   ██║██╔══██╗██╔════╝",
    "  ██║     ██║     ███████║██║   ██║██║  ██║█████╗  ",
    "  ██║     ██║     ██╔══██║██║   ██║██║  ██║██╔══╝  ",
    "  ╚██████╗███████╗██║  ██║╚██████╔╝██████╔╝███████╗",
    "   ╚═════╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚═════╝ ╚══════╝"
  )
  Render-TuiBannerLines -InnerWidth $InnerWidth -Lines $lines -Fg DarkMagenta
}

function Write-TuiBannerLlamaCpp {
  param([int]$InnerWidth)
  $txt = Get-TextLogo -Brand "llamacpp"
  if ($txt) {
    Render-TuiBannerLines -InnerWidth $InnerWidth -Lines $txt -Fg DarkGreen
    return
  }
  # Ширина баннера ~59, как у Claude/Qwen
  $lines = @(
    " ██╗     ██╗      █████╗ ███╗   ███╗ █████╗      ██████╗██████╗ ██████╗ "
    " ██║     ██║     ██╔══██╗████╗ ████║██╔══██╗    ██╔════╝██╔══██╗██╔══██╗"
    " ██║     ██║     ███████║██╔████╔██║███████║    ██║     ██████╔╝██████╔╝"
    " ██║     ██║     ██╔══██║██║╚██╔╝██║██╔══██║    ██║     ██╔═══╝ ██╔═══╝ "
    " ███████╗███████╗██║  ██║██║ ╚═╝ ██║██║  ██║    ╚██████╗██║     ██║     "
    " ╚══════╝╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝╚═╝  ╚═╝     ╚═════╝╚═╝     ╚═╝     "
  )
  Render-TuiBannerLines -InnerWidth $InnerWidth -Lines $lines -Fg DarkGreen
}

function Write-TuiBannerLMStudio {
  param([int]$InnerWidth)
  $txt = Get-TextLogo -Brand "lmstudio"
  if ($txt) {
    Render-TuiBannerLines -InnerWidth $InnerWidth -Lines $txt -Fg DarkCyan
    return
  }
  $lines = @(
    " ██╗     ███╗   ███╗    ███████╗████████╗██╗   ██╗██████╗ ██╗ ██████╗ "
    " ██║     ████╗ ████║    ██╔════╝╚══██╔══╝██║   ██║██╔══██╗██║██╔═══██╗"
    " ██║     ██╔████╔██║    ███████╗   ██║   ██║   ██║██║  ██║██║██║   ██║"
    " ██║     ██║╚██╔╝██║    ╚════██║   ██║   ██║   ██║██║  ██║██║██║   ██║"
    " ███████╗██║ ╚═╝ ██║    ███████║   ██║   ╚██████╔╝██████╔╝██║╚██████╔╝"
    " ╚══════╝╚═╝     ╚═╝    ╚══════╝   ╚═╝    ╚═════╝ ╚═════╝ ╚═╝ ╚═════╝ "
  )
  Render-TuiBannerLines -InnerWidth $InnerWidth -Lines $lines -Fg DarkCyan
}

function Write-TuiBannerOpenCode {
  param([int]$InnerWidth)
  $txt = Get-TextLogo -Brand "opencode"
  if ($txt) {
    Render-TuiBannerLines -InnerWidth $InnerWidth -Lines $txt -Fg DarkGreen
    return
  }
  $lines = @(
    " ██████╗ ██████╗ ███████╗███╗   ██╗ ██████╗ ██████╗ ██████╗ ███████╗"
    "██╔═══██╗██╔══██╗██╔════╝████╗  ██║██╔════╝██╔═══██╗██╔══██╗██╔════╝"
    "██║   ██║██████╔╝█████╗  ██╔██╗ ██║██║     ██║   ██║██║  ██║█████╗  "
    "██║   ██║██╔═══╝ ██╔══╝  ██║╚██╗██║██║     ██║   ██║██║  ██║██╔══╝  "
    "╚██████╔╝██║     ███████╗██║ ╚████║╚██████╗╚██████╔╝██████╔╝███████╗"
    " ╚═════╝ ╚═╝     ╚══════╝╚═╝  ╚═══╝ ╚═════╝ ╚═════╝ ╚═════╝ ╚══════╝"
  )
  Render-TuiBannerLines -InnerWidth $InnerWidth -Lines $lines -Fg DarkGreen
}

function Write-TuiBannerFreebuff {
  param([int]$InnerWidth)
  $txt = Get-TextLogo -Brand "freebuff"
  if ($txt) {
    Render-TuiBannerLines -InnerWidth $InnerWidth -Lines $txt -Fg White
    return
  }
  $lines = @(
    "███████╗██████╗ ███████╗███████╗██████╗ ██╗   ██╗███████╗███████╗",
    "██╔════╝██╔══██╗██╔════╝██╔════╝██╔══██╗██║   ██║██╔════╝██╔════╝",
    "█████╗  ██████╔╝█████╗  █████╗  ██████╔╝██║   ██║█████╗  █████╗  ",
    "██╔══╝  ██╔══██╗██╔══╝  ██╔══╝  ██╔══██╗██║   ██║██╔══╝  ██╔══╝  ",
    "██║     ██║  ██║███████╗███████╗██████╔╝╚██████╔╝██║     ██║     ",
    "╚═╝     ╚═╝  ╚═╝╚══════╝╚══════╝╚═════╝  ╚═════╝ ╚═╝     ╚═╝     "
  )
  Render-TuiBannerLines -InnerWidth $InnerWidth -Lines $lines -Fg White
}

function Write-TuiBannerOpenClaude {
  param([int]$InnerWidth)
  $txt = Get-TextLogo -Brand "openclaude"
  if ($txt) {
    Render-TuiBannerLines -InnerWidth $InnerWidth -Lines $txt -Fg DarkGreen
    return
  }
  # Однострок: OPEN + CLAUDE side-by-side (compact ANSI Shadow).
  $lines = @(
    " ██████╗ ██████╗ ███████╗███╗   ██╗   ██████╗██╗      █████╗ ██╗   ██╗██████╗ ███████╗",
    "██╔═══██╗██╔══██╗██╔════╝████╗  ██║  ██╔════╝██║     ██╔══██╗██║   ██║██╔══██╗██╔════╝",
    "██║   ██║██████╔╝█████╗  ██╔██╗ ██║  ██║     ██║     ███████║██║   ██║██║  ██║█████╗  ",
    "██║   ██║██╔═══╝ ██╔══╝  ██║╚██╗██║  ██║     ██║     ██╔══██║██║   ██║██║  ██║██╔══╝  ",
    "╚██████╔╝██║     ███████╗██║ ╚████║  ╚██████╗███████╗██║  ██║╚██████╔╝██████╔╝███████╗",
    " ╚═════╝ ╚═╝     ╚══════╝╚═╝  ╚═══╝   ╚═════╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚═════╝ ╚══════╝"
  )
  Render-TuiBannerLines -InnerWidth $InnerWidth -Lines $lines -Fg DarkGreen
}

function Show-TuiFramedMenu {
  param(
    [ValidateSet("Qwen", "Claude", "LlamaCpp", "LMStudio", "OpenCode", "Freebuff", "OpenClaude")]
    [string]$AppBrand,
    [Parameter(Mandatory = $true)][string]$Title,
    [string]$Subtitle = "",
    [Parameter(Mandatory = $true)][object[]]$Items,
    [int]$InitialIndex = 0,
    [int]$MaxVisible = 12,
    [ValidateSet("Exit", "Back")]
    [string]$EscapeAction = "Exit",
    [string]$UpdateHint = ""
  )

  Set-LauncherTuiConsole
  $b = Get-LauncherTuiBox
  $win = $Host.UI.RawUI.WindowSize
  $frameW = [Math]::Min(100, [Math]::Max(60, $win.Width - 2))
  $inner = $frameW - 2
  $n = $Items.Count
  if ($n -lt 1) {
    throw "Show-TuiFramedMenu: список Items пуст."
  }
  $idx = [Math]::Max(0, [Math]::Min($InitialIndex, $n - 1))
  $heightCap = [Math]::Max(6, $win.Height - 12)
  $visible = [Math]::Max(4, [Math]::Min($MaxVisible, [Math]::Min($n, $heightCap)))
  # При dot-source $script: - область вызывающего файла; скролл ломался. Hashtable - общий изменяемый объект.
  $scroll = @{ Top = 0 }

  function Sync-TuiScroll {
    if ($idx -lt $scroll.Top) { $scroll.Top = $idx }
    $maxTop = [Math]::Max(0, $n - $visible)
    if ($idx -ge $scroll.Top + $visible) { $scroll.Top = $idx - $visible + 1 }
    if ($scroll.Top -gt $maxTop) { $scroll.Top = $maxTop }
    if ($scroll.Top -lt 0) { $scroll.Top = 0 }
  }

  function Redraw-TuiMenu {
    Sync-TuiScroll
    Clear-Host
    Write-Host ($b.TL + (Repeat-TuiChar $b.H ($frameW - 2)) + $b.TR) -ForegroundColor Cyan
    Write-TuiRow -Text ("".PadRight($inner)) -InnerWidth $inner
    switch ($AppBrand) {
      "Qwen" { Write-TuiBannerQwen -InnerWidth $inner }
      "Claude" { Write-TuiBannerClaude -InnerWidth $inner }
      "LlamaCpp" { Write-TuiBannerLlamaCpp -InnerWidth $inner }
      "LMStudio" { Write-TuiBannerLMStudio -InnerWidth $inner }
      "OpenCode" { Write-TuiBannerOpenCode -InnerWidth $inner }
      "Freebuff" { Write-TuiBannerFreebuff -InnerWidth $inner }
      "OpenClaude" { Write-TuiBannerOpenClaude -InnerWidth $inner }
      default { Write-TuiBannerClaude -InnerWidth $inner }
    }
    Write-TuiRow -Text ("".PadRight($inner)) -InnerWidth $inner
    if (-not [string]::IsNullOrWhiteSpace($UpdateHint)) {
      Write-TuiRow -Text "" -InnerWidth $inner
      Write-TuiRow -Text ("  $UpdateHint") -InnerWidth $inner -Fg Yellow
      Write-TuiRow -Text "" -InnerWidth $inner
    }
    Write-Host ($b.LJ + (Repeat-TuiChar $b.H $inner) + $b.RJ) -ForegroundColor DarkCyan
    Write-TuiRow -Text (" " + $Title.Trim()) -InnerWidth $inner -Fg White
    if (-not [string]::IsNullOrWhiteSpace($Subtitle)) {
      Write-TuiRow -Text (" " + $Subtitle.Trim()) -InnerWidth $inner -Fg DarkGray
    }
    Write-Host ($b.LJ + (Repeat-TuiChar $b.H $inner) + $b.RJ) -ForegroundColor DarkCyan
    Write-TuiRow -Text ("".PadRight($inner)) -InnerWidth $inner
    for ($r = 0; $r -lt $visible; $r++) {
      $i = $scroll.Top + $r
      if ($i -ge $n) {
        Write-TuiRow -Text "" -InnerWidth $inner
        continue
      }
      $lbl = [string]$Items[$i].Label
      $mark = if ($i -eq $idx) { ("  {0} " -f [char]0x25B6) } else { "     " }
      $row = $mark + $lbl
      $fg = if ($i -eq $idx) { "Yellow" } else { "Gray" }
      Write-TuiRow -Text $row -InnerWidth $inner -Fg $fg
    }
    Write-TuiRow -Text ("".PadRight($inner)) -InnerWidth $inner
    $escHint = if ($EscapeAction -eq "Back") { "Esc/Ctrl+C - назад" } else { "Esc/Ctrl+C - выход" }
    $hint = ("  {0}{1}  выбор   Enter - OK   {2}   Home/End   PgUp/PgDn" -f [char]0x2191, [char]0x2193, $escHint)
    Write-TuiRow -Text $hint -InnerWidth $inner -Fg DarkGray
    if ($n -gt $visible) {
      $pg = ("  строки {0}-{1} из {2}" -f ($scroll.Top + 1), ([Math]::Min($scroll.Top + $visible, $n)), $n)
      Write-TuiRow -Text $pg -InnerWidth $inner -Fg DarkCyan
    }
    Write-Host ($b.BL + (Repeat-TuiChar $b.H ($frameW - 2)) + $b.BR) -ForegroundColor Cyan
  }

  $scroll.Top = 0
  Sync-TuiScroll
  try { [Console]::CursorVisible = $false } catch { }
  # Перехват Ctrl+C: TreatControlCAsInput=true позволяет нам самим обработать Ctrl+C в ReadKey
  # как ESC (Back — вернуться, Exit — закрыть TUI). Без этого Ctrl+C сразу терминирует скрипт.
  $prevCtrlC = $false
  try { $prevCtrlC = [Console]::TreatControlCAsInput; [Console]::TreatControlCAsInput = $true } catch { }
  try {
    Redraw-TuiMenu
    while ($true) {
      $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
      # Ctrl+C: Character = 0x03 (ETX). Обрабатываем как ESC.
      if ([int]$key.Character -eq 3) {
        if ($EscapeAction -eq "Back") {
          return [pscustomobject]@{ __menuBack = $true }
        }
        return $null
      }
      switch ($key.VirtualKeyCode) {
        38 {
          if ($idx -gt 0) { $idx-- }
          Redraw-TuiMenu
        }
        40 {
          if ($idx -lt $n - 1) { $idx++ }
          Redraw-TuiMenu
        }
        33 {
          $idx = [Math]::Max(0, $idx - $visible)
          Redraw-TuiMenu
        }
        34 {
          $idx = [Math]::Min($n - 1, $idx + $visible)
          Redraw-TuiMenu
        }
        36 {
          $idx = 0
          Redraw-TuiMenu
        }
        35 {
          $idx = $n - 1
          Redraw-TuiMenu
        }
        13 { return $Items[$idx] }
        27 {
          if ($EscapeAction -eq "Back") {
            return [pscustomobject]@{ __menuBack = $true }
          }
          return $null
        }
      }
    }
  } finally {
    try { [Console]::TreatControlCAsInput = $prevCtrlC } catch { }
    try { [Console]::CursorVisible = $true } catch { }
  }
}

function Show-TuiWaitFrame {
  param(
    [ValidateSet("Qwen", "Claude", "LlamaCpp", "LMStudio", "OpenCode", "Freebuff", "OpenClaude")]
    [string]$AppBrand,
    [Parameter(Mandatory = $true)][string]$Message
  )
  Set-LauncherTuiConsole
  $b = Get-LauncherTuiBox
  $win = $Host.UI.RawUI.WindowSize
  $frameW = [Math]::Min(82, [Math]::Max(50, $win.Width - 4))
  $inner = $frameW - 2
  Clear-Host
  Write-Host ($b.TL + (Repeat-TuiChar $b.H ($frameW - 2)) + $b.TR) -ForegroundColor Cyan
  Write-TuiRow -Text ("".PadRight($inner)) -InnerWidth $inner
  switch ($AppBrand) {
    "Qwen" { Write-TuiBannerQwen -InnerWidth $inner }
    "Claude" { Write-TuiBannerClaude -InnerWidth $inner }
    "LlamaCpp" { Write-TuiBannerLlamaCpp -InnerWidth $inner }
    "LMStudio" { Write-TuiBannerLMStudio -InnerWidth $inner }
    "OpenCode" { Write-TuiBannerOpenCode -InnerWidth $inner }
    "Freebuff" { Write-TuiBannerFreebuff -InnerWidth $inner }
    "OpenClaude" { Write-TuiBannerOpenClaude -InnerWidth $inner }
    default { Write-TuiBannerClaude -InnerWidth $inner }
  }
  Write-TuiRow -Text ("".PadRight($inner)) -InnerWidth $inner
  Write-TuiRow -Text ("  " + $Message) -InnerWidth $inner -Fg Yellow
  Write-TuiRow -Text ("".PadRight($inner)) -InnerWidth $inner
  Write-Host ($b.BL + (Repeat-TuiChar $b.H ($frameW - 2)) + $b.BR) -ForegroundColor Cyan
}

# ─── Restore-ProcessEnvFromUser ──────────────────────────────────────────────
# Copies a User-scope environment variable into the current process scope.
# Used after `Remove-Item Env:` clears process env to make sure API keys that
# the user set via "Сменить ключ API провайдера" (which writes User scope) are
# still visible to child CLIs that default to that provider.
function Restore-ProcessEnvFromUser {
  param([Parameter(Mandatory = $true)][string]$Key)
  $val = [Environment]::GetEnvironmentVariable($Key, "User")
  if ([string]::IsNullOrWhiteSpace($val) -or $val -eq "__SET_ME__") {
    Remove-Item -Path ("Env:" + $Key) -ErrorAction SilentlyContinue
    return
  }
  Set-Item -Path ("Env:" + $Key) -Value $val
}

# ─── Invoke-ChildCliCatchCtrlC ───────────────────────────────────────────────
# Thin wrapper around '& $exe' that swallows PipelineStoppedException so
# Ctrl+C (which aborts the running child CLI) returns control to the caller
# instead of aborting the whole launcher script.
function Invoke-ChildCliCatchCtrlC {
  param(
    [Parameter(Mandatory = $true)][string]$ExePath,
    [string[]]$Arguments = @()
  )
  try {
    if ($ExePath -like "*.cmd" -or $ExePath -like "*.bat") {
      $allArgs = @("/c", $ExePath) + $Arguments
      & cmd.exe @allArgs
    } elseif ($Arguments.Count -gt 0) {
      & $ExePath @Arguments
    } else {
      & $ExePath
    }
  } catch {}
}

# ─── Test-LauncherUpdates ─────────────────────────────────────────────────────
# Checks for updates to: (1) the CLI-CODES repo scripts, (2) the agent binary.
# Returns a string (update hint) or "" if no updates / check failed.
# Non-blocking: any failure is silently ignored.
#
# Performance: result is cached on disk in <repoRoot>/.update-cache.json with
# 1-hour TTL. Repeat launcher launches within ~1h skip both the GitHub API call
# and the npm view child-process spawn. Saves 2-10s per launch on warm cache.
$script:LauncherUpdateCachePath = $null
if ($PSScriptRoot) {
  $root = Split-Path $PSScriptRoot -Parent
  if ($root) { $script:LauncherUpdateCachePath = Join-Path $root ".update-cache.json" }
}
$script:LauncherUpdateCacheTTLSec = 3600

function Get-CachedLauncherUpdateHint {
  param([string]$Key)
  if (-not $script:LauncherUpdateCachePath) { return $null }
  if (-not (Test-Path -LiteralPath $script:LauncherUpdateCachePath)) { return $null }
  try {
    $obj = Get-Content -LiteralPath $script:LauncherUpdateCachePath -Raw -Encoding UTF8 | ConvertFrom-Json
    if (-not $obj -or -not $obj.PSObject.Properties[$Key]) { return $null }
    $entry = $obj.PSObject.Properties[$Key].Value
    if (-not $entry.checkedAt) { return $null }
    $age = ([DateTime]::UtcNow - [DateTime]::Parse(
      $entry.checkedAt,
      [System.Globalization.CultureInfo]::InvariantCulture,
      [System.Globalization.DateTimeStyles]::RoundtripKind
    )).TotalSeconds
    if ($age -ge $script:LauncherUpdateCacheTTLSec) { return $null }
    return [string]$entry.hint
  } catch { return $null }
}

function Set-CachedLauncherUpdateHint {
  param([string]$Key, [string]$Hint)
  if (-not $script:LauncherUpdateCachePath) { return }
  try {
    $obj = $null
    if (Test-Path -LiteralPath $script:LauncherUpdateCachePath) {
      try { $obj = Get-Content -LiteralPath $script:LauncherUpdateCachePath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $obj = $null }
    }
    if (-not $obj) { $obj = [pscustomobject]@{} }
    $entry = [pscustomobject]@{ checkedAt = (Get-Date).ToUniversalTime().ToString("o"); hint = $Hint }
    if ($obj.PSObject.Properties[$Key]) {
      $obj.PSObject.Properties[$Key].Value = $entry
    } else {
      $obj | Add-Member -NotePropertyName $Key -NotePropertyValue $entry -Force
    }
    ($obj | ConvertTo-Json -Compress) | Set-Content -LiteralPath $script:LauncherUpdateCachePath -Encoding UTF8 -NoNewline
  } catch {}
}

function Test-LauncherUpdates {
  param(
    [string]$AgentNpmPackage = "",
    [string]$AgentDisplayName = ""
  )

  # TTL cache short-circuit. Cache key distinguishes "repo-only" from "<pkg>+repo".
  $cacheKey = if ([string]::IsNullOrWhiteSpace($AgentNpmPackage)) { "repocheck" } else { ("npm+" + $AgentNpmPackage) }
  $cached = Get-CachedLauncherUpdateHint -Key $cacheKey
  if ($null -ne $cached) { return $cached }

  $hints = @()
  $prevEAP = $ErrorActionPreference
  $prevProgress = $ProgressPreference
  try {
    $ErrorActionPreference = "Continue"
    $ProgressPreference = "SilentlyContinue"

    # Check repo updates
    $repo = "chelaxian/CLI-CODES"
    $branch = "main"
    try {
      $apiUrl = "https://api.github.com/repos/$repo/commits/$branch"
      $resp = Invoke-RestMethod -Uri $apiUrl -TimeoutSec 5 -ErrorAction Stop
      $remoteSha = $resp.sha
      if ($remoteSha -and $PSScriptRoot) {
        $gitDir = Join-Path (Split-Path $PSScriptRoot) ".git"
        if (Test-Path -LiteralPath $gitDir) {
          $localSha = & git -C (Split-Path $PSScriptRoot) rev-parse HEAD 2>$null
          if ($localSha -and $remoteSha -ne $localSha.Trim()) {
            $hints += "ОБНОВЛЕНИЕ: доступно обновление на Github - запустите скрипт мастера установки и выберите [7]"
          }
        }
      }
    } catch {}

    # Check agent npm package updates
    if (-not [string]::IsNullOrWhiteSpace($AgentNpmPackage)) {
      try {
        $npmBin = Join-Path $env:APPDATA "npm"
        $npmView = Get-Command npm.cmd -ErrorAction SilentlyContinue
        if (-not $npmView) { $npmView = Join-Path $npmBin "npm.cmd" }
        if ($npmView -and (Test-Path -LiteralPath $npmView)) {
          $latest = & $npmView view $AgentNpmPackage version 2>$null
          if ($latest) {
            $installed = & $npmView list -g $AgentNpmPackage --depth=0 2>$null
            if ($installed -and $installed -notmatch [regex]::Escape($latest.Trim())) {
              $name = if ($AgentDisplayName) { $AgentDisplayName } else { $AgentNpmPackage }
              $hints += "${name}: обновление $latest — npm i -g $AgentNpmPackage@latest"
            }
          }
        }
    } catch {
    if ($_.Exception -is [System.Management.Automation.PipelineStoppedException] -or
        $_.Exception.Message -match "Ctrl\+C") {
      return
    }
    Write-Host ""
    Write-Host "  Ошибка при запуске: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
  }
    }
  } catch {} finally {
    $ErrorActionPreference = $prevEAP
    $ProgressPreference = $prevProgress
  }

  $result = ($hints -join " | ")
  # Only cache non-empty hints: if there's nothing to report, we want the next
  # launch to re-check the registry/npm so users who manually ran `[8] Update`
  # (git pull + npm update) get fresh results, not a stale "no updates".
  if (-not [string]::IsNullOrWhiteSpace($result)) {
    Set-CachedLauncherUpdateHint -Key $cacheKey -Hint $result
  }
  return $result
}

# ─── Resolve-CommandOrInstall ─────────────────────────────────────────────────
# Finds the agent executable. If not found, offers to install it.
# Returns the exe path or "" (empty = user declined / install failed).
function Resolve-CommandOrInstall {
  param(
    [Parameter(Mandatory = $true)][string]$CommandName,
    [Parameter(Mandatory = $true)][string]$NpmPackage,
    [Parameter(Mandatory = $true)][string]$DisplayName,
    [string]$AltCommandName = ""
  )

  $npmBin = Join-Path $env:APPDATA "npm"
  if ($npmBin -and (Test-Path -LiteralPath $npmBin)) {
    $parts = @($env:PATH -split ';' | Where-Object { $_ -and $_.Trim().Length -gt 0 })
    if (-not ($parts | Where-Object { $_.TrimEnd('\') -ieq $npmBin.TrimEnd('\') })) {
      $env:PATH = $npmBin + ";" + $env:PATH
    }
  }

  foreach ($name in @($CommandName, $AltCommandName)) {
    if ([string]::IsNullOrWhiteSpace($name)) { continue }
    $cmd = Get-Command $name -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
  }

  foreach ($ext in @(".cmd", ".ps1")) {
    $p = Join-Path $npmBin "$CommandName$ext"
    if (Test-Path -LiteralPath $p) { return $p }
  }
  if ($AltCommandName) {
    foreach ($ext in @(".cmd", ".ps1")) {
      $p = Join-Path $npmBin "$AltCommandName$ext"
      if (Test-Path -LiteralPath $p) { return $p }
    }
  }

  Write-Host ""
  Write-Host "  $DisplayName не найден." -ForegroundColor Yellow
  Write-Host "  Установить сейчас? (Y/n): " -ForegroundColor Cyan -NoNewline
  $answer = (Read-Host).Trim()
  if ($answer -in @("n", "N", "no", "No", "нет", "Нет")) { return "" }

  Write-Host "  Установка $NpmPackage..." -ForegroundColor Cyan
  $npmCmd = Get-Command npm.cmd -ErrorAction SilentlyContinue
  if (-not $npmCmd) {
    $npmCmd = Join-Path $npmBin "npm.cmd"
    if (-not (Test-Path -LiteralPath $npmCmd)) { $npmCmd = $null }
  }
  if (-not $npmCmd) {
    Write-Host "  npm не найден. Установите Node.js: https://nodejs.org/" -ForegroundColor Red
    Write-Host "  Нажмите любую клавишу..." -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    return ""
  }

  $prevEAP = $ErrorActionPreference
  try {
    $ErrorActionPreference = "Continue"
    & $npmCmd install -g "$NpmPackage@latest" 2>&1 | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }
  } catch {
    Write-Host ""
    Write-Host "  Ошибка установки." -ForegroundColor Red
    Write-Host "  Если вы находитесь в РФ/РБ/Иране — npm может быть заблокирован." -ForegroundColor Yellow
    Write-Host "  Решение: включите VPN и повторите." -ForegroundColor Yellow
    Write-Host "  Нажмите любую клавишу..." -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    $ErrorActionPreference = $prevEAP
    return ""
  } finally {
    $ErrorActionPreference = $prevEAP
  }

  if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "  npm install завершился с кодом $LASTEXITCODE." -ForegroundColor Red
    Write-Host "  Возможные причины:" -ForegroundColor Yellow
    Write-Host "    - Гео-блокировка (РФ/РБ/Иран) — включите VPN и повторите" -ForegroundColor Yellow
    Write-Host "    - Нет прав — запустите от администратора" -ForegroundColor Yellow
    Write-Host "    - Проблемы с сетью — проверьте интернет" -ForegroundColor Yellow
    Write-Host "  Нажмите любую клавишу..." -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    return ""
  }

  Write-Host ""
  Write-Host "  [OK] $DisplayName установлен." -ForegroundColor Green
  Write-Host ""

  foreach ($name in @($CommandName, $AltCommandName)) {
    if ([string]::IsNullOrWhiteSpace($name)) { continue }
    $cmd = Get-Command $name -ErrorAction SilentlyContinue
    if ($cmd) {
      Write-Host "  $DisplayName установлен: $($cmd.Source)" -ForegroundColor Green
      return $cmd.Source
    }
  }

  Write-Host "  Установка завершена, но $DisplayName не найден в PATH." -ForegroundColor Yellow
  Write-Host "  Перезапустите ярлык." -ForegroundColor Yellow
  return ""
}

# ─── Build-GroupMenuItems ────────────────────────────────────────────────────
# Dynamically builds a provider group menu by fetching models from the provider's
# API (using the user's API key from environment). Falls back to a bundled static
# list if the key is missing or the API call fails.
#
# .PARAMETER Provider
#   "zai" | "nim" | "bai" | "openrouter"
# .PARAMETER StaticItems
#   Hashtable of fallback items: @{ Id = "..."; Label = "..." }
# .PARAMETER ApiKeyEnv
#   Name of the env var holding the API key (e.g. "ZAI_API_KEY").
# .PARAMETER FetchScript
#   Name of the function in launcher-provider-models.ps1 that returns model IDs.
#   Supported: "Get-ZaiCodingModelIdsFromApi", "Get-NvidiaNimModelIdsFromApi",
#              "Get-BaiModelIdsFromApi", "Get-OpenRouterModelIdsFromApi".
# .PARAMETER FilterToBundled
#   If $true, filter API results against bundled free/preview catalog.
# .PARAMETER IdPrefix
#   Prefix for item IDs (e.g. "claude-" for Claude launcher, "" for others).
# .PARAMETER ApiIdToPresetId
#   Hashtable mapping API model id -> preset id for providers where they differ
#   (e.g. @{ "glm-5.1" = "zai-glm51"; "glm-4.7" = "zai-glm" }).
#
# Returns array of @{Id; Label} items.
function Build-GroupMenuItems {
  param(
    [Parameter(Mandatory)][string]$Provider,
    [Parameter(Mandatory)][object[]]$StaticItems,
    [string]$ApiKeyEnv = "",
    [string]$FetchScript = "",
    [switch]$FilterToBundled,
    [switch]$AgenticOnly,
    [string]$IdPrefix = "",
    [hashtable]$ApiIdToPresetId = @{},
    [hashtable]$ExtraFetchArgs = @{},
    [string[]]$AllowedApiIds = @(),
    [string[]]$ForcedIds = @()
  )

  $items = $StaticItems
  $source = "static"
  $hint = ""

  # Try dynamic fetch
  if (-not [string]::IsNullOrWhiteSpace($ApiKeyEnv) -and -not [string]::IsNullOrWhiteSpace($FetchScript)) {
    $key = [Environment]::GetEnvironmentVariable($ApiKeyEnv, "User")
    if ([string]::IsNullOrWhiteSpace($key) -or $key -eq "__SET_ME__") { $key = ${env:$ApiKeyEnv} }

    if (-not [string]::IsNullOrWhiteSpace($key)) {
      Write-Host "  [DEBUG] $Provider : trying dynamic fetch, key prefix=$($key.Substring(0, [Math]::Min(8, $key.Length)))..." -ForegroundColor DarkGray
      try {
        $prevEAP = $ErrorActionPreference
        $ErrorActionPreference = "Continue"

        $splatted = @{ ApiKey = $key }
        if ($FilterToBundled) { $splatted.FilterToBundled = $true }
        if ($AgenticOnly) { $splatted.AgenticOnly = $true }
        foreach ($k in $ExtraFetchArgs.Keys) { $splatted[$k] = $ExtraFetchArgs[$k] }

        Write-Host "  [DEBUG] $Provider : calling $FetchScript" -ForegroundColor DarkGray
        $ids = & $FetchScript @splatted
        $ErrorActionPreference = $prevEAP

        Write-Host "  [DEBUG] $Provider : fetch returned $($ids.Count) items" -ForegroundColor DarkGray

        if ($ids -and $ids.Count -gt 0) {
          $items = @()
          foreach ($rawId in $ids) {
            $mid = $rawId.Trim()
            if (-not $mid) { continue }
            $lowerMid = $mid.ToLowerInvariant()

            if ($AllowedApiIds.Count -gt 0 -and $lowerMid -notin $AllowedApiIds) { continue }

            if ($ApiIdToPresetId.ContainsKey($lowerMid)) {
              $presetId = $ApiIdToPresetId[$lowerMid]
              $itemId = $presetId
            } else {
              $presetId = "$IdPrefix$mid"
              $itemId = "$IdPrefix$mid"
            }
            $items += [pscustomobject]@{ Id = $itemId; Label = "$Provider - $mid" }
          }
          # ForcedIds: always include even if API didn't return them
          if ($ForcedIds.Count -gt 0) {
            $existingIds = @($items | ForEach-Object { $_.Id })
            foreach ($fid in $ForcedIds) {
              $lowerFid = $fid.ToLowerInvariant()
              $mappedId = if ($ApiIdToPresetId.ContainsKey($lowerFid)) { $ApiIdToPresetId[$lowerFid] } else { "$IdPrefix$fid" }
              if ($mappedId -notin $existingIds) {
                $items += [pscustomobject]@{ Id = $mappedId; Label = "$Provider - $fid (free)" }
                $existingIds += $mappedId
                Write-Host "  [DEBUG] $Provider : forced add $fid -> $mappedId" -ForegroundColor DarkGray
              }
            }
          }

          if ($items.Count -gt 0) {
            $source = "API"
            $hint = " (live)"
            Write-Host "  [DEBUG] $Provider : using dynamic list ($($items.Count) items)" -ForegroundColor DarkGreen
          }
        }

        if ($source -eq "static") {
          Write-Host "  [DEBUG] $Provider : fetch returned 0 items, falling back to static" -ForegroundColor DarkYellow
        }
      } catch {
        $errMsg = $_.Exception.Message
        Write-Host "  [DEBUG] $Provider : fetch EXCEPTION: $errMsg" -ForegroundColor Red
        if ($errMsg -match "timeout|timed out|connection|network|name resolution|DNS|geo") {
          Write-Host "  [WARN] $Provider : сетевая ошибка (таймаут/геоблок). Включите VPN." -ForegroundColor Yellow
        }
      }
    } else {
      Write-Host "  [DEBUG] $Provider : no API key found (env=$ApiKeyEnv), using static" -ForegroundColor DarkYellow
    }
  }

  if ($source -eq "static") {
    $label = if ($items.Count -gt 0) { "$($items.Count) моделей" } else { "модели" }
    $hint = " [ключ не добавлен, статический список]"
  }

  return [pscustomobject]@{
    Items   = $items
    Source  = $source
    Hint    = $hint
  }
}
