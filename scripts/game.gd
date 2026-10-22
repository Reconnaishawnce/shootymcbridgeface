class_name Game
extends Node3D
## Root controller. Builds the whole scene in code (no editor needed), owns
## the title / running / game-over state machine, scoring and input.
##
## Smoke mode (`godot --headless ++ --smoke`) auto-starts, steers toward the
## better gate panel and quits after a fixed number of frames with a JSON
## summary, so CI can prove the game loop runs end to end.
##
## Screenshot mode (`godot ++ --shots=DIR`, needs a real renderer, e.g. under
## xvfb with software GL) walks title, play and game over, saves a PNG of
## each into DIR and quits. Used to eyeball layout without a phone.

enum State { TITLE, RUNNING, GAME_OVER }

const SMOKE_FRAMES := 900
const SMOKE_SEED := 12345
## Ignore taps for a moment after dying so a frantic tap does not restart.
const RETRY_LOCKOUT := 0.6
const KEY_STEER_SPEED := 7.0

var state: int = State.TITLE
var distance := 0.0
var kills := 0
var score := 0
var best := 0
var peak_squad := 1
var gates_passed := 0
var run_seed := 0
var smoke := false

var camera: Camera3D
var world: World
var squad: Squad
var hud: Hud

var _frames := 0
var _smoke_frames := SMOKE_FRAMES
var _shots_dir := ""
var _since_game_over := 0.0
var _shake := 0.0
var _drag_scale := 0.015


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	smoke = args.has("--smoke")
	for a in args:
		if a.begins_with("--smoke-frames="):
			_smoke_frames = maxi(60, int(a.get_slice("=", 1)))
		elif a.begins_with("--shots="):
			_shots_dir = a.get_slice("=", 1)
	best = SaveData.load_best()
	_build_scene()
	_drag_scale = (Squad.LANE_HALF * 2.0) / (get_viewport().get_visible_rect().size.x * 0.5)
	hud.show_title(best)
	if smoke:
		start_run()
	elif _shots_dir != "":
		_shots_walkthrough()


func _build_scene() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.36, 0.42, 0.5)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.78, 0.85)
	e.ambient_light_energy = 0.7
	e.fog_enabled = true
	e.fog_light_color = Color(0.36, 0.42, 0.5)
	e.fog_density = 0.012
	env.environment = e
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58.0, 28.0, 0.0)
	sun.light_energy = 1.1
	add_child(sun)

	camera = Camera3D.new()
	camera.position = Vector3(0.0, 11.0, 9.0)
	camera.fov = 55.0
	add_child(camera)
	camera.look_at(Vector3(0.0, 0.0, -7.0))
	camera.current = true

	world = World.new()
	add_child(world)
	world.gate_passed.connect(_on_gate_passed)
	world.zombie_killed.connect(_on_zombie_killed)
	world.squad_bitten.connect(_on_squad_bitten)

	squad = Squad.new()
	squad.world = world
	world.squad = squad
	add_child(squad)
	squad.count_changed.connect(_on_count_changed)
	squad.wiped_out.connect(_on_wiped_out)
	squad.reset()

	hud = Hud.new()
	add_child(hud)


func start_run() -> void:
	run_seed = SMOKE_SEED if smoke else randi()
	distance = 0.0
	kills = 0
	score = 0
	peak_squad = 1
	gates_passed = 0
	_shake = 0.0
	world.reset(run_seed)
	squad.reset()
	squad.active = true
	state = State.RUNNING
	hud.show_running()
	hud.update_stats(squad.count, distance, score)


func end_run() -> void:
	if state != State.RUNNING:
		return
	state = State.GAME_OVER
	squad.active = false
	_since_game_over = 0.0
	hud.update_stats(squad.count, distance, score)
	var is_best := SaveData.record_run(score)
	if is_best:
		best = score
	hud.show_game_over(score, best, is_best, int(distance), kills, peak_squad)


