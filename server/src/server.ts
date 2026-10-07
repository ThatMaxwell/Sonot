/**
 * Sonot chat server.
 *
 * Holds the Anthropic API key so the app never ships it. The app POSTs the
 * conversation to /v1/chat and gets the reply back as Server-Sent Events:
 *
 *   event: delta   data: {"text": "..."}          (repeated)
 *   event: done    data: {"stop_reason": "..."}
 *   event: error   data: {"message": "..."}
 *
 * Config (environment):
 *   ANTHROPIC_API_KEY   required: your Anthropic key
 *   PORT                default 8787
 *   HOST                default 127.0.0.1 (use 0.0.0.0 to reach it from a phone)
 *   SONOT_APP_TOKEN     optional: if set, the app must send `Authorization: Bearer <token>`
 *   SONOT_MODEL         default claude-opus-5-5 (used when the app sends no Claude model)
 *   SONOT_EFFORT        default medium (low | medium | high | xhigh | max)
 *
 * The app normally talks to Puter directly (each user pays for their own
 * usage). This server is the self-hosted alternative.
 */
import http from "node:http";
import Anthropic from "@anthropic-ai/sdk";
import { browserMode, handleBrowser } from "./browser.ts";
import type { BetaMessageParam } from "@anthropic-ai/sdk/resources/beta/messages/messages";

const PORT = Number(process.env.PORT ?? 8787);
const HOST = process.env.HOST ?? "127.0.0.1";
const APP_TOKEN = process.env.SONOT_APP_TOKEN ?? "";
const MODEL = process.env.SONOT_MODEL ?? "claude-opus-5-5";
const EFFORTS = ["low", "medium", "high", "xhigh", "max"] as const;
type Effort = (typeof EFFORTS)[number];
const EFFORT = (process.env.SONOT_EFFORT ?? "medium") as Effort;
const MAX_BODY_BYTES = 2 * 1024 * 1024;
const MAX_MESSAGES = 200;

const SYSTEM = {
  chat: `You are Sonot, a friendly and sharp AI assistant made by ThatMaxwell.
Answer clearly and get to the point. Use Markdown when it helps (lists, code blocks), and plain prose for casual chat.`,
  code: `You are Sonot Code, the coding side of Sonot, made by ThatMaxwell.
You are a senior engineer pairing with the user. Be precise and direct. Prefer working code over discussion:
give complete, runnable snippets in fenced code blocks with a language tag, then a short note on anything non-obvious.
Ask a clarifying question only when the task truly cannot proceed without it.`,
};
type Mode = keyof typeof SYSTEM;

const client = new Anthropic();

type ChatMessage = { role: "user" | "assistant"; content: string };

/** Validates the app's message list. Returns an error string or the cleaned list. */
function parseMessages(body: unknown): ChatMessage[] | string {
  if (typeof body !== "object" || body === null) return "Body must be a JSON object.";
  const messages = (body as { messages?: unknown }).messages;
  if (!Array.isArray(messages) || messages.length === 0) return "`messages` must be a non-empty array.";
  if (messages.length > MAX_MESSAGES) return `At most ${MAX_MESSAGES} messages.`;
  const out: ChatMessage[] = [];
  for (const m of messages) {
    if (typeof m !== "object" || m === null) return "Each message must be an object.";
    const { role, content } = m as { role?: unknown; content?: unknown };
    if (role !== "user" && role !== "assistant") return "`role` must be 'user' or 'assistant'.";
    if (typeof content !== "string" || content.trim() === "") return "`content` must be a non-empty string.";
    out.push({ role, content });
  }
  if (out[0].role !== "user") return "The first message must be from the user.";
  if (out[out.length - 1].role !== "user") return "The last message must be from the user.";
  return out;
}

function readBody(req: http.IncomingMessage): Promise<string> {
  return new Promise((resolve, reject) => {
    let size = 0;
    const chunks: Buffer[] = [];
    req.on("data", (c: Buffer) => {
      size += c.length;
      if (size > MAX_BODY_BYTES) {
        reject(new Error("Request body too large."));
        req.destroy();
        return;
      }
      chunks.push(c);
    });
    req.on("end", () => resolve(Buffer.concat(chunks).toString("utf8")));
    req.on("error", reject);
  });
}

function sendJson(res: http.ServerResponse, status: number, payload: unknown) {
  res.writeHead(status, { "content-type": "application/json", ...cors });
  res.end(JSON.stringify(payload));
}

const cors = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, content-type",
  "access-control-allow-methods": "GET, POST, OPTIONS",
};

function sse(res: http.ServerResponse, event: string, data: unknown) {
  res.write(`event: ${event}\ndata: ${JSON.stringify(data)}\n\n`);
}

/** Merges consecutive same-role turns (e.g. a user retrying after an error). */
function mergeTurns(messages: ChatMessage[]): BetaMessageParam[] {
  const out: BetaMessageParam[] = [];
  for (const m of messages) {
    const last = out[out.length - 1];
    if (last && last.role === m.role) last.content = `${last.content}\n\n${m.content}`;
    else out.push({ role: m.role, content: m.content });
  }
  return out;
}

