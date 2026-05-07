# Dot-source перед интерактивным Qwen Code / Claude Code:
#   . (Join-Path $PSScriptRoot 'ensure-streaming-friendly-terminal.ps1')
#
# Qwen Code (Ink + is-in-ci): любые CI_* / CI / CONTINUOUS_INTEGRATION дают «не CI-терминал» -
# страдает интерактив и по ощущениям стриминг (пакетная отрисовка).
# Claude Code в обычном cmd /k тоже не должен видеть фальш-CI.

foreach ($name in @(
    'CI',
    'CONTINUOUS_INTEGRATION',
    'GITHUB_ACTIONS',
    'GITLAB_CI',
    'BUILDKITE',
    'TEAMCITY_VERSION',
    'JENKINS_URL',
    'TRAVIS',
    'CIRCLECI'
  )) {
  if (Test-Path -LiteralPath "Env:$name") {
    Remove-Item -LiteralPath "Env:$name" -ErrorAction SilentlyContinue
  }
}

foreach ($var in @(Get-ChildItem Env: -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'CI_*' })) {
  Remove-Item -LiteralPath ("Env:{0}" -f $var.Name) -ErrorAction SilentlyContinue
}

if (-not $env:PYTHONUNBUFFERED) {
  $env:PYTHONUNBUFFERED = "1"
}
