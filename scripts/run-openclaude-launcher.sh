#!/bin/bash
# OpenClaude launcher (Linux/macOS)
# OpenClaude (Gitlawb fork of Claude Code) uses provider profiles stored in
# ~/.openclaude/settings.json -> providerProfiles[] + activeProviderProfileId.
# At startup it calls applyProviderProfileToProcessEnv(profile) which fully
# overrides process env — so writing profiles is mandatory; env vars alone do
# nothing.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/launcher-tui.sh"
. "$SCRIPT_DIR/launcher-api-keys.sh"

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

ensure_jq() {
    if ! command -v jq >/dev/null 2>&1; then
        echo -e "${RED}jq не установлен. Установите: sudo apt install jq (или brew install jq)${RESET}" >&3
        exit 1
    fi
}

# set_openclaude_profile <profile_id> <provider> <name> <base_url> <api_key> <model>
# Writes provider profile to ~/.openclaude.json (NOT ~/.openclaude/settings.json —
# that's user preferences, while .openclaude.json holds runtime state including
# providerProfiles[] + activeProviderProfileId).
set_openclaude_profile() {
    ensure_jq
    local profile_id="$1" provider="$2" name="$3" base_url="$4" api_key="$5" model="$6"
    local config_file="$HOME/.openclaude.json"

    if [ ! -f "$config_file" ]; then
        echo '{}' > "$config_file"
    fi

    # UPSERT: remove existing profile with same id, then append new one and set as active
    local tmp
    tmp="$(jq --arg id "$profile_id" \
               --arg prov "$provider" \
               --arg nm "$name" \
               --arg base "$base_url" \
               --arg key "$api_key" \
               --arg mdl "$model" '
        . as $orig |
        ($orig.providerProfiles // []) | map(select(.id != $id)) as $filtered |
        $filtered + [{
            "id": $id,
            "provider": $prov,
            "name": $nm,
            "baseUrl": $base,
            "apiKey": $key,
            "model": $mdl
        }] as $newProfiles |
        $orig |
        .providerProfiles = $newProfiles |
        .activeProviderProfileId = $id
    ' "$config_file")"
    echo "$tmp" > "$config_file"
}

clear_openclaude_profiles() {
    ensure_jq
    local config_file="$HOME/.openclaude.json"
    if [ ! -f "$config_file" ]; then return; fi
    local tmp
    tmp="$(jq '.providerProfiles = [] | .activeProviderProfileId = null' "$config_file")"
    echo "$tmp" > "$config_file"
}

resolve_key() {
    # $1=env name, $2=provider name, $3=help url, $4=key file prefix (for get/set_current_api_key)
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

main() {
    local items=(
        "Z.AI - GLM-5.1 (Anthropic-compatible)"
        "Z.AI - GLM-4.7 (Anthropic-compatible)"
        "Z.AI - GLM-4.7-Flash (free, Anthropic-compatible)"
        "NVIDIA NIM - Qwen3.5-122B-A10B"
        "B.AI - GPT-5.5"
        "OpenRouter - бесплатные модели (выбор)"
        "Запустить OpenClaude без presetа (vanilla)"
        "OpenClaude /provider setup (интерактивный выбор)"
    )

    local choice
    choice="$(show_tui_numbered_menu "OpenClaude" "OpenClaude - выбор профиля" "Z.AI · NIM · B.AI · OpenRouter — provider profiles" "${items[@]}")"
    if [ "${choice:-0}" -eq 0 ]; then
        echo -e "${YELLOW}Отменено.${RESET}"
        exit 0
    fi

    local openclaude_exe
    openclaude_exe="$(resolve_openclaude_exe)" || true
    if [ -z "$openclaude_exe" ]; then
        echo -e "${RED}OpenClaude CLI не найден. Установите: npm install -g @gitlawb/openclaude${RESET}"
        exit 1
    fi

    case "$choice" in
        1)
            local key
            key="$(resolve_key ZAI_API_KEY "Z.AI" "https://console.z.ai/" "ZAI")"
            set_openclaude_profile "zai-glm-5.1-anthropic" "anthropic" "Z.AI GLM-5.1" \
                "https://api.z.ai/api/anthropic" "$key" "glm-5.1"
            export ANTHROPIC_API_KEY="$key"
            export ANTHROPIC_BASE_URL="https://api.z.ai/api/anthropic"
            export ANTHROPIC_DEFAULT_SONNET_MODEL="glm-5.1"
            export ANTHROPIC_DEFAULT_OPUS_MODEL="glm-5.1"
            export ANTHROPIC_DEFAULT_HAIKU_MODEL="glm-5.1"
            unset CLAUDE_CODE_USE_OPENAI OPENAI_BASE_URL OPENAI_MODEL OPENAI_API_KEY
            ;;
        2)
            local key
            key="$(resolve_key ZAI_API_KEY "Z.AI" "https://console.z.ai/" "ZAI")"
            set_openclaude_profile "zai-glm-4.7-anthropic" "anthropic" "Z.AI GLM-4.7" \
                "https://api.z.ai/api/anthropic" "$key" "glm-4.7"
            export ANTHROPIC_API_KEY="$key"
            export ANTHROPIC_BASE_URL="https://api.z.ai/api/anthropic"
            export ANTHROPIC_DEFAULT_SONNET_MODEL="glm-4.7"
            export ANTHROPIC_DEFAULT_OPUS_MODEL="glm-4.7"
            export ANTHROPIC_DEFAULT_HAIKU_MODEL="glm-4.7"
            unset CLAUDE_CODE_USE_OPENAI OPENAI_BASE_URL OPENAI_MODEL OPENAI_API_KEY
            ;;
        3)
            local key
            key="$(resolve_key ZAI_API_KEY "Z.AI" "https://console.z.ai/" "ZAI")"
            set_openclaude_profile "zai-glm-4.7-flash-anthropic" "anthropic" "Z.AI GLM-4.7-Flash" \
                "https://api.z.ai/api/anthropic" "$key" "glm-4.7-flash"
            export ANTHROPIC_API_KEY="$key"
            export ANTHROPIC_BASE_URL="https://api.z.ai/api/anthropic"
            export ANTHROPIC_DEFAULT_SONNET_MODEL="glm-4.7-flash"
            export ANTHROPIC_DEFAULT_OPUS_MODEL="glm-4.7-flash"
            export ANTHROPIC_DEFAULT_HAIKU_MODEL="glm-4.7-flash"
            unset CLAUDE_CODE_USE_OPENAI OPENAI_BASE_URL OPENAI_MODEL OPENAI_API_KEY
            ;;
        4)
            local key
            key="$(resolve_key NVIDIA_NIM_API_KEY "NVIDIA NIM" "https://build.nvidia.com/api-key" "NVIDIA_NIM")"
            set_openclaude_profile "nim-qwen3.5-122b-openai" "openai" "NVIDIA NIM Qwen3.5-122B" \
                "https://integrate.api.nvidia.com/v1" "$key" "qwen/qwen3.5-122b-a10b"
            export CLAUDE_CODE_USE_OPENAI=1
            export OPENAI_API_KEY="$key"
            export NVIDIA_API_KEY="$key"
            export OPENAI_BASE_URL="https://integrate.api.nvidia.com/v1"
            export OPENAI_MODEL="qwen/qwen3.5-122b-a10b"
            unset ANTHROPIC_BASE_URL ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN
            ;;
        5)
            local key
            key="$(resolve_key BAI_API_KEY "B.AI" "https://chat.b.ai/key" "BAI")"
            set_openclaude_profile "bai-gpt-5.5-openai" "openai" "B.AI GPT-5.5" \
                "https://api.b.ai/v1" "$key" "gpt-5.5"
            export CLAUDE_CODE_USE_OPENAI=1
            export OPENAI_API_KEY="$key"
            export OPENAI_BASE_URL="https://api.b.ai/v1"
            export OPENAI_MODEL="gpt-5.5"
            unset ANTHROPIC_BASE_URL ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN
            ;;
        6)
            # OpenRouter — запросим модель и ключ
            local or_key
            or_key="$(resolve_key OPENROUTER_API_KEY "OpenRouter" "https://openrouter.ai/settings/keys" "OPENROUTER")"
            echo -e "${CYAN}Популярные бесплатные модели OpenRouter:${RESET}" >&3
            echo "  1) poolside/laguna-m.1:free (coding)" >&3
            echo "  2) qwen/qwen3-coder:free" >&3
            echo "  3) другая" >&3
            read -p "Выбор [1]: " sub_or < /dev/tty
            sub_or="${sub_or:-1}"
            local or_model
            case "$sub_or" in
                2) or_model="qwen/qwen3-coder:free" ;;
                3) read -p "ID модели OpenRouter: " or_model < /dev/tty ;;
                *) or_model="poolside/laguna-m.1:free" ;;
            esac
            set_openclaude_profile "openrouter-custom-openai" "openai" "OpenRouter $or_model" \
                "https://openrouter.ai/api/v1" "$or_key" "$or_model"
            export CLAUDE_CODE_USE_OPENAI=1
            export OPENAI_API_KEY="$or_key"
            export OPENAI_BASE_URL="https://openrouter.ai/api/v1"
            export OPENAI_MODEL="$or_model"
            unset ANTHROPIC_BASE_URL ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN
            ;;
        7)
            unset OPENAI_BASE_URL OPENAI_MODEL OPENAI_API_KEY CLAUDE_CODE_USE_OPENAI \
                  ANTHROPIC_BASE_URL ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN \
                  ANTHROPIC_DEFAULT_OPUS_MODEL ANTHROPIC_DEFAULT_SONNET_MODEL ANTHROPIC_DEFAULT_HAIKU_MODEL
            clear_openclaude_profiles
            ;;
        8)
            echo -e "${CYAN}После запуска выполните /provider для настройки профиля.${RESET}" >&3
            sleep 1
            unset OPENAI_BASE_URL OPENAI_MODEL OPENAI_API_KEY CLAUDE_CODE_USE_OPENAI \
                  ANTHROPIC_BASE_URL ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN \
                  ANTHROPIC_DEFAULT_OPUS_MODEL ANTHROPIC_DEFAULT_SONNET_MODEL ANTHROPIC_DEFAULT_HAIKU_MODEL
            clear_openclaude_profiles
            ;;
    esac

    clear >&3
    echo -e "${CYAN}Запуск OpenClaude…${RESET}" >&3
    echo "" >&3
    exec "$openclaude_exe"
}

main "$@"
