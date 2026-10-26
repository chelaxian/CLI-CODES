#!/usr/bin/env python3
"""
Anthropic Messages API  ->  OpenAI Chat Completions API proxy.

Позволяет запускать Claude Code (и любой клиент Anthropic API) поверх
любого OpenAI-совместимого провайдера: NVIDIA NIM, Groq, Cerebras, Gemini,
Mistral, GitHub Models, Chutes, B.AI и т.д.

Только стандартная библиотека Python 3.8+. Поддерживает:
  * streaming (SSE) и обычные ответы;
  * tool calling в обе стороны (tool_use <-> tool_calls, tool_result <-> role=tool);
  * изображения (base64 / url);
  * /v1/messages/count_tokens (приблизительная оценка).

Переменные окружения:
  UPSTREAM_BASE_URL   OpenAI-совместимый base URL (например https://integrate.api.nvidia.com/v1)
  UPSTREAM_API_KEY    ключ провайдера (Bearer); может быть пустым для локальных серверов
  UPSTREAM_MODEL      ID модели у провайдера; если задан — подменяет model из запроса
  UPSTREAM_MAX_TOKENS потолок max_tokens (0 = без ограничения)
  PROXY_PORT          порт (по умолчанию 8082); можно передать первым аргументом
  PROXY_TOKEN         если задан — клиент обязан прислать его в x-api-key / Authorization
                      (лаунчер генерирует случайный токен на сессию, чтобы ключ провайдера
                      не мог тратить любой локальный процесс или веб-страница)
  PROXY_LOG           путь к лог-файлу (опционально)
"""

import http.client
import http.server
import json
import logging
import os
import ssl
import sys
import time
import uuid
from urllib.parse import urlparse

BASE_URL = os.environ.get("UPSTREAM_BASE_URL", "").rstrip("/")
API_KEY = os.environ.get("UPSTREAM_API_KEY", "")
FORCED_MODEL = os.environ.get("UPSTREAM_MODEL", "")
MAX_TOKENS_CAP = int(os.environ.get("UPSTREAM_MAX_TOKENS", "0") or 0)
HTTP_TIMEOUT = int(os.environ.get("HTTP_READ_TIMEOUT", "600"))
PROXY_TOKEN = os.environ.get("PROXY_TOKEN", "")

STOP_REASONS = {"stop": "end_turn", "length": "max_tokens", "tool_calls": "tool_use",
                "function_call": "tool_use", "content_filter": "end_turn"}


# ─── Запрос: Anthropic -> OpenAI ─────────────────────────────────────────────

def _text_of(content):
    """tool_result.content может быть строкой или списком блоков."""
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return "\n".join(b.get("text", "") for b in content if isinstance(b, dict) and b.get("type") == "text")
    return "" if content is None else json.dumps(content, ensure_ascii=False)


def _image_part(block):
    src = block.get("source", {})
    if src.get("type") == "base64":
        url = "data:%s;base64,%s" % (src.get("media_type", "image/png"), src.get("data", ""))
    else:
        url = src.get("url", "")
    return {"type": "image_url", "image_url": {"url": url}}


def convert_messages(body):
    out = []
    system = body.get("system")
    if system:
        text = system if isinstance(system, str) else "\n".join(
            b.get("text", "") for b in system if isinstance(b, dict))
        if text:
            out.append({"role": "system", "content": text})

    for msg in body.get("messages", []):
        role = msg.get("role", "user")
        content = msg.get("content", "")
        if isinstance(content, str):
            out.append({"role": role, "content": content})
            continue

        if role == "assistant":
            texts, calls = [], []
            for b in content:
                t = b.get("type")
                if t == "text":
                    texts.append(b.get("text", ""))
                elif t == "tool_use":
                    calls.append({"id": b.get("id"), "type": "function",
                                  "function": {"name": b.get("name", ""),
                                               "arguments": json.dumps(b.get("input", {}), ensure_ascii=False)}})
            m = {"role": "assistant", "content": "\n".join(texts) or None}
            if calls:
                m["tool_calls"] = calls
            out.append(m)
            continue

        # user: tool_result-блоки становятся отдельными сообщениями role=tool,
        # и они обязаны идти сразу после assistant-сообщения с tool_calls.
        parts = []
        for b in content:
            t = b.get("type")
            if t == "tool_result":
                text = _text_of(b.get("content"))
                if b.get("is_error"):
                    text = "[ERROR] " + text
                out.append({"role": "tool", "tool_call_id": b.get("tool_use_id"), "content": text})
            elif t == "text":
                parts.append({"type": "text", "text": b.get("text", "")})
            elif t == "image":
                parts.append(_image_part(b))
        if parts:
            if all(p["type"] == "text" for p in parts):
                out.append({"role": "user", "content": "\n".join(p["text"] for p in parts)})
            else:
                out.append({"role": "user", "content": parts})
    return out


