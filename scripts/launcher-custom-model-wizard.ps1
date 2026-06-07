# Dot-source после launcher-tui.ps1 и launcher-provider-models.ps1
# Возврат: [pscustomobject]@{ Provider = 'zai'|'nim'; ModelId = '...'; ClaudeNimModel = 'nvidia_nim/...' }
# Мастер показывает только динамически получаемые списки моделей из endpoint провайдера.

function Read-SecretTextWizard([string]$Prompt) {
  Write-Host -NoNewline $Prompt
  $key = ""
  while ($true) {
    $cki = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    if ($cki.Key -eq "Enter" -or [int]$cki.Character -eq 13 -or [int]$cki.Character -eq 10) {
      Write-Host ""
      break
    } elseif ($cki.Key -eq "Backspace") {
      if ($key.Length -gt 0) {
        $key = $key.Substring(0, $key.Length - 1)
        Write-Host -NoNewline "`b `b"
      }
    } elseif ($cki.Key -eq "Escape") {
      Write-Host ""
      return ""
    } elseif ($cki.Character -and [int]$cki.Character -ge 32) {
      $key += $cki.Character
      Write-Host -NoNewline "*"
    }
  }
  return $key
}

function Resolve-ZaiKeyForWizard {
  $k = [Environment]::GetEnvironmentVariable("ZAI_API_KEY", "User")
  if ([string]::IsNullOrWhiteSpace($k) -or $k -eq "__SET_ME__") { $k = $env:ZAI_API_KEY }
  if ([string]::IsNullOrWhiteSpace($k) -or $k -eq "__SET_ME__") { $k = [Environment]::GetEnvironmentVariable("OPENAI_API_KEY", "User") }
  if ([string]::IsNullOrWhiteSpace($k) -or $k -eq "__SET_ME__") { $k = $env:OPENAI_API_KEY }
  if ([string]::IsNullOrWhiteSpace($k) -or $k -eq "__SET_ME__") {
    $k = Read-SecretTextWizard "Z.AI API key (не сохраняется)"
  }
  return $k.Trim()
}

function Resolve-NimKeyForWizard {
  $k = [Environment]::GetEnvironmentVariable("NVIDIA_NIM_API_KEY", "User")
  if ([string]::IsNullOrWhiteSpace($k)) { $k = $env:NVIDIA_NIM_API_KEY }
  if ([string]::IsNullOrWhiteSpace($k)) {
    $k = Read-SecretTextWizard "NVIDIA NIM API key (не сохраняется)"
  }
  return $k.Trim()
}

function Resolve-GroqKeyForWizard {
  $k = [Environment]::GetEnvironmentVariable("GROQ_API_KEY", "User")
  if ([string]::IsNullOrWhiteSpace($k)) { $k = $env:GROQ_API_KEY }
  if ([string]::IsNullOrWhiteSpace($k)) {
    $k = Read-SecretTextWizard "Groq API key (не сохраняется)"
  }
  return $k.Trim()
}

function Resolve-OpenRouterKeyForWizard {
  $k = [Environment]::GetEnvironmentVariable("OPENROUTER_API_KEY", "User")
  if ([string]::IsNullOrWhiteSpace($k)) { $k = $env:OPENROUTER_API_KEY }
  if ([string]::IsNullOrWhiteSpace($k)) {
    $k = Read-SecretTextWizard "OpenRouter API key (не сохраняется)"
  }
  return $k.Trim()
}

function Resolve-BaiKeyForWizard {
  $k = [Environment]::GetEnvironmentVariable("BAI_API_KEY", "User")
  if ([string]::IsNullOrWhiteSpace($k) -or $k -eq "__SET_ME__") { $k = $env:BAI_API_KEY }
  if ([string]::IsNullOrWhiteSpace($k) -or $k -eq "__SET_ME__") {
    $k = Read-SecretTextWizard "B.AI API key (не сохраняется)"
  }
  return $k.Trim()
}

