# Ручная установка: пошаговое руководство

Полная инструкция для ручного развёртывания **Qwen Code**, **Claude Code**, **OpenCode**, **Freebuff** и **OpenClaude** с облачными провайдерами **NVIDIA NIM**, **Z.AI**, **B.AI**, **Groq** и **OpenRouter** на **Windows** и **Linux**.

---

## Оглавление

1. [Архитектура](#1-архитектура)
2. [Требования](#2-требования)
3. [Клонирование / Bootstrap](#3-клонирование--bootstrap)
4. [Установка CLI](#4-установка-cli)
5. [Настройка API ключей](#5-настройка-api-ключей)
6. [Профили сессий](#6-профили-сессий)
7. [free-claude-code для Claude Code → NIM / OpenRouter / B.AI / Groq](#7-free-claude-code-для-claude-code--nim--openrouter--ba-i--groq)
8. [claude-mem (опционально)](#8-claude-mem-опционально)
9. [Создание ярлыков](#9-создание-ярлыков)
10. [Управление API ключами через TUI](#10-управление-api-ключами-через-tui)
11. [Нативный логин](#11-нативный-логин)
12. [Проверка установки](#12-проверка-установки)
13. [Устранение проблем](#13-устранение-проблем)
14. [Быстрый чеклист](#14-быстрый-чеклист)

---

## 1. Архитектура

```
┌───────────────────────────────────────────────────────────────────┐
│                          Рабочая станция                          │
│                                                                   │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐            │
│  │  Qwen Code   │  │  Claude Code │  │   OpenCode   │            │
│  │  (OpenAI)    │  │  (Anthropic) │  │   (OpenAI)   │            │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘            │
│         │                 │                 │                    │
│  ┌──────┴───────┐  ┌──────┴───────┐         │                    │
│  │  Direct HTTPS │  │ free-claude- │         │                    │
│  │  NIM/Groq/etc │  │ code :8082+  │         │                    │
│  └──────────────┘  └──────────────┘         │                    │
│                                                                   │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐            │
│  │   Freebuff   │  │  OpenClaude  │  │  claude-mem  │            │
│  │  (context   │  │  (OpenAI     │  │  (optional,  │            │
│  │   logger)   │  │   proxy)    │  │   port 37777)│            │
│  └──────────────┘  └──────────────┘  └──────────────┘            │
└───────────────────────────────────────────────────────────────────┘
         │               │               │               │
         ▼               ▼               ▼               ▼
  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
  │  Z.AI        │ │  NVIDIA NIM  │ │   B.AI       │ │   Groq       │
  │  api.z.ai    │ │  integrate   │ │  api.b.ai    │ │  api.groq    │
  │  (OpenAI +   │ │  .api.nvidia │ │  (OpenAI-    │ │  (OpenAI,    │
  │   Anthropic) │ │  .com / v1)  │ │   compat.)   │ │   TPM лимит) │
  └──────────────┘ └──────────────┘ └──────────────┘ └──────────────┘
                              │
                              ▼
                    ┌──────────────┐
                    │  OpenRouter  │
                    │  (бесплатные │
                    │   модели)    │
                    └──────────────┘
```

**Потоки данных:**

| CLI | Провайдер | Протокол |
|-----|-----------|----------|
| Qwen Code | Z.AI | Прямой HTTPS → `https://api.z.ai/api/openai/v1` |
| Qwen Code | NVIDIA NIM | Прямой HTTPS → `https://integrate.api.nvidia.com/v1` |
| Qwen Code | Groq | Прямой HTTPS → `https://api.groq.com/openai/v1` (режим `--bare`) |
| Qwen Code | OpenRouter | Прямой HTTPS → `https://openrouter.ai/api/v1` |
| Qwen Code | B.AI | Прямой HTTPS → `https://api.b.ai/v1` |
| Claude Code | Z.AI | Прямой HTTPS → `https://api.z.ai/api/anthropic` |
| Claude Code | NVIDIA NIM | free-claude-code `127.0.0.1:8082` → NIM |
| Claude Code | OpenRouter | free-claude-code `127.0.0.1:8084` → OpenRouter |
| Claude Code | B.AI | free-claude-code `127.0.0.1:8085` → B.AI |
| Claude Code | Groq | free-claude-code `127.0.0.1:8086` → Groq |
| OpenCode | Z.AI | Прямой HTTPS → `https://api.z.ai/api/openai/v1` |
| OpenCode | NVIDIA NIM | Прямой HTTPS → `https://integrate.api.nvidia.com/v1` |
| OpenCode | Groq | Прямой HTTPS → `https://api.groq.com/openai/v1` |
| OpenCode | OpenRouter | Прямой HTTPS → `https://openrouter.ai/api/v1` |
| OpenCode | B.AI | Прямой HTTPS → `https://api.b.ai/v1` |
| Freebuff | N/A | Прямой запуск (не требует API) |
| OpenClaude | Z.AI | Прямой HTTPS → `https://api.z.ai/api/anthropic` (OpenAI-режим через env) |
| OpenClaude | NVIDIA NIM | OpenAI-режим через env → NIM |
| OpenClaude | Groq | OpenAI-режим через env → Groq |
| OpenClaude | OpenRouter | OpenAI-режим через env → OpenRouter |
| OpenClaude | B.AI | OpenAI-режим через env → B.AI |

---

## 2. Требования

### Обязательные

| Инструмент | Windows | Linux |
|-----------|---------|-------|
| **Git** | [git-scm.com](https://git-scm.com/download/win) | `sudo apt install git` |
| **Node.js** LTS (18+) | [nodejs.org](https://nodejs.org/) | `sudo apt install nodejs npm` или [nvm](https://github.com/nvm-sh/nvm) |
| **npm** | Ставится с Node.js | Ставится с Node.js |
| **Python 3.10+** | Для free-claude-code (устанавливается автоматически через `uv`) | Для free-claude-code |

### Для Claude Code + NIM / OpenRouter / B.AI / Groq

| Инструмент | Назначение |
|-----------|-----------|
| **uv** ([docs.astral.sh/uv](https://docs.astral.sh/uv/)) | Запуск free-claude-code |
| **free-claude-code** | Прокси Claude→NIM/OpenRouter/B.AI/Groq |

### Для OpenClaude

| Инструмент | Назначение |
|-----------|-----------|
| **jq** | Парсинг JSON в лаунчере (`sudo apt install jq`) |

### Опционально

| Инструмент | Назначение |
|-----------|-----------|
| **claude-mem** | Память для Claude Code (порт 37777) |
| **Obsidian** | Хранилище сессий Claude |
| **curl** | Для API запросов в мастере моделей |
| **nc / ss** | Проверка портов (Linux) |
| **netstat** | Проверка портов (Windows) |

---

## 3. Клонирование / Bootstrap

### Способ 1: 1-click скрипт

**Windows:**
```powershell
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
irm https://raw.githubusercontent.com/chelaxian/CLI-CODES/main/install.ps1 | iex
```

**Linux:**
```bash
curl -fsSL https://raw.githubusercontent.com/chelaxian/CLI-CODES/main/bootstrap.sh | bash
```

> `bootstrap.sh` автоматически определит ОС (Linux/macOS/Windows) и запустит нужный инсталлятор.

### Способ 2: git clone

**Windows (PowerShell):**
```powershell
git clone https://github.com/chelaxian/CLI-CODES.git
cd CLI-CODES
```

**Linux:**
```bash
git clone https://github.com/chelaxian/CLI-CODES.git
cd CLI-CODES
chmod +x scripts/*.sh
```

Далее в инструкции: **`$REPO_ROOT`** — корень клонированного репозитория.

---

## 4. Установка CLI

### Qwen Code

```bash
# Windows / Linux
npm install -g @qwen-code/qwen-code@latest
```

Проверка:
```bash
qwen --help
```

### Claude Code

```bash
# Windows / Linux
npm install -g @anthropic-ai/claude-code@latest
```

Проверка:
```bash
claude --help
```

### OpenCode

```bash
# Windows / Linux
npm install -g opencode-ai@latest
```

Проверка:
```bash
opencode --help
```

### Freebuff

```bash
# Windows / Linux
npm install -g freebuff@latest
```

Проверка:
```bash
freebuff --help
```

> Freebuff — CLI для логирования и контекст-менеджмента. Запускается напрямую через лаунчер (без TUI меню).

### OpenClaude

```bash
# Windows / Linux
npm install -g @gitlawb/openclaude@latest
```

Проверка:
```bash
openclaude --help
```

> OpenClaude — форк Claude Code с поддержкой OpenAI-совместимых провайдеров (NIM, Groq, OpenRouter, B.AI).

---

## 5. Настройка API ключей

### Где взять ключи

| Провайдер | Регистрация | Бесплатно |
|-----------|-------------|-----------|
| **NVIDIA NIM** | [build.nvidia.com](https://build.nvidia.com/) | Да, с лимитами |
| **Z.AI** | [open.bigmodel.cn](https://open.bigmodel.cn/) | Да, с лимитами |
| **B.AI** | [chat.b.ai/key](https://chat.b.ai/key) | Да, с лимитами |
| **Groq** | [console.groq.com](https://console.groq.com/) | Да, 14400 запросов/день |
| **OpenRouter** | [openrouter.ai](https://openrouter.ai/) | Да, бесплатные модели |

### Windows: переменные пользователя

**Способ 1 — через лаунчер:**

Запустите ярлык и выберите "Сменить ключ API провайдера".

**Способ 2 — через PowerShell:**

```powershell
[Environment]::SetEnvironmentVariable("NVIDIA_NIM_API_KEY", "ваш_ключ", "User")
[Environment]::SetEnvironmentVariable("ZAI_API_KEY", "ваш_ключ", "User")
[Environment]::SetEnvironmentVariable("BAI_API_KEY", "ваш_ключ", "User")
[Environment]::SetEnvironmentVariable("GROQ_API_KEY", "ваш_ключ", "User")
[Environment]::SetEnvironmentVariable("OPENROUTER_API_KEY", "ваш_ключ", "User")
```

**Способ 3 — через GUI:**

1. Win+R → `sysdm.cpl` → Дополнительно → Переменные среды
2. Добавьте пользовательские переменные `NVIDIA_NIM_API_KEY`, `ZAI_API_KEY`, `BAI_API_KEY`, `GROQ_API_KEY`, `OPENROUTER_API_KEY`

### Linux: ~/.bashrc / ~/.zshrc

```bash
export NVIDIA_NIM_API_KEY="ваш_ключ"
export ZAI_API_KEY="ваш_ключ"
export BAI_API_KEY="ваш_ключ"
export GROQ_API_KEY="ваш_ключ"
export OPENROUTER_API_KEY="ваш_ключ"

source ~/.bashrc
```

### Нативный логин (без API-ключей)

Каждый лаунчер поддерживает авторизацию через нативный OAuth/браузер:

| Лаунчер | Пункт меню | Команда |
|---------|-----------|---------|
| **Qwen Code** | Нативный логин → Qwen OAuth | `qwen auth qwen-oauth` (браузер, автоматически) |
| **Qwen Code** | Нативный логин → Coding Plan | `qwen auth coding-plan` (API-ключ Alibaba Cloud, автоматически) |
| **Qwen Code** | Нативный логин → Запуск Qwen Code | `qwen` |
| **Claude Code** | Нативный логин → Claude подписка | `claude auth login --claudeai` (OAuth, браузер) |
| **Claude Code** | Нативный логин → Anthropic Console | `claude auth login --console` (API-биллинг, браузер) |
| **Claude Code** | Нативный логин → Запуск Claude Code | `claude` |
| **OpenCode** | Нативный логин → Вход через провайдера | `opencode providers login` (автоматически) |
| **OpenCode** | Нативный логин → Показать провайдеров | `opencode providers list` (автоматически) |
| **OpenCode** | Нативный логин → Запуск OpenCode | `opencode` |
| **OpenClaude** | Нативный логин → vanilla | `openclaude` (без env) |

Для использования нативного логина требуется платная подписка на соответствующий сервис.

### Переменные окружения (справка)

| Переменная | Назначение |
|-----------|-----------|
| `NVIDIA_NIM_API_KEY` | Доступ к NVIDIA NIM API |
| `ZAI_API_KEY` | Z.AI Coding / Anthropic-совместимые вызовы |
| `BAI_API_KEY` | B.AI API (OpenAI-compatible) |
| `GROQ_API_KEY` | Groq API (бесплатно, 14400 запросов/день) |
| `OPENROUTER_API_KEY` | OpenRouter API (бесплатные и платные модели) |

**Не коммитьте значения ключей в git.**

---

## 6. Профили сессий

### Qwen Code

Директория: `$REPO_ROOT/qwen-sessions/`

Сессии разделены по провайдерам. Для большинства пресетов лаунчер автоматически создаёт контекст через динамические скрипты (`run-qwen-code-dynamic.ps1/sh`).

**Примеры существующих сессий:**

| Папка | Провайдер | Модель |
|-------|-----------|--------|
| `zai-glm47/` | Z.AI | GLM-4.7 (OpenAI-совместимый) |
| `nim-glm-47/` | NVIDIA NIM | GLM-4.7 (прямой HTTPS) |
| `nim-deepseek-v31/` | NVIDIA NIM | DeepSeek V3.1 |
| `_dynamic/` | Любой | Динамический выбор через лаунчер |

### Claude Code

Директория: `$REPO_ROOT/claude-sessions/_shared/`

Общие сессии для всех профилей. Launcher переключает env-переменные и запускает `claude` из этой директории.

### OpenCode

Директория: `$REPO_ROOT/opencode-sessions/_shared/`

Launcher генерирует `opencode.json` с указанием провайдера и модели. Конфиг автоматически перезаписывается при выборе нового профиля.

### Freebuff

Freebuff не использует директории сессий в репо — сам управляет контекстом и историей.

### OpenClaude

OpenClaude хранит профили в `~/.openclaude.json` (не в репо). Launcher записывает `providerProfiles` и `activeProviderProfileId`.

---

## 7. free-claude-code для Claude Code → NIM / OpenRouter / B.AI / Groq

**Для Claude Code + NIM или OpenRouter требуется free-claude-code прокси.** Если вы используете только Z.AI — пропустите этот шаг (Z.AI поддерживает Anthropic API напрямую).

### Установка

free-claude-code устанавливается автоматически через инсталлятор при выборе Claude Code. При ручной установке:

**Windows / Linux:**
```bash
# uv (если нет)
# Windows: irm https://astral.sh/uv/install.ps1 | iex
# Linux:   curl -LsSf https://astral.sh/uv/install.sh | sh

# Клонируйте free-claude-code в домашнюю директорию
git clone https://github.com/Alishahryar1/free-claude-code.git ~/.free-claude-code

# Установите зависимости
cd ~/.free-claude-code
uv sync
```

### Порты по умолчанию

| Провайдер | Порт |
|-----------|------|
| NVIDIA NIM | 8082 |
| OpenRouter | 8084 |
| B.AI | 8085 |
| Groq | 8086 |

### Запуск прокси

Скрипт `run-claude-cloud-session.ps1` (или `.sh`) автоматически запускает free-claude-code при выборе профиля NIM/OpenRouter/B.AI/Groq в лаунчере.

Для отладки/ручного запуска:

**NIM:**
```bash
cd ~/.free-claude-code
NVIDIA_NIM_API_KEY="ваш_ключ" MODEL="nvidia_nim/z-ai/glm-5.1" ANTHROPIC_AUTH_TOKEN="freecc" \
  uv run uvicorn server:app --host 127.0.0.1 --port 8082
```

**OpenRouter:**
```bash
cd ~/.free-claude-code
OPENROUTER_API_KEY="ваш_ключ" MODEL="open_router/deepseek/deepseek-chat-v3.1:free" ANTHROPIC_AUTH_TOKEN="freecc" \
  uv run uvicorn server:app --host 127.0.0.1 --port 8084
```

---

## 8. claude-mem (опционально)

Память для Claude Code — воркер на `127.0.0.1:37777`.

### Установка

```bash
npx claude-mem start
```

### Проверка

Откройте в браузере: `http://127.0.0.1:37777/`

### Очистка

```powershell
# Windows
.\scripts\clear-claude-mem.ps1
```

---

## 9. Создание ярлыков

### Автоматически (рекомендуется)

**Windows:**
```powershell
cd $REPO_ROOT
.\install.ps1
```

**Linux:**
```bash
cd $REPO_ROOT
./install.sh
```

Инсталлятор создаст/обновит ярлыки автоматически.

### Ручная сборка ярлыков

#### Windows

После установки через `install.ps1` ярлыки создаются автоматически в скрытой папке `Desktop\Cloud Launchers\`:

- **Qwen Code (cloud).cmd / .lnk**
- **Claude Code (cloud).cmd / .lnk**
- **OpenCode (cloud).cmd / .lnk**
- **Freebuff (cloud).cmd / .lnk**
- **OpenClaude (cloud).cmd / .lnk**

На рабочем столе остаётся по одному `.lnk` на каждый инструмент (без приставки `(cloud)`), который points на скрытую папку.

#### Linux

Создаются `.sh` в `~/` и `.desktop` на рабочем столе:

```bash
REPO_ROOT="$HOME/CLI-CODES"
SCRIPTS="$REPO_ROOT/scripts"
DESKTOP="$HOME/Desktop"
[ -d "$DESKTOP" ] || DESKTOP="$HOME"

for entry in \
  "Qwen Code:run-qwen-code-launcher.sh" \
  "Claude Code:run-claude-cloud-launcher.sh" \
  "OpenCode:run-opencode-launcher.sh" \
  "Freebuff:run-freebuff-launcher.sh" \
  "OpenClaude:run-openclaude-launcher.sh"; do
  
  name="${entry%%:*}"
  script="${entry##*:}"
  
  cat > "$HOME/${name,,}.sh" << EOF
#!/bin/bash
exec bash "$SCRIPTS/$script" "\$@"
EOF
  chmod +x "$HOME/${name,,}.sh"
  
  cat > "$DESKTOP/$name.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=$name
Exec=bash "$SCRIPTS/$script"
Path=$REPO_ROOT
Terminal=true
StartupNotify=true
Categories=Development;
EOF
  chmod +x "$DESKTOP/$name.desktop"
done
```

---

## 10. Управление API ключами через TUI

Во всех лаунчерах (Qwen Code, Claude Code, OpenCode, OpenClaude) есть встроенное меню для смены API ключей:

1. Запустите ярлык
2. Выберите **«Сменить ключ API провайдера»**
3. Выберите провайдера: **NVIDIA NIM**, **Z.AI**, **B.AI**, **Groq** или **OpenRouter**
4. Текущий ключ показан замаскированным
5. Введите новый ключ (скрытый ввод)
6. **ESC** — вернуться в предыдущее меню

Ключи сохраняются:
- **Windows**: в переменных пользователя (`[Environment]::SetEnvironmentVariable`)
- **Linux**: в `~/.bashrc` и `~/.zshrc` через helper-функции `launcher-api-keys.sh`

---

## 11. Нативный логин

Каждый лаунчер поддерживает нативную авторизацию (OAuth через браузер).

### Qwen Code

| Способ | Описание |
|--------|----------|
| **Qwen OAuth** | Авторизация через браузер (подписка Qwen) |
| **Coding Plan** | Alibaba Cloud Coding Plan (API-ключ, регионы china/global) |

Выберите в меню **«Нативный логин (Qwen OAuth / Coding Plan)»** → нужный способ.

### Claude Code

| Способ | Описание |
|--------|----------|
| **Claude подписка** | OAuth через браузер (Claude Pro / Max) |
| **Anthropic Console** | API-биллинг через Anthropic Console |

Выберите в меню **«Нативный логин (Anthropic OAuth / Console)»** → нужный способ.

### OpenCode

Интерактивное меню `opencode providers login` с выбором провайдера и метода входа.

Выберите в меню **«Нативный логин (OpenCode Providers)»** → нужное действие.

### OpenClaude

Выберите **«Нативный запуск (vanilla / Opengateway)»** — запускает `openclaude` без предустановленных env-переменных (очищает все cloud-переменные).

---

## 12. Проверка установки

### Проверка зависимостей

```bash
git --version
node --version
npm --version
qwen --help
claude --help
opencode --help
freebuff --help
openclaude --help
```

### Проверка API ключей

**Windows:**
```powershell
[Environment]::GetEnvironmentVariable("NVIDIA_NIM_API_KEY", "User")
[Environment]::GetEnvironmentVariable("ZAI_API_KEY", "User")
[Environment]::GetEnvironmentVariable("BAI_API_KEY", "User")
[Environment]::GetEnvironmentVariable("GROQ_API_KEY", "User")
[Environment]::GetEnvironmentVariable("OPENROUTER_API_KEY", "User")
```

**Linux:**
```bash
echo $NVIDIA_NIM_API_KEY
echo $ZAI_API_KEY
echo $BAI_API_KEY
echo $GROQ_API_KEY
echo $OPENROUTER_API_KEY
```

### Проверка free-claude-code (если установлен)

```bash
curl http://127.0.0.1:8082/v1/models  # NIM
curl http://127.0.0.1:8084/v1/models  # OpenRouter
curl http://127.0.0.1:8085/v1/models  # B.AI
curl http://127.0.0.1:8086/v1/models  # Groq
```

### Проверка OpenCode config (если установлен)

```bash
cat $REPO_ROOT/opencode-sessions/_shared/opencode.json
```

### Быстрые тесты

**Qwen Code:**
```bash
cd $REPO_ROOT/qwen-sessions/zai-glm47
qwen
```

**Claude Code:**
```bash
cd $REPO_ROOT/claude-sessions/_shared
claude
```

---

## 13. Устранение проблем

### Windows: «Политика выполнения скриптов»

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Linux: «Permission denied»

```bash
chmod +x $REPO_ROOT/scripts/*.sh
```

### Ключи не подхватываются

**Windows**: Перезапустите терминал (новое окно PowerShell).

**Linux**: Выполните `source ~/.bashrc` или откройте новый терминал.

### free-claude-code не стартует

1. Проверьте что `uv` установлен: `uv --version`
2. Проверьте что зависимости установлены: `cd ~/.free-claude-code && uv sync`
3. Проверьте что порт не занят:
   - **Linux**: `ss -ltnp | grep 8082`
   - **Windows**: `netstat -an | findstr 8082`

### Claude Code: модели не в белом списке

Для моделей **вне белого списка** Claude Code запускается с `--tools minimal`. Белый список:
- `z-ai/glm5.1`
- `z-ai/glm4.7`
- `qwen/qwen3.5-122b-a10b`

### NIM: «Model not found» / 404

Убедитесь что модель доступна в [NIM каталоге](https://build.nvidia.com/models). Некоторые модели требуют специальный доступ.

### B.AI: конфиг и переменные

B.AI работает через OpenAI-совместимый эндпоинт `https://api.b.ai/v1`:
- Для Qwen Code/OpenCode/OpenClaude: прямой HTTPS
- Для Claude Code: через free-claude-code (порт 8085) с `OPENAI_BASE_URL="https://api.b.ai/v1"`

### Groq: «Request too large» / TPM limit exceeded

Groq бесплатный тариф имеет жёсткие лимиты TPM (6000-12000 токенов в минуту). Системный промпт агента (~20-30K токенов) **превышает лимит**.

Решение:
- **Qwen Code**: запуск в режиме чата (`--bare`, без инструментов)
- **OpenCode**: урезанный контекст `maxTokens=2048`, `contextLength=4096`

Для полноценной работы агента используйте **Z.AI**, **NVIDIA NIM** или **OpenRouter**.

### OpenRouter: «403 Provider returned error» / «429 Too Many Requests»

OpenRouter имеет лимиты: ~20 RPM, ~50 RPD для бесплатных моделей. Лаунчеры автоматически урезают контекст:
- **Qwen Code**: `contextWindowSize=16384`, `max_tokens=8192`, `skipStartupContext=true`
- **OpenCode**: `maxTokens=8192`, `contextLength=16384`
- **Claude Code**: через free-claude-code сrate-limit на стороне прокси

Если ошибка повторяется — подождите или используйте платный API-ключ.

### Очистка памяти claude-mem

```powershell
# Windows
.\scripts\clear-claude-mem.ps1
```

---

## 14. Быстрый чеклист

### Минимальная установка (только Qwen + Z.AI)

- [ ] Git установлен
- [ ] Node.js + npm установлены
- [ ] Qwen Code CLI: `npm i -g @qwen-code/qwen-code`
- [ ] Claude Code CLI: `npm i -g @anthropic-ai/claude-code`
- [ ] OpenCode CLI: `npm i -g opencode-ai`
- [ ] Freebuff CLI: `npm i -g freebuff`
- [ ] OpenClaude CLI: `npm i -g @gitlawb/openclaude`
- [ ] Репозиторий клонирован
- [ ] `ZAI_API_KEY` задан
- [ ] Ярлыки созданы (через `install.ps1` / `install.sh`)

### Полная установка (все провайдеры)

- [ ] Всё из минимальной установки
- [ ] `NVIDIA_NIM_API_KEY` задан
- [ ] `BAI_API_KEY` задан
- [ ] `GROQ_API_KEY` задан
- [ ] `OPENROUTER_API_KEY` задан
- [ ] free-claude-code установлен (`~/.free-claude-code`)
- [ ] uv установлен (для free-claude-code)
- [ ] (Опционально) claude-mem запущен (`:37777`)
- [ ] (Опционально) Obsidian установлен

---

## Дополнительные ресурсы

- **Репозиторий**: [github.com/chelaxian/CLI-CODES](https://github.com/chelaxian/CLI-CODES)
- **NVIDIA NIM**: [build.nvidia.com](https://build.nvidia.com/)
- **Z.AI**: [open.bigmodel.cn](https://open.bigmodel.cn/)
- **B.AI**: [chat.b.ai](https://chat.b.ai/)
- **Groq**: [console.groq.com](https://console.groq.com/)
- **OpenRouter**: [openrouter.ai](https://openrouter.ai/)
- **free-claude-code**: [github.com/Alishahryar1/free-claude-code](https://github.com/Alishahryar1/free-claude-code)
