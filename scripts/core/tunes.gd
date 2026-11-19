class_name Tunes
extends RefCounted
## The music, as numbers. One chord progression (Am, F, C, G) at one
## tempo, so every loop is the same length and they all stay in step:
## three beds that carry the room (calm, tense, boss) and one melody
## per kind of run laid over whichever bed is playing. Pure: it returns
## samples; the sound script wraps them in streams.

const RATE := 8000
## Samples per beat: 126 beats a minute, near enough.
const BEAT := 3810
const BEATS := 16
const STEPS_PER_BAR := 8
const BEDS := ["calm", "tense", "boss"]
const LEADS := ["lead_levels", "lead_endless", "lead_contest", "lead_rush"]

## The four bars: the bass note, the pad's triad, and the four notes a
## melody may use over it (low to high).
const BARS := [
	{"name": "Am", "bass": 110.0, "pad": [220.0, 261.63, 329.63], "lead": [440.0, 523.25, 659.25, 880.0]},
	{"name": "F", "bass": 87.31, "pad": [174.61, 220.0, 261.63], "lead": [440.0, 523.25, 698.46, 880.0]},
	{"name": "C", "bass": 130.81, "pad": [196.0, 261.63, 329.63], "lead": [392.0, 523.25, 659.25, 783.99]},
	{"name": "G", "bass": 98.0, "pad": [196.0, 246.94, 293.66], "lead": [392.0, 493.88, 587.33, 783.99]},
]

## Melodies: per bar, eight steps, each an index into that bar's lead
## notes or -1 for a rest.
const MELODIES := {
	# The road: a climb that answers itself.
	"lead_levels": [[0, -1, 2, -1, 1, 2, 3, -1], [0, -1, 2, -1, 1, 2, 3, -1], [3, -1, 2, -1, 1, -1, 2, 1], [0, -1, 1, -1, 2, -1, -1, -1]],
	# Endless: a wheel that never stops turning.
	"lead_endless": [[0, 1, 2, 3, 2, 1, 2, 1], [0, 1, 2, 3, 2, 1, 2, 1], [0, 1, 2, 3, 2, 1, 2, 1], [0, 1, 2, 3, 2, 1, 0, -1]],
	# The daily and the weekly: a syncopated call from the top.
	"lead_contest": [[3, -1, 3, 2, -1, 1, 2, -1], [3, -1, 3, 2, -1, 1, 0, -1], [2, -1, 2, 3, -1, 2, 1, -1], [1, -1, 1, 2, -1, 3, -1, -1]],
	# Boss rush: hammered eighths.
	"lead_rush": [[0, 0, 2, 0, 3, 0, 2, 0], [0, 0, 2, 0, 3, 0, 2, 1], [0, 0, 2, 0, 3, 0, 2, 0], [3, 3, 2, 2, 1, 1, 0, -1]],
}


static func length() -> int:
	return BEAT * BEATS


## The melody a run of [param mode] carries.
static func lead_for_mode(mode: String) -> String:
	match mode:
		"endless":
			return "lead_endless"
		"daily", "weekly":
			return "lead_contest"
		"rush":
			return "lead_rush"
	return "lead_levels"


## The notes of a melody as {step, hz}: one per sounding step.
static func notes(lead: String) -> Array:
	var out := []
	var bars: Array = MELODIES.get(lead, MELODIES["lead_levels"])
	for bar in range(bars.size()):
		for s in range(STEPS_PER_BAR):
			var idx := int(bars[bar][s])
			if idx >= 0:
				out.append({"step": bar * STEPS_PER_BAR + s, "hz": float(BARS[bar]["lead"][idx])})
	return out


## Adds one plucked note to [param out]: a fundamental with two soft
## overtones (so a phone speaker can find the low ones), a quick attack
## and an exponential tail.
static func _pluck(out: PackedFloat32Array, start: int, samples: int, hz: float, amp: float, decay: float) -> void:
	var n := out.size()
	var w := TAU * hz / float(RATE)
	var attack := 40.0
	for j in range(samples):
		var idx := start + j
		if idx >= n:
			break
		var ph := w * float(j)
		var env := minf(1.0, float(j) / attack) * exp(-decay * float(j) / float(RATE))
		out[idx] += (sin(ph) + 0.35 * sin(ph * 2.0) + 0.18 * sin(ph * 3.0)) * amp * env


