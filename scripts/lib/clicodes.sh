#!/bin/bash
# clicodes.sh — общее ядро CLI-CODES для Linux/macOS (source-only).
#
#   * реестры TXT/agents.txt и TXT/providers.txt
#   * хранилище API-ключей  (~/.config/cli-codes/keys.env, chmod 600)
#   * динамический каталог моделей с кэшем и статическим fallback (TXT/models/<provider>.txt)
#   * установка агентов (npm / uv / curl-скрипты)
#   * адаптеры запуска: как передать выбранные провайдер+модель конкретному агенту
#
# Windows-аналог: scripts/lib/clicodes.ps1 (тот же формат реестров и state).

CC_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CC_ROOT="$(cd "$CC_LIB_DIR/../.." && pwd)"
CC_TXT="$CC_ROOT/TXT"
CC_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/cli-codes"
CC_KEYS_FILE="$CC_CONFIG_DIR/keys.env"
CC_STATE_DIR="$CC_CONFIG_DIR/state"
CC_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/cli-codes"
CC_MODELS_TTL="${CC_MODELS_TTL:-21600}"   # 6 часов

case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac
# Без UTF-8 локали bash считает ${#str} в байтах, и рамки TUI с кириллицей «разъезжаются»
case "${LC_ALL:-${LANG:-}}" in *[Uu][Tt][Ff]-8*|*[Uu][Tt][Ff]8*) ;; *) export LANG=C.UTF-8 ;; esac

# ─── Реестры ─────────────────────────────────────────────────────────────────

cc_rows() {  # печатает значимые строки файла (без комментариев, пустых строк и CR)
    [ -f "$1" ] || return 1
    tr -d '\r' < "$1" | grep -v '^[[:space:]]*#' | grep -v '^[[:space:]]*$'
}

# cc_field <file> <key> <n> — n-я колонка строки с ключом key ("-" превращается в пустую строку)
cc_field() {
    cc_rows "$1" | awk -F'|' -v k="$2" -v n="$3" '
        { gsub(/^[ \t]+|[ \t]+$/, "", $1) }
        $1 == k { v = $n; gsub(/^[ \t]+|[ \t]+$/, "", v); if (v == "-") v = ""; print v; exit }'
}

cc_agent_keys()    { cc_rows "$CC_TXT/agents.txt"    | cut -d'|' -f1 | tr -d ' '; }
cc_provider_keys() { cc_rows "$CC_TXT/providers.txt" | cut -d'|' -f1 | tr -d ' '; }

# Агент:     1 key | 2 name | 3 cmd | 4 linux | 5 windows | 6 adapter | 7 legacy | 8 url | 9 desc
cc_agent()    { cc_field "$CC_TXT/agents.txt" "$1" "$2"; }
# Провайдер: 1 key | 2 name | 3 key-url | 4 env | 5 base | 6 models-url | 7 auth | 8 tier | 9 anthropic | 10 responses | 11 note
cc_provider() { cc_field "$CC_TXT/providers.txt" "$1" "$2"; }

cc_python() {
    if command -v python3 >/dev/null 2>&1; then echo python3
    elif command -v python >/dev/null 2>&1; then echo python
    else return 1; fi
}

# ─── API-ключи ───────────────────────────────────────────────────────────────

cc_key_get() {  # <ENV_VAR> → значение ключа или пусто
    local var="$1" val=""
    [ -n "$var" ] || return 0
    val="${!var:-}"
    if [ -z "$val" ] && [ -f "$CC_KEYS_FILE" ]; then
        val="$(grep "^export $var=" "$CC_KEYS_FILE" 2>/dev/null | tail -1 | sed "s/^export $var=//; s/^['\"]//; s/['\"]\$//")"
    fi
    if [ -z "$val" ]; then  # ключи, сохранённые старыми версиями в ~/.bashrc / ~/.zshrc
        local rc
        for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
            [ -f "$rc" ] || continue
            val="$(grep "^export $var=" "$rc" 2>/dev/null | tail -1 | cut -d'"' -f2)"
            [ -n "$val" ] && break
        done
    fi
    [ "$val" = "__SET_ME__" ] && val=""
    printf '%s' "$val" | tr -d '[:space:]'
}

