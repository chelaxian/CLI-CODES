#!/bin/bash
# CLI-CODES — Linux/macOS инсталлятор
# Запуск: curl -fsSL https://raw.githubusercontent.com/chelaxian/CLI-CODES/main/install.sh | bash
# Или: git clone + ./install.sh

set -e

REPO_URL="${REPO_URL:-https://github.com/chelaxian/CLI-CODES.git}"
INSTALL_DIR="${INSTALL_DIR:-$HOME/CLI-CODES}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
GRAY='\033[0;37m'
RESET='\033[0m'

step()   { echo -e "\n${CYAN}══════════════════════════════════════════════════════════════════${RESET}"; echo -e "${MAGENTA}$1${RESET}"; echo -e "${CYAN}══════════════════════════════════════════════════════════════════${RESET}\n"; }
ok()     { echo -e "${GREEN}  [OK]   $1${RESET}"; }
skip()   { echo -e "${YELLOW}  [SKIP] $1${RESET}"; }
warn()   { echo -e "${YELLOW}  [WARN] $1${RESET}"; }
err()    { echo -e "${RED}  [ERR]  $1${RESET}" >&2; }

MIN_NODE_MAJOR=18

ensure_node_lts() {
    if ! command -v node >/dev/null 2>&1; then
        return 1
    fi

    local current_major
    current_major=$(node --version 2>/dev/null | sed 's/^v//' | cut -d. -f1)

    if [ -n "$current_major" ] && [ "$current_major" -ge "$MIN_NODE_MAJOR" ] 2>/dev/null; then
        return 0
    fi

    echo ""
    echo -e "${YELLOW}  Node.js v${current_major} < ${MIN_NODE_MAJOR} — требуется обновление${RESET}"
    echo -e "${CYAN}  Обновление Node.js до LTS…${RESET}"

    if command -v apt-get >/dev/null 2>&1; then
        echo -e "${GRAY}  → NodeSource setup for apt…${RESET}"
        if curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash - 2>/dev/null; then
            sudo apt-get install -y nodejs 2>/dev/null
        else
            warn "NodeSource setup failed, trying n-install…"
            _install_node_via_n
        fi
    elif command -v dnf >/dev/null 2>&1; then
        if curl -fsSL https://rpm.nodesource.com/setup_lts.x | sudo bash - 2>/dev/null; then
            sudo dnf install -y nodejs 2>/dev/null
        else
            _install_node_via_n
        fi
    elif command -v yum >/dev/null 2>&1; then
        if curl -fsSL https://rpm.nodesource.com/setup_lts.x | sudo bash - 2>/dev/null; then
            sudo yum install -y nodejs 2>/dev/null
        else
            _install_node_via_n
        fi
    elif command -v brew >/dev/null 2>&1; then
        brew install node 2>/dev/null
    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -S --noconfirm nodejs npm 2>/dev/null
    else
        warn "Не удалось автоматически обновить Node.js. Установите Node.js >= ${MIN_NODE_MAJOR} вручную."
        return 1
    fi

    _verify_node_after_upgrade
}

_install_node_via_n() {
    local N_DIR="$HOME/.n"
    local N_BIN="${N_DIR}/bin/n"
    local N_PREFIX="${N_DIR}"

    echo -e "${CYAN}  → Установка через n (Node.js version manager)…${RESET}"

    if ! command -v make >/dev/null 2>&1 || ! command -v gcc >/dev/null 2>&1; then
        if command -v apt-get >/dev/null 2>&1; then
            sudo apt-get install -y make gcc 2>/dev/null || true
        elif command -v dnf >/dev/null 2>&1; then
            sudo dnf install -y make gcc 2>/dev/null || true
        fi
    fi

    curl -fsSL https://raw.githubusercontent.com/tj/n/master/bin/n -o "$N_BIN" 2>/dev/null || {
        warn "Не удалось скачать n"
        return 1
    }
    chmod +x "$N_BIN" 2>/dev/null

    export N_PREFIX
    export PATH="${N_PREFIX}/bin:${PATH}"

    "$N_BIN" lts 2>/dev/null || {
        warn "Не удалось установить Node.js LTS через n"
        return 1
    }

    echo -e "${GRAY}  → Добавляю N_PREFIX в ~/.bashrc…${RESET}"
    for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
        if [ -f "$rc" ] && ! grep -q 'N_PREFIX' "$rc" 2>/dev/null; then
            {
                echo ''
                echo 'export N_PREFIX="$HOME/.n"'
                echo 'export PATH="$N_PREFIX/bin:$PATH"'
            } >> "$rc"
        fi
    done
}

_verify_node_after_upgrade() {
    hash -r 2>/dev/null || true
    export PATH="/usr/local/bin:/usr/bin:$HOME/.n/bin:$HOME/.local/bin:$PATH"

    if command -v node >/dev/null 2>&1; then
        local new_ver
        new_ver=$(node --version 2>/dev/null)
        local new_major
        new_major=$(echo "$new_ver" | sed 's/^v//' | cut -d. -f1)
        if [ -n "$new_major" ] && [ "$new_major" -ge "$MIN_NODE_MAJOR" ] 2>/dev/null; then
            ok "Node.js обновлён: $new_ver"
            return 0
        else
            warn "Node.js обновлён до $new_ver, но всё ещё < ${MIN_NODE_MAJOR}. Перезапустите терминал."
            return 1
        fi
    else
        err "Node.js не найден после обновления. Перезапустите терминал и запустите install.sh снова."
        return 1
    fi
}

# ─── Заголовок ───────────────────────────────────────────────────────────────

