#!/bin/bash
# CLI-CODES — Linux/macOS инсталлятор AI-агентов.
# Запуск: curl -fsSL https://raw.githubusercontent.com/chelaxian/CLI-CODES/main/bootstrap.sh | bash
# Или:    git clone https://github.com/chelaxian/CLI-CODES.git && ./CLI-CODES/install.sh
#
# Неинтерактивно:  ./install.sh --agents claude,codex,gemini   |   ./install.sh --all   |   ./install.sh --update
#
# Список агентов и способы установки — в TXT/agents.txt (меню строится из него).

REPO_URL="${REPO_URL:-https://github.com/chelaxian/CLI-CODES.git}"
INSTALL_DIR="${INSTALL_DIR:-$HOME/CLI-CODES}"
MIN_NODE_MAJOR=20
# Рекомендуемый набор: самые популярные агенты + те, что работают с бесплатными провайдерами
RECOMMENDED="claude codex gemini qwen opencode crush copilot kilo openclaude"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'
MAGENTA='\033[0;35m'; GRAY='\033[0;37m'; RESET='\033[0m'

step() { echo -e "\n${CYAN}══════════════════════════════════════════════════════════════════${RESET}\n${MAGENTA}$1${RESET}\n${CYAN}══════════════════════════════════════════════════════════════════${RESET}\n"; }
ok()   { echo -e "${GREEN}  [OK]   $1${RESET}"; }
skip() { echo -e "${YELLOW}  [SKIP] $1${RESET}"; }
warn() { echo -e "${YELLOW}  [WARN] $1${RESET}"; }
err()  { echo -e "${RED}  [ERR]  $1${RESET}" >&2; }
ask()  { local v; read -r -p "$1" v < /dev/tty; printf '%s' "$v"; }
pause() { [ -t 0 ] || [ -e /dev/tty ] && read -r -p "Нажмите Enter для выхода…" _ < /dev/tty; }

# root → напрямую; sudo без пароля → sudo; пароль спрашиваем только если есть терминал
# (/dev/tty, а не stdin: при curl | bash stdin — это pipe). Без терминала (--agents в CI)
# не зависаем на запросе пароля, а уходим в rootless-фоллбэк.
sudo_cmd() {
    if [ "$(id -u)" -eq 0 ]; then "$@"
    elif command -v sudo >/dev/null 2>&1 && { sudo -n true 2>/dev/null || ( : </dev/tty ) 2>/dev/null; }; then sudo "$@"
    else return 1; fi
}

# ─── Системные зависимости ───────────────────────────────────────────────────

detect_pm() {
    for pm in apt-get dnf yum pacman zypper apk brew; do
        command -v "$pm" >/dev/null 2>&1 && { echo "$pm"; return; }
    done
}

node_major() { node --version 2>/dev/null | sed 's/^v//' | cut -d. -f1; }

install_node_lts() {
    local pm; pm="$(detect_pm)"
    echo -e "${CYAN}  Установка Node.js LTS…${RESET}"
    case "$pm" in
        apt-get) curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo_cmd bash - && sudo_cmd apt-get install -y nodejs ;;
        dnf|yum) curl -fsSL https://rpm.nodesource.com/setup_lts.x | sudo_cmd bash - && sudo_cmd "$pm" install -y nodejs ;;
        pacman)  sudo_cmd pacman -S --noconfirm nodejs npm ;;
        zypper)  sudo_cmd zypper install -y nodejs npm ;;
        apk)     sudo_cmd apk add nodejs npm ;;
        brew)    brew install node ;;
    esac
    hash -r
    if [ "$(node_major)" -ge "$MIN_NODE_MAJOR" ] 2>/dev/null; then return 0; fi
    # Fallback без root: n (Node version manager) в ~/.n
    warn "Пакетный менеджер не дал Node.js ≥ $MIN_NODE_MAJOR — ставлю через n в ~/.n"
    export N_PREFIX="$HOME/.n"; mkdir -p "$N_PREFIX/bin"
    curl -fsSL https://raw.githubusercontent.com/tj/n/master/bin/n -o "$N_PREFIX/bin/n" && chmod +x "$N_PREFIX/bin/n" \
        && "$N_PREFIX/bin/n" lts >/dev/null && export PATH="$N_PREFIX/bin:$PATH"
    for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
        [ -f "$rc" ] && ! grep -q 'N_PREFIX' "$rc" && printf '\nexport N_PREFIX="$HOME/.n"\nexport PATH="$N_PREFIX/bin:$PATH"\n' >> "$rc"
    done
    hash -r
}

