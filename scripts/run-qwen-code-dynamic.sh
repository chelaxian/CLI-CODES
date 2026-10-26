#!/bin/bash
# Динамический запуск Qwen Code с произвольным OpenAI-совместимым провайдером
# Usage: bash run-qwen-code-dynamic.sh -Provider <zai|nim|groq|openrouter> -ModelId <model-id>

set -euo pipefail

PROVIDER=""
MODEL_ID=""
CTX_LENGTH_CLI=""
MAX_TOKENS_CLI=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -Provider) PROVIDER="$2"; shift 2 ;;
    -ModelId) MODEL_ID="$2"; shift 2 ;;
    --ctx-length) CTX_LENGTH_CLI="$2"; shift 2 ;;
    --max-tokens) MAX_TOKENS_CLI="$2"; shift 2 ;;
    *) echo "Unknown param: $1" >&2; exit 1 ;;
  esac
done

if [ -z "$PROVIDER" ] || [ -z "$MODEL_ID" ]; then
  echo "Usage: $0 -Provider <zai|zai-general|nim|groq|openrouter|bai> -ModelId <model-id> [--ctx-length N] [--max-tokens N]" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

. "$SCRIPT_DIR/launcher-api-keys.sh"

# ── Безопасное имя для директории ──
safe_dir_name() {
  echo "$1" | sed 's/[^a-zA-Z0-9._-]/_/g'
}

get_api_key_interactive() {
  local prompt="$1"
  local key=""
  local char=""
  printf "%s" "$prompt"
  while IFS= read -rsn1 char < /dev/tty; do
    if [[ $char == $'\0' ]]; then
      continue
    elif [[ $char == $'\177' || $char == $'\b' ]]; then
      if [ -n "$key" ]; then
        key="${key%?}"
        printf '\b \b'
      fi
    elif [[ $char == $'\n' || $char == '' ]]; then
      printf '\n'
      break
    else
      key+="$char"
      printf '*'
    fi
  done
  echo "$key"
}

get_api_key_with_url() {
  local prompt="$1"
  local url="$2"
  echo -e "\033[33mAPI ключ не задан.\033[0m"
  echo -e "\033[36mПолучить ключ: $url\033[0m"
  local key=""
  local char=""
  printf "%s" "$prompt"
  while IFS= read -rsn1 char < /dev/tty; do
    if [[ $char == $'\0' ]]; then
      continue
    elif [[ $char == $'\177' || $char == $'\b' ]]; then
      if [ -n "$key" ]; then
        key="${key%?}"
        printf '\b \b'
      fi
    elif [[ $char == $'\n' || $char == '' ]]; then
      printf '\n'
      break
    else
      key+="$char"
      printf '*'
    fi
  done
  echo "$key"
}

# ── Определяем API ключ и baseURL ──
API_KEY=""
BASE_URL=""
SESSION_DIR_NAME="$(safe_dir_name "$PROVIDER")-$(safe_dir_name "$MODEL_ID")"

