// The Shooty McBridgeface leaderboard: one Cloudflare Worker and one KV
// namespace. Daily and weekly runs only (everyone plays the same seed, so
// a score is comparable and checkable). The game signs each submission
// with a secret that only CI and this Worker know; the Worker checks the
// signature, the period, and whether the game could have produced the
// numbers, then keeps the best score per player per period.
//
// Bindings: BOARD (KV namespace), SIGNING_SECRET (secret), and for the
// reports page ADMIN_KEY (secret): the one you type into the URL.
//
// Reports: the game POSTs crash, freeze and bug reports to /report,
// signed with the same secret (over "report|" + the text). They are
// kept thirty days. GET /reports?key=ADMIN_KEY lists them (add &html=1
// for a page you can read on a phone), GET /report/<id>?key=ADMIN_KEY
// shows one.
//
// Logs: with LOGGING on, the game POSTs its flight recorder to /log in
// chunks, signed over "log|" + the text: one row a second of frame
// times and what was on screen. All of a session's chunks are kept in
// one document for fourteen days, with how the session ended (clean,
// or in a crash) and whether the player reported it. GET
// /logs?key=ADMIN_KEY&html=1 lists sessions, GET
// /log/<id>?key=ADMIN_KEY&html=1 shows one.

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
export const REPORT_MAX_BYTES = 48000;
export const REPORT_TTL_SECONDS = 30 * 86400;
export const REPORTS_PER_INSTALL_PER_DAY = 10;
export const REPORT_KINDS = ["crash", "freeze", "slow", "manual"];
export const REPORTS_LIST_MAX = 100;
export const LOG_MAX_BYTES = 48000;
export const LOG_TTL_SECONDS = 14 * 86400;
export const LOG_SESSIONS_PER_INSTALL_PER_DAY = 40;
export const LOG_MAX_SEQ = 210;
export const LOG_CHUNK_ROWS = 400;
export const LOG_DOC_ROWS = 7200;
export const LOG_DOC_EVENTS = 600;
export const LOGS_LIST_MAX = 100;
// A row is trouble when its worst frame or its average is this long (ms).
export const LOG_TROUBLE_MAX_MS = 400;
export const LOG_TROUBLE_AVG_MS = 45;

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

// --- reports ------------------------------------------------------------

function reportKey(nowUnix, rand) {
  // Zero-padded so KV's lexicographic listing is chronological.
  return `report:${String(nowUnix).padStart(12, "0")}:${rand}`;
}

export async function report(env, body, nowUnix) {
  if (!body || typeof body.text !== "string" || typeof body.sig !== "string") return json({ ok: false, error: "bad body" }, 400);
  if (enc.encode(body.text).length > REPORT_MAX_BYTES) return json({ ok: false, error: "too big" }, 413);
  const expect = await hmacHex(env.SIGNING_SECRET, `report|${body.text}`);
  if (!timingEqual(expect, body.sig)) return json({ ok: false, error: "bad signature" }, 403);
  let p;
  try {
    p = JSON.parse(body.text);
  } catch (e) {
    return json({ ok: false, error: "bad json" }, 400);
  }
  if (!p || typeof p !== "object" || !REPORT_KINDS.includes(p.kind)) return json({ ok: false, error: "bad kind" }, 400);
  const install = typeof p.install === "string" && /^[a-f0-9]{8,32}$/.test(p.install) ? p.install : "anon";
  const dayKey = `rr:${install}:${dayNumber(nowUnix)}`;
  const n = parseInt((await env.BOARD.get(dayKey)) || "0", 10) + 1;
  await env.BOARD.put(dayKey, String(n), { expirationTtl: 86400 });
  if (n > REPORTS_PER_INSTALL_PER_DAY) return json({ ok: false, error: "enough for today" }, 429);
  const rand = Math.random().toString(16).slice(2, 8).padEnd(6, "0");
  const key = reportKey(nowUnix, rand);
  const row = {
    t: nowUnix,
    kind: p.kind,
    version: String(p.version || "?").slice(0, 32),
    device: String(p.device || "?").slice(0, 80),
    state: String(p.state || "").slice(0, 32),
    crumb: String(p.crumb || "").slice(0, 64),
    note: String(p.note || "").slice(0, 600),
    text: body.text,
  };
  await env.BOARD.put(key, JSON.stringify(row), { expirationTtl: REPORT_TTL_SECONDS });
  return json({ ok: true, id: key.slice("report:".length) });
}

