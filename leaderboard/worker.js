// The Shooty McBridgeface leaderboard: one Cloudflare Worker and one KV
// namespace. Daily and weekly runs only (everyone plays the same seed, so
// a score is comparable and checkable). The game signs each submission
// with a secret that only CI and this Worker know; the Worker checks the
// signature, the period, and whether the game could have produced the
// numbers, then keeps the best score per player per period.
//
// Bindings: BOARD (KV namespace), SIGNING_SECRET (secret).

export const EPOCH_DAY = 20748; // matches scripts/core/daily.gd
export const TOP_KEPT = 200;
export const TOP_SHOWN = 50;
export const NAME_RE = /^[A-Za-z0-9 _-]{2,14}$/;
export const BANNED = ["admin", "fuck", "shit", "cunt", "nigg", "fag", "hitler"];
export const CAPS = {
  minLevel: 1,
  maxLevel: 40,
  scorePerLevel: 12000,
  scoreBase: 20000,
  killsPerLevel: 400,
  killsBase: 200,
  secondsPerLevel: 25,
  maxPeak: 500,
};
export const RATE_PER_MINUTE = 20;
export const GRACE_SECONDS = 15 * 60;

const enc = new TextEncoder();

export function dayNumber(unix) {
  return Math.floor(unix / 86400) - EPOCH_DAY + 1;
}

export function weekNumber(unix) {
  return Math.floor((dayNumber(unix) - 1) / 7) + 1;
}

export function canonical(p) {
  return `v1|${p.id}|${p.mode}|${p.period}|${p.score}|${p.level}|${p.kills}|${p.peak}|${p.seconds}`;
}

