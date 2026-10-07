/**
 * Cloud browsing for Sonot Code on phones.
 *
 * Runs the same browser-use helper the desktop app runs
 * (app/assets/helpers/sonot_browser.py) and streams its events to the app
 * as Server-Sent Events. With Cua credentials the browser itself runs on a
 * cua.ai cloud computer; without them it runs headless on this server.
 *
 *   POST /v1/browser   {task, token, model, start_url?, max_steps?, computer?}
 *   -> data: {"type": "status" | "step" | "done" | "error", ...}
 *   POST /v1/computer  {computer, action, x?, y?, x2?, y2?, dx?, dy?, text?, keys?, url?}
 *   -> {ok, text, screenshot?}     (needs Cua credentials)
 *
 * `computer` names a cloud computer of its own (a Bud's, or Sonot Code's).
 * The same name gets the same computer back while it is alive.
 *
 * `X-Cua-Api-Key` brings the app user's own Cua credentials
 * (`client_id:client_secret` or a Fleet token); they get a helper of their
 * own, and the key is never logged.
 *
 * The task's LLM calls use the app user's own Puter token (`token`), so the
 * user pays for their own browsing, same as chat.
 */
import { spawn, type ChildProcessWithoutNullStreams } from "node:child_process";
import { createHash } from "node:crypto";
import { existsSync } from "node:fs";
import type http from "node:http";
import { dirname, resolve } from "node:path";
import { createInterface } from "node:readline";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const HELPER = process.env.SONOT_BROWSER_HELPER ?? resolve(here, "../../app/assets/helpers/sonot_browser.py");
const UV = process.env.UV ?? "uv";
const CUA_VARS = ["SONOT_CUA", "FLEETS_TOKEN", "CUA_API_KEY", "CUA_CLIENT_ID", "CUA_CLIENT_SECRET"];
// The server's own Cua Fleet credentials (or SONOT_CUA=1 after `cua auth login` here).
const CLOUD = Boolean(
  process.env.SONOT_CUA === "1" || process.env.FLEETS_TOKEN || process.env.CUA_API_KEY || (process.env.CUA_CLIENT_ID && process.env.CUA_CLIENT_SECRET),
);
/** A user's own helper shuts down after this long unused. */
const IDLE_MS = 30 * 60_000;
const MAX_HELPERS = 20;

type Event = { type: string; id?: string; [k: string]: unknown };
type Listener = (e: Event) => void;

let nextId = 1;

/** One helper process. The server's own runs on its env credentials; each
 * app user who brings their own Cua key gets one of their own, so keys and
 * computers never mix. */
class Helper {
  proc: ChildProcessWithoutNullStreams | null = null;
  ready: Promise<void> | null = null;
  listeners = new Map<string, Listener>();
  lastUsed = Date.now();

  readonly cloud: boolean;
  readonly env: Record<string, string>;

  constructor(cloud: boolean, env: Record<string, string>) {
    this.cloud = cloud;
    this.env = env;
  }

  start(): Promise<void> {
    this.lastUsed = Date.now();
    if (this.ready) return this.ready;
    if (!existsSync(HELPER)) return Promise.reject(new Error(`Browser helper not found at ${HELPER}.`));
    const args = ["run", "--quiet", "--python", "3.12"];
    if (this.cloud) args.push("--with", "cua-sandbox", "--extra-index-url", "https://wheels.cua.ai/simple");
    args.push(HELPER);
    if (this.cloud) args.push("--cloud");
    const p = spawn(UV, args, {
      env: { ...this.env, PYTHONUNBUFFERED: "1", PYTHONIOENCODING: "utf-8", ...(!this.cloud && { SONOT_BROWSER_HEADLESS: "1" }) },
    });
    this.proc = p;
    const tail: string[] = [];
    createInterface({ input: p.stderr }).on("line", (l) => {
      tail.push(l);
      if (tail.length > 30) tail.shift();
    });
    this.ready = new Promise<void>((ok, fail) => {
      createInterface({ input: p.stdout }).on("line", (line) => {
        let ev: Event;
        try {
          ev = JSON.parse(line);
        } catch {
          return;
        }
        if (ev.type === "ready") return ok();
        const l = ev.id ? this.listeners.get(ev.id) : undefined;
        if (l) l(ev);
      });
      p.on("error", (e) => fail(new Error(`Couldn't start uv (${e.message}). Install it from https://docs.astral.sh/uv/.`)));
      p.on("exit", (code) => {
        const why = `The browser helper stopped (exit ${code}). ${tail.slice(-5).join(" ")}`;
        fail(new Error(why));
        for (const l of this.listeners.values()) l({ type: "error", message: why });
        this.listeners.clear();
        this.proc = null;
        this.ready = null;
      });
    });
    return this.ready;
  }

  send(msg: unknown) {
    this.lastUsed = Date.now();
    this.proc?.stdin.write(JSON.stringify(msg) + "\n");
  }

  stop() {
    this.proc?.kill();
  }
}

const serverEnv = Object.fromEntries(Object.entries(process.env).filter((e): e is [string, string] => e[1] !== undefined));
const ownHelper = new Helper(CLOUD, serverEnv);
const userHelpers = new Map<string, Helper>();

setInterval(() => {
  for (const [k, h] of userHelpers) {
    if (Date.now() - h.lastUsed > IDLE_MS && h.listeners.size === 0) {
      h.stop();
      userHelpers.delete(k);
    }
  }
}, 60_000).unref();

/**
 * The helper for a request. `X-Cua-Api-Key` carries the app user's own Cua
 * credentials: `client_id:client_secret`, or a Fleet token. Never logged.
 */
