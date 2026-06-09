#!/bin/bash
# OpenClaude launcher (Linux/macOS) — Gitlawb fork of Claude Code
# Uses provider profiles stored in ~/.openclaude.json (NOT ~/.openclaude/settings.json).
# OpenClaude calls applyProviderProfileToProcessEnv(profile) at startup which fully
# overrides process env.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_FILE="$SCRIPT_DIR/openclaude-launcher-state.json"

. "$SCRIPT_DIR/launcher-tui.sh"
. "$SCRIPT_DIR/launcher-api-keys.sh"

ensure_jq() {
    if ! command -v jq >/dev/null 2>&1; then
        echo -e "${RED}jq не установлен. Установите: sudo apt install jq${RESET}" >&3
        exit 1
    fi
}

set_openclaude_profile() {
    ensure_jq
    local profile_id="$1" provider="$2" name="$3" base_url="$4" api_key="$5" model="$6"
    local config_file="$HOME/.openclaude.json"

    if [ ! -f "$config_file" ]; then
        echo '{}' > "$config_file"
    fi

    if ! jq -e 'type == "object"' "$config_file" &>/dev/null; then
        echo '{}' > "$config_file"
    fi

    local tmp
    tmp="$(jq --arg id "$profile_id" \
               --arg prov "$provider" \
               --arg nm "$name" \
               --arg base "$base_url" \
               --arg key "$api_key" \
               --arg mdl "$model" '
        (.providerProfiles // []) | map(select(.id != $id)) as $filtered |
        $filtered + [{
            "id": $id,
            "provider": $prov,
            "name": $nm,
            "baseUrl": $base,
            "apiKey": $key,
            "model": $mdl
        }] as $newProfiles |
        {} |
        .providerProfiles = $newProfiles |
        .activeProviderProfileId = $id
    ' "$config_file")"
    echo "$tmp" > "$config_file"
}

clear_openclaude_profiles() {
    ensure_jq
    local config_file="$HOME/.openclaude.json"
    if [ ! -f "$config_file" ]; then return; fi
    if ! jq -e 'type == "object"' "$config_file" &>/dev/null; then
        echo '{}' > "$config_file"
    fi
    local tmp
    tmp="$(jq '.providerProfiles = [] | .activeProviderProfileId = null' "$config_file")"
    echo "$tmp" > "$config_file"
}

resolve_key() {
    local env_name="$1" provider_name="$2" help_url="$3" key_prefix="$4"
    local key="${!env_name:-}"
    if [ -z "$key" ] || [ "$key" = "__SET_ME__" ]; then
        key="$(get_current_api_key "$key_prefix" 2>/dev/null || true)"
    fi
    if [ -z "$key" ] || [ "$key" = "__SET_ME__" ]; then
        echo -e "${YELLOW}$provider_name API ключ не задан.${RESET}" >&3
        echo -e "${CYAN}Получить ключ: $help_url${RESET}" >&3
        key="$(read_secret_text "$provider_name API key: ")"
        if [ -n "$key" ]; then
            set_provider_api_key "$key_prefix" "$key"
        fi
    fi
    echo "$key"
}

# ── State management ───────────────────────────────────────────────────────────
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
        "zai-glm51"|"zai-glm47"|"zai-flash47"|"nim-mistral-medium"| \
        "nim-glm51"|"nim-step-3.5-flash"|"nim-mistral-large-3"| \
        "nim-deepseek-v4-flash"|"nim-gemma-4-31b"|"nim-qwen3.5-397b"| \
        "nim-qwen3-next-80b"|"nim-qwen3-coder-480b"| \
        "openrouter-laguna"|"openrouter-qwen3-coder"| \
        "openrouter-deepseek-v4-flash"|"openrouter-nemotron"| \
        "custom-openclaude-zai"|"custom-openclaude-nim"| \
        "custom-openclaude-openrouter"|"custom-openclaude-bai"|"vanilla")
            echo "$profile_id"
            return 0
            ;;
        bai-*)
            if [[ -n "${PRESET_SPEC[$profile_id]:-}" ]]; then
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

