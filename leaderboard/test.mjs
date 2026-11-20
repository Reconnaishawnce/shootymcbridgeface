// Runs with plain node (18+): node leaderboard/test.mjs
import { handle, hmacHex, canonical, dayNumber, weekNumber, cleanName, plausible, traceHtml, flightHtml, LOG_SESSIONS_PER_INSTALL_PER_DAY } from "./worker.js";

class FakeKV {
  constructor() { this.m = new Map(); this.meta = new Map(); this.writes = 0; }
  async get(k, type) { const v = this.m.get(k); if (v === undefined) return null; return type === "json" ? JSON.parse(v) : v; }
  async put(k, v, opts) { this.writes++; this.m.set(k, v); if (opts && opts.metadata) this.meta.set(k, opts.metadata); }
  async delete(k) { this.m.delete(k); this.meta.delete(k); }
  async list({ prefix }) { return { keys: [...this.m.keys()].filter((k) => k.startsWith(prefix)).map((name) => ({ name, metadata: this.meta.get(name) })) }; }
}

const env = { BOARD: new FakeKV(), SIGNING_SECRET: "test-secret" };
const NOW = 1_798_000_000; // some day in 2026
let failures = 0;
function check(cond, msg) { if (!cond) { failures++; console.log("FAIL " + msg); } else console.log("  ok " + msg); }

async function post(path, body, ip = "1.2.3.4") {
  const req = new Request("https://x.test" + path, { method: "POST", body: JSON.stringify(body), headers: { "cf-connecting-ip": ip } });
  const res = await handle(req, env, NOW);
  return { status: res.status, body: await res.json() };
}
async function get(path) {
  const res = await handle(new Request("https://x.test" + path), env, NOW);
  return { status: res.status, body: await res.json() };
}

const day = dayNumber(NOW);
async function signed(p) { return { ...p, sig: await hmacHex(env.SIGNING_SECRET, canonical(p)) }; }

check(weekNumber(NOW) === Math.floor((day - 1) / 7) + 1, "week from day");
check(cleanName("  Ada  Lovelace ") === "Ada Lovelace", "names are trimmed and squashed");
check(cleanName("x") === null && cleanName("a".repeat(15)) === null, "name length");
check(cleanName("admin1") === null, "banned words");
check(plausible({ id: "abcdef0123456789", mode: "daily", period: day, score: 5000, level: 2, kills: 100, peak: 40, seconds: 60 }) === null, "a plausible run");
check(plausible({ id: "abcdef0123456789", mode: "daily", period: day, score: 900000, level: 2, kills: 100, peak: 40, peak: 40, seconds: 60 }) !== null, "an impossible score");

const good = await signed({ id: "abcdef0123456789", name: "Ada", mode: "daily", period: day, score: 5000, level: 2, kills: 100, peak: 40, seconds: 60 });
let r = await post("/submit", good);
check(r.status === 200 && r.body.ok && r.body.rank === 1, "first submission ranks first");
r = await post("/submit", { ...good, score: 9999 });
check(r.status === 403, "a changed score with the old signature is refused");
const better = await signed({ ...good, score: 7000 });
r = await post("/submit", better);
check(r.body.kept === true && r.body.rank === 1, "a better score replaces the old one");
const worse = await signed({ ...good, score: 100 });
r = await post("/submit", worse);
check(r.body.kept === false, "a worse score keeps the best");
const other = await signed({ id: "0123456789abcdef", name: "Bo", mode: "daily", period: day, score: 8000, level: 3, kills: 200, peak: 60, seconds: 100 });
r = await post("/submit", other, "5.6.7.8");
check(r.body.rank === 1, "a higher score takes the top");
const old = await signed({ ...good, period: day - 5 });
r = await post("/submit", old);
check(r.status === 400, "a period long over is refused");
r = await get(`/board?mode=daily&period=${day}&id=abcdef0123456789`);
check(r.body.rows.length === 2 && r.body.rows[0].name === "Bo" && r.body.you.rank === 2, "the board lists both, you second");
env.BOARD.m.set("p:0123456789abcdef", JSON.stringify({ name: "Bo", shadow: true }));
const shadowed = await signed({ ...other, score: 8001 });
await post("/submit", shadowed, "5.6.7.8");
r = await get(`/board?mode=daily&period=${day}&id=abcdef0123456789`);
check(r.body.rows.length === 1 && r.body.you.rank === 1, "a shadowed player is hidden from others");
r = await get(`/board?mode=daily&period=${day}&id=0123456789abcdef`);
check(r.body.rows.length === 2 && r.body.you.rank === 1, "and still sees themselves");
const fsig = await hmacHex(env.SIGNING_SECRET, "forget|abcdef0123456789");
r = await post("/forget", { id: "abcdef0123456789", sig: fsig });
r = await get(`/board?mode=daily&period=${day}&id=abcdef0123456789`);
check(r.body.you === null, "forget removes the player");
for (let i = 0; i < 25; i++) await post("/submit", good, "9.9.9.9");
r = await post("/submit", good, "9.9.9.9");
check(r.status === 429, "rate limited per ip");
r = await get("/");
check(r.body.ok && r.body.day === day, "the root says which day it is");