case "$PROVIDER" in
  zai)
    API_KEY="${ZAI_API_KEY:-}"
    if [ -z "$API_KEY" ] || [ "$API_KEY" = "__SET_ME__" ]; then
      API_KEY=$(get_current_api_key "ZAI")
    fi
    if [ -z "$API_KEY" ] || [ "$API_KEY" = "__SET_ME__" ]; then
      API_KEY=$(get_api_key_with_url "Z.AI API key: " "https://console.z.ai/")
    fi
    BASE_URL="https://api.z.ai/api/coding/paas/v4"
    ;;
  zai-general)
    API_KEY="${ZAI_API_KEY:-}"
    if [ -z "$API_KEY" ] || [ "$API_KEY" = "__SET_ME__" ]; then
      API_KEY=$(get_current_api_key "ZAI")
    fi
    if [ -z "$API_KEY" ] || [ "$API_KEY" = "__SET_ME__" ]; then
      API_KEY=$(get_api_key_with_url "Z.AI API key: " "https://console.z.ai/")
    fi
    BASE_URL="https://api.z.ai/api/paas/v4"
    ;;
  nim)
    API_KEY="${NVIDIA_NIM_API_KEY:-}"
    if [ -z "$API_KEY" ]; then
      API_KEY=$(get_current_api_key "NVIDIA_NIM")
    fi
    if [ -z "$API_KEY" ]; then
      API_KEY=$(get_api_key_with_url "NVIDIA NIM API key: " "https://build.nvidia.com/api-key")
    fi
    BASE_URL="https://integrate.api.nvidia.com/v1"
    ;;
  groq)
    API_KEY="${GROQ_API_KEY:-}"
    if [ -z "$API_KEY" ]; then
      API_KEY=$(get_current_api_key "GROQ")
    fi
    if [ -z "$API_KEY" ]; then
      API_KEY=$(get_api_key_with_url "Groq API key: " "https://console.groq.com/keys")
    fi
    BASE_URL="https://api.groq.com/openai/v1"
    ;;
  openrouter)
    API_KEY="${OPENROUTER_API_KEY:-}"
    if [ -z "$API_KEY" ]; then
      API_KEY=$(get_current_api_key "OPENROUTER")
    fi
    if [ -z "$API_KEY" ]; then
      API_KEY=$(get_api_key_with_url "OpenRouter API key: " "https://openrouter.ai/settings/keys")
    fi
    BASE_URL="https://openrouter.ai/api/v1"
    ;;
  bai)
    API_KEY="${BAI_API_KEY:-}"
    if [ -z "$API_KEY" ] || [ "$API_KEY" = "__SET_ME__" ]; then
      API_KEY=$(get_current_api_key "BAI")
    fi
    if [ -z "$API_KEY" ] || [ "$API_KEY" = "__SET_ME__" ]; then
      API_KEY=$(get_api_key_with_url "B.AI API key: " "https://chat.b.ai/key")
    fi
    BASE_URL="https://api.b.ai/v1"
    ;;
  *)
    echo "Unknown provider: $PROVIDER" >&2
    exit 1
    ;;
esac

if [ -z "$API_KEY" ]; then
  echo "API ключ не задан." >&2
  exit 1
fi

# ── Создаём сессионную директорию ──
SESSION_ROOT="$SCRIPT_DIR/../qwen-sessions/_shared"
QWEN_DIR="$SESSION_ROOT/.qwen"
mkdir -p "$QWEN_DIR"

# ── Генерируем settings.json ──
if [ "$PROVIDER" = "zai" ]; then
  cat > "$QWEN_DIR/settings.json" <<SETTINGS_EOF
{
  "modelProviders": {
    "openai": [
      {
        "id": "$MODEL_ID",
        "name": "Z.AI - $MODEL_ID (dynamic)",
        "envKey": "OPENAI_API_KEY",
        "baseUrl": "https://api.z.ai/api/coding/paas/v4",
        "generationConfig": {
          "timeout": 600000,
          "maxRetries": 4,
          "contextWindowSize": 202752,
          "extra_body": {
            "enable_thinking": true,
            "chat_template_kwargs": {
              "enable_thinking": true,
              "clear_thinking": false
            }
          },
          "samplingParams": {
            "temperature": 0.6,
            "top_p": 0.95,
            "max_tokens": 81920
          }
        }
      }
    ]
  },
  "security": { "auth": { "selectedType": "openai" } },
  "model": { "name": "$MODEL_ID" }
}
SETTINGS_EOF
else
  CONTEXT_SIZE=131072
  MAX_TOKENS=81920
  SKIP_STARTUP=""
  if [ "$PROVIDER" = "openrouter" ]; then
    CONTEXT_SIZE=16384
    MAX_TOKENS=8192
    SKIP_STARTUP=',"skipStartupContext":true'
  fi
  if [ "$PROVIDER" = "bai" ]; then
    CONTEXT_SIZE="${CTX_LENGTH_CLI:-131072}"
    MAX_TOKENS="${MAX_TOKENS_CLI:-8192}"
  fi
  cat > "$QWEN_DIR/settings.json" <<SETTINGS_EOF
{
  "modelProviders": {
    "openai": [
      {
        "id": "$MODEL_ID",
        "name": "$PROVIDER - $MODEL_ID (dynamic)",
        "envKey": "OPENAI_API_KEY",
        "baseUrl": "$BASE_URL",
        "generationConfig": {
          "timeout": 600000,
          "maxRetries": 4,
          "contextWindowSize": $CONTEXT_SIZE,
          "samplingParams": {
            "temperature": 0.6,
            "top_p": 0.95,
            "max_tokens": $MAX_TOKENS
          }
        }
      }
    ]
  },
  "security": { "auth": { "selectedType": "openai" } },
  "model": { "name": "$MODEL_ID"$SKIP_STARTUP }
}
SETTINGS_EOF
fi

