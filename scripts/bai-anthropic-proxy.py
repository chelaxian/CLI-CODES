#!/usr/bin/env python3
"""
Minimal Anthropic Messages API -> OpenAI Chat Completions API proxy for B.AI.

NO external dependencies - uses only Python 3 standard library.
Supports: streaming (SSE), non-streaming, tool calling.
"""

import http.client
import http.server
import json
import os
import ssl
import sys
import threading
import time
import uuid
from urllib.parse import urlparse

BAI_BASE_URL = os.environ.get("OPENAI_BASE_URL", "https://api.b.ai/v1").rstrip("/")
BAI_API_KEY = os.environ.get("OPENROUTER_API_KEY", "") or os.environ.get("BAI_API_KEY", "")
MODEL_ID = os.environ.get("MODEL", "gpt-5-nano")
if "/" in MODEL_ID:
    MODEL_ID = MODEL_ID.split("/", 1)[1]
PROXY_PORT = int(os.environ.get("BAI_PROXY_PORT", "8088"))
HTTP_TIMEOUT = int(os.environ.get("HTTP_READ_TIMEOUT", "300"))

_parsed = urlparse(BAI_BASE_URL)
_upstream_host = _parsed.hostname
_upstream_port = _parsed.port or (443 if _parsed.scheme == "https" else 80)
_upstream_path = _parsed.path.rstrip("/")
_is_https = _parsed.scheme == "https"


def _new_upstream_conn():
    if _is_https:
        ctx = ssl.create_default_context()
        return http.client.HTTPSConnection(_upstream_host, _upstream_port, context=ctx, timeout=HTTP_TIMEOUT)
    return http.client.HTTPConnection(_upstream_host, _upstream_port, timeout=HTTP_TIMEOUT)


def anthropic_to_openai(body):
    messages = []
    system_text = ""
    for msg in body.get("system", []):
        if isinstance(msg, dict):
            system_text += msg.get("text", "")
        elif isinstance(msg, str):
            system_text += msg
    if system_text:
        messages.append({"role": "system", "content": system_text})

    for msg in body.get("messages", []):
        role = msg.get("role", "user")
        content = msg.get("content", "")
        if isinstance(content, list):
            parts = []
            for block in content:
                if isinstance(block, dict):
                    bt = block.get("type", "")
                    if bt == "text":
                        parts.append(block.get("text", ""))
                    elif bt == "tool_result":
                        tc = block.get("content", "")
                        if isinstance(tc, list):
                            tc = " ".join(p.get("text", "") for p in tc if isinstance(p, dict))
                        parts.append(str(tc))
                    elif bt == "thinking":
                        parts.append(block.get("thinking", ""))
                    elif bt == "redacted_thinking":
                        pass
                    else:
                        parts.append(json.dumps(block))
                else:
                    parts.append(str(block))
            content = "\n".join(parts)
        messages.append({"role": role, "content": content})

    result = {"model": MODEL_ID, "messages": messages, "max_tokens": body.get("max_tokens", 16384)}

    tools = body.get("tools")
    if tools:
        result["tools"] = [
            {"type": "function", "function": {"name": t.get("name", ""), "description": t.get("description", ""), "parameters": t.get("input_schema", {})}}
            for t in tools
        ]
        result["tool_choice"] = "auto"

    if body.get("stream"):
        result["stream"] = True
        result["stream_options"] = {"include_usage": True}

    return result


def openai_chunk_to_anthropic(chunk, model):
    choices = chunk.get("choices", [])
    if not choices:
        usage = chunk.get("usage")
        if usage:
            return {"type": "message_delta", "usage": {"output_tokens": usage.get("completion_tokens", 0)}, "delta": {"stop_reason": "end_turn"}}
        return None

    choice = choices[0]
    delta = choice.get("delta", {})
    finish_reason = choice.get("finish_reason")

    tool_calls = delta.get("tool_calls")
    if tool_calls:
        tc = tool_calls[0]
        fn = tc.get("function", {})
        return {"type": "content_block_delta", "index": tc.get("index", 0), "delta": {"type": "input_json_delta", "partial_json": fn.get("arguments", "")}}

    text = delta.get("content", "")
    if finish_reason:
        stop = "tool_use" if finish_reason == "tool_calls" else "end_turn"
        return {"type": "message_delta", "delta": {"stop_reason": stop}, "usage": {"output_tokens": 0}}

    if not text:
        return None
    return {"type": "content_block_delta", "index": 0, "delta": {"type": "text_delta", "text": text}}


def openai_to_anthropic_response(resp, model):
    content = []
    stop_reason = "end_turn"
    usage = resp.get("usage", {})
    input_tokens = usage.get("prompt_tokens", 0)
    output_tokens = usage.get("completion_tokens", 0)

    for choice in resp.get("choices", []):
        msg = choice.get("message", {})
        text = msg.get("content", "")
        if text:
            content.append({"type": "text", "text": text})
        for tc in msg.get("tool_calls", []):
            fn = tc.get("function", {})
            try:
                args = json.loads(fn.get("arguments", "{}"))
            except json.JSONDecodeError:
                args = {"raw": fn.get("arguments", "")}
            content.append({"type": "tool_use", "id": tc.get("id", f"call_{uuid.uuid4().hex[:24]}"), "name": fn.get("name", ""), "input": args})
            stop_reason = "tool_use"
        fr = choice.get("finish_reason")
        if fr == "tool_calls":
            stop_reason = "tool_use"
    if not content:
        content.append({"type": "text", "text": ""})
    return {"id": f"msg_{uuid.uuid4().hex[:24]}", "type": "message", "role": "assistant", "content": content, "model": model, "stop_reason": stop_reason, "stop_sequence": None, "usage": {"input_tokens": input_tokens, "output_tokens": output_tokens}}


