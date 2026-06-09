$errors = @()
$files = @(
    "C:\Users\chelaxian\Projects\CLI-CODES\install.ps1",
    "C:\Users\chelaxian\Projects\CLI-CODES\scripts\run-qwen-code-launcher.ps1",
    "C:\Users\chelaxian\Projects\CLI-CODES\scripts\run-claude-cloud-launcher.ps1",
    "C:\Users\chelaxian\Projects\CLI-CODES\scripts\run-opencode-launcher.ps1"
)

foreach ($f in $files) {
    $err = $null
    $tok = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($f, [ref]$tok, [ref]$err)
    $name = Split-Path $f -Leaf
    if ($err.Count -eq 0) {
        Write-Host "[OK] $name"
    } else {
        Write-Host "[FAIL] $name ($($err.Count) errors)"
        foreach ($e in $err) {
            Write-Host ("  Line " + $e.Extent.StartLineNumber + ": " + $e.Message)
        }
        $errors += $err
    }
}

if ($errors.Count -eq 0) {
    Write-Host "`nAll scripts parse correctly!"
    exit 0
} else {
    Write-Host "`nSome scripts failed to parse!"
    exit 1
}