function Invoke-LauncherCustomModelWizard {
  param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("Qwen", "Claude", "OpenCode")]
    [string]$App
  )

  $brand = $App
  $provItems = @(
    [pscustomobject]@{ Id = "zai-all";            Label = "Z.AI - все модели (Coding API, paid)" }
    [pscustomobject]@{ Id = "nim-all";            Label = "NVIDIA NIM - все модели (free + preview)" }
    [pscustomobject]@{ Id = "nim-free";           Label = "NVIDIA NIM - только бесплатные (free preview catalog)" }
    [pscustomobject]@{ Id = "nim-agentic";        Label = "NVIDIA NIM - только Agentic (tool calling, build.nvidia.com filter)" }
    [pscustomobject]@{ Id = "groq-all";           Label = "Groq - все модели (paid, /v1/models)" }
    [pscustomobject]@{ Id = "openrouter-all";     Label = "OpenRouter - все модели" }
    [pscustomobject]@{ Id = "openrouter-free";    Label = "OpenRouter - только бесплатные (pricing=0)" }
    [pscustomobject]@{ Id = "openrouter-agentic"; Label = "OpenRouter - только Agentic (supported_parameters: tools)" }
    [pscustomobject]@{ Id = "bai-all";            Label = "B.AI - все модели (api.b.ai/v1)" }
    [pscustomobject]@{ Id = "bai-agentic";        Label = "B.AI - только Agentic (tool/function calling)" }
  )

  # Groq не поддерживается для Claude Code (ограничение free-claude-code: nvidia_nim transport)
  if ($App -eq "Claude") {
    $provItems = @($provItems | Where-Object { $_.Id -notlike "groq*" })
  }

  while ($true) {
    $p1 = Show-TuiFramedMenu -AppBrand $brand -Title "Другая модель" -Subtitle "Шаг 1 из 2 - выберите провайдера" -Items $provItems -InitialIndex 0 -EscapeAction Back
    if ($null -eq $p1) { return $null }
    if ($true -eq $p1.__menuBack) { return [pscustomobject]@{ __menuBack = $true } }
    $provSource = [string]$p1.Id

    $ids = @()
    try {
      if ($provSource -eq "zai-all") {
        Show-TuiWaitFrame -AppBrand $brand -Message "Загрузка каталога моделей с API…"
        $key = Resolve-ZaiKeyForWizard
        $ids = @(Get-ZaiCodingModelIdsFromApi -ApiKey $key)
      }
      elseif ($provSource -eq "nim-all") {
        Show-TuiWaitFrame -AppBrand $brand -Message "Загрузка каталога NVIDIA NIM (полный список)…"
        $key = Resolve-NimKeyForWizard
        $ids = @(Get-NvidiaNimModelIdsFromApi -ApiKey $key)
      }
      elseif ($provSource -eq "nim-free") {
        Show-TuiWaitFrame -AppBrand $brand -Message "Загрузка каталога NVIDIA NIM (только free preview)…"
        $key = Resolve-NimKeyForWizard
        $ids = @(Get-NvidiaNimModelIdsFromApi -ApiKey $key -FilterToBundledFreeCatalog)
      }
      elseif ($provSource -eq "nim-agentic") {
        Show-TuiWaitFrame -AppBrand $brand -Message "Загрузка каталога NVIDIA NIM (Agentic фильтр)…"
        $key = Resolve-NimKeyForWizard
        $ids = @(Get-NvidiaNimModelIdsFromApi -ApiKey $key -AgenticOnly)
      }
      elseif ($provSource -eq "groq-all") {
        Show-TuiWaitFrame -AppBrand $brand -Message "Загрузка каталога Groq (paid)…"
        $key = Resolve-GroqKeyForWizard
        try {
          $ids = @(Get-GroqModelIdsFromApi -ApiKey $key)
        } catch {
          # DNS / timeout / network error — fallback на встроенный каталог free-моделей Groq
          Write-Host ("API Groq недоступен: {0}" -f $_.Exception.Message) -ForegroundColor DarkYellow
          $ids = @()
        }
        if ($ids.Count -eq 0) {
          # Fallback на встроенный список Groq (free tier)
          $ids = @(Get-GroqBundledFreeModelIds)
        }
      }
      elseif ($provSource -eq "openrouter-all") {
        Show-TuiWaitFrame -AppBrand $brand -Message "Загрузка каталога OpenRouter (все модели)…"
        $key = Resolve-OpenRouterKeyForWizard
        $ids = @(Get-OpenRouterModelIdsFromApi -ApiKey $key)
      }
      elseif ($provSource -eq "openrouter-free") {
        Show-TuiWaitFrame -AppBrand $brand -Message "Загрузка каталога OpenRouter (только free)…"
        $key = Resolve-OpenRouterKeyForWizard
        $ids = @(Get-OpenRouterFreeModelIdsFromApi -ApiKey $key)
        if ($ids.Count -eq 0) {
          # Fallback на встроенный список free
          $ids = @(Get-OpenRouterBundledFreeModelIds)
        }
      }
      elseif ($provSource -eq "openrouter-agentic") {
        Show-TuiWaitFrame -AppBrand $brand -Message "Загрузка каталога OpenRouter (Agentic: tools)…"
        $key = Resolve-OpenRouterKeyForWizard
        $ids = @(Get-OpenRouterAgenticModelIdsFromApi -ApiKey $key)
        if ($ids.Count -eq 0) {
          # Fallback на встроенный список Agentic
          $ids = @(Get-OpenRouterBundledAgenticModelIds)
        }
      }
      elseif ($provSource -eq "bai-all") {
        Show-TuiWaitFrame -AppBrand $brand -Message "Загрузка каталога B.AI (https://api.b.ai/v1/models)…"
        $key = Resolve-BaiKeyForWizard
        $ids = @(Get-BaiModelIdsFromApi -ApiKey $key)
        if ($ids.Count -eq 0) {
          # Fallback на встроенный список популярных моделей B.AI
          $ids = @(Get-BaiBundledPopularModelIds)
        }
      }
      elseif ($provSource -eq "bai-agentic") {
        Show-TuiWaitFrame -AppBrand $brand -Message "Загрузка каталога B.AI (Agentic фильтр)…"
        $key = Resolve-BaiKeyForWizard
        $apiIds = @(Get-BaiModelIdsFromApi -ApiKey $key)
        if ($apiIds.Count -gt 0) {
          # Пересечение ответа API с bundled Agentic whitelist
          $allowAgentic = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
          foreach ($x in @(Get-BaiBundledAgenticModelIds)) { [void]$allowAgentic.Add($x) }
          $ids = @($apiIds | Where-Object { $allowAgentic.Contains($_) })
        } else {
          $ids = @()
        }
        if ($ids.Count -eq 0) {
          # Fallback: API пуст или пересечение пустое — берём bundled Agentic напрямую
          $ids = @(Get-BaiBundledAgenticModelIds)
        }
      }
      else {
        throw ("Неизвестный провайдер: {0}" -f $provSource)
      }
    } catch {
      Write-Host ("Ошибка API: {0}" -f $_.Exception.Message) -ForegroundColor Red
      Write-Host "Нажмите любую клавишу…" -ForegroundColor DarkYellow
      $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
      return $null
    }

    if ($ids.Count -eq 0) {
      Write-Host "Провайдер вернул пустой список моделей." -ForegroundColor Red
      Write-Host "Нажмите любую клавишу…" -ForegroundColor DarkYellow
      $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
      return $null
    }

    $prov = if ($provSource -eq "zai-all") { "zai" }
            elseif ($provSource -eq "nim-all") { "nim" }
            elseif ($provSource -eq "nim-free") { "nim" }
            elseif ($provSource -eq "nim-agentic") { "nim" }
            elseif ($provSource -eq "groq-all") { "groq" }
            elseif ($provSource -eq "openrouter-all") { "openrouter" }
            elseif ($provSource -eq "openrouter-free") { "openrouter" }
            elseif ($provSource -eq "openrouter-agentic") { "openrouter" }
            elseif ($provSource -eq "bai-all") { "bai" }
            elseif ($provSource -eq "bai-agentic") { "bai" }
            else { $provSource }
    $provLabel = switch ($provSource) {
      "zai-all"            { "Z.AI (все)" }
      "nim-all"            { "NIM (полный)" }
      "nim-free"           { "NIM (free)" }
      "nim-agentic"        { "NIM (Agentic)" }
      "groq-all"           { "Groq (paid)" }
      "openrouter-all"     { "OpenRouter (все)" }
      "openrouter-free"    { "OpenRouter (free)" }
      "openrouter-agentic" { "OpenRouter (Agentic)" }
      "bai-all"            { "B.AI (все)" }
      "bai-agentic"        { "B.AI (Agentic)" }
      default              { $provSource.ToUpper() }
    }

    $modelItems = foreach ($id in $ids) {
      [pscustomobject]@{ Id = $id; Label = $id }
    }

    $pick = Show-TuiFramedMenu -AppBrand $brand -Title "Другая модель" -Subtitle ("Шаг 2 из 2 - {0}, моделей: {1}" -f $provLabel, $ids.Count) -Items $modelItems -InitialIndex 0 -MaxVisible 14 -EscapeAction Back
    if ($null -eq $pick) { return $null }
    if ($pick.__menuBack) { continue }

    $mid = [string]$pick.Id
    $claudeNim = $null
    if ($App -eq "Claude" -and $prov -eq "nim") {
      $claudeNim = Resolve-NvidiaNimFreeClaudeModel -OpenAiModelId $mid
    }

    return [pscustomobject]@{
      Provider        = $prov
      ModelId         = $mid
      ClaudeNimModel  = $claudeNim
    }
  }
}
