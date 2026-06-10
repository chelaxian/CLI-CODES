#!/bin/bash
# Меню Claude Code - Linux версия

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_FILE="$SCRIPT_DIR/claude-cloud-launcher-state.json"
SESSION_DIR="$SCRIPT_DIR/../claude-sessions/_shared"

# Единое пространство для /resume (как у Qwen): общий каталог для запуска claude
CLAUDE_SESSION_ROOT="${CLAUDE_SESSION_ROOT:-$SCRIPT_DIR/../claude-sessions/_shared}"

# Настройки (можно изменить под свои пути)
. "$SCRIPT_DIR/launcher-tui.sh"
. "$SCRIPT_DIR/launcher-api-keys.sh"
enter_claude_shared_dir() {
    mkdir -p "$CLAUDE_SESSION_ROOT"
    cd "$CLAUDE_SESSION_ROOT"
}

update_claude_settings_env() {
    local clear_top_model="${1:-0}"
    shift

    local sf="$HOME/.claude/settings.json"
    mkdir -p "$HOME/.claude"

    if ! command -v python3 &>/dev/null; then
        return
    fi

    local pairs=""
    while [ $# -gt 0 ]; do
        [ -n "$pairs" ] && pairs+=","
        local k=$(printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g')
        local v=$(printf '%s' "$2" | sed 's/\\/\\\\/g; s/"/\\"/g')
        pairs+="[\"${k}\",\"${v}\"]"
        shift 2
    done

    _CL_SF="$sf" _CL_CM="$clear_top_model" _CL_PAIRS="[${pairs}]" python3 -c '
import json, sys, os

sf = os.environ["_CL_SF"]
cm = os.environ["_CL_CM"]
pairs = json.loads(os.environ["_CL_PAIRS"])

try:
    with open(sf, "r") as f:
        d = json.load(f)
except:
    d = {}

if "env" not in d or not isinstance(d.get("env"), dict):
    d["env"] = {}

if "CLAUDE_CODE_ATTRIBUTION_HEADER" not in d["env"]:
    d["env"]["CLAUDE_CODE_ATTRIBUTION_HEADER"] = "0"
if "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC" not in d["env"]:
    d["env"]["CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC"] = "1"

for k, v in pairs:
    if v == "__DELETE__":
        d["env"].pop(k, None)
    else:
        d["env"][k] = v

if cm == "1" and "model" in d:
    del d["model"]

with open(sf, "w") as f:
    json.dump(d, f, indent=2)
' 2>/dev/null || true
}

# Top-level menu: provider groups + utility entries
PROFILES=(
    "last|Запустить с последними настройками (быстрый старт)"
    "group:zai|Z.AI - GLM-5.1 / GLM-4.7 / GLM-4.7-Flash"
    "group:nim|NVIDIA NIM - бесплатные agentic модели"
    "group:bai|B.AI - DeepSeek/MiniMax/GLM/Kimi/GPT (Anthropic-compatible)"
    "group:openrouter|OpenRouter - бесплатные agentic модели"
    "custom-model|Другая модель… → выбор провайдера и модели"
    "native-login|Нативный логин (Anthropic OAuth / Console)"
    "change-api-key|Сменить ключ API провайдера"
)

# Per-provider submenu items (id|Label)
ZAI_MODELS=(
    "claude-zai-glm51|Z.AI - GLM-5.1 (paid, tool calling)"
    "claude-zai|Z.AI - GLM-4.7 (paid, tool calling)"
    "claude-zai-flash47|Z.AI - GLM-4.7-Flash (free)"
)

NIM_MODELS=(
    "claude-nim-mistral-medium|NIM - Mistral Medium 3.5 128B (free, tool calling)"
    "claude-nim-glm51|NIM - Z.AI GLM-5.1 (free, tool calling)"
    "claude-nim-step-3.5-flash|NIM - Step 3.5 Flash (free, tool calling)"
    "claude-nim-mistral-large-3|NIM - Mistral Large 3 675B (free, tool calling)"
    "claude-nim-deepseek-v4-flash|NIM - DeepSeek V4 Flash 284B MoE (free)"
    "claude-nim-gemma-4-31b|NIM - Google Gemma-4 31B (free)"
    "claude-nim-qwen3.5-397b|NIM - Qwen 3.5 397B A17B (free)"
    "claude-nim-qwen3-next-80b|NIM - Qwen 3 Next 80B A3B (free)"
    "claude-nim-qwen3-coder-480b|NIM - Qwen 3 Coder 480B A35B (free)"
)

OPENROUTER_MODELS=(
    "claude-openrouter-deepseek-v4-flash|OpenRouter - DeepSeek V4 Flash (free, tool calling)"
    "claude-openrouter-qwen3-coder|OpenRouter - Qwen3 Coder (free, tool calling)"
    "claude-openrouter-nemotron|OpenRouter - Nemotron 3 Super 120B (free, tool calling)"
    "claude-openrouter-laguna|OpenRouter - Poolside Laguna M.1 (free, tool calling, coding)"
)

BAI_MODELS=(
    "claude-bai-gpt-5-nano|B.AI - GPT-5 Nano (OpenAI, agentic)"
    "claude-bai-gpt-5-mini|B.AI - GPT-5 Mini (OpenAI, agentic)"
    "claude-bai-gpt-5.2|B.AI - GPT-5.2 (OpenAI, agentic)"
    "claude-bai-gpt-5.4-nano|B.AI - GPT-5.4 Nano (OpenAI, agentic)"
    "claude-bai-gpt-5.4-mini|B.AI - GPT-5.4 Mini (OpenAI, agentic)"
    "claude-bai-gpt-5.4|B.AI - GPT-5.4 (OpenAI, agentic)"
    "claude-bai-gpt-5.4-pro|B.AI - GPT-5.4 Pro (OpenAI, agentic)"
    "claude-bai-gpt-5.5|B.AI - GPT-5.5 (OpenAI, agentic)"
    "claude-bai-gpt-5.5-instant|B.AI - GPT-5.5 Instant (OpenAI, agentic)"
    "claude-bai-claude-haiku-4.5|B.AI - Claude Haiku 4.5 (Anthropic, agentic)"
    "claude-bai-claude-sonnet-4.5|B.AI - Claude Sonnet 4.5 (Anthropic, agentic)"
    "claude-bai-claude-sonnet-4.6|B.AI - Claude Sonnet 4.6 (Anthropic, agentic)"
    "claude-bai-claude-opus-4.5|B.AI - Claude Opus 4.5 (Anthropic, agentic)"
    "claude-bai-claude-opus-4.6|B.AI - Claude Opus 4.6 (Anthropic, agentic)"
    "claude-bai-claude-opus-4.7|B.AI - Claude Opus 4.7 (Anthropic, agentic)"
    "claude-bai-claude-opus-4.8|B.AI - Claude Opus 4.8 (Anthropic, agentic)"
    "claude-bai-deepseek-v4-pro|B.AI - DeepSeek V4 Pro (agentic)"
    "claude-bai-deepseek-v4-flash|B.AI - DeepSeek V4 Flash (agentic)"
    "claude-bai-gemini-3.1-pro|B.AI - Gemini 3.1 Pro (Google, agentic)"
    "claude-bai-gemini-3.5-flash|B.AI - Gemini 3.5 Flash (Google, agentic)"
    "claude-bai-glm-5|B.AI - GLM-5 (Z.AI)"
    "claude-bai-glm-5.1|B.AI - GLM-5.1 (Z.AI)"
    "claude-bai-kimi-k2.5|B.AI - Kimi K2.5 (Moonshot)"
    "claude-bai-kimi-k2.6|B.AI - Kimi K2.6 (Moonshot)"
    "claude-bai-minimax-m3|B.AI - MiniMax M3 (agentic)"
    "claude-bai-minimax-m2.7|B.AI - MiniMax M2.7 (fast)"
)

# B.AI model_id (WITHOUT claude-bai- prefix) -> "context_window:max_tokens".
# Used to validate wildcard claude-bai-* profile IDs and as a future routing hint source.
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

# Submenu subtitles per group
GROUP_SUBTITLE_ZAI="Z.AI Coding (paid) + GLM-4.7-Flash"
GROUP_SUBTITLE_NIM="NVIDIA NIM - 9 бесплатных agentic моделей"
GROUP_SUBTITLE_OPENROUTER="OpenRouter - бесплатные agentic модели"
GROUP_SUBTITLE_BAI="B.AI - https://api.b.ai/v1 (OpenAI-compatible)"

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
        "claude-zai"|"claude-zai-glm51"|"claude-zai-flash47"|"claude-zai-flash45"| \
        "claude-nim"|"claude-nim-qwen"| \
        "claude-nim-mistral-medium"|"claude-nim-glm51"|"claude-nim-step-3.5-flash"| \
        "claude-nim-mistral-large-3"|"claude-nim-deepseek-v4-flash"|"claude-nim-gemma-4-31b"| \
        "claude-nim-qwen3.5-397b"|"claude-nim-qwen3-next-80b"|"claude-nim-qwen3-coder-480b"| \
        "claude-openrouter-hy3"|"claude-openrouter-nemotron"|"claude-openrouter-laguna"| \
        "claude-openrouter-deepseek-v4-flash"|"claude-openrouter-qwen3-coder"| \
        "custom-claude-zai"|"custom-claude-zai-general"|"custom-claude-nim"| \
        "custom-claude-openrouter"|"custom-claude-bai"|"custom-claude-groq")
            echo "$profile_id"
            return 0
            ;;
        claude-bai-*)
            local mid="${profile_id#claude-bai-}"
            if [[ -n "${BAI_MODEL_SPEC[$mid]:-}" ]]; then
                echo "$profile_id"
                return 0
            fi
            return 1
            ;;
        claude-zai-*|claude-nim-*|claude-openrouter-*)
            echo "$profile_id"
            return 0
            ;;
        *)
            return 1
            ;;
    esac
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

