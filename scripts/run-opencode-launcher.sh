#!/bin/bash
# Меню OpenCode (облако) - Linux версия

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_FILE="$SCRIPT_DIR/opencode-launcher-state.json"
# Единое пространство (как у Qwen /resume): общий рабочий каталог + единый config
CONFIG_DIR="$SCRIPT_DIR/../opencode-sessions/_shared"

# Загрузка модулей
. "$SCRIPT_DIR/launcher-tui.sh"
. "$SCRIPT_DIR/launcher-api-keys.sh"

PROFILES=(
    "last|Запустить с последними настройками (быстрый старт)"
    "group:zai|Z.AI - GLM-5.1 / GLM-4.7 / GLM-4.7-Flash"
    "group:nim|NVIDIA NIM - бесплатные agentic модели"
    "group:bai|B.AI - DeepSeek/MiniMax/GLM/Kimi/GPT (OpenAI-compatible)"
    "group:openrouter|OpenRouter - бесплатные agentic модели"
    "custom-model|Другая модель… → выбор провайдера и модели"
    "native-login|Нативный логин (OpenCode Providers)"
    "change-api-key|Сменить ключ API провайдера"
)

# Submenus grouped by provider
ZAI_MODELS=(
    "zai-glm51|Z.AI - GLM-5.1 (paid, tool calling)"
    "zai-glm|Z.AI - GLM-4.7 (paid, tool calling)"
    "zai-flash47|Z.AI - GLM-4.7-Flash (free)"
)

NIM_MODELS=(
    "nim-mistral-medium|NIM - Mistral Medium 3.5 128B (free, tool calling)"
    "nim-glm51|NIM - Z.AI GLM-5.1 (free, tool calling)"
    "nim-step-3.5-flash|NIM - Step 3.5 Flash (free, tool calling)"
    "nim-mistral-large-3|NIM - Mistral Large 3 675B (free, tool calling)"
    "nim-deepseek-v4-flash|NIM - DeepSeek V4 Flash 284B MoE (free)"
    "nim-gemma-4-31b|NIM - Google Gemma-4 31B (free)"
    "nim-qwen3.5-397b|NIM - Qwen 3.5 397B A17B (free)"
    "nim-qwen3-next-80b|NIM - Qwen 3 Next 80B A3B (free)"
    "nim-qwen3-coder-480b|NIM - Qwen 3 Coder 480B A35B (free)"
)

OPENROUTER_MODELS=(
    "openrouter-deepseek-v4-flash|OpenRouter - DeepSeek V4 Flash (free, tool calling)"
    "openrouter-qwen3-coder|OpenRouter - Qwen3 Coder (free, tool calling)"
    "openrouter-nemotron|OpenRouter - Nemotron 3 Super 120B (free, tool calling)"
    "openrouter-laguna|OpenRouter - Poolside Laguna M.1 (free, tool calling, coding)"
)

BAI_MODELS=(
    "bai-gpt-5-nano|B.AI - GPT-5 Nano (OpenAI, agentic)"
    "bai-gpt-5-mini|B.AI - GPT-5 Mini (OpenAI, agentic)"
    "bai-gpt-5.2|B.AI - GPT-5.2 (OpenAI, agentic)"
    "bai-gpt-5.4-nano|B.AI - GPT-5.4 Nano (OpenAI, agentic)"
    "bai-gpt-5.4-mini|B.AI - GPT-5.4 Mini (OpenAI, agentic)"
    "bai-gpt-5.4|B.AI - GPT-5.4 (OpenAI, agentic)"
    "bai-gpt-5.4-pro|B.AI - GPT-5.4 Pro (OpenAI, agentic)"
    "bai-gpt-5.5|B.AI - GPT-5.5 (OpenAI, agentic)"
    "bai-gpt-5.5-instant|B.AI - GPT-5.5 Instant (OpenAI, agentic)"
    "bai-claude-haiku-4.5|B.AI - Claude Haiku 4.5 (Anthropic, agentic)"
    "bai-claude-sonnet-4.5|B.AI - Claude Sonnet 4.5 (Anthropic, agentic)"
    "bai-claude-sonnet-4.6|B.AI - Claude Sonnet 4.6 (Anthropic, agentic)"
    "bai-claude-opus-4.5|B.AI - Claude Opus 4.5 (Anthropic, agentic)"
    "bai-claude-opus-4.6|B.AI - Claude Opus 4.6 (Anthropic, agentic)"
    "bai-claude-opus-4.7|B.AI - Claude Opus 4.7 (Anthropic, agentic)"
    "bai-claude-opus-4.8|B.AI - Claude Opus 4.8 (Anthropic, agentic)"
    "bai-deepseek-v4-pro|B.AI - DeepSeek V4 Pro (agentic)"
    "bai-deepseek-v4-flash|B.AI - DeepSeek V4 Flash (agentic)"
    "bai-gemini-3.1-pro|B.AI - Gemini 3.1 Pro (Google, agentic)"
    "bai-gemini-3.5-flash|B.AI - Gemini 3.5 Flash (Google, agentic)"
    "bai-glm-5|B.AI - GLM-5 (Z.AI)"
    "bai-glm-5.1|B.AI - GLM-5.1 (Z.AI)"
    "bai-kimi-k2.5|B.AI - Kimi K2.5 (Moonshot)"
    "bai-kimi-k2.6|B.AI - Kimi K2.6 (Moonshot)"
    "bai-minimax-m3|B.AI - MiniMax M3 (agentic)"
    "bai-minimax-m2.7|B.AI - MiniMax M2.7 (fast)"
)