static func _noise(out: PackedFloat32Array, start: int, samples: int, amp: float, decay: float, rng: RandomNumberGenerator) -> void:
	var n := out.size()
	for j in range(samples):
		var idx := start + j
		if idx >= n:
			break
		out[idx] += rng.randf_range(-1.0, 1.0) * amp * exp(-decay * float(j) / float(RATE))


static func _kick(out: PackedFloat32Array, start: int, amp: float) -> void:
	var n := out.size()
	for j in range(int(0.22 * RATE)):
		var idx := start + j
		if idx >= n:
			break
		var t := float(j) / float(RATE)
		out[idx] += sin(TAU * (150.0 - 320.0 * t) * t) * amp * exp(-16.0 * t)


## A bed: pad, bass and drums for the whole progression.
static func bed(style: String) -> PackedFloat32Array:
	var n := length()
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = style.hash()
	var bar_len := BEAT * 4
	var step := BEAT / 2
	var pad_amp := 0.06 if style != "boss" else 0.07
	var fade := 240.0
	for bar in range(BARS.size()):
		var chord: Dictionary = BARS[bar]
		var base := bar * bar_len
		# The pad: three sines that swell in and out at the bar line, so a
		# chord change never clicks.
		var w0 := TAU * float(chord.pad[0]) / float(RATE)
		var w1 := TAU * float(chord.pad[1]) / float(RATE)
		var w2 := TAU * float(chord.pad[2]) / float(RATE)
		for j in range(bar_len):
			var env := minf(1.0, minf(float(j), float(bar_len - j)) / fade)
			var fj := float(j)
			out[base + j] += (sin(w0 * fj) + sin(w1 * fj) + sin(w2 * fj)) * pad_amp * env
		# The bass, by style: two notes a bar, eighths, or eighths that
		# jump the octave.
		var root := float(chord.bass)
		for s in range(STEPS_PER_BAR):
			var at := base + s * step
			match style:
				"calm":
					if s == 0 or s == 4:
						_pluck(out, at, step * 3, root, 0.26, 5.0)
				"tense":
					_pluck(out, at, step, root, 0.24 if s % 4 == 0 else 0.17, 9.0)
				_:
					_pluck(out, at, step, root * (2.0 if s % 2 == 1 else 1.0), 0.24, 10.0)
		# Drums.
		for beat in range(4):
			var at_b := base + beat * BEAT
			match style:
				"calm":
					if beat == 0:
						_kick(out, at_b, 0.4)
					if beat == 2:
						_noise(out, at_b, 300, 0.05, 90.0, rng)
				"tense":
					if beat % 2 == 0:
						_kick(out, at_b, 0.5)
					else:
						_noise(out, at_b, 900, 0.16, 30.0, rng)
					_noise(out, at_b + step, 300, 0.08, 90.0, rng)
				_:
					_kick(out, at_b, 0.55)
					if beat % 2 == 1:
						_noise(out, at_b, 900, 0.2, 30.0, rng)
					for q in range(4):
						_noise(out, at_b + q * (step / 2), 220, 0.07 if q % 2 == 0 else 0.045, 110.0, rng)
	for i in range(n):
		out[i] = clampf(out[i], -1.0, 1.0)
	return out


## A melody: plucked notes on the eighth-note grid, silent between.
static func lead(id: String) -> PackedFloat32Array:
	var n := length()
	var out := PackedFloat32Array()
	out.resize(n)
	var step := BEAT / 2
	var staccato := id == "lead_rush"
	for note in notes(id):
		_pluck(out, int(note.step) * step, step * (1 if staccato else 2), float(note.hz), 0.3, 11.0 if staccato else 5.5)
	for i in range(n):
		out[i] = clampf(out[i], -1.0, 1.0)
	return out


## How far up the scale a combo's kill sound has climbed: the pitch
## multiplier for kill number [param chain] of a chain. It walks a minor
## pentatonic scale, one step every two kills, over two octaves.
const COMBO_SCALE := [1.0, 1.2, 1.3333, 1.5, 1.8]
const COMBO_KILLS_PER_STEP := 2
const COMBO_MAX_STEPS := 10
const COMBO_FROM := 3


static func combo_pitch(chain: int) -> float:
	var steps := clampi((chain - COMBO_FROM) / COMBO_KILLS_PER_STEP, 0, COMBO_MAX_STEPS)
	return float(COMBO_SCALE[steps % COMBO_SCALE.size()]) * pow(2.0, float(steps / COMBO_SCALE.size()))