function helperFor(req: http.IncomingMessage): Helper {
  const raw = req.headers["x-cua-api-key"];
  const key = (Array.isArray(raw) ? raw[0] : raw)?.trim();
  if (!key) return ownHelper;
  const id = createHash("sha256").update(key).digest("hex");
  let h = userHelpers.get(id);
  if (!h) {
    if (userHelpers.size >= MAX_HELPERS) throw new Error("This Sonot server is busy. Try again later.");
    const env = Object.fromEntries(Object.entries(serverEnv).filter(([k]) => !CUA_VARS.includes(k)));
    const colon = key.indexOf(":");
    if (colon > 0) {
      env.CUA_CLIENT_ID = key.slice(0, colon);
      env.CUA_CLIENT_SECRET = key.slice(colon + 1);
    } else {
      env.FLEETS_TOKEN = key;
      env.CUA_API_KEY = key;
    }
    h = new Helper(true, env);
    userHelpers.set(id, h);
  }
  return h;
}

export async function handleBrowser(req: http.IncomingMessage, res: http.ServerResponse, body: unknown, cors: Record<string, string>) {
  const b = (body ?? {}) as { task?: unknown; token?: unknown; model?: unknown; start_url?: unknown; max_steps?: unknown; computer?: unknown };
  if (typeof b.task !== "string" || !b.task.trim() || typeof b.token !== "string" || !b.token) {
    res.writeHead(400, { "content-type": "application/json", ...cors });
    return res.end(JSON.stringify({ error: "`task` and `token` are required." }));
  }
  res.writeHead(200, {
    "content-type": "text/event-stream; charset=utf-8",
    "cache-control": "no-cache",
    connection: "keep-alive",
    "x-accel-buffering": "no",
    ...cors,
  });
  res.flushHeaders();
  const send = (e: Event) => res.write(`data: ${JSON.stringify(e)}\n\n`);
  const id = `s${nextId++}`;
  let finished = false;
  let helper: Helper;

  try {
    helper = helperFor(req);
    res.on("close", () => {
      helper.listeners.delete(id);
      if (!finished) helper.send({ type: "cancel", id });
    });
    send({ type: "status", text: helper.cloud ? "Starting a cloud computer" : "Starting the server's browser" });
    await helper.start();
  } catch (e) {
    finished = true;
    send({ type: "error", message: (e as Error).message });
    return res.end();
  }
  await new Promise<void>((done) => {
    helper.listeners.set(id, (ev) => {
      send(ev);
      if (ev.type === "done" || ev.type === "error") {
        finished = true;
        helper.listeners.delete(id);
        done();
      }
    });
    helper.send({
        type: "task",
        id,
        task: b.task,
        token: b.token,
        model: typeof b.model === "string" ? b.model : "claude-sonnet-5-5",
        start_url: typeof b.start_url === "string" ? b.start_url : undefined,
        max_steps: typeof b.max_steps === "number" ? Math.min(b.max_steps, 100) : 40,
        computer: computerName(b.computer),
      });
    res.on("close", () => done());
  });
  res.end();
}

const ACTIONS = new Set(["screenshot", "click", "double_click", "right_click", "move", "drag", "scroll", "type", "key", "open_url", "release"]);

function computerName(v: unknown): string {
  return typeof v === "string" && /^[A-Za-z0-9_.-]{1,64}$/.test(v) ? v : "default";
}

/** One computer-use action on a cloud computer. Answers JSON. */
export async function handleComputer(req: http.IncomingMessage, res: http.ServerResponse, body: unknown, cors: Record<string, string>) {
  const reply = (status: number, payload: unknown) => {
    res.writeHead(status, { "content-type": "application/json", ...cors });
    res.end(JSON.stringify(payload));
  };
  const b = (body ?? {}) as Record<string, unknown>;
  if (typeof b.action !== "string" || !ACTIONS.has(b.action)) return reply(400, { error: "Unknown `action`." });
  let helper: Helper;
  try {
    helper = helperFor(req);
    if (!helper.cloud) {
      return reply(200, { ok: false, text: "No cua.ai key: add yours in Sonot's settings, or set Cua credentials on the server." });
    }
    await helper.start();
  } catch (e) {
    return reply(200, { ok: false, text: (e as Error).message });
  }
  const id = `c${nextId++}`;
  const num = (k: string) => (typeof b[k] === "number" ? Math.round(b[k] as number) : undefined);
  const str = (k: string) => (typeof b[k] === "string" ? (b[k] as string).slice(0, 20000) : undefined);
  const result = await new Promise<Event>((done) => {
    const timer = setTimeout(() => done({ type: "result", ok: false, text: "The cloud computer took too long to answer." }), 15 * 60_000);
    helper.listeners.set(id, (ev) => {
      if (ev.type !== "result" && ev.type !== "error") return; // status lines
      clearTimeout(timer);
      helper.listeners.delete(id);
      done(ev);
    });
    helper.send({
        type: "computer",
        id,
        computer: computerName(b.computer),
        action: b.action,
        x: num("x"),
        y: num("y"),
        x2: num("x2"),
        y2: num("y2"),
        dx: num("dx"),
        dy: num("dy"),
        text: str("text"),
        keys: str("keys"),
        url: str("url"),
      });
  });
  const { type: _t, id: _i, ...rest } = result;
  reply(200, rest);
}

export const browserMode = () => (CLOUD ? "cua cloud computer" : "headless on this server");

/** Whether this server has Cua credentials of its own (for /health). */
export const hasCloud = () => CLOUD;