cc_key_set() {  # <ENV_VAR> <value>  (пустое value = удалить ключ)
    local var="$1" val="$2" rc tmp
    mkdir -p "$CC_CONFIG_DIR"
    touch "$CC_KEYS_FILE" && chmod 600 "$CC_KEYS_FILE"
    tmp="$(grep -v "^export $var=" "$CC_KEYS_FILE" 2>/dev/null)"
    printf '%s\n' "$tmp" | grep -v '^$' > "$CC_KEYS_FILE"
    if [ -n "$val" ]; then
        # одинарные кавычки: значение не интерпретируется shell'ом при source
        printf "export %s='%s'\n" "$var" "${val//\'/}" >> "$CC_KEYS_FILE"
        export "$var=$val"
    else
        unset "$var"
    fi
    for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
        [ -f "$rc" ] || continue
        sed -i.bak "/^export $var=/d" "$rc" 2>/dev/null && rm -f "$rc.bak"
        grep -q 'cli-codes/keys.env' "$rc" 2>/dev/null || \
            printf '\n# CLI-CODES: API-ключи провайдеров\n[ -f "%s" ] && . "%s"\n' "$CC_KEYS_FILE" "$CC_KEYS_FILE" >> "$rc"
    done
}

cc_keys_load() {  # экспортирует все сохранённые ключи в текущее окружение
    [ -f "$CC_KEYS_FILE" ] && { set -a; . "$CC_KEYS_FILE"; set +a; }
    local p var val
    for p in $(cc_provider_keys); do
        var="$(cc_provider "$p" 4)"
        [ -n "$var" ] && [ -z "${!var:-}" ] && { val="$(cc_key_get "$var")"; [ -n "$val" ] && export "$var=$val"; }
    done
    return 0
}

cc_provider_key() { cc_key_get "$(cc_provider "$1" 4)"; }

cc_provider_ready() {  # провайдер можно использовать прямо сейчас (ключ есть или не нужен)
    case "$(cc_provider "$1" 7)" in
        none|optional) return 0 ;;
        *) [ -n "$(cc_provider_key "$1")" ] ;;
    esac
}

