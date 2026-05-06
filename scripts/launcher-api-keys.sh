#!/bin/bash
# Модуль для управления API ключами в лаунчерах Qwen/Claude (Linux)

# ANSI цвета для TUI
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export MAGENTA='\033[0;35m'
export CYAN='\033[0;36m'
export GRAY='\033[0;37m'
export WHITE='\033[1;37m'
export RESET='\033[0m'

get_current_api_key() {
    local provider="$1"
    
    case "$provider" in
        "NVIDIA_NIM")
            local key="${NVIDIA_NIM_API_KEY:-}"
            if [ -z "$key" ]; then
                key=$(getent passwd "$USER" | cut -d: -f6)/.bashrc 2>/dev/null | grep "export NVIDIA_NIM_API_KEY=" | cut -d'"' -f2
            fi
            if [ -z "$key" ] || [ "$key" = "__SET_ME__" ]; then
                echo ""
            else
                echo "$key" | xargs
            fi
            ;;
        "ZAI")
            local key="${ZAI_API_KEY:-}"
            if [ -z "$key" ] || [ "$key" = "__SET_ME__" ]; then
                key=$(getent passwd "$USER" | cut -d: -f6)/.bashrc 2>/dev/null | grep "export ZAI_API_KEY=" | cut -d'"' -f2
            fi
            if [ -z "$key" ] || [ "$key" = "__SET_ME__" ]; then
                key="${OPENAI_API_KEY:-}"
            fi
            if [ -z "$key" ] || [ "$key" = "__SET_ME__" ]; then
                key=$(getent passwd "$USER" | cut -d: -f6)/.bashrc 2>/dev/null | grep "export OPENAI_API_KEY=" | cut -d'"' -f2
            fi
            if [ -z "$key" ] || [ "$key" = "__SET_ME__" ]; then
                echo ""
            else
                echo "$key" | xargs
            fi
            ;;
        "GROQ")
            local key="${GROQ_API_KEY:-}"
            if [ -z "$key" ]; then
                key=$(grep "^export GROQ_API_KEY=" "$HOME/.bashrc" 2>/dev/null | cut -d'"' -f2)
            fi
            if [ -z "$key" ]; then echo "" ; else echo "$key" | xargs ; fi
            ;;
        "OPENROUTER")
            local key="${OPENROUTER_API_KEY:-}"
            if [ -z "$key" ]; then
                key=$(grep "^export OPENROUTER_API_KEY=" "$HOME/.bashrc" 2>/dev/null | cut -d'"' -f2)
            fi
            if [ -z "$key" ]; then echo "" ; else echo "$key" | xargs ; fi
            ;;
        *)
            echo ""
            ;;
    esac
}

read_secret_text() {
    local prompt="$1"
    echo -n "$prompt"
    read -s key
    echo
    echo "$key"
}

set_provider_api_key() {
    local provider="$1"
    local new_key="$2"
    local bashrc_file="$HOME/.bashrc"
    local zshrc_file="$HOME/.zshrc"
    
    if [ -z "$new_key" ]; then
        echo -e "${RED}Ошибка: API ключ не может быть пустым${RESET}" >&2
        return 1
    fi
    
    local env_var=""
    local export_line=""
    
    case "$provider" in
        "NVIDIA_NIM")
            env_var="NVIDIA_NIM_API_KEY"
            ;;
        "ZAI")
            env_var="ZAI_API_KEY"
            ;;
        "GROQ")
            env_var="GROQ_API_KEY"
            ;;
        "OPENROUTER")
            env_var="OPENROUTER_API_KEY"
            ;;
        *)
            echo -e "${RED}Неизвестный провайдер: $provider${RESET}" >&2
            return 1
            ;;
    esac
    
    export_line="export $env_var=\"$new_key\""
    
    # Удаляем старую запись если есть
    for rc_file in "$bashrc_file" "$zshrc_file"; do
        if [ -f "$rc_file" ]; then
            sed -i "/^export $env_var=/d" "$rc_file"
            echo "$export_line" >> "$rc_file"
        fi
    done
    
    # Экспортируем в текущую сессию
    export "$env_var=$new_key"
    
    echo -e "${GREEN}${env_var} обновлён в ~/.bashrc и ~/.zshrc${RESET}"
    return 0
}

