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
 * The task's LLM calls use the app user's own Puter token (`token`), so the
 * user pays for their own browsing, same as chat.
 */
import { spawn, type ChildProcessWithoutNullStreams } from "node:child_process";
import { existsSync } from "node:fs";
import type http from "node:http";
import { dirname, resolve } from "node:path";
import { createInterface } from "node:readline";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const HELPER = process.env.SONOT_BROWSER_HELPER ?? resolve(here, "../../app/assets/helpers/sonot_browser.py");
const UV = process.env.UV ?? "uv";
// Cua Fleet credentials (or SONOT_CUA=1 after `cua auth login` on this machine).
const CLOUD = Boolean(
  process.env.SONOT_CUA === "1" || process.env.FLEETS_TOKEN || process.env.CUA_API_KEY || (process.env.CUA_CLIENT_ID && process.env.CUA_CLIENT_SECRET),
);

type Event = { type: string; id?: string; [k: string]: unknown };
type Listener = (e: Event) => void;

let helper: ChildProcessWithoutNullStreams | null = null;
let ready: Promise<void> | null = null;
const listeners = new Map<string, Listener>();
let nextId = 1;

function start(): Promise<void> {
  if (ready) return ready;
  if (!existsSync(HELPER)) return Promise.reject(new Error(`Browser helper not found at ${HELPER}.`));
  const args = ["run", "--quiet", "--python", "3.12"];
  if (CLOUD) args.push("--with", "cua-sandbox", "--extra-index-url", "https://wheels.cua.ai/simple");
  args.push(HELPER);
  if (CLOUD) args.push("--cloud");
  const p = spawn(UV, args, {
    env: { ...process.env, PYTHONUNBUFFERED: "1", PYTHONIOENCODING: "utf-8", ...(!CLOUD && { SONOT_BROWSER_HEADLESS: "1" }) },
  });
  helper = p;
  const tail: string[] = [];
  createInterface({ input: p.stderr }).on("line", (l) => {
    tail.push(l);
    if (tail.length > 30) tail.shift();
  });
  ready = new Promise<void>((ok, fail) => {
    createInterface({ input: p.stdout }).on("line", (line) => {
      let ev: Event;
      try {
        ev = JSON.parse(line);
      } catch {
        return;
      }
      if (ev.type === "ready") return ok();
      const l = ev.id ? listeners.get(ev.id) : undefined;
      if (l) l(ev);
    });
    p.on("error", (e) => fail(new Error(`Couldn't start uv (${e.message}). Install it from https://docs.astral.sh/uv/.`)));
    p.on("exit", (code) => {
      const why = `The browser helper stopped (exit ${code}). ${tail.slice(-5).join(" ")}`;
      fail(new Error(why));
      for (const l of listeners.values()) l({ type: "error", message: why });
      listeners.clear();
      helper = null;
      ready = null;
    });
  });
  return ready;
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

  res.on("close", () => {
    listeners.delete(id);
    if (!finished && helper) helper.stdin.write(JSON.stringify({ type: "cancel", id }) + "\n");
  });

  try {
    send({ type: "status", text: CLOUD ? "Starting a cloud computer" : "Starting the server's browser" });
    await start();
  } catch (e) {
    finished = true;
    send({ type: "error", message: (e as Error).message });
    return res.end();
  }
  await new Promise<void>((done) => {
    listeners.set(id, (ev) => {
      send(ev);
      if (ev.type === "done" || ev.type === "error") {
        finished = true;
        listeners.delete(id);
        done();
      }
    });
    helper!.stdin.write(
      JSON.stringify({
        type: "task",
        id,
        task: b.task,
        token: b.token,
        model: typeof b.model === "string" ? b.model : "claude-sonnet-5-5",
        start_url: typeof b.start_url === "string" ? b.start_url : undefined,
        max_steps: typeof b.max_steps === "number" ? Math.min(b.max_steps, 100) : 40,
        computer: computerName(b.computer),
      }) + "\n",
    );
    res.on("close", () => done());
  });
  res.end();
}

const ACTIONS = new Set(["screenshot", "click", "double_click", "right_click", "move", "drag", "scroll", "type", "key", "open_url", "release"]);

function computerName(v: unknown): string {
  return typeof v === "string" && /^[A-Za-z0-9_.-]{1,64}$/.test(v) ? v : "default";
}

/** One computer-use action on a cloud computer. Answers JSON. */
export async function handleComputer(res: http.ServerResponse, body: unknown, cors: Record<string, string>) {
  const reply = (status: number, payload: unknown) => {
    res.writeHead(status, { "content-type": "application/json", ...cors });
    res.end(JSON.stringify(payload));
  };
  const b = (body ?? {}) as Record<string, unknown>;
  if (!CLOUD) return reply(200, { ok: false, text: "This Sonot server has no Cua credentials, so it has no cloud computers." });
  if (typeof b.action !== "string" || !ACTIONS.has(b.action)) return reply(400, { error: "Unknown `action`." });
  try {
    await start();
  } catch (e) {
    return reply(200, { ok: false, text: (e as Error).message });
  }
  const id = `c${nextId++}`;
  const num = (k: string) => (typeof b[k] === "number" ? Math.round(b[k] as number) : undefined);
  const str = (k: string) => (typeof b[k] === "string" ? (b[k] as string).slice(0, 20000) : undefined);
  const result = await new Promise<Event>((done) => {
    const timer = setTimeout(() => done({ type: "result", ok: false, text: "The cloud computer took too long to answer." }), 15 * 60_000);
    listeners.set(id, (ev) => {
      if (ev.type !== "result" && ev.type !== "error") return; // status lines
      clearTimeout(timer);
      listeners.delete(id);
      done(ev);
    });
    helper!.stdin.write(
      JSON.stringify({
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
      }) + "\n",
    );
  });
  const { type: _t, id: _i, ...rest } = result;
  reply(200, rest);
}

export const browserMode = () => (CLOUD ? "cua cloud computer" : "headless on this server");
