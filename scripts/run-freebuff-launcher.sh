#!/bin/bash
# Freebuff launcher (Linux/macOS) — direct launch without TUI menu.
# Reason: Freebuff's built-in interactive picker breaks when preceded by our
# TUI launcher. So we hand control directly to Freebuff CLI.

set -e

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

freebuff_exe="$(resolve_freebuff_exe)" || true
if [ -z "$freebuff_exe" ]; then
    echo "Freebuff CLI не найден. Установите: npm install -g freebuff" >&2
    exit 1
fi

if [ -r /proc/cpuinfo ] && ! grep -qi 'avx2' /proc/cpuinfo; then
    echo "Freebuff binary несовместим с этим CPU/VM: нет AVX2." >&2
    echo "Нужен хост/тариф с AVX2 или сборка Freebuff без AVX2 от авторов." >&2
    exit 1
fi

export CODEBUFF_AUTO_UPDATE_DISABLED=1
export CODEBUFF_SKIP_UPDATE=1
export FREEBUFF_SKIP_UPDATE=1
export NPM_CONFIG_UPDATE_NOTIFIER=false
export NPM_CONFIG_FUND=false

exec "$freebuff_exe"
