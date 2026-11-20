// Takes what the game itself built (the bot writes it with
// --smoke-dump=FILE) and gives it to the Worker's own code. If the
// game's signing, sizes or shapes ever drift from what the server
// checks, this is where it shows, before a phone finds out.
//   node leaderboard/accept.mjs FILE
import { readFileSync } from "node:fs";
import { handle } from "./worker.js";

class FakeKV {
  constructor() { this.m = new Map(); this.meta = new Map(); }
  async get(k, type) { const v = this.m.get(k); if (v === undefined) return null; return type === "json" ? JSON.parse(v) : v; }
  async put(k, v, opts) { this.m.set(k, v); if (opts && opts.metadata) this.meta.set(k, opts.metadata); }
  async delete(k) { this.m.delete(k); }
  async list({ prefix }) { return { keys: [...this.m.keys()].filter((k) => k.startsWith(prefix)).map((name) => ({ name, metadata: this.meta.get(name) })) }; }
}

const dump = JSON.parse(readFileSync(process.argv[2], "utf8"));
const env = { BOARD: new FakeKV(), SIGNING_SECRET: dump.secret, ADMIN_KEY: "k" };
const now = Math.floor(Date.now() / 1000);
let failures = 0;
function check(cond, msg) { if (!cond) { failures++; console.log("FAIL " + msg); } else console.log("  ok " + msg); }
async function post(path, body) {
  const res = await handle(new Request("https://x.test" + path, { method: "POST", body: JSON.stringify(body), headers: { "cf-connecting-ip": "9.9.9.9" } }), env, now);
  return { status: res.status, body: await res.json() };
}

let r = await post("/report", dump.report);
check(r.status === 200 && r.body.ok, `the Worker accepts the game's report (${r.status} ${JSON.stringify(r.body)})`);
r = await post("/log", dump.log);
check(r.status === 200 && r.body.ok, `the Worker accepts the game's log chunk (${r.status} ${JSON.stringify(r.body)})`);
const page = await handle(new Request(`https://x.test/log/${r.body.id}?key=k&html=1`), env, now);
const html = await page.text();
check(page.status === 200 && html.includes("<table>") && html.includes("zombies"), "and its page shows the rows the game recorded");
const reports = await handle(new Request("https://x.test/reports?key=k&html=1"), env, now);
check((await reports.text()).includes("flight recorder"), "and the report page shows the flight recorder the report carried");
console.log(failures === 0 ? "the game and the Worker agree" : `${failures} failed`);
process.exit(failures === 0 ? 0 : 1);