# ── Preset specifications ───────────────────────────────────────────────────────
declare -A ZAI_PRESET_SPEC=(
    ["zai-glm51"]="glm-5.1"
    ["zai-glm47"]="glm-4.7"
    ["zai-flash47"]="glm-4.7-flash"
)

declare -A PRESET_SPEC=(
    ["nim-mistral-medium"]="https://integrate.api.nvidia.com/v1|mistralai/mistral-medium-3.5-128b|NVIDIA_NIM_API_KEY"
    ["nim-glm51"]="https://integrate.api.nvidia.com/v1|z-ai/glm-5.1|NVIDIA_NIM_API_KEY"
    ["nim-step-3.5-flash"]="https://integrate.api.nvidia.com/v1|stepfun-ai/step-3.5-flash|NVIDIA_NIM_API_KEY"
    ["nim-mistral-large-3"]="https://integrate.api.nvidia.com/v1|mistralai/mistral-large-3-675b-instruct-2512|NVIDIA_NIM_API_KEY"
    ["nim-deepseek-v4-flash"]="https://integrate.api.nvidia.com/v1|deepseek-ai/deepseek-v4-flash|NVIDIA_NIM_API_KEY"
    ["nim-gemma-4-31b"]="https://integrate.api.nvidia.com/v1|google/gemma-4-31b-it|NVIDIA_NIM_API_KEY"
    ["nim-qwen3.5-397b"]="https://integrate.api.nvidia.com/v1|qwen/qwen3.5-397b-a17b|NVIDIA_NIM_API_KEY"
    ["nim-qwen3-next-80b"]="https://integrate.api.nvidia.com/v1|qwen/qwen3-next-80b-a3b-instruct|NVIDIA_NIM_API_KEY"
    ["nim-qwen3-coder-480b"]="https://integrate.api.nvidia.com/v1|qwen/qwen3-coder-480b-a35b-instruct|NVIDIA_NIM_API_KEY"
    ["openrouter-laguna"]="https://openrouter.ai/api/v1|poolside/laguna-m.1:free|OPENROUTER_API_KEY"
    ["openrouter-qwen3-coder"]="https://openrouter.ai/api/v1|qwen/qwen3-coder:free|OPENROUTER_API_KEY"
    ["openrouter-deepseek-v4-flash"]="https://openrouter.ai/api/v1|deepseek/deepseek-chat-v3.1:free|OPENROUTER_API_KEY"
    ["openrouter-nemotron"]="https://openrouter.ai/api/v1|nvidia/nemotron-3-super-120b-a12b:free|OPENROUTER_API_KEY"
    ["bai-gpt-5-nano"]="https://api.b.ai/v1|gpt-5-nano|BAI_API_KEY"
    ["bai-gpt-5-mini"]="https://api.b.ai/v1|gpt-5-mini|BAI_API_KEY"
    ["bai-gpt-5.2"]="https://api.b.ai/v1|gpt-5.2|BAI_API_KEY"
    ["bai-gpt-5.4-nano"]="https://api.b.ai/v1|gpt-5.4-nano|BAI_API_KEY"
    ["bai-gpt-5.4-mini"]="https://api.b.ai/v1|gpt-5.4-mini|BAI_API_KEY"
    ["bai-gpt-5.4"]="https://api.b.ai/v1|gpt-5.4|BAI_API_KEY"
    ["bai-gpt-5.4-pro"]="https://api.b.ai/v1|gpt-5.4-pro|BAI_API_KEY"
    ["bai-gpt-5.5"]="https://api.b.ai/v1|gpt-5.5|BAI_API_KEY"
    ["bai-gpt-5.5-instant"]="https://api.b.ai/v1|gpt-5.5-instant|BAI_API_KEY"
    ["bai-claude-haiku-4.5"]="https://api.b.ai/v1|claude-haiku-4.5|BAI_API_KEY"
    ["bai-claude-sonnet-4.5"]="https://api.b.ai/v1|claude-sonnet-4.5|BAI_API_KEY"
    ["bai-claude-sonnet-4.6"]="https://api.b.ai/v1|claude-sonnet-4.6|BAI_API_KEY"
    ["bai-claude-opus-4.5"]="https://api.b.ai/v1|claude-opus-4.5|BAI_API_KEY"
    ["bai-claude-opus-4.6"]="https://api.b.ai/v1|claude-opus-4.6|BAI_API_KEY"
    ["bai-claude-opus-4.7"]="https://api.b.ai/v1|claude-opus-4.7|BAI_API_KEY"
    ["bai-claude-opus-4.8"]="https://api.b.ai/v1|claude-opus-4.8|BAI_API_KEY"
    ["bai-deepseek-v4-pro"]="https://api.b.ai/v1|deepseek-v4-pro|BAI_API_KEY"
    ["bai-deepseek-v4-flash"]="https://api.b.ai/v1|deepseek-v4-flash|BAI_API_KEY"
    ["bai-gemini-3.1-pro"]="https://api.b.ai/v1|gemini-3.1-pro|BAI_API_KEY"
    ["bai-gemini-3.5-flash"]="https://api.b.ai/v1|gemini-3.5-flash|BAI_API_KEY"
    ["bai-glm-5"]="https://api.b.ai/v1|glm-5|BAI_API_KEY"
    ["bai-glm-5.1"]="https://api.b.ai/v1|glm-5.1|BAI_API_KEY"
    ["bai-kimi-k2.5"]="https://api.b.ai/v1|kimi-k2.5|BAI_API_KEY"
    ["bai-kimi-k2.6"]="https://api.b.ai/v1|kimi-k2.6|BAI_API_KEY"
    ["bai-minimax-m3"]="https://api.b.ai/v1|minimax-m3|BAI_API_KEY"
    ["bai-minimax-m2.7"]="https://api.b.ai/v1|minimax-m2.7|BAI_API_KEY"
)

