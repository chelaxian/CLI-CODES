# TUI-меню для лаунчеров Qwen / Claude (рамки, прокрутка, баннер).

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

function Write-TuiBannerQwen {
  param([int]$InnerWidth)
  # Тот же визуальный язык, что и у Claude (FIGlet «ANSI Shadow»), по центру как CLAUDE (ширина 59).
  $raw = @(
    " ██████╗ ██╗    ██╗███████╗███╗   ██╗"
    "██╔═══██╗██║    ██║██╔════╝████╗  ██║"
    "██║   ██║██║ █╗ ██║█████╗  ██╔██╗ ██║"
    "██║▄▄ ██║██║███╗██║██╔══╝  ██║╚██╗██║"
    "╚██████╔╝╚███╔███╔╝███████╗██║ ╚████║"
    " ╚══▀▀═╝  ╚══╝╚══╝ ╚══════╝╚═╝  ╚═══╝"
  )
  $bannerW = 59
  foreach ($ln in $raw) {
    $len = $ln.Length
    if ($len -ge $bannerW) {
      $row = $ln.Substring(0, $bannerW)
    } else {
      $padL = [int][Math]::Floor(($bannerW - $len) / 2)
      $padR = $bannerW - $len - $padL
      $row = ((" " * $padL) + $ln + (" " * $padR))
    }
    Write-TuiRow -Text $row -InnerWidth $InnerWidth -Fg DarkCyan
  }
}

function Write-TuiBannerClaude {
  param([int]$InnerWidth)
  $lines = @(
    "   ██████╗██╗     ██╗      █████╗ ██╗   ██╗██████╗ ███████╗",
    "  ██╔════╝██║     ██║     ██╔══██╗██║   ██║██╔══██╗██╔════╝",
    "  ██║     ██║     ██║     ███████║██║   ██║██║  ██║█████╗  ",
    "  ██║     ██║     ██║     ██╔══██║██║   ██║██║  ██║██╔══╝  ",
    "  ╚██████╗███████╗███████╗██║  ██║╚██████╔╝██████╔╝███████╗",
    "   ╚═════╝╚══════╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚═════╝ ╚══════╝"
  )
  foreach ($ln in $lines) {
    Write-TuiRow -Text $ln -InnerWidth $InnerWidth -Fg DarkMagenta
  }
}

function Write-TuiBannerLlamaCpp {
  param([int]$InnerWidth)
  # Ширина баннера ~59, как у Claude/Qwen
  $lines = @(
    " ██╗     ██╗      █████╗ ███╗   ███╗ █████╗      ██████╗██████╗ ██████╗ "
    " ██║     ██║     ██╔══██╗████╗ ████║██╔══██╗    ██╔════╝██╔══██╗██╔══██╗"
    " ██║     ██║     ███████║██╔████╔██║███████║    ██║     ██████╔╝██████╔╝"
    " ██║     ██║     ██╔══██║██║╚██╔╝██║██╔══██║    ██║     ██╔═══╝ ██╔═══╝ "
    " ███████╗███████╗██║  ██║██║ ╚═╝ ██║██║  ██║    ╚██████╗██║     ██║     "
    " ╚══════╝╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝╚═╝  ╚═╝     ╚═════╝╚═╝     ╚═╝     "
  )
  foreach ($ln in $lines) {
    Write-TuiRow -Text $ln -InnerWidth $InnerWidth -Fg DarkGreen
  }
}

function Write-TuiBannerLMStudio {
  param([int]$InnerWidth)
  $lines = @(
    " ██╗     ███╗   ███╗    ███████╗████████╗██╗   ██╗██████╗ ██╗ ██████╗ "
    " ██║     ████╗ ████║    ██╔════╝╚══██╔══╝██║   ██║██╔══██╗██║██╔═══██╗"
    " ██║     ██╔████╔██║    ███████╗   ██║   ██║   ██║██║  ██║██║██║   ██║"
    " ██║     ██║╚██╔╝██║    ╚════██║   ██║   ██║   ██║██║  ██║██║██║   ██║"
    " ███████╗██║ ╚═╝ ██║    ███████║   ██║   ╚██████╔╝██████╔╝██║╚██████╔╝"
    " ╚══════╝╚═╝     ╚═╝    ╚══════╝   ╚═╝    ╚═════╝ ╚═════╝ ╚═╝ ╚═════╝ "
  )
  foreach ($ln in $lines) {
    Write-TuiRow -Text $ln -InnerWidth $InnerWidth -Fg DarkCyan
  }
}

