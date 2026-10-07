# /// script
# requires-python = ">=3.11"
# dependencies = ["browser-use==0.13.10", "httpx>=0.28"]
# ///
"""Sonot Code's browser: browser-use (https://github.com/browser-use/browser-use)
driven by the user's own Puter account.

The Sonot app starts this with `uv run sonot_browser.py` and talks to it over
stdin/stdout, one JSON object per line.

In (app -> helper):
  {"type": "task", "id": "...", "task": "...", "token": "<puter token>",
   "model": "claude-sonnet-5-5", "start_url": "...", "max_steps": 40}
  {"type": "cancel", "id": "..."}
  {"type": "close"}                     closes the browser window

Out (helper -> app):
  {"type": "ready", "where": "local" | "cloud"}
  {"type": "status", "id", "text"}      setup progress (cloud computer, install)
  {"type": "step", "id", "n", "goal", "url", "title", "actions": [...], "screenshot": "<base64 jpeg>"}
  {"type": "done", "id", "ok", "result", "urls": [...], "steps": n}
  {"type": "error", "id", "message"}

`--cloud` runs the browser on a cua.ai cloud computer instead of this machine
(the Sonot server does this for phones). It needs `cua-sandbox` and Cua
credentials (CUA_API_KEY, or CUA_CLIENT_ID + CUA_CLIENT_SECRET).
"""

from __future__ import annotations

import asyncio
import base64
import io
import json
import os
import re
import sys
from typing import Any, TypeVar

os.environ.setdefault("ANONYMIZED_TELEMETRY", "false")
os.environ.setdefault("BROWSER_USE_SETUP_LOGGING", "false")

import httpx  # noqa: E402
from pydantic import BaseModel  # noqa: E402

from browser_use import Agent, Browser  # noqa: E402
from browser_use.llm.messages import BaseMessage  # noqa: E402
from browser_use.llm.openai.serializer import OpenAIMessageSerializer  # noqa: E402
from browser_use.llm.schema import SchemaOptimizer  # noqa: E402
from browser_use.llm.views import ChatInvokeCompletion  # noqa: E402

T = TypeVar("T", bound=BaseModel)

PUTER_API = os.environ.get("SONOT_PUTER_API", "https://api.puter.com")
_out_lock = asyncio.Lock()


async def emit(**msg: Any) -> None:
    async with _out_lock:
        sys.stdout.write(json.dumps(msg, ensure_ascii=False) + "\n")
        sys.stdout.flush()


class PuterError(Exception):
    pass


class ChatPuter:
    """browser-use chat model that calls Puter's `puter-chat-completion` driver,
    the same endpoint puter.js uses, with the user's own token (user-pays)."""

    _verified_api_keys = True

    def __init__(self, model: str, token: str):
        self.model = model
        self.token = token

    @property
    def provider(self) -> str:
        return "puter"

    @property
    def name(self) -> str:
        return self.model

    @property
    def model_name(self) -> str:
        return self.model

    async def _call(self, args: dict[str, Any]) -> tuple[str, list[dict[str, Any]]]:
        body = {
            "interface": "puter-chat-completion",
            "driver": "ai-chat",
            "method": "complete",
            "args": {"model": self.model, "stream": True, **args},
            "auth_token": self.token,
        }
        text, tools = [], []
        async with httpx.AsyncClient(timeout=httpx.Timeout(180, connect=20)) as client:
            async with client.stream(
                "POST",
                f"{PUTER_API}/drivers/call",
                json=body,
                headers={"authorization": f"Bearer {self.token}"},
            ) as res:
                if res.status_code != 200:
                    raw = (await res.aread()).decode("utf-8", "replace")
                    raise PuterError(f"Puter answered {res.status_code}: {raw[:400]}")
                async for line in res.aiter_lines():
                    if not line.strip():
                        continue
                    try:
                        chunk = json.loads(line)
                    except json.JSONDecodeError:
                        continue
                    if not isinstance(chunk, dict):
                        continue
                    if chunk.get("type") == "error" or chunk.get("success") is False or chunk.get("error"):
                        err = chunk.get("error")
                        msg = err.get("message") if isinstance(err, dict) else err or chunk.get("message")
                        raise PuterError(str(msg or "Puter returned an error."))
                    if chunk.get("type") == "text":
                        text.append(chunk.get("text") or "")
                    elif chunk.get("type") == "tool_use":
                        tools.append(chunk)
        return "".join(text), tools

    async def ainvoke(self, messages: list[BaseMessage], output_format: type[T] | None = None, **kwargs: Any):
        wire = [dict(m) for m in OpenAIMessageSerializer.serialize_messages(messages)]
        if output_format is None:
            text, _ = await self._call({"messages": wire})
            return ChatInvokeCompletion(completion=text, usage=None)

        schema = SchemaOptimizer.create_optimized_json_schema(output_format)
        tool = {
            "type": "function",
            "function": {
                "name": "agent_output",
                "description": "Your next step. Always answer by calling this tool.",
                "parameters": schema,
            },
        }
        text, tools = await self._call(
            {
                "messages": wire,
                "tools": [tool],
                "tool_choice": {"type": "function", "function": {"name": "agent_output"}},
            }
        )
        for t in tools:
            data = t.get("input")
            if isinstance(data, str):
                data = json.loads(data or "{}")
            return ChatInvokeCompletion(completion=output_format.model_validate(data), usage=None)
        # Some models answer in text instead of calling the tool.
        m = re.search(r"\{.*\}", text, re.S)
        if not m:
            raise PuterError("The model did not return a next step.")
        return ChatInvokeCompletion(completion=output_format.model_validate_json(m.group(0)), usage=None)


