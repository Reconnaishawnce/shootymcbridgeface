extends TestCase


func test_tone_shape() -> void:
	var s := Sfx.tone(0.1, 440.0, 440.0, 0.0, Sfx.Wave.SINE, 1.0)
	check_eq(s.size(), int(0.1 * Sfx.RATE), "sample count")
	var peak := 0.0
	for v in s:
		check(v >= -1.0 and v <= 1.0, "bounded")
		peak = maxf(peak, absf(v))
	check(peak > 0.9, "reaches near full amplitude")
	var decayed := Sfx.tone(0.5, 440.0, 440.0, 20.0, Sfx.Wave.SINE, 1.0)
	check(absf(decayed[decayed.size() - 1]) < 0.01, "decays to silence")


func test_every_effect_builds() -> void:
	for s in [Sfx.make_shot(), Sfx.make_hit(), Sfx.make_gate_step(), Sfx.make_gate_good(),
			Sfx.make_gate_bad(), Sfx.make_bite(), Sfx.make_boss_hit(), Sfx.make_boss_roar(),
			Sfx.make_level_clear(), Sfx.make_wipe(), Sfx.make_spawn(), Sfx.make_click()]:
		check(s.data.size() > 100, "stream has data")
		check_eq(s.mix_rate, Sfx.RATE, "mix rate")
		check(s.get_length() < 2.0, "effects are short")


func test_mix_and_concat() -> void:
	var a := Sfx.tone(0.01, 100.0, 100.0, 0.0, Sfx.Wave.SINE, 0.9)
	var b := Sfx.tone(0.02, 100.0, 100.0, 0.0, Sfx.Wave.SINE, 0.9)
	check_eq(Sfx.concat(a, b).size(), a.size() + b.size(), "concat length")
	var m := Sfx.mix(a, b)
	check_eq(m.size(), b.size(), "mix takes the longer length")
	for v in m:
		check(v >= -1.0 and v <= 1.0, "mix is clamped")