declare -A BAI_MODEL_SPEC=(
    ["gpt-5-nano"]="128000:16384"
    ["gpt-5-mini"]="128000:16384"
    ["gpt-5.2"]="200000:16384"
    ["gpt-5.4-nano"]="200000:16384"
    ["gpt-5.4-mini"]="200000:16384"
    ["gpt-5.4"]="200000:16384"
    ["gpt-5.4-pro"]="200000:16384"
    ["gpt-5.5"]="200000:16384"
    ["gpt-5.5-instant"]="200000:16384"
    ["claude-haiku-4.5"]="200000:8192"
    ["claude-sonnet-4.5"]="200000:8192"
    ["claude-sonnet-4.6"]="200000:8192"
    ["claude-opus-4.5"]="200000:8192"
    ["claude-opus-4.6"]="200000:8192"
    ["claude-opus-4.7"]="200000:8192"
    ["claude-opus-4.8"]="200000:8192"
    ["deepseek-v4-pro"]="131072:8192"
    ["deepseek-v4-flash"]="131072:8192"
    ["gemini-3.1-pro"]="1000000:8192"
    ["gemini-3.5-flash"]="1000000:8192"
    ["glm-5"]="128000:8192"
    ["glm-5.1"]="128000:8192"
    ["kimi-k2.5"]="131072:8192"
    ["kimi-k2.6"]="131072:8192"
    ["minimax-m3"]="1000000:8192"
    ["minimax-m2.7"]="1000000:8192"
)

get_launcher_state() {
    if [ ! -f "$STATE_FILE" ]; then
        return 1
    fi
    cat "$STATE_FILE"
}

resolve_api_key_or_prompt() {
    local current_key="$1"
    local provider_name="$2"
    local help_url="$3"

    if [ -z "$current_key" ]; then
        echo -e "${YELLOW}$provider_name API ключ не задан.${RESET}"
        echo -e "${CYAN}Получить ключ: $help_url${RESET}"
    fi

    if [ -z "$current_key" ]; then
        read_secret_text "$provider_name API key: "
    else
        echo "$current_key"
    fi
}

save_launcher_state() {
    local profile_id="$1"
    local extra="$2"
    
    local timestamp=$(date -Iseconds)
    local json="{\"profileId\":\"$profile_id\",\"updatedAt\":\"$timestamp\""
    
    if [ -n "$extra" ]; then
        json="$json,$extra"
    fi
    
    json="$json}"
    
    echo "$json" > "$STATE_FILE"
}

resolve_profile_from_state() {
    local state="$1"
    local profile_id=$(echo "$state" | grep -o '"profileId":"[^"]*"' | cut -d'"' -f4)
    
    case "$profile_id" in
        "zai-glm"|"zai-glm51"|"zai-flash47"|"zai-flash45"|\
        "nim-mistral-medium"|"nim-glm51"|"nim-step-3.5-flash"|"nim-mistral-large-3"|\
        "nim-deepseek-v4-flash"|"nim-gemma-4-31b"|"nim-qwen3.5-397b"|"nim-qwen3-next-80b"|"nim-qwen3-coder-480b"|\
        "nim-glm"|"nim-qwen"|\
        "openrouter-hy3"|"openrouter-deepseek-v4-flash"|"openrouter-qwen3-coder"|"openrouter-nemotron"|"openrouter-laguna"|\
        "custom-opencode-zai"|"custom-opencode-nim"|"custom-opencode-groq"|"custom-opencode-openrouter"|"custom-opencode-bai")
            echo "$profile_id"
            return 0
            ;;
        bai-*)
            local mid="${profile_id#bai-}"
            if [ -n "${BAI_MODEL_SPEC[$mid]:-}" ]; then
                echo "$profile_id"
                return 0
            fi
            return 1
            ;;
        zai-*|nim-*|openrouter-*)
            echo "$profile_id"
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

resolve_opencode_exe() {
    # Проверяем глобальную установку npm
    if command -v opencode &> /dev/null; then
        which opencode
        return 0
    fi
    
    # Проверяем npm global bin
    local npm_prefix
    npm_prefix=$(npm config get prefix 2>/dev/null || true)
    if [ -n "$npm_prefix" ] && [ -x "$npm_prefix/bin/opencode" ]; then
        echo "$npm_prefix/bin/opencode"
        return 0
    fi
    
    # Проверяем ~/.npm-global
    if [ -x "$HOME/.npm-global/bin/opencode" ]; then
        echo "$HOME/.npm-global/bin/opencode"
        return 0
    fi
    
    echo ""
    return 1
}

write_opencode_config() {
    local provider="$1"
    local model="$2"
    local base_url="$3"
    local api_key="$4"
    local max_tokens="${5:-8192}"
    local context_length="${6:-131072}"
    
    mkdir -p "$CONFIG_DIR"
    
    local config_path="$CONFIG_DIR/opencode.json"
    
    cat > "$config_path" << EOFJSON
{
  "\$schema": "https://opencode.ai/config.json",
  "provider": {
    "$provider": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "$provider",
      "options": {
        "baseURL": "$base_url",
        "apiKey": "$api_key"
      },
      "models": {
        "$model": {
          "name": "$model",
          "maxTokens": $max_tokens,
          "contextLength": $context_length
        }
      }
    }
  },
  "model": "$provider/$model"
}
EOFJSON
    
    echo "$config_path"
}

get_zai_api_key() {
    local key="${ZAI_API_KEY:-}"
    if [ -z "$key" ] || [ "$key" = "__SET_ME__" ]; then
        key=$(get_current_api_key "ZAI")
    fi
    if [ -z "$key" ] || [ "$key" = "__SET_ME__" ]; then
        printf "${YELLOW}Z.AI API ключ не задан.${RESET}\n" >&3
        printf "${CYAN}Получить ключ: https://console.z.ai/${RESET}\n" >&3
        local input
        input=$(read_secret_text "Z.AI API key: ")
        if [ -n "$input" ]; then
            set_provider_api_key "ZAI" "$input"
            echo "$input"
        fi
    else
        echo "$key"
    fi
}

get_nim_api_key() {
    local key="${NVIDIA_NIM_API_KEY:-}"
    if [ -z "$key" ]; then
        key=$(get_current_api_key "NVIDIA_NIM")
    fi
    if [ -z "$key" ]; then
        printf "${YELLOW}NVIDIA NIM API ключ не задан.${RESET}\n" >&3
        printf "${CYAN}Получить ключ: https://build.nvidia.com/api-key${RESET}\n" >&3
        local input
        input=$(read_secret_text "NVIDIA NIM API key: ")
        if [ -n "$input" ]; then
            set_provider_api_key "NVIDIA_NIM" "$input"
            echo "$input"
        fi
    else
        echo "$key"
    fi
}

