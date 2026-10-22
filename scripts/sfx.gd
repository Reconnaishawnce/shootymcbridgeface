class_name Sfx
extends Node
## Procedural one-shot sounds. No asset files: every effect is synthesised
## into an AudioStreamWAV at startup, so the APK stays tiny and every sound
## is tweakable in code. Runs while paused so menu clicks still play.

enum Wave { SINE, SQUARE, NOISE }

const RATE := 22050
const POOL := 12
const SHOT_INTERVAL := 0.07
const HIT_INTERVAL := 0.05

static var enabled := true
static var music_on := true

const MUSIC_RATE := 11025
const MUSIC_DB := -15.0
const MUSIC_STYLES := ["calm", "tense", "boss"]

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _shot_cooldown := 0.0
var _hit_cooldown := 0.0
var _music: Dictionary = {}
var _music_target: Dictionary = {}
var _music_style := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_streams = {
		"shot": make_shot(),
		"hit": make_hit(),
		"step": make_gate_step(),
		"gate_good": make_gate_good(),
		"gate_bad": make_gate_bad(),
		"bite": make_bite(),
		"boss_hit": make_boss_hit(),
		"boss_roar": make_boss_roar(),
		"level_clear": make_level_clear(),
		"wipe": make_wipe(),
		"spawn": make_spawn(),
		"click": make_click(),
		"rally": make_rally(),
		"powerup": make_powerup(),
		"throw": make_throw(),
		"explosion": make_explosion(),
		"block": make_block(),
		"crate": make_crate(),
	}
	for i in range(POOL):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	for style in MUSIC_STYLES:
		var mp := AudioStreamPlayer.new()
		mp.stream = make_music(style)
		mp.volume_db = -80.0
		mp.bus = "Master"
		add_child(mp)
		mp.play()
		_music[style] = mp
		_music_target[style] = 0.0


func _exit_tree() -> void:
	stop_all()


func _process(delta: float) -> void:
	_shot_cooldown -= delta
	_hit_cooldown -= delta
	# Crossfade the music layers toward their targets.
	for style in _music:
		var mp: AudioStreamPlayer = _music[style]
		var target: float = _music_target[style] if (music_on and enabled) else 0.0
		var cur := db_to_linear(mp.volume_db) if mp.volume_db > -79.0 else 0.0
		var nxt := lerpf(cur, target, 1.0 - exp(-2.5 * delta))
		mp.volume_db = linear_to_db(nxt) if nxt > 0.001 else -80.0


## Pick which layer carries the room: calm, tense or boss. Blank silences.
func set_music(style: String) -> void:
	if style == _music_style:
		return
	_music_style = style
	for key in _music_target:
		_music_target[key] = db_to_linear(MUSIC_DB) if key == style else 0.0