def convert_request(body):
    req = {"model": FORCED_MODEL or body.get("model", ""), "messages": convert_messages(body)}
    max_tokens = body.get("max_tokens")
    if max_tokens:
        req["max_tokens"] = min(max_tokens, MAX_TOKENS_CAP) if MAX_TOKENS_CAP else max_tokens
    for src, dst in (("temperature", "temperature"), ("top_p", "top_p"), ("stop_sequences", "stop")):
        if body.get(src) is not None:
            req[dst] = body[src]

    tools = body.get("tools") or []
    fn_tools = [{"type": "function", "function": {"name": t.get("name", ""),
                                                  "description": t.get("description", ""),
                                                  "parameters": t.get("input_schema") or {"type": "object", "properties": {}}}}
                for t in tools if t.get("name")]
    if fn_tools:
        req["tools"] = fn_tools
        choice = body.get("tool_choice") or {}
        ctype = choice.get("type")
        if ctype == "any":
            req["tool_choice"] = "required"
        elif ctype == "tool":
            req["tool_choice"] = {"type": "function", "function": {"name": choice.get("name", "")}}
        elif ctype == "none":
            req["tool_choice"] = "none"

    if body.get("stream"):
        req["stream"] = True
        req["stream_options"] = {"include_usage": True}
    return req


# ─── Ответ: OpenAI -> Anthropic ──────────────────────────────────────────────

def convert_response(resp, model):
    content, stop = [], "end_turn"
    for choice in resp.get("choices", [])[:1]:
        msg = choice.get("message") or {}
        if msg.get("content"):
            content.append({"type": "text", "text": msg["content"]})
        for tc in msg.get("tool_calls") or []:
            fn = tc.get("function", {})
            try:
                args = json.loads(fn.get("arguments") or "{}")
            except ValueError:
                args = {"raw": fn.get("arguments", "")}
            content.append({"type": "tool_use", "id": tc.get("id") or "toolu_" + uuid.uuid4().hex[:24],
                            "name": fn.get("name", ""), "input": args})
        stop = STOP_REASONS.get(choice.get("finish_reason"), "end_turn")
        if any(b["type"] == "tool_use" for b in content):
            stop = "tool_use"
    usage = resp.get("usage") or {}
    return {"id": "msg_" + uuid.uuid4().hex[:24], "type": "message", "role": "assistant",
            "model": model, "content": content or [{"type": "text", "text": ""}],
            "stop_reason": stop, "stop_sequence": None,
            "usage": {"input_tokens": usage.get("prompt_tokens", 0),
                      "output_tokens": usage.get("completion_tokens", 0)}}