cc_mask() { local k="$1"; [ ${#k} -gt 12 ] && echo "${k:0:6}…${k: -4}" || echo "***"; }

# ─── Каталог моделей ─────────────────────────────────────────────────────────

cc_models_fetch() {  # <provider> → "id|label" из API (stdout), код 1 при ошибке
    local p="$1" url key py
    url="$(cc_provider "$p" 6)"
    [ "$url" = "none" ] && return 1
    [ -z "$url" ] && url="$(cc_provider "$p" 5)/models"
    key="$(cc_provider_key "$p")"
    py="$(cc_python)" || return 1
    # заголовок с ключом передаём через stdin (--config -), а не в argv: иначе ключ виден в ps
    { [ -n "$key" ] && printf 'header = "Authorization: Bearer %s"
' "$key"; } |
        curl -fsSL --max-time 20 -H "Accept: application/json" --config - "$url" 2>/dev/null |
        "$py" "$CC_LIB_DIR/models.py" "$p"
}

# cc_models <provider> [refresh] — заполняет массивы CC_MODEL_IDS / CC_MODEL_LABELS
# и переменную CC_MODELS_SOURCE (api|cache|static).
# Порядок: сначала «рекомендуемые» из TXT/models/<provider>.txt, затем остальные из API.
cc_models() {
    local p="$1" refresh="${2:-}" cache="$CC_CACHE_DIR/models/$1.txt" dyn="" line id
    CC_MODEL_IDS=(); CC_MODEL_LABELS=(); CC_MODELS_SOURCE="static"
    mkdir -p "$CC_CACHE_DIR/models"

    if [ -z "$refresh" ] && [ -s "$cache" ] && \
       [ $(( $(date +%s) - $(stat -c %Y "$cache" 2>/dev/null || stat -f %m "$cache" 2>/dev/null || echo 0) )) -lt "$CC_MODELS_TTL" ]; then
        dyn="$(cat "$cache")"; CC_MODELS_SOURCE="cache"
    elif dyn="$(cc_models_fetch "$p")" && [ -n "$dyn" ]; then
        printf '%s\n' "$dyn" > "$cache"; CC_MODELS_SOURCE="api"
    elif [ -s "$cache" ]; then
        dyn="$(cat "$cache")"; CC_MODELS_SOURCE="cache"
    fi

    local seen=$'
'   # список уже добавленных id (без declare -A: совместимо с bash 3.2)
    while IFS='|' read -r id label; do
        [ -n "$id" ] || continue
        # если API доступно, рекомендуемые модели, которых там уже нет, не показываем
        if [ -n "$dyn" ] && ! grep -qxF -- "$id" <(printf '%s\n' "$dyn" | cut -d'|' -f1); then continue; fi
        seen+="$id"$'
'; CC_MODEL_IDS+=("$id"); CC_MODEL_LABELS+=("★ ${label:-$id}")
    done < <(cc_rows "$CC_TXT/models/$p.txt")
    while IFS= read -r line; do
        id="${line%%|*}"
        [ -n "$id" ] || continue
        case "$seen" in *$'
'"$id"$'
'*) continue ;; esac
        seen+="$id"$'
'; CC_MODEL_IDS+=("$id"); CC_MODEL_LABELS+=("${line#*|}")
    done <<< "$dyn"
}

# ─── State (последний выбор для каждого агента) ─────────────────────────────

cc_state_get() { [ -f "$CC_STATE_DIR/$1" ] && head -1 "$CC_STATE_DIR/$1"; }  # → provider|model
cc_state_set() { mkdir -p "$CC_STATE_DIR"; printf '%s|%s\n' "$2" "$3" > "$CC_STATE_DIR/$1"; }

# ─── Установка агентов ───────────────────────────────────────────────────────

cc_agent_installed() { local c; c="$(cc_agent "$1" 3)"; [ -n "$c" ] && command -v "$c" >/dev/null 2>&1; }

cc_agent_supported() { [ -n "$(cc_agent "$1" 4)" ]; }

cc_ensure_uv() {
    command -v uv >/dev/null 2>&1 && return 0
    echo "  → установка uv (менеджер Python-инструментов)…"
    curl -LsSf https://astral.sh/uv/install.sh | sh >/dev/null 2>&1
    hash -r; command -v uv >/dev/null 2>&1
}

# sudo только когда он не зависнет: root, sudo без пароля или есть терминал для ввода пароля.
# Без терминала (CI, --agents из скрипта) возвращаем ошибку вместо вечного ожидания пароля.
cc_sudo() {
    if [ "$(id -u)" -eq 0 ]; then "$@"
    elif command -v sudo >/dev/null 2>&1 && { sudo -n true 2>/dev/null || ( : </dev/tty ) 2>/dev/null; }; then sudo "$@"
    else return 1; fi
}

cc_npm_global() {  # npm install -g с fallback на sudo при EACCES (системный Node.js)
    command -v npm >/dev/null 2>&1 || { echo "npm не найден (нужен Node.js)" >&2; return 1; }
    npm install -g "$@" >/dev/null 2>&1 && return 0
    [ "$(id -u)" -ne 0 ] && cc_sudo npm install -g "$@" >/dev/null 2>&1
}

cc_agent_install() {  # <agent> — установка или обновление до latest
    local a="$1" spec kind target
    spec="$(cc_agent "$a" 4)"
    [ -n "$spec" ] || { echo "  [SKIP] $(cc_agent "$a" 2): не поддерживается на этой ОС"; return 2; }
    kind="${spec%%:*}"; target="${spec#*:}"
    case "$kind" in
        npm) cc_npm_global "${target}@latest" ;;
        uv)  cc_ensure_uv && case "$target" in
                 aider-chat) uv tool install --force --python 3.12 aider-chat >/dev/null 2>&1 ;;
                 *)          uv tool install --force $target >/dev/null 2>&1 ;;
             esac ;;
        sh)  # таймауты: зависшая сеть не должна вешать весь инсталлятор
             local script; script="$(curl -fsSL --connect-timeout 20 --max-time 120 "$target")" || {
                 echo "  [ERR] не удалось скачать $target" >&2; return 1; }
             case "$a" in
                 goose) CONFIGURE=false bash -c "$script" >/dev/null 2>&1 ;;
                 *)     bash -c "$script" ;;
             esac ;;
        *)   echo "  [ERR] неизвестный способ установки: $spec"; return 1 ;;
    esac
    hash -r
    cc_agent_installed "$a"
}

