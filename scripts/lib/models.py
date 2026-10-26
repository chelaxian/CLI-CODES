#!/usr/bin/env python3
"""
Нормализует ответ /models любого OpenAI-совместимого провайдера в строки
"model-id|label" (по одной на строку) для TUI-лаунчера.

Использование:  curl ... | python3 models.py <provider-key>

Понимает форматы:
  * {"data": [{"id": ...}, ...]}                  -- OpenAI / большинство провайдеров
  * {"models": [{"name"|"id": ...}, ...]}          -- некоторые шлюзы
  * [{"id": ..., "name": ...}, ...]                -- GitHub Models catalog
  * OpenRouter: поля pricing / supported_parameters (бесплатность и tool calling)
"""

import json
import re
import sys

# Модели, которые заведомо не годятся для кодинг-агента (эмбеддинги, TTS, картинки, guard-модели и т.п.)
NON_CHAT = re.compile(
    r"embed|rerank|tts|whisper|transcri|speech|audio|voxtral|image|dall-e|sdxl|stable-diffusion|flux|"
    r"seedance|kling|video|guard|safety|reward|moderation|nemoretriever|parse|nvclip|vila|deplot|kosmos|"
    r"neva|fuyu|ocr|translate|riva|detector|calibration|bge-|^test$",
    re.IGNORECASE,
)


def is_agentic(provider, model):
    """Решает, показывать ли модель в списке для кодинг-агента.

    Отсекаем не-чатовые модели по имени, а у OpenRouter (единственный, кто
    честно отдаёт метаданные) дополнительно требуем поддержку tool calling.
    """
    mid = model.get("id", "")
    if NON_CHAT.search(mid):
        return False
    params = model.get("supported_parameters")
    if provider == "openrouter" and isinstance(params, list):
        return "tools" in params
    return True


def is_free(provider, model):
    mid = model.get("id", "")
    if mid.endswith(":free") or mid.endswith("-free") or mid == "openrouter/free":
        return True
    pricing = model.get("pricing")
    if isinstance(pricing, dict):
        try:
            return float(pricing.get("prompt", 1)) == 0 and float(pricing.get("completion", 1)) == 0
        except (TypeError, ValueError):
            return False
    return False


def make_label(provider, model, free):
    name = model.get("name") or model.get("display_name") or model.get("id")
    ctx = model.get("context_length") or model.get("context_window") or 0
    parts = [str(name)]
    extra = []
    if free and "free" not in str(name).lower():
        extra.append("free")
    if ctx:
        extra.append("%dk ctx" % (int(ctx) // 1000))
    if extra:
        parts.append("(" + ", ".join(extra) + ")")
    return " ".join(parts).replace("|", "/")


def extract(payload):
    if isinstance(payload, list):
        items = payload
    elif isinstance(payload, dict):
        items = payload.get("data") or payload.get("models") or []
    else:
        items = []
    out = []
    for it in items:
        if isinstance(it, str):
            it = {"id": it}
        if not isinstance(it, dict):
            continue
        if "id" not in it and "name" in it:
            it = dict(it, id=it["name"])
        if it.get("id"):
            out.append(it)
    return out


def main():
    provider = sys.argv[1] if len(sys.argv) > 1 else ""
    try:
        payload = json.load(sys.stdin)
    except ValueError:
        return 1
    models = [m for m in extract(payload) if is_agentic(provider, m)]
    if not models:
        return 1
    rows = []
    for m in models:
        free = is_free(provider, m)
        rows.append((0 if free else 1, str(m["id"]).lower(), str(m["id"]), make_label(provider, m, free)))
    rows.sort()  # бесплатные выше, дальше по алфавиту
    seen = set()
    for _, _, mid, label in rows:
        if mid in seen:
            continue
        seen.add(mid)
        sys.stdout.write("%s|%s\n" % (mid, label))
    return 0


if __name__ == "__main__":
    sys.exit(main())