def _small_jpeg(b64png: str | None) -> str | None:
    """Shrinks a screenshot for the app's step card. Pillow ships with browser-use."""
    if not b64png:
        return None
    try:
        from PIL import Image

        img = Image.open(io.BytesIO(base64.b64decode(b64png))).convert("RGB")
        img.thumbnail((640, 640))
        buf = io.BytesIO()
        img.save(buf, "JPEG", quality=62)
        return base64.b64encode(buf.getvalue()).decode()
    except Exception:
        return None


class CloudComputer:
    """A cua.ai cloud computer whose Chromium browser-use drives over CDP."""

    def __init__(self) -> None:
        self.sb = None
        self._ctx = None
        self._tunnel = None
        self.cdp_url: str | None = None

    async def start(self, say) -> str:
        if self.cdp_url:
            return self.cdp_url
        try:
            from cua_sandbox import Image, Sandbox
        except ImportError as e:
            raise RuntimeError("cua-sandbox is not installed on this server.") from e
        await say("Starting a cloud computer")
        self._ctx = Sandbox.ephemeral(Image.linux(), on="cloud")
        self.sb = await self._ctx.__aenter__()
        await say("Opening the browser on it")
        launch = (
            "B=$(command -v chromium || command -v chromium-browser || command -v google-chrome || true); "
            'if [ -z "$B" ]; then (sudo -n apt-get update -qq && sudo -n apt-get install -y -qq chromium) >/dev/null 2>&1 '
            "|| (apt-get update -qq && apt-get install -y -qq chromium) >/dev/null 2>&1; "
            "B=$(command -v chromium || command -v chromium-browser); fi; "
            'export DISPLAY=${DISPLAY:-:0}; nohup "$B" --remote-debugging-port=9222 --remote-debugging-address=0.0.0.0 '
            "--no-first-run --no-default-browser-check --user-data-dir=/tmp/sonot-chrome about:blank >/tmp/sonot-chrome.log 2>&1 &"
        )
        await self.sb.shell.run(launch)
        self._tunnel = self.sb.tunnel.forward(9222)
        t = await self._tunnel.__aenter__()
        self.cdp_url = str(t.url).rstrip("/")
        for _ in range(60):
            try:
                async with httpx.AsyncClient(timeout=5) as c:
                    if (await c.get(f"{self.cdp_url}/json/version")).status_code == 200:
                        return self.cdp_url
            except Exception:
                pass
            await asyncio.sleep(2)
        raise RuntimeError("The cloud computer's browser did not start.")

    async def stop(self) -> None:
        for ctx in (self._tunnel, self._ctx):
            if ctx is not None:
                try:
                    await ctx.__aexit__(None, None, None)
                except Exception:
                    pass
        self.sb = self._ctx = self._tunnel = self.cdp_url = None


