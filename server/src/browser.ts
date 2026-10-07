/**
 * Cloud browsing for Sonot Code on phones.
 *
 * Runs the same browser-use helper the desktop app runs
 * (app/assets/helpers/sonot_browser.py) and streams its events to the app
 * as Server-Sent Events. With Cua credentials the browser itself runs on a
 * cua.ai cloud computer; without them it runs headless on this server.
 *
 *   POST /v1/browser  {task, token, model, start_url?, max_steps?}
 *   -> data: {"type": "status" | "step" | "done" | "error", ...}
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
const CLOUD = Boolean(process.env.CUA_API_KEY || (process.env.CUA_CLIENT_ID && process.env.CUA_CLIENT_SECRET));

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
  const b = (body ?? {}) as { task?: unknown; token?: unknown; model?: unknown; start_url?: unknown; max_steps?: unknown };
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
      }) + "\n",
    );
    res.on("close", () => done());
  });
  res.end();
}

export const browserMode = () => (CLOUD ? "cua cloud computer" : "headless on this server");