clear
echo -e "${CYAN}════════════════════════════════════════════════════════════════════════════════${RESET}"
echo -e "${CYAN}   ██████╗██╗     ██╗        ██████╗ ██████╗ ██████╗ ███████╗${RESET}"
echo -e "${CYAN}  ██╔════╝██║     ██║        ██╔════╝██╔═══██╗██╔══██╗██╔════╝${RESET}"
echo -e "${CYAN}  ██║     ██║     ██║ █████╗ ██║     ██║   ██║██║  ██║█████╗  ${RESET}"
echo -e "${CYAN}  ██║     ██║     ██║ ╚════╝ ██║     ██║   ██║██║  ██║██╔══╝  ${RESET}"
echo -e "${CYAN}  ╚██████╗███████╗██║        ╚██████╗╚██████╔╝██████╔╝███████╗${RESET}"
echo -e "${CYAN}   ╚═════╝╚══════╝╚═╝         ╚═════╝ ╚═════╝ ╚═════╝ ╚══════╝${RESET}"
echo -e "${CYAN}${RESET}"
echo -e "${YELLOW}              C L O U D   S E T U P  -  1-click install${RESET}"
echo -e "${YELLOW}  Qwen Code + Claude Code + OpenCode + Freebuff + OpenClaude${RESET}"
echo -e "${CYAN}════════════════════════════════════════════════════════════════════════════════${RESET}"
echo ""

# ─── Проверка зависимостей ───────────────────────────────────────────────────

step "ПРОВЕРКА ЗАВИСИМОСТЕЙ"

missing=()

if ! command -v git >/dev/null 2>&1; then
    missing+=("git")
fi
if ! command -v node >/dev/null 2>&1; then
    missing+=("node (Node.js LTS — https://nodejs.org/)")
fi
if ! command -v npm >/dev/null 2>&1; then
    missing+=("npm (ставится вместе с Node.js)")
fi

if [ ${#missing[@]} -gt 0 ]; then
    err "Отсутствуют необходимые инструменты:"
    for m in "${missing[@]}"; do
        echo -e "${YELLOW}  - $m${RESET}"
    done
    echo ""
    echo -e "${YELLOW}Установите их и запустите инсталлятор заново.${RESET}"
    echo ""
    echo "  Ubuntu/Debian: sudo apt install git nodejs npm"
    echo "  Fedora:        sudo dnf install git nodejs npm"
    echo "  Arch:          sudo pacman -S git nodejs npm"
    echo ""
    read -p "Нажмите Enter для выхода…"
    exit 1
fi

ok "git: $(git --version 2>&1 | head -1)"
ok "node: $(node --version 2>&1)"
ok "npm: $(npm --version 2>&1)"

if ! ensure_node_lts; then
    err "Node.js >= ${MIN_NODE_MAJOR} не доступен. Некоторые пакеты могут не установиться."
    echo -e "${YELLOW}  Установите Node.js >= ${MIN_NODE_MAJOR} и запустите install.sh снова.${RESET}"
    read -p "Нажмите Enter для выхода…"
    exit 1
fi

# ─── Клонирование ────────────────────────────────────────────────────────────

step "КЛОНИРОВАНИЕ РЕПОЗИТОРИЯ"

if [ -d "$INSTALL_DIR/.git" ]; then
    warn "Репозиторий уже клонирован: $INSTALL_DIR"
    echo -e "${CYAN}Обновление…${RESET}"
    (cd "$INSTALL_DIR" && git fetch origin main 2>/dev/null && git reset --hard origin/main 2>/dev/null) || warn "Не удалось обновить"
    ok "Репозиторий обновлён"
else
    echo -e "${CYAN}Клонирование $REPO_URL → $INSTALL_DIR…${RESET}"
    git clone "$REPO_URL" "$INSTALL_DIR" 2>&1 || {
        err "Ошибка клонирования. Проверьте доступ к $REPO_URL"
        exit 1
    }
    ok "Репозиторий клонирован: $INSTALL_DIR"
fi

# ─── Выбор инструментов ──────────────────────────────────────────────────────

INSTALL_QWEN=false
INSTALL_CLAUDE=false
INSTALL_OPENCODE=false
INSTALL_FREEBUFF=false
INSTALL_OPENCLAUDE=false
DO_UNINSTALL=false
DO_UPDATE=false
DO_SYNC_SHORTCUTS=false
DO_INSTALL_DEPS=false

while true; do
    step "ЧТО УСТАНОВИТЬ?"

    if [ -d "$INSTALL_DIR/.git" ]; then
        current_commit="$(cd "$INSTALL_DIR" && git rev-parse --short HEAD 2>/dev/null || true)"
        if [ -n "$current_commit" ]; then
            echo -e "${GRAY}Версия installer: ${current_commit}${RESET}"
            echo ""
        fi
    fi

    echo -e "  ${CYAN}[0]${RESET} Установка/обновление зависимостей (git, curl, Node.js ≥${MIN_NODE_MAJOR} LTS)"
    echo -e "  ${YELLOW}[1]${RESET} Установка сразу ВСЕХ агентов  ← рекомендуется"
    echo -e "  ${GREEN}[2]${RESET} Только Qwen Code"
    echo -e "  ${GREEN}[3]${RESET} Только Claude Code"
    echo -e "  ${GREEN}[4]${RESET} Только OpenCode"
    echo -e "  ${GREEN}[5]${RESET} Только Freebuff"
    echo -e "  ${GREEN}[6]${RESET} Только OpenClaude"
    echo -e "  ${YELLOW}[7]${RESET} Обновление ВСЕХ компонентов (проверяет актуальность)"
    echo -e "  ${RED}[8]${RESET} Полное удаление проекта с ПК (uninstall)"
    echo -e "  ${CYAN}[9]${RESET} Обновить ярлыки на рабочем столе (актуализация, скрытие скриптов)"
    echo -e "  ${GRAY}[X]${RESET} Выход из мастера установки"
    echo ""

    read -p "Ваш выбор [1]: " install_choice
    install_choice="${install_choice:-1}"
    install_choice="$(echo "$install_choice" | tr '[:lower:]' '[:upper:]')"

    INSTALL_QWEN=false
    INSTALL_CLAUDE=false
    INSTALL_OPENCODE=false
    INSTALL_FREEBUFF=false
    INSTALL_OPENCLAUDE=false
    DO_UNINSTALL=false
    DO_UPDATE=false
    DO_SYNC_SHORTCUTS=false
    DO_INSTALL_DEPS=false

    case "$install_choice" in
        0) DO_INSTALL_DEPS=true; break ;;
        1) INSTALL_QWEN=true; INSTALL_CLAUDE=true; INSTALL_OPENCODE=true; INSTALL_FREEBUFF=true; INSTALL_OPENCLAUDE=true; break ;;
        2) INSTALL_QWEN=true; break ;;
        3) INSTALL_CLAUDE=true; break ;;
        4) INSTALL_OPENCODE=true; break ;;
        5) INSTALL_FREEBUFF=true; break ;;
        6) INSTALL_OPENCLAUDE=true; break ;;
        7) DO_UPDATE=true; break ;;
        8) DO_UNINSTALL=true; break ;;
        9) DO_SYNC_SHORTCUTS=true; break ;;
        X|Q) echo -e "${YELLOW}Выход.${RESET}"; exit 0 ;;
        *) warn "Неверный выбор. Попробуйте снова." ;;
    esac
