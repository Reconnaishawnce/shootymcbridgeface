class_name Leaderboard
extends RefCounted
## The leaderboard's client side: what a submission looks like, how it is
## signed, which names pass, whether a run is worth sending. Mirrors
## leaderboard/worker.js; the Worker is the judge, this is the form.
## Pure except for the HMAC, which is the engine's.

const MODES := ["daily", "weekly"]
const NAME_MIN := 2
const NAME_MAX := 14
const TIMEOUT := 10.0


static func configured() -> bool:
	return LeaderboardConfig.URL != "" and LeaderboardConfig.SECRET != ""


## A random, anonymous id for this save: sixteen hex characters.
static func new_id() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var out := ""
	for i in range(16):
		out += "0123456789abcdef"[rng.randi_range(0, 15)]
	return out


static func clean_name(name: String) -> String:
	var n := name.strip_edges()
	while n.contains("  "):
		n = n.replace("  ", " ")
	if n.length() < NAME_MIN or n.length() > NAME_MAX:
		return ""
	for ch in n:
		var c: String = ch
		if not (c == " " or c == "_" or c == "-" or (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or (c >= "0" and c <= "9")):
			return ""
	return n


## The submission for a finished daily or weekly run.
static func payload(id: String, name: String, mode: String, period: int, score: int, level: int, kills: int, peak: int, seconds: int) -> Dictionary:
	return {"id": id, "name": name, "mode": mode, "period": period, "score": score, "level": level, "kills": kills, "peak": peak, "seconds": seconds}


static func canonical(p: Dictionary) -> String:
	return "v1|%s|%s|%d|%d|%d|%d|%d|%d" % [str(p.id), str(p.mode), int(p.period), int(p.score), int(p.level), int(p.kills), int(p.peak), int(p.seconds)]


static func hmac_hex(secret: String, text: String) -> String:
	var ctx := HMACContext.new()
	ctx.start(HashingContext.HASH_SHA256, secret.to_utf8_buffer())
	ctx.update(text.to_utf8_buffer())
	return ctx.finish().hex_encode()


static func signed(p: Dictionary, secret: String) -> Dictionary:
	var out := p.duplicate()
	out.sig = hmac_hex(secret, canonical(p))
	return out


static func forget_body(id: String, secret: String) -> Dictionary:
	return {"id": id, "sig": hmac_hex(secret, "forget|" + id)}


static func board_url(base: String, mode: String, period: int, id: String) -> String:
	return "%s/board?mode=%s&period=%d&id=%s" % [base.trim_suffix("/"), mode, period, id]


## Rows for the page from the Worker's answer.
static func rows_text(answer: Dictionary) -> Array:
	var out := []
	for r in answer.get("rows", []):
		out.append("%d.  %s   %d   ·   level %d" % [int(r.rank), str(r.name), int(r.score), int(r.level)])
	return out


## The home screen's one line: the leader, and you.
static func teaser(answer: Dictionary, period: int) -> String:
	var rows: Array = answer.get("rows", [])
	if rows.is_empty():
		return "DAILY #%d   ·   nobody yet, be first" % period
	var top: Dictionary = rows[0]
	var line := "DAILY #%d   ·   %s leads with %d" % [period, str(top.name), int(top.score)]
	var you = answer.get("you", null)
	if you is Dictionary:
		line += "   ·   you %s" % ordinal(int(you.rank))
	return line


static func ordinal(n: int) -> String:
	var tail := "th"
	if n % 100 < 11 or n % 100 > 13:
		tail = {1: "st", 2: "nd", 3: "rd"}.get(n % 10, "th")
	return "%d%s" % [n, tail]


static func you_text(answer: Dictionary) -> String:
	var you = answer.get("you", null)
	if you == null or not (you is Dictionary):
		return "You are not on this board yet."
	return "You: rank %d of %d   ·   %d" % [int(you.rank), int(answer.get("total", 0)), int(you.score)]
