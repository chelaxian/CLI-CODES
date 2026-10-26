"""Офлайн-тесты ядра CLI-CODES: прокси Anthropic→OpenAI, парсер моделей, реестры TXT/.

Запуск:  python -m unittest discover -s tests -v
"""

import importlib.util
import io
import json
import os
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIB = os.path.join(ROOT, "scripts", "lib")


def load(name, filename):
    spec = importlib.util.spec_from_file_location(name, os.path.join(LIB, filename))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


proxy = load("anthropic_proxy", "anthropic-proxy.py")
models = load("models", "models.py")


def rows(path):
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#"):
                yield [c.strip() for c in line.split("|")]


class ProxyRequestTest(unittest.TestCase):
    def test_tool_roundtrip_is_translated_to_openai_messages(self):
        body = {
            "model": "claude-x", "max_tokens": 100, "system": [{"type": "text", "text": "be brief"}],
            "tools": [{"name": "get_weather", "description": "d", "input_schema": {"type": "object"}}],
            "tool_choice": {"type": "any"},
            "messages": [
                {"role": "user", "content": "weather?"},
                {"role": "assistant", "content": [{"type": "text", "text": "checking"},
                                                  {"type": "tool_use", "id": "t1", "name": "get_weather", "input": {"city": "Paris"}}]},
                {"role": "user", "content": [{"type": "tool_result", "tool_use_id": "t1", "content": [{"type": "text", "text": "Sunny"}]},
                                             {"type": "text", "text": "thanks"}]},
            ],
        }
        req = proxy.convert_request(body)
        roles = [m["role"] for m in req["messages"]]
        self.assertEqual(roles, ["system", "user", "assistant", "tool", "user"])
        call = req["messages"][2]["tool_calls"][0]
        self.assertEqual(call["function"]["name"], "get_weather")
        self.assertEqual(json.loads(call["function"]["arguments"]), {"city": "Paris"})
        self.assertEqual(req["messages"][3], {"role": "tool", "tool_call_id": "t1", "content": "Sunny"})
        self.assertEqual(req["tool_choice"], "required")
        self.assertEqual(req["tools"][0]["function"]["parameters"], {"type": "object"})

    def test_forced_model_and_token_cap(self):
        proxy.FORCED_MODEL, proxy.MAX_TOKENS_CAP = "glm-5.3", 4096
        try:
            req = proxy.convert_request({"model": "claude-x", "max_tokens": 32000, "messages": []})
            self.assertEqual((req["model"], req["max_tokens"]), ("glm-5.3", 4096))
        finally:
            proxy.FORCED_MODEL, proxy.MAX_TOKENS_CAP = "", 0

    def test_image_block_becomes_data_uri(self):
        req = proxy.convert_request({"messages": [{"role": "user", "content": [
            {"type": "image", "source": {"type": "base64", "media_type": "image/png", "data": "AAA"}},
            {"type": "text", "text": "what is it"}]}]})
        parts = req["messages"][0]["content"]
        self.assertEqual(parts[0]["image_url"]["url"], "data:image/png;base64,AAA")