install_dependencies() {
    step "СИСТЕМНЫЕ ЗАВИСИМОСТИ"
    local missing=() pm cmd
    for cmd in git curl python3; do
        command -v "$cmd" >/dev/null 2>&1 && ok "$cmd → $(command -v "$cmd")" || { echo -e "${YELLOW}  [MISS] $cmd${RESET}"; missing+=("$cmd"); }
    done
    pm="$(detect_pm)"
    if [ ${#missing[@]} -gt 0 ]; then
        [ -n "$pm" ] || { err "Пакетный менеджер не найден. Установите вручную: ${missing[*]}"; return 1; }
        case "$pm" in
            apt-get) sudo_cmd apt-get update -qq; sudo_cmd apt-get install -y "${missing[@]}" ;;
            brew)    brew install "${missing[@]}" ;;
            pacman)  sudo_cmd pacman -S --noconfirm "${missing[@]/python3/python}" ;;
            apk)     sudo_cmd apk add "${missing[@]}" ;;
            *)       sudo_cmd "$pm" install -y "${missing[@]}" ;;
        esac
    fi
    if ! command -v node >/dev/null 2>&1 || [ "$(node_major)" -lt "$MIN_NODE_MAJOR" ] 2>/dev/null; then
        install_node_lts
    fi
    # macOS: системный bash 3.2 слишком стар для TUI-лаунчера (нужен bash ≥ 4)
    if [ "$pm" = "brew" ] && [ ! -x /opt/homebrew/bin/bash ] && [ ! -x /usr/local/bin/bash ]; then
        brew install bash && ok "bash $(brew --prefix)/bin/bash"
    fi
    if command -v node >/dev/null 2>&1 && [ "$(node_major)" -ge "$MIN_NODE_MAJOR" ] 2>/dev/null; then
        ok "node $(node --version), npm $(npm --version 2>/dev/null)"
    else
        err "Node.js ≥ $MIN_NODE_MAJOR недоступен — npm-агенты не установятся"
        return 1
    fi
}

# ─── Репозиторий ─────────────────────────────────────────────────────────────

