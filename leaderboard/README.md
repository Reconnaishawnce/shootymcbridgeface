# The leaderboard server

One Cloudflare Worker and one KV namespace. Free tier is plenty. The
game signs each submission with a secret that only your CI and this
Worker know, the Worker checks the signature, the period and whether
the game could have produced the numbers, and keeps the best score per
player per day and per week.

## Set it up (about ten minutes, dashboard only)

1. **The KV namespace.** In the Cloudflare dashboard open *Storage &
   Databases → KV*, click *Create*, name it `shooty-board`.
2. **The Worker.** Open *Compute (Workers) → Create → Start with Hello
   World*, name it `shootymcbridgeface-leaderboard`, deploy, then *Edit
   code*: replace everything with the contents of `worker.js` from this
   folder and deploy again.
3. **Bind the namespace.** In the Worker's *Settings → Bindings*, add a
   *KV namespace* binding: variable name `BOARD`, namespace
   `shooty-board`.
4. **The secret.** Make up a long random string (40+ characters; a
   password manager's generator is fine). In the Worker's *Settings →
   Variables and Secrets*, add a **secret** named `SIGNING_SECRET` with
   that value.
5. **Tell the build.** In the GitHub repository open *Settings → Secrets
   and variables → Actions* and add two repository secrets:
   - `LEADERBOARD_URL`: the Worker's URL, e.g.
     `https://shootymcbridgeface-leaderboard.<your-account>.workers.dev`
   - `LEADERBOARD_SECRET`: exactly the same string as `SIGNING_SECRET`.
6. **Check it.** Open the Worker URL in a browser: it answers with
   `{"ok":true,"service":"shootymcbridgeface leaderboard",...}`. Push
   anything to `main` (or re-run the last workflow): the build log says
   "Leaderboard: configured". The next release has the board under MORE.

If you prefer the command line, `wrangler.toml` is here: `npx wrangler
kv namespace create BOARD`, paste the id into the file, `npx wrangler
secret put SIGNING_SECRET`, `npx wrangler deploy`.

## Crash and freeze reports

From 0.43 the game also sends bug reports here on its own (SEND
REPORTS in the game's SETTINGS, on by default): after a crash, a
frozen frame of two seconds or more, or a start so slow that safe
graphics switched itself on. Each is signed with the same secret,
capped at 48 KB and ten a day per phone, and kept thirty days. It
carries the phone model, OS, graphics chip, renderer, frame-time
buckets and the worst frames, the event log, engine error lines, a
save summary and what the game was doing, under a random install id.
Never a name.

To read them you need one more secret on the Worker:

1. In the Worker's *Settings → Variables and Secrets*, add a **secret**
   named `ADMIN_KEY` with a long random string of your own. Nothing
   else needs it; it is the password for the reports page.
2. **Redeploy the Worker** with the current `worker.js` (Edit code,
   paste, Deploy): the `/report` routes are new in this version.
3. Open `https://<your worker>/reports?key=<ADMIN_KEY>&html=1` on any
   phone or laptop: newest first, one line each, tap to unfold the
   whole report. Without `&html=1` it is JSON; `/report/<id>?key=...`
   is one report whole.

The page says "no admin key" until step 1 is done, and the game keeps
reports in its save while it is offline and sends them on the next
visit to the home screen.

## What it stores

Per player: a random id the game made, the chosen name, a hidden
"shadow" flag. Per day and per week: up to 200 rows of id, name,
score, level, kills, peak squad and time. Nothing else. FORGET ME in
the game deletes the player's rows and id.

## Moderation

To hide a cheater without a fight, edit their `p:<id>` row in the KV
namespace and set `"shadow": true`: they still see their own score,
nobody else does. To rename, edit `name` there and in the board rows.
Daily boards are `b:daily:<day>`, weekly `b:weekly:<week>`, where the
day number is the game's (`scripts/core/daily.gd`); the Worker's root
URL tells you today's.

## Honest limits

The game is open source, so a determined person can pull the secret
out of the APK and sign a forged score. The plausibility caps in
`worker.js` stop anything the game could not produce, the shared seed
lets you replay a suspicious run with the bot, and the shadow flag
removes it quietly. That is as far as a free, accountless board should
go; a stronger scheme needs accounts and a server that replays runs.

## Tests

`node leaderboard/test.mjs` runs the Worker against a fake KV: signing,
replacement by a better score, period and plausibility rejections,
shadowing, forgetting, the rate limit, and the reports (storage,
signature, size cap, kind check, the admin key, the HTML page, the
per-phone daily cap). CI runs it on every push.