function adminOk(env, key) {
  if (!env.ADMIN_KEY) return "no admin key: add the ADMIN_KEY secret to the Worker";
  if (!timingEqual(String(key || ""), env.ADMIN_KEY)) return "bad key";
  return null;
}

function esc(s) {
  return String(s).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
}

// The performance trace as a table: one row per half second, the slow
// frames (over 33 ms) marked, so a slowdown reads top to bottom.
export function traceHtml(trace) {
  if (!Array.isArray(trace) || trace.length === 0) return "";
  const keys = [];
  for (const row of trace) for (const k of Object.keys(row)) if (!keys.includes(k)) keys.push(k);
  const head = keys.map((k) => `<th>${esc(k)}</th>`).join("");
  const body = trace.map((row) => {
    const slow = Number(row.ms) > 33;
    return `<tr${slow ? ' class="slow"' : ""}>${keys.map((k) => `<td>${esc(row[k] === undefined ? "" : row[k])}</td>`).join("")}</tr>`;
  }).join("");
  return `<p>Trace (${trace.length} samples, oldest first; red rows are frames over 33 ms)</p><table><tr>${head}</tr>${body}</table>`;
}

// Whether a flight row (an array in the order of cols) shows trouble.
export function rowTrouble(cols, row) {
  const mx = Number(row[cols.indexOf("max")]);
  const ms = Number(row[cols.indexOf("ms")]);
  return mx >= LOG_TROUBLE_MAX_MS || ms >= LOG_TROUBLE_AVG_MS;
}

// The flight recorder as a table: one row a second, oldest first. Slow
// seconds are red; with lastN, the final rows are marked as the last
// seconds before the end.
export function flightHtml(flight, title, lastN = 0) {
  if (!flight || !Array.isArray(flight.cols) || !Array.isArray(flight.rows) || flight.rows.length === 0) return "";
  const cols = flight.cols;
  const head = cols.map((k) => `<th>${esc(k)}</th>`).join("");
  const n = flight.rows.length;
  const body = flight.rows.map((row, i) => {
    const cls = [rowTrouble(cols, row) ? "slow" : "", lastN > 0 && i >= n - lastN ? "last" : ""].filter(Boolean).join(" ");
    return `<tr${cls ? ` class="${cls}"` : ""}>${cols.map((_, j) => `<td>${esc(row[j] === undefined || row[j] === null ? "" : row[j])}</td>`).join("")}</tr>`;
  }).join("");
  return `<p>${esc(title)} (${n} seconds, oldest first; red is a slow second${lastN > 0 ? ", outlined is the last " + Math.min(lastN, n) + " before the end" : ""})</p><div class="scroll"><table><tr>${head}</tr>${body}</table></div>`;
}

const PAGE_STYLE = "body{font:15px/1.4 system-ui;margin:12px;background:#111;color:#eee}a{color:#8cf}summary{cursor:pointer;padding:6px 0}pre{white-space:pre-wrap;word-break:break-word;background:#1b1b22;padding:10px;border-radius:8px;font-size:12px}details{border-bottom:1px solid #333}table{border-collapse:collapse;font-size:11px;margin:6px 0}td,th{padding:1px 6px;text-align:right;border-bottom:1px solid #222;white-space:nowrap}tr.slow td{background:#4a1a1a}tr.last td{border-left:2px solid #fc6}.scroll{overflow-x:auto}.bad{color:#f66;font-weight:bold}.warn{color:#fc6;font-weight:bold}.ok{color:#8d8}li{margin:6px 0}";