func play(name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not enabled or not _streams.has(name):
		return
	var p := _players[_next]
	_next = (_next + 1) % POOL
	p.stream = _streams[name]
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


## Stop every voice and drop the streams. Called before quitting so no
## playback object is left alive at exit.
func stop_all() -> void:
	for p in _players:
		p.stop()
		p.stream = null
	for style in _music:
		var mp: AudioStreamPlayer = _music[style]
		mp.stop()
		mp.stream = null
	_streams.clear()


## Gunfire is throttled: thirty tracers a second would be a wall of noise.
func play_shot() -> void:
	if _shot_cooldown > 0.0:
		return
	_shot_cooldown = SHOT_INTERVAL
	play("shot", -16.0, randf_range(0.9, 1.1))


func play_hit() -> void:
	if _hit_cooldown > 0.0:
		return
	_hit_cooldown = HIT_INTERVAL
	play("hit", -10.0, randf_range(0.85, 1.15))


# --- synthesis (static and pure, so it is unit-testable) -------------------

## A tone sweeping from [param f0] to [param f1] with exponential decay.
static func tone(duration: float, f0: float, f1: float, decay: float, wave: int, amp: float = 0.8) -> PackedFloat32Array:
	var n := maxi(1, int(duration * RATE))
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in range(n):
		var t := float(i) / float(RATE)
		var f := lerpf(f0, f1, t / duration)
		phase += TAU * f / float(RATE)
		var v := 0.0
		match wave:
			Wave.SINE:
				v = sin(phase)
			Wave.SQUARE:
				v = 1.0 if sin(phase) > 0.0 else -1.0
			Wave.NOISE:
				v = randf_range(-1.0, 1.0)
		out[i] = v * amp * exp(-decay * t)
	return out


static func concat(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var out := PackedFloat32Array(a)
	out.append_array(b)
	return out


static func mix(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var n := maxi(a.size(), b.size())
	var out := PackedFloat32Array()
	out.resize(n)
	for i in range(n):
		var v := 0.0
		if i < a.size():
			v += a[i]
		if i < b.size():
			v += b[i]
		out[i] = clampf(v, -1.0, 1.0)
	return out


static func to_stream(samples: PackedFloat32Array) -> AudioStreamWAV:
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in range(samples.size()):
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	s.data = bytes
	return s


static func make_shot() -> AudioStreamWAV:
	return to_stream(mix(tone(0.07, 0.0, 0.0, 60.0, Wave.NOISE, 0.7), tone(0.05, 220.0, 80.0, 50.0, Wave.SINE, 0.5)))


static func make_hit() -> AudioStreamWAV:
	return to_stream(tone(0.05, 0.0, 0.0, 70.0, Wave.NOISE, 0.6))


static func make_gate_step() -> AudioStreamWAV:
	return to_stream(tone(0.09, 660.0, 990.0, 25.0, Wave.SINE, 0.5))


static func make_gate_good() -> AudioStreamWAV:
	return to_stream(concat(tone(0.12, 523.0, 523.0, 8.0, Wave.SINE, 0.6), tone(0.25, 784.0, 784.0, 7.0, Wave.SINE, 0.6)))


static func make_gate_bad() -> AudioStreamWAV:
	return to_stream(tone(0.3, 220.0, 110.0, 6.0, Wave.SQUARE, 0.35))


static func make_bite() -> AudioStreamWAV:
	return to_stream(mix(tone(0.25, 90.0, 45.0, 10.0, Wave.SINE, 0.9), tone(0.08, 0.0, 0.0, 40.0, Wave.NOISE, 0.4)))


static func make_boss_hit() -> AudioStreamWAV:
	return to_stream(tone(0.08, 140.0, 100.0, 30.0, Wave.SQUARE, 0.35))


static func make_boss_roar() -> AudioStreamWAV:
	return to_stream(mix(tone(0.7, 70.0, 40.0, 3.0, Wave.SQUARE, 0.5), tone(0.7, 0.0, 0.0, 4.0, Wave.NOISE, 0.3)))


static func make_level_clear() -> AudioStreamWAV:
	var s := PackedFloat32Array()
	for f in [523.0, 659.0, 784.0, 1047.0]:
		s = concat(s, tone(0.13, f, f, 9.0, Wave.SINE, 0.6))
	return to_stream(concat(s, tone(0.4, 1047.0, 1047.0, 5.0, Wave.SINE, 0.6)))


static func make_wipe() -> AudioStreamWAV:
	return to_stream(tone(0.8, 300.0, 50.0, 3.0, Wave.SQUARE, 0.4))


static func make_spawn() -> AudioStreamWAV:
	return to_stream(tone(0.09, 440.0, 880.0, 20.0, Wave.SINE, 0.5))


static func make_click() -> AudioStreamWAV:
	return to_stream(tone(0.04, 1200.0, 900.0, 60.0, Wave.SINE, 0.5))


static func make_rally() -> AudioStreamWAV:
	# A rising chord stab: the squad cheering a big gain.
	var a := tone(0.35, 392.0, 392.0, 6.0, Wave.SINE, 0.35)
	var b := tone(0.35, 494.0, 494.0, 6.0, Wave.SINE, 0.3)
	var c := tone(0.35, 587.0, 587.0, 6.0, Wave.SINE, 0.3)
	var lead := concat(tone(0.08, 523.0, 523.0, 10.0, Wave.SINE, 0.5), concat(tone(0.08, 659.0, 659.0, 10.0, Wave.SINE, 0.5), tone(0.3, 784.0, 784.0, 6.0, Wave.SINE, 0.5)))
	return to_stream(mix(mix(mix(a, b), c), lead))


static func make_powerup() -> AudioStreamWAV:
	return to_stream(concat(tone(0.07, 440.0, 660.0, 12.0, Wave.SQUARE, 0.25), concat(tone(0.07, 660.0, 880.0, 12.0, Wave.SQUARE, 0.25), tone(0.25, 880.0, 1320.0, 8.0, Wave.SINE, 0.5))))


static func make_throw() -> AudioStreamWAV:
	return to_stream(tone(0.18, 300.0, 900.0, 12.0, Wave.SINE, 0.4))


static func make_explosion() -> AudioStreamWAV:
	return to_stream(mix(tone(0.6, 0.0, 0.0, 7.0, Wave.NOISE, 0.9), tone(0.5, 80.0, 30.0, 6.0, Wave.SINE, 0.9)))


static func make_block() -> AudioStreamWAV:
	return to_stream(mix(tone(0.12, 1200.0, 600.0, 20.0, Wave.SQUARE, 0.2), tone(0.12, 0.0, 0.0, 30.0, Wave.NOISE, 0.3)))


static func make_crate() -> AudioStreamWAV:
	return to_stream(concat(tone(0.05, 700.0, 700.0, 20.0, Wave.SQUARE, 0.3), tone(0.12, 1050.0, 1050.0, 14.0, Wave.SINE, 0.4)))


# --- music -----------------------------------------------------------------

## A short looping bed synthesised from a kick, a bass pulse, hats and a pad.
## Three styles share the key so crossfading between them feels like one
## track getting more urgent.
static func make_music(style: String) -> AudioStreamWAV:
	var bpm := 100.0
	var kicks := [0]
	var hats := []
	var bass_amp := 0.22
	var pad := [110.0, 130.8, 164.8]
	var pad_amp := 0.07
	match style:
		"tense":
			bpm = 118.0
			kicks = [0, 2]
			hats = [1, 3]
			bass_amp = 0.3
			pad = [110.0, 130.8, 164.8, 196.0]
			pad_amp = 0.06
		"boss":
			bpm = 140.0
			kicks = [0, 1, 2, 3]
			hats = [0.5, 1.5, 2.5, 3.5]
			bass_amp = 0.36
			pad = [110.0, 130.8, 155.6, 164.8]
			pad_amp = 0.08
	var beat := 60.0 / bpm
	var beats := 8
	var n := int(beat * float(beats) * float(MUSIC_RATE))
	var out := PackedFloat32Array()
	out.resize(n)
	var bass_phase := 0.0
	var pad_phases := []
	for f in pad:
		pad_phases.append(0.0)
	for i in range(n):
		var t := float(i) / float(MUSIC_RATE)
		var b := t / beat
		var in_beat := fmod(b, 1.0)
		var bar_beat := fmod(b, 4.0)
		var v := 0.0
		# Bass: one note, pulsing every beat, octave jump on beat 3 for boss.
		var bass_f := 55.0 if not (style == "boss" and int(bar_beat) == 2) else 110.0
		bass_phase += TAU * bass_f / float(MUSIC_RATE)
		v += sin(bass_phase) * bass_amp * exp(-3.0 * in_beat)
		# Kick: a quick pitch drop on the chosen beats.
		for k in kicks:
			var since := bar_beat - float(k)
			if since >= 0.0 and since < 0.25:
				v += sin(TAU * (120.0 - 300.0 * since) * since) * 0.5 * exp(-18.0 * since)
		# Hats: short noise ticks.
		for h in hats:
			var since_h := bar_beat - float(h)
			if since_h >= 0.0 and since_h < 0.05:
				v += randf_range(-1.0, 1.0) * 0.12 * exp(-80.0 * since_h)
		# Pad: slow tremolo chord.
		var trem := 0.7 + 0.3 * sin(t * 0.8)
		for j in range(pad.size()):
			pad_phases[j] += TAU * float(pad[j]) / float(MUSIC_RATE)
			v += sin(pad_phases[j]) * pad_amp * trem
		out[i] = clampf(v, -1.0, 1.0)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MUSIC_RATE
	stream.stereo = false
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in range(n):
		bytes.encode_s16(i * 2, int(out[i] * 32767.0))
	stream.data = bytes
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = n
	return stream