func _process(delta: float) -> void:
	_frames += 1
	match state:
		State.RUNNING:
			_tick_run(delta)
		State.GAME_OVER:
			_since_game_over += delta
	_keyboard_steer(delta)
	_apply_shake(delta)
	if smoke:
		_smoke_tick()


func _tick_run(delta: float) -> void:
	var ws := Difficulty.world_speed(distance)
	distance += ws * delta
	world.advance(delta, ws, distance, squad)
	score = int(distance) + kills * 10
	hud.update_stats(squad.count, distance, score)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_try_start()
	elif event is InputEventScreenDrag and state == State.RUNNING:
		squad.nudge(event.relative.x * _drag_scale)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			_try_start()


func _try_start() -> void:
	if state == State.TITLE:
		start_run()
	elif state == State.GAME_OVER and _since_game_over >= RETRY_LOCKOUT:
		start_run()


func _keyboard_steer(delta: float) -> void:
	if state != State.RUNNING:
		return
	var dir := 0.0
	if Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A):
		dir -= 1.0
	if Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D):
		dir += 1.0
	if dir != 0.0:
		squad.nudge(dir * KEY_STEER_SPEED * delta)


func _apply_shake(delta: float) -> void:
	if _shake <= 0.0:
		return
	_shake = maxf(0.0, _shake - delta * 3.0)
	camera.h_offset = randf_range(-_shake, _shake) * 0.3
	camera.v_offset = randf_range(-_shake, _shake) * 0.3


func _on_gate_passed(panel: GateMath.GatePanel, before: int, after: int) -> void:
	gates_passed += 1
	var text := GateMath.label(panel)
	if after > before:
		text += "   %d > %d" % [before, after]
	hud.show_float(text, after >= before)


func _on_zombie_killed(_zombie: Zombie) -> void:
	kills += 1


func _on_squad_bitten(bite: int) -> void:
	_shake = minf(1.0, _shake + 0.25 * bite)


func _on_count_changed(new_count: int) -> void:
	peak_squad = maxi(peak_squad, new_count)


func _on_wiped_out() -> void:
	# Deferred: the wipe can fire from inside the world's update loop.
	call_deferred("end_run")


func _smoke_tick() -> void:
	if _frames < _smoke_frames and state == State.RUNNING:
		# Play like a person: shoot whatever is close, otherwise line up the
		# better panel of the next gate.
		var z := world.nearest_zombie(22.0)
		var g := world.nearest_upcoming_gate()
		if z != null and (g == null or z.position.z > g.position.z):
			squad.target_x = clampf(z.position.x, -Squad.LANE_HALF, Squad.LANE_HALF)
		elif g != null:
			var i := GateMath.better_index(g.panels[0], g.panels[1], squad.count)
			squad.target_x = -GatePanelView.CENTER_X if i == 0 else GatePanelView.CENTER_X
		return
	if _shots_dir != "":
		return
	if _frames >= _smoke_frames or state == State.GAME_OVER:
		var summary := {
			"frames": _frames,
			"distance": int(distance),
			"gates": gates_passed,
			"kills": kills,
			"squad": squad.count,
			"peak_squad": peak_squad,
			"score": score,
			"state": state,
		}
		print("SMOKE_RESULT ", JSON.stringify(summary))
		var ok := gates_passed >= 3 and distance > 100.0
		get_tree().quit(0 if ok else 1)


func _shots_walkthrough() -> void:
	DirAccess.make_dir_recursive_absolute(_shots_dir)
	await _capture("1_title.png", 20)
	smoke = true
	start_run()
	await _capture("2_play_early.png", 240)
	await _capture("3_play_mid.png", 420)
	await _capture("4_play_late.png", 240)
	smoke = false
	squad.set_count(0)
	await _capture("5_game_over.png", 30)
	get_tree().quit(0)


func _capture(file_name: String, wait_frames: int) -> void:
	for i in range(wait_frames):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(_shots_dir.path_join(file_name))
	print("SHOT %s -> %s" % [file_name, error_string(err)])
