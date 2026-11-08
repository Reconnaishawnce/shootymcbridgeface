// Runs with plain node (18+): node leaderboard/test.mjs
import { handle, hmacHex, canonical, dayNumber, weekNumber, cleanName, plausible } from "./worker.js";

class FakeKV {
  constructor() { this.m = new Map(); }
  async get(k, type) { const v = this.m.get(k); if (v === undefined) return null; return type === "json" ? JSON.parse(v) : v; }
  async put(k, v) { this.m.set(k, v); }
  async delete(k) { this.m.delete(k); }
  async list({ prefix }) { return { keys: [...this.m.keys()].filter((k) => k.startsWith(prefix)).map((name) => ({ name })) }; }
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

console.log(failures === 0 ? "\nleaderboard worker: all checks passed" : `\n${failures} failed`);
process.exit(failures === 0 ? 0 : 1);
