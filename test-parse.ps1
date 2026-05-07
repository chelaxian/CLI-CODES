$files = @(
    "scripts\run-qwen-code-launcher.ps1",
    "scripts\run-claude-cloud-launcher.ps1",
    "scripts\run-opencode-launcher.ps1"
)

foreach ($f in $files) {
    $path = Join-Path $PSScriptRoot $f
    $content = Get-Content -Raw -Path $path
    try {
        [ScriptBlock]::Create($content) | Out-Null
        Write-Host "$f : OK" -ForegroundColor Green
    } catch {
        Write-Host "$f : PARSE ERROR" -ForegroundColor Red
        Write-Host $_.Exception.Message
    }
}