class StreamTranslator:
    """Превращает поток OpenAI chunk'ов в последовательность Anthropic SSE-событий."""

    def __init__(self, model):
        self.model = model
        self.index = -1          # индекс текущего content-блока Anthropic
        self.kind = None         # "text" | "tool" | None
        self.tool_slot = None    # индекс tool_call в нотации OpenAI
        self.tool_id = None      # id текущего tool_call (некоторые провайдеры не присылают index)
        self.saw_tool = False
        self.stop = "end_turn"
        self.in_tokens = 0
        self.out_tokens = 0

    def start(self):
        return [("message_start", {"type": "message_start", "message": {
            "id": "msg_" + uuid.uuid4().hex[:24], "type": "message", "role": "assistant",
            "content": [], "model": self.model, "stop_reason": None, "stop_sequence": None,
            "usage": {"input_tokens": 0, "output_tokens": 0}}})]

    def _close(self):
        if self.kind is None:
            return []
        self.kind = None
        return [("content_block_stop", {"type": "content_block_stop", "index": self.index})]

    def _open(self, kind, block):
        events = self._close()
        self.index += 1
        self.kind = kind
        events.append(("content_block_start", {"type": "content_block_start", "index": self.index,
                                               "content_block": block}))
        return events

    def feed(self, chunk):
        events = []
        usage = chunk.get("usage")
        if usage:
            self.in_tokens = usage.get("prompt_tokens", self.in_tokens)
            self.out_tokens = usage.get("completion_tokens", self.out_tokens)
        for choice in chunk.get("choices", [])[:1]:
            delta = choice.get("delta") or {}
            text = delta.get("content")
            if text:
                if self.kind != "text":
                    events += self._open("text", {"type": "text", "text": ""})
                events.append(("content_block_delta", {"type": "content_block_delta", "index": self.index,
                                                       "delta": {"type": "text_delta", "text": text}}))
            for tc in delta.get("tool_calls") or []:
                slot = tc.get("index", 0)
                fn = tc.get("function") or {}
                new_id = tc.get("id")
                if self.kind != "tool" or slot != self.tool_slot or (new_id and new_id != self.tool_id):
                    self.tool_slot, self.tool_id, self.saw_tool = slot, new_id, True
                    events += self._open("tool", {"type": "tool_use",
                                                  "id": tc.get("id") or "toolu_" + uuid.uuid4().hex[:24],
                                                  "name": fn.get("name", ""), "input": {}})
                if fn.get("arguments"):
                    events.append(("content_block_delta", {"type": "content_block_delta", "index": self.index,
                                                           "delta": {"type": "input_json_delta",
                                                                     "partial_json": fn["arguments"]}}))
            if choice.get("finish_reason"):
                self.stop = STOP_REASONS.get(choice["finish_reason"], "end_turn")
        return events

    def finish(self):
        events = []
        if self.index < 0:
            events += self._open("text", {"type": "text", "text": ""})
        events += self._close()
        if self.saw_tool and self.stop == "end_turn":
            self.stop = "tool_use"  # Gemini и часть шлюзов шлют finish_reason=stop вместе с tool_calls
        events.append(("message_delta", {"type": "message_delta",
                                         "delta": {"stop_reason": self.stop, "stop_sequence": None},
                                         "usage": {"input_tokens": self.in_tokens, "output_tokens": self.out_tokens}}))
        events.append(("message_stop", {"type": "message_stop"}))
        return events


# ─── HTTP ────────────────────────────────────────────────────────────────────

def upstream_connection():
    u = urlparse(BASE_URL)
    if u.scheme == "https":
        return http.client.HTTPSConnection(u.hostname, u.port or 443, timeout=HTTP_TIMEOUT,
                                           context=ssl.create_default_context()), u.path.rstrip("/")
    return http.client.HTTPConnection(u.hostname, u.port or 80, timeout=HTTP_TIMEOUT), u.path.rstrip("/")


def anthropic_error(status, message):
    kind = {400: "invalid_request_error", 401: "authentication_error", 403: "permission_error",
            404: "not_found_error", 429: "rate_limit_error"}.get(status, "api_error")
    return {"type": "error", "error": {"type": kind, "message": message}}