get_groq_api_key() {
    local key="${GROQ_API_KEY:-}"
    if [ -z "$key" ]; then
        key=$(get_current_api_key "GROQ")
    fi
    if [ -z "$key" ]; then
        printf "${YELLOW}Groq API ключ не задан.${RESET}\n" >&3
        printf "${CYAN}Получить ключ: https://console.groq.com/keys${RESET}\n" >&3
        local input
        input=$(read_secret_text "Groq API key: ")
        if [ -n "$input" ]; then
            set_provider_api_key "GROQ" "$input"
            echo "$input"
        fi
    else
        echo "$key"
    fi
}

get_openrouter_api_key() {
    local key="${OPENROUTER_API_KEY:-}"
    if [ -z "$key" ]; then
        key=$(get_current_api_key "OPENROUTER")
    fi
    if [ -z "$key" ]; then
        printf "${YELLOW}OpenRouter API ключ не задан.${RESET}\n" >&3
        printf "${CYAN}Получить ключ: https://openrouter.ai/settings/keys${RESET}\n" >&3
        local input
        input=$(read_secret_text "OpenRouter API key: ")
        if [ -n "$input" ]; then
            set_provider_api_key "OPENROUTER" "$input"
            echo "$input"
        fi
    else
        echo "$key"
    fi
}

get_bai_api_key() {
    local key="${BAI_API_KEY:-}"
    if [ -z "$key" ] || [ "$key" = "__SET_ME__" ]; then
        key=$(get_current_api_key "BAI")
    fi
    if [ -z "$key" ] || [ "$key" = "__SET_ME__" ]; then
        printf "${YELLOW}B.AI API ключ не задан.${RESET}\n" >&3
        printf "${CYAN}Получить ключ: https://chat.b.ai/key${RESET}\n" >&3
        local input
        input=$(read_secret_text "B.AI API key: ")
        if [ -n "$input" ]; then
            set_provider_api_key "BAI" "$input"
            echo "$input"
        fi
    else
        echo "$key"
    fi
}