cc_agent_uninstall() {
    local a="$1" spec kind target
    spec="$(cc_agent "$a" 4)"; kind="${spec%%:*}"; target="${spec#*:}"
    case "$kind" in
        npm) npm uninstall -g "$target" >/dev/null 2>&1 || cc_sudo npm uninstall -g "$target" >/dev/null 2>&1 ;;
        uv)  command -v uv >/dev/null && uv tool uninstall "${target%% *}" >/dev/null 2>&1 ;;
        *)   return 2 ;;  # curl-установщики удаляются средствами самого агента
    esac
}

cc_agent_version() {  # быстрая версия без запуска тяжёлых бинарей
    local a="$1" spec target v
    spec="$(cc_agent "$a" 4)"; target="${spec#*:}"
    if [ "${spec%%:*}" = "npm" ]; then
        v="$(npm ls -g "$target" --depth=0 2>/dev/null | grep -o "$target@[^ ]*" | head -1)"
        [ -n "$v" ] && { echo "${v##*@}"; return; }
    fi
    local to=""; command -v timeout >/dev/null 2>&1 && to="timeout 5"   # в macOS нет timeout
    cc_agent_installed "$a" && $to "$(cc_agent "$a" 3)" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1
}

# ─── Адаптеры запуска ────────────────────────────────────────────────────────

# Может ли адаптер агента работать с провайдером
cc_adapter_supports() {  # <adapter> <provider>
    case "$1" in
        env)    return 1 ;;
        gemini) [ "$2" = "gemini" ] ;;
        codex)  [ "$(cc_provider "$2" 10)" = "yes" ] ;;
        claude) [ -n "$(cc_provider "$2" 9)" ] || cc_python >/dev/null ;;  # иначе нужен python для прокси
        *)      return 0 ;;
    esac
}

CC_PROXY_PID=""
cc_proxy_start() {  # <base-url> <key> <model> → CC_PROXY_PORT, CC_PROXY_TOKEN
    local py port i
    py="$(cc_python)" || { echo "Нужен python3 для прокси Anthropic→OpenAI" >&2; return 1; }
    port="$("$py" -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1])')"
    # одноразовый токен: без него прокси не примет запросы от других локальных процессов
    CC_PROXY_TOKEN="$("$py" -c 'import secrets;print(secrets.token_hex(24))')"
    mkdir -p "$CC_CACHE_DIR"
    UPSTREAM_BASE_URL="$1" UPSTREAM_API_KEY="$2" UPSTREAM_MODEL="$3" PROXY_TOKEN="$CC_PROXY_TOKEN" PROXY_LOG="$CC_CACHE_DIR/anthropic-proxy.log" \
        "$py" "$CC_LIB_DIR/anthropic-proxy.py" "$port" >/dev/null 2>&1 &
    CC_PROXY_PID=$!
    trap '[ -n "$CC_PROXY_PID" ] && kill "$CC_PROXY_PID" 2>/dev/null' EXIT  # и при Ctrl+C
    for _ in $(seq 1 50); do
        curl -fs "http://127.0.0.1:$port/" >/dev/null 2>&1 && { CC_PROXY_PORT="$port"; return 0; }
        sleep 0.1
    done
    kill "$CC_PROXY_PID" 2>/dev/null; CC_PROXY_PID=""
    echo "Прокси не стартовал, см. $CC_CACHE_DIR/anthropic-proxy.log" >&2
    return 1
}

