class_name Game
extends Node3D
## Root controller. Builds the whole scene in code (no editor needed), owns
## the title / running / game-over state machine, pause, scoring and input.
##
## Smoke mode (`godot --headless ++ --smoke`) auto-starts, plays like a
## competent person (shoots what is close, lines up the better panel, tracks
## the boss core) and quits after a fixed number of frames with a JSON
## summary, so CI can prove the game loop runs end to end.
##
## Screenshot mode (`godot ++ --shots=DIR`, needs a real renderer, e.g. under
## xvfb with software GL) walks title, play, boss and game over, saves a PNG
## of each into DIR and quits. Used to eyeball layout without a phone.

enum State { TITLE, RUNNING, GAME_OVER }

const SMOKE_FRAMES := 900
const SMOKE_SEED := 12345
## Ignore taps for a moment after dying so a frantic tap does not restart.
const RETRY_LOCKOUT := 0.6
const KEY_STEER_SPEED := 7.0

var state: int = State.TITLE
var total_distance := 0.0
var kills := 0
var score := 0
var bonus := 0
var best := 0
var best_level := 0
var peak_squad := 1
var gates_passed := 0
var bosses_killed := 0
var run_seed := 0
var smoke := false

var camera: Camera3D
var world: World
var squad: Squad
var hud: Hud
var sfx: Sfx

var _frames := 0
var _smoke_frames := SMOKE_FRAMES
var _shots_dir := ""
var _since_game_over := 0.0
var _shake := 0.0
var _drag_scale := 0.015
var _fov_tween: Tween
var _quitting := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	smoke = args.has("--smoke")
	for a in args:
		if a.begins_with("--smoke-frames="):
			_smoke_frames = maxi(60, int(a.get_slice("=", 1)))
		elif a.begins_with("--shots="):
			_shots_dir = a.get_slice("=", 1)
	best = SaveData.load_best()
	best_level = SaveData.load_best_level()
	# Headless CI has no audio device; the dummy driver releases playbacks
	# on its own thread and can report them as leaked at exit. Keep the
	# auto-player silent so its exit is deterministic.
	Sfx.enabled = SaveData.load_sound_on() and not smoke
	_build_scene()
	_drag_scale = (Squad.LANE_HALF * 2.0) / (get_viewport().get_visible_rect().size.x * 0.5)
	hud.set_sound(Sfx.enabled)
	hud.show_title(best, best_level)
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

	sfx = Sfx.new()
	add_child(sfx)

	world = World.new()
	add_child(world)
	world.gate_passed.connect(_on_gate_passed)
	world.gate_stepped.connect(_on_gate_stepped)
	world.zombie_killed.connect(_on_zombie_killed)
	world.squad_bitten.connect(_on_squad_bitten)
	world.boss_spawned.connect(_on_boss_spawned)
	world.boss_hit.connect(_on_boss_hit)
	world.boss_killed.connect(_on_boss_killed)
	world.level_started.connect(_on_level_started)

	squad = Squad.new()
	squad.world = world
	world.squad = squad
	add_child(squad)
	squad.count_changed.connect(_on_count_changed)
	squad.wiped_out.connect(_on_wiped_out)
	squad.reset()

	hud = Hud.new()
	add_child(hud)
	hud.pause_pressed.connect(pause_game)
	hud.resume_pressed.connect(resume_game)
	hud.quit_pressed.connect(quit_to_title)
	hud.sound_toggled.connect(_on_sound_toggled)


func start_run() -> void:
	run_seed = SMOKE_SEED if smoke else randi()
	total_distance = 0.0
	kills = 0
	score = 0
	bonus = 0
	peak_squad = 1
	gates_passed = 0
	bosses_killed = 0
	_shake = 0.0
	state = State.RUNNING
	squad.reset()
	world.reset(run_seed)
	squad.active = true
	hud.show_running()
	hud.update_stats(squad.count, world.level, total_distance, score)
	sfx.play("spawn")


func end_run() -> void:
	if state != State.RUNNING:
		return
	state = State.GAME_OVER
	squad.active = false
	_since_game_over = 0.0
	# The auto-player must not pollute a real player's records.
	var records := {"new_best_score": false, "new_best_level": false}
	if not smoke:
		records = SaveData.record_run(score, world.level)
	if records.new_best_score:
		best = score
	if records.new_best_level:
		best_level = world.level
	hud.update_stats(squad.count, world.level, total_distance, score)
	hud.show_game_over(score, best, records.new_best_score, world.level, int(total_distance), kills, peak_squad)
	sfx.play("wipe")
	_shake = 1.0


