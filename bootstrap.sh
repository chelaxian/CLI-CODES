#!/bin/bash
# cloud-code-setup — bootstrap (curl | bash)
# Определяет ОС и запускает нужный инсталлятор

set -e

REPO_RAW="https://raw.githubusercontent.com/chelaxian/cloud-code-setup/main"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

echo -e "${CYAN}cloud-code-setup :: 1-click bootstrap${RESET}"
echo ""

# Определение ОС
OS="$(uname -s 2>/dev/null || echo unknown)"
case "$OS" in
    Linux*)
        echo -e "${GREEN}Обнаружена ОС: Linux${RESET}"
        PLATFORM="linux"
        ;;
    Darwin*)
        echo -e "${GREEN}Обнаружена ОС: macOS (экспериментально)${RESET}"
        PLATFORM="linux"
        ;;
    MINGW*|MSYS*|CYGWIN*|Windows_NT)
        echo -e "${GREEN}Обнаружена ОС: Windows${RESET}"
        PLATFORM="windows"
        ;;
    *)
        echo -e "${RED}Не удалось определить ОС: $OS${RESET}"
        echo -e "${YELLOW}Поддерживаются: Windows, Linux, macOS${RESET}"
        exit 1
        ;;
esac

# Создаём временную директорию
TMPDIR="$(mktemp -d 2>/dev/null || echo /tmp/cloud-code-setup-$$)"
mkdir -p "$TMPDIR"
trap 'rm -rf "$TMPDIR" 2>/dev/null' EXIT

echo -e "${CYAN}Загрузка инсталлятора…${RESET}"

if command -v curl >/dev/null 2>&1; then
    DL="curl -fsSL"
elif command -v wget >/dev/null 2>&1; then
    DL="wget -qO-"
else
    echo -e "${RED}curl или wget не найдены. Установите curl.${RESET}"
    exit 1
fi

if [ "$PLATFORM" = "windows" ]; then
    echo -e "${YELLOW}Для Windows загрузка через curl-bash не поддерживается.${RESET}"
    echo ""
    echo -e "${CYAN}Запустите в PowerShell (от имени администратора):${RESET}"
    echo ""
    echo -e "${GREEN}irm https://raw.githubusercontent.com/chelaxian/cloud-code-setup/main/install.ps1 | iex${RESET}"
    echo ""
    echo -e "${CYAN}Или вручную:${RESET}"
    echo "  1. git clone https://github.com/chelaxian/cloud-code-setup.git"
    echo "  2. cd cloud-code-setup"
    echo "  3. .\\install.ps1"
    exit 0
fi

# Linux/macOS: скачиваем и запускаем инсталлятор
INSTALLER="$TMPDIR/install.sh"
$DL "$REPO_RAW/install.sh" > "$INSTALLER" 2>/dev/null || {
    echo -e "${RED}Ошибка загрузки install.sh${RESET}"
    exit 1
}

chmod +x "$INSTALLER"
echo -e "${GREEN}Запуск инсталлятора…${RESET}"
echo ""
exec bash "$INSTALLER" "$@" < /dev/tty