# ── Provider group menus (static fallback) ──────────────────────────────────────
ZAI_MODELS=(
    "zai-glm51|Z.AI - GLM-5.1 (paid, Anthropic-compatible, full tool support)"
    "zai-glm47|Z.AI - GLM-4.7 (paid, Anthropic-compatible, tool support)"
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
    "openrouter-deepseek-v4-flash|OpenRouter - DeepSeek V4 Flash (free, text-only)"
    "openrouter-qwen3-coder|OpenRouter - Qwen3 Coder (free, text-only)"
    "openrouter-nemotron|OpenRouter - Nemotron 3 Super 120B (free, text-only)"
    "openrouter-laguna|OpenRouter - Poolside Laguna M.1 (free, text-only, coding)"
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

# ── Menu functions ───────────────────────────────────────────────────────────────
PROFILES=(
    "last|Запустить с последними настройками (быстрый старт)"
    "group:zai|Z.AI - GLM-5.1 / GLM-4.7 / GLM-4.7-Flash"
    "group:nim|NVIDIA NIM - бесплатные agentic модели"
    "group:bai|B.AI - DeepSeek/MiniMax/GLM/Kimi/GPT (OpenAI-compatible)"
    "group:openrouter|OpenRouter - бесплатные agentic модели"
    "custom-model|Другая модель… → выбор провайдера и модели"
    "native-login|Нативный запуск (vanilla / Opengateway)"
    "change-api-key|Сменить ключ API провайдера"
)

resolve_openclaude_exe() {
    if command -v openclaude >/dev/null 2>&1; then
        command -v openclaude
        return 0
    fi
    local npm_prefix
    npm_prefix="$(npm prefix -g 2>/dev/null || true)"
    if [ -n "$npm_prefix" ] && [ -x "$npm_prefix/bin/openclaude" ]; then
        echo "$npm_prefix/bin/openclaude"
        return 0
    fi
    return 1
}

show_submenu_for_group() {
    local group_key="$1"
    local subtitle=""
    local group_items=()
    case "$group_key" in
        zai) subtitle="Z.AI - Anthropic-compatible"; group_items=("${ZAI_MODELS[@]}") ;;
        nim) subtitle="NVIDIA NIM - OpenAI-compatible"; group_items=("${NIM_MODELS[@]}") ;;
        bai) subtitle="B.AI - https://api.b.ai/v1"; group_items=("${BAI_MODELS[@]}") ;;
        openrouter) subtitle="OpenRouter - бесплатные модели"; group_items=("${OPENROUTER_MODELS[@]}") ;;
        *) return 1 ;;
    esac

    local labels=()
    for item in "${group_items[@]}"; do
        labels+=("${item##*|}")
    done

    echo -e "${CYAN}↑↓ выбор · Enter · Esc=назад${RESET}" >&3
    local sub_choice
    sub_choice=$(show_tui_numbered_menu "OpenClaude" "OpenClaude - ${group_key^^}" "$subtitle" "${labels[@]}")

    if [ "${sub_choice:-0}" -eq 0 ]; then
        echo "back"
        return 0
    fi

    echo "${group_items[$((sub_choice-1))]}" | cut -d'|' -f1
}

