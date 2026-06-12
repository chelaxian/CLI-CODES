#!/bin/bash
# MiMo Code launcher (Linux/macOS) — direct launch without TUI menu.

set -e

resolve_mimo_exe() {
    if command -v mimo >/dev/null 2>&1; then
        command -v mimo
        return 0
    fi
    if [ -x "$HOME/.mimocode/bin/mimo" ]; then
        echo "$HOME/.mimocode/bin/mimo"
        return 0
    fi
    local npm_prefix
    npm_prefix="$(npm prefix -g 2>/dev/null || true)"
    if [ -n "$npm_prefix" ] && [ -x "$npm_prefix/bin/mimo" ]; then
        echo "$npm_prefix/bin/mimo"
        return 0
    fi
    return 1
}

mimo_exe="$(resolve_mimo_exe)" || true
if [ -z "$mimo_exe" ]; then
    echo "MiMo Code CLI не найден. Установите: npm install -g @mimo-ai/cli" >&2
    echo "Или: curl -fsSL https://mimo.xiaomi.com/install | bash" >&2
    exit 1
fi

exec "$mimo_exe"
