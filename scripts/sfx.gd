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

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _shot_cooldown := 0.0
var _hit_cooldown := 0.0


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
	}
	for i in range(POOL):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


func _process(delta: float) -> void:
	_shot_cooldown -= delta
	_hit_cooldown -= delta


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