class Helper:
    def __init__(self, cloud: bool):
        self.cloud = CloudComputer() if cloud else None
        self.browser: Browser | None = None
        self.agents: dict[str, Agent] = {}
        self.tasks: dict[str, asyncio.Task] = {}

    async def _browser(self, say) -> Browser:
        if self.browser is not None:
            return self.browser
        if self.cloud:
            self.browser = Browser(cdp_url=await self.cloud.start(say), keep_alive=True)
        else:
            # A profile of its own, so sign-ins stick between tasks but never
            # touch the user's everyday browser profile.
            profile = os.environ.get("SONOT_BROWSER_PROFILE") or os.path.join(
                os.path.expanduser("~"), ".sonot", "browser-profile"
            )
            self.browser = Browser(
                headless=os.environ.get("SONOT_BROWSER_HEADLESS") == "1",
                user_data_dir=profile,
                keep_alive=True,
                executable_path=os.environ.get("SONOT_BROWSER_EXECUTABLE") or None,
                chromium_sandbox=os.environ.get("SONOT_BROWSER_NO_SANDBOX") != "1",
            )
        return self.browser

    async def run(self, msg: dict[str, Any]) -> None:
        tid = str(msg.get("id"))

        async def say(text: str) -> None:
            await emit(type="status", id=tid, text=text)

        try:
            token = msg.get("token") or ""
            if not token:
                raise RuntimeError("Sign in to Puter first.")
            llm = ChatPuter(msg.get("model") or "claude-sonnet-5-5", token)
            browser = await self._browser(say)

            async def on_step(state, output, n) -> None:
                actions = []
                for a in getattr(output, "action", None) or []:
                    d = a.model_dump(exclude_none=True)
                    actions.extend(f"{k} {json.dumps(v, ensure_ascii=False)[:160]}" for k, v in d.items())
                await emit(
                    type="step",
                    id=tid,
                    n=n,
                    goal=getattr(output, "next_goal", None) or "",
                    url=getattr(state, "url", ""),
                    title=getattr(state, "title", ""),
                    actions=actions,
                    screenshot=_small_jpeg(getattr(state, "screenshot", None)),
                )

            task = msg.get("task") or ""
            if msg.get("start_url"):
                task = f"Start at {msg['start_url']}. {task}"
            agent = Agent(
                task=task,
                llm=llm,
                browser=browser,
                register_new_step_callback=on_step,
                use_judge=False,
                use_vision=True,
                directly_open_url=True,
            )
            self.agents[tid] = agent
            history = await agent.run(max_steps=int(msg.get("max_steps") or 40))
            await emit(
                type="done",
                id=tid,
                ok=bool(history.is_successful()),
                result=history.final_result() or "",
                urls=[u for u in history.urls() if u][-8:],
                steps=history.number_of_steps(),
                errors=[e for e in history.errors() if e][-3:],
            )
        except asyncio.CancelledError:
            await emit(type="error", id=tid, message="Stopped.")
        except Exception as e:  # report everything; the app shows it on the step card
            await emit(type="error", id=tid, message=f"{type(e).__name__}: {e}")
        finally:
            self.agents.pop(tid, None)
            self.tasks.pop(tid, None)

    async def close(self) -> None:
        if self.browser is not None:
            try:
                await self.browser.kill()
            except Exception:
                pass
            self.browser = None
        if self.cloud:
            await self.cloud.stop()


async def main() -> None:
    helper = Helper(cloud="--cloud" in sys.argv)
    await emit(type="ready", where="cloud" if helper.cloud else "local")
    loop = asyncio.get_running_loop()
    while True:
        # A thread read works the same on Windows, where stdin pipes can't be
        # attached to the event loop.
        line = await loop.run_in_executor(None, sys.stdin.readline)
        if not line:
            break
        try:
            msg = json.loads(line)
        except json.JSONDecodeError:
            continue
        kind = msg.get("type")
        tid = str(msg.get("id"))
        if kind == "task":
            helper.tasks[tid] = asyncio.create_task(helper.run(msg))
        elif kind == "cancel":
            if tid in helper.agents:
                helper.agents[tid].stop()
            if tid in helper.tasks:
                helper.tasks[tid].cancel()
        elif kind == "close":
            await helper.close()
    await helper.close()


if __name__ == "__main__":
    asyncio.run(main())
