#!/bin/bash
# Меню Qwen Code (облако) - Linux версия

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_FILE="$SCRIPT_DIR/qwen-code-launcher-state.json"

# Загрузка модулей
. "$SCRIPT_DIR/launcher-tui.sh"
. "$SCRIPT_DIR/launcher-api-keys.sh"

resolve_qwen_exe() {
    if command -v qwen >/dev/null 2>&1; then
        command -v qwen
        return 0
    fi
    if [ -x "$HOME/.local/bin/qwen-code" ]; then
        echo "$HOME/.local/bin/qwen-code"
        return 0
    fi
    return 1
}

PROFILES=(
    "last|Запустить с последними настройками (быстрый старт)"
    "group:zai|Z.AI - GLM-5.1 / GLM-4.7 / GLM-4.7-Flash"
    "group:nim|NVIDIA NIM - бесплатные agentic модели"
    "group:bai|B.AI - DeepSeek/MiniMax/GLM/Kimi/GPT (OpenAI-compatible)"
    "group:openrouter|OpenRouter - бесплатные agentic модели"
    "custom-model|Другая модель… → выбор провайдера и модели"
    "native-login|Нативный логин (Qwen OAuth / Coding Plan)"
    "change-api-key|Сменить ключ API провайдера"
)

# Submenus per provider group (must match resolve_profile_from_state / invoke_qwen_profile)
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

# Show provider-group submenu and return chosen profile id (or "back" on Esc)
show_submenu_for_group() {
    local group_key="$1"

    local subtitle=""
    local -a items=()
    case "$group_key" in
        zai)
            subtitle="Z.AI Coding (paid) + GLM-4.7-Flash"
            items=("${ZAI_MODELS[@]}")
            ;;
        nim)
            subtitle="NVIDIA NIM - 9 бесплатных agentic моделей"
            items=("${NIM_MODELS[@]}")
            ;;
        openrouter)
            subtitle="OpenRouter - бесплатные agentic модели"
            items=("${OPENROUTER_MODELS[@]}")
            ;;
        bai)
            subtitle="B.AI - https://api.b.ai/v1 (OpenAI-compatible)"
            items=("${BAI_MODELS[@]}")
            ;;
        *)
            return 1
            ;;
    esac

    local group_key_upper=$(echo "$group_key" | tr '[:lower:]' '[:upper:]')
    local title="Qwen Code - $group_key_upper"

    local labels=()
    local item
    for item in "${items[@]}"; do
        labels+=("${item##*|}")
    done

    local choice
    choice=$(show_tui_framed_menu "Qwen" "$title" "$subtitle" "${labels[@]}")

    if [ "${choice:-0}" -eq 0 ]; then
        echo "back"
        return 0
    fi

    echo "${items[$((choice-1))]}" | cut -d'|' -f1
    return 0
}

get_launcher_state() {
    if [ ! -f "$STATE_FILE" ]; then
        return 1
    fi
    cat "$STATE_FILE"
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
        "nim-glm"|"nim-qwen"|"nim-mistral-medium"|"nim-glm51"|"nim-step-3.5-flash"|"nim-mistral-large-3"|"nim-deepseek-v4-flash"|"nim-gemma-4-31b"|"nim-qwen3.5-397b"|"nim-qwen3-next-80b"|"nim-qwen3-coder-480b"|"zai-glm"|"zai-glm51"|"zai-flash47"|"zai-flash45"|"openrouter-hy3"|"openrouter-deepseek-v4-flash"|"openrouter-qwen3-coder"|"openrouter-nemotron"|"openrouter-laguna"|"custom-qwen-zai"|"custom-qwen-zai-general"|"custom-qwen-nim"|"custom-qwen-groq"|"custom-qwen-openrouter"|"custom-qwen-bai")
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

# ── API key helpers ──────────────────────────────────────────────────────────
get_qwen_zai_api_key() {
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
        else
            return 1
        fi
    else
        echo "$key"
    fi
}