done

# Установка системных зависимостей
install_system_dependencies() {
    echo ""
    echo -e "${CYAN}======================================================================${RESET}"
    echo -e "${MAGENTA}УСТАНОВКА СИСТЕМНЫХ ЗАВИСИМОСТЕЙ${RESET}"
    echo -e "${CYAN}======================================================================${RESET}"
    echo ""

    local missing=()
    local node_needs_upgrade=false
    for cmd in git node npm curl jq; do
        if command -v "$cmd" >/dev/null 2>&1; then
            local path="$(command -v "$cmd")"
            echo -e "  ${GREEN}[OK]${RESET}   $cmd → $path"
        else
            echo -e "  ${YELLOW}[MISS]${RESET} $cmd — не найден"
            missing+=("$cmd")
        fi
    done

    if command -v node >/dev/null 2>&1; then
        local node_major
        node_major=$(node --version 2>/dev/null | sed 's/^v//' | cut -d. -f1)
        if [ -n "$node_major" ] && [ "$node_major" -lt "$MIN_NODE_MAJOR" ] 2>/dev/null; then
            echo -e "  ${YELLOW}[OLD]${RESET}  node v${node_major} < ${MIN_NODE_MAJOR} — будет обновлён"
            node_needs_upgrade=true
        fi
    fi

    if [ "${#missing[@]}" -eq 0 ] && [ "$node_needs_upgrade" = false ]; then
        echo ""
        echo -e "${GREEN}Все необходимые зависимости уже установлены.${RESET}"
        return 0
    fi

    if [ "${#missing[@]}" -gt 0 ]; then
        echo ""
        echo -e "${YELLOW}Отсутствуют: ${missing[*]}${RESET}"
        echo -e "${CYAN}Определяем пакетный менеджер...${RESET}"
    fi

    local pm=""
    if command -v apt-get >/dev/null 2>&1; then pm="apt"
    elif command -v dnf >/dev/null 2>&1; then pm="dnf"
    elif command -v yum >/dev/null 2>&1; then pm="yum"
    elif command -v pacman >/dev/null 2>&1; then pm="pacman"
    elif command -v apk >/dev/null 2>&1; then pm="apk"
    elif command -v brew >/dev/null 2>&1; then pm="brew"
    else
        echo -e "${RED}Пакетный менеджер не определён. Установите вручную: ${missing[*]}${RESET}"
        return 1
    fi
    echo -e "${CYAN}Используется: $pm${RESET}"

    local non_node_missing=()
    for pkg in "${missing[@]}"; do
        case "$pkg" in
            node|npm) ;;
            *) non_node_missing+=("$pkg") ;;
        esac
    done

    case "$pm" in
        apt)
            sudo apt-get update -qq

            if [ "${#non_node_missing[@]}" -gt 0 ]; then
                sudo apt-get install -y "${non_node_missing[@]}"
            fi

            if printf '%s\n' "${missing[@]}" | grep -q '^node$\|^npm$' || [ "$node_needs_upgrade" = true ]; then
                echo -e "${CYAN}  Установка Node.js LTS через NodeSource…${RESET}"
                if curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -; then
                    sudo apt-get install -y nodejs
                else
                    warn "NodeSource setup failed"
                    _install_node_via_n
                fi
            fi
            ;;
        dnf|yum)
            if [ "${#non_node_missing[@]}" -gt 0 ]; then
                sudo "$pm" install -y "${non_node_missing[@]}"
            fi

            if printf '%s\n' "${missing[@]}" | grep -q '^node$\|^npm$' || [ "$node_needs_upgrade" = true ]; then
                echo -e "${CYAN}  Установка Node.js LTS через NodeSource…${RESET}"
                if curl -fsSL https://rpm.nodesource.com/setup_lts.x | sudo bash -; then
                    sudo "$pm" install -y nodejs
                else
                    warn "NodeSource setup failed"
                    _install_node_via_n
                fi
            fi
            ;;
        pacman)
            local pacman_pkgs=()
            for pkg in "${non_node_missing[@]}"; do
                pacman_pkgs+=("$pkg")
            done
            if printf '%s\n' "${missing[@]}" | grep -q '^node$\|^npm$' || [ "$node_needs_upgrade" = true ]; then
                pacman_pkgs+=("nodejs" "npm")
            fi
            if [ "${#pacman_pkgs[@]}" -gt 0 ]; then
                sudo pacman -S --noconfirm "${pacman_pkgs[@]}"
            fi
            ;;
        apk)
            local apk_pkgs=()
            for pkg in "${non_node_missing[@]}"; do
                apk_pkgs+=("$pkg")
            done
            if printf '%s\n' "${missing[@]}" | grep -q '^node$\|^npm$' || [ "$node_needs_upgrade" = true ]; then
                apk_pkgs+=("nodejs" "npm")
            fi
            if [ "${#apk_pkgs[@]}" -gt 0 ]; then
                sudo apk add "${apk_pkgs[@]}"
            fi
            ;;
        brew)
            local brew_pkgs=("${non_node_missing[@]}")
            if printf '%s\n' "${missing[@]}" | grep -q '^node$\|^npm$' || [ "$node_needs_upgrade" = true ]; then
                brew_pkgs+=("node")
            fi
            if [ "${#brew_pkgs[@]}" -gt 0 ]; then
                brew install "${brew_pkgs[@]}"
            fi
            ;;
    esac

    echo ""
    echo -e "${CYAN}Проверка после установки:${RESET}"
    hash -r 2>/dev/null || true
    export PATH="/usr/local/bin:/usr/bin:$HOME/.n/bin:$HOME/.local/bin:$PATH"
    for cmd in git node npm curl jq; do
        if command -v "$cmd" >/dev/null 2>&1; then
            echo -e "  ${GREEN}[OK]${RESET}   $cmd → $(command -v "$cmd")"
        else
            echo -e "  ${YELLOW}[MISS]${RESET} $cmd — установите вручную или перезапустите терминал"
        fi
    done

    if command -v node >/dev/null 2>&1; then
        local final_major
        final_major=$(node --version 2>/dev/null | sed 's/^v//' | cut -d. -f1)
        if [ -n "$final_major" ] && [ "$final_major" -ge "$MIN_NODE_MAJOR" ] 2>/dev/null; then
            echo -e "  ${GREEN}[OK]${RESET}   Node.js $(node --version 2>/dev/null) ≥ ${MIN_NODE_MAJOR}"
        else
            echo -e "  ${YELLOW}[WARN]${RESET}  Node.js $(node --version 2>/dev/null) < ${MIN_NODE_MAJOR} — перезапустите терминал"
        fi
    fi
}