function Write-TuiBannerOpenCode {
  param([int]$InnerWidth)
  $lines = @(
    " ██████╗ ██████╗ ███████╗███╗   ██╗ ██████╗ ██████╗ ██████╗ ███████╗"
    "██╔═══██╗██╔══██╗██╔════╝████╗  ██║██╔════╝██╔═══██╗██╔══██╗██╔════╝"
    "██║   ██║██████╔╝█████╗  ██╔██╗ ██║██║     ██║   ██║██║  ██║█████╗  "
    "██║   ██║██╔═══╝ ██╔══╝  ██║╚██╗██║██║     ██║   ██║██║  ██║██╔══╝  "
    "╚██████╔╝██║     ███████╗██║ ╚████║╚██████╗╚██████╔╝██████╔╝███████╗"
    " ╚═════╝ ╚═╝     ╚══════╝╚═╝  ╚═══╝ ╚═════╝ ╚═════╝ ╚═════╝ ╚══════╝"
  )
  foreach ($ln in $lines) {
    Write-TuiRow -Text $ln -InnerWidth $InnerWidth -Fg DarkGreen
  }
}

function Write-TuiBannerFreebuff {
  param([int]$InnerWidth)
  $lines = @(
    "███████╗██████╗ ███████╗███████╗██████╗ ██╗   ██╗███████╗███████╗",
    "██╔════╝██╔══██╗██╔════╝██╔════╝██╔══██╗██║   ██║██╔════╝██╔════╝",
    "█████╗  ██████╔╝█████╗  █████╗  ██████╔╝██║   ██║█████╗  █████╗  ",
    "██╔══╝  ██╔══██╗██╔══╝  ██╔══╝  ██╔══██╗██║   ██║██╔══╝  ██╔══╝  ",
    "██║     ██║  ██║███████╗███████╗██████╔╝╚██████╔╝██║     ██║     ",
    "╚═╝     ╚═╝  ╚═╝╚══════╝╚══════╝╚═════╝  ╚═════╝ ╚═╝     ╚═╝     "
  )
  foreach ($ln in $lines) {
    Write-TuiRow -Text $ln -InnerWidth $InnerWidth -Fg White
  }
}

function Write-TuiBannerOpenClaude {
  param([int]$InnerWidth)
  # Однострок: OPEN + CLAUDE side-by-side (compact ANSI Shadow).
  $lines = @(
    " ██████╗ ██████╗ ███████╗███╗   ██╗   ██████╗██╗      █████╗ ██╗   ██╗██████╗ ███████╗",
    "██╔═══██╗██╔══██╗██╔════╝████╗  ██║  ██╔════╝██║     ██╔══██╗██║   ██║██╔══██╗██╔════╝",
    "██║   ██║██████╔╝█████╗  ██╔██╗ ██║  ██║     ██║     ███████║██║   ██║██║  ██║█████╗  ",
    "██║   ██║██╔═══╝ ██╔══╝  ██║╚██╗██║  ██║     ██║     ██╔══██║██║   ██║██║  ██║██╔══╝  ",
    "╚██████╔╝██║     ███████╗██║ ╚████║  ╚██████╗███████╗██║  ██║╚██████╔╝██████╔╝███████╗",
    " ╚═════╝ ╚═╝     ╚══════╝╚═╝  ╚═══╝   ╚═════╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚═════╝ ╚══════╝"
  )
  foreach ($ln in $lines) {
    Write-TuiRow -Text $ln -InnerWidth $InnerWidth -Fg DarkGreen
  }
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
# Checks for updates to: (1) the cloud-code-setup repo scripts, (2) the agent binary.
# Returns a string (update hint) or "" if no updates / check failed.
# Non-blocking: any failure is silently ignored.
function Test-LauncherUpdates {
  param(
    [string]$AgentNpmPackage = "",
    [string]$AgentDisplayName = ""
  )

  $hints = @()
  $prevEAP = $ErrorActionPreference
  $prevProgress = $ProgressPreference
  try {
    $ErrorActionPreference = "Continue"
    $ProgressPreference = "SilentlyContinue"

    # Check repo updates
    $repo = "chelaxian/cloud-code-setup"
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
            $hints += "РЕПО: есть обновление скриптов — git pull"
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
      } catch {}
    }
  } catch {} finally {
    $ErrorActionPreference = $prevEAP
    $ProgressPreference = $prevProgress
  }

  return ($hints -join " | ")
}
