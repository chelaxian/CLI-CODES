#!/bin/bash
# CLI-CODES — универсальный лаунчер AI-агентов (Linux/macOS).
#
#   cli-codes                     меню выбора агента
#   cli-codes <agent> [args…]     меню агента (провайдер → модель → запуск)
#   cli-codes <agent> --last      быстрый старт с последними настройками без меню
#   cli-codes list                таблица агентов: установлен / версия
#   cli-codes models <provider>   список моделей провайдера (динамически, с fallback)
#   cli-codes keys                управление API-ключами
#   cli-codes install [agent…]    установка/обновление агентов (без аргументов — инсталлятор)
#
# Агенты и провайдеры описаны в TXT/agents.txt и TXT/providers.txt.

# TUI требует bash ≥ 4 (дробные read -t, mapfile). macOS: системный bash 3.2 → перезапуск в brew bash
if [ "${BASH_VERSINFO[0]:-0}" -lt 4 ]; then
    for b in /opt/homebrew/bin/bash /usr/local/bin/bash; do [ -x "$b" ] && exec "$b" "$0" "$@"; done
    echo "Нужен bash ≥ 4. macOS: brew install bash" >&2; exit 1
fi

# ~/.local/bin/cli-codes — симлинк: идём по цепочке ссылок (readlink -f нет в старых macOS)
_self="${BASH_SOURCE[0]}"
while [ -L "$_self" ]; do
    _link="$(readlink "$_self")"
    case "$_link" in /*) _self="$_link" ;; *) _self="$(dirname "$_self")/$_link" ;; esac
done
SCRIPT_DIR="$(cd "$(dirname "$_self")" && pwd)"
. "$SCRIPT_DIR/lib/clicodes.sh"

# ─── Ввод/вывод ──────────────────────────────────────────────────────────────

cc_tui_loaded=""
cc_tui() {  # ленивая загрузка TUI: CLI-подкоманды должны работать и без /dev/tty
    [ -n "$cc_tui_loaded" ] && return
    . "$SCRIPT_DIR/launcher-tui.sh"
    cc_tui_loaded=1
}

menu() {  # menu <brand> <title> <subtitle> items… → 1-based индекс или 0
    cc_tui
    show_tui_numbered_menu "$@"
}

say()   { printf '%b\n' "$*" >&3; }
pause() { printf '%b' "${GRAY}  Enter — продолжить…${RESET}" >&3; IFS= read -r _ < /dev/tty; }

read_line() {  # read_line <prompt> → строка
    local v
    printf '%b' "$1" >&3
    IFS= read -r v < /dev/tty
    printf '%s' "$v"
}

read_secret() {  # ввод со звёздочками; Esc/пусто = отмена
    local key="" ch
    printf '%b' "$1" >&3
    while IFS= read -r -s -n1 ch < /dev/tty; do
        case "$ch" in
            "")          break ;;
            $'\x1b')     key=""; break ;;
            $'\x7f'|$'\b') [ -n "$key" ] && { key="${key%?}"; printf '\b \b' >&3; } ;;
            *)           key+="$ch"; printf '*' >&3 ;;
        esac
    done
    printf '\n' >&3
    printf '%s' "$key"
}

tier_badge() {
    case "$1" in
        free)     echo "FREE" ;;
        freemium) echo "FREE-квота" ;;
        local)    echo "LOCAL" ;;
        *)        echo "PAID" ;;
    esac
}

# ─── Ключи ───────────────────────────────────────────────────────────────────

prompt_key() {  # prompt_key <provider> → 0, если ключ сохранён
    local p="$1" var url key
    var="$(cc_provider "$p" 4)"; url="$(cc_provider "$p" 3)"
    cc_tui; clear >&3
    say "${CYAN}══════════════════════════════════════════════════════════════${RESET}"
    say "${WHITE}  $(cc_provider "$p" 2) — API-ключ ($var)${RESET}"
    say "${CYAN}══════════════════════════════════════════════════════════════${RESET}"
    local cur; cur="$(cc_key_get "$var")"
    [ -n "$cur" ] && say "  Текущий ключ: ${GREEN}$(cc_mask "$cur")${RESET}" || say "  Текущий ключ: ${YELLOW}не задан${RESET}"
    say "  Получить ключ: ${CYAN}$url${RESET}"
    say "  ${GRAY}$(cc_provider "$p" 11)${RESET}"
    say ""
    key="$(read_secret "  Новый ключ (Enter — отмена, «-» — удалить): ")"
    [ -z "$key" ] && return 1
    if [ "$key" = "-" ]; then
        cc_key_set "$var" ""; say "${YELLOW}  Ключ удалён.${RESET}"; pause; return 1
    fi
    cc_key_set "$var" "$key"
    say "${GREEN}  Сохранено в $CC_KEYS_FILE${RESET}"
    return 0
}

keys_menu() {
    local items=() keys=() p var mark choice
    while true; do
        items=(); keys=()
        for p in $(cc_provider_keys); do
            var="$(cc_provider "$p" 4)"; [ -z "$var" ] && continue
            if [ -n "$(cc_key_get "$var")" ]; then mark="✓"; else mark="·"; fi
            items+=("$mark $(cc_provider "$p" 2)  [$(tier_badge "$(cc_provider "$p" 8)")]  $var"); keys+=("$p")
        done
        choice="$(menu "CLI-CODES" "API-ключи провайдеров" "✓ — ключ сохранён · Enter — изменить · Esc — назад" "${items[@]}")"
        [ "${choice:-0}" -eq 0 ] && return
        prompt_key "${keys[$((choice-1))]}" && pause
    done
}

# ─── Выбор провайдера и модели ───────────────────────────────────────────────

pick_provider() {  # pick_provider <agent> → печатает ключ провайдера
    local a="$1" adapter items=() keys=() p status choice
    adapter="$(cc_agent "$a" 6)"
    for p in $(cc_provider_keys); do
        cc_adapter_supports "$adapter" "$p" || continue
        case "$(cc_provider "$p" 7)" in
            none)     status="без ключа" ;;
            optional) status="ключ не обязателен" ;;
            *)        cc_provider_ready "$p" && status="✓ ключ" || status="нет ключа" ;;
        esac
        items+=("$(cc_provider "$p" 2) [$(tier_badge "$(cc_provider "$p" 8)")] · $status — $(cc_provider "$p" 11)")
        keys+=("$p")
    done
    [ ${#keys[@]} -eq 0 ] && return 1
    local sub="Бесплатные и с бесплатной квотой — вверху списка"
    [ "$adapter" = "codex" ] && sub="Codex работает только с провайдерами, поддерживающими Responses API"
    [ "$adapter" = "claude" ] && sub="Нет нативного Anthropic API → автоматически поднимается локальный прокси"
    choice="$(menu "$(cc_agent "$a" 2)" "Провайдер для $(cc_agent "$a" 2)" "$sub" "${items[@]}")"
    [ "${choice:-0}" -eq 0 ] && return 1
    p="${keys[$((choice-1))]}"
    if ! cc_provider_ready "$p"; then
        prompt_key "$p" || return 1
    fi
    printf '%s' "$p"
}

pick_model() {  # pick_model <agent> <provider> → печатает ID модели
    local a="$1" p="$2" filter="" refresh="" choice i n items=() ids=()
    while true; do
        cc_tui
        show_tui_wait_frame "$(cc_agent "$a" 2)" "Загрузка моделей $(cc_provider "$p" 2)…"
        cc_models "$p" $refresh; refresh=""
        items=("✎ Ввести ID модели вручную…" "🔍 Фильтр по названию…${filter:+ (сейчас: $filter)}" "↻ Обновить список из API")
        ids=("" "" "")
        n=${#CC_MODEL_IDS[@]}
        for ((i=0; i<n; i++)); do
            if [ -n "$filter" ] && ! printf '%s %s' "${CC_MODEL_IDS[$i]}" "${CC_MODEL_LABELS[$i]}" | grep -qiF -- "$filter"; then continue; fi
            items+=("${CC_MODEL_LABELS[$i]}  · ${CC_MODEL_IDS[$i]}"); ids+=("${CC_MODEL_IDS[$i]}")
        done
        local src="статический каталог"
        [ "$CC_MODELS_SOURCE" = "api" ] && src="живой список из API"
        [ "$CC_MODELS_SOURCE" = "cache" ] && src="кэш API (до 6 ч)"
        choice="$(menu "$(cc_agent "$a" 2)" "Модель · $(cc_provider "$p" 2)" "$(( ${#ids[@]} - 3 )) моделей · $src · ★ — рекомендуемые" "${items[@]}")"
        case "${choice:-0}" in
            0) return 1 ;;
            1) local m; m="$(read_line "  ID модели: ")"; [ -n "$m" ] && { printf '%s' "$m"; return 0; } ;;
            2) filter="$(read_line "  Подстрока (пусто — сбросить): ")" ;;
            3) refresh=1 ;;
            *) printf '%s' "${ids[$((choice-1))]}"; return 0 ;;
        esac
    done
}

# ─── Меню агента ─────────────────────────────────────────────────────────────

workdir_get() {
    local d; d="$(cat "$CC_STATE_DIR/workdir" 2>/dev/null)"
    [ -n "$d" ] && [ -d "$d" ] && { echo "$d"; return; }
    case "$PWD" in "$CC_ROOT"|"$CC_ROOT"/*) echo "$HOME" ;; *) echo "$PWD" ;; esac
}

run_agent() {  # run_agent <agent> <provider> <model> [args…]
    local a="$1" p="$2" m="$3"; shift 3
    cd "$(workdir_get)" || true
    cc_tui; clear >&3
    if [ -n "$p" ]; then
        cc_state_set "$a" "$p" "$m"
        say "${CYAN}▶ $(cc_agent "$a" 2) · $(cc_provider "$p" 2) · $m${RESET}  ${GRAY}($(pwd))${RESET}"
    else
        say "${CYAN}▶ $(cc_agent "$a" 2)${RESET}  ${GRAY}($(pwd))${RESET}"
    fi
    exec 3>&-
    cc_launch "$a" "$p" "$m" "$@"
    exit $?
}

agent_menu() {
    local a="$1"; shift
    local name adapter legacy last lp lm items=() acts=() choice p m
    name="$(cc_agent "$a" 2)"; adapter="$(cc_agent "$a" 6)"; legacy="$(cc_agent "$a" 7)"
    [ -n "$name" ] || { echo "Неизвестный агент: $a. Список: cli-codes list" >&2; exit 1; }

    if ! cc_agent_installed "$a"; then
        cc_tui
        choice="$(menu "$name" "$name не установлен" "$(cc_agent "$a" 9)" "Установить сейчас" "Отмена")"
        [ "$choice" = "1" ] || exit 0
        clear >&3; say "${CYAN}Установка $name…${RESET}"
        cc_agent_install "$a" && say "${GREEN}  [OK] установлен${RESET}" || { say "${RED}  [ERR] не удалось установить${RESET}"; pause; exit 1; }
    fi

    if [ "${1:-}" = "--last" ]; then
        shift
        last="$(cc_state_get "$a")"
        run_agent "$a" "${last%%|*}" "${last#*|}" "$@"
    fi

    while true; do
        items=(); acts=()
        last="$(cc_state_get "$a")"; lp="${last%%|*}"; lm="${last#*|}"
        if [ "$adapter" = "env" ]; then
            items+=("▶ Запустить $name"); acts+=("run")
        else
            if [ -n "$last" ] && [ -n "$(cc_provider "$lp" 2)" ]; then
                items+=("▶ Быстрый старт: $(cc_provider "$lp" 2) · $lm"); acts+=("last")
            fi
            items+=("Выбрать провайдера и модель…"); acts+=("pick")
            items+=("Нативный запуск ($name со своим логином/конфигом)"); acts+=("run")
        fi
        if [ -n "$legacy" ] && [ -f "$SCRIPT_DIR/$legacy.sh" ]; then
            items+=("Классический лаунчер (пресеты прошлых версий)"); acts+=("legacy")
        fi
        items+=("API-ключи провайдеров…"); acts+=("keys")
        items+=("Рабочая папка: $(workdir_get)"); acts+=("workdir")
        items+=("Обновить $name"); acts+=("update")

        choice="$(menu "$name" "$name" "$(cc_agent "$a" 9)" "${items[@]}")"
        [ "${choice:-0}" -eq 0 ] && return 0
        case "${acts[$((choice-1))]}" in
            last)   run_agent "$a" "$lp" "$lm" "$@" ;;
            pick)   p="$(pick_provider "$a")" || continue
                    m="$(pick_model "$a" "$p")" || continue
                    run_agent "$a" "$p" "$m" "$@" ;;
            run)    run_agent "$a" "" "" "$@" ;;
            legacy) exec 3>&-; exec bash "$SCRIPT_DIR/$legacy.sh" "$@" ;;
            keys)   keys_menu ;;
            workdir)
                local d; d="$(read_line "  Папка проекта (пусто — текущая): ")"
                mkdir -p "$CC_STATE_DIR"
                if [ -z "$d" ]; then rm -f "$CC_STATE_DIR/workdir"
                elif [ -d "${d/#\~/$HOME}" ]; then (cd "${d/#\~/$HOME}" && pwd) > "$CC_STATE_DIR/workdir"
                else say "${RED}  Нет такой папки: $d${RESET}"; pause; fi ;;
            update) clear >&3; say "${CYAN}Обновление $name…${RESET}"
                    cc_agent_install "$a" && say "${GREEN}  [OK] $(cc_agent_version "$a")${RESET}" || say "${RED}  [ERR] обновление не удалось${RESET}"
                    pause ;;
        esac
    done
}

main_menu() {
    local items=() keys=() a choice
    while true; do
        items=(); keys=()
        for a in $(cc_agent_keys); do
            cc_agent_installed "$a" || continue
            items+=("$(cc_agent "$a" 2) — $(cc_agent "$a" 9)"); keys+=("$a")
        done
        items+=("＋ Установить / обновить агентов…" "API-ключи провайдеров…")
        choice="$(menu "CLI-CODES" "Выберите AI-агента" "Установлено агентов: ${#keys[@]}" "${items[@]}")"
        [ "${choice:-0}" -eq 0 ] && exit 0
        if [ "$choice" -le "${#keys[@]}" ]; then
            agent_menu "${keys[$((choice-1))]}"
        elif [ "$choice" -eq $(( ${#keys[@]} + 1 )) ]; then
            exec 3>&-; exec bash "$CC_ROOT/install.sh"
        else
            keys_menu
        fi
    done
}

# ─── CLI ─────────────────────────────────────────────────────────────────────

case "${1:-}" in
    "")       main_menu ;;
    -h|--help|help) sed -n '2,12p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' ;;
    list)
        printf '%-12s %-22s %-10s %s\n' KEY NAME STATUS VERSION
        for a in $(cc_agent_keys); do
            if ! cc_agent_supported "$a"; then s="n/a"; v=""
            elif cc_agent_installed "$a"; then s="installed"; v="$(cc_agent_version "$a")"
            else s="-"; v=""; fi
            printf '%-12s %-22s %-10s %s\n' "$a" "$(cc_agent "$a" 2)" "$s" "$v"
        done ;;
    models)
        [ -n "${2:-}" ] || { echo "Использование: cli-codes models <provider> [--refresh]" >&2; exit 1; }
        cc_keys_load
        cc_models "$2" "${3:+1}"
        echo "# $(cc_provider "$2" 2): ${#CC_MODEL_IDS[@]} моделей (источник: $CC_MODELS_SOURCE)" >&2
        for i in "${!CC_MODEL_IDS[@]}"; do printf '%s\t%s\n' "${CC_MODEL_IDS[$i]}" "${CC_MODEL_LABELS[$i]}"; done ;;
    providers)
        for p in $(cc_provider_keys); do
            cc_provider_ready "$p" && k="ready" || k="no-key"
            printf '%-13s %-9s %-7s %s\n' "$p" "$(tier_badge "$(cc_provider "$p" 8)")" "$k" "$(cc_provider "$p" 2)"
        done ;;
    keys)     cc_tui; keys_menu ;;
    install)
        shift
        [ $# -eq 0 ] && exec bash "$CC_ROOT/install.sh"
        for a in "$@"; do
            printf '%s… ' "$(cc_agent "$a" 2)"
            cc_agent_install "$a" && echo "OK $(cc_agent_version "$a")" || echo "FAIL"
        done ;;
    *)        a="$1"; shift; cc_tui; agent_menu "$a" "$@" ;;
esac