show_api_key_change_menu() {
    local app_brand="${1:-Qwen}"
    
    clear
    
    while true; do
        # Provider URLs for API key registration
        local nim_url="https://build.nvidia.com/api-key"
        local zai_url="https://console.z.ai/"
        local groq_url="https://console.groq.com/keys"
        local openrouter_url="https://openrouter.ai/settings/keys"

        # Заголовок меню
        local title="Сменить ключ API провайдера"
        local subtitle="Выберите провайдер"
        
        case "$app_brand" in
            "Qwen")
                local banner_color="$CYAN"
                ;;
            "Claude")
                local banner_color="$MAGENTA"
                ;;
            *)
                local banner_color="$CYAN"
                ;;
        esac
        
        clear
        echo -e "${banner_color}╔══════════════════════════════════════════════════════════════════════════════╗${RESET}"
        echo -e "${banner_color}║                                                                        ║${RESET}"
        
        if [ "$app_brand" = "Qwen" ]; then
            echo -e "${banner_color}║            ██████╗ ██╗    ██╗███████╗███╗   ██╗                        ║${RESET}"
            echo -e "${banner_color}║           ██╔═══██╗██║    ██║██╔════╝████╗  ██║                        ║${RESET}"
            echo -e "${banner_color}║           ██║   ██║██║ █╗ ██║█████╗  ██╔██╗ ██║                        ║${RESET}"
            echo -e "${banner_color}║           ██║▄▄ ██║██║███╗██║██╔══╝  ██║╚██╗██║                        ║${RESET}"
            echo -e "${banner_color}║           ╚██████╔╝╚███╔███╔╝███████╗██║ ╚████║                        ║${RESET}"
            echo -e "${banner_color}║            ╚══▀▀═╝  ╚══╝╚══╝ ╚══════╝╚═╝  ╚═══╝                        ║${RESET}"
        else
            echo -e "${banner_color}║   ██████╗██╗     ██╗      █████╗ ██╗   ██╗██████╗ ███████╗             ║${RESET}"
            echo -e "${banner_color}║  ██╔════╝██║     ██║     ██╔══██╗██║   ██║██╔══██╗██╔════╝             ║${RESET}"
            echo -e "${banner_color}║  ██║     ██║     ██║     ███████║██║   ██║██║  ██║█████╗               ║${RESET}"
            echo -e "${banner_color}║  ██║     ██║     ██║     ██╔══██║██║   ██║██║  ██║██╔══╝               ║${RESET}"
            echo -e "${banner_color}║  ╚██████╗███████╗███████╗██║  ██║╚██████╔╝██████╔╝███████╗             ║${RESET}"
            echo -e "${banner_color}║   ╚═════╝╚══════╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚═════╝ ╚══════╝             ║${RESET}"
        fi
        
        echo -e "${banner_color}║                                                                        ║${RESET}"
        echo -e "${banner_color}╠════════════════════════════════════════════════════════════════════════════╣${RESET}"
        echo -e "${banner_color}║ $title                                                                ║${RESET}"
        echo -e "${banner_color}║ $subtitle                                                             ║${RESET}"
        echo -e "${banner_color}╠════════════════════════════════════════════════════════════════════════════╣${RESET}"
        echo -e "${banner_color}║                                                                        ║${RESET}"
        echo -e "${banner_color}║   [1] NVIDIA NIM API ключ                                              ║${RESET}"
        echo -e "${banner_color}║       $nim_url                                   ║${RESET}"
        echo -e "${banner_color}║   [2] Z.AI API ключ                                                   ║${RESET}"
        echo -e "${banner_color}║       $zai_url                                           ║${RESET}"
        echo -e "${banner_color}║   [3] Groq API ключ                                                   ║${RESET}"
        echo -e "${banner_color}║       $groq_url                                     ║${RESET}"
        echo -e "${banner_color}║   [4] OpenRouter API ключ                                             ║${RESET}"
        echo -e "${banner_color}║       $openrouter_url                           ║${RESET}"
        echo -e "${banner_color}║   [0] Назад                                                           ║${RESET}"
        echo -e "${banner_color}║                                                                        ║${RESET}"
        echo -e "${banner_color}║                                                                        ║${RESET}"
        echo -e "${banner_color}╚════════════════════════════════════════════════════════════════════════════╝${RESET}"
        echo -ne "${GRAY}Ваш выбор: ${RESET}"
        
        read -r choice
        
        case "$choice" in
            1)
                provider_id="nim"
                provider_name="NVIDIA NIM"
                env_var_name="NVIDIA_NIM"
                provider_url="$nim_url"
                ;;
            2)
                provider_id="zai"
                provider_name="Z.AI"
                env_var_name="ZAI"
                provider_url="$zai_url"
                ;;
            3)
                provider_id="groq"
                provider_name="Groq"
                env_var_name="GROQ"
                provider_url="$groq_url"
                ;;
            4)
                provider_id="openrouter"
                provider_name="OpenRouter"
                env_var_name="OPENROUTER"
                provider_url="$openrouter_url"
                ;;
            0|"")
                return 0
                ;;
            *)
                echo -e "${RED}Неверный выбор${RESET}"
                sleep 1
                continue
                ;;
        esac
        
        current_key=$(get_current_api_key "$env_var_name")
        
        clear
        echo -e "${CYAN}Провайдер: $provider_name${RESET}"
        if [ -z "$current_key" ]; then
            echo -e "${YELLOW}Текущий ключ: (не задан)${RESET}"
        else
            if [ ${#current_key} -gt 12 ]; then
                masked="${current_key:0:6}...${current_key: -6}"
            else
                masked="***"
            fi
            echo -e "${GREEN}Текущий ключ: $masked${RESET}"
        fi
        echo ""
        echo -e "${CYAN}Получить ключ: $provider_url${RESET}"
        echo ""
        
        new_key=$(read_secret_text "Введите новый API ключ (или оставьте пустым для отмены): ")
        
        if [ -z "$new_key" ]; then
            echo -e "${YELLOW}Отмена — ключ не изменён.${RESET}"
            read -p "Нажмите Enter для продолжения..."
            continue
        fi
        
        if set_provider_api_key "$env_var_name" "$new_key"; then
            echo ""
            read -p "Нажмите Enter для продолжения..."
        else
            echo ""
            read -p "Нажмите Enter для продолжения..."
        fi
    done
}
