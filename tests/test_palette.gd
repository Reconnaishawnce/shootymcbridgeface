extends TestCase


func test_the_road_reads() -> void:
	check(Palette.luma(Palette.CURB) - Palette.luma(Palette.ROAD) > 0.4, "curbs stand off the deck")
	check(Palette.luma(Palette.DASH) - Palette.luma(Palette.ROAD) > 0.4, "lines stand off the deck")
	check(Palette.hue_gap(Palette.ROAD, Palette.WATER_DEEP) < 0.1 and Palette.luma(Palette.ROAD) > Palette.luma(Palette.WATER_DEEP), "the deck is a lighter blue than the water under it")
	check(Palette.chroma(Palette.ROAD) > 0.6, "the deck is saturated, not grey")
	check(Palette.luma(Palette.CURB) - Palette.luma(Palette.WALK) > 0.25, "the curb stands off the walkway beside it")


func test_the_cast_reads() -> void:
	check(Palette.hue_gap(Palette.SOLDIER, Palette.ZOMBIE) > 0.3, "soldiers and zombies are opposite hues")
	check(Palette.hue_gap(Palette.ZOMBIE, Palette.ROAD) > 0.3, "zombies stand off the deck")
	check(Palette.chroma(Palette.ZOMBIE) > 0.7 and Palette.chroma(Palette.SOLDIER) > 0.7, "both are vivid")
	for a in [Palette.ZOMBIE, Palette.BRUTE, Palette.RUNNER, Palette.THIEF, Palette.TANK, Palette.LATCHER]:
		for b in [Palette.ZOMBIE, Palette.BRUTE, Palette.RUNNER, Palette.THIEF, Palette.TANK, Palette.LATCHER]:
			if a != b:
				check(Palette.hue_gap(a, b) > 0.04 or absf(Palette.luma(a) - Palette.luma(b)) > 0.12, "zombie kinds tell apart (%s vs %s)" % [a.to_html(false), b.to_html(false)])


func test_the_panels_read() -> void:
	check(Palette.hue_gap(Palette.GOOD, Palette.BAD) > 0.3, "blue and red panels are far apart")
	check(Palette.hue_gap(Palette.POWER, Palette.GOOD) > 0.08 and Palette.hue_gap(Palette.POWER, Palette.BAD) > 0.15, "purple is neither blue nor red")
	check(Palette.hue_gap(Palette.THINK, Palette.GOOD) > 0.08, "teal sums are not blue")
	check(Palette.hue_gap(Palette.SUPPLY, Palette.DEAL) < 0.1 and Palette.luma(Palette.SUPPLY) > Palette.luma(Palette.DEAL), "gold is a brighter amber")
	check(Palette.luma(Palette.INK) < 0.05, "the ink is near black")
