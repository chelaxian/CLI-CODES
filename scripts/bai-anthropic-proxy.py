#!/usr/bin/env python3
"""
Minimal Anthropic Messages API -> OpenAI Chat Completions API proxy for B.AI.

Receives Anthropic-format requests from Claude Code and forwards them
to B.AI (https://api.b.ai/v1) as OpenAI Chat Completions requests,
then translates the response back to Anthropic format.

Supports: streaming (SSE), non-streaming, tool calling, thinking.
"""

import asyncio
import json
import os
import sys
import time
import uuid
from typing import Any

import aiohttp
from aiohttp import web

BAI_BASE_URL = os.environ.get("OPENAI_BASE_URL", "https://api.b.ai/v1").rstrip("/")
BAI_API_KEY = os.environ.get("OPENROUTER_API_KEY", "") or os.environ.get("BAI_API_KEY", "")
MODEL_ID = os.environ.get("MODEL", "gpt-5-nano")
if "/" in MODEL_ID:
    MODEL_ID = MODEL_ID.split("/", 1)[1]
PROXY_PORT = int(os.environ.get("BAI_PROXY_PORT", "8085"))
HTTP_TIMEOUT = int(os.environ.get("HTTP_READ_TIMEOUT", "300"))


def anthropic_to_openai(body: dict) -> dict:
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
                    if block.get("type") == "text":
                        parts.append(block.get("text", ""))
                    elif block.get("type") == "tool_result":
                        tc = block.get("content", "")
                        if isinstance(tc, list):
                            tc = " ".join(
                                p.get("text", "") for p in tc if isinstance(p, dict)
                            )
                        parts.append(str(tc))
                    elif block.get("type") == "thinking":
                        parts.append(block.get("thinking", ""))
                    elif block.get("type") == "redacted_thinking":
                        pass
                    else:
                        parts.append(json.dumps(block))
                else:
                    parts.append(str(block))
            content = "\n".join(parts)
        messages.append({"role": role, "content": content})

    tools = None
    if body.get("tools"):
        tools = []
        for t in body["tools"]:
            tools.append(
                {
                    "type": "function",
                    "function": {
                        "name": t.get("name", ""),
                        "description": t.get("description", ""),
                        "parameters": t.get("input_schema", {}),
                    },
                }
            )

    max_tokens = body.get("max_tokens", 16384)

    result: dict[str, Any] = {
        "model": MODEL_ID,
        "messages": messages,
        "max_tokens": max_tokens,
    }

    if tools:
        result["tools"] = tools
        result["tool_choice"] = "auto"

    if body.get("stream"):
        result["stream"] = True
        result["stream_options"] = {"include_usage": True}

    return result


def openai_to_anthropic_chunk(chunk: dict, model: str) -> dict | None:
    choices = chunk.get("choices", [])
    if not choices:
        usage = chunk.get("usage")
        if usage:
            return {
                "type": "message_delta",
                "usage": {"output_tokens": usage.get("completion_tokens", 0)},
                "delta": {"stop_reason": "end_turn"},
            }
        return None

    choice = choices[0]
    delta = choice.get("delta", {})
    finish_reason = choice.get("finish_reason")

    content_blocks = []

    tool_calls = delta.get("tool_calls")
    if tool_calls:
        for tc in tool_calls:
            idx = tc.get("index", 0)
            fn = tc.get("function", {})
            content_blocks.append(
                {
                    "type": "input_json_delta",
                    "index": idx,
                    "partial_json": fn.get("arguments", ""),
                }
            )

    text = delta.get("content", "")
    if text and not tool_calls:
        content_blocks.append({"type": "text_delta", "text": text})

    if finish_reason:
        stop = "end_turn"
        if finish_reason == "tool_calls":
            stop = "tool_use"
        content_blocks.append({"type": "text_delta", "text": ""})
        return {
            "type": "message_delta",
            "delta": {"stop_reason": stop},
            "usage": {"output_tokens": 0},
        }

    if not content_blocks:
        return None

    return {
        "type": "content_block_delta",
        "index": 0 if not tool_calls else tool_calls[0].get("index", 0),
        "delta": content_blocks[0] if len(content_blocks) == 1 else content_blocks[0],
    }