class ProxyResponseTest(unittest.TestCase):
    def test_non_stream_tool_call(self):
        resp = {"choices": [{"finish_reason": "tool_calls", "message": {"content": None, "tool_calls": [
            {"id": "c1", "function": {"name": "f", "arguments": "{\"a\": 1}"}}]}}],
            "usage": {"prompt_tokens": 5, "completion_tokens": 7}}
        out = proxy.convert_response(resp, "m")
        self.assertEqual(out["stop_reason"], "tool_use")
        self.assertEqual(out["content"][0], {"type": "tool_use", "id": "c1", "name": "f", "input": {"a": 1}})
        self.assertEqual(out["usage"], {"input_tokens": 5, "output_tokens": 7})

    def test_stream_text_then_two_tools(self):
        tr = proxy.StreamTranslator("m")
        events = tr.start()
        chunks = [
            {"choices": [{"delta": {"content": "Hi"}}]},
            {"choices": [{"delta": {"tool_calls": [{"index": 0, "id": "a", "function": {"name": "f1", "arguments": "{\"x\""}}]}}]},
            {"choices": [{"delta": {"tool_calls": [{"index": 0, "function": {"arguments": ":1}"}}]}}]},
            {"choices": [{"delta": {"tool_calls": [{"index": 1, "id": "b", "function": {"name": "f2", "arguments": "{}"}}]}}]},
            {"choices": [{"delta": {}, "finish_reason": "tool_calls"}]},
            {"choices": [], "usage": {"prompt_tokens": 3, "completion_tokens": 4}},
        ]
        for c in chunks:
            events += tr.feed(c)
        events += tr.finish()
        names = [e[0] for e in events]
        self.assertEqual(names, ["message_start",
                                 "content_block_start", "content_block_delta",            # text
                                 "content_block_stop", "content_block_start",             # tool a
                                 "content_block_delta", "content_block_delta",
                                 "content_block_stop", "content_block_start",             # tool b
                                 "content_block_delta",
                                 "content_block_stop", "message_delta", "message_stop"])
        starts = [e[1]["content_block"] for e in events if e[0] == "content_block_start"]
        self.assertEqual([s["type"] for s in starts], ["text", "tool_use", "tool_use"])
        self.assertEqual([s.get("id") for s in starts[1:]], ["a", "b"])
        delta = events[-2][1]
        self.assertEqual(delta["delta"]["stop_reason"], "tool_use")
        self.assertEqual(delta["usage"], {"input_tokens": 3, "output_tokens": 4})

    def test_stream_tool_with_stop_finish_reason_and_no_index(self):
        # Gemini-подобный поток: tool_calls без index, finish_reason=stop
        tr = proxy.StreamTranslator("m")
        events = tr.start()
        for c in ({"choices": [{"delta": {"tool_calls": [{"id": "a", "function": {"name": "f1", "arguments": "{}"}}]}}]},
                  {"choices": [{"delta": {"tool_calls": [{"id": "b", "function": {"name": "f2", "arguments": "{}"}}]}}]},
                  {"choices": [{"delta": {}, "finish_reason": "stop"}]}):
            events += tr.feed(c)
        events += tr.finish()
        starts = [e[1]["content_block"]["id"] for e in events if e[0] == "content_block_start"]
        self.assertEqual(starts, ["a", "b"])
        self.assertEqual(events[-2][1]["delta"]["stop_reason"], "tool_use")

    def test_empty_stream_still_has_a_block(self):
        tr = proxy.StreamTranslator("m")
        names = [e[0] for e in tr.start() + tr.finish()]
        self.assertIn("content_block_start", names)


class ProxyHttpTest(unittest.TestCase):
    """Поднимает прокси на случайном порту и проверяет защиту без обращения к апстриму."""

    @classmethod
    def setUpClass(cls):
        import http.server, threading
        proxy.PROXY_TOKEN = "secret-token"
        cls.server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), proxy.Handler)
        threading.Thread(target=cls.server.serve_forever, daemon=True).start()
        cls.port = cls.server.server_address[1]

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        proxy.PROXY_TOKEN = ""

    def post(self, headers, path="/v1/messages/count_tokens"):
        import http.client
        c = http.client.HTTPConnection("127.0.0.1", self.port, timeout=5)
        c.request("POST", path, body=b'{"messages": []}', headers=headers)
        r = c.getresponse()
        return r.status, json.loads(r.read() or b"{}")

    def test_rejects_missing_token(self):
        self.assertEqual(self.post({"Content-Type": "application/json"})[0], 401)

    def test_rejects_non_json_content_type(self):
        self.assertEqual(self.post({"Content-Type": "text/plain", "x-api-key": "secret-token"})[0], 415)

    def test_accepts_valid_token(self):
        status, body = self.post({"Content-Type": "application/json", "Authorization": "Bearer secret-token"})
        self.assertEqual(status, 200)
        self.assertIn("input_tokens", body)


