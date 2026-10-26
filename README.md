# CLI-CODES

**1-click установка 30 популярных AI-агентов для терминала и запуск любого из них с 36 провайдерами моделей — включая бесплатные.**

Claude Code · Codex CLI · Gemini CLI · Qwen Code · OpenCode · Crush · GitHub Copilot CLI · Kilo Code · Cline · OpenClaude · Amp · Cursor CLI · Factory Droid · Augment Auggie · Kimi Code · Qoder · CodeBuddy · Pi · Letta Code · Junie · Goose · Aider · Mistral Vibe · OpenHands · Hermes Agent · OpenClaw · Kiro · Codebuff · Freebuff · MiMo Code

Работает на Windows, Linux и macOS.

<img width="1600" height="800" alt="CLI-CODES" src="https://github.com/user-attachments/assets/45e2e8f6-040f-49e0-987c-ac0e11b1d9ed" />

---

## Быстрая установка

**Windows (PowerShell):**

```powershell
irm https://raw.githubusercontent.com/chelaxian/CLI-CODES/main/install.ps1 | iex
```

**Linux / macOS:**

```bash
curl -fsSL https://raw.githubusercontent.com/chelaxian/CLI-CODES/main/bootstrap.sh | bash
```

Инсталлятор сам поставит git / Node.js LTS (через winget, apt, dnf, pacman, zypper, apk или brew), склонирует репозиторий и предложит:

| Пункт | Что делает |
|-------|------------|
| **[1] Рекомендуемый набор** | Claude Code, Codex, Gemini CLI, Qwen Code, OpenCode, Crush, Copilot CLI, Kilo, OpenClaude |
| **[2] Все агенты** | все 30 из [`TXT/agents.txt`](TXT/agents.txt) |
| **[3] Выбрать вручную** | номера через пробел или диапазоны: `1 2 5`, `1-6` |
| **[4] Обновить** | репозиторий и все уже установленные агенты |
| **[5] API-ключи** | ключи провайдеров (все можно пропустить) |
| **[6] Ярлыки** | ярлыки на рабочем столе и команда `cli-codes` |
| **[9] Удаление** | агенты, ключи, ярлыки, репозиторий (конфиги самих агентов не трогает) |

Без меню: `./install.sh --agents claude,codex,gemini`, `--all`, `--update` (Windows: `install-full.ps1 -Agents claude,codex -All -Update`).

---

## Запуск: `cli-codes`

После установки у каждого агента есть ярлык на рабочем столе, а в терминале — команда `cli-codes`:

```bash
cli-codes                    # меню: выбрать агента
cli-codes claude             # меню агента: провайдер → модель → запуск
cli-codes claude --last      # сразу с последними провайдером и моделью
cli-codes keys               # API-ключи провайдеров
cli-codes list               # какие агенты установлены и их версии
cli-codes providers          # провайдеры и наличие ключей
cli-codes models openrouter  # живой список моделей провайдера
cli-codes install aider vibe # поставить/обновить конкретных агентов
```

Меню агента:

- **▶ Быстрый старт** — последний провайдер и модель;
- **Выбрать провайдера и модель…** — провайдеры, совместимые с этим агентом; у бесплатных пометка `FREE` / `FREE-квота`. Список моделей грузится **динамически из API провайдера** (кэш 6 ч), сверху — рекомендуемые `★`. Есть фильтр по названию, ручной ввод ID и обновление списка;
- **Нативный запуск** — агент со своим логином (подписка Claude, ChatGPT, Google, GitHub Copilot…);
- **Классический лаунчер** — пресеты прошлых версий для Qwen, Claude, OpenCode, OpenClaude, Freebuff, MiMo;
- **Рабочая папка** — где запускать агента (по умолчанию текущая папка терминала).

---

## Провайдеры

Все провайдеры OpenAI-совместимые и описаны в [`TXT/providers.txt`](TXT/providers.txt). Модели подгружаются из `/models` провайдера; если API недоступно, используется статический каталог из `TXT/models/<провайдер>.txt`.

### Бесплатные и с бесплатной квотой