def openai_to_anthropic_response(resp: dict, model: str) -> dict:
    choices = resp.get("choices", [])
    content = []
    stop_reason = "end_turn"
    input_tokens = 0
    output_tokens = 0

    usage = resp.get("usage", {})
    input_tokens = usage.get("prompt_tokens", 0)
    output_tokens = usage.get("completion_tokens", 0)

    for choice in choices:
        msg = choice.get("message", {})
        text = msg.get("content", "")
        if text:
            content.append({"type": "text", "text": text})

        tool_calls = msg.get("tool_calls", [])
        for tc in tool_calls:
            fn = tc.get("function", {})
            args_str = fn.get("arguments", "{}")
            try:
                args = json.loads(args_str)
            except json.JSONDecodeError:
                args = {"raw": args_str}
            content.append(
                {
                    "type": "tool_use",
                    "id": tc.get("id", f"call_{uuid.uuid4().hex[:24]}"),
                    "name": fn.get("name", ""),
                    "input": args,
                }
            )
            stop_reason = "tool_use"

        fr = choice.get("finish_reason")
        if fr == "tool_calls":
            stop_reason = "tool_use"
        elif fr == "stop":
            stop_reason = "end_turn"

    if not content:
        content.append({"type": "text", "text": ""})

    return {
        "id": f"msg_{uuid.uuid4().hex[:24]}",
        "type": "message",
        "role": "assistant",
        "content": content,
        "model": model,
        "stop_reason": stop_reason,
        "stop_sequence": None,
        "usage": {"input_tokens": input_tokens, "output_tokens": output_tokens},
    }


async def handle_messages(req: web.Request) -> web.StreamResponse:
    body = await req.json()
    is_stream = body.get("stream", False)
    requested_model = body.get("model", MODEL_ID)

    openai_req = anthropic_to_openai(body)

    headers = {
        "Authorization": f"Bearer {BAI_API_KEY}",
        "Content-Type": "application/json",
    }

    url = f"{BAI_BASE_URL}/chat/completions"

    if is_stream:
        resp = web.StreamResponse(
            status=200,
            headers={
                "Content-Type": "text/event-stream",
                "Cache-Control": "no-cache",
                "Connection": "keep-alive",
            },
        )
        await resp.prepare(req)

        timeout = aiohttp.ClientTimeout(total=HTTP_TIMEOUT)
        async with aiohttp.ClientSession(timeout=timeout) as session:
            async with session.post(url, json=openai_req, headers=headers) as client_resp:
                msg_start = json.dumps(
                    {
                        "type": "message_start",
                        "message": {
                            "id": f"msg_{uuid.uuid4().hex[:24]}",
                            "type": "message",
                            "role": "assistant",
                            "content": [],
                            "model": requested_model,
                            "stop_reason": None,
                            "stop_sequence": None,
                            "usage": {"input_tokens": 0, "output_tokens": 0},
                        },
                    }
                )
                await resp.write(f"event: message_start\ndata: {msg_start}\n\n".encode())

                content_block_sent = False
                async for line in client_resp.content:
                    line = line.decode("utf-8", errors="replace").strip()
                    if not line or not line.startswith("data: "):
                        continue
                    data = line[6:]
                    if data == "[DONE]":
                        break
                    try:
                        chunk = json.loads(data)
                    except json.JSONDecodeError:
                        continue

                    if not content_block_sent:
                        content_block_sent = True
                        await resp.write(
                            f"event: content_block_start\ndata: {json.dumps({'type': 'content_block_start', 'index': 0, 'content_block': {'type': 'text', 'text': ''}})}\n\n".encode()
                        )

                    anthropic_chunk = openai_to_anthropic_chunk(chunk, requested_model)
                    if anthropic_chunk:
                        await resp.write(
                            f"event: {anthropic_chunk['type']}\ndata: {json.dumps(anthropic_chunk)}\n\n".encode()
                        )

                if not content_block_sent:
                    await resp.write(
                        f"event: content_block_start\ndata: {json.dumps({'type': 'content_block_start', 'index': 0, 'content_block': {'type': 'text', 'text': ''}})}\n\n".encode()
                    )

                await resp.write(
                    f"event: content_block_stop\ndata: {json.dumps({'type': 'content_block_stop', 'index': 0})}\n\n".encode()
                )
                await resp.write(
                    f"event: message_delta\ndata: {json.dumps({'type': 'message_delta', 'delta': {'stop_reason': 'end_turn'}, 'usage': {'output_tokens': 0}})}\n\n".encode()
                )
                await resp.write(
                    f"event: message_stop\ndata: {json.dumps({'type': 'message_stop'})}\n\n".encode()
                )

        await resp.write_eof()
        return resp
    else:
        timeout = aiohttp.ClientTimeout(total=HTTP_TIMEOUT)
        async with aiohttp.ClientSession(timeout=timeout) as session:
            async with session.post(url, json=openai_req, headers=headers) as client_resp:
                resp_body = await client_resp.json()
                anthropic_resp = openai_to_anthropic_response(resp_body, requested_model)
                return web.json_response(anthropic_resp)


async def handle_models(req: web.Request) -> web.Response:
    return web.json_response(
        {
            "object": "list",
            "data": [
                {
                    "id": MODEL_ID,
                    "object": "model",
                    "created": int(time.time()),
                    "owned_by": "b-ai",
                }
            ],
        }
    )


app = web.Application()
app.router.add_post("/v1/messages", handle_messages)
app.router.add_get("/v1/models", handle_models)

if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else PROXY_PORT
    web.run_app(app, host="127.0.0.1", port=port, print=None)