function reportsHtml(rows) {
  const items = rows.map((r) => {
    const when = new Date(r.t * 1000).toISOString().replace("T", " ").slice(0, 16);
    let pretty = r.text;
    let trace = "";
    try {
      const parsed = JSON.parse(r.text);
      trace = flightHtml(parsed.previous_flight, "The session that died: its last seconds", 15) + traceHtml(parsed.trace) + flightHtml(parsed.flight, "This session's flight recorder");
      delete parsed.trace;
      delete parsed.flight;
      delete parsed.previous_flight;
      pretty = JSON.stringify(parsed, null, 2);
    } catch (e) { /* keep raw */ }
    return `<details><summary><b>${esc(r.kind)}</b> &middot; v${esc(r.version)} &middot; ${esc(r.device)} &middot; ${esc(r.state)}/${esc(r.crumb)} &middot; ${when}${r.note ? " &middot; <i>" + esc(r.note) + "</i>" : ""}</summary>${trace}<pre>${esc(pretty)}</pre></details>`;
  });
  return `<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Shooty reports</title><style>${PAGE_STYLE}</style><h2>Reports (${rows.length}, newest first)</h2>${items.join("") || "<p>None yet.</p>"}`;
}

export async function reports(env, key, limit, html) {
  const why = adminOk(env, key);
  if (why) return json({ ok: false, error: why }, env.ADMIN_KEY ? 403 : 503);
  const n = Math.min(Math.max(parseInt(limit || "50", 10) || 50, 1), REPORTS_LIST_MAX);
  const list = await env.BOARD.list({ prefix: "report:" });
  const keys = list.keys.map((k) => k.name).sort().slice(-n).reverse();
  const rows = [];
  for (const k of keys) {
    const row = await env.BOARD.get(k, "json");
    if (row) rows.push({ id: k.slice("report:".length), ...row });
  }
  if (html) return new Response(reportsHtml(rows), { headers: { "content-type": "text/html; charset=utf-8" } });
  return json({ ok: true, total: list.keys.length, rows: rows.map((r) => ({ ...r, text: undefined, bytes: r.text.length })) });
}

export async function reportOne(env, key, id) {
  const why = adminOk(env, key);
  if (why) return json({ ok: false, error: why }, env.ADMIN_KEY ? 403 : 503);
  if (!/^[0-9]{12}:[a-f0-9]{6}$/.test(id)) return json({ ok: false, error: "bad id" }, 400);
  const row = await env.BOARD.get(`report:${id}`, "json");
  if (!row) return json({ ok: false, error: "not found" }, 404);
  return json({ ok: true, id, ...row });
}

// --- logs ---------------------------------------------------------------

function logKey(started, session) {
  return `log:${String(started).padStart(12, "0")}:${session}`;
}

// What the list page needs to know about a session, kept as the key's
// metadata so listing costs no reads.
function logMeta(doc) {
  let worst = 0;
  let slow = 0;
  const mx = doc.cols.indexOf("max");
  for (const row of doc.rows) {
    worst = Math.max(worst, Number(row[mx]) || 0);
    if (rowTrouble(doc.cols, row)) slow++;
  }
  return { v: doc.version, d: doc.device, e: doc.ended, r: doc.reported, n: doc.rows.length, w: Math.round(worst), s: slow, c: doc.chunks, u: doc.updated };
}