if [ "$DO_INSTALL_DEPS" = true ]; then
    install_system_dependencies
    echo ""
    echo -e "${CYAN}Готово. Перезапустите терминал и запустите install.sh снова для установки инструментов.${RESET}"
    exit 0
fi

# ─── Helper: синхронизация ярлыков ──────────────────────────────────────────
# Создаёт недостающие .desktop и ~/.sh лаунчеры для уже установленных CLI.
sync_launcher_shortcuts() {
    local install_dir="$1"
    local scripts_dir="$install_dir/scripts"

    # Определяем каталог рабочего стола
    local desktop=""
    for d in "$HOME/Desktop" "$HOME/Рабочий стол"; do
        if [ -d "$d" ]; then
            desktop="$d"
            break
        fi
    done

    chmod +x "$scripts_dir"/*.sh 2>/dev/null || true

    # Список: CLI-binary, имя ярлыка, имя .sh файла (без расширения), лаунчер .sh
    local entries=(
        "qwen|Qwen Code|qwen-code|$scripts_dir/run-qwen-code-launcher.sh"
        "claude|Claude Code|claude-code|$scripts_dir/run-claude-cloud-launcher.sh"
        "opencode|OpenCode|opencode|$scripts_dir/run-opencode-launcher.sh"
        "freebuff|Freebuff|freebuff|$scripts_dir/run-freebuff-launcher.sh"
        "openclaude|OpenClaude|openclaude|$scripts_dir/run-openclaude-launcher.sh"
    )

    local added=0
    local present=0
    for entry in "${entries[@]}"; do
        local cli="${entry%%|*}"
        local rest="${entry#*|}"
        local name="${rest%%|*}"
        local rest2="${rest#*|}"
        local sh_name="${rest2%%|*}"
        local script="${rest2##*|}"

        # Пропускаем если CLI не установлен
        if ! command -v "$cli" >/dev/null 2>&1; then
            echo -e "${GRAY}  [SKIP] $cli CLI не установлен — ярлык пропущен${RESET}"
            continue
        fi
        if [ ! -f "$script" ]; then
            echo -e "${GRAY}  [SKIP] $script не найден${RESET}"
            continue
        fi

        local sh_path="$HOME/${sh_name}.sh"

        # .sh launcher (для серверов без GUI)
        if [ ! -f "$sh_path" ]; then
            cat > "$sh_path" << EOF
#!/bin/bash
# Запуск лаунчера $name
exec bash "$script" "\$@"
EOF
            chmod +x "$sh_path"
            echo -e "${GREEN}  [+] $sh_name.sh → $sh_path${RESET}"
            added=$((added + 1))
        else
            present=$((present + 1))
        fi

        # .desktop file (для desktop сред)
        if [ -n "$desktop" ]; then
            local entry_path="$desktop/${name}.desktop"
            if [ ! -f "$entry_path" ]; then
                cat > "$entry_path" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=$name
Exec=bash "$script"
Path=$install_dir
Terminal=true
StartupNotify=true
Categories=Development;
EOF
                chmod +x "$entry_path"
                echo -e "${GREEN}  [+] ${name}.desktop → $entry_path${RESET}"
                added=$((added + 1))
            else
                present=$((present + 1))
            fi
        fi
    done

    echo ""
    echo -e "${CYAN}Ярлыки: уже на месте = $present, добавлено новых = $added${RESET}"
}

# --- Sync shortcuts only ---
if $DO_SYNC_SHORTCUTS; then
    step "СИНХРОНИЗАЦИЯ ЯРЛЫКОВ"

    if [ ! -d "$INSTALL_DIR" ]; then
        err "Репозиторий не найден: $INSTALL_DIR"
        err "Сначала установите инструменты через пункт [6]."
        read -p "Нажмите Enter для выхода…"
        exit 1
    fi

    echo -e "${CYAN}Проверка ярлыков для установленных CLI…${RESET}"
    sync_launcher_shortcuts "$INSTALL_DIR"

    echo ""
    echo -e "${GREEN}════════════════════════════════════════════════════════════════════════════════${RESET}"
    echo -e "${GREEN}  ЯРЛЫКИ ОБНОВЛЕНЫ${RESET}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════════════════════════${RESET}"
    echo ""
    read -p "Нажмите Enter для выхода…"
    exit 0
fi

# --- Update ---
if $DO_UPDATE; then
    step "ОБНОВЛЕНИЕ ВСЕХ КОМПОНЕНТОВ"

    install_system_dependencies

    # Pull latest code (check if anything changed)
    if [ -d "$INSTALL_DIR/.git" ]; then
        echo -e "${CYAN}Проверка обновлений репозитория…${RESET}"
        head_before=$(cd "$INSTALL_DIR" && git rev-parse HEAD 2>/dev/null || echo "")
        (cd "$INSTALL_DIR" && git fetch origin main 2>/dev/null && git reset --hard origin/main 2>/dev/null) || warn "Не удалось обновить репозиторий"
        head_after=$(cd "$INSTALL_DIR" && git rev-parse HEAD 2>/dev/null || echo "")
        if [ -n "$head_before" ] && [ -n "$head_after" ] && [ "$head_before" = "$head_after" ]; then
            echo -e "${GRAY}  [OK] Репозиторий уже актуален (${head_after:0:7})${RESET}"
        elif [ -n "$head_after" ]; then
            short_b="${head_before:0:7}"
            short_a="${head_after:0:7}"
            ok "Репозиторий обновлён ($short_b → $short_a)"
        fi
    else
        err "Репозиторий не найден: $INSTALL_DIR"
        err "Сначала установите через пункт [6]"
        read -p "Нажмите Enter для выхода…"
        exit 1
    fi

    SCRIPTS_DIR="$INSTALL_DIR/scripts"
    chmod +x "$SCRIPTS_DIR"/*.sh 2>/dev/null || true

    # Helper: get installed npm version (empty if not installed)
    get_installed_version() {
        local npm_name="$1"
        if npm ls -g "$npm_name" &>/dev/null; then
            npm ls -g "$npm_name" 2>/dev/null | grep "$npm_name" | head -1 | sed 's/.*@//' | tr -d ' '
        fi
    }

    # Helper: get latest npm version from registry (empty if unknown)
    get_latest_version() {
        local npm_name="$1"
        npm view "$npm_name" version 2>/dev/null | head -1 | tr -d ' ' || echo ""
    }

    # Update npm packages (skip if already at latest)
    echo ""
    echo -e "${CYAN}Проверка и обновление npm пакетов…${RESET}"

    pkg_updated=0
    pkg_skipped=0
    for pkg_info in "qwen-code:@qwen-code/qwen-code" "claude-code:@anthropic-ai/claude-code" "opencode-ai:opencode-ai" "freebuff:freebuff" "openclaude:@gitlawb/openclaude"; do
        pkg_name="${pkg_info%%:*}"
        npm_name="${pkg_info##*:}"

        before=$(get_installed_version "$npm_name")
        latest=$(get_latest_version "$npm_name")

        if [ -n "$before" ] && [ -n "$latest" ] && [ "$before" = "$latest" ]; then
            echo -e "${GRAY}  [OK] $pkg_name v$before (уже актуально)${RESET}"
            pkg_skipped=$((pkg_skipped + 1))
            continue
        fi

        if [ -n "$before" ]; then
            target="${latest:-latest}"
            echo -e "${CYAN}  → $pkg_name: $before → $target${RESET}"
        else
            echo -e "${CYAN}  → Установка $pkg_name (не установлен)${RESET}"
        fi

        if npm install -g "${npm_name}@latest" 2>/dev/null; then
            after=$(get_installed_version "$npm_name")
            if [ -n "$before" ] && [ "$before" != "$after" ]; then
                ok "$pkg_name: $before → $after"
            else
                ok "$pkg_name: $after"
            fi
            pkg_updated=$((pkg_updated + 1))
        else
            warn "Не удалось обновить $pkg_name"
        fi
    done

    # Update free-claude-code proxy if exists (skip if already at latest)
    FCC_DIR="$HOME/.free-claude-code"
    if [ -d "$FCC_DIR" ]; then
        echo ""
        echo -e "${CYAN}Проверка free-claude-code proxy…${RESET}"
        fcc_before=$(cd "$FCC_DIR" && git rev-parse HEAD 2>/dev/null || echo "")
        (cd "$FCC_DIR" && git pull origin main >/dev/null 2>&1) || true
        fcc_after=$(cd "$FCC_DIR" && git rev-parse HEAD 2>/dev/null || echo "")
        if [ -n "$fcc_before" ] && [ -n "$fcc_after" ] && [ "$fcc_before" != "$fcc_after" ]; then
            echo -e "${CYAN}  → free-claude-code обновлён, синхронизация зависимостей…${RESET}"
            if command -v uv &>/dev/null; then
                (cd "$FCC_DIR" && uv sync &>/dev/null) || true
            fi
            ok "free-claude-code обновлён"
        elif [ -n "$fcc_after" ]; then
            echo -e "${GRAY}  [OK] free-claude-code уже актуален (${fcc_after:0:7})${RESET}"
        fi
    fi

    # Синхронизация ярлыков
    echo ""
    echo -e "${CYAN}Проверка ярлыков для установленных CLI…${RESET}"
    sync_launcher_shortcuts "$INSTALL_DIR"

    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════════════════${RESET}"
    echo -e "${GREEN}  ОБНОВЛЕНИЕ ЗАВЕРШЕНО!${RESET}"
    echo -e "${GREEN}  Обновлено: $pkg_updated, пропущено (актуально): $pkg_skipped${RESET}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════════════════${RESET}"
    echo ""
    read -p "Нажмите Enter для выхода…"
    exit 0
fi

# --- Uninstall ---
if $DO_UNINSTALL; then
    step "ПОЛНОЕ УДАЛЕНИЕ"

    echo -e "${RED}ВНИМАНИЕ: Это действие удалит:${RESET}"
    echo -e "${RED}  - Репозиторий $INSTALL_DIR${RESET}"
    echo -e "${RED}  - Все сессии (qwen/claude/opencode-sessions)${RESET}"
    echo -e "${RED}  - Конфиги CLI (~/.claude, ~/.qwen)${RESET}"
    echo -e "${RED}  - API ключи из ~/.bashrc и ~/.zshrc${RESET}"
    echo -e "${RED}  - Лаунчеры ~/qwen-code.sh, ~/claude-code.sh, ~/opencode.sh, ~/freebuff.sh, ~/openclaude.sh${RESET}"
    echo -e "${RED}  - Desktop ярлыки (.desktop)${RESET}"
    echo -e "${RED}  - Глобальные npm пакеты (qwen-code, claude-code, opencode-ai, freebuff, openclaude)${RESET}"
    echo ""
    echo -e "${YELLOW}Введите 'yes' для подтверждения удаления: ${RESET}"
    read -r confirm
    if [ "$confirm" != "yes" ]; then
        echo -e "${YELLOW}Отмена удаления.${RESET}"
        read -p "Нажмите Enter для выхода..."
        exit 0
    fi

    echo ""
    echo -e "${CYAN}Удаление репозитория...${RESET}"
    if [ -d "$INSTALL_DIR" ]; then
        rm -rf "$INSTALL_DIR"
        ok "Удалён: $INSTALL_DIR"
    else
        skip "$INSTALL_DIR не найден"
    fi

    echo -e "${CYAN}Удаление сессий...${RESET}"
    for sdir in "$HOME/qwen-sessions" "$HOME/claude-sessions" "$HOME/opencode-sessions"; do
        if [ -d "$sdir" ]; then
            rm -rf "$sdir"
            ok "Удалён: $sdir"
        fi
    done

    echo -e "${CYAN}Удаление конфигов CLI...${RESET}"
    for cfg in "$HOME/.claude" "$HOME/.qwen" "$HOME/.opencode"; do
        if [ -d "$cfg" ]; then
            rm -rf "$cfg"
            ok "Удалён: $cfg"
        fi
    done

    echo -e "${CYAN}Удаление API ключей из ~/.bashrc и ~/.zshrc...${RESET}"
    for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
        if [ -f "$rc" ]; then
            for var in NVIDIA_NIM_API_KEY ZAI_API_KEY OPENAI_API_KEY GROQ_API_KEY OPENROUTER_API_KEY BAI_API_KEY; do
                sed -i "/^export ${var}=/d" "$rc"
            done
            ok "Очищен: $rc"
        fi
    done

    echo -e "${CYAN}Удаление лаунчеров...${RESET}"
    for launcher in "$HOME/qwen-code.sh" "$HOME/claude-code.sh" "$HOME/opencode.sh" "$HOME/freebuff.sh" "$HOME/openclaude.sh" \
                    "$HOME/qwen-code-cloud.sh" "$HOME/claude-code-cloud.sh" "$HOME/opencode-cloud.sh" "$HOME/freebuff-cloud.sh" "$HOME/openclaude-cloud.sh"; do
        if [ -f "$launcher" ]; then
            rm -f "$launcher"
            ok "Удалён: $launcher"
        fi
    done

    echo -e "${CYAN}Удаление desktop ярлыков...${RESET}"
    for d in "$HOME/Desktop" "$HOME/Рабочий стол"; do
        if [ -d "$d" ]; then
            for f in "$d/Qwen Code.desktop" "$d/Claude Code.desktop" "$d/OpenCode.desktop" "$d/Freebuff.desktop" "$d/OpenClaude.desktop" \
                      "$d/Qwen Code (cloud).desktop" "$d/Claude Code (cloud).desktop" "$d/OpenCode (cloud).desktop" "$d/Freebuff (cloud).desktop" "$d/OpenClaude (cloud).desktop"; do
                if [ -f "$f" ]; then
                    rm -f "$f"
                    ok "Удалён: $f"
                fi
            done
        fi
    done

    echo -e "${CYAN}Удаление глобальных npm пакетов...${RESET}"
    for pkg in @qwen-code/qwen-code @anthropic-ai/qwen-code @anthropic-ai/claude-code opencode-ai freebuff @gitlawb/openclaude; do
        if npm ls -g "$pkg" &>/dev/null; then
            npm uninstall -g "$pkg" 2>/dev/null && ok "Удалён npm: $pkg" || warn "Не удалось удалить: $pkg"
        else
            skip "npm $pkg не установлен"
        fi
    done

    echo ""
    echo -e "${GREEN}════════════════════════════════════════════════════════════════════════════════${RESET}"
    echo -e "${GREEN}  ПОЛНОЕ УДАЛЕНИЕ ЗАВЕРШЕНО!${RESET}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════════════════════════${RESET}"
    echo ""
    echo -e "${YELLOW}Перезапустите терминал для очистки переменных окружения.${RESET}"
    echo ""
    read -p "Нажмите Enter для выхода..."
    exit 0
fi

# ─── Установка CLI ───────────────────────────────────────────────────────────

step "УСТАНОВКА CLI"

install_system_dependencies

if $INSTALL_QWEN; then
    echo -e "${CYAN}Установка/обновление Qwen Code CLI…${RESET}"
    if npm install -g @qwen-code/qwen-code@latest 2>/dev/null; then
        ok "Qwen Code CLI: $(which qwen 2>/dev/null)"
    else
        warn "Не удалось установить Qwen Code CLI. Установите вручную: npm i -g @qwen-code/qwen-code"
    fi
fi

if $INSTALL_CLAUDE; then
    echo -e "${CYAN}Установка/обновление Claude Code CLI…${RESET}"
    if npm install -g @anthropic-ai/claude-code@latest 2>/dev/null; then
        ok "Claude Code CLI: $(which claude 2>/dev/null)"
    else
        warn "Не удалось установить Claude Code CLI. Установите вручную: npm i -g @anthropic-ai/claude-code"
    fi

    # free-claude-code proxy for NIM/OpenRouter
    FCC_DIR="$HOME/.free-claude-code"
    echo -e "${CYAN}Установка free-claude-code proxy (для NIM/OpenRouter)…${RESET}"
    if ! command -v uv &>/dev/null; then
        echo -e "${CYAN}  Установка uv…${RESET}"
        curl -LsSf https://astral.sh/uv/install.sh | sh 2>/dev/null
        export PATH="$HOME/.local/bin:$PATH"
    fi
    if [ ! -d "$FCC_DIR" ]; then
        git clone https://github.com/Alishahryar1/free-claude-code.git "$FCC_DIR" 2>/dev/null
        if [ -d "$FCC_DIR" ]; then
            ok "free-claude-code: $FCC_DIR"
            # Preinstall deps to avoid first-run hang
            (cd "$FCC_DIR" && uv sync &>/dev/null) || warn "free-claude-code: не удалось прогреть зависимости (uv sync)"
        else
            warn "Не удалось клонировать free-claude-code. NIM/OpenRouter будут недоступны."
        fi
    else
        (cd "$FCC_DIR" && git pull origin main >/dev/null 2>&1) || true
        ok "free-claude-code: обновлён"
        (cd "$FCC_DIR" && uv sync &>/dev/null) || true
    fi
fi

if $INSTALL_OPENCODE; then
    echo -e "${CYAN}Установка/обновление OpenCode CLI…${RESET}"
    if npm install -g opencode-ai@latest 2>/dev/null; then
        ok "OpenCode CLI: $(which opencode 2>/dev/null)"
    else
        warn "Не удалось установить OpenCode CLI. Установите вручную: npm i -g opencode-ai@latest"
    fi
fi

if $INSTALL_FREEBUFF; then
    echo -e "${CYAN}Установка/обновление Freebuff CLI…${RESET}"
    if npm install -g freebuff@latest 2>/dev/null; then
        ok "Freebuff CLI: $(which freebuff 2>/dev/null)"
    else
        warn "Не удалось установить Freebuff CLI. Установите вручную: npm i -g freebuff"
    fi
fi

if $INSTALL_OPENCLAUDE; then
    echo -e "${CYAN}Установка/обновление OpenClaude CLI…${RESET}"
    if npm install -g @gitlawb/openclaude@latest 2>/dev/null; then
        ok "OpenClaude CLI: $(which openclaude 2>/dev/null)"
    else
        warn "Не удалось установить OpenClaude CLI. Установите вручную: npm i -g @gitlawb/openclaude"
    fi
fi

# ─── API ключи ───────────────────────────────────────────────────────────────

step "НАСТРОЙКА API КЛЮЧЕЙ"

# Function to read key with asterisk display
read_key_stars() {
    local prompt="$1"
    local var_name="$2"
    local key=""
    local char
    
    printf "%s" "$prompt"
    while IFS= read -r -n1 -s char; do
        if [[ -z "$char" ]]; then
            printf '\n'
            break
        elif [[ "$char" == $'\x7f' || "$char" == $'\x08' ]]; then
            if [ -n "$key" ]; then
                key="${key%?}"
                printf '\b \b'
            fi
        else
            key+="$char"
            printf '*'
        fi
    done < /dev/tty
    eval "$var_name=\"\$key\""
}

echo -e "${YELLOW}Оставьте пустым, чтобы пропустить. Ключи можно изменить позже через меню лаунчера.${RESET}"
echo ""

read_key_stars "NVIDIA NIM API ключ (Enter = пропуск): " nim_key
if [ -n "$nim_key" ]; then
    for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
        if [ -f "$rc" ]; then
            sed -i '/^export NVIDIA_NIM_API_KEY=/d' "$rc"
            echo "export NVIDIA_NIM_API_KEY=\"$nim_key\"" >> "$rc"
        fi
    done
    export NVIDIA_NIM_API_KEY="$nim_key"
    ok "NVIDIA_NIM_API_KEY сохранён"
else
    skip "NVIDIA_NIM_API_KEY пропущен"
fi

echo ""

read_key_stars "Z.AI API ключ (Enter = пропуск): " zai_key
if [ -n "$zai_key" ]; then
    for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
        if [ -f "$rc" ]; then
            sed -i '/^export ZAI_API_KEY=/d' "$rc"
            echo "export ZAI_API_KEY=\"$zai_key\"" >> "$rc"
        fi
    done
    export ZAI_API_KEY="$zai_key"
    ok "ZAI_API_KEY сохранён"
else
    skip "ZAI_API_KEY пропущен"
fi

echo ""

read_key_stars "Groq API ключ (Enter = пропуск): " groq_key
if [ -n "$groq_key" ]; then
    for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
        if [ -f "$rc" ]; then
            sed -i '/^export GROQ_API_KEY=/d' "$rc"
            echo "export GROQ_API_KEY=\"$groq_key\"" >> "$rc"
        fi
    done
    export GROQ_API_KEY="$groq_key"
    ok "GROQ_API_KEY сохранён"
else
    skip "GROQ_API_KEY пропущен"
fi

echo ""

read_key_stars "OpenRouter API ключ (Enter = пропуск): " or_key
if [ -n "$or_key" ]; then
    for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
        if [ -f "$rc" ]; then
            sed -i '/^export OPENROUTER_API_KEY=/d' "$rc"
            echo "export OPENROUTER_API_KEY=\"$or_key\"" >> "$rc"
        fi
    done
    export OPENROUTER_API_KEY="$or_key"
    ok "OPENROUTER_API_KEY сохранён"
else
    skip "OPENROUTER_API_KEY пропущен"
fi

echo ""

read_key_stars "B.AI API ключ (Enter = пропуск): " bai_key
if [ -n "$bai_key" ]; then
    for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
        if [ -f "$rc" ]; then
            sed -i '/^export BAI_API_KEY=/d' "$rc"
            echo "export BAI_API_KEY=\"$bai_key\"" >> "$rc"
        fi
    done
    export BAI_API_KEY="$bai_key"
    ok "BAI_API_KEY сохранён"
else
    skip "BAI_API_KEY пропущен"
fi

# ─── Единое пространство /resume ──────────────────────────────────────────────

step "НАСТРОЙКА СЕССИЙ (/resume)"

if $INSTALL_QWEN; then
    SHARED_DIR="$INSTALL_DIR/qwen-sessions/_shared/.qwen"
    mkdir -p "$SHARED_DIR"
    ok "qwen-sessions/_shared/"
fi
if $INSTALL_CLAUDE; then
    mkdir -p "$INSTALL_DIR/claude-sessions/_shared"
    ok "claude-sessions/_shared/"
fi
if $INSTALL_OPENCODE; then
    mkdir -p "$INSTALL_DIR/opencode-sessions/_shared"
    ok "opencode-sessions/_shared/"
fi

# ─── Создание ярлыков ────────────────────────────────────────────────────────

step "СОЗДАНИЕ ЯРЛЫКОВ"

SCRIPTS_DIR="$INSTALL_DIR/scripts"
chmod +x "$SCRIPTS_DIR"/*.sh 2>/dev/null || true

# Определяем каталог рабочего стола
DESKTOP=""
for d in "$HOME/Desktop" "$HOME/Рабочий стол"; do
    if [ -d "$d" ]; then
        DESKTOP="$d"
        break
    fi
done

make_desktop_entry() {
    local name="$1"
    local exec_path="$2"
    local entry_path="$DESKTOP/${name}.desktop"

    cat > "$entry_path" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=$name
Exec=bash "$exec_path"
Path=$INSTALL_DIR
Terminal=true
StartupNotify=true
Categories=Development;
EOF
    chmod +x "$entry_path"
    ok "${name}.desktop → $entry_path"
}

# Создаём .sh скрипты-лаунчеры в ~/ (для серверов без GUI)
make_sh_launcher() {
    local name="$1"
    local exec_path="$2"
    local sh_path="$HOME/${name}.sh"

    cat > "$sh_path" << EOF
#!/bin/bash
# Запуск лаунчера $name
exec bash "$exec_path" "\$@"
EOF
    chmod +x "$sh_path"
    ok "${name}.sh → $sh_path"
}

if $INSTALL_QWEN; then
    LAUNCHER="$SCRIPTS_DIR/run-qwen-code-launcher.sh"
    if [ -f "$LAUNCHER" ]; then
        if [ -n "$DESKTOP" ]; then
            make_desktop_entry "Qwen Code" "$LAUNCHER"
        fi
        make_sh_launcher "qwen-code" "$LAUNCHER"
    fi
fi

if $INSTALL_CLAUDE; then
    LAUNCHER="$SCRIPTS_DIR/run-claude-cloud-launcher.sh"
    if [ -f "$LAUNCHER" ]; then
        if [ -n "$DESKTOP" ]; then
            make_desktop_entry "Claude Code" "$LAUNCHER"
        fi
        make_sh_launcher "claude-code" "$LAUNCHER"
    fi
fi

if $INSTALL_OPENCODE; then
    LAUNCHER="$SCRIPTS_DIR/run-opencode-launcher.sh"
    if [ -f "$LAUNCHER" ]; then
        if [ -n "$DESKTOP" ]; then
            make_desktop_entry "OpenCode" "$LAUNCHER"
        fi
        make_sh_launcher "opencode" "$LAUNCHER"
    fi
fi

if $INSTALL_FREEBUFF; then
    LAUNCHER="$SCRIPTS_DIR/run-freebuff-launcher.sh"
    if [ -f "$LAUNCHER" ]; then
        if [ -n "$DESKTOP" ]; then
            make_desktop_entry "Freebuff" "$LAUNCHER"
        fi
        make_sh_launcher "freebuff" "$LAUNCHER"
    fi
fi

if $INSTALL_OPENCLAUDE; then
    LAUNCHER="$SCRIPTS_DIR/run-openclaude-launcher.sh"
    if [ -f "$LAUNCHER" ]; then
        if [ -n "$DESKTOP" ]; then
            make_desktop_entry "OpenClaude" "$LAUNCHER"
        fi
        make_sh_launcher "openclaude" "$LAUNCHER"
    fi
fi

# ─── Итоги ───────────────────────────────────────────────────────────────────

echo ""
echo -e "${CYAN}════════════════════════════════════════════════════════════════════════════════${RESET}"
echo -e "${GREEN}УСТАНОВКА ЗАВЕРШЕНА!${RESET}"
echo -e "${CYAN}════════════════════════════════════════════════════════════════════════════════${RESET}"
echo ""
echo -e "${GRAY}Репозиторий: $INSTALL_DIR${RESET}"
echo ""
echo -e "${CYAN}Команды для запуска:${RESET}"
if $INSTALL_QWEN;     then echo -e "${GREEN}  ~/qwen-code.sh${RESET}"; fi
if $INSTALL_CLAUDE;   then echo -e "${GREEN}  ~/claude-code.sh${RESET}"; fi
if $INSTALL_OPENCODE; then echo -e "${GREEN}  ~/opencode.sh${RESET}"; fi
if $INSTALL_FREEBUFF; then echo -e "${GREEN}  ~/freebuff.sh${RESET}"; fi
if $INSTALL_OPENCLAUDE; then echo -e "${GREEN}  ~/openclaude.sh${RESET}"; fi
echo ""
echo -e "${YELLOW}Перезапустите терминал для применения API ключей. Запускайте через команды выше!${RESET}"
echo ""
echo -e "${CYAN}Приятного использования!${RESET}"
echo ""
read -p "Нажмите Enter для выхода…"