class ProxyHandler(http.server.BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass

    def _read_body(self):
        length = int(self.headers.get("Content-Length", 0))
        return self.rfile.read(length) if length > 0 else b""

    def _send_json(self, code, obj):
        body = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path == "/v1/models" or self.path == "/models":
            self._send_json(200, {"object": "list", "data": [{"id": MODEL_ID, "object": "model", "created": int(time.time()), "owned_by": "b-ai"}]})
        else:
            self._send_json(404, {"error": "not found"})

    def do_POST(self):
        if self.path not in ("/v1/messages", "/messages"):
            self._send_json(404, {"error": "not found"})
            return

        raw = self._read_body()
        try:
            body = json.loads(raw)
        except Exception:
            self._send_json(400, {"error": "invalid json"})
            return

        is_stream = body.get("stream", False)
        requested_model = body.get("model", MODEL_ID)
        openai_req = anthropic_to_openai(body)
        req_body = json.dumps(openai_req).encode()
        headers = {"Authorization": f"Bearer {BAI_API_KEY}", "Content-Type": "application/json", "Content-Length": str(len(req_body)), "Host": _upstream_host}

        try:
            conn = _new_upstream_conn()
            conn.request("POST", f"{_upstream_path}/chat/completions", body=req_body, headers=headers)
            resp = conn.getresponse()
        except Exception as e:
            self._send_json(502, {"error": {"type": "api_error", "message": str(e)}})
            return

        if resp.status != 200:
            resp_body = resp.read().decode("utf-8", errors="replace")
            try:
                err = json.loads(resp_body)
            except Exception:
                err = {"error": resp_body}
            self._send_json(resp.status, err)
            conn.close()
            return

        if is_stream:
            self.send_response(200)
            self.send_header("Content-Type", "text/event-stream")
            self.send_header("Cache-Control", "no-cache")
            self.send_header("Connection", "keep-alive")
            self.end_headers()

            msg_id = f"msg_{uuid.uuid4().hex[:24]}"
            msg_start = json.dumps({"type": "message_start", "message": {"id": msg_id, "type": "message", "role": "assistant", "content": [], "model": requested_model, "stop_reason": None, "stop_sequence": None, "usage": {"input_tokens": 0, "output_tokens": 0}}})
            self.wfile.write(f"event: message_start\ndata: {msg_start}\n\n".encode())

            content_block_sent = False
            buf = b""
            while True:
                chunk = resp.read(4096)
                if not chunk:
                    break
                buf += chunk
                while b"\n" in buf:
                    line, buf = buf.split(b"\n", 1)
                    line = line.decode("utf-8", errors="replace").strip()
                    if not line or not line.startswith("data: "):
                        continue
                    data = line[6:]
                    if data == "[DONE]":
                        break
                    try:
                        parsed = json.loads(data)
                    except json.JSONDecodeError:
                        continue

                    if not content_block_sent:
                        content_block_sent = True
                        self.wfile.write(f"event: content_block_start\ndata: {json.dumps({'type': 'content_block_start', 'index': 0, 'content_block': {'type': 'text', 'text': ''}})}\n\n".encode())
                        self.wfile.flush()

                    ac = openai_chunk_to_anthropic(parsed, requested_model)
                    if ac:
                        self.wfile.write(f"event: {ac['type']}\ndata: {json.dumps(ac)}\n\n".encode())
                        self.wfile.flush()

            if not content_block_sent:
                self.wfile.write(f"event: content_block_start\ndata: {json.dumps({'type': 'content_block_start', 'index': 0, 'content_block': {'type': 'text', 'text': ''}})}\n\n".encode())
            self.wfile.write(f"event: content_block_stop\ndata: {json.dumps({'type': 'content_block_stop', 'index': 0})}\n\n".encode())
            self.wfile.write(f"event: message_delta\ndata: {json.dumps({'type': 'message_delta', 'delta': {'stop_reason': 'end_turn'}, 'usage': {'output_tokens': 0}})}\n\n".encode())
            self.wfile.write(f"event: message_stop\ndata: {json.dumps({'type': 'message_stop'})}\n\n".encode())
            self.wfile.flush()
            conn.close()
        else:
            resp_body = resp.read().decode("utf-8", errors="replace")
            conn.close()
            try:
                parsed = json.loads(resp_body)
            except Exception:
                self._send_json(502, {"error": {"type": "api_error", "message": "invalid upstream response"}})
                return
            anthropic_resp = openai_to_anthropic_response(parsed, requested_model)
            self._send_json(200, anthropic_resp)


class ThreadedHTTPServer(http.server.ThreadingHTTPServer):
    allow_reuse_address = True
    daemon_threads = True


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else PROXY_PORT
    if not BAI_API_KEY:
        print(f"WARNING: BAI_API_KEY / OPENROUTER_API_KEY is empty! B.AI requests will fail.", flush=True)
    server = ThreadedHTTPServer(("127.0.0.1", port), ProxyHandler)
    print(f"bai-proxy listening on 127.0.0.1:{port}", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        server.shutdown()