// One chunk of a session's flight recorder. All chunks of a session go
// into one document; a chunk seen before is not added twice; a chunk
// can also say how the session ended and that the player reported it.
export async function logChunk(env, body, nowUnix, ip = "") {
  if (!body || typeof body.text !== "string" || typeof body.sig !== "string") return json({ ok: false, error: "bad body" }, 400);
  if (enc.encode(body.text).length > LOG_MAX_BYTES) return json({ ok: false, error: "too big" }, 413);
  const expect = await hmacHex(env.SIGNING_SECRET, `log|${body.text}`);
  if (!timingEqual(expect, body.sig)) return json({ ok: false, error: "bad signature" }, 403);
  let p;
  try {
    p = JSON.parse(body.text);
  } catch (e) {
    return json({ ok: false, error: "bad json" }, 400);
  }
  if (!p || typeof p !== "object") return json({ ok: false, error: "bad chunk" }, 400);
  if (typeof p.session !== "string" || !/^[a-f0-9]{8,32}$/.test(p.session)) return json({ ok: false, error: "bad session" }, 400);
  const started = Number(p.started);
  if (!Number.isInteger(started) || started <= 0 || started > nowUnix + 86400 || nowUnix - started > 60 * 86400) return json({ ok: false, error: "bad start" }, 400);
  const seq = Number(p.seq);
  if (!Number.isInteger(seq) || seq < 0 || seq > LOG_MAX_SEQ) return json({ ok: false, error: "bad seq" }, 400);
  if (!Array.isArray(p.cols) || p.cols.length < 3 || p.cols.length > 32 || !p.cols.every((c) => typeof c === "string" && c.length <= 16)) return json({ ok: false, error: "bad cols" }, 400);
  if (!Array.isArray(p.rows) || p.rows.length > LOG_CHUNK_ROWS || !p.rows.every((r) => Array.isArray(r) && r.length === p.cols.length)) return json({ ok: false, error: "bad rows" }, 400);
  const events = Array.isArray(p.events) ? p.events.slice(0, 100) : [];
  const install = typeof p.install === "string" && /^[a-f0-9]{8,32}$/.test(p.install) ? p.install : "anon";
  const key = logKey(started, p.session);
  let doc = await env.BOARD.get(key, "json");
  if (!doc) {
    // A new session: the only place a log counts against the address
    // and the install, so a chunk of a running session costs one write.
    if (ip && (await rateLimited(env, ip))) return json({ ok: false, error: "slow down" }, 429);
    const dayKey = `lr:${install}:${dayNumber(nowUnix)}`;
    const n = parseInt((await env.BOARD.get(dayKey)) || "0", 10) + 1;
    await env.BOARD.put(dayKey, String(n), { expirationTtl: 86400 });
    if (n > LOG_SESSIONS_PER_INSTALL_PER_DAY) return json({ ok: false, error: "enough for today" }, 429);
    doc = {
      t: started, install, session: p.session,
      version: String(p.version || "?").slice(0, 32), device: String(p.device || "?").slice(0, 80),
      os: String(p.os || "?").slice(0, 80), gpu: String(p.gpu || "?").slice(0, 120),
      screen: String(p.screen || "?").slice(0, 60), renderer: String(p.renderer || "?").slice(0, 40),
      cols: p.cols, rows: [], events: [], seq: -1, chunks: 0, ended: "", reported: false, note: "", updated: nowUnix,
    };
  }
  const dup = p.rows.length > 0 && seq <= doc.seq;
  if (!dup && (p.rows.length > 0 || events.length > 0)) {
    doc.rows = doc.rows.concat(p.rows).slice(-LOG_DOC_ROWS);
    doc.events = doc.events.concat(events).slice(-LOG_DOC_EVENTS);
    doc.seq = Math.max(doc.seq, seq);
    doc.chunks += 1;
  }
  if (p.ended === "clean" || p.ended === "crash") doc.ended = p.ended;
  if (p.reported === true) {
    doc.reported = true;
    if (typeof p.note === "string" && p.note) doc.note = p.note.slice(0, 600);
  }
  doc.updated = nowUnix;
  await env.BOARD.put(key, JSON.stringify(doc), { expirationTtl: LOG_TTL_SECONDS, metadata: logMeta(doc) });
  return json({ ok: true, id: key.slice("log:".length), seq: doc.seq, dup });
}

function logFlag(m) {
  if (m.r) return '<span class="bad">CRASH REPORTED BY THE PLAYER</span>';
  if (m.e === "crash") return '<span class="warn">ENDED IN A CRASH</span>';
  if (m.e === "clean") return '<span class="ok">ended cleanly</span>';
  return "no ending yet (still running, or never reopened)";
}

function logsHtml(rows, key) {
  const items = rows.map((r) => {
    const when = new Date(Number(r.id.slice(0, 12)) * 1000).toISOString().replace("T", " ").slice(0, 16);
    const m = r.meta;
    return `<li><a href="/log/${esc(r.id)}?key=${encodeURIComponent(key)}&html=1">${when}</a> &middot; ${logFlag(m)} &middot; v${esc(m.v)} &middot; ${esc(m.d)} &middot; ${esc(m.n)} s recorded &middot; worst frame ${esc(m.w)} ms &middot; ${esc(m.s)} slow seconds</li>`;
  });
  return `<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Shooty logs</title><style>${PAGE_STYLE}</style><h2>Session logs (${rows.length}, newest first)</h2><p>One line per launch of the game with LOGGING on. Open one to see every second of it.</p><ul>${items.join("") || "<li>None yet.</li>"}</ul>`;
}