invoke_opencode_profile() {
    local profile_id="$1"
    
    # Проверка API ключа
    local env_var=""
    local provider_name=""
    local provider_url=""
    case "$profile_id" in
        zai-*|custom-opencode-zai*) env_var="ZAI"; provider_name="Z.AI"; provider_url="https://console.z.ai/" ;;
        nim-*|custom-opencode-nim*) env_var="NVIDIA_NIM"; provider_name="NVIDIA NIM"; provider_url="https://build.nvidia.com/api-key" ;;
        openrouter-*|custom-opencode-openrouter*) env_var="OPENROUTER"; provider_name="OpenRouter"; provider_url="https://openrouter.ai/settings/keys" ;;
        bai-*|custom-opencode-bai*) env_var="BAI"; provider_name="B.AI"; provider_url="https://chat.b.ai/key" ;;
    esac
    if [ -n "$env_var" ]; then
        if ! ensure_api_key_or_prompt "$env_var" "$provider_name" "$provider_url"; then
            return 1
        fi
    fi
    
    local opencode_exe
    opencode_exe=$(resolve_opencode_exe) || true
    if [ -z "$opencode_exe" ]; then
        echo -e "${RED}OpenCode CLI не найден. Установите: npm install -g opencode-ai@latest${RESET}"
        return 1
    fi
    
    case "$profile_id" in
        "zai-glm")
            local api_key
            api_key=$(get_zai_api_key) || true
            local config_path
            config_path=$(write_opencode_config "zai" "glm-4.7" "https://api.z.ai/api/coding/paas/v4" "$api_key")
            export OPENCODE_CONFIG="$config_path"
            echo -e "${CYAN}Запуск OpenCode (Z.AI GLM-4.7)…${RESET}"
            "$opencode_exe"
            ;;
        "zai-glm51")
            local api_key
            api_key=$(get_zai_api_key) || true
            local config_path
            config_path=$(write_opencode_config "zai" "glm-5.1" "https://api.z.ai/api/coding/paas/v4" "$api_key")
            export OPENCODE_CONFIG="$config_path"
            echo -e "${CYAN}Запуск OpenCode (Z.AI GLM-5.1)…${RESET}"
            "$opencode_exe"
            ;;
        "zai-flash47")
            local api_key
            api_key=$(get_zai_api_key) || true
            local config_path
            config_path=$(write_opencode_config "zai" "glm-4.7-flash" "https://api.z.ai/api/coding/paas/v4" "$api_key")
            export OPENCODE_CONFIG="$config_path"
            echo -e "${CYAN}Запуск OpenCode (Z.AI GLM-4.7-Flash)…${RESET}"
            "$opencode_exe"
            ;;
        "zai-flash45")
            local api_key
            api_key=$(get_zai_api_key) || true
            local config_path
            config_path=$(write_opencode_config "zai" "glm-4.5-flash" "https://api.z.ai/api/coding/paas/v4" "$api_key")
            export OPENCODE_CONFIG="$config_path"
            echo -e "${CYAN}Запуск OpenCode (Z.AI GLM-4.5-Flash)…${RESET}"
            "$opencode_exe"
            ;;
        "nim-glm")
            local api_key
            api_key=$(get_nim_api_key) || true
            local config_path
            config_path=$(write_opencode_config "nvidia-nim" "qwen/qwen3.5-122b-a10b" "https://integrate.api.nvidia.com/v1" "$api_key")
            export OPENCODE_CONFIG="$config_path"
            echo -e "${CYAN}Запуск OpenCode (NVIDIA NIM Qwen3.5-122B-A10B)…${RESET}"
            "$opencode_exe"
            ;;
        "nim-qwen")
            local api_key
            api_key=$(get_nim_api_key) || true
            local config_path
            config_path=$(write_opencode_config "nvidia-nim" "qwen/qwen3.5-122b-a10b" "https://integrate.api.nvidia.com/v1" "$api_key")
            export OPENCODE_CONFIG="$config_path"
            echo -e "${CYAN}Запуск OpenCode (NVIDIA NIM Qwen3.5-122B-A10B)…${RESET}"
            "$opencode_exe"
            ;;
        "nim-mistral-medium")
            local api_key
            api_key=$(get_nim_api_key) || true
            local config_path
            config_path=$(write_opencode_config "nvidia-nim" "mistralai/mistral-medium-3.5-128b" "https://integrate.api.nvidia.com/v1" "$api_key")
            export OPENCODE_CONFIG="$config_path"
            echo -e "${CYAN}Запуск OpenCode (NVIDIA NIM Mistral Medium 3.5 128B)…${RESET}"
            "$opencode_exe"
            ;;
        "nim-glm51")
            local api_key
            api_key=$(get_nim_api_key) || true
            local config_path
            config_path=$(write_opencode_config "nvidia-nim" "z-ai/glm-5.1" "https://integrate.api.nvidia.com/v1" "$api_key")
            export OPENCODE_CONFIG="$config_path"
            echo -e "${CYAN}Запуск OpenCode (NVIDIA NIM Z.AI GLM-5.1)…${RESET}"
            "$opencode_exe"
            ;;
        "nim-step-3.5-flash")
            local api_key
            api_key=$(get_nim_api_key) || true
            local config_path
            config_path=$(write_opencode_config "nvidia-nim" "stepfun-ai/step-3.5-flash" "https://integrate.api.nvidia.com/v1" "$api_key")
            export OPENCODE_CONFIG="$config_path"
            echo -e "${CYAN}Запуск OpenCode (NVIDIA NIM Step 3.5 Flash)…${RESET}"
            "$opencode_exe"
            ;;
        "nim-mistral-large-3")
            local api_key
            api_key=$(get_nim_api_key) || true
            local config_path
            config_path=$(write_opencode_config "nvidia-nim" "mistralai/mistral-large-3-675b-instruct-2512" "https://integrate.api.nvidia.com/v1" "$api_key")
            export OPENCODE_CONFIG="$config_path"
            echo -e "${CYAN}Запуск OpenCode (NVIDIA NIM Mistral Large 3 675B)…${RESET}"
            "$opencode_exe"
            ;;
        "nim-deepseek-v4-flash")
            local api_key
            api_key=$(get_nim_api_key) || true
            local config_path
            config_path=$(write_opencode_config "nvidia-nim" "deepseek-ai/deepseek-v4-flash" "https://integrate.api.nvidia.com/v1" "$api_key")
            export OPENCODE_CONFIG="$config_path"
            echo -e "${CYAN}Запуск OpenCode (NVIDIA NIM DeepSeek V4 Flash)…${RESET}"
            "$opencode_exe"
            ;;
        "nim-gemma-4-31b")
            local api_key
            api_key=$(get_nim_api_key) || true
            local config_path
            config_path=$(write_opencode_config "nvidia-nim" "google/gemma-4-31b-it" "https://integrate.api.nvidia.com/v1" "$api_key")
            export OPENCODE_CONFIG="$config_path"
            echo -e "${CYAN}Запуск OpenCode (NVIDIA NIM Gemma-4 31B)…${RESET}"
            "$opencode_exe"
            ;;
        "nim-qwen3.5-397b")
            local api_key
            api_key=$(get_nim_api_key) || true
            local config_path
            config_path=$(write_opencode_config "nvidia-nim" "qwen/qwen3.5-397b-a17b" "https://integrate.api.nvidia.com/v1" "$api_key")
            export OPENCODE_CONFIG="$config_path"
            echo -e "${CYAN}Запуск OpenCode (NVIDIA NIM Qwen 3.5 397B)…${RESET}"
            "$opencode_exe"
            ;;
        "nim-qwen3-next-80b")
            local api_key
            api_key=$(get_nim_api_key) || true
            local config_path
            config_path=$(write_opencode_config "nvidia-nim" "qwen/qwen3-next-80b-a3b-instruct" "https://integrate.api.nvidia.com/v1" "$api_key")
            export OPENCODE_CONFIG="$config_path"
            echo -e "${CYAN}Запуск OpenCode (NVIDIA NIM Qwen 3 Next 80B)…${RESET}"
            "$opencode_exe"
            ;;
        "nim-qwen3-coder-480b")
            local api_key
            api_key=$(get_nim_api_key) || true
            local config_path
            config_path=$(write_opencode_config "nvidia-nim" "qwen/qwen3-coder-480b-a35b-instruct" "https://integrate.api.nvidia.com/v1" "$api_key")
            export OPENCODE_CONFIG="$config_path"
            echo -e "${CYAN}Запуск OpenCode (NVIDIA NIM Qwen 3 Coder 480B)…${RESET}"
            "$opencode_exe"
            ;;
        bai-*)
            local mid="${profile_id#bai-}"
            local spec="${BAI_MODEL_SPEC[$mid]:-}"
            if [ -z "$spec" ]; then
                echo -e "${RED}Неизвестная B.AI модель: $mid${RESET}"
                return 1
            fi
            local ctx="${spec%:*}"
            local max="${spec#*:}"
            local api_key
            api_key=$(get_bai_api_key) || true
            local config_path
            config_path=$(write_opencode_config "bai" "$mid" "https://api.b.ai/v1" "$api_key" "$max" "$ctx")
            export OPENCODE_CONFIG="$config_path"
            echo -e "${CYAN}Запуск OpenCode (B.AI $mid)…${RESET}"
            "$opencode_exe"
            ;;
        "openrouter-hy3"|"openrouter-deepseek-v4-flash")
            local api_key
            api_key=$(get_openrouter_api_key)
            if [ -z "$api_key" ]; then
                echo -e "${YELLOW}OpenRouter API ключ не задан.${RESET}"
                read -p "Нажмите Enter для продолжения..."
                return 0
            fi
            local config_path
            config_path=$(write_opencode_config "openrouter" "deepseek/deepseek-chat-v3.1:free" "https://openrouter.ai/api/v1" "$api_key" 8192 1048576)
            export OPENCODE_CONFIG="$config_path"
            echo -e "${CYAN}Запуск OpenCode (OpenRouter DeepSeek V4 Flash)…${RESET}"
            "$opencode_exe"
            ;;
        "openrouter-qwen3-coder")
            local api_key
            api_key=$(get_openrouter_api_key)
            if [ -z "$api_key" ]; then
                echo -e "${YELLOW}OpenRouter API ключ не задан.${RESET}"
                read -p "Нажмите Enter для продолжения..."
                return 0
            fi
            local config_path
            config_path=$(write_opencode_config "openrouter" "qwen/qwen3-coder:free" "https://openrouter.ai/api/v1" "$api_key" 8192 262000)
            export OPENCODE_CONFIG="$config_path"
            echo -e "${CYAN}Запуск OpenCode (OpenRouter Qwen3 Coder)…${RESET}"
            "$opencode_exe"
            ;;
        "openrouter-nemotron")
            local api_key
            api_key=$(get_openrouter_api_key)
            if [ -z "$api_key" ]; then
                echo -e "${YELLOW}OpenRouter API ключ не задан.${RESET}"
                read -p "Нажмите Enter для продолжения..."
                return 0
            fi
            local config_path
            config_path=$(write_opencode_config "openrouter" "nvidia/nemotron-3-super-120b-a12b:free" "https://openrouter.ai/api/v1" "$api_key" 8192 262144)
            export OPENCODE_CONFIG="$config_path"
            echo -e "${CYAN}Запуск OpenCode (OpenRouter Nemotron 3 Super)…${RESET}"
            "$opencode_exe"
            ;;
        "openrouter-laguna")
            local api_key
            api_key=$(get_openrouter_api_key)
            if [ -z "$api_key" ]; then
                echo -e "${YELLOW}OpenRouter API ключ не задан.${RESET}"
                read -p "Нажмите Enter для продолжения..."
                return 0
            fi
            local config_path
            config_path=$(write_opencode_config "openrouter" "poolside/laguna-m.1:free" "https://openrouter.ai/api/v1" "$api_key" 8192 131072)
            export OPENCODE_CONFIG="$config_path"
            echo -e "${CYAN}Запуск OpenCode (OpenRouter Poolside Laguna M.1)…${RESET}"
            "$opencode_exe"
            ;;
        "custom-opencode-zai")
            local state
            state=$(get_launcher_state) || true
            local model_id=$(echo "$state" | grep -o '"customModelId":"[^"]*"' | cut -d'"' -f4)
            
            if [ -z "$model_id" ]; then
                echo -e "${RED}Нет customModelId. Выберите модель в пункте «Другая модель».${RESET}"
                return 1
            fi
            
            local api_key
            api_key=$(get_zai_api_key) || true
            local config_path
            config_path=$(write_opencode_config "zai" "$model_id" "https://api.z.ai/api/coding/paas/v4" "$api_key")
            export OPENCODE_CONFIG="$config_path"
            echo -e "${CYAN}Запуск OpenCode (Z.AI custom: $model_id)…${RESET}"
            "$opencode_exe"
            ;;
        "custom-opencode-nim")
            local state
            state=$(get_launcher_state) || true
            local model_id=$(echo "$state" | grep -o '"customModelId":"[^"]*"' | cut -d'"' -f4)
            
            if [ -z "$model_id" ]; then
                echo -e "${RED}Нет customModelId. Выберите модель в пункте «Другая модель».${RESET}"
                return 1
            fi
            
            local api_key
            api_key=$(get_nim_api_key) || true
            local config_path
            config_path=$(write_opencode_config "nvidia-nim" "$model_id" "https://integrate.api.nvidia.com/v1" "$api_key")
            export OPENCODE_CONFIG="$config_path"
            echo -e "${CYAN}Запуск OpenCode (NVIDIA NIM custom: $model_id)…${RESET}"
            "$opencode_exe"
            ;;
        "custom-opencode-groq")
            local state
            state=$(get_launcher_state) || true
            local model_id=$(echo "$state" | grep -o '"customModelId":"[^"]*"' | cut -d'"' -f4)
            if [ -z "$model_id" ]; then
                echo -e "${RED}Нет customModelId для Groq. Выберите модель в «Другая модель».${RESET}"
                return 1
            fi
            local api_key="${GROQ_API_KEY:-}"
            if [ -z "$api_key" ]; then
                echo -e "${YELLOW}Groq API ключ не задан. Задайте GROQ_API_KEY.${RESET}" >&2
                return 1
            fi
            local config_path
            config_path=$(write_opencode_config "groq" "$model_id" "https://api.groq.com/openai/v1" "$api_key" 8192 131072)
            export OPENCODE_CONFIG="$config_path"
            echo -e "${CYAN}Запуск OpenCode (Groq custom: $model_id)…${RESET}"
            "$opencode_exe"
            ;;
        "custom-opencode-openrouter")
            local state
            state=$(get_launcher_state) || true
            local model_id=$(echo "$state" | grep -o '"customModelId":"[^"]*"' | cut -d'"' -f4)
            if [ -z "$model_id" ]; then
                echo -e "${RED}Нет customModelId для OpenRouter. Выберите модель в «Другая модель».${RESET}"
                return 1
            fi
            local api_key="${OPENROUTER_API_KEY:-}"
            if [ -z "$api_key" ]; then
                echo -e "${YELLOW}OpenRouter API ключ не задан. Задайте OPENROUTER_API_KEY.${RESET}" >&2
                return 1
            fi
            local config_path
            config_path=$(write_opencode_config "openrouter" "$model_id" "https://openrouter.ai/api/v1" "$api_key" 8192 16384)
            export OPENCODE_CONFIG="$config_path"
            echo -e "${CYAN}Запуск OpenCode (OpenRouter custom: $model_id)…${RESET}"
            "$opencode_exe"
            ;;
        "custom-opencode-bai")
            local state
            state=$(get_launcher_state) || true
            local model_id=$(echo "$state" | grep -o '"customModelId":"[^"]*"' | cut -d'"' -f4)
            if [ -z "$model_id" ]; then
                echo -e "${RED}Нет customModelId для B.AI. Выберите модель в «Другая модель».${RESET}"
                return 1
            fi
            local api_key
            api_key=$(get_bai_api_key) || true
            local config_path
            config_path=$(write_opencode_config "bai" "$model_id" "https://api.b.ai/v1" "$api_key" 8192 131072)
            export OPENCODE_CONFIG="$config_path"
            echo -e "${CYAN}Запуск OpenCode (B.AI custom: $model_id)…${RESET}"
            "$opencode_exe"
            ;;
        *)
            echo -e "${RED}Неизвестный профиль: $profile_id${RESET}"
            return 1
            ;;
    esac
}