# ── free-claude-code proxy for NIM/OpenRouter ──────────────────────────────────
FCC_DIR="$HOME/.free-claude-code"

ensure_fcc_proxy() {
    local provider="$1"
    local model="$2"
    local preferred_port="${3:-8082}"
    local extra_env="${4:-}"

    _is_port_in_use() {
        ss -tlnp 2>/dev/null | grep -q ":${1} " || nc -z 127.0.0.1 "$1" 2>/dev/null
    }

    _kill_port() {
        fuser -k "${1}/tcp" 2>/dev/null || true
        sleep 1
    }

    _is_port_free() {
        ! (ss -tlnp 2>/dev/null | grep -q ":${1} " || nc -z 127.0.0.1 "$1" 2>/dev/null)
    }

    _check_http() {
        curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:${1}/v1/models" 2>/dev/null || true
    }

    _install_and_prepare() {
        if ! command -v uv &>/dev/null; then
            printf "${CYAN}Установка uv (Python package manager)...${RESET}\n" >&3
            curl -LsSf https://astral.sh/uv/install.sh | sh 2>/dev/null || {
                printf "${RED}Не удалось установить uv.${RESET}\n" >&3
                return 1
            }
            export PATH="$HOME/.local/bin:$PATH"
        fi

        if [ ! -d "$FCC_DIR" ]; then
            printf "${CYAN}Клонирование free-claude-code...${RESET}\n" >&3
            git clone https://github.com/Alishahryar1/free-claude-code.git "$FCC_DIR" 2>/dev/null || {
                printf "${RED}Не удалось клонировать free-claude-code.${RESET}\n" >&3
                return 1
            }
        fi

        (cd "$FCC_DIR" && git pull origin main >/dev/null 2>&1) || true

        timeout 30 sh -c 'cd "$1" && uv sync &>/dev/null' _ "$FCC_DIR" 2>/dev/null || true
    }

    _write_env() {
        local nim_key="${NVIDIA_NIM_API_KEY:-}"
        if [ -z "$nim_key" ] || [ "$nim_key" = "__SET_ME__" ]; then nim_key=$(get_current_api_key "NVIDIA_NIM"); fi
        local or_key="${OPENROUTER_API_KEY:-}"
        if [ -z "$or_key" ] || [ "$or_key" = "__SET_ME__" ]; then or_key=$(get_current_api_key "OPENROUTER"); fi
        if [ "$provider" = "bai" ]; then
            or_key="${BAI_API_KEY:-}"
            if [ -z "$or_key" ] || [ "$or_key" = "__SET_ME__" ]; then or_key=$(get_current_api_key "BAI"); fi
        fi
        export NVIDIA_NIM_API_KEY="$nim_key"
        export OPENROUTER_API_KEY="$or_key"
        cat > "$FCC_DIR/.env" << ENVEOF
NVIDIA_NIM_API_KEY="${nim_key}"
OPENROUTER_API_KEY="${or_key}"
MODEL="${model}"
ANTHROPIC_AUTH_TOKEN="freecc"
ENABLE_MODEL_THINKING=true
PROVIDER_RATE_LIMIT=1
PROVIDER_RATE_WINDOW=3
PROVIDER_MAX_CONCURRENCY=5
HTTP_READ_TIMEOUT=300
MESSAGING_PLATFORM="none"
ENABLE_WEB_SERVER_TOOLS=false
${extra_env}
ENVEOF
    }

    _start_proxy_on_port() {
        local port="$1"
        local log_file="$FCC_DIR/fcc-${port}.log"

        printf "${CYAN}Запуск free-claude-code proxy на порту ${port}...${RESET}\n" >&3
        printf "${GRAY}Логи: ${log_file}${RESET}\n" >&3

        nohup sh -c "cd '$FCC_DIR' && uv run uvicorn server:app --host 127.0.0.1 --port '$port' --log-level warning" </dev/null >>"$log_file" 2>&1 &
        local proxy_pid=$!
        disown "$proxy_pid" 2>/dev/null || true

        sleep 0.5

        local tries=0
        printf "${GRAY}  Ожидание TCP" >&3
        while [ $tries -lt 30 ]; do
            if nc -z 127.0.0.1 "$port" 2>/dev/null; then
                printf " ✓${RESET}\n" >&3
                break
            fi
            printf "." >&3
            sleep 1
            tries=$((tries + 1))
        done

        if [ $tries -ge 30 ]; then
            printf "${RED}Proxy не запустился за 30 сек (TCP порт не открыт).${RESET}\n" >&3
            printf "${YELLOW}Последние строки лога:${RESET}\n" >&3
            tail -20 "$log_file" >&3 2>/dev/null || true
            return 1
        fi

        local http_tries=0
        while [ $http_tries -lt 15 ]; do
            local http_code
            http_code=$(_check_http "$port")
            if [ -n "$http_code" ] && [ "$http_code" != "000" ]; then
                printf "${GREEN}  [OK] Proxy запущен на порту ${port} (HTTP ${http_code})${RESET}\n" >&3
                echo "$port"
                return 0
            fi
            sleep 1
            http_tries=$((http_tries + 1))
        done

        printf "${RED}Proxy TCP порт открыт, но HTTP не отвечает за 15 сек.${RESET}\n" >&3
        printf "${YELLOW}Последние строки лога:${RESET}\n" >&3
        tail -20 "$log_file" >&3 2>/dev/null || true
        return 1
    }

    _install_and_prepare || return 1
    _write_env

    local port="$preferred_port"
    local max_port=$((preferred_port + 2))

    while [ "$port" -le "$max_port" ]; do
        if ! _is_port_in_use "$port"; then
            local result
            result=$(_start_proxy_on_port "$port") && {
                echo "$result"
                return 0
            }
            return 1
        fi

        local env_file="$FCC_DIR/.env"
        if [ -f "$env_file" ] && ! grep -qx "MODEL=\"${model}\"" "$env_file"; then
            printf "${YELLOW}Proxy на порту ${port} запущен с другой моделью. Перезапуск...${RESET}\n" >&3
            _kill_port "$port"
            if _is_port_free "$port"; then
                local result
                result=$(_start_proxy_on_port "$port") && {
                    echo "$result"
                    return 0
                }
                return 1
            fi
            printf "${YELLOW}Порт ${port} не освободился после kill. Пробуем следующий...${RESET}\n" >&3
            port=$((port + 1))
            continue
        fi

        local existing_code
        existing_code=$(_check_http "$port")
        if [ -n "$existing_code" ] && [ "$existing_code" != "000" ]; then
            printf "${GREEN}  [OK] Proxy уже работает на порту ${port} (HTTP ${existing_code})${RESET}\n" >&3
            echo "$port"
            return 0
        fi

        printf "${YELLOW}Порт ${port} занят, но не отвечает на HTTP. Пробуем освободить...${RESET}\n" >&3
        _kill_port "$port"

        if _is_port_free "$port"; then
            local result
            result=$(_start_proxy_on_port "$port") && {
                echo "$result"
                return 0
            }
            return 1
        fi

        printf "${YELLOW}Порт ${port} занят сторонним процессом. Пробуем порт $((port + 1))...${RESET}\n" >&3
        port=$((port + 1))
    done

    printf "${RED}Не удалось найти свободный порт в диапазоне ${preferred_port}-${max_port}.${RESET}\n" >&3
    return 1
}