// Reports.
const payload = JSON.stringify({ kind: "freeze", version: "0.43.1", device: "Galaxy S23 Ultra (Android)", state: "running", crumb: "boss", install: "abcdef0123456789", events: ["a", "b"] });
const rsig = await hmacHex(env.SIGNING_SECRET, "report|" + payload);
r = await post("/report", { text: payload, sig: rsig }, "7.7.7.7");
check(r.status === 200 && r.body.ok && /^[0-9]{12}:[a-f0-9]{6}$/.test(r.body.id), "a signed report is stored");
const firstId = r.body.id;
r = await post("/report", { text: payload + " ", sig: rsig }, "7.7.7.7");
check(r.status === 403, "a changed text fails the signature");
const big = JSON.stringify({ kind: "crash", pad: "x".repeat(50000) });
r = await post("/report", { text: big, sig: await hmacHex(env.SIGNING_SECRET, "report|" + big) }, "7.7.7.7");
check(r.status === 413, "an oversize report is refused");
const odd = JSON.stringify({ kind: "weird" });
r = await post("/report", { text: odd, sig: await hmacHex(env.SIGNING_SECRET, "report|" + odd) }, "7.7.7.7");
check(r.status === 400, "an unknown kind is refused");
r = await get("/reports?key=whatever");
check(r.status === 503, "no admin key configured: the list says so");
env.ADMIN_KEY = "admin-secret";
r = await get("/reports?key=wrong");
check(r.status === 403, "a wrong admin key is refused");
r = await get("/reports?key=admin-secret");
check(r.body.ok && r.body.rows.length === 1 && r.body.rows[0].kind === "freeze" && r.body.rows[0].text === undefined && r.body.rows[0].bytes > 0, "the list shows the summary, not the body");
r = await get(`/report/${firstId}?key=admin-secret`);
check(r.body.ok && r.body.text === payload, "one report comes back whole");
const page = await handle(new Request("https://x.test/reports?key=admin-secret&html=1"), env, NOW);
const htmlText = await page.text();
check(page.headers.get("content-type").startsWith("text/html") && htmlText.includes("Galaxy S23 Ultra") && htmlText.includes("&lt;") === false, "the html page lists the device");
for (let i = 0; i < 12; i++) await post("/report", { text: payload, sig: rsig }, "8.8.8." + i);
r = await post("/report", { text: payload, sig: rsig }, "8.8.8.99");
check(r.status === 429, "an install is capped per day");

const table = traceHtml([{ t: 1, ms: 16.7, zombies: 3 }, { t: 1.5, ms: 80.2, zombies: 90, st: "running" }]);
check(table.includes("<th>st</th>") && table.includes('class="slow"') && table.split("<tr").length === 4, "the trace renders as a table with slow rows marked");
check(traceHtml(undefined) === "" && traceHtml([]) === "", "no trace, no table");