invoke_opencode_dynamic_fallback() {
    local profile_id="$1"
    local raw_model="" provider="" base_url="" api_key=""

    case "$profile_id" in
        zai-*)
            raw_model="${profile_id#zai-}"
            provider="zai"
            base_url="https://api.z.ai/api/coding/paas/v4"
            api_key=$(get_zai_api_key) || return 1
            ;;
        nim-*)
            raw_model="${profile_id#nim-}"
            provider="nvidia-nim"
            base_url="https://integrate.api.nvidia.com/v1"
            api_key=$(get_nim_api_key) || return 1
            ;;
        openrouter-*)
            raw_model="${profile_id#openrouter-}"
            provider="openrouter"
            base_url="https://openrouter.ai/api/v1"
            api_key=$(get_openrouter_api_key) || return 1
            ;;
        *)
            echo -e "${RED}Неизвестный профиль: $profile_id${RESET}"
            return 1
            ;;
    esac

    local opencode_exe
    opencode_exe=$(resolve_opencode_exe) || true
    if [ -z "$opencode_exe" ]; then
        echo -e "${RED}OpenCode CLI не найден. Установите: npm install -g opencode-ai@latest${RESET}"
        return 1
    fi

    local config_path
    config_path=$(write_opencode_config "$provider" "$raw_model" "$base_url" "$api_key")
    export OPENCODE_CONFIG="$config_path"
    echo -e "${CYAN}Запуск OpenCode ($provider $raw_model)…${RESET}"
    "$opencode_exe"
}