func pause_game() -> void:
	if state != State.RUNNING or get_tree().paused:
		return
	get_tree().paused = true
	hud.show_paused(true)
	sfx.play("click")


func resume_game() -> void:
	if not get_tree().paused:
		return
	get_tree().paused = false
	hud.show_paused(false)
	sfx.play("click")


func quit_to_title() -> void:
	get_tree().paused = false
	hud.show_paused(false)
	if state == State.RUNNING:
		# Leaving mid-run still counts: the score stands.
		state = State.GAME_OVER
		squad.active = false
		SaveData.record_run(score, world.level)
		best = maxi(best, score)
		best_level = maxi(best_level, world.level)
	state = State.TITLE
	hud.show_title(best, best_level)
	sfx.play("click")


func _notification(what: int) -> void:
	# Phone went to the home screen, or the back button was pressed.
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if state == State.RUNNING and not get_tree().paused:
			pause_game()


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
	var ws := world.advance(delta, squad)
	total_distance += ws * delta
	score = int(total_distance) + kills * 10 + bonus
	hud.update_stats(squad.count, world.level, total_distance, score)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_try_start()
	elif event is InputEventScreenDrag and state == State.RUNNING:
		squad.nudge(event.relative.x * _drag_scale)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			_try_start()
		elif event.keycode == KEY_ESCAPE or event.keycode == KEY_P:
			if get_tree().paused:
				resume_game()
			else:
				pause_game()


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


## A quick zoom-in and back: the camera leaning into a good moment.
func _punch(amount: float) -> void:
	if _fov_tween != null:
		_fov_tween.kill()
	_fov_tween = create_tween()
	_fov_tween.tween_property(camera, "fov", 55.0 - amount, 0.08)
	_fov_tween.tween_property(camera, "fov", 55.0, 0.25)


func _on_gate_passed(panel: GateMath.GatePanel, before: int, after: int) -> void:
	gates_passed += 1
	var text := GateMath.label(panel)
	if after > before:
		text += "   %d > %d" % [before, after]
	hud.show_float(text, after >= before)
	if after > before:
		sfx.play("gate_good")
		_punch(3.0)
	else:
		sfx.play("gate_bad", -4.0)


func _on_gate_stepped(gate: Gate, index: int) -> void:
	sfx.play("step", -8.0, randf_range(0.95, 1.1))
	Burst.spawn(world, gate.panel_position(index) + Vector3(0.0, 0.0, 0.3), GatePanelView.CHOSEN, 4, 0.1, 3.0, 0.3)


func _on_zombie_killed(zombie: Zombie) -> void:
	kills += 1
	sfx.play_hit()
	var color := Zombie.BRUTE_SKIN if zombie.brute else Zombie.SKIN
	Burst.spawn(world, zombie.position + Vector3(0.0, 0.8, 0.0), color, 10 if zombie.brute else 5, 0.16 if zombie.brute else 0.12)


func _on_squad_bitten(bite: int, heavy: bool) -> void:
	_shake = minf(1.0, _shake + (0.5 if heavy else 0.2))
	sfx.play("bite", 0.0 if heavy else -6.0)
	Burst.spawn(world, squad.position + Vector3(0.0, 0.9, -0.5), Soldier.BODY, mini(bite * 3, 24), 0.12, 4.5)


func _on_boss_spawned(boss: Boss) -> void:
	if smoke:
		print("SMOKE_BOSS ", JSON.stringify({"level": world.level, "squad": squad.count, "boss_hp": boss.max_hp, "frame": _frames}))
	hud.show_boss(true)
	hud.show_banner("BOSS", 1.2)
	sfx.play("boss_roar")
	_shake = 0.6


func _on_boss_hit(boss: Boss, is_core: bool) -> void:
	hud.set_boss_ratio(boss.hp / boss.max_hp)
	if is_core:
		sfx.play("boss_hit", -4.0, 1.4)
		Burst.spawn(world, boss.position + Vector3(boss.core_x, 1.9, 1.2), Boss.CORE_COLOR, 3, 0.1, 3.0, 0.3)


