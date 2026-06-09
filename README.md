# cloud-code-setup

**1-click развёртывание Qwen Code, Claude Code, OpenCode, OpenClaude и Freebuff с облачными моделями (NVIDIA NIM, Z.AI, B.AI, OpenRouter, Groq)**

Работает на Windows и Linux. Устанавливается одной командой в терминале.

<img width="1600" height="800" alt="ezgif-4dd52e4654358b8a" src="https://github.com/user-attachments/assets/45e2e8f6-040f-49e0-987c-ac0e11b1d9ed" />
---

## Быстрая установка

### Windows (PowerShell)

```powershell
irm https://raw.githubusercontent.com/chelaxian/cloud-code-setup/main/install.ps1 | iex
```

### Linux / macOS

```bash
sudo curl -fsSL https://raw.githubusercontent.com/chelaxian/cloud-code-setup/main/bootstrap.sh | bash
```

Или вручную:

```bash
git clone https://github.com/chelaxian/cloud-code-setup.git
cd cloud-code-setup
./install.sh          # Linux
.\install.ps1         # Windows
```

---

## Что делает инсталлятор

1. **Проверяет зависимости** — git, Node.js, npm (автоустановка через winget/choco/scoop на Windows)
2. **Спрашивает** что установить: Qwen Code, Claude Code, OpenCode, OpenClaude, Freebuff или все инструменты
3. **Устанавливает CLI** через npm (если не установлен)
4. **Запрашивает API ключи** (все можно пропустить):
   - NVIDIA NIM, Z.AI, Groq, OpenRouter, B.AI
5. **Создаёт ярлыки** на рабочем столе (Windows) / в `~` (Linux)
6. **Настраивает профили сессий** для `/resume`

Дополнительные пункты меню:

- **[7] Обновление всех компонентов** — обновляет npm-пакеты и **синхронизирует ярлыки**
- **[8] Удаление** — полная очистка (репозиторий, npm-пакеты, конфиги, ключи, ярлыки)
- **[9] Добавить недостающие ярлыки** — просканирует установленные CLI и дополнит ярлыки

---

## Документация

| Документ | Описание |
|----------|----------|
| [docs/MANUAL-SETUP.md](docs/MANUAL-SETUP.md) | Полное пошаговое руководство по ручной установке (Windows + Linux) |
| [docs/DEPLOY-FROM-SCRATCH.md](docs/DEPLOY-FROM-SCRATCH.md) | Развёртывание с нуля с полными текстами скриптов |

---

## Поддерживаемые CLI

| CLI | npm-пакет | Описание |
|-----|-----------|----------|
| **Qwen Code** | `qwen-code` | Coding agent от Alibaba |
| **Claude Code** | `@anthropic-ai/claude-code` | Официальный Anthropic CLI |
| **OpenCode** | `opencode-ai` | Open-source coding agent |
| **OpenClaude** | `@gitlawb/openclaude` | Форк Claude Code с provider profiles |
| **Freebuff** | `freebuff` | Coding agent от Codebuff (собственный TUI) |

Все CLI, кроме Freebuff, запускаются через единообразное **TUI-меню** с псевдографикой, навигацией стрелками и динамической загрузкой каталогов моделей. Freebuff запускается напрямую (встроенный picker конфликтует с нашим TUI).

---

## Провайдеры и модели

Все модели доступны из главного меню лаунчера. Каталоги обновляются динамически через API провайдера (с static fallback при отсутствии ключа).

### Z.AI (paid + free flash, tool calling)

| Модель | Qwen | Claude | OpenCode | OpenClaude |
|--------|------|--------|----------|------------|
| GLM-5.1 | + | + | + | + |
| GLM-4.7 | + | + | + | + |
| GLM-4.7-Flash (free) | + | + | + | + |

### NVIDIA NIM (free, 9 agentic моделей)

| Модель | Qwen | Claude | OpenCode | OpenClaude |
|--------|------|--------|----------|------------|
| Mistral Medium 3.5 128B | + | + | + | + |
| GLM-5.1 | + | + | + | + |
| Step 3.5 Flash | + | + | + | + |
| Mistral Large 3 675B | + | + | + | + |
| DeepSeek V4 Flash 284B MoE | + | + | + | + |
| Gemma-4 31B | + | + | + | + |
| Qwen 3.5 397B A17B | + | + | + | + |
| Qwen 3 Next 80B A3B | + | + | + | + |
| Qwen 3 Coder 480B A35B | + | + | + | + |

### B.AI (26 agentic моделей, OpenAI-compatible)

В подменю B.AI модели с поддержкой tool/function calling:

**OpenAI GPT-5 (9):** Nano, Mini, 5.2, 5.4 Nano/Mini/Pro, 5.5, 5.5 Instant

**Anthropic Claude (7):** Haiku 4.5, Sonnet 4.5/4.6, Opus 4.5/4.6/4.7/4.8

**Другие agentic (10):** DeepSeek V4 Pro/Flash, Gemini 3.1 Pro/3.5 Flash, GLM-5/5.1, Kimi K2.5/K2.6, MiniMax M3/M2.7

> Полный каталог B.AI (28 моделей, включая DeepSeek V3.2 и Gemini 3 Flash) доступен через **«Другая модель» → B.AI**.

### OpenRouter (free, tool calling)

| Модель | Qwen | Claude | OpenCode | OpenClaude |
|--------|------|--------|----------|------------|
| DeepSeek V4 Flash | + | + | + | + |
| Qwen3 Coder | + | + | + | + |
| Nemotron 3 Super 120B | + | + | + | + |
| Poolside Laguna M.1 | + | + | + | + |

### Groq (paid, через «Другая модель»)

> Free Tier Groq ограничен TPM 6000/8000 — недостаточно для coding agent. Требуется Paid подписка.

