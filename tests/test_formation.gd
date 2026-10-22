extends TestCase


func test_sizes() -> void:
	check_eq(Formation.positions(0).size(), 0, "zero")
	check_eq(Formation.positions(1).size(), 1, "one")
	check_eq(Formation.positions(7).size(), 7, "seven")
	check_eq(Formation.positions(50).size(), 50, "fifty")


func test_leader_is_centred_and_slots_are_distinct() -> void:
	var pos := Formation.positions(40)
	check_eq(pos[0], Vector2.ZERO, "leader at origin")
	for i in range(pos.size()):
		for j in range(i + 1, pos.size()):
			check(pos[i].distance_to(pos[j]) > 0.2, "slots %d and %d overlap" % [i, j])


func test_big_squad_fits_in_lane() -> void:
	check(Formation.half_width(50) < 1.6, "50 soldiers stay narrow")
	check(Formation.half_width(50) >= Formation.half_width(10), "wider with more")