invoke_openclaude_zai_preset() {
    local preset_id="$1"
    local model="${ZAI_PRESET_SPEC[$preset_id]:-${preset_id#zai-}}"
    if [ -z "$model" ]; then
        echo -e "${RED}Неизвестный Z.AI preset: $preset_id${RESET}" >&3
        return 1
    fi

    local key
    key="$(resolve_key ZAI_API_KEY "Z.AI" "https://console.z.ai/" "ZAI")"

    remove_item Env:CLAUDE_CODE_USE_OPENAI Env:OPENAI_BASE_URL Env:OPENAI_MODEL Env:OPENAI_API_KEY 2>/dev/null || true
    export ANTHROPIC_API_KEY="$key"
    export ANTHROPIC_BASE_URL="https://api.z.ai/api/anthropic"
    export ANTHROPIC_DEFAULT_OPUS_MODEL="$model"
    export ANTHROPIC_DEFAULT_SONNET_MODEL="$model"
    export ANTHROPIC_DEFAULT_HAIKU_MODEL="$model"

    set_openclaude_profile "zai-${model}-anthropic" "anthropic" "Z.AI ${model}" \
        "https://api.z.ai/api/anthropic" "$key" "$model"

    exec "$openclaude_exe"
}

invoke_openclaude_openai_preset() {
    local preset_id="$1"
    local spec="${PRESET_SPEC[$preset_id]:-}"

    if [ -z "$spec" ]; then
        local base_url="" model_raw="$preset_id" key_env=""
        case "$preset_id" in
            nim-*) base_url="https://integrate.api.nvidia.com/v1"; key_env="NVIDIA_NIM_API_KEY"; model_raw="${preset_id#nim-}" ;;
            bai-*) base_url="https://api.b.ai/v1"; key_env="BAI_API_KEY"; model_raw="${preset_id#bai-}" ;;
            openrouter-*) base_url="https://openrouter.ai/api/v1"; key_env="OPENROUTER_API_KEY"; model_raw="${preset_id#openrouter-}" ;;
            *) echo -e "${RED}Неизвестный preset: $preset_id${RESET}" >&3; return 1 ;;
        esac
        spec="${base_url}|${model_raw}|${key_env}"
    fi

    IFS='|' read -r base_url model key_env <<< "$spec"

    local provider_name="$key_env"
    local help_url="https://console.z.ai/"
    local key_prefix="$key_env"
    case "$key_env" in
        NVIDIA_NIM_API_KEY) provider_name="NVIDIA NIM"; help_url="https://build.nvidia.com/api-key"; key_prefix="NVIDIA_NIM" ;;
        OPENROUTER_API_KEY) provider_name="OpenRouter"; help_url="https://openrouter.ai/settings/keys"; key_prefix="OPENROUTER" ;;
        BAI_API_KEY) provider_name="B.AI"; help_url="https://chat.b.ai/key"; key_prefix="BAI" ;;
    esac

    local key
    key="$(resolve_key "$key_env" "$provider_name" "$help_url" "$key_prefix")"

    remove_item Env:ANTHROPIC_BASE_URL Env:ANTHROPIC_API_KEY Env:ANTHROPIC_AUTH_TOKEN 2>/dev/null || true
    export CLAUDE_CODE_USE_OPENAI=1
    export OPENAI_API_KEY="$key"
    export OPENAI_BASE_URL="$base_url"
    export OPENAI_MODEL="$model"

    set_openclaude_profile "${preset_id}-openai" "openai" "$provider_name $model" \
        "$base_url" "$key" "$model"

    exec "$openclaude_exe"
}