# ── Экспортируем ключ и лимиты ──
export OPENAI_API_KEY="$API_KEY"
export API_TIMEOUT_MS="600000"
if [ "$PROVIDER" = "openrouter" ]; then
  export QWEN_CODE_MAX_OUTPUT_TOKENS="8192"
  export QWEN_CODE_EMIT_TOOL_USE_SUMMARIES="0"
elif [ "$PROVIDER" = "bai" ]; then
  export QWEN_CODE_MAX_OUTPUT_TOKENS="$MAX_TOKENS"
  export QWEN_CODE_EMIT_TOOL_USE_SUMMARIES="0"
else
  export QWEN_CODE_MAX_OUTPUT_TOKENS="81920"
  export QWEN_CODE_EMIT_TOOL_USE_SUMMARIES="1"
fi

# ── Находим qwen-code ──
QWEN_EXE=""
if command -v qwen-code &>/dev/null; then
  QWEN_EXE="$(command -v qwen-code)"
elif command -v qwen &>/dev/null; then
  QWEN_EXE="$(command -v qwen)"
elif [ -f "$HOME/.npm-global/bin/qwen-code" ]; then
  QWEN_EXE="$HOME/.npm-global/bin/qwen-code"
elif [ -f "$HOME/.local/bin/qwen-code" ]; then
  QWEN_EXE="$HOME/.local/bin/qwen-code"
fi

if [ -z "$QWEN_EXE" ]; then
  echo "Qwen Code CLI не найден. Установите: npm install -g @qwen-code/qwen-code@latest" >&2
  exit 1
fi

# ── Проверка версии Node.js ──
NODE_VERSION=$(node -v 2>/dev/null | sed 's/^v//' | cut -d. -f1)
if [ -z "$NODE_VERSION" ] || [ "$NODE_VERSION" -lt 20 ]; then
  echo -e "\033[31m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
  echo -e "\033[31m  Node.js $(node -v 2>/dev/null || echo 'не найден') — требуется v20+ для RegExp 'v' flag\033[0m"
  echo -e "\033[31m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
  echo ""
  echo -e "\033[33m  Qwen Code требует Node.js >= 20. Текущая версия слишком старая.\033[0m"
  echo ""
  echo -e "\033[36m  Обновите Node.js:\033[0m"
  echo ""
  echo -e "  \033[37m# Вариант 1 — через nvm (рекомендуется):\033[0m"
  echo -e "  \033[37m  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash\033[0m"
  echo -e "  \033[37m  source ~/.bashrc\033[0m"
  echo -e "  \033[37m  nvm install 22\033[0m"
  echo -e "  \033[37m  nvm alias default 22\033[0m"
  echo ""
  echo -e "  \033[37m# Вариант 2 — через NodeSource (Debian/Ubuntu):\033[0m"
  echo -e "  \033[37m  curl -fsSL https://deb.nodesource.com/setup_22.x | bash -\033[0m"
  echo -e "  \033[37m  apt-get install -y nodejs\033[0m"
  echo ""
  echo -e "  \033[37m# После обновления переустановите qwen-code:\033[0m"
  echo -e "  \033[37m  npm install -g @qwen-code/qwen-code@latest\033[0m"
  echo ""
  echo -e "\033[31m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
  exit 1
fi

echo -e "\033[36mQwen Code: $PROVIDER / модель $MODEL_ID → $SESSION_ROOT\033[0m"
cd "$SESSION_ROOT"

# Ensure UTF-8 locale for proper handling of non-ASCII input
export LC_ALL="${LC_ALL:-C.UTF-8}"
export LANG="${LANG:-C.UTF-8}"

exec "$QWEN_EXE"