async function handleChat(req: http.IncomingMessage, res: http.ServerResponse) {
  let body: unknown;
  try {
    body = JSON.parse(await readBody(req));
  } catch (e) {
    return sendJson(res, 400, { error: e instanceof SyntaxError ? "Invalid JSON." : String((e as Error).message) });
  }
  const messages = parseMessages(body);
  if (typeof messages === "string") return sendJson(res, 400, { error: messages });
  const opts = body as { mode?: unknown; model?: unknown; effort?: unknown; system?: unknown };
  // Buds send their own persona; cap it so a request can't balloon.
  const system = typeof opts.system === "string" && opts.system.trim() ? opts.system.slice(0, 20000) : null;
  const mode: Mode = opts.mode === "code" ? "code" : "chat";
  // The app sends the Sonot tier's model id; only Claude models run here.
  const model = typeof opts.model === "string" && /^claude-[a-z0-9-]+$/.test(opts.model) ? opts.model : MODEL;
  // The app speaks Puter's effort scale, which adds "none"; Claude's lowest is "low".
  const asked = opts.effort === "none" ? "low" : opts.effort;
  const effort = EFFORTS.includes(asked as Effort) ? (asked as Effort) : EFFORT;
  // Haiku 4.5 predates adaptive thinking and effort; send it a plain request.
  const modern = !model.startsWith("claude-haiku");

  res.writeHead(200, {
    "content-type": "text/event-stream; charset=utf-8",
    "cache-control": "no-cache",
    connection: "keep-alive",
    "x-accel-buffering": "no",
    ...cors,
  });
  res.flushHeaders();

  const stream = client.beta.messages.stream({
    model,
    max_tokens: modern ? 64000 : 32000,
    system: system ?? SYSTEM[mode],
    messages: mergeTurns(messages),
    ...(modern && {
      thinking: { type: "adaptive" },
      output_config: { effort },
      // If a safety classifier declines, the API retries on a fallback model in the same call.
      betas: ["server-side-fallback-2026-07-01"],
      fallbacks: "default",
    }),
  });

  // Stop paying for tokens nobody will read once the app hangs up.
  res.on("close", () => {
    if (!res.writableFinished) stream.abort();
  });

  try {
    for await (const event of stream) {
      if (event.type === "content_block_delta" && event.delta.type === "text_delta") {
        sse(res, "delta", { text: event.delta.text });
      }
    }
    const final = await stream.finalMessage();
    if (final.stop_reason === "refusal") {
      sse(res, "error", { message: "Sonot can't help with that one." });
    } else {
      sse(res, "done", { stop_reason: final.stop_reason });
    }
  } catch (e) {
    if (res.destroyed) return;
    sse(res, "error", { message: describeError(e) });
  }
  res.end();
}

function describeError(e: unknown): string {
  if (e instanceof Anthropic.AuthenticationError) return "The server's API key was rejected.";
  if (e instanceof Anthropic.RateLimitError) return "Sonot is busy right now. Try again in a moment.";
  if (e instanceof Anthropic.APIConnectionError) return "The server couldn't reach the AI provider.";
  if (e instanceof Anthropic.APIError) return `The AI provider returned an error (${e.status ?? "unknown"}).`;
  console.error(e);
  return "Something went wrong on the server.";
}

function authorized(req: http.IncomingMessage): boolean {
  if (!APP_TOKEN) return true;
  return req.headers.authorization === `Bearer ${APP_TOKEN}`;
}

const server = http.createServer((req, res) => {
  const url = new URL(req.url ?? "/", "http://localhost");
  if (req.method === "OPTIONS") {
    res.writeHead(204, cors);
    return res.end();
  }
  if (req.method === "GET" && url.pathname === "/health") {
    return sendJson(res, 200, { ok: true, model: MODEL });
  }
  if (req.method === "POST" && url.pathname === "/v1/chat") {
    if (!authorized(req)) return sendJson(res, 401, { error: "Missing or wrong app token." });
    handleChat(req, res).catch((e) => {
      console.error(e);
      if (!res.headersSent) sendJson(res, 500, { error: "Server error." });
      else res.end();
    });
    return;
  }
  if (req.method === "POST" && url.pathname === "/v1/browser") {
    if (!authorized(req)) return sendJson(res, 401, { error: "Missing or wrong app token." });
    readBody(req)
      .then((raw) => handleBrowser(req, res, JSON.parse(raw), cors))
      .catch((e) => {
        if (!res.headersSent) sendJson(res, 400, { error: e instanceof SyntaxError ? "Invalid JSON." : String((e as Error).message) });
        else res.end();
      });
    return;
  }
  sendJson(res, 404, { error: "Not found." });
});

server.listen(PORT, HOST, () => {
  console.log(`Sonot server on http://${HOST}:${PORT} (model ${MODEL}, effort ${EFFORT}; browser: ${browserMode()})`);
  if (!process.env.ANTHROPIC_API_KEY) console.warn("Warning: ANTHROPIC_API_KEY is not set; chats will fail.");
  if (!APP_TOKEN) console.warn("Note: SONOT_APP_TOKEN is not set; anyone who can reach this port can chat.");
});
