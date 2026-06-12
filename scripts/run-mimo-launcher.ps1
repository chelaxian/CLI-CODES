[CmdletBinding()]
param()

$PSNativeCommandUseErrorActionPreference = $false
$ErrorActionPreference = "Stop"

function Resolve-MimoExe {
    $cmd = Get-Command mimo -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    $localBin = Join-Path $env:USERPROFILE ".mimocode\bin\mimo.exe"
    if (Test-Path -LiteralPath $localBin) { return $localBin }

    foreach ($p in @(
        (Join-Path $env:APPDATA "npm\mimo.cmd"),
        (Join-Path $env:APPDATA "npm\mimo.ps1"),
        (Join-Path $env:APPDATA "npm\mimo")
    )) {
        if (Test-Path -LiteralPath $p) { return $p }
    }
    return ""
}

$mimoExe = Resolve-MimoExe
if (-not $mimoExe) {
    Write-Host "MiMo Code CLI не найден. Установите: npm install -g @mimo-ai/cli" -ForegroundColor Red
    Write-Host "Или: curl -fsSL https://mimo.xiaomi.com/install | bash" -ForegroundColor Yellow
    exit 1
}

try {
    & $mimoExe
} catch {
    exit 0
}
exit 0