remove_item() {
    for var in "$@"; do
        unset "$var" 2>/dev/null || true
    done
}

# ── Custom model wizard ──────────────────────────────────────────────────────────
invoke_custom_model_wizard() {
    local prov_items=(
        "zai|Z.AI - Coding / Anthropic"
        "nim|NVIDIA NIM - полный каталог"
        "openrouter|OpenRouter - полный каталог"
        "bai|B.AI - OpenAI-compatible"
    )

    while true; do
        local prov_menu=()
        for item in "${prov_items[@]}"; do
            prov_menu+=("${item##*|}")
        done

        local prov_choice
        prov_choice="$(show_tui_numbered_menu "OpenClaude" "Другая модель" "Шаг 1 из 2 - выберите провайдера" "${prov_menu[@]}")"

        if [ "${prov_choice:-0}" -eq 0 ]; then
            return 1
        fi

        local prov_source=$(echo "${prov_items[$((prov_choice-1))]}" | cut -d'|' -f1)
        local key=""
        local ids=()

        case "$prov_source" in
            zai)
                key="$(resolve_key ZAI_API_KEY "Z.AI" "https://console.z.ai/" "ZAI")" || return 1
                ids=($(curl -s -H "Authorization: Bearer $key" "https://api.z.ai/api/coding/paas/v4/models" 2>/dev/null | grep -o '"id":"[^"]*"' | cut -d'"' -f4 | sort -u)) || true
                ;;
            nim)
                key="$(resolve_key NVIDIA_NIM_API_KEY "NVIDIA NIM" "https://build.nvidia.com/api-key" "NVIDIA_NIM")" || return 1
                ids=($(curl -s -H "Authorization: Bearer $key" "https://integrate.api.nvidia.com/v1/models" 2>/dev/null | grep -o '"id":"[^"]*"' | cut -d'"' -f4 | sort -u)) || true
                ;;
            openrouter)
                key="$(resolve_key OPENROUTER_API_KEY "OpenRouter" "https://openrouter.ai/settings/keys" "OPENROUTER")" || return 1
                ids=($(curl -s -H "Authorization: Bearer $key" "https://openrouter.ai/api/v1/models" 2>/dev/null | jq -r '.data[] | select(.pricing.prompt == "0" and .pricing.completion == "0") | .id' 2>/dev/null | sort -u)) || true
                ;;
            bai)
                key="$(resolve_key BAI_API_KEY "B.AI" "https://chat.b.ai/key" "BAI")" || return 1
                ids=($(curl -s -H "Authorization: Bearer $key" "https://api.b.ai/v1/models" 2>/dev/null | grep -o '"id":"[^"]*"' | cut -d'"' -f4 | sort -u)) || true
                ;;
        esac

        if [ ${#ids[@]} -eq 0 ]; then
            echo -e "${RED}Провайдер вернул пустой список моделей.${RESET}" >&3
            return 1
        fi

        local model_menu=()
        for id in "${ids[@]}"; do
            model_menu+=("$id")
        done

        local model_choice
        model_choice="$(show_tui_numbered_menu "OpenClaude" "Другая модель" "Шаг 2 из 2 - моделей: ${#ids[@]}" "${model_menu[@]}")"

        if [ "${model_choice:-0}" -eq 0 ]; then
            continue
        fi

        echo "${prov_source}|${ids[$((model_choice-1))]}"
        return 0
    done
}

# Быстрый старт
if [ "${OPENCLAUDE_LAUNCHER_QUICK:-0}" = "1" ]; then
    if state=$(get_launcher_state); then
        if resolved_id=$(resolve_profile_from_state "$state"); then
            openclaude_exe=$(resolve_openclaude_exe) || exit 1
            if [[ "$resolved_id" == zai-* ]]; then
                invoke_openclaude_zai_preset "$resolved_id"
            else
                invoke_openclaude_openai_preset "$resolved_id"
            fi
            exit $?
        fi
    fi
    echo -e "${YELLOW}Нет сохранённого профиля. Один раз выберите модель в меню.${RESET}" >&2
    exit 2
fi

# ── Dynamic model fetching ───────────────────────────────────────────────────────
echo -e "${GRAY}Загрузка списков моделей...${RESET}" >&3

DYNAMIC_ZAI=()
mapfile -t DYNAMIC_ZAI < <(fetch_menu_items "ZAI_API_KEY" \
    "https://api.z.ai/api/coding/paas/v4/models" "zai-" \
    "glm-5.1:zai-glm51|glm-4.7:zai-glm47|glm-4.7-flash:zai-flash47" \
    "zai-flash47" "" \
    "zai-glm51|Z.AI - GLM-5.1 (paid, Anthropic-compatible)" \
    "zai-glm47|Z.AI - GLM-4.7 (paid, Anthropic-compatible)" \
    "zai-flash47|Z.AI - GLM-4.7-Flash (free)" 2>/dev/null) || true
if [ ${#DYNAMIC_ZAI[@]} -gt 0 ]; then ZAI_MODELS=("${DYNAMIC_ZAI[@]}"); fi

DYNAMIC_NIM=()
mapfile -t DYNAMIC_NIM < <(fetch_menu_items "NVIDIA_NIM_API_KEY" \
    "https://integrate.api.nvidia.com/v1/models" "nim-" \
    "mistralai/mistral-medium-3.5-128b:nim-mistral-medium|z-ai/glm-5.1:nim-glm51|stepfun-ai/step-3.5-flash:nim-step-3.5-flash|mistralai/mistral-large-3-675b-instruct-2512:nim-mistral-large-3|deepseek-ai/deepseek-v4-flash:nim-deepseek-v4-flash|google/gemma-4-31b-it:nim-gemma-4-31b|qwen/qwen3.5-397b-a17b:nim-qwen3.5-397b|qwen/qwen3-next-80b-a3b-instruct:nim-qwen3-next-80b|qwen/qwen3-coder-480b-a35b-instruct:nim-qwen3-coder-480b" \
    "" "$(printf '%s|' "${NIM_AGENTIC_IDS[@]}" | sed 's/|$//')" \
    "${NIM_MODELS[@]}" 2>/dev/null) || true
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
local state last_id choice profile_id sub_result wizard_result wiz_provider wiz_model openclaude_exe
while true; do
    state=$(get_launcher_state 2>/dev/null || true)
    last_id=$(resolve_profile_from_state "$state" 2>/dev/null || true)

    local menu_items=()
    for profile in "${PROFILES[@]}"; do
        menu_items+=("${profile##*|}")
    done

    choice="$(show_tui_numbered_menu "OpenClaude" "OpenClaude - выбор профиля" "Z.AI · NIM · B.AI · OpenRouter" "${menu_items[@]}")"

    if [ "${choice:-0}" -eq 0 ]; then
        continue
    fi

    profile_id=$(echo "${PROFILES[$((choice-1))]}" | cut -d'|' -f1)

    case "$profile_id" in
        group:*)
            local group_key="${profile_id#group:}"
            sub_result=$(show_submenu_for_group "$group_key")
            if [ -z "$sub_result" ] || [ "$sub_result" = "back" ]; then
                continue
            fi
            profile_id="$sub_result"
            save_launcher_state "$profile_id"
            openclaude_exe=$(resolve_openclaude_exe) || { echo -e "${RED}OpenClaude CLI не найден${RESET}" >&2; continue; }
            if [[ "$profile_id" == zai-* ]]; then
                invoke_openclaude_zai_preset "$profile_id"
            else
                invoke_openclaude_openai_preset "$profile_id"
            fi
            continue
            ;;
        native-login)
            openclaude_exe=$(resolve_openclaude_exe) || { echo -e "${RED}OpenClaude CLI не найден${RESET}" >&2; continue; }
            remove_item Env:OPENAI_BASE_URL Env:OPENAI_MODEL Env:CLAUDE_CODE_USE_OPENAI Env:OPENAI_API_KEY \
                      Env:ANTHROPIC_BASE_URL Env:ANTHROPIC_API_KEY Env:ANTHROPIC_AUTH_TOKEN
            clear_openclaude_profiles
            save_launcher_state "vanilla"
            exec "$openclaude_exe"
            ;;
        change-api-key)
            show_api_key_change_menu "OpenClaude"
            continue
            ;;
        custom-model)
            wizard_result=$(invoke_custom_model_wizard) || { echo -e "${YELLOW}Отменено${RESET}" >&3; continue; }
            wiz_provider=$(echo "$wizard_result" | cut -d'|' -f1)
            wiz_model=$(echo "$wizard_result" | cut -d'|' -f2)

            openclaude_exe=$(resolve_openclaude_exe) || { echo -e "${RED}OpenClaude CLI не найден${RESET}" >&2; continue; }

            if [ "$wiz_provider" = "zai" ]; then
                remove_item Env:CLAUDE_CODE_USE_OPENAI Env:OPENAI_BASE_URL Env:OPENAI_MODEL Env:OPENAI_API_KEY
                export ANTHROPIC_API_KEY="$(get_current_api_key "ZAI")"
                export ANTHROPIC_BASE_URL="https://api.z.ai/api/anthropic"
                set_openclaude_profile "zai-custom-${wiz_model}-anthropic" "anthropic" "Z.AI $wiz_model" \
                    "https://api.z.ai/api/anthropic" "${ANTHROPIC_API_KEY:-}" "$wiz_model"
            else
                local base_for_provider="" key_env="" key_val=""
                case "$wiz_provider" in
                    nim) base_for_provider="https://integrate.api.nvidia.com/v1"; key_env="NVIDIA_NIM_API_KEY" ;;
                    openrouter) base_for_provider="https://openrouter.ai/api/v1"; key_env="OPENROUTER_API_KEY" ;;
                    bai) base_for_provider="https://api.b.ai/v1"; key_env="BAI_API_KEY" ;;
                esac
                key_val="${!key_env:-}"
                if [ -z "$key_val" ]; then key_val="$(get_current_api_key "${key_env%%_API_KEY}")"; fi
                remove_item Env:ANTHROPIC_BASE_URL Env:ANTHROPIC_API_KEY Env:ANTHROPIC_AUTH_TOKEN
                export CLAUDE_CODE_USE_OPENAI=1
                export OPENAI_API_KEY="$key_val"
                export OPENAI_BASE_URL="${base_for_provider}"
                export OPENAI_MODEL="$wiz_model"
                set_openclaude_profile "custom-$wiz_provider-$wiz_model-openai" "openai" "$wiz_provider $wiz_model" \
                    "${base_for_provider}" "$key_val" "$wiz_model"
            fi
            exec "$openclaude_exe"
            ;;
        last)
            if state=$(get_launcher_state); then
                profile_id=$(resolve_profile_from_state "$state")
                if [ -z "$profile_id" ]; then
                    echo -e "${RED}Сохранённый профиль не найден${RESET}" >&3
                    continue
                fi
                openclaude_exe=$(resolve_openclaude_exe) || { echo -e "${RED}OpenClaude CLI не найден${RESET}" >&2; continue; }
                if [[ "$profile_id" == zai-* ]]; then
                    invoke_openclaude_zai_preset "$profile_id"
                else
                    invoke_openclaude_openai_preset "$profile_id"
                fi
            fi
            continue
            ;;
        vanilla)
            openclaude_exe=$(resolve_openclaude_exe) || { echo -e "${RED}OpenClaude CLI не найден${RESET}" >&2; continue; }
            remove_item Env:OPENAI_BASE_URL Env:OPENAI_MODEL Env:CLAUDE_CODE_USE_OPENAI Env:OPENAI_API_KEY \
                      Env:ANTHROPIC_BASE_URL Env:ANTHROPIC_API_KEY Env:ANTHROPIC_AUTH_TOKEN
            clear_openclaude_profiles
            exec "$openclaude_exe"
            ;;
    esac
done
}
main "$@"