---

## Где взять API ключи

| Провайдер | URL | Тип |
|-----------|-----|-----|
| **NVIDIA NIM** | [build.nvidia.com](https://build.nvidia.com/) | Free |
| **Z.AI** | [console.z.ai](https://console.z.ai/) / [open.bigmodel.cn](https://open.bigmodel.cn/) | Paid |
| **B.AI** | [chat.b.ai/key](https://chat.b.ai/key) | Free/Paid |
| **OpenRouter** | [openrouter.ai](https://openrouter.ai/) | Free/Paid |
| **Groq** | [console.groq.com](https://console.groq.com/) | Free (limited) |

---

## После установки

### Запуск

**Windows** — дважды кликните на ярлык на рабочем столе:

- **Qwen Code** — меню выбора модели/провайдера
- **Claude Code** — меню выбора провайдера
- **OpenCode** — меню выбора провайдера
- **OpenClaude** — меню выбора провайдера
- **Freebuff** — прямой запуск (собственный TUI)

**Linux** — запуск через `.sh` файлы в `~/`:

```bash
~/openclaude-cloud.sh
~/claude-cloud.sh
~/qwen-code-cloud.sh
~/opencode-cloud.sh
~/freebuff-cloud.sh
```

### Быстрый старт

Каждый лаунчер запоминает последний выбранный профиль. При повторном запуске выбирайте **«Запустить с последними настройками»** — модель и провайдер подхватятся автоматически.

### Смена API ключей

В меню лаунчера: **«Сменить ключ API провайдера»** → выберите провайдера → введите новый ключ.

### Нативный логин (OAuth)

| CLI | Способ |
|-----|--------|
| **Qwen Code** | Qwen OAuth или Alibaba Cloud Coding Plan |
| **Claude Code** | Claude подписка (OAuth) или Anthropic Console |
| **OpenCode** | `opencode providers login` |
| **OpenClaude** | Vanilla / Opengateway |

### Другая модель

Пункт **«Другая модель…»** позволяет выбрать любую модель из полного каталога провайдера (загружается через API по вашему ключу). Для NIM есть фильтр **«только Agentic модели»**. Для OpenRouter — **только бесплатные**.

---

## Архитектура подключения

| CLI | Z.AI | NIM | B.AI | OpenRouter | Groq |
|-----|------|-----|------|------------|------|
| **Claude Code** | Anthropic-compat | free-claude-code proxy | free-claude-code proxy | free-claude-code proxy | — |
| **Qwen Code** | OpenAI-compat | Node-прокси / LiteLLM | OpenAI-compat | OpenAI-compat | OpenAI-compat |
| **OpenCode** | opencode.json | opencode.json | opencode.json | opencode.json | opencode.json |
| **OpenClaude** | Provider profiles | Provider profiles | Provider profiles | Provider profiles | — |
| **Freebuff** | — | — | — | — | — |

---

## Структура проекта

```
cloud-code-setup/
├── install.ps1                # Windows thin installer
├── install-full.ps1           # Windows полный инсталлятор
├── install.sh                 # Linux инсталлятор
├── bootstrap.sh               # curl | bash entrypoint
├── README.md
├── scripts/
│   ├── launcher-tui.ps1       # TUI-движок (Windows)
│   ├── launcher-tui.sh        # TUI-движок (Linux)
│   ├── launcher-api-keys.ps1  # Управление API ключами (Windows)
│   ├── launcher-api-keys.sh   # Управление API ключами (Linux)
│   ├── launcher-provider-models.ps1   # Каталоги моделей
│   ├── launcher-custom-model-wizard.ps1  # Мастер «Другая модель»
│   ├── create-desktop-shortcuts.ps1   # Ярлыки на рабочем столе
│   ├── run-qwen-code-launcher.ps1     # Qwen Code (Windows)
│   ├── run-qwen-code-launcher.sh      # Qwen Code (Linux)
│   ├── run-claude-cloud-launcher.ps1  # Claude Code (Windows)
│   ├── run-claude-cloud-launcher.sh   # Claude Code (Linux)
│   ├── run-opencode-launcher.ps1      # OpenCode (Windows)
│   ├── run-opencode-launcher.sh       # OpenCode (Linux)
│   ├── run-openclaude-launcher.ps1    # OpenClaude (Windows)
│   ├── run-openclaude-launcher.sh     # OpenClaude (Linux)
│   ├── run-freebuff-launcher.ps1      # Freebuff (Windows)
│   ├── run-freebuff-launcher.sh       # Freebuff (Linux)
│   └── ...
├── qwen-sessions/             # Профили сессий Qwen Code
└── docs/
    ├── MANUAL-SETUP.md        # Ручная установка
    └── DEPLOY-FROM-SCRATCH.md # Развёртывание с нуля
```

---

## Требования

### Обязательные
- **Windows 10/11** или **Linux** (Ubuntu 20+, Fedora, Arch и т.д.)
- **Git**
- **Node.js** LTS (18+)
- **npm**

### Опциональные (Linux)
- **jq** — для OpenClaude launcher (работа с `~/.openclaude.json`)
- **uv** — для free-claude-code proxy (автоустановка)
- **LiteLLM** — для пресетов NIM с Qwen Code (порт 4000)

---

## Устранение проблем

### Windows: «Политика выполнения скриптов»

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Linux: «Permission denied»

```bash
chmod +x ~/cloud-code-setup/scripts/*.sh
chmod +x ~/cloud-code-setup/install.sh
```

### Linux: «jq не установлен» (OpenClaude)

```bash
sudo apt install jq
```

### Ключи не подхватываются

**Windows**: Перезапустите терминал или компьютер.

**Linux**: Выполните `source ~/.bashrc` или перезапустите терминал.

---

## Лицензия

MIT
