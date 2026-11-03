extends TestCase


func test_names_ids_and_signing() -> void:
	check_eq(Leaderboard.clean_name("  Ada   Lovelace "), "Ada Lovelace", "trimmed and squashed")
	check_eq(Leaderboard.clean_name("x"), "", "too short")
	check_eq(Leaderboard.clean_name("a".repeat(15)), "", "too long")
	check_eq(Leaderboard.clean_name("Bad;Name"), "", "only letters, digits, space, dash, underscore")
	var id := Leaderboard.new_id()
	check(id.length() == 16 and id.is_valid_hex_number(), "a sixteen-hex id")
	check(Leaderboard.new_id() != id, "random")
	var p := Leaderboard.payload("abcdef0123456789", "Ada", "daily", 12, 5000, 2, 100, 40, 60)
	check_eq(Leaderboard.canonical(p), "v1|abcdef0123456789|daily|12|5000|2|100|40|60", "the canonical line the Worker signs")
	# The same HMAC the Worker computes: node's reference value.
	var s := Leaderboard.signed(p, "test-secret")
	check_eq(s.sig, "9289d9e4e413084286a8538b31a628280b3bf8cdbb063b6b534196bf89a3f5e5", "the engine's HMAC matches the Worker's")
	check(s.sig.length() == 64 and s.sig != Leaderboard.signed(p, "other").sig, "a 64-hex signature that depends on the secret")
	check(Leaderboard.forget_body("abcdef0123456789", "k").sig.length() == 64, "forget is signed too")
	check_eq(Leaderboard.board_url("https://x.workers.dev/", "weekly", 3, "ab"), "https://x.workers.dev/board?mode=weekly&period=3&id=ab", "board url")
	var rows := Leaderboard.rows_text({"rows": [{"rank": 1, "name": "Bo", "score": 8000, "level": 3}]})
	check(rows.size() == 1 and rows[0].begins_with("1.  Bo"), "a row")
	check(Leaderboard.you_text({}).contains("not on this board"), "no rank yet")
	check(Leaderboard.you_text({"you": {"rank": 2, "score": 7000}, "total": 9}).contains("rank 2 of 9"), "your rank")
	# A local build has neither; a CI build has both. Never one without the other.
	check((LeaderboardConfig.URL == "") == (LeaderboardConfig.SECRET == ""), "the server and the secret come together")
