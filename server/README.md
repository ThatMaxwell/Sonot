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

API: `POST /v1/chat` with `{mode, model, effort, messages}` returns Server-Sent Events (`delta`, then `done` or `error`). `GET /health` for a check. Needs Node 22.18+ (runs the TypeScript directly).
