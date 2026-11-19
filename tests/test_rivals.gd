extends TestCase


func test_next_and_pass() -> void:
	var r := Rivals.new()
	check_eq(r.chip(0), "", "nobody to chase says nothing")
	r.set_best(900)
	r.set_board([{"rank": 1, "name": "BO", "score": 2100}, {"rank": 2, "name": "SAM", "score": 1200}, {"rank": 3, "name": "ME", "score": 900}, {"rank": 4, "name": "LEE", "score": 400}], 3)
	check_eq(r.targets.size(), 4, "the board without my own row, plus my best")
	check_eq(str(r.next(0).name), "LEE", "the lowest above me first")
	check_eq(r.chip(100), "LEE  400   ·   300 to go", "the chip says who and how far")
	check(r.advance(300).is_empty(), "nothing passed yet")
	var got := r.advance(950)
	check_eq(got.size(), 2, "two passed in one stride")
	check_eq(str(got[0].name), "LEE", "lowest first")
	check_eq(Rivals.shout(got[0]), "PASSED LEE", "a rival is named")
	check_eq(Rivals.shout(got[1]), "NEW BEST!", "my own best is a new best")
	check(r.advance(960).is_empty(), "each is reported once")
	check_eq(str(r.next(960).name), "SAM", "then the next one up")
	r.advance(5000)
	check_eq(r.chip(5000), "", "at the top there is nobody left")
	check_eq(r.summary(), "PASSED  LEE, SAM, BO", "the results line leaves my own best out")


func test_late_board_and_ties() -> void:
	var r := Rivals.new()
	r.set_best(0)
	check(r.targets.is_empty(), "no best, no self target")
	# The board arrives mid-run: rivals already behind are not announced.
	r.set_board([{"rank": 1, "name": "A", "score": 800}, {"rank": 2, "name": "B", "score": 300}], 0, 500)
	check_eq(r.targets.size(), 1, "only those still ahead")
	check(r.advance(800).is_empty(), "a tie is not a pass")
	check_eq(r.advance(801).size(), 1, "one more point is")
	var many := Rivals.new()
	many.set_board([{"rank": 1, "name": "A", "score": 5}, {"rank": 2, "name": "B", "score": 4}, {"rank": 3, "name": "C", "score": 3}, {"rank": 4, "name": "D", "score": 2}, {"rank": 5, "name": "E", "score": 1}])
	many.advance(100)
	check_eq(many.summary(), "PASSED  B, A and 3 more", "a long list is cut to the best two")
	many.set_board([{"rank": 1, "name": "", "score": 999}, "junk"])
	check(many.targets.is_empty(), "nameless rows and junk are skipped")