get_qwen_nim_api_key() {
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
        else
            return 1
        fi
    else
        echo "$key"
    fi
}

get_qwen_groq_api_key() {
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
        else
            return 1
        fi
    else
        echo "$key"
    fi
}

get_qwen_bai_api_key() {
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
        else
            return 1
        fi
    else
        echo "$key"
    fi
}

get_qwen_openrouter_api_key() {
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
        else
            return 1
        fi
    else
        echo "$key"
    fi
}

# ── Мастер выбора модели ─────────────────────────────────────────────────────
invoke_qwen_custom_model_wizard() {
    local app_brand="$1"

    local prov_items=(
        "zai|Z.AI - Coding / Anthropic (список моделей по вашему ключу)"
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
            show_tui_wait_frame "$app_brand" "Загрузка каталога моделей Z.AI…"
            key=$(get_qwen_zai_api_key) || { echo -e "${RED}Не удалось получить API ключ${RESET}"; read -p "Нажмите Enter..."; return 1; }

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
            key=$(get_qwen_nim_api_key) || { echo -e "${RED}Не удалось получить API ключ${RESET}"; read -p "Нажмите Enter..."; return 1; }

            local response
            response=$(curl -s -H "Authorization: Bearer $key" "https://integrate.api.nvidia.com/v1/models" 2>/dev/null) || true

            if [ -n "$response" ]; then
                ids=($(echo "$response" | grep -o '"id":"[^"]*"' | cut -d'"' -f4 | sort -u))
            fi
        elif [ "$prov_source" = "groq" ]; then
            show_tui_wait_frame "$app_brand" "Загрузка каталога Groq…"
            key=$(get_qwen_groq_api_key) || { echo -e "${RED}Не удалось получить API ключ${RESET}"; read -p "Нажмите Enter..."; return 1; }

            local response
            response=$(curl -s -H "Authorization: Bearer $key" -H "Content-Type: application/json" "https://api.groq.com/openai/v1/models" 2>/dev/null) || true

            if [ -n "$response" ]; then
                ids=($(echo "$response" | grep -o '"id":"[^"]*"' | cut -d'"' -f4 | sort -u))
            fi
        elif [ "$prov_source" = "openrouter" ]; then
            show_tui_wait_frame "$app_brand" "Загрузка каталога OpenRouter…"
            key=$(get_qwen_openrouter_api_key) || { echo -e "${RED}Не удалось получить API ключ${RESET}"; read -p "Нажмите Enter..."; return 1; }

            local response
            response=$(curl -s -H "Authorization: Bearer $key" -H "Content-Type: application/json" "https://openrouter.ai/api/v1/models" 2>/dev/null) || true

            if [ -n "$response" ]; then
                ids=($(echo "$response" | grep -o '"id":"[^"]*"' | cut -d'"' -f4 | sort -u))
            fi
        elif [ "$prov_source" = "bai" ]; then
            show_tui_wait_frame "$app_brand" "Загрузка каталога B.AI…"
            key=$(get_qwen_bai_api_key) || { echo -e "${RED}Не удалось получить API ключ${RESET}"; read -p "Нажмите Enter..."; return 1; }

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

# ── Проверка API ключа перед запуском ──────────────────────────────────────────
require_api_key_for_profile() {
    local profile_id="$1"
    local env_var=""
    local provider_name=""
    local provider_url=""
    
    case "$profile_id" in
        nim-*|custom-qwen-nim) env_var="NVIDIA_NIM"; provider_name="NVIDIA NIM"; provider_url="https://build.nvidia.com/api-key" ;;
        zai-*|custom-qwen-zai*) env_var="ZAI"; provider_name="Z.AI"; provider_url="https://console.z.ai/" ;;
        openrouter-*|custom-qwen-openrouter) env_var="OPENROUTER"; provider_name="OpenRouter"; provider_url="https://openrouter.ai/settings/keys" ;;
        bai-*|custom-qwen-bai) env_var="BAI"; provider_name="B.AI"; provider_url="https://chat.b.ai/key" ;;
        groq-*|custom-qwen-groq*) env_var="GROQ"; provider_name="Groq"; provider_url="https://console.groq.com/keys" ;;
        *) return 0 ;;
    esac
    
    ensure_api_key_or_prompt "$env_var" "$provider_name" "$provider_url"
}