invoke_claude_cloud_profile() {
    local profile_id="$1"
    
    # Проверка API ключа
    local env_var=""
    local provider_name=""
    local provider_url=""
    case "$profile_id" in
        claude-zai*|custom-claude-zai*) env_var="ZAI"; provider_name="Z.AI"; provider_url="https://console.z.ai/" ;;
        "custom-claude-zai-general") env_var="ZAI"; provider_name="Z.AI General"; provider_url="https://console.z.ai/" ;;
        claude-nim*|custom-claude-nim*) env_var="NVIDIA_NIM"; provider_name="NVIDIA NIM"; provider_url="https://build.nvidia.com/api-key" ;;
        claude-openrouter*|custom-claude-openrouter*) env_var="OPENROUTER"; provider_name="OpenRouter"; provider_url="https://openrouter.ai/settings/keys" ;;
        claude-bai*|custom-claude-bai*) env_var="BAI"; provider_name="B.AI"; provider_url="https://chat.b.ai/key" ;;
        claude-groq*|custom-claude-groq*) env_var="GROQ"; provider_name="Groq"; provider_url="https://console.groq.com/keys" ;;
    esac
    if [ -n "$env_var" ]; then
        if ! ensure_api_key_or_prompt "$env_var" "$provider_name" "$provider_url"; then
            return 1
        fi
    fi
    
    # Находим claude CLI
    local claude_exe=""
    if command -v claude &>/dev/null; then
        claude_exe="$(command -v claude)"
    fi
    if [ -z "$claude_exe" ]; then
        printf "${RED}Claude Code CLI не найден. Установите: npm install -g @anthropic-ai/claude-code@latest${RESET}\n" >&3
        return 1
    fi
    
    # Определяем модель для Z.AI (NIM/OpenRouter используют proxy — модель задаётся ниже)
    local model=""
    case "$profile_id" in
        "claude-zai") model="glm-4.7" ;;
        "claude-zai-glm51") model="glm-5.1" ;;
        "claude-zai-flash47") model="glm-4.7-flash" ;;
        "claude-zai-flash45") model="glm-4.5-flash" ;;
        custom-claude-zai|"custom-claude-zai-general")
            local state=$(get_launcher_state)
            model=$(echo "$state" | grep -o '"customModelId":"[^"]*"' | cut -d'"' -f4)
            if [ -z "$model" ]; then
                printf "${RED}Нет customModelId. Выберите модель в «Другая модель».${RESET}\n" >&3
                return 1
            fi
            ;;
        claude-zai-*)
            model="${profile_id#claude-zai-}"
            ;;
        claude-nim*|claude-openrouter*|claude-bai*|claude-groq*|custom-claude-nim|custom-claude-openrouter|custom-claude-bai|custom-claude-groq)
            # Model determined in env-vars block below (via proxy)
            ;;
        *) model="" ;;
    esac
    
    # Устанавливаем env vars для Claude Code
    case "$profile_id" in
        claude-zai*|custom-claude-zai*|custom-claude-zai-general)
            local key="${ZAI_API_KEY:-}"
            if [ -z "$key" ] || [ "$key" = "__SET_ME__" ]; then key=$(get_current_api_key "ZAI"); fi
            if [ -z "$key" ] || [ "$key" = "__SET_ME__" ]; then key="${OPENAI_API_KEY:-}"; fi
            export ZAI_API_KEY="$key"
            export ANTHROPIC_API_KEY="$key"
            unset ANTHROPIC_AUTH_TOKEN
            export ANTHROPIC_BASE_URL="https://api.z.ai/api/anthropic"
            export ANTHROPIC_DEFAULT_OPUS_MODEL="$model"
            export ANTHROPIC_DEFAULT_SONNET_MODEL="$model"
            export ANTHROPIC_DEFAULT_HAIKU_MODEL="$model"
            export API_TIMEOUT_MS="3000000"
            update_claude_settings_env "0" \
                ANTHROPIC_API_KEY "$key" \
                ANTHROPIC_BASE_URL "https://api.z.ai/api/anthropic" \
                ANTHROPIC_DEFAULT_OPUS_MODEL "$model" \
                ANTHROPIC_DEFAULT_SONNET_MODEL "$model" \
                ANTHROPIC_DEFAULT_HAIKU_MODEL "$model" \
                API_TIMEOUT_MS "3000000" \
                ANTHROPIC_AUTH_TOKEN "__DELETE__" \
                OPENROUTER_API_KEY "__DELETE__" \
                OPENAI_BASE_URL "__DELETE__" \
                OPENAI_API_KEY "__DELETE__" \
                NVIDIA_NIM_API_KEY "__DELETE__" \
                BAI_API_KEY "__DELETE__" \
                CLAUDE_CODE_USE_OPENAI "__DELETE__" \
                OPENAI_MODEL "__DELETE__"
            ;;
        claude-nim*|custom-claude-nim*)
            local fcc_model="nvidia_nim/qwen/qwen3.5-122b-a10b"
            case "$profile_id" in
                "claude-nim-qwen") fcc_model="nvidia_nim/qwen/qwen3.5-122b-a10b" ;;
                "claude-nim-mistral-medium") fcc_model="nvidia_nim/mistralai/mistral-medium-3.5-128b" ;;
                "claude-nim-glm51") fcc_model="nvidia_nim/z-ai/glm-5.1" ;;
                "claude-nim-step-3.5-flash") fcc_model="nvidia_nim/stepfun-ai/step-3.5-flash" ;;
                "claude-nim-mistral-large-3") fcc_model="nvidia_nim/mistralai/mistral-large-3-675b-instruct-2512" ;;
                "claude-nim-deepseek-v4-flash") fcc_model="nvidia_nim/deepseek-ai/deepseek-v4-flash" ;;
                "claude-nim-gemma-4-31b") fcc_model="nvidia_nim/google/gemma-4-31b-it" ;;
                "claude-nim-qwen3.5-397b") fcc_model="nvidia_nim/qwen/qwen3.5-397b-a17b" ;;
                "claude-nim-qwen3-next-80b") fcc_model="nvidia_nim/qwen/qwen3-next-80b-a3b-instruct" ;;
                "claude-nim-qwen3-coder-480b") fcc_model="nvidia_nim/qwen/qwen3-coder-480b-a35b-instruct" ;;
                "custom-claude-nim")
                    local st=$(get_launcher_state)
                    local cm=$(echo "$st" | grep -o '"customNimModel":"[^"]*"' | cut -d'"' -f4)
                    if [ -n "$cm" ]; then fcc_model="nvidia_nim/$cm"; fi
                    ;;
                *)
                    fcc_model="nvidia_nim/${profile_id#claude-nim-}"
                    ;;
            esac
            local proxy_port
            local nim_proxy_port="8082"
            if [ "$profile_id" = "claude-nim-qwen" ]; then nim_proxy_port="8083"; fi
            proxy_port=$(ensure_fcc_proxy "nvidia_nim" "$fcc_model" "$nim_proxy_port") || {
                printf "${RED}Не удалось запустить free-claude-code proxy.${RESET}\n" >&3
                return 1
            }
            # Final HTTP sanity check before launching Claude Code
            local precheck_code
            precheck_code=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:${proxy_port}/v1/models" 2>/dev/null) || true
            if [ -z "$precheck_code" ] || [ "$precheck_code" = "000" ]; then
                printf "${RED}Proxy на порту ${proxy_port} не отвечает на HTTP-запросы.${RESET}\n" >&3
                printf "${YELLOW}Логи: $FCC_DIR/fcc-${proxy_port}.log${RESET}\n" >&3
                return 1
            fi
            export ANTHROPIC_AUTH_TOKEN="freecc"
            unset ANTHROPIC_API_KEY
            export ANTHROPIC_BASE_URL="http://127.0.0.1:${proxy_port}"
            export ANTHROPIC_DEFAULT_OPUS_MODEL="$fcc_model"
            export ANTHROPIC_DEFAULT_SONNET_MODEL="$fcc_model"
            export ANTHROPIC_DEFAULT_HAIKU_MODEL="$fcc_model"
            export API_TIMEOUT_MS="3000000"
            update_claude_settings_env "1" \
                ANTHROPIC_AUTH_TOKEN "freecc" \
                ANTHROPIC_BASE_URL "http://127.0.0.1:${proxy_port}" \
                API_TIMEOUT_MS "3000000" \
                ANTHROPIC_API_KEY "__DELETE__" \
                ANTHROPIC_DEFAULT_OPUS_MODEL "__DELETE__" \
                ANTHROPIC_DEFAULT_SONNET_MODEL "__DELETE__" \
                ANTHROPIC_DEFAULT_HAIKU_MODEL "__DELETE__" \
                OPENROUTER_API_KEY "__DELETE__" \
                OPENAI_BASE_URL "__DELETE__" \
                OPENAI_API_KEY "__DELETE__" \
                BAI_API_KEY "__DELETE__" \
                CLAUDE_CODE_USE_OPENAI "__DELETE__" \
                OPENAI_MODEL "__DELETE__"
            ;;
        claude-openrouter*|custom-claude-openrouter*)
            # Keep main menu to working free tool-calling models; custom still supported.
            local fcc_model="open_router/deepseek/deepseek-chat-v3.1:free"
            case "$profile_id" in
                "claude-openrouter-hy3") fcc_model="open_router/deepseek/deepseek-chat-v3.1:free" ;;
                "claude-openrouter-deepseek-v4-flash") fcc_model="open_router/deepseek/deepseek-chat-v3.1:free" ;;
                "claude-openrouter-qwen3-coder") fcc_model="open_router/qwen/qwen3-coder:free" ;;
                "claude-openrouter-nemotron") fcc_model="open_router/nvidia/nemotron-3-super-120b-a12b:free" ;;
                "claude-openrouter-laguna") fcc_model="open_router/poolside/laguna-m.1:free" ;;
                "custom-claude-openrouter")
                    local st=$(get_launcher_state)
                    local cm=$(echo "$st" | grep -o '"customModelId":"[^"]*"' | cut -d'"' -f4)
                    if [ -n "$cm" ]; then fcc_model="open_router/$cm"; fi
                    ;;
                *)
                    fcc_model="open_router/${profile_id#claude-openrouter-}"
                    ;;
            esac
            local proxy_port
            proxy_port=$(ensure_fcc_proxy "open_router" "$fcc_model" "8084") || {
                printf "${RED}Не удалось запустить free-claude-code proxy.${RESET}\n" >&3
                return 1
            }
            # Final HTTP sanity check before launching Claude Code
            local precheck_code
            precheck_code=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:${proxy_port}/v1/models" 2>/dev/null) || true
            if [ -z "$precheck_code" ] || [ "$precheck_code" = "000" ]; then
                printf "${RED}Proxy на порту ${proxy_port} не отвечает на HTTP-запросы.${RESET}\n" >&3
                printf "${YELLOW}Логи: $FCC_DIR/fcc-${proxy_port}.log${RESET}\n" >&3
                return 1
            fi
            export ANTHROPIC_AUTH_TOKEN="freecc"
            unset ANTHROPIC_API_KEY
            export ANTHROPIC_BASE_URL="http://127.0.0.1:${proxy_port}"
            export ANTHROPIC_DEFAULT_OPUS_MODEL="$fcc_model"
            export ANTHROPIC_DEFAULT_SONNET_MODEL="$fcc_model"
            export ANTHROPIC_DEFAULT_HAIKU_MODEL="$fcc_model"
            export API_TIMEOUT_MS="3000000"
            update_claude_settings_env "1" \
                ANTHROPIC_AUTH_TOKEN "freecc" \
                ANTHROPIC_BASE_URL "http://127.0.0.1:${proxy_port}" \
                API_TIMEOUT_MS "3000000" \
                OPENROUTER_API_KEY "${OPENROUTER_API_KEY:-}" \
                ANTHROPIC_API_KEY "__DELETE__" \
                ANTHROPIC_DEFAULT_OPUS_MODEL "__DELETE__" \
                ANTHROPIC_DEFAULT_SONNET_MODEL "__DELETE__" \
                ANTHROPIC_DEFAULT_HAIKU_MODEL "__DELETE__" \
                OPENAI_BASE_URL "__DELETE__" \
                OPENAI_API_KEY "__DELETE__" \
                BAI_API_KEY "__DELETE__" \
                NVIDIA_NIM_API_KEY "__DELETE__" \
                CLAUDE_CODE_USE_OPENAI "__DELETE__" \
                OPENAI_MODEL "__DELETE__"
            ;;
        claude-bai-*|custom-claude-bai*)
            local mid="${profile_id#claude-bai-}"
            local bai_model
            if [ "$profile_id" = "custom-claude-bai" ]; then
                local st=$(get_launcher_state)
                local cm=$(echo "$st" | grep -o '"customModelId":"[^"]*"' | cut -d'"' -f4)
                if [ -z "$cm" ]; then
                    printf "${RED}Нет customModelId. Выберите модель в «Другая модель».${RESET}\n" >&3
                    return 1
                fi
                bai_model="$cm"
            else
                if [ -z "${BAI_MODEL_SPEC[$mid]:-}" ]; then
                    printf "${RED}Неизвестная B.AI модель: $mid${RESET}\n" >&3
                    return 1
                fi
                bai_model="$mid"
            fi

            local bai_proxy_port="8088"
            local bai_proxy_script="$SCRIPT_DIR/bai-anthropic-proxy.py"
            local bai_proxy_log="$HOME/.qwen-local-setup/bai-proxy.log"
            mkdir -p "$HOME/.qwen-local-setup"

            local bai_resolved_key="${BAI_API_KEY:-}"
            if [ -z "$bai_resolved_key" ] || [ "$bai_resolved_key" = "__SET_ME__" ]; then
                bai_resolved_key=$(get_current_api_key "BAI")
            fi
            export BAI_API_KEY="$bai_resolved_key"

            if ! (ss -tlnp 2>/dev/null | grep -q ":${bai_proxy_port} " || nc -z 127.0.0.1 "$bai_proxy_port" 2>/dev/null); then
                printf "${CYAN}Запуск B.AI Anthropic proxy на порту ${bai_proxy_port}...${RESET}\n" >&3
                BAI_API_KEY="$bai_resolved_key" \
                OPENROUTER_API_KEY="$bai_resolved_key" \
                OPENAI_BASE_URL="https://api.b.ai/v1" \
                MODEL="$bai_model" \
                HTTP_READ_TIMEOUT=300 \
                BAI_PROXY_LOG="$bai_proxy_log" \
                nohup python3 "$bai_proxy_script" "$bai_proxy_port" </dev/null >>"$bai_proxy_log" 2>&1 &
                local bai_pid=$!
                disown "$bai_pid" 2>/dev/null || true
                local bai_tries=0
                printf "${GRAY}  Ожидание TCP" >&3
                while [ $bai_tries -lt 20 ]; do
                    if nc -z 127.0.0.1 "$bai_proxy_port" 2>/dev/null; then
                        printf " ✓${RESET}\n" >&3
                        break
                    fi
                    printf "." >&3
                    sleep 1
                    bai_tries=$((bai_tries + 1))
                done
                if [ $bai_tries -ge 20 ]; then
                    printf "${RED}B.AI proxy не запустился за 20 сек.${RESET}\n" >&3
                    tail -20 "$bai_proxy_log" >&3 2>/dev/null || true
                    return 1
                fi
            fi

            local precheck_code
            precheck_code=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:${bai_proxy_port}/v1/models" 2>/dev/null) || true
            if [ -z "$precheck_code" ] || [ "$precheck_code" = "000" ]; then
                printf "${RED}B.AI proxy на порту ${bai_proxy_port} не отвечает.${RESET}\n" >&3
                printf "${YELLOW}Логи: ${bai_proxy_log}${RESET}\n" >&3
                return 1
            fi

            export ANTHROPIC_AUTH_TOKEN="freecc"
            unset ANTHROPIC_API_KEY
            export ANTHROPIC_BASE_URL="http://127.0.0.1:${bai_proxy_port}"
            export API_TIMEOUT_MS="3000000"
            update_claude_settings_env "1" \
                ANTHROPIC_AUTH_TOKEN "freecc" \
                ANTHROPIC_BASE_URL "http://127.0.0.1:${bai_proxy_port}" \
                API_TIMEOUT_MS "3000000" \
                ANTHROPIC_API_KEY "__DELETE__" \
                ANTHROPIC_DEFAULT_OPUS_MODEL "__DELETE__" \
                ANTHROPIC_DEFAULT_SONNET_MODEL "__DELETE__" \
                ANTHROPIC_DEFAULT_HAIKU_MODEL "__DELETE__" \
                OPENAI_BASE_URL "__DELETE__" \
                OPENAI_API_KEY "__DELETE__" \
                OPENROUTER_API_KEY "__DELETE__" \
                CLAUDE_CODE_USE_OPENAI "__DELETE__" \
                OPENAI_MODEL "__DELETE__" \
                NVIDIA_NIM_API_KEY "__DELETE__" \
                BAI_API_KEY "__DELETE__"
            ;;
        custom-claude-groq)
            local st=$(get_launcher_state)
            local cm=$(echo "$st" | grep -o '"customModelId":"[^"]*"' | cut -d'"' -f4)
            if [ -z "$cm" ]; then
                printf "${RED}Нет customModelId для Groq. Выберите модель в «Другая модель».${RESET}\n" >&3
                return 1
            fi
            local fcc_model="groq/$cm"
            local groq_extra_env='OPENAI_BASE_URL="https://api.groq.com/openai/v1"'
            local proxy_port
            proxy_port=$(ensure_fcc_proxy "groq" "$fcc_model" "8086" "$groq_extra_env") || {
                printf "${RED}Не удалось запустить free-claude-code proxy.${RESET}\n" >&3
                return 1
            }
            local precheck_code
            precheck_code=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:${proxy_port}/v1/models" 2>/dev/null) || true
            if [ -z "$precheck_code" ] || [ "$precheck_code" = "000" ]; then
                printf "${RED}Proxy на порту ${proxy_port} не отвечает на HTTP-запросы.${RESET}\n" >&3
                printf "${YELLOW}Логи: $FCC_DIR/fcc-${proxy_port}.log${RESET}\n" >&3
                return 1
            fi
            local groq_key="${GROQ_API_KEY:-}"
            if [ -z "$groq_key" ] || [ "$groq_key" = "__SET_ME__" ]; then groq_key=$(get_current_api_key "GROQ"); fi
            export GROQ_API_KEY="$groq_key"
            export OPENROUTER_API_KEY="$groq_key"
            export OPENAI_BASE_URL="https://api.groq.com/openai/v1"
            export ANTHROPIC_AUTH_TOKEN="freecc"
            unset ANTHROPIC_API_KEY
            export ANTHROPIC_BASE_URL="http://127.0.0.1:${proxy_port}"
            export ANTHROPIC_DEFAULT_OPUS_MODEL="$fcc_model"
            export ANTHROPIC_DEFAULT_SONNET_MODEL="$fcc_model"
            export ANTHROPIC_DEFAULT_HAIKU_MODEL="$fcc_model"
            export API_TIMEOUT_MS="3000000"
            update_claude_settings_env "1" \
                ANTHROPIC_AUTH_TOKEN "freecc" \
                ANTHROPIC_BASE_URL "http://127.0.0.1:${proxy_port}" \
                API_TIMEOUT_MS "3000000" \
                OPENROUTER_API_KEY "$groq_key" \
                OPENAI_BASE_URL "https://api.groq.com/openai/v1" \
                ANTHROPIC_API_KEY "__DELETE__" \
                ANTHROPIC_DEFAULT_OPUS_MODEL "__DELETE__" \
                ANTHROPIC_DEFAULT_SONNET_MODEL "__DELETE__" \
                ANTHROPIC_DEFAULT_HAIKU_MODEL "__DELETE__" \
                OPENAI_API_KEY "__DELETE__" \
                CLAUDE_CODE_USE_OPENAI "__DELETE__" \
                OPENAI_MODEL "__DELETE__" \
                NVIDIA_NIM_API_KEY "__DELETE__" \
                BAI_API_KEY "__DELETE__"
            ;;
    esac
    
    # Входим в shared session dir и запускаем claude
    enter_claude_shared_dir
    
    clear >&3
    printf "${CYAN}Запуск Claude Code…${RESET}\n" >&3
    printf "${GRAY}Провайдер: $profile_id   Модель: ${model:-default}${RESET}\n" >&3
    printf "${GRAY}Директория сессий: $(pwd)${RESET}\n" >&3
    printf "${GRAY}ANTHROPIC_BASE_URL=${ANTHROPIC_BASE_URL:-<unset>}  ANTHROPIC_AUTH_TOKEN=${ANTHROPIC_AUTH_TOKEN:+set}  ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY:+set}${RESET}\n" >&3
    printf "\n" >&3
    
    # --bare: skip OAuth/keychain, use only ANTHROPIC_API_KEY (env or settings).
    exec "$claude_exe" --bare
}

