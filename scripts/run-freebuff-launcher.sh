#!/bin/bash
# Freebuff launcher (Linux/macOS)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/launcher-tui.sh"

resolve_freebuff_exe() {
    if command -v freebuff >/dev/null 2>&1; then
        command -v freebuff
        return 0
    fi
    local npm_prefix
    npm_prefix="$(npm prefix -g 2>/dev/null || true)"
    if [ -n "$npm_prefix" ] && [ -x "$npm_prefix/bin/freebuff" ]; then
        echo "$npm_prefix/bin/freebuff"
        return 0
    fi
    return 1
}

main() {
    local items=(
        "DeepSeek V4 Pro - smartest (основной agent)"
        "DeepSeek V4 Flash - most efficient (основной agent)"
        "GPT-5.4 - deep thinking (нужна подписка ChatGPT)"
        "Запустить Freebuff с встроенным выбором модели"
    )

    local choice
    choice="$(show_tui_numbered_menu "Freebuff" "Freebuff - выбор модели" "DeepSeek V4 Pro/Flash (main) · GPT-5.4 (deep thinking)" "${items[@]}")"
    if [ "${choice:-0}" -eq 0 ]; then
        echo -e "${YELLOW}Отменено.${RESET}"
        exit 0
    fi

    local freebuff_exe
    freebuff_exe="$(resolve_freebuff_exe)" || true
    if [ -z "$freebuff_exe" ]; then
        echo -e "${RED}Freebuff CLI не найден. Установите: npm install -g freebuff${RESET}"
        exit 1
    fi

    if [ -r /proc/cpuinfo ] && ! grep -qi 'avx2' /proc/cpuinfo; then
        echo -e "${RED}Freebuff binary несовместим с этим CPU/VM: нет AVX2.${RESET}"
        echo -e "${YELLOW}Это означает SIGILL: бинарник выполняет инструкцию, которую процессор не поддерживает.${RESET}"
        echo -e "${GRAY}Нужен хост/тариф с AVX2 или сборка Freebuff без AVX2 от авторов.${RESET}"
        exit 1
    fi

    local model_id=""
    case "$choice" in
        1) model_id="deepseek-v4-pro" ;;
        2) model_id="deepseek-v4-flash" ;;
        3) model_id="gpt-5.4" ;;
        *) model_id="" ;;
    esac

    # Подавляем авто-обновление freebuff/codebuff. ECONNRESET при старте обычно
    # означает попытку скачать обновление агентов/моделей.
    export CODEBUFF_AUTO_UPDATE_DISABLED=1
    export CODEBUFF_SKIP_UPDATE=1
    export FREEBUFF_SKIP_UPDATE=1
    export NPM_CONFIG_UPDATE_NOTIFIER=true
    export NPM_CONFIG_FUND=false

    if [ -n "$model_id" ]; then
        export FREEBUFF_MODEL="$model_id"
    else
        unset FREEBUFF_MODEL
    fi

    # Обёртка с retry для сетевых ошибок (ECONNRESET и подобных).
    local max_retries=2
    local attempt=0
    local exit_code=0
    while [ $attempt -lt $max_retries ]; do
        attempt=$((attempt + 1))
        clear >&3
        echo -e "${CYAN}Запуск Freebuff (попытка $attempt/$max_retries)…${RESET}" >&3
        if [ -n "${FREEBUFF_MODEL:-}" ]; then
            echo -e "${GRAY}Предпочтительная модель: ${FREEBUFF_MODEL}${RESET}" >&3
            echo -e "${GRAY}Freebuff автоматически выбирает модель под задачу. Если FREEBUFF_MODEL игнорируется — используйте встроенный выбор.${RESET}" >&3
        fi
        echo "" >&3
        "$freebuff_exe"
        exit_code=$?
        if [ $exit_code -eq 0 ]; then
            exit 0
        fi
        if [ $attempt -lt $max_retries ]; then
            echo "" >&3
            echo -e "${YELLOW}Freebuff завершился с кодом $exit_code. Повторная попытка через 3 секунды…${RESET}" >&3
            sleep 3
        fi
    done

    echo "" >&3
    echo -e "${YELLOW}Freebuff завершился с кодом $exit_code.${RESET}" >&3
    echo -e "${YELLOW}Если была сетевая ошибка (ECONNRESET/timeout) — проверьте интернет и попробуйте снова.${RESET}" >&3
    echo -e "${GRAY}Помочь может ручное обновление: npm i -g freebuff@latest${RESET}" >&3
    exit $exit_code
}

main "$@"