# ── Профили ──────────────────────────────────────────────────────────────────
invoke_qwen_profile() {
    local profile_id="$1"
    
    case "$profile_id" in
        "nim-glm")
            bash "$SCRIPT_DIR/run-qwen-code-dynamic.sh" -Provider nim -ModelId "qwen/qwen3.5-122b-a10b"
            ;;
        "nim-qwen")
            bash "$SCRIPT_DIR/run-qwen-code-dynamic.sh" -Provider nim -ModelId "qwen/qwen3.5-122b-a10b"
            ;;
        "nim-mistral-medium")
            bash "$SCRIPT_DIR/run-qwen-code-dynamic.sh" -Provider nim -ModelId "mistralai/mistral-medium-3.5-128b"
            ;;
        "nim-glm51")
            bash "$SCRIPT_DIR/run-qwen-code-dynamic.sh" -Provider nim -ModelId "z-ai/glm-5.1"
            ;;
        "nim-step-3.5-flash")
            bash "$SCRIPT_DIR/run-qwen-code-dynamic.sh" -Provider nim -ModelId "stepfun-ai/step-3.5-flash"
            ;;
        "nim-mistral-large-3")
            bash "$SCRIPT_DIR/run-qwen-code-dynamic.sh" -Provider nim -ModelId "mistralai/mistral-large-3-675b-instruct-2512"
            ;;
        "nim-deepseek-v4-flash")
            bash "$SCRIPT_DIR/run-qwen-code-dynamic.sh" -Provider nim -ModelId "deepseek-ai/deepseek-v4-flash"
            ;;
        "nim-gemma-4-31b")
            bash "$SCRIPT_DIR/run-qwen-code-dynamic.sh" -Provider nim -ModelId "google/gemma-4-31b-it"
            ;;
        "nim-qwen3.5-397b")
            bash "$SCRIPT_DIR/run-qwen-code-dynamic.sh" -Provider nim -ModelId "qwen/qwen3.5-397b-a17b"
            ;;
        "nim-qwen3-next-80b")
            bash "$SCRIPT_DIR/run-qwen-code-dynamic.sh" -Provider nim -ModelId "qwen/qwen3-next-80b-a3b-instruct"
            ;;
        "nim-qwen3-coder-480b")
            bash "$SCRIPT_DIR/run-qwen-code-dynamic.sh" -Provider nim -ModelId "qwen/qwen3-coder-480b-a35b-instruct"
            ;;
        "zai-glm")
            bash "$SCRIPT_DIR/run-qwen-code-dynamic.sh" -Provider zai -ModelId "glm-4.7"
            ;;
        "zai-glm51")
            bash "$SCRIPT_DIR/run-qwen-code-dynamic.sh" -Provider zai -ModelId "glm-5.1"
            ;;
        "zai-flash47")
            bash "$SCRIPT_DIR/run-qwen-code-dynamic.sh" -Provider zai -ModelId "glm-4.7-flash"
            ;;
        "zai-flash45")
            bash "$SCRIPT_DIR/run-qwen-code-dynamic.sh" -Provider zai -ModelId "glm-4.5-flash"
            ;;
        bai-*)
            local mid="${profile_id#bai-}"
            local spec="${BAI_MODEL_SPEC[$mid]:-}"
            if [ -z "$spec" ]; then
                echo -e "${RED}Unknown B.AI model: $mid${RESET}"
                return 1
            fi
            local ctx="${spec%%:*}"
            local max="${spec##*:}"
            bash "$SCRIPT_DIR/run-qwen-code-dynamic.sh" -Provider bai -ModelId "$mid" --ctx-length "$ctx" --max-tokens "$max"
            ;;
        "custom-qwen-zai")
            local state=$(get_launcher_state)
            local model_id=$(echo "$state" | grep -o '"customModelId":"[^"]*"' | cut -d'"' -f4)
            
            if [ -z "$model_id" ]; then
                echo -e "${RED}В qwen-code-launcher-state.json нет customModelId для custom-qwen-zai.${RESET}"
                echo -e "${RED}Выберите модель в пункте «Другая модель».${RESET}"
                return 1
            fi
            
            bash "$SCRIPT_DIR/run-qwen-code-dynamic.sh" -Provider zai -ModelId "$model_id"
            ;;
        "custom-qwen-zai-general")
            local state=$(get_launcher_state)
            local model_id=$(echo "$state" | grep -o '"customModelId":"[^"]*"' | cut -d'"' -f4)
            
            if [ -z "$model_id" ]; then
                echo -e "${RED}Нет customModelId для custom-qwen-zai-general.${RESET}"
                return 1
            fi
            
            bash "$SCRIPT_DIR/run-qwen-code-dynamic.sh" -Provider zai-general -ModelId "$model_id"
            ;;
        "custom-qwen-nim")
            local state=$(get_launcher_state)
            local model_id=$(echo "$state" | grep -o '"customModelId":"[^"]*"' | cut -d'"' -f4)
            
            if [ -z "$model_id" ]; then
                echo -e "${RED}В qwen-code-launcher-state.json нет customModelId для custom-qwen-nim.${RESET}"
                return 1
            fi
            
            bash "$SCRIPT_DIR/run-qwen-code-dynamic.sh" -Provider nim -ModelId "$model_id"
            ;;
        "custom-qwen-groq")
            local state=$(get_launcher_state)
            local model_id=$(echo "$state" | grep -o '"customModelId":"[^"]*"' | cut -d'"' -f4)
            if [ -z "$model_id" ]; then
                echo -e "${RED}Нет customModelId для custom-qwen-groq. Выберите модель в «Другая модель».${RESET}"
                return 1
            fi
            bash "$SCRIPT_DIR/run-qwen-code-dynamic.sh" -Provider groq -ModelId "$model_id"
            ;;
        "custom-qwen-openrouter")
            local state=$(get_launcher_state)
            local model_id=$(echo "$state" | grep -o '"customModelId":"[^"]*"' | cut -d'"' -f4)
            if [ -z "$model_id" ]; then
                echo -e "${RED}Нет customModelId для custom-qwen-openrouter. Выберите модель в «Другая модель».${RESET}"
                return 1
            fi
            bash "$SCRIPT_DIR/run-qwen-code-dynamic.sh" -Provider openrouter -ModelId "$model_id"
            ;;
        "custom-qwen-bai")
            local state=$(get_launcher_state)
            local model_id=$(echo "$state" | grep -o '"customModelId":"[^"]*"' | cut -d'"' -f4)
            if [ -z "$model_id" ]; then
                echo -e "${RED}Нет customModelId для custom-qwen-bai. Выберите модель в «Другая модель».${RESET}"
                return 1
            fi
            bash "$SCRIPT_DIR/run-qwen-code-dynamic.sh" -Provider bai -ModelId "$model_id"
            ;;
        *)
            echo -e "${RED}Неизвестный профиль: $profile_id${RESET}"
            return 1
            ;;
    esac
}