// --- logs ---------------------------------------------------------------
const COLS = ["t", "ms", "max", "fps", "proc", "phys", "nodes", "draw", "prims", "vram", "mem", "zombies", "squad", "level", "fx", "state", "crumb"];
const flightRow = (t, ms = 16.7, mx = 20) => [t, ms, mx, 60, 8, 1, 2000, 300, 40000, 80, 900, 30, 40, 2, 3, "running", "gate:4"];
async function logBody(over) {
  const chunk = { v: 1, install: "0123456789abcdef", session: "abcd1234abcd1234", started: NOW - 300, seq: 0, version: "0.60.61", device: "Pixel (Android)", os: "14", gpu: "Adreno", screen: "(1080, 2400) @ 60Hz", renderer: "gl_compatibility", cols: COLS, rows: [flightRow(1), flightRow(2), flightRow(3, 16, 900)], events: [{ e: "state", t: 1.5, d: { to: "running" } }], ended: "", reported: false, note: "", ...over };
  const text = JSON.stringify(chunk);
  return { text, sig: await hmacHex(env.SIGNING_SECRET, `log|${text}`) };
}
r = await post("/log", await logBody({}));
check(r.status === 200 && r.body.ok && r.body.seq === 0 && !r.body.dup, "a signed chunk starts a session log");
const logId = r.body.id;
check(/^[0-9]{12}:abcd1234abcd1234$/.test(logId), "its id is the start time and the session");
r = await post("/log", await logBody({}));
check(r.status === 200 && r.body.dup === true, "the same chunk again is not added twice");
const before = env.BOARD.writes;
r = await post("/log", await logBody({ seq: 1, rows: [flightRow(4), flightRow(5)], events: [] }));
check(r.status === 200 && r.body.seq === 1, "the next chunk joins the same session");
check(env.BOARD.writes - before === 1, "and costs one write, not three");
r = await get(`/log/${logId}?key=admin-secret`);
check(r.status === 200 && r.body.rows.length === 5 && r.body.chunks === 2 && r.body.ended === "", "the session holds every row once");
r = await post("/log", await logBody({ seq: 2, rows: [flightRow(6)], events: [], ended: "crash" }));
r = await get(`/log/${logId}?key=admin-secret`);
check(r.body.ended === "crash" && r.body.rows.length === 6 && !r.body.reported, "the tail sent at the next launch says it ended in a crash");
r = await post("/log", await logBody({ seq: 3, rows: [], events: [], ended: "crash", reported: true, note: "froze at the boss" }));
r = await get(`/log/${logId}?key=admin-secret`);
check(r.body.reported === true && r.body.note === "froze at the boss" && r.body.rows.length === 6, "the player's report marks the session and adds no rows");
r = await get("/logs?key=admin-secret");
check(r.status === 200 && r.body.rows.length === 1 && r.body.rows[0].meta.r === true && r.body.rows[0].meta.w === 900 && r.body.rows[0].meta.s === 1 && r.body.rows[0].meta.n === 6, "the list shows the session with its flags and its worst frame");
let logPage = await handle(new Request(`https://x.test/logs?key=admin-secret&html=1`), env, NOW);
let logHtmlText = await logPage.text();
check(logPage.headers.get("content-type").startsWith("text/html") && logHtmlText.includes("CRASH REPORTED BY THE PLAYER") && logHtmlText.includes(`/log/${logId}`), "the list page links to the session and says it was reported");
logPage = await handle(new Request(`https://x.test/log/${logId}?key=admin-secret&html=1`), env, NOW);
logHtmlText = await logPage.text();
check(logHtmlText.includes("froze at the boss") && logHtmlText.includes('class="slow') && logHtmlText.includes("last"), "the session page shows the note, the slow second and the last seconds");
r = await get("/logs?key=wrong");
check(r.status === 403, "logs need the admin key");
r = await get("/log/nonsense?key=admin-secret");
check(r.status === 400, "a bad log id is refused");
let bad = await logBody({});
r = await post("/log", { text: bad.text, sig: "0".repeat(64) });
check(r.status === 403, "an unsigned chunk is refused");
r = await post("/log", await logBody({ session: "not hex!" }));
check(r.status === 400, "a bad session id is refused");
r = await post("/log", await logBody({ session: "ffff0000ffff0000", rows: [[1, 2, 3]] }));
check(r.status === 400, "rows must match the columns");
r = await post("/log", await logBody({ session: "ffff0000ffff0000", started: NOW - 90 * 86400 }));
check(r.status === 400, "a session from months ago is refused");
r = await post("/log", await logBody({ session: "ffff0000ffff0000", seq: 9999 }));
check(r.status === 400, "a chunk number past the end is refused");
let capped = 200;
let cappedWhy = "";
for (let i = 0; i < LOG_SESSIONS_PER_INSTALL_PER_DAY + 2; i++) {
  // A different address each time, so it is the install's cap that bites.
  r = await post("/log", await logBody({ install: "aaaaaaaaaaaaaaaa", session: (0x10000000 + i).toString(16) }), `10.0.${i}.1`);
  capped = r.status;
  cappedWhy = r.body.error;
}
check(capped === 429 && cappedWhy === "enough for today", "an install can start only so many sessions a day");
let flood = 200;
for (let i = 0; i < 25; i++) {
  r = await post("/log", await logBody({ install: "bbbbbbbbbbbbbbbb", session: (0x20000000 + i).toString(16) }), "7.7.7.7");
  flood = r.status;
}
check(flood === 429 && r.body.error === "slow down", "one address cannot start sessions without end");
check(flightHtml({ cols: COLS, rows: [flightRow(1), flightRow(2, 60, 70)] }, "x", 1).split('class="').length === 3, "the table marks the slow row and the last row");
check(flightHtml(undefined, "x") === "" && flightHtml({ cols: COLS, rows: [] }, "x") === "", "no rows, no table");

console.log(failures === 0 ? "\nleaderboard worker: all checks passed" : `\n${failures} failed`);
process.exit(failures === 0 ? 0 : 1);