# cc_launch <agent> <provider> <model> [аргументы агента…]
cc_launch() {
    local a="$1" p="$2" m="$3"; shift 3
    local cmd adapter base key anth
    cmd="$(cc_agent "$a" 3)"; adapter="$(cc_agent "$a" 6)"
    command -v "$cmd" >/dev/null 2>&1 || { echo "$(cc_agent "$a" 2) не установлен (команда $cmd). Запустите инсталлятор." >&2; return 127; }
    cc_keys_load

    if [ "$adapter" = "env" ] || [ -z "$p" ]; then
        "$cmd" "$@"; return $?
    fi
    base="$(cc_provider "$p" 5)"; key="$(cc_provider_key "$p")"
    [ -z "$key" ] && [ "$(cc_provider "$p" 7)" != "key" ] && key="cli-codes"

    case "$adapter" in
        claude)
            anth="$(cc_provider "$p" 9)"
            unset ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN ANTHROPIC_BASE_URL \
                  CLAUDE_CODE_USE_BEDROCK CLAUDE_CODE_USE_VERTEX CLAUDE_CODE_USE_FOUNDRY
            if [ "$p" = "anthropic" ]; then
                export ANTHROPIC_API_KEY="$key"
            elif [ -n "$anth" ]; then
                export ANTHROPIC_BASE_URL="$anth" ANTHROPIC_AUTH_TOKEN="$key"
            else
                cc_proxy_start "$base" "$key" "$m" || return 1
                export ANTHROPIC_BASE_URL="http://127.0.0.1:$CC_PROXY_PORT" ANTHROPIC_AUTH_TOKEN="$CC_PROXY_TOKEN"
            fi
            export ANTHROPIC_MODEL="$m"
            if [ "$p" != "anthropic" ]; then
                # все «слоты» Claude Code (opus/sonnet/haiku/субагенты) → выбранная модель
                export ANTHROPIC_DEFAULT_OPUS_MODEL="$m" ANTHROPIC_DEFAULT_FABLE_MODEL="$m" ANTHROPIC_DEFAULT_SONNET_MODEL="$m" \
                       ANTHROPIC_DEFAULT_HAIKU_MODEL="$m" CLAUDE_CODE_SUBAGENT_MODEL="$m" \
                       CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 API_TIMEOUT_MS=600000
            fi
            "$cmd" "$@"
            ;;
        openclaude)
            export CLAUDE_CODE_USE_OPENAI=1 OPENAI_BASE_URL="$base" OPENAI_API_KEY="$key" OPENAI_MODEL="$m"
            "$cmd" "$@"
            ;;
        qwen)
            export OPENAI_API_KEY="$key"
            "$cmd" --auth-type openai --openai-base-url "$base" -m "$m" "$@"
            ;;
        opencode)
            local cfg="$CC_STATE_DIR/opencode.json"
            mkdir -p "$CC_STATE_DIR"
            export CC_OPENCODE_API_KEY="$key"
            # ключ не пишется в файл: opencode подставляет {env:VAR} сам
            cat > "$cfg" <<EOF
{
  "\$schema": "https://opencode.ai/config.json",
  "provider": {
    "cc": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "$(cc_provider "$p" 2)",
      "options": { "baseURL": "$base", "apiKey": "{env:CC_OPENCODE_API_KEY}" },
      "models": { "$m": { "name": "$m" } }
    }
  },
  "model": "cc/$m"
}
EOF
            OPENCODE_CONFIG="$cfg" "$cmd" "$@"
            ;;
        codex)
            if [ "$p" = "openai" ]; then
                OPENAI_API_KEY="$key" "$cmd" -m "$m" "$@"
            else
                export CC_CODEX_API_KEY="$key"
                "$cmd" -c "model_provider='cc'" \
                    -c "model_providers.cc={ name = '$(cc_provider "$p" 2)', base_url = '$base', env_key = 'CC_CODEX_API_KEY', wire_api = 'responses' }" \
                    -m "$m" "$@"
            fi
            ;;
        gemini)
            GEMINI_API_KEY="$key" "$cmd" -m "$m" "$@"
            ;;
        aider)
            OPENAI_API_BASE="$base" OPENAI_API_KEY="$key" "$cmd" --model "openai/$m" "$@"
            ;;
        goose)
            # goose хочет хост и путь раздельно: https://host[:port] + v1/chat/completions
            local rest="${base#*://}" path=""
            [[ "$rest" == */* ]] && path="${rest#*/}/"
            GOOSE_PROVIDER=openai OPENAI_HOST="${base%%://*}://${rest%%/*}" OPENAI_BASE_PATH="${path}chat/completions" \
                OPENAI_API_KEY="$key" GOOSE_MODEL="$m" "$cmd" session "$@"
            ;;
        *)
            "$cmd" "$@"
            ;;
    esac
    local rc=$?
    [ -n "$CC_PROXY_PID" ] && kill "$CC_PROXY_PID" 2>/dev/null
    return $rc
}