| Провайдер | Что бесплатно | Ключ |
|-----------|---------------|------|
| **OpenRouter** | модели `:free` (50 запросов/день, 1000 при балансе от $10) | [openrouter.ai/settings/keys](https://openrouter.ai/settings/keys) |
| **NVIDIA NIM** | ~40 запросов/мин: GLM, Kimi, DeepSeek, MiniMax, Nemotron | [build.nvidia.com](https://build.nvidia.com/settings/api-keys) |
| **Google AI Studio** | Gemini Flash / Gemma | [aistudio.google.com/apikey](https://aistudio.google.com/apikey) |
| **OpenCode Zen** | `big-pickle`, модели `*-free` | [opencode.ai/auth](https://opencode.ai/auth) |
| **Ollama Cloud** | облачные Kimi / GLM / DeepSeek / MiniMax | [ollama.com/settings/keys](https://ollama.com/settings/keys) |
| **Groq** | быстрый инференс с лимитами TPM | [console.groq.com/keys](https://console.groq.com/keys) |
| **Cerebras** | до 1M токенов/день | [cloud.cerebras.ai](https://cloud.cerebras.ai/platform) |
| **Mistral** | план Experiment: Devstral, Codestral | [console.mistral.ai](https://console.mistral.ai/api-keys) |
| **GitHub Models** | бесплатно с GitHub-аккаунтом | [PAT с `models:read`](https://github.com/settings/personal-access-tokens) |
| **Hugging Face** | ежемесячные кредиты | [huggingface.co/settings/tokens](https://huggingface.co/settings/tokens) |
| **ModelScope** | 2000 запросов/день | [modelscope.cn](https://modelscope.cn/my/myaccesstoken) |
| **Chutes**, **SambaNova** | бесплатный tier | [chutes.ai](https://chutes.ai/app/api), [sambanova.ai](https://cloud.sambanova.ai/apis) |
| **LLM7.io**, **Pollinations**, **OVHcloud** | работают **без ключа** (ключ повышает лимиты) | — |
| **Vercel AI Gateway** | $5 кредитов в месяц | [vercel.com](https://vercel.com/d?to=%2F%5Bteam%5D%2F%7E%2Fai%2Fapi-keys) |
| **Z.AI** | GLM-*-Flash | [z.ai](https://z.ai/manage-apikey/apikey-create) |
| **Alibaba Model Studio**, **SiliconFlow**, **LongCat**, **Xiaomi MiMo**, **B.AI** | стартовая квота / часть моделей | см. `cli-codes keys` |

### Платные и локальные

DeepSeek, Moonshot (Kimi), MiniMax, StepFun, Z.AI Coding Plan, OpenAI, Anthropic, xAI, Together, Fireworks, Novita, а также **Ollama** и **LM Studio** на локальной машине.

---

## Как агенты подключаются к провайдерам

| Агент | Механизм | Ограничения |
|-------|----------|-------------|
| Claude Code | `ANTHROPIC_BASE_URL` → нативный Anthropic API провайдера (Z.AI, DeepSeek, Kimi, MiniMax, OpenRouter, Ollama, Zen…) или встроенный прокси `scripts/lib/anthropic-proxy.py` | для прокси нужен Python 3 |
| Codex CLI | `-c model_providers.*`, `wire_api = "responses"` | только провайдеры с Responses API: OpenAI, OpenRouter, Groq, Ollama, Zen, HF, Vercel, xAI, LLM7, локальные |
| Qwen Code | `--auth-type openai --openai-base-url -m` | — |
| OpenCode | сгенерированный `opencode.json` (`OPENCODE_CONFIG`) | — |
| OpenClaude | `CLAUDE_CODE_USE_OPENAI` + `OPENAI_*` | — |
| Gemini CLI | `GEMINI_API_KEY` + `-m` | только Google AI Studio |
| Aider | `--openai-api-base --model openai/<id>` | — |
| Goose | `GOOSE_PROVIDER=openai` + `OPENAI_HOST` | Linux/macOS |
| Остальные | свой логин / конфиг; сохранённые ключи экспортируются в окружение (Crush, Kilo, Pi и др. подхватывают их сами) | — |

Встроенный прокси переводит Anthropic Messages API в OpenAI Chat Completions, включая стриминг и tool calling (`tool_use` ↔ `tool_calls`, `tool_result` ↔ `role: tool`), слушает только `127.0.0.1` и живёт, пока работает агент.

---

## Структура проекта

```
CLI-CODES/
├── install.sh / install.ps1 / install-full.ps1 / bootstrap.sh   # инсталляторы
├── TXT/
│   ├── agents.txt          # реестр агентов: команда, способ установки (npm/uv/curl/irm), адаптер
│   ├── providers.txt       # реестр провайдеров: base URL, /models, тариф, Anthropic API, Responses API
│   ├── models/<key>.txt    # статические каталоги моделей (fallback + «★ рекомендуемые»)
│   ├── catalogs/, logos/, menus/   # данные классических лаунчеров
├── scripts/
│   ├── run-agent.sh / .ps1         # универсальный лаунчер = команда cli-codes
│   ├── lib/clicodes.sh / .ps1      # ядро: реестры, ключи, модели, установка, адаптеры
│   ├── lib/models.py               # нормализация ответов /models
│   ├── lib/anthropic-proxy.py      # прокси Anthropic → OpenAI (stdlib, без зависимостей)
│   ├── create-desktop-shortcuts.ps1
│   └── run-*-launcher.*            # классические лаунчеры прошлых версий
├── tests/test_core.py              # офлайн-тесты прокси, парсера и реестров
└── docs/MANUAL-SETUP.md
```

**Добавить агента или провайдера** — одна строка в `TXT/agents.txt` / `TXT/providers.txt` (+ файл `TXT/models/<key>.txt`). Код менять не нужно: меню инсталлятора, лаунчер и ярлыки строятся из реестров.

---

## Хранение ключей

- **Linux / macOS:** `~/.config/cli-codes/keys.env` (`chmod 600`), подключается из `~/.bashrc` / `~/.zshrc`.
- **Windows:** пользовательские переменные среды.

Подробнее — [SECURITY.md](SECURITY.md).

## Требования

- Windows 10/11, Linux или macOS
- git, Node.js ≥ 20 (ставятся инсталлятором автоматически)
- Python 3 — только для Claude Code с провайдерами без Anthropic API; uv ставится автоматически для Aider, Mistral Vibe и OpenHands

## Устранение проблем

| Проблема | Решение |
|----------|---------|
| Windows: «выполнение сценариев отключено» | `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` |
| `cli-codes: command not found` | откройте новый терминал (PATH обновлён) или `~/CLI-CODES/scripts/run-agent.sh` |
| Список моделей не загружается | проверьте ключ (`cli-codes keys`); при недоступном API используется статический каталог |
| Claude Code через прокси не отвечает | лог: `~/.cache/cli-codes/anthropic-proxy.log` (Windows: `%LOCALAPPDATA%\cli-codes\`) |
| Агент «только Linux/macOS» на Windows | Goose и Kiro ставятся через WSL |

## Тесты

```bash
python -m unittest discover -s tests -v
```

## Лицензия

MIT