invoke_qwen_dynamic_fallback() {
    local profile_id="$1"
    local raw_model="" provider=""

    case "$profile_id" in
        zai-*) raw_model="${profile_id#zai-}"; provider="zai" ;;
        nim-*) raw_model="${profile_id#nim-}"; provider="nim" ;;
        openrouter-*) raw_model="${profile_id#openrouter-}"; provider="openrouter" ;;
        *) echo -e "${RED}Неизвестный профиль: $profile_id${RESET}"; return 1 ;;
    esac

    bash "$SCRIPT_DIR/run-qwen-code-dynamic.sh" -Provider "$provider" -ModelId "$raw_model"
}

# Быстрый старт
if [ "${QWEN_CODE_LAUNCHER_QUICK:-0}" = "1" ]; then
    if state=$(get_launcher_state); then
        if resolved_id=$(resolve_profile_from_state "$state"); then
            invoke_qwen_profile "$resolved_id"
            exit $?
        fi
    fi
    
    echo -e "${YELLOW}Нет сохранённого профиля. Один раз выберите модель в меню или уберите -Quick.${RESET}"
    sleep 3
    exit 2
fi

# ── Dynamic model fetching (with static fallback) ────────────────────────────
echo -e "${GRAY}Загрузка списков моделей...${RESET}" >&3