func _on_boss_killed(level: int, squad_left: int) -> void:
	bosses_killed += 1
	if smoke:
		print("SMOKE_BOSS_DOWN ", JSON.stringify({"level": level, "squad_left": squad_left, "frame": _frames}))
	var b := Difficulty.level_bonus(level, squad_left)
	bonus += b
	hud.show_boss(false)
	hud.show_banner("LEVEL %d CLEAR\n+%d" % [level, b], 1.8)
	hud.flash(0.35)
	sfx.play("level_clear")
	_punch(6.0)
	_shake = 0.8
	if world.boss != null:
		Burst.spawn(world, world.boss.position + Vector3(0.0, 2.0, 0.0), Boss.CORE_COLOR, 40, 0.22, 7.0, 0.9)
		Burst.spawn(world, world.boss.position + Vector3(0.0, 1.5, 0.0), Boss.SKIN, 30, 0.2, 6.0, 0.9)


func _on_level_started(level: int) -> void:
	if level > 1:
		squad.redeploy()
		hud.show_banner("LEVEL %d" % level, 1.0)
		sfx.play("spawn")


func _on_count_changed(new_count: int) -> void:
	peak_squad = maxi(peak_squad, new_count)


func _on_wiped_out() -> void:
	# Deferred: the wipe can fire from inside the world's update loop.
	call_deferred("end_run")


func _on_sound_toggled(on: bool) -> void:
	Sfx.enabled = on
	SaveData.save_sound_on(on)
	if on:
		sfx.play("click")


func _smoke_tick() -> void:
	if _quitting:
		return
	if _frames < _smoke_frames and state == State.RUNNING:
		_bot_steer()
		return
	if _shots_dir != "":
		return
	if _frames >= _smoke_frames or state == State.GAME_OVER:
		var summary := {
			"frames": _frames,
			"level": world.level,
			"distance": int(total_distance),
			"gates": gates_passed,
			"bosses": bosses_killed,
			"kills": kills,
			"squad": squad.count,
			"peak_squad": peak_squad,
			"score": score,
			"state": state,
		}
		print("SMOKE_RESULT ", JSON.stringify(summary))
		var ok := gates_passed >= 3 and total_distance > 100.0
		_quit_with(0 if ok else 1)


## Play like a person: track the boss core, shoot whatever is close,
## otherwise line up the better panel of the next gate.
func _bot_steer() -> void:
	if world.phase == World.Phase.BOSS and world.boss != null and world.boss.alive:
		squad.target_x = clampf(world.boss.position.x + world.boss.core_x, -Squad.LANE_HALF, Squad.LANE_HALF)
		return
	var z := world.nearest_zombie(22.0)
	var g := world.nearest_upcoming_gate()
	if z != null and (g == null or z.position.z > g.position.z):
		squad.target_x = clampf(z.position.x, -Squad.LANE_HALF, Squad.LANE_HALF)
	elif g != null:
		var i := GateMath.better_index(g.panels[0], g.panels[1], squad.count)
		squad.target_x = -GatePanelView.CENTER_X if i == 0 else GatePanelView.CENTER_X


func _shots_walkthrough() -> void:
	DirAccess.make_dir_recursive_absolute(_shots_dir)
	await _capture("1_title.png", 20)
	smoke = true
	start_run()
	await _capture("2_play_early.png", 240)
	await _capture("3_play_mid.png", 600)
	# Run until the boss fight is on, then grab it.
	for i in range(3000):
		if world.phase == World.Phase.BOSS and world.boss != null and world.boss.position.z > -14.0:
			break
		await get_tree().process_frame
	await _capture("4_boss.png", 5)
	for i in range(3000):
		if world.phase != World.Phase.BOSS:
			break
		await get_tree().process_frame
	await _capture("5_level_clear.png", 20)
	await _capture("6_level_two.png", 400)
	pause_game()
	await _capture("7_paused.png", 5)
	resume_game()
	smoke = false
	squad.set_count(0)
	await _capture("8_game_over.png", 30)
	_quit_with(0)


func _capture(file_name: String, wait_frames: int) -> void:
	for i in range(wait_frames):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(_shots_dir.path_join(file_name))
	print("SHOT %s -> %s" % [file_name, error_string(err)])


## Quit cleanly: silence the audio voices and give the audio server a mix
## or two to release their playbacks, otherwise Godot reports leaked
## AudioStreamPlayback objects at exit.
func _quit_with(code: int) -> void:
	if _quitting:
		return
	_quitting = true
	sfx.stop_all()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(code)