class Handler(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):
        logging.debug(fmt, *args)

    def _json(self, code, obj):
        data = json.dumps(obj, ensure_ascii=False).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def _sse(self, event, data):
        self.wfile.write(("event: %s\ndata: %s\n\n" % (event, json.dumps(data, ensure_ascii=False))).encode())
        self.wfile.flush()

    def do_HEAD(self):
        self.send_response(200)
        self.send_header("Content-Length", "0")
        self.end_headers()

    def do_GET(self):
        path = self.path.split("?")[0]
        if path in ("/v1/models", "/models"):
            self._json(200, {"data": [{"id": FORCED_MODEL or "default", "type": "model",
                                       "display_name": FORCED_MODEL, "created_at": int(time.time())}],
                             "has_more": False})
        else:
            self._json(200, {"status": "ok", "upstream": BASE_URL, "model": FORCED_MODEL})

    def _authorized(self):
        if not PROXY_TOKEN:
            return True
        auth = self.headers.get("x-api-key") or self.headers.get("Authorization", "").replace("Bearer ", "", 1)
        return auth.strip() == PROXY_TOKEN

    def do_POST(self):
        path = self.path.split("?")[0]
        # тело вычитываем ВСЕГДА: иначе на keep-alive соединении остаток тела отказанного
        # запроса склеится со следующим запросом
        raw = self.rfile.read(int(self.headers.get("Content-Length") or 0))
        if not self._authorized():
            self.close_connection = True
            return self._json(401, anthropic_error(401, "invalid proxy token"))
        # браузер не может отправить application/json кросс-доменно без preflight → защита от CSRF
        if "application/json" not in (self.headers.get("Content-Type") or ""):
            self.close_connection = True
            return self._json(415, anthropic_error(400, "Content-Type must be application/json"))
        try:
            body = json.loads(raw or b"{}")
        except ValueError:
            return self._json(400, anthropic_error(400, "invalid JSON"))

        if path.endswith("/messages/count_tokens"):
            return self._json(200, {"input_tokens": max(1, len(json.dumps(body)) // 4)})
        if not path.endswith("/messages"):
            return self._json(404, anthropic_error(404, "unknown path " + path))
        try:
            self._proxy(body)
        except (BrokenPipeError, ConnectionResetError):
            pass
        except Exception as exc:  # noqa: BLE001 — прокси не должен падать целиком
            logging.exception("proxy error")
            try:
                self._json(502, anthropic_error(502, "proxy error: %s" % exc))
            except Exception:
                pass

    def _proxy(self, body):
        req = convert_request(body)
        model = body.get("model") or req["model"]
        payload = json.dumps(req, ensure_ascii=False).encode()
        headers = {"Content-Type": "application/json", "Accept": "text/event-stream" if req.get("stream") else "application/json",
                   "HTTP-Referer": "https://github.com/chelaxian/CLI-CODES", "X-Title": "CLI-CODES"}
        if API_KEY:
            headers["Authorization"] = "Bearer " + API_KEY
        conn, prefix = upstream_connection()
        logging.info("-> %s model=%s stream=%s msgs=%d tools=%d", BASE_URL, req["model"], bool(req.get("stream")),
                     len(req["messages"]), len(req.get("tools", [])))
        conn.request("POST", prefix + "/chat/completions", body=payload, headers=headers)
        resp = conn.getresponse()

        if resp.status == 400 and "max_tokens" in req:
            # Claude Code просит 32k–64k токенов ответа; у части моделей лимит меньше → повтор без max_tokens
            text = resp.read().decode("utf-8", "replace")
            conn.close()
            if "token" in text.lower():
                logging.warning("400 по max_tokens=%s, повтор без ограничения", req.pop("max_tokens"))
                payload = json.dumps(req, ensure_ascii=False).encode()
                conn, prefix = upstream_connection()
                conn.request("POST", prefix + "/chat/completions", body=payload, headers=headers)
                resp = conn.getresponse()
            else:
                logging.error("<- 400 %s", text[:500])
                return self._json(400, anthropic_error(400, text[:2000]))

        if resp.status != 200:
            text = resp.read().decode("utf-8", "replace")
            conn.close()
            logging.error("<- %s %s", resp.status, text[:500])
            return self._json(resp.status, anthropic_error(resp.status, text[:2000]))

        if not req.get("stream"):
            data = json.loads(resp.read().decode("utf-8", "replace") or "{}")
            conn.close()
            return self._json(200, convert_response(data, model))

        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Connection", "close")
        self.end_headers()
        self.close_connection = True

        tr = StreamTranslator(model)
        for ev in tr.start():
            self._sse(*ev)
        while True:
            line = resp.readline()
            if not line:
                break
            line = line.decode("utf-8", "replace").strip()
            if not line.startswith("data:"):
                continue
            data = line[5:].strip()
            if data == "[DONE]":
                break
            try:
                chunk = json.loads(data)
            except ValueError:
                continue
            if "error" in chunk and not chunk.get("choices"):
                logging.error("stream error: %s", chunk["error"])
                self._sse("error", anthropic_error(500, json.dumps(chunk["error"], ensure_ascii=False)))
                break
            for ev in tr.feed(chunk):
                self._sse(*ev)
        for ev in tr.finish():
            self._sse(*ev)
        conn.close()


def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else int(os.environ.get("PROXY_PORT", "8082"))
    handlers = [logging.StreamHandler(sys.stderr)]
    if os.environ.get("PROXY_LOG"):
        handlers.append(logging.FileHandler(os.environ["PROXY_LOG"], encoding="utf-8"))
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(message)s", handlers=handlers)
    if not BASE_URL:
        sys.exit("UPSTREAM_BASE_URL не задан")
    server = http.server.ThreadingHTTPServer(("127.0.0.1", port), Handler)
    server.daemon_threads = True
    logging.info("anthropic-proxy :%d -> %s (model=%s, key=%s)", port, BASE_URL, FORCED_MODEL or "<из запроса>",
                 "set" if API_KEY else "none")
    print("anthropic-proxy listening on 127.0.0.1:%d" % port, flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
