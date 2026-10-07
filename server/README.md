# Sonot server (optional)

The app talks to Puter directly by default, so most people never need this. Run it when you want Sonot on your own Anthropic API key instead: it holds the key and streams replies to the app, so the key never ships inside the app.

```sh
cd server
npm install
ANTHROPIC_API_KEY=sk-ant-... npm start                    # http://127.0.0.1:8787
HOST=0.0.0.0 SONOT_APP_TOKEN=pick-a-secret npm start      # reachable from your phone
```

In the app: **Use my own server**, then your PC's address (for example `192.168.1.20:8787`) and the app token.

| Variable | Default | |
|---|---|---|
| `ANTHROPIC_API_KEY` | | required |
| `PORT` / `HOST` | `8787` / `127.0.0.1` | |
| `SONOT_APP_TOKEN` | | if set, the app must send it |
| `SONOT_MODEL` | `claude-opus-5-5` | used when the app's tier isn't a Claude model |
| `SONOT_EFFORT` | `medium` | default effort |

### Cloud computers for Buds and Sonot Code

`POST /v1/computer` with `{computer, action, ...}` drives a named cua.ai cloud computer (a Linux desktop): `screenshot`, `click`, `double_click`, `right_click`, `move`, `drag`, `scroll`, `type`, `key`, `open_url`, `release`. Every action answers `{ok, text, screenshot}` (base64 JPEG). Each Bud has its own computer, and `/v1/browser` with the same `computer` runs browser-use on that computer's Chromium. Computers stay up for `SONOT_COMPUTER_KEEP_MINUTES` (30) after the last use. Needs Cua credentials (below).

### Cloud browsing for Sonot Code

Phones can't run a browser for the agent, so Sonot Code on Android sends browser tasks here: `POST /v1/browser` with `{task, token, model}` streams the same events the desktop helper emits. The server runs [`app/assets/helpers/sonot_browser.py`](../app/assets/helpers/sonot_browser.py) with [uv](https://docs.astral.sh/uv/) (install it first). The task's AI calls use the phone user's own Puter token.

| Variable | |
|---|---|
| `CUA_CLIENT_ID` + `CUA_CLIENT_SECRET` (or `SONOT_CUA=1` after `cua auth login`) | the browser runs on a [cua.ai](https://cua.ai) cloud computer. Without them it runs headless on this machine. |
| `SONOT_BROWSER_NO_SANDBOX=1` | needed when the server runs as root (Docker). |

One helper (and one cloud computer) is shared by everyone using this server, so keep it to people you trust.

API: `POST /v1/chat` with `{mode, model, effort, messages}` returns Server-Sent Events (`delta`, then `done` or `error`). `GET /health` for a check. Needs Node 22.18+ (runs the TypeScript directly).