invoke_claude_dynamic_fallback() {
    local profile_id="$1"
    local raw_model="" fcc_prefix="" provider="" port="8082"

    case "$profile_id" in
        claude-zai-*)
            raw_model="${profile_id#claude-zai-}"
            local key="${ZAI_API_KEY:-}"
            if [ -z "$key" ] || [ "$key" = "__SET_ME__" ]; then key=$(get_current_api_key "ZAI"); fi
            export ANTHROPIC_API_KEY="$key"
            unset ANTHROPIC_AUTH_TOKEN
            export ANTHROPIC_BASE_URL="https://api.z.ai/api/anthropic"
            export ANTHROPIC_DEFAULT_OPUS_MODEL="$raw_model"
            export ANTHROPIC_DEFAULT_SONNET_MODEL="$raw_model"
            export ANTHROPIC_DEFAULT_HAIKU_MODEL="$raw_model"
            update_claude_settings_env "0" \
                ANTHROPIC_API_KEY "$key" \
                ANTHROPIC_BASE_URL "https://api.z.ai/api/anthropic" \
                ANTHROPIC_DEFAULT_OPUS_MODEL "$raw_model" \
                ANTHROPIC_DEFAULT_SONNET_MODEL "$raw_model" \
                ANTHROPIC_DEFAULT_HAIKU_MODEL "$raw_model" \
                API_TIMEOUT_MS "3000000" \
                ANTHROPIC_AUTH_TOKEN "__DELETE__"
            local claude_exe
            if command -v claude &>/dev/null; then claude_exe="$(command -v claude)"; fi
            if [ -n "$claude_exe" ]; then enter_claude_shared_dir; exec "$claude_exe" --bare; fi
            return 1
            ;;
        claude-nim-*)
            raw_model="${profile_id#claude-nim-}"
            fcc_prefix="nvidia_nim"
            provider="nvidia_nim"
            port="8082"
            ;;
        claude-openrouter-*)
            raw_model="${profile_id#claude-openrouter-}"
            fcc_prefix="open_router"
            provider="open_router"
            port="8084"
            ;;
        *)
            echo -e "${RED}Неизвестный профиль: $profile_id${RESET}"
            return 1
            ;;
    esac

    local fcc_model="${fcc_prefix}/${raw_model}"
    local proxy_port
    proxy_port=$(ensure_fcc_proxy "$provider" "$fcc_model" "$port") || {
        printf "${RED}Не удалось запустить free-claude-code proxy.${RESET}\n" >&3
        return 1
    }
    export ANTHROPIC_AUTH_TOKEN="freecc"
    unset ANTHROPIC_API_KEY
    export ANTHROPIC_BASE_URL="http://127.0.0.1:${proxy_port}"
    export ANTHROPIC_DEFAULT_OPUS_MODEL="$fcc_model"
    export ANTHROPIC_DEFAULT_SONNET_MODEL="$fcc_model"
    export ANTHROPIC_DEFAULT_HAIKU_MODEL="$fcc_model"
    export API_TIMEOUT_MS="3000000"
    update_claude_settings_env "1" \
        ANTHROPIC_AUTH_TOKEN "freecc" \
        ANTHROPIC_BASE_URL "http://127.0.0.1:${proxy_port}" \
        API_TIMEOUT_MS "3000000" \
        ANTHROPIC_API_KEY "__DELETE__" \
        ANTHROPIC_DEFAULT_OPUS_MODEL "__DELETE__" \
        ANTHROPIC_DEFAULT_SONNET_MODEL "__DELETE__" \
        ANTHROPIC_DEFAULT_HAIKU_MODEL "__DELETE__"

    local claude_exe
    if command -v claude &>/dev/null; then claude_exe="$(command -v claude)"; fi
    if [ -n "$claude_exe" ]; then enter_claude_shared_dir; exec "$claude_exe" --bare; fi
    return 1
}