export async function hmacHex(secret, text) {
  const key = await crypto.subtle.importKey("raw", enc.encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const sig = await crypto.subtle.sign("HMAC", key, enc.encode(text));
  return [...new Uint8Array(sig)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

function timingEqual(a, b) {
  if (typeof a !== "string" || typeof b !== "string" || a.length !== b.length) return false;
  let out = 0;
  for (let i = 0; i < a.length; i++) out |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return out === 0;
}

export function cleanName(name) {
  if (typeof name !== "string") return null;
  const n = name.trim().replace(/\s+/g, " ");
  if (!NAME_RE.test(n)) return null;
  const low = n.toLowerCase();
  if (BANNED.some((w) => low.includes(w))) return null;
  return n;
}

export function plausible(p) {
  const ints = ["period", "score", "level", "kills", "peak", "seconds"];
  for (const k of ints) if (!Number.isInteger(p[k]) || p[k] < 0) return `bad ${k}`;
  if (p.mode !== "daily" && p.mode !== "weekly") return "bad mode";
  if (typeof p.id !== "string" || !/^[a-f0-9]{16,32}$/.test(p.id)) return "bad id";
  if (p.level < CAPS.minLevel || p.level > CAPS.maxLevel) return "bad level";
  if (p.score > CAPS.scoreBase + CAPS.scorePerLevel * p.level) return "score too high for the level";
  if (p.kills > CAPS.killsBase + CAPS.killsPerLevel * p.level) return "kills too high for the level";
  if (p.seconds < CAPS.secondsPerLevel * (p.level - 1)) return "too fast for the level";
  if (p.peak > CAPS.maxPeak) return "peak too high";
  return null;
}

export function periodOk(p, nowUnix) {
  const current = p.mode === "daily" ? dayNumber(nowUnix) : weekNumber(nowUnix);
  if (p.period === current) return true;
  if (p.period !== current - 1) return false;
  // A run that ended just before the boundary and was sent just after.
  const span = p.mode === "daily" ? 86400 : 7 * 86400;
  const startOfCurrent = p.mode === "daily"
    ? (current - 1 + EPOCH_DAY) * 86400
    : ((current - 1) * 7 + EPOCH_DAY) * 86400;
  return nowUnix - startOfCurrent <= GRACE_SECONDS && span > 0;
}

function boardKey(mode, period) {
  return `b:${mode}:${period}`;
}

function json(obj, status = 200) {
  return new Response(JSON.stringify(obj), { status, headers: { "content-type": "application/json" } });
}

export async function rateLimited(env, ip) {
  const key = `r:${ip}`;
  const n = parseInt((await env.BOARD.get(key)) || "0", 10) + 1;
  await env.BOARD.put(key, String(n), { expirationTtl: 60 });
  return n > RATE_PER_MINUTE;
}

export async function submit(env, p, nowUnix) {
  const why = plausible(p);
  if (why) return json({ ok: false, error: why }, 400);
  if (!periodOk(p, nowUnix)) return json({ ok: false, error: "period is over" }, 400);
  const expect = await hmacHex(env.SIGNING_SECRET, canonical(p));
  if (!timingEqual(expect, p.sig)) return json({ ok: false, error: "bad signature" }, 403);
  const name = cleanName(p.name);
  if (!name) return json({ ok: false, error: "bad name" }, 400);
  const player = (await env.BOARD.get(`p:${p.id}`, "json")) || {};
  await env.BOARD.put(`p:${p.id}`, JSON.stringify({ name, shadow: !!player.shadow, t: nowUnix }));
  const key = boardKey(p.mode, p.period);
  const rows = (await env.BOARD.get(key, "json")) || [];
  const mine = rows.find((r) => r.id === p.id);
  if (mine && mine.score >= p.score) {
    return json({ ok: true, rank: rankOf(rows, p.id, player.shadow), total: rows.length, kept: false });
  }
  const next = rows.filter((r) => r.id !== p.id);
  next.push({ id: p.id, name, score: p.score, level: p.level, kills: p.kills, peak: p.peak, t: nowUnix, shadow: !!player.shadow });
  next.sort((a, b) => b.score - a.score || a.t - b.t);
  const kept = next.slice(0, TOP_KEPT);
  await env.BOARD.put(key, JSON.stringify(kept));
  return json({ ok: true, rank: rankOf(kept, p.id, player.shadow), total: kept.length, kept: true });
}

function visible(rows, viewerId) {
  return rows.filter((r) => !r.shadow || r.id === viewerId);
}

function rankOf(rows, id, shadow) {
  const list = shadow ? rows : visible(rows, id);
  const i = list.findIndex((r) => r.id === id);
  return i < 0 ? null : i + 1;
}

export async function board(env, mode, period, viewerId) {
  if (mode !== "daily" && mode !== "weekly") return json({ ok: false, error: "bad mode" }, 400);
  const rows = (await env.BOARD.get(boardKey(mode, period), "json")) || [];
  const shown = visible(rows, viewerId);
  const you = shown.find((r) => r.id === viewerId);
  return json({
    ok: true,
    mode,
    period,
    total: shown.length,
    rows: shown.slice(0, TOP_SHOWN).map((r, i) => ({ rank: i + 1, name: r.name, score: r.score, level: r.level })),
    you: you ? { rank: shown.indexOf(you) + 1, score: you.score, level: you.level } : null,
  });
}

export async function forget(env, p) {
  if (typeof p.id !== "string" || !/^[a-f0-9]{16,32}$/.test(p.id)) return json({ ok: false, error: "bad id" }, 400);
  const expect = await hmacHex(env.SIGNING_SECRET, `forget|${p.id}`);
  if (!timingEqual(expect, p.sig)) return json({ ok: false, error: "bad signature" }, 403);
  await env.BOARD.delete(`p:${p.id}`);
  const list = await env.BOARD.list({ prefix: "b:" });
  for (const k of list.keys) {
    const rows = (await env.BOARD.get(k.name, "json")) || [];
    const next = rows.filter((r) => r.id !== p.id);
    if (next.length !== rows.length) await env.BOARD.put(k.name, JSON.stringify(next));
  }
  return json({ ok: true });
}

export async function handle(request, env, nowUnix = Math.floor(Date.now() / 1000)) {
  const url = new URL(request.url);
  const ip = request.headers.get("cf-connecting-ip") || "0.0.0.0";
  if (request.method === "GET" && url.pathname === "/board") {
    const mode = url.searchParams.get("mode") || "daily";
    const period = parseInt(url.searchParams.get("period") || "0", 10);
    const viewer = url.searchParams.get("id") || "";
    return board(env, mode, period, viewer);
  }
  if (request.method === "POST" && (url.pathname === "/submit" || url.pathname === "/forget")) {
    if (await rateLimited(env, ip)) return json({ ok: false, error: "slow down" }, 429);
    let body;
    try {
      body = await request.json();
    } catch (e) {
      return json({ ok: false, error: "bad json" }, 400);
    }
    return url.pathname === "/submit" ? submit(env, body, nowUnix) : forget(env, body);
  }
  if (request.method === "GET" && url.pathname === "/") {
    return json({ ok: true, service: "shootymcbridgeface leaderboard", day: dayNumber(nowUnix), week: weekNumber(nowUnix) });
  }
  return json({ ok: false, error: "not found" }, 404);
}

export default {
  async fetch(request, env) {
    return handle(request, env);
  },
};