class ModelsParserTest(unittest.TestCase):
    def run_parser(self, provider, payload):
        old_in, old_out = sys.stdin, sys.stdout
        sys.stdin, sys.stdout = io.StringIO(json.dumps(payload)), io.StringIO()
        sys.argv = ["models.py", provider]
        try:
            models.main()
            return [l.split("|", 1) for l in sys.stdout.getvalue().splitlines()]
        finally:
            sys.stdin, sys.stdout = old_in, old_out

    def test_filters_non_chat_and_sorts_free_first(self):
        out = self.run_parser("nim", {"data": [{"id": "z/paid"}, {"id": "nvidia/nv-embedqa-mistral-7b-v2"},
                                               {"id": "a/model-free"}, {"id": "openai/whisper-large-v3"}]})
        self.assertEqual([r[0] for r in out], ["a/model-free", "z/paid"])

    def test_openrouter_requires_tools_and_detects_free_by_price(self):
        out = self.run_parser("openrouter", {"data": [
            {"id": "x/no-tools", "supported_parameters": ["temperature"]},
            {"id": "y/paid", "name": "Y", "supported_parameters": ["tools"], "pricing": {"prompt": "0.1", "completion": "0.2"}},
            {"id": "z/zero", "name": "Z", "context_length": 128000, "supported_parameters": ["tools"], "pricing": {"prompt": "0", "completion": "0"}},
        ]})
        self.assertEqual(out, [["z/zero", "Z (free, 128k ctx)"], ["y/paid", "Y"]])

    def test_github_catalog_list_format(self):
        out = self.run_parser("github", [{"id": "openai/gpt-x", "name": "GPT X"}])
        self.assertEqual(out, [["openai/gpt-x", "GPT X"]])


class RegistryTest(unittest.TestCase):
    INSTALL_KINDS = {"npm", "uv", "sh", "ps"}
    ADAPTERS = {"claude", "openclaude", "qwen", "opencode", "codex", "gemini", "aider", "goose", "env"}

    def test_agents(self):
        keys = set()
        for c in rows(os.path.join(ROOT, "TXT", "agents.txt")):
            self.assertEqual(len(c), 9, c)
            key, _, cmd, linux, win, adapter, legacy = c[:7]
            self.assertNotIn(key, keys); keys.add(key)
            self.assertTrue(cmd)
            self.assertIn(adapter, self.ADAPTERS, key)
            for spec, allowed in ((linux, {"npm", "uv", "sh"}), (win, {"npm", "uv", "ps"})):
                if spec != "-":
                    self.assertIn(spec.split(":", 1)[0], allowed, (key, spec))
            if legacy != "-":
                self.assertTrue(os.path.exists(os.path.join(ROOT, "scripts", legacy + ".sh")), legacy)

    def test_providers_and_static_catalogs(self):
        keys = set()
        for c in rows(os.path.join(ROOT, "TXT", "providers.txt")):
            self.assertEqual(len(c), 11, c)
            key, _, _, env, base, _, auth, tier, anth, resp, _ = c
            self.assertNotIn(key, keys); keys.add(key)
            self.assertTrue(base.startswith("http"), key)
            self.assertIn(auth, {"key", "optional", "none"}, key)
            self.assertIn(tier, {"free", "freemium", "paid", "local"}, key)
            self.assertIn(resp, {"yes", "no"}, key)
            self.assertTrue(anth == "-" or anth.startswith("http"), key)
            self.assertTrue(env != "-" or auth == "none", key)
            catalog = os.path.join(ROOT, "TXT", "models", key + ".txt")
            self.assertTrue(os.path.exists(catalog), catalog)
            self.assertTrue(list(rows(catalog)), catalog)


if __name__ == "__main__":
    unittest.main()