# ── API key helpers ──────────────────────────────────────────────────────────
get_claude_zai_api_key() {
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

get_claude_nim_api_key() {
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

get_claude_openrouter_api_key() {
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

get_claude_bai_api_key() {
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

get_claude_groq_api_key() {
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

# ── Мастер выбора модели ─────────────────────────────────────────────────────
invoke_claude_custom_model_wizard() {
    local app_brand="$1"

    local prov_items=(
        "zai|Z.AI - Coding / Anthropic (GET /models по вашему ключу)"
        "nim|NVIDIA NIM - полный каталог (GET /v1/models)"
        "groq|Groq - полный каталог моделей (paid, GET /v1/models)"
        "openrouter|OpenRouter - полный каталог моделей (GET /v1/models)"
        "bai|B.AI - https://api.b.ai/v1 (OpenAI-compatible)"
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
            key=$(get_claude_zai_api_key) || true

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
            key=$(get_claude_nim_api_key) || true

            local response
            response=$(curl -s -H "Authorization: Bearer $key" "https://integrate.api.nvidia.com/v1/models" 2>/dev/null) || true

            if [ -n "$response" ]; then
                ids=($(echo "$response" | grep -o '"id":"[^"]*"' | cut -d'"' -f4 | sort -u))
            fi
        elif [ "$prov_source" = "openrouter" ]; then
            show_tui_wait_frame "$app_brand" "Загрузка каталога OpenRouter…"
            key=$(get_claude_openrouter_api_key) || true

            local response
            response=$(curl -s -H "Authorization: Bearer $key" -H "Content-Type: application/json" "https://openrouter.ai/api/v1/models" 2>/dev/null) || true

            if [ -n "$response" ]; then
                ids=($(echo "$response" | grep -o '"id":"[^"]*"' | cut -d'"' -f4 | sort -u))
            fi
        elif [ "$prov_source" = "groq" ]; then
            show_tui_wait_frame "$app_brand" "Загрузка каталога Groq…"
            key=$(get_claude_groq_api_key) || true

            local response
            response=$(curl -s -H "Authorization: Bearer $key" -H "Content-Type: application/json" "https://api.groq.com/openai/v1/models" 2>/dev/null) || true

            if [ -n "$response" ]; then
                ids=($(echo "$response" | grep -o '"id":"[^"]*"' | cut -d'"' -f4 | sort -u))
            fi
        elif [ "$prov_source" = "bai" ]; then
            show_tui_wait_frame "$app_brand" "Загрузка каталога B.AI…"
            key=$(get_claude_bai_api_key) || true

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

# Быстрый старт
if [ "${CLAUDE_CLOUD_LAUNCHER_QUICK:-0}" = "1" ]; then
    if state=$(get_launcher_state); then
        if resolved_id=$(resolve_profile_from_state "$state"); then
            invoke_claude_cloud_profile "$resolved_id"
            exit $?
        fi
    fi
    
    echo -e "${YELLOW}Нет сохранённого профиля Claude. Один раз выберите провайдер в меню.${RESET}"
    sleep 3
    exit 2
fi

# ── Dynamic model fetching (with static fallback) ────────────────────────────
echo -e "${GRAY}Загрузка списков моделей...${RESET}" >&3

DYNAMIC_ZAI=()
mapfile -t DYNAMIC_ZAI < <(fetch_menu_items "ZAI_API_KEY" \
    "https://api.z.ai/api/coding/paas/v4/models" "claude-zai-" \
    "glm-5.1:claude-zai-glm51|glm-4.7:claude-zai|glm-4.7-flash:claude-zai-flash47" \
    "claude-zai-flash47" "" \
    "claude-zai-glm51|Z.AI - GLM-5.1 (paid, tool calling)" \
    "claude-zai|Z.AI - GLM-4.7 (paid, tool calling)" \
    "claude-zai-flash47|Z.AI - GLM-4.7-Flash (free)" 2>/dev/null) || true
if [ ${#DYNAMIC_ZAI[@]} -gt 0 ]; then ZAI_MODELS=("${DYNAMIC_ZAI[@]}"); fi

DYNAMIC_NIM=()
mapfile -t DYNAMIC_NIM < <(fetch_menu_items "NVIDIA_NIM_API_KEY" \
    "https://integrate.api.nvidia.com/v1/models" "claude-nim-" \
    "mistralai/mistral-medium-3.5-128b:claude-nim-mistral-medium|z-ai/glm-5.1:claude-nim-glm51|stepfun-ai/step-3.5-flash:claude-nim-step-3.5-flash|mistralai/mistral-large-3-675b-instruct-2512:claude-nim-mistral-large-3|deepseek-ai/deepseek-v4-flash:claude-nim-deepseek-v4-flash|google/gemma-4-31b-it:claude-nim-gemma-4-31b|qwen/qwen3.5-397b-a17b:claude-nim-qwen3.5-397b|qwen/qwen3-next-80b-a3b-instruct:claude-nim-qwen3-next-80b|qwen/qwen3-coder-480b-a35b-instruct:claude-nim-qwen3-coder-480b" \
    "" "$(printf '%s|' "${NIM_AGENTIC_IDS[@]}" | sed 's/|$//')" \
    "${NIM_MODELS[@]}" 2>/dev/null) || true
if [ ${#DYNAMIC_NIM[@]} -gt 0 ]; then NIM_MODELS=("${DYNAMIC_NIM[@]}"); fi

DYNAMIC_BAI=()
mapfile -t DYNAMIC_BAI < <(fetch_menu_items "BAI_API_KEY" \
    "https://api.b.ai/v1/models" "claude-bai-" "" "" "" \
    "${BAI_MODELS[@]}" 2>/dev/null) || true
if [ ${#DYNAMIC_BAI[@]} -gt 0 ]; then BAI_MODELS=("${DYNAMIC_BAI[@]}"); fi

DYNAMIC_OR=()
mapfile -t DYNAMIC_OR < <(fetch_or_free_menu_items "OPENROUTER_API_KEY" "claude-openrouter-" \
    "deepseek/deepseek-chat-v3.1:free:claude-openrouter-deepseek-v4-flash|qwen/qwen3-coder:free:claude-openrouter-qwen3-coder|nvidia/nemotron-3-super-120b-a12b:free:claude-openrouter-nemotron|poolside/laguna-m.1:free:claude-openrouter-laguna" \
    "${OPENROUTER_MODELS[@]}" 2>/dev/null) || true
if [ ${#DYNAMIC_OR[@]} -gt 0 ]; then OPENROUTER_MODELS=("${DYNAMIC_OR[@]}"); fi

# Main menu loop
main() {
local update_hint=$(test_launcher_updates)
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
    choice="$(show_tui_numbered_menu "Claude" "Claude Code - провайдер" "Z.AI · NIM · Groq · OpenRouter · B.AI (через free-claude-code)" ${update_hint:+"$update_hint"} "${menu_items[@]}")"
    
    if [ "${choice:-0}" -eq 0 ]; then
        continue
    fi
    
    local profile_id=$(echo "${PROFILES[$((choice-1))]}" | cut -d'|' -f1)
    
    # Provider group submenu
    case "$profile_id" in
        group:*)
            local group_key="${profile_id#group:}"
            local group_items=()
            local group_subtitle=""
            case "$group_key" in
                zai)
                    group_items=("${ZAI_MODELS[@]}")
                    group_subtitle="$GROUP_SUBTITLE_ZAI"
                    ;;
                nim)
                    group_items=("${NIM_MODELS[@]}")
                    group_subtitle="$GROUP_SUBTITLE_NIM"
                    ;;
                openrouter)
                    group_items=("${OPENROUTER_MODELS[@]}")
                    group_subtitle="$GROUP_SUBTITLE_OPENROUTER"
                    ;;
                bai)
                    group_items=("${BAI_MODELS[@]}")
                    group_subtitle="$GROUP_SUBTITLE_BAI"
                    ;;
                *)
                    echo -e "${RED}Неизвестная группа: $group_key${RESET}"
                    sleep 2
                    continue
                    ;;
            esac
            
            local sub_menu=()
            for item in "${group_items[@]}"; do
                sub_menu+=("${item##*|}")
            done
            
            local upper_key=$(echo "$group_key" | tr '[:lower:]' '[:upper:]')
            local sub_choice
            sub_choice="$(show_tui_numbered_menu "Claude" "Claude Code - $upper_key" "$group_subtitle" "${sub_menu[@]}")"
            
            if [ "${sub_choice:-0}" -eq 0 ]; then
                continue
            fi
            
            profile_id=$(echo "${group_items[$((sub_choice-1))]}" | cut -d'|' -f1)
            save_launcher_state "$profile_id"
            invoke_claude_cloud_profile "$profile_id"
            continue
            ;;
    esac
    
    case "$profile_id" in
        "native-login")
            if ! command -v claude &>/dev/null; then
                echo -e "${RED}Claude Code CLI не найден (claude). Установите: npm install -g @anthropic-ai/claude-code@latest${RESET}"
                echo -e "${GREEN}Нажмите Enter для возврата в меню…${RESET}"
                read
                continue
            fi
            local login_items=("claude-sub|Claude подписка (OAuth, браузер)" "anthropic-console|Anthropic Console (API-биллинг, браузер)" "vanilla|Запуск Claude Code (ванильный запуск)")
            local login_menu=()
            for item in "${login_items[@]}"; do
                login_menu+=("${item##*|}")
            done

            local login_choice
            login_choice="$(show_tui_numbered_menu "Claude" "Нативный логин Claude Code" "Anthropic авторизация" "${login_menu[@]}")"

            if [ "${login_choice:-0}" -eq 0 ]; then
                continue
            fi

            local login_id=$(echo "${login_items[$((login_choice-1))]}" | cut -d'|' -f1)

            case "$login_id" in
                "claude-sub")
                    clear
                    echo -e "${CYAN}═══════════════════════════════════════════════════${RESET}"
                    echo -e "${CYAN}  Claude OAuth - авторизация через браузер${RESET}"
                    echo -e "${CYAN}═══════════════════════════════════════════════════${RESET}"
                    echo ""
                    echo -e "${YELLOW}  Откроется браузер. Завершите авторизацию в нём.${RESET}"
                    echo -e "${YELLOW}  Нужна подписка Claude Pro / Max (claude.ai).${RESET}"
                    echo ""
                    echo -e "${CYAN}  Запуск...${RESET}"
                    enter_claude_shared_dir
                    claude auth login --claudeai
                    echo ""
                    echo -e "${GREEN}  Текущий статус:${RESET}"
                    claude auth status
                    echo ""
                    echo -e "${GREEN}Нажмите Enter для возврата в меню…${RESET}"
                    read
                    ;;
                "anthropic-console")
                    clear
                    echo -e "${CYAN}═══════════════════════════════════════════════════${RESET}"
                    echo -e "${CYAN}  Anthropic Console - авторизация через браузер${RESET}"
                    echo -e "${CYAN}═══════════════════════════════════════════════════${RESET}"
                    echo ""
                    echo -e "${YELLOW}  Откроется браузер. Завершите авторизацию.${RESET}"
                    echo -e "${YELLOW}  Нужен аккаунт на console.anthropic.com.${RESET}"
                    echo ""
                    echo -e "${CYAN}  Запуск...${RESET}"
                    enter_claude_shared_dir
                    claude auth login --console
                    echo ""
                    echo -e "${GREEN}  Текущий статус:${RESET}"
                    claude auth status
                    echo ""
                    echo -e "${GREEN}Нажмите Enter для возврата в меню…${RESET}"
                    read
                    ;;
                "vanilla")
                    unset ANTHROPIC_API_KEY ANTHROPIC_BASE_URL ANTHROPIC_AUTH_TOKEN
                    unset ANTHROPIC_DEFAULT_OPUS_MODEL ANTHROPIC_DEFAULT_SONNET_MODEL ANTHROPIC_DEFAULT_HAIKU_MODEL
                    unset OPENAI_BASE_URL OPENAI_API_KEY OPENAI_MODEL CLAUDE_CODE_USE_OPENAI
                    unset OPENROUTER_API_KEY NVIDIA_NIM_API_KEY BAI_API_KEY API_TIMEOUT_MS
                    claude_settings="$HOME/.claude/settings.json"
                    if [ -f "$claude_settings" ] && command -v jq &>/dev/null; then
                        for ek in ANTHROPIC_API_KEY ANTHROPIC_BASE_URL ANTHROPIC_AUTH_TOKEN ANTHROPIC_DEFAULT_OPUS_MODEL ANTHROPIC_DEFAULT_SONNET_MODEL ANTHROPIC_DEFAULT_HAIKU_MODEL OPENAI_BASE_URL OPENAI_API_KEY OPENAI_MODEL CLAUDE_CODE_USE_OPENAI OPENROUTER_API_KEY NVIDIA_NIM_API_KEY BAI_API_KEY API_TIMEOUT_MS; do
                            jq --arg k "$ek" 'del(.env[$k])' "$claude_settings" > "${claude_settings}.tmp" 2>/dev/null && mv -f "${claude_settings}.tmp" "$claude_settings"
                        done
                    fi
                    clear
                    echo -e "${CYAN}═══════════════════════════════════════════════════${RESET}"
                    echo -e "${CYAN}  Запуск Claude Code (ванильный запуск)${RESET}"
                    echo -e "${CYAN}═══════════════════════════════════════════════════${RESET}"
                    echo ""
                    echo -e "${YELLOW}  Команда: claude${RESET}"
                    echo ""
                    enter_claude_shared_dir
                    claude
                    echo ""
                    echo -e "${GREEN}Нажмите Enter для возврата в меню…${RESET}"
                    read
                    ;;
            esac
            continue
            ;;
        "change-api-key")
            show_api_key_change_menu "Claude"
            continue
            ;;
        "custom-model")
            wizard_result=$(invoke_claude_custom_model_wizard "Claude") || {
                echo -e "${YELLOW}Отменено.${RESET}"
                continue
            }
            local wiz_provider=$(echo "$wizard_result" | cut -d'|' -f1)
            local wiz_model=$(echo "$wizard_result" | cut -d'|' -f2)
            
            local new_id="custom-claude-nim"
            local extra="\"customNimModel\":\"$wiz_model\""
            if [ "$wiz_provider" = "zai" ] || [ "$wiz_provider" = "zai-general" ]; then
                new_id="custom-claude-zai"
                extra="\"customModelId\":\"$wiz_model\""
            elif [ "$wiz_provider" = "groq" ]; then
                new_id="custom-claude-groq"
                extra="\"customModelId\":\"$wiz_model\""
            elif [ "$wiz_provider" = "openrouter" ]; then
                new_id="custom-claude-openrouter"
                extra="\"customModelId\":\"$wiz_model\""
            elif [ "$wiz_provider" = "bai" ]; then
                new_id="custom-claude-bai"
                extra="\"customModelId\":\"$wiz_model\""
            fi
            
            save_launcher_state "$new_id" "$extra"
            invoke_claude_cloud_profile "$new_id"
            continue
            ;;
        "last")
            if state=$(get_launcher_state); then
                if resolved_id=$(resolve_profile_from_state "$state"); then
                    profile_id="$resolved_id"
                else
                    echo -e "${RED}Сохранённый профиль не найден. Выберите пункт меню один раз.${RESET}"
                    read -p "Нажмите Enter..."
                    continue
                fi
            else
                echo -e "${RED}Сохранённый профиль не найден. Выберите пункт меню один раз.${RESET}"
                read -p "Нажмите Enter..."
                continue
            fi
            ;;
        *)
            save_launcher_state "$profile_id"
            ;;
    esac
    
    if ! invoke_claude_cloud_profile "$profile_id" 2>/dev/null; then
        invoke_claude_dynamic_fallback "$profile_id"
    fi
    continue
done
}
main "$@"