export async function logs(env, key, limit, html) {
  const why = adminOk(env, key);
  if (why) return json({ ok: false, error: why }, env.ADMIN_KEY ? 403 : 503);
  const n = Math.min(Math.max(parseInt(limit || "50", 10) || 50, 1), LOGS_LIST_MAX);
  const list = await env.BOARD.list({ prefix: "log:" });
  const rows = list.keys.sort((a, b) => (a.name < b.name ? 1 : -1)).slice(0, n).map((k) => ({ id: k.name.slice("log:".length), meta: k.metadata || {} }));
  if (html) return new Response(logsHtml(rows, key), { headers: { "content-type": "text/html; charset=utf-8" } });
  return json({ ok: true, total: list.keys.length, rows });
}

function logHtml(id, doc) {
  const when = new Date(doc.t * 1000).toISOString().replace("T", " ").slice(0, 16);
  const m = logMeta(doc);
  const events = doc.events.map((e) => `${esc(e.t)}  ${esc(e.e)}  ${esc(JSON.stringify(e.d || {}))}`).join("\n");
  const crashed = doc.ended === "crash" || doc.reported;
  return `<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Shooty log ${esc(id)}</title><style>${PAGE_STYLE}</style><h2>${when} &middot; ${logFlag(m)}</h2><p>v${esc(doc.version)} &middot; ${esc(doc.device)} &middot; ${esc(doc.os)} &middot; ${esc(doc.gpu)} &middot; ${esc(doc.screen)} &middot; ${esc(doc.renderer)}</p><p>${m.n} seconds recorded in ${doc.chunks} uploads &middot; worst frame ${m.w} ms &middot; ${m.s} slow seconds${doc.note ? " &middot; the player said: <i>" + esc(doc.note) + "</i>" : ""}</p>${flightHtml({ cols: doc.cols, rows: doc.rows }, "Every second of the session", crashed ? 15 : 0)}<details><summary>Events (${doc.events.length})</summary><pre>${events}</pre></details>`;
}

export async function logOne(env, key, id, html) {
  const why = adminOk(env, key);
  if (why) return json({ ok: false, error: why }, env.ADMIN_KEY ? 403 : 503);
  if (!/^[0-9]{12}:[a-f0-9]{8,32}$/.test(id)) return json({ ok: false, error: "bad id" }, 400);
  const doc = await env.BOARD.get(`log:${id}`, "json");
  if (!doc) return json({ ok: false, error: "not found" }, 404);
  if (html) return new Response(logHtml(id, doc), { headers: { "content-type": "text/html; charset=utf-8" } });
  return json({ ok: true, id, ...doc });
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
  if (request.method === "POST" && url.pathname === "/report") {
    if (await rateLimited(env, ip)) return json({ ok: false, error: "slow down" }, 429);
    let body;
    try {
      body = await request.json();
    } catch (e) {
      return json({ ok: false, error: "bad json" }, 400);
    }
    return report(env, body, nowUnix);
  }
  if (request.method === "POST" && url.pathname === "/log") {
    // A chunk is refused without a valid signature before anything is
    // read or written; the per-address counter is only touched when a
    // chunk starts a new session.
    let body;
    try {
      body = await request.json();
    } catch (e) {
      return json({ ok: false, error: "bad json" }, 400);
    }
    return logChunk(env, body, nowUnix, ip);
  }
  if (request.method === "GET" && url.pathname === "/logs") {
    return logs(env, url.searchParams.get("key"), url.searchParams.get("limit"), url.searchParams.get("html") === "1");
  }
  if (request.method === "GET" && url.pathname.startsWith("/log/")) {
    return logOne(env, url.searchParams.get("key"), url.pathname.slice("/log/".length), url.searchParams.get("html") === "1");
  }
  if (request.method === "GET" && url.pathname === "/reports") {
    return reports(env, url.searchParams.get("key"), url.searchParams.get("limit"), url.searchParams.get("html") === "1");
  }
  if (request.method === "GET" && url.pathname.startsWith("/report/")) {
    return reportOne(env, url.searchParams.get("key"), url.pathname.slice("/report/".length));
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