DYNAMIC_ZAI=()
mapfile -t DYNAMIC_ZAI < <(fetch_menu_items "ZAI_API_KEY" \
    "https://api.z.ai/api/coding/paas/v4/models" "zai-" \
    "glm-5.1:zai-glm51|glm-4.7:zai-glm|glm-4.7-flash:zai-flash47" \
    "zai-flash47" "" \
    "zai-glm51|Z.AI - GLM-5.1 (paid, tool calling)" \
    "zai-glm|Z.AI - GLM-4.7 (paid, tool calling)" \
    "zai-flash47|Z.AI - GLM-4.7-Flash (free)" 2>/dev/null) || true
if [ ${#DYNAMIC_ZAI[@]} -gt 0 ]; then ZAI_MODELS=("${DYNAMIC_ZAI[@]}"); fi

DYNAMIC_NIM=()
mapfile -t DYNAMIC_NIM < <(fetch_menu_items "NVIDIA_NIM_API_KEY" \
    "https://integrate.api.nvidia.com/v1/models" "nim-" \
    "mistralai/mistral-medium-3.5-128b:nim-mistral-medium|z-ai/glm-5.1:nim-glm51|stepfun-ai/step-3.5-flash:nim-step-3.5-flash|mistralai/mistral-large-3-675b-instruct-2512:nim-mistral-large-3|deepseek-ai/deepseek-v4-flash:nim-deepseek-v4-flash|google/gemma-4-31b-it:nim-gemma-4-31b|qwen/qwen3.5-397b-a17b:nim-qwen3.5-397b|qwen/qwen3-next-80b-a3b-instruct:nim-qwen3-next-80b|qwen/qwen3-coder-480b-a35b-instruct:nim-qwen3-coder-480b" \
    "" "$(printf '%s|' "${NIM_AGENTIC_IDS[@]}" | sed 's/|$//')" \
    "nim-mistral-medium|NIM - Mistral Medium 3.5 128B (free, tool calling)" \
    "nim-glm51|NIM - Z.AI GLM-5.1 (free, tool calling)" \
    "nim-step-3.5-flash|NIM - Step 3.5 Flash (free, tool calling)" \
    "nim-mistral-large-3|NIM - Mistral Large 3 675B (free, tool calling)" \
    "nim-deepseek-v4-flash|NIM - DeepSeek V4 Flash 284B MoE (free)" \
    "nim-gemma-4-31b|NIM - Google Gemma-4 31B (free)" \
    "nim-qwen3.5-397b|NIM - Qwen 3.5 397B A17B (free)" \
    "nim-qwen3-next-80b|NIM - Qwen 3 Next 80B A3B (free)" \
    "nim-qwen3-coder-480b|NIM - Qwen 3 Coder 480B A35B (free)" 2>/dev/null) || true
if [ ${#DYNAMIC_NIM[@]} -gt 0 ]; then NIM_MODELS=("${DYNAMIC_NIM[@]}"); fi

DYNAMIC_BAI=()
mapfile -t DYNAMIC_BAI < <(fetch_menu_items "BAI_API_KEY" \
    "https://api.b.ai/v1/models" "bai-" "" "" "" \
    "${BAI_MODELS[@]}" 2>/dev/null) || true
if [ ${#DYNAMIC_BAI[@]} -gt 0 ]; then BAI_MODELS=("${DYNAMIC_BAI[@]}"); fi

DYNAMIC_OR=()
mapfile -t DYNAMIC_OR < <(fetch_or_free_menu_items "OPENROUTER_API_KEY" "openrouter-" \
    "deepseek/deepseek-chat-v3.1:free:openrouter-deepseek-v4-flash|qwen/qwen3-coder:free:openrouter-qwen3-coder|nvidia/nemotron-3-super-120b-a12b:free:openrouter-nemotron|poolside/laguna-m.1:free:openrouter-laguna" \
    "${OPENROUTER_MODELS[@]}" 2>/dev/null) || true
if [ ${#DYNAMIC_OR[@]} -gt 0 ]; then OPENROUTER_MODELS=("${DYNAMIC_OR[@]}"); fi

# Главное меню
main() {
local update_hint=$(test_launcher_updates "qwen-code" "Qwen Code")
while true; do
    local state=$(get_launcher_state 2>/dev/null || true)
    local last_id=$(resolve_profile_from_state "$state" 2>/dev/null || true)
    
    # Подготовка списка пунктов меню
    local menu_items=()
    for profile in "${PROFILES[@]}"; do
        local id="${profile%%|*}"
        local label="${profile##*|}"
        menu_items+=("$label")
    done
    
    local choice
    choice="$(show_tui_numbered_menu "Qwen" "Qwen Code - выбор провайдера" "Z.AI · NIM · OpenRouter · B.AI" ${update_hint:+"$update_hint"} "${menu_items[@]}")"
    
    if [ "${choice:-0}" -eq 0 ]; then
        continue
    fi
    
    local profile_id=$(echo "${PROFILES[$((choice-1))]}" | cut -d'|' -f1)
    
    case "$profile_id" in
        group:*)
            local group_key="${profile_id#group:}"
            local sub_choice
            sub_choice=$(show_submenu_for_group "$group_key")
            if [ -z "${sub_choice:-}" ] || [ "$sub_choice" = "back" ]; then
                continue
            fi
            profile_id="$sub_choice"
            save_launcher_state "$profile_id"
            ;;
        "native-login")
            qwen_exe=$(resolve_qwen_exe) || true
            if [ -z "${qwen_exe:-}" ]; then
                echo -e "${RED}Qwen Code CLI не найден (qwen). Установите: npm install -g @qwen-code/qwen-code@latest${RESET}"
                echo -e "${GREEN}Нажмите Enter для возврата в меню…${RESET}"
                read
                continue
            fi
            local login_items=("qwen-oauth|Qwen OAuth (браузер, подписка Qwen)" "coding-plan|Alibaba Cloud Coding Plan (API-ключ)" "vanilla|Запуск Qwen Code (ванильный запуск)")
            local login_menu=()
            for item in "${login_items[@]}"; do
                login_menu+=("${item##*|}")
            done

            local login_choice
            login_choice="$(show_tui_numbered_menu "Qwen" "Нативный логин Qwen Code" "Выберите способ авторизации" "${login_menu[@]}")"

            if [ "${login_choice:-0}" -eq 0 ]; then
                continue
            fi

            local login_id=$(echo "${login_items[$((login_choice-1))]}" | cut -d'|' -f1)

            case "$login_id" in
                "qwen-oauth")
                    clear
                    echo -e "${CYAN}═══════════════════════════════════════════════════${RESET}"
                    echo -e "${CYAN}  Qwen OAuth - авторизация через браузер${RESET}"
                    echo -e "${CYAN}═══════════════════════════════════════════════════${RESET}"
                    echo ""
                    echo -e "${YELLOW}  Откроется браузер. Завершите авторизацию в нём.${RESET}"
                    echo -e "${YELLOW}  Для этого нужна подписка Qwen (qwen.ai).${RESET}"
                    echo ""
                    echo -e "${CYAN}  Запуск...${RESET}"
                    "$qwen_exe" auth qwen-oauth
                    echo ""
                    echo -e "${GREEN}  Текущий статус:${RESET}"
                    "$qwen_exe" auth status
                    echo ""
                    echo -e "${GREEN}Нажмите Enter для возврата в меню…${RESET}"
                    read
                    ;;
                "coding-plan")
                    clear
                    echo -e "${CYAN}═══════════════════════════════════════════════════${RESET}"
                    echo -e "${CYAN}  Alibaba Cloud Coding Plan${RESET}"
                    echo -e "${CYAN}═══════════════════════════════════════════════════${RESET}"
                    echo ""
                    echo -e "${YELLOW}  Регион: china или global${RESET}"
                    echo -e "${YELLOW}  Потребуется API-ключ от Alibaba Cloud.${RESET}"
                    echo ""
                    echo -e "${CYAN}  Запуск...${RESET}"
                    "$qwen_exe" auth coding-plan
                    echo ""
                    echo -e "${GREEN}  Текущий статус:${RESET}"
                    "$qwen_exe" auth status
                    echo ""
                    echo -e "${GREEN}Нажмите Enter для возврата в меню…${RESET}"
                    read
                    ;;
                "vanilla")
                    clear
                    echo -e "${CYAN}═══════════════════════════════════════════════════${RESET}"
                    echo -e "${CYAN}  Запуск Qwen Code (ванильный запуск)${RESET}"
                    echo -e "${CYAN}═══════════════════════════════════════════════════${RESET}"
                    echo ""
                    echo -e "${YELLOW}  Команда: qwen${RESET}"
                    echo ""
                    "$qwen_exe"
                    echo ""
                    echo -e "${GREEN}Нажмите Enter для возврата в меню…${RESET}"
                    read
                    ;;
            esac
            continue
            ;;
        "change-api-key")
            show_api_key_change_menu "Qwen"
            continue
            ;;
        "custom-model")
            wizard_result=$(invoke_qwen_custom_model_wizard "Qwen") || {
                echo -e "${YELLOW}Отменено.${RESET}"
                continue
            }
            local wiz_provider=$(echo "$wizard_result" | cut -d'|' -f1)
            local wiz_model=$(echo "$wizard_result" | cut -d'|' -f2)
            
            local new_id="custom-qwen-nim"
            if [ "$wiz_provider" = "zai" ]; then
                new_id="custom-qwen-zai"
            elif [ "$wiz_provider" = "zai-general" ]; then
                new_id="custom-qwen-zai-general"
            elif [ "$wiz_provider" = "groq" ]; then
                new_id="custom-qwen-groq"
            elif [ "$wiz_provider" = "openrouter" ]; then
                new_id="custom-qwen-openrouter"
            elif [ "$wiz_provider" = "bai" ]; then
                new_id="custom-qwen-bai"
            fi
            
            save_launcher_state "$new_id" "\"customModelId\":\"$wiz_model\""
            invoke_qwen_profile "$new_id"
            continue
            ;;
        "last")
            if state=$(get_launcher_state); then
                if resolved_id=$(resolve_profile_from_state "$state"); then
                    profile_id="$resolved_id"
                else
                    echo -e "${RED}Сохранённый профиль не найден. Выберите пресет или «Другая модель» один раз.${RESET}"
                    read -p "Нажмите Enter..."
                    continue
                fi
            else
                echo -e "${RED}Сохранённый профиль не найден. Выберите пресет или «Другая модель» один раз.${RESET}"
                read -p "Нажмите Enter..."
                continue
            fi
            ;;
        *)
            save_launcher_state "$profile_id"
            ;;
    esac
    
    if ! require_api_key_for_profile "$profile_id"; then
        continue
    fi
    
    if ! invoke_qwen_profile "$profile_id" 2>/dev/null; then
        invoke_qwen_dynamic_fallback "$profile_id"
    fi
    continue
done
}
main "$@"