# ── Мастер выбора модели (упрощённый для Linux) ────────────────────────────────

invoke_custom_model_wizard() {
    local app_brand="$1"
    
    local prov_items=(
        "zai|Z.AI - Coding / Anthropic (GET /models по вашему ключу)"
        "nim|NVIDIA NIM - полный каталог (GET /v1/models)"
        "groq|Groq - полный каталог моделей (paid, GET /v1/models)"
        "openrouter|OpenRouter - полный каталог моделей (GET /v1/models)"
        "bai|B.AI - DeepSeek/MiniMax/GLM/Kimi/GPT (GET /v1/models)"
    )
    
    while true; do
        local prov_menu=()
        for item in "${prov_items[@]}"; do
            local label="${item##*|}"
            prov_menu+=("$label")
        done
        
        local prov_choice
        prov_choice="$(show_tui_numbered_menu "$app_brand" "Другая модель" "Шаг 1 из 2 - выберите провайдера" "${prov_menu[@]}")"
        
        if [ "${prov_choice:-0}" -eq 0 ]; then
            return 1
        fi
        
        local prov_source=$(echo "${prov_items[$((prov_choice-1))]}" | cut -d'|' -f1)
        
        local ids=()
        local key=""
        
        if [ "$prov_source" = "zai" ]; then
            show_tui_wait_frame "$app_brand" "Загрузка каталога моделей Z.AI с API…"
            key=$(get_zai_api_key) || { echo -e "${RED}Не удалось получить API ключ${RESET}"; read -p "Нажмите Enter..."; return 1; }
            
            # Получаем список моделей через API
            local response
            response=$(curl -s -H "Authorization: Bearer $key" "https://api.z.ai/api/coding/paas/v4/models" 2>/dev/null) || true
            if [ -z "$response" ]; then
                response=$(curl -s -H "Authorization: Bearer $key" "https://api.z.ai/api/paas/v4/models" 2>/dev/null) || true
            fi
            
            if [ -n "$response" ]; then
                ids=($(echo "$response" | grep -o '"id":"[^"]*"' | cut -d'"' -f4 | sort -u))
            fi
            
        elif [ "$prov_source" = "nim" ]; then
            show_tui_wait_frame "$app_brand" "Загрузка каталога NVIDIA NIM…"
            key=$(get_nim_api_key) || { echo -e "${RED}Не удалось получить API ключ${RESET}"; read -p "Нажмите Enter..."; return 1; }
            
            local response
            response=$(curl -s -H "Authorization: Bearer $key" "https://integrate.api.nvidia.com/v1/models" 2>/dev/null) || true
            
            if [ -n "$response" ]; then
                ids=($(echo "$response" | grep -o '"id":"[^"]*"' | cut -d'"' -f4 | sort -u))
            fi
        elif [ "$prov_source" = "groq" ]; then
            show_tui_wait_frame "$app_brand" "Загрузка каталога Groq…"
            key=$(get_groq_api_key) || { echo -e "${RED}Не удалось получить API ключ${RESET}"; read -p "Нажмите Enter..."; return 1; }
            
            local response
            response=$(curl -s -H "Authorization: Bearer $key" -H "Content-Type: application/json" "https://api.groq.com/openai/v1/models" 2>/dev/null) || true
            
            if [ -n "$response" ]; then
                ids=($(echo "$response" | grep -o '"id":"[^"]*"' | cut -d'"' -f4 | sort -u))
            fi
        elif [ "$prov_source" = "openrouter" ]; then
            show_tui_wait_frame "$app_brand" "Загрузка каталога OpenRouter…"
            key=$(get_openrouter_api_key) || { echo -e "${RED}Не удалось получить API ключ${RESET}"; read -p "Нажмите Enter..."; return 1; }
            
            local response
            response=$(curl -s -H "Authorization: Bearer $key" -H "Content-Type: application/json" "https://openrouter.ai/api/v1/models" 2>/dev/null) || true
            
            if [ -n "$response" ]; then
                ids=($(echo "$response" | grep -o '"id":"[^"]*"' | cut -d'"' -f4 | sort -u))
            fi
        elif [ "$prov_source" = "bai" ]; then
            show_tui_wait_frame "$app_brand" "Загрузка каталога B.AI…"
            key=$(get_bai_api_key) || { echo -e "${RED}Не удалось получить API ключ${RESET}"; read -p "Нажмите Enter..."; return 1; }
            
            local response
            response=$(curl -s -H "Authorization: Bearer $key" -H "Content-Type: application/json" "https://api.b.ai/v1/models" 2>/dev/null) || true
            
            if [ -n "$response" ]; then
                ids=($(echo "$response" | grep -o '"id":"[^"]*"' | cut -d'"' -f4 | sort -u))
            fi
        fi
        
        if [ ${#ids[@]} -eq 0 ]; then
            echo -e "${RED}Провайдер вернул пустой список моделей.${RESET}"
            read -p "Нажмите Enter…"
            return 1
        fi
        
        local model_menu=()
        for id in "${ids[@]}"; do
            model_menu+=("$id")
        done
        
        local model_choice
        model_choice="$(show_tui_numbered_menu "$app_brand" "Другая модель" "Шаг 2 из 2 - моделей: ${#ids[@]}" "${model_menu[@]}")"
        
        if [ "${model_choice:-0}" -eq 0 ]; then
            continue
        fi
        
        local model_id="${ids[$((model_choice-1))]}"
        local prov="nim"
        if [ "$prov_source" = "zai" ]; then
            prov="zai"
        elif [ "$prov_source" = "groq" ]; then
            prov="groq"
        elif [ "$prov_source" = "openrouter" ]; then
            prov="openrouter"
        elif [ "$prov_source" = "bai" ]; then
            prov="bai"
        fi
        
        echo "$prov|$model_id"
        return 0
    done
}

# ── Быстрый старт ────────────────────────────────────────────────────────────

if [ "${OPENCODE_LAUNCHER_QUICK:-0}" = "1" ]; then
    if state=$(get_launcher_state); then
        if resolved_id=$(resolve_profile_from_state "$state"); then
            invoke_opencode_profile "$resolved_id"
            exit $?
        fi
    fi
    
    echo -e "${YELLOW}Нет сохранённого профиля. Один раз выберите модель в меню.${RESET}"
    sleep 3
    exit 2
fi

# ── Dynamic model fetching (with static fallback) ────────────────────────────
echo -e "${GRAY}Загрузка списков моделей...${RESET}" >&3

DYNAMIC_ZAI_OC=()
mapfile -t DYNAMIC_ZAI_OC < <(fetch_menu_items "ZAI_API_KEY" \
    "https://api.z.ai/api/coding/paas/v4/models" "zai-" \
    "glm-5.1:zai-glm51|glm-4.7:zai-glm|glm-4.7-flash:zai-flash47" \
    "zai-flash47" "" \
    "zai-glm51|Z.AI - GLM-5.1 (paid, tool calling)" \
    "zai-glm|Z.AI - GLM-4.7 (paid, tool calling)" \
    "zai-flash47|Z.AI - GLM-4.7-Flash (free)" 2>/dev/null) || true
if [ ${#DYNAMIC_ZAI_OC[@]} -gt 0 ]; then ZAI_MODELS=("${DYNAMIC_ZAI_OC[@]}"); fi

DYNAMIC_NIM_OC=()
mapfile -t DYNAMIC_NIM_OC < <(fetch_menu_items "NVIDIA_NIM_API_KEY" \
    "https://integrate.api.nvidia.com/v1/models" "nim-" \
    "mistralai/mistral-medium-3.5-128b:nim-mistral-medium|z-ai/glm-5.1:nim-glm51|stepfun-ai/step-3.5-flash:nim-step-3.5-flash|mistralai/mistral-large-3-675b-instruct-2512:nim-mistral-large-3|deepseek-ai/deepseek-v4-flash:nim-deepseek-v4-flash|google/gemma-4-31b-it:nim-gemma-4-31b|qwen/qwen3.5-397b-a17b:nim-qwen3.5-397b|qwen/qwen3-next-80b-a3b-instruct:nim-qwen3-next-80b|qwen/qwen3-coder-480b-a35b-instruct:nim-qwen3-coder-480b" \
    "" "$(printf '%s|' "${NIM_AGENTIC_IDS[@]}" | sed 's/|$//')" \
    "${NIM_MODELS[@]}" 2>/dev/null) || true
if [ ${#DYNAMIC_NIM_OC[@]} -gt 0 ]; then NIM_MODELS=("${DYNAMIC_NIM_OC[@]}"); fi

DYNAMIC_BAI_OC=()
mapfile -t DYNAMIC_BAI_OC < <(fetch_menu_items "BAI_API_KEY" \
    "https://api.b.ai/v1/models" "bai-" "" "" "" \
    "${BAI_MODELS[@]}" 2>/dev/null) || true
if [ ${#DYNAMIC_BAI_OC[@]} -gt 0 ]; then BAI_MODELS=("${DYNAMIC_BAI_OC[@]}"); fi

DYNAMIC_OR_OC=()
mapfile -t DYNAMIC_OR_OC < <(fetch_or_free_menu_items "OPENROUTER_API_KEY" "openrouter-" \
    "deepseek/deepseek-chat-v3.1:free:openrouter-deepseek-v4-flash|qwen/qwen3-coder:free:openrouter-qwen3-coder|nvidia/nemotron-3-super-120b-a12b:free:openrouter-nemotron|poolside/laguna-m.1:free:openrouter-laguna" \
    "${OPENROUTER_MODELS[@]}" 2>/dev/null) || true
if [ ${#DYNAMIC_OR_OC[@]} -gt 0 ]; then OPENROUTER_MODELS=("${DYNAMIC_OR_OC[@]}"); fi

# ── Главное меню ─────────────────────────────────────────────────────────────

main() {
local update_hint=$(test_launcher_updates)
while true; do
    local state=$(get_launcher_state 2>/dev/null || true)
    local last_id=$(resolve_profile_from_state "$state" 2>/dev/null || true)
    
    # Подготовка списка пунктов меню
    local menu_items=()
    for profile in "${PROFILES[@]}"; do
        local label="${profile##*|}"
        menu_items+=("$label")
    done
    
    local choice
    choice="$(show_tui_framed_menu "OpenCode" "OpenCode - выбор провайдера" "Z.AI · NIM · OpenRouter · B.AI (OpenAI-compatible)" ${update_hint:+"$update_hint"} "${menu_items[@]}")"
    
    if [ "${choice:-0}" -eq 0 ]; then
        continue
    fi
    
    local profile_id=$(echo "${PROFILES[$((choice-1))]}" | cut -d'|' -f1)
    
    case "$profile_id" in
        group:*)
            local group_key="${profile_id#group:}"
            local group_items=()
            local subtitle=""
            case "$group_key" in
                zai)
                    subtitle="Z.AI Coding (paid) + GLM-4.7-Flash"
                    group_items=("${ZAI_MODELS[@]}")
                    ;;
                nim)
                    subtitle="NVIDIA NIM - 9 бесплатных agentic моделей"
                    group_items=("${NIM_MODELS[@]}")
                    ;;
                openrouter)
                    subtitle="OpenRouter - бесплатные agentic модели"
                    group_items=("${OPENROUTER_MODELS[@]}")
                    ;;
                bai)
                    subtitle="B.AI - https://api.b.ai/v1 (OpenAI-compatible)"
                    group_items=("${BAI_MODELS[@]}")
                    ;;
                *)
                    echo -e "${RED}Не найдено подменю для группы: $group_key${RESET}"
                    sleep 2
                    continue
                    ;;
            esac
            
            local sub_menu=()
            for item in "${group_items[@]}"; do
                sub_menu+=("${item##*|}")
            done
            
            local group_upper="${group_key^^}"
            local sub_choice
            sub_choice=$(show_tui_framed_menu "OpenCode" "OpenCode - $group_upper" "$subtitle" "${sub_menu[@]}")
            
            if [ "${sub_choice:-0}" -eq 0 ]; then
                continue
            fi
            
            profile_id=$(echo "${group_items[$((sub_choice-1))]}" | cut -d'|' -f1)
            save_launcher_state "$profile_id"
            invoke_opencode_profile "$profile_id"
            continue
            ;;
        "native-login")
            local opencode_exe
            opencode_exe=$(resolve_opencode_exe) || true
            if [ -z "$opencode_exe" ]; then
                echo -e "${RED}OpenCode CLI не найден. Установите: npm install -g opencode-ai@latest${RESET}"
                echo -e "${GREEN}Нажмите Enter для возврата в меню…${RESET}"
                read
                continue
            fi
            local login_items=("providers-login|Вход через провайдера (opencode providers login)" "providers-list|Показать подключённых провайдеров" "vanilla|Запуск OpenCode (ванильный запуск)")
            local login_menu=()
            for item in "${login_items[@]}"; do
                login_menu+=("${item##*|}")
            done

            local login_choice
            login_choice="$(show_tui_numbered_menu "OpenCode" "Нативный логин OpenCode" "Выберите действие" "${login_menu[@]}")"

            if [ "${login_choice:-0}" -eq 0 ]; then
                continue
            fi

            local login_id=$(echo "${login_items[$((login_choice-1))]}" | cut -d'|' -f1)

            case "$login_id" in
                "providers-login")
                    clear
                    echo -e "${CYAN}═══════════════════════════════════════════════════${RESET}"
                    echo -e "${CYAN}  OpenCode - вход через провайдера${RESET}"
                    echo -e "${CYAN}═══════════════════════════════════════════════════${RESET}"
                    echo ""
                    echo -e "${YELLOW}  Выберите провайдера и следуйте инструкциям.${RESET}"
                    echo ""
                    echo -e "${CYAN}  Запуск...${RESET}"
                    "$opencode_exe" providers login
                    echo ""
                    echo -e "${GREEN}Нажмите Enter для возврата в меню…${RESET}"
                    read
                    ;;
                "providers-list")
                    clear
                    echo -e "${CYAN}═══════════════════════════════════════════════════${RESET}"
                    echo -e "${CYAN}  OpenCode - подключённые провайдеры${RESET}"
                    echo -e "${CYAN}═══════════════════════════════════════════════════${RESET}"
                    echo ""
                    "$opencode_exe" providers list
                    echo ""
                    echo -e "${GREEN}Нажмите Enter для возврата в меню…${RESET}"
                    read
                    ;;
                "vanilla")
                    unset OPENCODE_CONFIG
                    clear
                    echo -e "${CYAN}═══════════════════════════════════════════════════${RESET}"
                    echo -e "${CYAN}  Запуск OpenCode (ванильный запуск)${RESET}"
                    echo -e "${CYAN}═══════════════════════════════════════════════════${RESET}"
                    echo ""
                    echo -e "${YELLOW}  Команда: opencode${RESET}"
                    echo ""
                    "$opencode_exe"
                    echo ""
                    echo -e "${GREEN}Нажмите Enter для возврата в меню…${RESET}"
                    read
                    ;;
            esac
            continue
            ;;
        "change-api-key")
            show_api_key_change_menu "OpenCode"
            continue
            ;;
        "custom-model")
            local wizard_result
            wizard_result=$(invoke_custom_model_wizard "OpenCode") || {
                echo -e "${YELLOW}Отменено.${RESET}"
                continue
            }
            
            local wiz_provider=$(echo "$wizard_result" | cut -d'|' -f1)
            local wiz_model=$(echo "$wizard_result" | cut -d'|' -f2)
            
            local new_id="custom-opencode-nim"
            if [ "$wiz_provider" = "zai" ]; then
                new_id="custom-opencode-zai"
            elif [ "$wiz_provider" = "groq" ]; then
                new_id="custom-opencode-groq"
            elif [ "$wiz_provider" = "openrouter" ]; then
                new_id="custom-opencode-openrouter"
            elif [ "$wiz_provider" = "bai" ]; then
                new_id="custom-opencode-bai"
            fi
            
            save_launcher_state "$new_id" "\"customModelId\":\"$wiz_model\""
            invoke_opencode_profile "$new_id"
            continue
            ;;
        "last")
            if state=$(get_launcher_state); then
                if resolved_id=$(resolve_profile_from_state "$state"); then
                    profile_id="$resolved_id"
                else
                    echo -e "${RED}Сохранённый профиль не найден. Выберите провайдер один раз.${RESET}"
                    read -p "Нажмите Enter..."
                    continue
                fi
            else
                echo -e "${RED}Сохранённый профиль не найден. Выберите провайдер один раз.${RESET}"
                read -p "Нажмите Enter..."
                continue
            fi
            ;;
        *)
            save_launcher_state "$profile_id"
            ;;
    esac
    
    if ! invoke_opencode_profile "$profile_id" 2>/dev/null; then
        invoke_opencode_dynamic_fallback "$profile_id"
    fi
    continue
done
}
main "$@"