sync_repo() {
    if [ -d "$INSTALL_DIR/.git" ]; then
        local before after
        before="$(git -C "$INSTALL_DIR" rev-parse --short HEAD 2>/dev/null)"
        # локальные правки (например, в TXT/) не теряем: откладываем в stash, их можно вернуть
        if [ -n "$(git -C "$INSTALL_DIR" status --porcelain --untracked-files=no 2>/dev/null)" ]; then
            git -C "$INSTALL_DIR" stash push -q -m "cli-codes autostash $(date '+%F %R')" 2>/dev/null                 && echo -e "${GRAY}  [INFO] Локальные изменения отложены: git -C $INSTALL_DIR stash list${RESET}"
        fi
        git -C "$INSTALL_DIR" fetch -q origin main 2>/dev/null && git -C "$INSTALL_DIR" reset -q --hard origin/main 2>/dev/null \
            || warn "Не удалось обновить репозиторий, работаю с локальной копией"
        after="$(git -C "$INSTALL_DIR" rev-parse --short HEAD 2>/dev/null)"
        [ "$before" = "$after" ] && ok "Репозиторий актуален ($after)" || ok "Репозиторий обновлён ($before → $after)"
    else
        git clone -q "$REPO_URL" "$INSTALL_DIR" || { err "Ошибка клонирования $REPO_URL"; exit 1; }
        ok "Репозиторий клонирован: $INSTALL_DIR"
    fi
    chmod +x "$INSTALL_DIR"/*.sh "$INSTALL_DIR"/scripts/*.sh "$INSTALL_DIR"/scripts/lib/*.sh 2>/dev/null
}

# ─── Ярлыки и команда cli-codes ──────────────────────────────────────────────

desktop_dir() {
    local d
    command -v xdg-user-dir >/dev/null 2>&1 && d="$(xdg-user-dir DESKTOP 2>/dev/null)"
    for d in "$d" "$HOME/Desktop" "$HOME/Рабочий стол"; do [ -n "$d" ] && [ -d "$d" ] && { echo "$d"; return; }; done
}

install_shortcuts() {
    local bin="$HOME/.local/bin" launcher="$INSTALL_DIR/scripts/run-agent.sh" desk a name
    mkdir -p "$bin"
    chmod +x "$launcher" "$INSTALL_DIR"/scripts/*.sh 2>/dev/null
    ln -sf "$launcher" "$bin/cli-codes"
    ok "Команда cli-codes → $bin/cli-codes"
    for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
        [ -f "$rc" ] && ! grep -q '.local/bin' "$rc" && printf '\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$rc"
    done

    desk="$(desktop_dir)"
    [ -n "$desk" ] || return 0
    for a in $(cc_agent_keys); do
        cc_agent_installed "$a" || continue
        name="$(cc_agent "$a" 2)"
        cat > "$desk/$name.desktop" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=$name
Comment=$(cc_agent "$a" 9)
Exec=bash "$launcher" $a
Terminal=true
Categories=Development;
EOF
        chmod +x "$desk/$name.desktop"
        command -v gio >/dev/null 2>&1 && gio set "$desk/$name.desktop" metadata::trusted true 2>/dev/null
    done
    ok "Ярлыки на рабочем столе: $desk"
}

# ─── Действия ────────────────────────────────────────────────────────────────

install_agents() {  # install_agents key…
    local a ok_n=0 fail_n=0
    step "УСТАНОВКА АГЕНТОВ"
    for a in "$@"; do
        [ -n "$(cc_agent "$a" 2)" ] || { warn "неизвестный агент: $a"; continue; }
        cc_agent_supported "$a" || { skip "$(cc_agent "$a" 2): не поддерживается на этой ОС"; continue; }
        printf '  %-22s ' "$(cc_agent "$a" 2)"
        if cc_agent_install "$a"; then
            echo -e "${GREEN}OK $(cc_agent_version "$a")${RESET}"; ok_n=$((ok_n+1))
        else
            echo -e "${RED}FAIL${RESET}  ($(cc_agent "$a" 4))"; fail_n=$((fail_n+1))
        fi
    done
    echo -e "\n${CYAN}  Установлено: $ok_n, ошибок: $fail_n${RESET}"
}

update_all() {
    step "ОБНОВЛЕНИЕ"
    sync_repo
    local list=() a
    for a in $(cc_agent_keys); do cc_agent_installed "$a" && list+=("$a"); done
    [ ${#list[@]} -gt 0 ] && install_agents "${list[@]}" || skip "Установленных агентов нет"
    if [ -d "$HOME/.free-claude-code/.git" ]; then  # прокси для классического Claude-лаунчера
        git -C "$HOME/.free-claude-code" pull -q 2>/dev/null && command -v uv >/dev/null && (cd "$HOME/.free-claude-code" && uv sync -q 2>/dev/null)
        ok "free-claude-code обновлён"
    fi
    install_shortcuts
}

pick_agents() {  # интерактивный выбор → печатает ключи
    local keys=() i=1 a mark sel n
    for a in $(cc_agent_keys); do keys+=("$a"); done
    echo -e "${CYAN}Номера через пробел/запятую (например: 1 2 5 или 1-6):${RESET}\n" >&2
    for a in "${keys[@]}"; do
        if ! cc_agent_supported "$a"; then mark="${GRAY}n/a${RESET}"
        elif cc_agent_installed "$a"; then mark="${GREEN}✓${RESET}"
        else mark=" "; fi
        printf "  ${YELLOW}%2d${RESET} %b %-20s ${GRAY}%s${RESET}\n" "$i" "$mark" "$(cc_agent "$a" 2)" "$(cc_agent "$a" 9)" >&2
        i=$((i+1))
    done
    sel="$(ask $'\nВыбор: ')"
    for n in $(echo "$sel" | tr ',' ' '); do
        if [[ "$n" =~ ^([0-9]+)-([0-9]+)$ ]]; then
            for ((i=BASH_REMATCH[1]; i<=BASH_REMATCH[2]; i++)); do echo "${keys[$((i-1))]}"; done
        elif [[ "$n" =~ ^[0-9]+$ ]] && [ "$n" -ge 1 ] && [ "$n" -le ${#keys[@]} ]; then
            echo "${keys[$((n-1))]}"
        fi
    done
}

uninstall_all() {
    step "ПОЛНОЕ УДАЛЕНИЕ"
    echo -e "${RED}Будут удалены: установленные через CLI-CODES агенты (npm/uv), $INSTALL_DIR,${RESET}"
    echo -e "${RED}~/.config/cli-codes (ключи и настройки), ~/.cache/cli-codes, ярлыки и команда cli-codes.${RESET}"
    echo -e "${GRAY}Конфиги самих агентов (~/.claude, ~/.codex, …) не трогаем.${RESET}\n"
    [ "$(ask "Введите 'yes' для подтверждения: ")" = "yes" ] || { echo "Отмена."; return; }
    local a desk
    for a in $(cc_agent_keys); do
        cc_agent_installed "$a" && cc_agent_uninstall "$a" && ok "удалён $(cc_agent "$a" 2)"
    done
    desk="$(desktop_dir)"
    for a in $(cc_agent_keys); do [ -n "$desk" ] && rm -f "$desk/$(cc_agent "$a" 2).desktop"; done
    rm -f "$HOME/.local/bin/cli-codes" "$HOME"/{qwen-code,claude-code,opencode,freebuff,openclaude,mimo}.sh
    for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
        [ -f "$rc" ] && sed -i.bak '/# CLI-CODES: API-ключи/d; /cli-codes\/keys.env/d' "$rc" && rm -f "$rc.bak"
    done
    rm -rf "$HOME/.config/cli-codes" "$HOME/.cache/cli-codes" "$INSTALL_DIR"
    ok "Готово. Перезапустите терминал."
}

summary() {
    step "ГОТОВО"
    echo -e "  Запуск:   ${GREEN}cli-codes${RESET}            — меню всех агентов"
    echo -e "            ${GREEN}cli-codes <агент>${RESET}    — например: cli-codes claude, cli-codes codex"
    echo -e "            ${GREEN}cli-codes keys${RESET}       — API-ключи (бесплатные провайдеры: OpenRouter, NIM, Gemini, Zen, Groq…)"
    echo -e "            ${GREEN}cli-codes list${RESET}       — что установлено"
    echo -e "\n${YELLOW}  Если команда cli-codes не находится — откройте новый терминал (PATH обновлён).${RESET}\n"
}

# ─── main ────────────────────────────────────────────────────────────────────

# Если скрипт запущен не из клона (curl | bash) — сначала клонируем/обновляем репозиторий
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd)"
if [ ! -f "$SELF_DIR/scripts/lib/clicodes.sh" ]; then
    command -v git >/dev/null 2>&1 || install_dependencies
    sync_repo
    exec bash "$INSTALL_DIR/install.sh" "$@"
fi
INSTALL_DIR="$SELF_DIR"
. "$INSTALL_DIR/scripts/lib/clicodes.sh"

case "${1:-}" in
    --all)     install_dependencies; install_agents $(cc_agent_keys); install_shortcuts; summary; exit ;;
    --agents)  install_dependencies; install_agents $(echo "${2:-}" | tr ',' ' '); install_shortcuts; summary; exit ;;
    --update)  update_all; summary; exit ;;
    --uninstall) uninstall_all; exit ;;
    -h|--help) sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit ;;
esac

clear
echo -e "${CYAN}════════════════════════════════════════════════════════════════════════════════${RESET}"
if [ -f "$CC_TXT/logos/installer.txt" ]; then
    while IFS= read -r l; do echo -e "${CYAN}$l${RESET}"; done < <(cc_rows "$CC_TXT/logos/installer.txt")
fi
echo -e "${YELLOW}        1-click установка AI-агентов для терминала · $(cc_agent_keys | wc -l | tr -d ' ') агентов · $(cc_provider_keys | wc -l | tr -d ' ') провайдеров${RESET}"
echo -e "${GRAY}        версия: $(git -C "$INSTALL_DIR" rev-parse --short HEAD 2>/dev/null || echo local)${RESET}"
echo -e "${CYAN}════════════════════════════════════════════════════════════════════════════════${RESET}"

while true; do
    step "ЧТО ДЕЛАЕМ?"
    echo -e "  ${YELLOW}[1]${RESET} Рекомендуемый набор  ${GRAY}($RECOMMENDED)${RESET}  ← по умолчанию"
    echo -e "  ${GREEN}[2]${RESET} ВСЕ агенты ($(cc_agent_keys | wc -l | tr -d ' '))"
    echo -e "  ${GREEN}[3]${RESET} Выбрать агентов вручную…"
    echo -e "  ${CYAN}[4]${RESET} Обновить репозиторий и все установленные агенты"
    echo -e "  ${CYAN}[5]${RESET} API-ключи провайдеров (бесплатные: OpenRouter, NIM, Gemini, Zen, Groq, Cerebras…)"
    echo -e "  ${CYAN}[6]${RESET} Пересоздать ярлыки и команду cli-codes"
    echo -e "  ${CYAN}[0]${RESET} Только системные зависимости (git, curl, python3, Node.js ≥ $MIN_NODE_MAJOR)"
    echo -e "  ${RED}[9]${RESET} Полное удаление"
    echo -e "  ${GRAY}[X]${RESET} Выход\n"
    choice="$(ask "Ваш выбор [1]: ")"; choice="$(echo "${choice:-1}" | tr '[:lower:]' '[:upper:]')"
    case "$choice" in
        1) install_dependencies; install_agents $RECOMMENDED; install_shortcuts; summary; break ;;
        2) install_dependencies; install_agents $(cc_agent_keys); install_shortcuts; summary; break ;;
        3) A=($(pick_agents)); [ ${#A[@]} -gt 0 ] || continue
           install_dependencies; install_agents "${A[@]}"; install_shortcuts; summary; break ;;
        4) update_all; summary; break ;;
        5) bash "$INSTALL_DIR/scripts/run-agent.sh" keys ;;
        6) install_shortcuts ;;
        0) install_dependencies ;;
        9) uninstall_all; break ;;
        X|Q) exit 0 ;;
        *) warn "Неверный выбор" ;;
    esac
done
pause
