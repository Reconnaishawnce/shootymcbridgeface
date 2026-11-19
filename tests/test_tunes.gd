extends TestCase


func _rms(s: PackedFloat32Array) -> float:
	var sum := 0.0
	for v in s:
		sum += v * v
	return sqrt(sum / float(maxi(1, s.size())))


func test_loops_stay_in_step() -> void:
	var n := Tunes.length()
	check_eq(n, Tunes.BEAT * Tunes.BEATS, "sixteen beats")
	for id in Tunes.BEDS:
		var s := Tunes.bed(id)
		check_eq(s.size(), n, "%s is the same length as every other loop" % id)
		var peak := 0.0
		for v in s:
			peak = maxf(peak, absf(v))
		check(peak <= 1.0 and peak > 0.2, "%s is loud enough and does not clip past the rail (%.2f)" % [id, peak])
		check(_rms(s) > 0.03, "%s is not silence" % id)
		check(absf(s[0] - s[n - 1]) < 0.25, "%s loops without a jump" % id)
	check(_rms(Tunes.bed("boss")) > _rms(Tunes.bed("calm")), "the boss bed is busier than the calm one")
	for id in Tunes.LEADS:
		var s := Tunes.lead(id)
		check_eq(s.size(), n, "%s is the same length too" % id)
		check(_rms(s) > 0.01, "%s plays" % id)
		check(absf(s[n - 1]) < 0.05, "%s ends quiet, so the loop is clean" % id)


func test_melodies_are_in_key() -> void:
	check_eq(Tunes.MELODIES.size(), Tunes.LEADS.size(), "a melody for every lead")
	for id in Tunes.LEADS:
		var bars: Array = Tunes.MELODIES[id]
		check_eq(bars.size(), Tunes.BARS.size(), "%s has a bar for each chord" % id)
		var sounding := 0
		for bar in range(bars.size()):
			check_eq((bars[bar] as Array).size(), Tunes.STEPS_PER_BAR, "%s bar %d has eight steps" % [id, bar])
			for idx in bars[bar]:
				check(int(idx) >= -1 and int(idx) < 4, "%s only uses its bar's notes" % id)
				if int(idx) >= 0:
					sounding += 1
		check_eq(Tunes.notes(id).size(), sounding, "%s: every sounding step is a note" % id)
		check(sounding >= 12, "%s is a tune, not a ping" % id)
	# Each bar's melody notes belong to its chord (octaves of the triad).
	for bar in Tunes.BARS:
		for hz in bar.lead:
			var ok := false
			for p in bar.pad:
				var ratio := float(hz) / float(p)
				for octave in [1.0, 2.0, 4.0, 8.0]:
					for third in [1.0]:
						if absf(ratio / octave - third) < 0.01:
							ok = true
			check(ok, "%s: %.1f Hz is a chord tone" % [str(bar.name), float(hz)])
	check(Tunes.MELODIES["lead_levels"] != Tunes.MELODIES["lead_endless"] and Tunes.MELODIES["lead_contest"] != Tunes.MELODIES["lead_rush"], "the modes do not share a tune")


func test_lead_for_mode() -> void:
	check_eq(Tunes.lead_for_mode("levels"), "lead_levels", "a normal run")
	check_eq(Tunes.lead_for_mode("endless"), "lead_endless", "endless")
	check_eq(Tunes.lead_for_mode("daily"), "lead_contest", "the daily")
	check_eq(Tunes.lead_for_mode("weekly"), "lead_contest", "the weekly shares it")
	check_eq(Tunes.lead_for_mode("rush"), "lead_rush", "the rush")
	check_eq(Tunes.lead_for_mode("nonsense"), "lead_levels", "anything else is the road")
	for mode in ["levels", "endless", "daily", "rush"]:
		check(Tunes.LEADS.has(Tunes.lead_for_mode(mode)), "a real lead for %s" % mode)


func test_combo_pitch() -> void:
	check_near(Tunes.combo_pitch(0), 1.0, 0.0001, "no chain, the plain note")
	check_near(Tunes.combo_pitch(Tunes.COMBO_FROM), 1.0, 0.0001, "the first ping is the root")
	var last := 0.0
	for chain in range(Tunes.COMBO_FROM, Tunes.COMBO_FROM + Tunes.COMBO_MAX_STEPS * Tunes.COMBO_KILLS_PER_STEP + 1, Tunes.COMBO_KILLS_PER_STEP):
		var p := Tunes.combo_pitch(chain)
		check(p > last, "kill %d is higher than the one before (%.2f)" % [chain, p])
		last = p
	check_near(Tunes.combo_pitch(1000), 4.0, 0.0001, "it tops out two octaves up")
	check_near(Tunes.combo_pitch(Tunes.COMBO_FROM + 5 * Tunes.COMBO_KILLS_PER_STEP), 2.0, 0.0001, "five steps is an octave")
