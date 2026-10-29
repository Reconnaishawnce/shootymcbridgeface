class_name Game
extends Node3D
## Root controller. Builds the whole scene in code (no editor needed), owns
## the title / running / choosing / game-over state machine, pause, modes,
## perks, the wallet and shop, scoring and input.
##
## Smoke mode (`godot --headless ++ --smoke [--endless]`) auto-starts, plays
## like a competent person (shoots what is close, lines up the better
## panel, tracks the boss core, takes the first perk) and quits after a
## fixed number of frames with a JSON summary, so CI can prove the game
## loop runs end to end.
##
## Screenshot mode (`godot ++ --shots=DIR`, needs a real renderer, e.g. under
## xvfb with software GL) walks title, shop, play, perks, boss, level clear,
## level two, pause and game over, saves a PNG of each into DIR and quits.

enum State { TITLE, RUNNING, GAME_OVER }

const SMOKE_FRAMES := 900
const SMOKE_SEED := 12345
var _smoke_seed := SMOKE_SEED
## Ignore taps for a moment after dying so a frantic tap does not restart.
const RETRY_LOCKOUT := 0.6
const KEY_STEER_SPEED := 7.0

var state: int = State.TITLE
var mode := "levels"
var total_distance := 0.0
var kills := 0
## Coins the kills have paid this run, before the multipliers.
var bounty := 0
var score := 0
var bonus := 0
var best := 0
var best_level := 0
var best_endless := 0
var coins := 0
var peak_squad := 1
var gates_passed := 0
var bosses_killed := 0
var run_seed := 0
var smoke := false
var squad_type := "rifle"

var camera: Camera3D
var _cam_rig: Node3D
var _sun: DirectionalLight3D
var _env: Environment
var _vignette: ColorRect
var world: World
var squad: Squad
var hud: Hud
var sfx: Sfx
var meta := Meta.new()
var perks := Perks.new()
var combo := Combo.new()
var powerups := Powerups.new()
var waves_cleared := 0
var perfect_gates := 0
var _run_time := 0.0
var _level_peak := 1
## The upgrades in force for the current run: the real ones, or a blank
## set for the daily so everyone plays the same game.
var run_meta := Meta.new()
var daily_day := 0
var daily_results: Dictionary = {}
var week_number := 0
## Lifetime numbers and the achievements already paid.
var stats: Dictionary = Stats.blank()
var quest_state: Dictionary = {}
var season_state: Dictionary = {}
var trophies := 0
var revives: Dictionary = {}
var _revive_used := false
var _revive_open := false
var achievements_done: Array = []
var _bets_won := 0
var _bets_lost := 0
var _help_from_pause := false
## Second wind: one comeback per run from the shop.
var _second_wind_used := false
var _second_wind_pending := false
var _vehicles_formed := 0
var weekly_results: Dictionary = {}
## While a finger is dragging the locker preview round, the idle turn waits.
var _preview_drag_until := 0.0
var _last_result := {}
## Character mode: heroes, outfits, hats, weapons, backs, paid in stars.
var wardrobe := Wardrobe.new()
## Difficulty modifier for the next run (the daily ignores it).
var modifier := "normal"
## Level grades this run, S to D, one per boss killed.
var grades: Array = []
var _level_gates := 0
var _level_perfect := 0
var _boss_start := 0.0
var _horde_warned := false
var character_mode := false
var _locker_tab := "hero"
var _preview: Node3D
var _preview_yaw := 0.0

var _frames := 0
var _smoke_frames := SMOKE_FRAMES
var _smoke_endless := false
var _smoke_daily := false
var _smoke_weekly := false
var _smoke_upgrades := false
var _shots_dir := ""
var _shots_quick := false
var _game_over_at := 0
var _game_over_frame := 0
var _smoke_retry := false
## --smoke-wipe-at=N: the bot loses its whole squad at frame N, so the
## results screen and the restart are exercised whatever the balance.
var _smoke_wipe_at := 0
var _warming := false
var _fps_frames := 0
var _fps_since := 0.0
var _crash_card_shown := false
## The learning round: lessons pop up once each, the first time a thing
## appears; LEARN starts a run where every lesson shows again.
var lessons_seen: Array = []
var lessons_on := true
var _learning := false
var _lesson_open := false
var _lesson_last := -100.0
var _vets_made := 0
var _smoke_retries := 0
var _shake := 0.0
var _drag_scale := 0.015
var _fov_tween: Tween
var _quitting := false
var _slowmo_until := 0.0
## Touch bookkeeping: index -> "focus" or "steer", decided by where the
## finger landed. The road (upper part of the screen) is for focus fire;
## the strip near the squad is for steering and flick-dashing.
var _touches: Dictionary = {}
## Touch index to the clinging zombie it is holding fire on.
var _cling_touch: Dictionary = {}
const FOCUS_ZONE := 0.62
## The screenshot walkthrough sets the spread by hand; the bot leaves it.
var _bot_spread := true


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	smoke = args.has("--smoke")
	_smoke_endless = args.has("--endless")
	_smoke_daily = args.has("--daily")
	_smoke_weekly = args.has("--weekly")
	# --smoke-upgrades: play with every shop upgrade maxed, to exercise them.
	_smoke_upgrades = args.has("--smoke-upgrades")
	# --smoke-retry: after a wipe, tap through the results and play again,
	# so the game-over screen and the restart run in CI too.
	_smoke_retry = args.has("--smoke-retry")
	if args.has("--hard"):
		modifier = "hard"
	elif args.has("--nightmare"):
		modifier = "nightmare"
	for a in args:
		if a.begins_with("--smoke-frames="):
			_smoke_frames = maxi(60, int(a.get_slice("=", 1)))
		elif a.begins_with("--smoke-seed="):
			_smoke_seed = int(a.get_slice("=", 1))
		elif a.begins_with("--smoke-wipe-at="):
			_smoke_wipe_at = int(a.get_slice("=", 1))
		elif a.begins_with("--shots="):
			_shots_dir = a.get_slice("=", 1)
		elif a == "--shots-quick":
			_shots_quick = true
	modifier = SaveData.load_modifier()
	trophies = SaveData.load_trophies()
	revives = SaveData.load_revives()
	lessons_seen = SaveData.load_lessons_seen()
	lessons_on = SaveData.load_lessons_on()
	if modifier != "normal" and not _feature_open(modifier):
		modifier = "normal"
	_load_bests()
	if smoke:
		modifier = "hard" if args.has("--hard") else ("nightmare" if args.has("--nightmare") else "normal")
	coins = SaveData.load_coins()
	meta.levels = SaveData.load_upgrades()
	if _smoke_upgrades:
		for id in Meta.ORDER:
			meta.levels[id] = Meta.max_level(id)
	squad_type = SaveData.load_squad_type()
	if not meta.squad_unlocked(squad_type):
		squad_type = "rifle"
	daily_day = Daily.day_number(int(Time.get_unix_time_from_system()))
	daily_results = Daily.prune(SaveData.load_daily(), daily_day)
	week_number = Daily.week_number(int(Time.get_unix_time_from_system()))
	weekly_results = Daily.prune_weeks(SaveData.load_weekly(), week_number)
	wardrobe.from_dict(SaveData.load_wardrobe())
	stats = SaveData.load_stats()
	# Saves older than the lifetime stats still know how many runs they played.
	stats.runs = maxi(int(stats.get("runs", 0)), SaveData.load_runs())
	achievements_done = SaveData.load_achievements()
	quest_state = SaveData.load_quests()
	season_state = SaveData.load_season()
	# The auto-player dresses up so the character code runs in CI too.
	character_mode = SaveData.load_character_mode() or smoke
	# Headless CI has no audio device; the dummy driver releases playbacks
	# on its own thread and can report them as leaked at exit. Keep the
	# auto-player silent so its exit is deterministic.
	Sfx.enabled = SaveData.load_sound_on() and not smoke
	Sfx.music_on = SaveData.load_music_on()
	var t_boot := Time.get_ticks_msec()
	_build_scene()
	Diag.note("boot_scene", {"ms": Time.get_ticks_msec() - t_boot})
	_drag_scale = (squad.road_half * 2.0) / (get_viewport().get_visible_rect().size.x * 0.5)
	hud.set_sound(Sfx.enabled)
	hud.set_music(Sfx.music_on)
	hud.set_characters(character_mode)
	hud.set_shadows(SaveData.load_shadows_on())
	hud.set_safe_graphics(SaveData.load_safe_graphics())
	hud.set_lessons(lessons_on)
	_apply_graphics(SaveData.load_safe_graphics())
	_apply_looks()
	Diag.note("ready", {"smoke": smoke, "character_mode": character_mode})
	if not smoke:
		await _warm_up()
	show_title()
	if smoke:
		start_run("weekly" if _smoke_weekly else ("daily" if _smoke_daily else ("endless" if _smoke_endless else "levels")))
	elif _shots_dir != "":
		_shots_walkthrough()


## The look: a late-afternoon sky, a warm key light with shadows, a cool
## fill, filmic tonemapping, a little glow on the things that give off
## light, and fog that eats the horizon. All of it runs on the mobile
## Compatibility renderer.
func _build_scene() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.18, 0.28, 0.48)
	sky_mat.sky_horizon_color = Color(0.72, 0.62, 0.58)
	sky_mat.sky_curve = 0.18
	sky_mat.ground_bottom_color = Color(0.12, 0.11, 0.1)
	sky_mat.ground_horizon_color = Color(0.5, 0.42, 0.36)
	sky_mat.sun_angle_max = 20.0
	sky_mat.sun_curve = 0.12
	var sky := Sky.new()
	sky.sky_material = sky_mat
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.9
	e.ambient_light_sky_contribution = 0.8
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 1.05
	e.tonemap_white = 6.0
	e.glow_enabled = true
	e.glow_intensity = 0.45
	e.glow_bloom = 0.04
	e.glow_hdr_threshold = 1.0
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	e.adjustment_enabled = true
	e.adjustment_contrast = 1.05
	e.adjustment_saturation = 1.08
	# Fog only takes the far distance, in the sky's own haze colour.
	e.fog_enabled = true
	e.fog_light_color = Color(0.66, 0.6, 0.6)
	e.fog_density = 0.0055
	e.fog_sky_affect = 0.15
	env.environment = e
	_env = e
	add_child(env)

	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-52.0, 34.0, 0.0)
	_sun.light_color = Color(1.0, 0.92, 0.8)
	_sun.light_energy = 1.35
	_sun.shadow_enabled = SaveData.load_shadows_on() and not smoke
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	_sun.directional_shadow_max_distance = 70.0
	_sun.shadow_bias = 0.06
	_sun.shadow_normal_bias = 2.0
	_sun.shadow_opacity = 0.7
	add_child(_sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-30.0, -140.0, 0.0)
	fill.light_color = Color(0.55, 0.65, 0.9)
	fill.light_energy = 0.35
	add_child(fill)

	# The camera rides a rig: the rig sways with the steering and leans
	# into it, the camera keeps its framing.
	_cam_rig = Node3D.new()
	add_child(_cam_rig)
	camera = Camera3D.new()
	camera.position = Vector3(0.0, 11.0, 9.0)
	camera.fov = 55.0
	_cam_rig.add_child(camera)
	camera.look_at(Vector3(0.0, 0.0, -7.0))
	camera.current = true

	sfx = Sfx.new()
	add_child(sfx)

	world = World.new()
	world.meta = meta
	add_child(world)
	world.gate_passed.connect(_on_gate_passed)
	world.gate_robbed.connect(_on_gate_robbed)
	world.spit_landed.connect(_on_spit_landed)
	world.gate_stepped.connect(_on_gate_stepped)
	world.zombie_killed.connect(_on_zombie_killed)
	world.squad_bitten.connect(_on_squad_bitten)
	world.boss_spawned.connect(_on_boss_spawned)
	world.boss_hit.connect(_on_boss_hit)
	world.boss_killed.connect(_on_boss_killed)
	world.level_started.connect(_on_level_started)
	world.perk_chosen.connect(_on_perk_chosen)
	world.wave_cleared.connect(_on_wave_cleared)
	world.gate_perfect.connect(_on_gate_perfect)
	world.powerup_granted.connect(_on_powerup_granted)
	world.shield_blocked.connect(_on_shield_blocked)
	world.bomb_exploded.connect(_on_bomb_exploded)
	world.fork_ahead.connect(_on_fork_ahead)
	world.fork_chosen.connect(_on_fork_chosen)
	world.fork_merged.connect(_on_fork_merged)
	world.dodged.connect(_on_dodged)
	world.latched.connect(_on_latched)
	world.strike_landed.connect(_on_strike_landed)
	world.shaken_off.connect(_on_shaken_off)
	world.lanes_changed.connect(_on_lanes_changed)
	world.bet_placed.connect(_on_bet_placed)
	world.vehicle_formed.connect(_on_vehicle_formed)
	world.shell_exploded.connect(_on_shell_exploded)
	world.scouts_sent.connect(func(n: int) -> void:
		hud.show_banner("SCOUTS OUT\nNEXT %d GATES REVEALED" % n, 1.4)
		sfx.play("powerup", -4.0, 1.4))
	world.bet_resolved.connect(_on_bet_resolved)
	world.saw_spawned.connect(func() -> void:
		hud.show_float("SAW AHEAD", false)
		sfx.play("boss_roar", -12.0, 2.2))
	world.saw_hit.connect(_on_saw_hit)
	world.foreman_threw.connect(func(what: String) -> void:
		if smoke:
			print("SMOKE_FOREMAN ", JSON.stringify({"what": what, "level": world.level, "frame": _frames}))
		sfx.play("throw" if what == "saw" else "crate", -4.0, 0.8)
		if what == "saw":
			hud.show_float("SAW!", false))
	world.perk_felt.connect(_on_perk_felt)
	world.supply_bought.connect(_on_supply_bought)
	world.supply_refused.connect(func(cost: int) -> void:
		hud.show_float("NEED %d COINS" % cost, false)
		sfx.play("gate_bad", -4.0))
	world.horde_bit.connect(_on_horde_bit)
	world.boss_engaged.connect(func() -> void: _boss_start = _run_time)
	world.powerups = powerups

	squad = Squad.new()
	squad.world = world
	squad.meta = meta
	squad.powerups = powerups
	world.squad = squad
	add_child(squad)
	squad.count_changed.connect(_on_count_changed)
	squad.wiped_out.connect(_on_wiped_out)
	squad.dashed.connect(func() -> void: world.shake_off())
	squad.vehicle_lost.connect(_on_vehicle_lost)
	squad.vehicle_ranked.connect(func(id: String, r: int) -> void:
		hud.show_banner("%s  RANK %d" % [Convoy.title(id), r], 1.2)
		sfx.play("level_clear", -8.0, 1.3)
		if smoke:
			print("SMOKE_RANK ", JSON.stringify({"id": id, "rank": r, "level": world.level, "frame": _frames})))
	squad.reset()

	# A soft vignette under the HUD: the eye goes to the middle of the road.
	var vignette_layer := CanvasLayer.new()
	vignette_layer.layer = 0
	add_child(vignette_layer)
	var vignette := ColorRect.new()
	_vignette = vignette
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = "shader_type canvas_item; void fragment() { vec2 d = UV - vec2(0.5); float v = smoothstep(0.42, 0.95, length(d * vec2(1.0, 1.25))); COLOR = vec4(0.02, 0.02, 0.05, v * 0.55); }"
	var sm := ShaderMaterial.new()
	sm.shader = sh
	vignette.material = sm
	vignette_layer.add_child(vignette)

	hud = Hud.new()
	add_child(hud)
	hud.play_pressed.connect(start_run)
	hud.shop_opened.connect(open_shop)
	hud.daily_opened.connect(open_daily)
	hud.copy_pressed.connect(copy_result)
	hud.shop_closed.connect(show_title)
	hud.buy_pressed.connect(buy_upgrade)
	hud.squad_toggled.connect(toggle_squad)
	hud.mode_pressed.connect(cycle_mode)
	hud.menu_pressed.connect(show_title)
	hud.pause_pressed.connect(pause_game)
	hud.resume_pressed.connect(resume_game)
	hud.quit_pressed.connect(quit_to_title)
	hud.sound_toggled.connect(_on_sound_toggled)
	hud.music_toggled.connect(_on_music_toggled)
	hud.formation_pressed.connect(cycle_formation)
	hud.bomb_pressed.connect(throw_bomb)
	hud.settings_opened.connect(open_settings)
	hud.records_opened.connect(open_records)
	hud.quests_opened.connect(open_quests)
	hud.road_opened.connect(open_road)
	hud.revive_accepted.connect(_on_revive_accepted)
	hud.revive_declined.connect(_on_revive_declined)
	hud.help_opened.connect(open_help)
	hud.help_closed.connect(close_help)
	hud.settings_closed.connect(show_title)
	hud.characters_toggled.connect(_on_characters_toggled)
	hud.shadows_toggled.connect(func(on: bool) -> void:
		_sun.shadow_enabled = on and not SaveData.load_safe_graphics()
		SaveData.save_shadows_on(on)
		Diag.note("shadows", {"on": on})
		sfx.play("click"))
	hud.safe_graphics_toggled.connect(func(on: bool) -> void:
		SaveData.save_safe_graphics(on)
		_apply_graphics(on)
		Diag.note("safe_graphics", {"on": on})
		sfx.play("click"))
	hud.report_pressed.connect(_send_report)
	hud.lesson_closed.connect(_close_lesson)
	hud.learn_pressed.connect(start_learning_round)
	hud.lessons_toggled.connect(func(on: bool) -> void:
		lessons_on = on
		SaveData.save_lessons_on(on)
		sfx.play("click"))
	hud.crash_dismissed.connect(func() -> void:
		hud.hide_crash_card()
		sfx.play("click"))
	hud.locker_opened.connect(open_locker)
	hud.locker_closed.connect(close_locker)
	hud.locker_tab.connect(_on_locker_tab)
	hud.item_pressed.connect(_on_item_pressed)


# --- menus -----------------------------------------------------------------

# --- lessons ---------------------------------------------------------------

## LEARN on the title: a normal run where every lesson pops up again.
func start_learning_round() -> void:
	sfx.play("click")
	_learning = true
	start_run("levels")
	hud.toast("Learning round: every lesson pops up as it comes")


## Show [param id] now if it is due: the road pauses under the card.
func _teach(id: String, body_override: String = "") -> bool:
	if smoke or _lesson_open or state != State.RUNNING or get_tree().paused:
		return false
	var since := Time.get_ticks_msec() * 0.001 - _lesson_last
	if not Lessons.due(id, lessons_seen, lessons_on, _learning, since):
		return false
	lessons_seen = Lessons.mark_seen(lessons_seen, id)
	SaveData.save_lessons_seen(lessons_seen)
	_lesson_open = true
	Engine.time_scale = 1.0
	_slowmo_until = 0.0
	get_tree().paused = true
	Diag.set_state("lesson")
	Diag.note("lesson", {"id": id})
	hud.show_lesson(Lessons.title(id), body_override if body_override != "" else Lessons.body(id))
	sfx.play("click", -4.0, 1.2)
	return true


func _close_lesson() -> void:
	if not _lesson_open:
		return
	_lesson_open = false
	_lesson_last = Time.get_ticks_msec() * 0.001
	hud.hide_lesson()
	get_tree().paused = false
	Diag.set_state("running")
	sfx.play("click")


## What is coming down the road that the player has not met yet.
func _check_lessons() -> void:
	if smoke or _lesson_open or not lessons_on and not _learning:
		return
	if gates_passed == 0 and _run_time < 0.5:
		if _teach("basics"):
			return
	if squad.count >= 12 and _teach("fire_modes"):
		return
	if kills >= 10 and _teach("bounty"):
		return
	var g := world.nearest_upcoming_gate()
	if g != null and g.position.z > -26.0:
		if gates_passed == 0 and _teach("shoot_panels"):
			return
		for panel in g.panels:
			var id := ""
			if not panel.revealed:
				id = "hidden"
			elif GateMath.is_expr(panel):
				id = "expr"
			elif GateMath.is_deal(panel):
				id = "deal"
			elif GateMath.is_supply(panel):
				id = "supply"
			elif GateMath.is_vehicle(panel):
				id = "vehicle"
			if id != "" and _teach(id):
				return
	var pg := world.nearest_upcoming_perk_gate()
	if pg != null and pg.position.z > -28.0 and _teach("perk", Lessons.perk_body(pg.ids)):
		return
	if world.fork != null and not world.fork.chosen and world.fork.position.z > -34.0 and _teach("fork"):
		return
	var saw := world.nearest_saw(26.0)
	if saw != null and _teach("saw"):
		return


## The warm-up. Phones compile every shader the first time it is drawn,
## so the first zombie, boss, vehicle and particle each used to cost a
## stutter, and the first screens hitched on the glyph caches. Under a
## loading screen, draw one of everything for a few frames, then free it.
func _warm_up() -> void:
	_warming = true
	Diag.set_state("warm_up")
	var t0 := Time.get_ticks_msec()
	hud.show_loading(true)
	hud.warm_fonts()
	var warm := Node3D.new()
	warm.position = Vector3(0.0, 0.0, -26.0)
	add_child(warm)
	var x := -7.0
	for k in Zombie.Kind.values():
		var zb := Zombie.new()
		zb.setup(10.0, 0.0, k)
		zb.position = Vector3(x, 0.0, 0.0)
		warm.add_child(zb)
		x += 1.4
	x = -6.0
	for k in Boss.Kind.values():
		var b := Boss.new()
		b.setup(100.0, k)
		b.position = Vector3(x, 0.0, -6.0)
		warm.add_child(b)
		x += 5.0
	x = -6.0
	for id in Convoy.SPECS:
		var v := Vehicle.new(id)
		v.position = Vector3(x, 0.0, 4.0)
		v.target_offset = v.position
		warm.add_child(v)
		x += 3.5
	for i in range(3):
		var s := Soldier.new(i < 2, ["rifle", "shotgun", "medic"][i], wardrobe.look() if i == 0 else {})
		s.position = Vector3(-2.0 + float(i) * 2.0, 0.0, 7.0)
		warm.add_child(s)
	var g := Gate.new()
	g.setup([GateMath.add(5), GateMath.mul(2.0), GateMath.add(-3, true), GateMath.power("bomb"), GateMath.vehicle("jeep")])
	g.position = Vector3(0.0, 0.0, -10.0)
	warm.add_child(g)
	var pg := PerkGate.new()
	pg.setup(["rapid", "skin", "greed"], 3.0)
	pg.position = Vector3(0.0, 0.0, -14.0)
	warm.add_child(pg)
	var rg := RouteGate.new()
	rg.setup(GateMath.add(4), -1, 3.3)
	rg.position = Vector3(0.0, 0.0, -18.0)
	warm.add_child(rg)
	var c := Crate.new()
	c.setup("bomb")
	c.position = Vector3(3.0, 0.0, 2.0)
	warm.add_child(c)
	var st := Strike.new()
	st.setup(-3.0)
	warm.add_child(st)
	var sp := Spit.new()
	warm.add_child(sp)
	sp.launch(Vector3(0.0, 3.0, -8.0), 1.0, warm)
	var sh := Shell.new()
	sh.position = Vector3(2.0, 0.6, 0.0)
	warm.add_child(sh)
	var bm := Bomb.new()
	bm.launch(Vector3(-2.0, 1.0, 0.0))
	warm.add_child(bm)
	for args in [[1.0, Bullet.COLOR, 0.7], [0.8, Color(1.0, 0.35, 0.3), 2.4]]:
		var bl := Bullet.new(args[0], args[1], args[2])
		bl.position = Vector3(0.0, 0.8, 0.0)
		warm.add_child(bl)
	var at := warm.position + Vector3(0.0, 1.0, 0.0)
	Fx.blood(warm, at, true)
	Fx.dust(warm, at, 6)
	Fx.sparks(warm, at, 6)
	Fx.smoke(warm, at, 4)
	Fx.trail(warm, Vector3.ZERO)
	Burst.spawn(warm, at, Color(1.0, 0.6, 0.15), 6, 0.14, 2.0, 1.0)
	for i in range(4):
		await get_tree().process_frame
	warm.queue_free()
	hud.end_font_warm()
	await get_tree().process_frame
	hud.show_loading(false)
	_warming = false
	_fps_frames = 0
	_fps_since = Time.get_ticks_msec() * 0.001
	Diag.note("warm_up", {"ms": Time.get_ticks_msec() - t0})


## The watchdog: a phone that cannot hold the frame rate gets the safe
## renderer, once, and is told.
func _watch_fps() -> void:
	if smoke or _warming or _shots_dir != "" or get_tree().paused:
		return
	_fps_frames += 1
	var now := Time.get_ticks_msec() * 0.001
	var seconds := now - _fps_since
	if seconds < Perf.SAMPLE_SECONDS:
		return
	var avg := Perf.average_fps(_fps_frames, seconds)
	if avg < 40.0:
		Diag.note("fps_low", {"avg": snappedf(avg, 0.1), "state": State.keys()[state]})
	if Perf.should_degrade(avg, seconds, SaveData.load_safe_graphics(), SaveData.load_auto_safe_done()):
		SaveData.save_safe_graphics(true)
		SaveData.save_auto_safe_done(true)
		hud.set_safe_graphics(true)
		_apply_graphics(true)
		hud.toast(Perf.notice())
		Diag.note("auto_safe_graphics", {"avg": snappedf(avg, 0.1)})
	_fps_frames = 0
	_fps_since = now


## Safe graphics: the plain renderer for phones whose drivers choke on
## the extras. No glow, no fog, no shadows, no anti-aliasing, no vignette.
func _apply_graphics(safe: bool) -> void:
	if _env != null:
		_env.glow_enabled = not safe
		_env.fog_enabled = not safe
		_env.adjustment_enabled = not safe
	if _sun != null:
		_sun.shadow_enabled = SaveData.load_shadows_on() and not smoke and not safe
	if _vignette != null:
		_vignette.visible = not safe
	get_viewport().msaa_3d = Viewport.MSAA_DISABLED if safe else Viewport.MSAA_2X


## What the report says about this save: enough to reproduce, no secrets.
func _save_summary() -> Dictionary:
	return {
		"runs": int(stats.get("runs", 0)), "best_level": SaveData.load_best_level("normal"),
		"coins": coins, "stars": wardrobe.stars, "trophies": trophies, "modifier": modifier,
		"character_mode": character_mode, "upgrades": meta.levels, "squad_type": squad_type,
		"mode": mode, "state": State.keys()[state], "last_result": _last_result,
	}


func _send_report(note: String) -> void:
	sfx.play("click")
	var ok := Diag.send(_save_summary(), note)
	hud.show_banner("REPORT COPIED\nOPENING MAIL..." if ok else "REPORT COPIED TO CLIPBOARD\nNO MAIL APP FOUND", 2.2)


func show_title() -> void:
	state = State.TITLE
	Diag.set_state("title")
	sfx.set_music("calm")
	# A daily or weekly forces rifles; the title squad shows the real pick.
	if squad.squad_type != squad_type:
		squad.squad_type = squad_type
		_apply_looks()
	var hint := ""
	if modifier == "normal" and not _feature_open("hard"):
		hint = "Hard mode opens at %d trophies" % int(Road.UNLOCKS["hard"])
	elif modifier == "hard" and not _feature_open("nightmare"):
		hint = "Nightmare opens at %d trophies" % int(Road.UNLOCKS["nightmare"])
	var runs := int(stats.get("runs", 0))
	var goal := Goals.next(_goal_context())
	if Diag.had_bad_exit() and runs > 0:
		goal = "The game stopped suddenly last time. SETTINGS has a REPORT A BUG button that emails the details."
	if Diag.had_bad_exit() and runs > 0 and not _crash_card_shown and not smoke and _shots_dir == "":
		_crash_card_shown = true
		call_deferred("_offer_crash_report")
	hud.show_title({
		"goal": goal,
		"buttons": _title_buttons(runs),
		"trophies": trophies,
		"best": best, "best_level": best_level, "best_endless": best_endless, "coins": coins,
		"endless_unlocked": _feature_open("endless"), "squad_type": squad_type,
		"shotgun_unlocked": meta.shotgun_unlocked() or meta.squad_unlocked("medic"),
		"stars": wardrobe.stars, "hero_name": wardrobe.hero_name() if character_mode else "",
		"modifier": modifier, "mode_hint": hint,
	})


func _offer_crash_report() -> void:
	if state == State.TITLE:
		hud.show_crash_card()


func _quests_left() -> int:
	var day := Daily.day_number(int(Time.get_unix_time_from_system()))
	var n := 0
	for q in Quests.rows(quest_state, day):
		if not q.done:
			n += 1
	return n


## What Goals needs to name the next thing to do.
func _goal_context() -> Dictionary:
	var cheapest := ""
	var cheapest_cost := 0
	for id in Meta.ORDER:
		if meta.is_maxed(id):
			continue
		var c := meta.cost(id)
		if cheapest == "" or c < cheapest_cost:
			cheapest = Meta.title(id)
			cheapest_cost = c
	return {
		"runs": int(stats.get("runs", 0)), "best_level": SaveData.load_best_level("normal"),
		"hard_best_level": SaveData.load_best_level("hard"), "coins": coins,
		"cheapest": cheapest, "cheapest_cost": cheapest_cost, "vehicles": int(stats.get("vehicles", 0)),
		"modifier": modifier, "character_mode": character_mode,
		"affordable_item": wardrobe.can_afford_something(),
		"daily_played": daily_results.has(Daily.day_number(int(Time.get_unix_time_from_system()))),
		"quests_left": _quests_left(),
		"trophies": trophies,
		"trophies_to_next": Road.next_milestone(trophies) - trophies,
		"hard_open": _feature_open("hard"),
		"best_score": best,
	}


## A feature is open once the road reaches it, or by the older level rule,
## so nobody who already had it loses it.
func _feature_open(feature: String) -> bool:
	if Road.is_unlocked(feature, trophies):
		return true
	var normal_level := SaveData.load_best_level("normal")
	var hard_level := SaveData.load_best_level("hard")
	match feature:
		"endless":
			return Meta.endless_unlocked(normal_level)
		"hard", "nightmare":
			return Modifiers.unlocked(feature, normal_level, hard_level)
		"weekly":
			return int(stats.get("weeklies", 0)) > 0
	return true


func _title_buttons(runs: int) -> Dictionary:
	var b := Goals.title_buttons(runs, _feature_open("hard"), character_mode)
	b.weekly = bool(b.get("weekly", false)) and _feature_open("weekly")
	return b


func open_road() -> void:
	sfx.play("click")
	var unlocks := {}
	for feature in Road.UNLOCKS:
		unlocks[feature] = _feature_open(feature)
	hud.show_road(trophies, Road.rows(trophies), unlocks)


func _load_bests() -> void:
	best = SaveData.load_best(modifier)
	best_level = SaveData.load_best_level(modifier)
	best_endless = SaveData.load_best_endless(modifier)


func cycle_mode() -> void:
	var i := Modifiers.ORDER.find(modifier)
	for k in range(1, Modifiers.ORDER.size() + 1):
		var cand: String = Modifiers.ORDER[(i + k) % Modifiers.ORDER.size()]
		if cand == "normal" or _feature_open(cand):
			modifier = cand
			break
	SaveData.save_modifier(modifier)
	_load_bests()
	sfx.play("click")
	show_title()
	if modifier != "normal":
		hud.toast(Modifiers.blurb(modifier))


func open_quests() -> void:
	sfx.play("click")
	var day := Daily.day_number(int(Time.get_unix_time_from_system()))
	hud.show_quests(day, Quests.rows(quest_state, day), Season.number(day), season_state if int(season_state.get("season", -1)) == Season.number(day) else Season.blank(Season.number(day)))


func open_records() -> void:
	sfx.play("click")
	hud.show_records(stats, Achievements.rows(stats, achievements_done))


func open_help() -> void:
	sfx.play("click")
	_help_from_pause = state == State.RUNNING and get_tree().paused
	hud.show_help()


func close_help() -> void:
	sfx.play("click")
	if _help_from_pause:
		hud.show_paused(true)
	else:
		show_title()


func open_settings() -> void:
	sfx.play("click")
	hud.show_settings()


func _on_characters_toggled(on: bool) -> void:
	character_mode = on
	SaveData.save_character_mode(on)
	sfx.play("click")
	_apply_looks()


## Dress the squad for the mode: the hero and crew from the locker, or
## the classic kit.
func _apply_looks() -> void:
	if character_mode:
		squad.set_looks(wardrobe.look(), wardrobe.crew_look())
	else:
		squad.set_looks({}, {})


# --- locker ----------------------------------------------------------------

func open_locker() -> void:
	sfx.play("click")
	_show_locker()


func _show_locker() -> void:
	hud.show_locker(wardrobe, _locker_tab)
	# The title-screen squad would show through the card: hide it.
	squad.visible = false
	_refresh_preview()


func close_locker() -> void:
	sfx.play("click")
	_drop_preview()
	squad.visible = true
	SaveData.save_wardrobe(wardrobe.to_dict())
	_apply_looks()
	show_title()
	squad.cheer()


func _on_locker_tab(cat: String) -> void:
	_locker_tab = cat
	sfx.play("click")
	_show_locker()


func _on_item_pressed(id: String) -> void:
	var what := wardrobe.tap(id)
	if what == "bought":
		sfx.play("gate_good", -4.0)
		hud.toast("%s UNLOCKED" % Wardrobe.title(id))
		SaveData.save_wardrobe(wardrobe.to_dict())
	elif what == "equipped":
		sfx.play("click")
	_show_locker()
	if what != "" and _preview != null and _preview.get_child_count() > 0:
		_preview.get_child(0).cheer()


## A big hero stands in front of the camera above the locker, slowly
## turning, wearing whatever is picked right now.
func _refresh_preview() -> void:
	_drop_preview()
	# A holder node carries the spot; the soldier inside keeps its own
	# bob and recoil relative to it.
	_preview = Node3D.new()
	add_child(_preview)
	var size := get_viewport().get_visible_rect().size
	var spot := camera.project_position(Vector2(size.x * 0.5, size.y * 0.2), 6.5)
	_preview.position = spot - Vector3(0.0, 0.95, 0.0)
	_preview.scale = Vector3.ONE * 1.25
	_preview.look_at(camera.global_position, Vector3.UP)
	_preview_yaw = _preview.rotation.y
	_preview.rotation = Vector3(0.0, _preview_yaw, 0.0)
	_preview.add_child(Soldier.new(true, squad_type, wardrobe.look()))


func _drop_preview() -> void:
	if _preview != null:
		_preview.queue_free()
		_preview = null


func open_daily() -> void:
	sfx.play("click")
	daily_day = Daily.day_number(int(Time.get_unix_time_from_system()))
	daily_results = Daily.prune(daily_results, daily_day)
	week_number = Daily.week_number(int(Time.get_unix_time_from_system()))
	weekly_results = Daily.prune_weeks(weekly_results, week_number)
	hud.show_daily(daily_day, daily_results, week_number, weekly_results)


## Put the last result (or today's daily best) on the clipboard.
func copy_result() -> void:
	var text := ""
	if state == State.GAME_OVER and not _last_result.is_empty():
		text = _result_text(_last_result)
	elif daily_results.has(daily_day):
		var r: Dictionary = daily_results[daily_day]
		text = Daily.share_text(daily_day, int(r.score), int(r.level), int(r.kills), int(r.peak))
	elif weekly_results.has(week_number):
		var r: Dictionary = weekly_results[week_number]
		text = Daily.week_share_text(week_number, int(r.score), int(r.level), int(r.kills), int(r.peak))
	if text == "":
		hud.toast("Nothing to copy yet")
		return
	DisplayServer.clipboard_set(text)
	hud.toast("Copied!")
	sfx.play("click")


func _result_text(r: Dictionary) -> String:
	match r.mode:
		"daily":
			return Daily.share_text(daily_day, r.score, r.level, r.kills, r.peak)
		"weekly":
			return Daily.week_share_text(week_number, r.score, r.level, r.kills, r.peak)
		"endless":
			return "Shooty McBridgeface endless\nScore %d · %d m · %d kills · peak squad %d\nhttps://github.com/Reconnaishawnce/shootymcbridgeface" % [r.score, r.distance, r.kills, r.peak]
	var who := " as %s" % wardrobe.hero_name().capitalize() if character_mode else ""
	var how := "" if str(r.get("modifier", "normal")) == "normal" else " · %s" % Modifiers.title(str(r.modifier)).capitalize()
	var g := "" if str(r.get("grades", "")) == "" else "\nGrades %s" % r.grades
	return "Shooty McBridgeface%s%s\nScore %d · level %d · %d kills · peak squad %d%s\nhttps://github.com/Reconnaishawnce/shootymcbridgeface" % [who, how, r.score, r.level, r.kills, r.peak, g]


func open_shop() -> void:
	sfx.play("click")
	hud.show_shop(meta, coins)


func buy_upgrade(id: String) -> void:
	var left := meta.buy(id, coins)
	if left == coins:
		return
	coins = left
	SaveData.save_coins(coins)
	SaveData.save_upgrades(meta.levels)
	sfx.play("gate_good", -4.0)
	hud.show_shop(meta, coins)


func toggle_squad() -> void:
	squad_type = meta.next_squad(squad_type)
	SaveData.save_squad_type(squad_type)
	sfx.play("click")
	show_title()


# --- run lifecycle ---------------------------------------------------------

func start_run(p_mode: String = "levels") -> void:
	mode = p_mode
	run_seed = _smoke_seed if smoke else randi()
	# The daily: one seed for everyone, no upgrades, rifles.
	run_meta = Meta.new() if mode in ["daily", "weekly"] else meta
	if mode == "daily":
		daily_day = Daily.day_number(int(Time.get_unix_time_from_system()))
		run_seed = Daily.seed_for_day(daily_day)
	elif mode == "weekly":
		week_number = Daily.week_number(int(Time.get_unix_time_from_system()))
		run_seed = Daily.seed_for_week(week_number)
	squad.meta = run_meta
	world.meta = run_meta
	# The bot's runs repeat: the same seed gives the same road and the
	# same dice, so a soak failure can be run again.
	if smoke:
		seed(run_seed)
	total_distance = 0.0
	kills = 0
	bounty = 0
	score = 0
	bonus = 0
	peak_squad = 1
	gates_passed = 0
	bosses_killed = 0
	_shake = 0.0
	perks = Perks.new()
	combo.reset()
	powerups.reset()
	for i in range(run_meta.start_bombs()):
		powerups.grant("bomb", 0.0)
	hud.set_bombs(powerups.bombs)
	_second_wind_used = false
	_revive_used = false
	_revive_open = false
	_second_wind_pending = false
	_lesson_open = false
	_lesson_last = -100.0
	_vets_made = 0
	_vehicles_formed = 0
	waves_cleared = 0
	perfect_gates = 0
	_run_time = 0.0
	_level_peak = 1
	Engine.time_scale = 1.0
	_slowmo_until = 0.0
	squad.perks = perks
	squad.squad_type = "rifle" if mode in ["daily", "weekly"] else squad_type
	_drop_preview()
	squad.visible = true
	_apply_looks()
	world.perks = perks
	world.perk_count = 0
	world.endless = mode == "endless"
	world.modifier = "normal" if mode == "daily" else (Daily.WEEKLY_MODIFIER if mode == "weekly" else modifier)
	grades = []
	_bets_won = 0
	_bets_lost = 0
	_level_gates = 0
	_level_perfect = 0
	_boss_start = 0.0
	_horde_warned = false
	squad.now = 0.0
	world.now = 0.0
	squad.reset(run_meta.start_squad())
	# Reset before RUNNING: a road snapping back to two lanes must not
	# banner, chime or glide the camera like a mid-run widening.
	world.reset(run_seed)
	state = State.RUNNING
	Diag.set_state("running")
	Diag.note("start_run", {"mode": mode, "modifier": modifier, "seed": run_seed, "squad_type": squad_type})
	squad.active = true
	if mode != "levels":
		_learning = false
	hud.show_running()
	hud.set_formation(squad.formation_name())
	hud.update_stats(squad.count, world.level, total_distance, score)
	hud.set_bounty(0)
	world.supply_funds = 0
	hud.set_perks("")
	hud.show_hint(Progression.hint_for(1), 4.0)
	if character_mode:
		hud.toast("%s: %s" % [wardrobe.hero_name(), Wardrobe.hero_line(wardrobe.equipped.get("hero", "max"))])
	_touches.clear()
	_cling_touch.clear()
	squad.clear_focus()
	sfx.play("spawn")
	sfx.set_music("tense" if mode == "endless" else "calm")


func end_run() -> void:
	if state != State.RUNNING:
		return
	state = State.GAME_OVER
	_learning = false
	Diag.set_state("game_over")
	var t0 := Time.get_ticks_msec()
	squad.active = false
	world.frozen = true
	Engine.time_scale = 1.0
	_slowmo_until = 0.0
	hud.set_combo(0, 1.0, 0.0)
	hud.set_danger(0.0)
	sfx.set_music("")
	_game_over_at = Time.get_ticks_msec()
	_game_over_frame = _frames
	Diag.mark("end_run:records")
	var earned := 0 if mode in ["daily", "weekly"] else int(round(float(Meta.coins_for_run(bounty, bosses_killed, gates_passed)) * perks.coin_mult() * meta.coin_mult() * world.mod("coins") * squad.veterans.coin_mult()))
	_last_result = {"mode": mode, "score": score, "level": world.level, "distance": int(total_distance), "kills": kills, "peak": peak_squad, "grades": " ".join(grades), "modifier": world.modifier}
	# The auto-player must not pollute a real player's records or wallet.
	var records := {"new_best_score": false, "new_best_level": false, "new_best_endless": false}
	var is_best := false
	var shown_best := best
	if mode == "daily":
		var prev := int(daily_results.get(daily_day, {}).get("score", 0))
		if not smoke:
			var out := Daily.record(daily_results, daily_day, score, world.level, kills, peak_squad)
			daily_results = out.results
			is_best = out.new_best
			SaveData.save_daily(daily_results)
			SaveData.count_run()
		shown_best = maxi(prev, score)
	elif mode == "weekly":
		var prev := int(weekly_results.get(week_number, {}).get("score", 0))
		if not smoke:
			var out := Daily.record(weekly_results, week_number, score, world.level, kills, peak_squad)
			weekly_results = out.results
			is_best = out.new_best
			SaveData.save_weekly(weekly_results)
			SaveData.count_run()
		shown_best = maxi(prev, score)
	else:
		if not smoke:
			records = SaveData.record_run(score, world.level, world.endless, modifier)
			coins = SaveData.add_coins(earned)
		if records.new_best_score:
			best = score
		if records.new_best_level:
			best_level = world.level
		if records.new_best_endless:
			best_endless = score
		is_best = records.new_best_endless if world.endless else records.new_best_score
		shown_best = best_endless if world.endless else best
	var stars_earned := Wardrobe.stars_for_run(bosses_killed, perfect_gates, gates_passed, world.endless, mode == "daily")
	if stars_earned > 0 and bosses_killed > 0:
		stars_earned += int(world.mod("stars"))
	if mode == "weekly" and stars_earned > 0:
		stars_earned += 2
	# Lifetime numbers, then any achievement they complete. Achievements
	# pay stars once. The auto-player keeps its hands off the save.
	var s_count := 0
	for g in grades:
		if g == "S":
			s_count += 1
	var run_stats := {
		"runs": 1, "kills": kills, "bosses": bosses_killed, "gates": gates_passed, "perfect": perfect_gates,
		"distance": int(total_distance), "best_combo": combo.best, "bets_won": _bets_won, "bets_lost": _bets_lost,
		"dailies": 1 if mode == "daily" else 0, "weeklies": 1 if mode == "weekly" else 0,
		"hard_bosses": bosses_killed if world.modifier == "hard" else 0,
		"nightmare_bosses": bosses_killed if world.modifier == "nightmare" else 0,
		"s_grades": s_count, "stars_earned": stars_earned, "coins_earned": earned,
		"best_level": 0 if world.endless else world.level, "endless_level": world.level if world.endless else 0,
		"escapes": 1 if character_mode else 0, "vehicles": _vehicles_formed, "waves": waves_cleared,
		"veterans": _vets_made,
	}
	var new_achievements: Array = []
	var quests_done: Array = []
	var season_rewards: Array = []
	# Quests and the season run for the auto-player too (so the code is
	# exercised); only a real player's progress is kept.
	var day := Daily.day_number(int(Time.get_unix_time_from_system()))
	var qa := Quests.advance(quest_state, day, run_stats)
	quests_done = qa.completed
	if not quests_done.is_empty():
		var sa := Season.advance(season_state, Season.number(day), Quests.points_for(quests_done))
		season_rewards = sa.rewards
		if smoke:
			print("SMOKE_QUESTS ", JSON.stringify({"done": quests_done.size(), "rewards": season_rewards.size(), "frame": _frames}))
		else:
			season_state = sa.state
			SaveData.save_season(season_state)
			for rw in season_rewards:
				match str(rw.kind):
					"coins":
						coins = SaveData.add_coins(int(rw.amount))
					"stars":
						stars_earned += int(rw.amount)
					"item":
						if wardrobe.is_owned(str(rw.id)):
							# Already in the locker: its price in stars instead.
							rw.owned = true
							stars_earned += maxi(1, Wardrobe.cost(str(rw.id)))
						else:
							wardrobe.owned[str(rw.id)] = true
							SaveData.save_wardrobe(wardrobe.to_dict())
	Diag.mark("end_run:road")
	# The road: trophies for the run, milestones passed, rewards applied.
	var trophies_earned := Road.trophies_for_run(world.level, grades, world.modifier, world.endless)
	var road_rewards: Array = []
	if trophies_earned > 0:
		var ra := Road.advance(trophies, trophies_earned)
		road_rewards = ra.rewards
		if smoke:
			print("SMOKE_ROAD ", JSON.stringify({"earned": trophies_earned, "milestones": road_rewards.size(), "frame": _frames}))
		else:
			trophies = int(ra.trophies)
			SaveData.save_trophies(trophies)
			for rw in road_rewards:
				match str(rw.kind):
					"coins":
						coins = SaveData.add_coins(int(rw.amount))
					"stars":
						stars_earned += int(rw.amount)
					"item":
						if wardrobe.is_owned(str(rw.id)):
							rw.owned = true
							stars_earned += maxi(1, Wardrobe.cost(str(rw.id)))
						else:
							wardrobe.owned[str(rw.id)] = true
							SaveData.save_wardrobe(wardrobe.to_dict())
	# Stars from the season and the road count in the lifetime numbers too.
	run_stats.stars_earned = stars_earned
	Diag.mark("end_run:stats")
	if not smoke:
		quest_state = qa.state
		SaveData.save_quests(quest_state)
		stats = Stats.merge(stats, run_stats)
		new_achievements = Achievements.newly_done(stats, achievements_done)
		if not new_achievements.is_empty():
			achievements_done.append_array(new_achievements)
			stars_earned += Achievements.stars_for(new_achievements)
			SaveData.save_achievements(achievements_done)
			sfx.play("level_clear", -4.0, 1.2)
		stats.stars_earned = int(stats.stars_earned) + Achievements.stars_for(new_achievements)
		SaveData.save_stats(stats)
	if not smoke and stars_earned > 0:
		wardrobe.stars += stars_earned
		SaveData.save_wardrobe(wardrobe.to_dict())
	Diag.mark("end_run:card")
	hud.update_stats(squad.count, world.level, total_distance, score)
	hud.show_game_over({
		"score": score, "best": shown_best, "is_best": is_best, "level": world.level,
		"distance": int(total_distance), "kills": kills, "peak": peak_squad, "coins_earned": earned,
		"mode": mode, "stars_earned": stars_earned, "hero_name": wardrobe.hero_name() if character_mode else "",
		"locker_nudge": character_mode and wardrobe.can_afford_something(),
		"grades": " ".join(grades), "modifier": world.modifier, "achievements": new_achievements,
		"goal": Goals.next(_goal_context()), "quests_done": quests_done, "season_rewards": season_rewards,
		"trophies_earned": trophies_earned, "road_rewards": road_rewards,
	})
	Diag.note("end_run_done", {"ms": Time.get_ticks_msec() - t0, "level": world.level, "score": score, "mode": mode})
	Diag.mark("end_run:shown")
	if character_mode:
		squad.cheer()
	sfx.play("wipe")
	_shake = 1.0


func pause_game() -> void:
	if state != State.RUNNING or get_tree().paused:
		return
	get_tree().paused = true
	Diag.set_state("paused")
	hud.show_paused(true)
	sfx.play("click")


func resume_game() -> void:
	if not get_tree().paused:
		return
	get_tree().paused = false
	Diag.set_state("running")
	hud.show_paused(false)
	sfx.play("click")


func quit_to_title() -> void:
	get_tree().paused = false
	hud.show_paused(false)
	if state == State.RUNNING:
		# Leaving mid-run still counts: the score and coins stand.
		end_run()
	show_title()
	sfx.play("click")


func _notification(what: int) -> void:
	# Phone went to the home screen, or the back button was pressed.
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if state == State.RUNNING and not get_tree().paused:
			pause_game()


# --- frame -----------------------------------------------------------------

func _process(delta: float) -> void:
	if _preview != null:
		var t := Time.get_ticks_msec() * 0.001
		_preview.rotation.y = _preview_yaw + (0.0 if t < _preview_drag_until else sin(t * 1.2) * 0.6)
	_frames += 1
	match state:
		State.RUNNING:
			_tick_run(delta)
		_:
			# Insurance: slow motion belongs to the run. Anything that left
			# the clock slow after it would make every menu crawl.
			if Engine.time_scale != 1.0:
				Diag.note("time_scale_reset", {"was": Engine.time_scale})
				Engine.time_scale = 1.0
				_slowmo_until = 0.0
	_keyboard_steer(delta)
	_apply_shake(delta)
	_watch_fps()
	if smoke:
		_smoke_tick()


func cycle_formation() -> void:
	if state != State.RUNNING:
		return
	squad.cycle_formation()
	hud.set_formation(squad.formation_name())
	sfx.play("click")


func throw_bomb() -> void:
	if state != State.RUNNING or not powerups.take_bomb():
		return
	hud.set_bombs(powerups.bombs)
	world.throw_bomb(squad.position.x)
	sfx.play("throw")


func _tick_run(delta: float) -> void:
	_run_time += delta
	squad.now = _run_time
	world.now = _run_time
	# Sway: the rig drifts a little toward the squad and leans into a turn.
	var k := 1.0 - exp(-4.0 * delta)
	_cam_rig.position.x = lerpf(_cam_rig.position.x, squad.position.x * 0.12, k)
	_cam_rig.rotation.z = lerpf(_cam_rig.rotation.z, clampf(-squad.velocity_x * 0.006, -0.05, 0.05), k)
	# A held touch follows its clinger; once it dies, the hold is over.
	for idx in _cling_touch.keys():
		var z: Zombie = _cling_touch[idx]
		if is_instance_valid(z) and z.alive and z.latched:
			squad.set_focus(z.position)
		else:
			_cling_touch.erase(idx)
			_touches.erase(idx)
			if _cling_touch.is_empty() and not _touches.values().has("focus"):
				squad.clear_focus()
	_check_lessons()
	var ws := world.advance(delta, squad)
	total_distance += ws * delta
	score = int((total_distance + float(bonus)) * world.mod("score"))
	if world.horde_z < World.HORDE_REST_Z - 0.5 and not _horde_warned:
		_horde_warned = true
		hud.show_banner("THE HORDE IS COMING\nKILL IT FAST", 1.6)
		_teach("horde")
		sfx.play("boss_roar", -6.0, 0.8)
	hud.update_stats(squad.count, world.level, total_distance, score)
	hud.set_combo(combo.count if combo.alive(_run_time) else 0, combo.multiplier(), combo.remaining(_run_time))
	# Danger pulse: the squad is a shadow of what it was this level.
	var danger := 0.0
	if squad.count > 0 and squad.count <= 5:
		danger = 1.0 - float(squad.count - 1) / 5.0
	elif _level_peak >= 12 and squad.count < _level_peak / 4:
		danger = 0.5
	hud.set_danger(danger)
	hud.set_formation(squad.formation_name())
	hud.set_dash(Progression.dash_enabled(world.level), squad.can_dash())
	var powers := []
	for id in Powerups.ORDER:
		if id != "bomb" and powerups.active(id, _run_time):
			powers.append("%s %ds" % [Powerups.title(id), int(ceil(powerups.remaining(id, _run_time)))])
	hud.set_powers("   ".join(powers))
	# Music follows the room: boss, trouble, or the road.
	if world.phase == World.Phase.BOSS:
		sfx.set_music("boss")
	elif danger > 0.0 or world.level >= 3 or mode == "endless":
		sfx.set_music("tense")
	else:
		sfx.set_music("calm")
	if _slowmo_until > 0.0 and Time.get_ticks_msec() * 0.001 >= _slowmo_until:
		_slowmo_until = 0.0
		Engine.time_scale = 1.0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_try_retry()
			if state == State.RUNNING:
				var zone := "focus" if event.position.y < get_viewport().get_visible_rect().size.y * FOCUS_ZONE else "steer"
				# A touch on a clinger aims at it wherever it is, and sticks.
				var px := Progression.CLING_TAP_PX * get_viewport().get_visible_rect().size.x / 720.0
				var cling: Zombie = world.latched_near_screen(camera, event.position, px)
				if cling != null:
					zone = "cling"
					_cling_touch[event.index] = cling
					squad.set_focus(cling.position)
				_touches[event.index] = zone
				if zone == "focus":
					squad.set_focus(_road_point(event.position))
		else:
			if _touches.get(event.index, "") in ["focus", "cling"]:
				squad.clear_focus()
			_touches.erase(event.index)
			_cling_touch.erase(event.index)
	elif event is InputEventScreenDrag and state == State.TITLE and _preview != null:
		# Spin the hero round with a finger.
		_preview_yaw += event.relative.x * 0.012
		_preview_drag_until = Time.get_ticks_msec() * 0.001 + 1.5
	elif event is InputEventScreenDrag and state == State.RUNNING:
		var zone: String = _touches.get(event.index, "steer")
		if zone == "cling":
			pass
		elif zone == "focus":
			squad.set_focus(_road_point(event.position))
		else:
			# A hard flick is a dash; anything gentler steers.
			if Progression.dash_enabled(world.level) and absf(event.velocity.x) >= Progression.DASH_FLICK_SPEED and squad.can_dash():
				if squad.dash(event.velocity.x):
					_on_dash()
			else:
				squad.nudge(event.relative.x * _drag_scale)
				# Drag up to spread the line, down to tighten it.
				squad.adjust_spread(-event.relative.y * _drag_scale * 0.35)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			if state == State.TITLE:
				start_run("levels")
			else:
				_try_retry()
		elif event.keycode == KEY_ESCAPE or event.keycode == KEY_P:
			if get_tree().paused:
				resume_game()
			else:
				pause_game()
		elif event.keycode == KEY_F:
			cycle_formation()
		elif event.keycode == KEY_B:
			throw_bomb()
		elif event.keycode == KEY_Q or event.keycode == KEY_E:
			if state == State.RUNNING and Progression.dash_enabled(world.level) and squad.dash(-1.0 if event.keycode == KEY_Q else 1.0):
				_on_dash()


## Where a screen point lands on the road (y = 0), for focus fire.
func _road_point(screen: Vector2) -> Vector3:
	var origin := camera.project_ray_origin(screen)
	var dir := camera.project_ray_normal(screen)
	if absf(dir.y) < 0.001:
		return Vector3(0.0, 0.0, -20.0)
	var t := -origin.y / dir.y
	var p := origin + dir * t
	return Vector3(p.x, 0.0, p.z)


func _on_dash() -> void:
	sfx.play("throw", -6.0, 1.6)
	Burst.spawn(world, squad.position + Vector3(0.0, 0.6, 0.0), Soldier.BODY, 10, 0.1, 3.0, 0.3)


func _try_retry() -> void:
	if state == State.GAME_OVER and Time.get_ticks_msec() - _game_over_at >= int(RETRY_LOCKOUT * 1000.0):
		Diag.note("retry")
		start_run(mode)


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
	var sp := 0.0
	if Input.is_physical_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_W):
		sp += 1.0
	if Input.is_physical_key_pressed(KEY_DOWN) or Input.is_physical_key_pressed(KEY_S):
		sp -= 1.0
	if sp != 0.0:
		squad.adjust_spread(sp * 2.0 * delta)


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


# --- world events ----------------------------------------------------------

func _on_gate_passed(panel: GateMath.GatePanel, before: int, after: int) -> void:
	gates_passed += 1
	_level_gates += 1
	if smoke:
		print("SMOKE_GATE ", JSON.stringify({"level": world.level, "n": gates_passed, "dist": int(world.level_distance), "panel": GateMath.label(panel), "before": before, "after": after, "frame": _frames}))
	var text := GateMath.label(panel)
	if after > before:
		text += "   %d > %d" % [before, after]
	hud.show_float(text, after >= before)
	if GateMath.is_power(panel):
		return
	if after >= before + 3 or (before > 0 and after >= before * 1.3 and after > before):
		# A real gain: the squad cheers, the ground rings, the camera leans.
		squad.rally()
		sfx.play("rally")
		_punch(5.0)
	elif after > before:
		sfx.play("gate_good")
		_punch(3.0)
	else:
		sfx.play("gate_bad", -4.0)


func _on_gate_robbed(gate: Gate, index: int) -> void:
	sfx.play("gate_bad", -2.0, 1.3)
	hud.show_float("ROBBED!", false)
	Burst.spawn(world, gate.panel_position(index) + Vector3(0.0, 0.0, 0.3), Zombie.THIEF_SKIN, 8, 0.12, 4.0, 0.4)


func _on_spit_landed(hit: bool) -> void:
	sfx.play("hit", -2.0, 0.6)
	var at := squad.position + Vector3(0.0, 0.3, 0.0) if hit else squad.position + Vector3(2.0, 0.3, 0.0)
	Burst.spawn(world, at, Spit.COLOR, 10, 0.14, 4.0, 0.5)
	if hit:
		_shake = minf(1.0, _shake + 0.5)


func _on_gate_stepped(gate: Gate, index: int) -> void:
	sfx.play("step", -8.0, randf_range(0.95, 1.1))
	Burst.spawn(world, gate.panel_position(index) + Vector3(0.0, 0.0, 0.3), GatePanelView.CHOSEN, 4, 0.1, 3.0, 0.3)


func _on_zombie_killed(zombie: Zombie) -> void:
	kills += 1
	bounty += Bounty.for_kind(zombie.kind_name())
	world.supply_funds = bounty
	# Greed shows on the counter as it happens, not only at the end.
	hud.set_bounty(int(round(float(bounty) * perks.coin_mult())))
	var chain := combo.kill(_run_time)
	bonus += int(10.0 * combo.multiplier())
	sfx.play_hit()
	if chain > 0 and chain % Combo.STEP == 0:
		sfx.play("step", -6.0, 1.0 + 0.08 * float(chain / Combo.STEP))
		hud.show_float("%d COMBO" % chain, true)
	var color := Zombie.BRUTE_SKIN if zombie.brute else Zombie.SKIN
	Burst.spawn(world, zombie.position + Vector3(0.0, 0.8, 0.0), color, 6 if zombie.brute else 3, 0.16 if zombie.brute else 0.12)
	if not smoke:
		Fx.blood(world, zombie.position + Vector3(0.0, 0.9, 0.0), zombie.brute or zombie.is_tank())


func _on_squad_bitten(bite: int, heavy: bool) -> void:
	_shake = minf(1.0, _shake + (0.5 if heavy else 0.2))
	sfx.play("bite", 0.0 if heavy else -6.0)
	Burst.spawn(world, squad.position + Vector3(0.0, 0.9, -0.5), Soldier.BODY, mini(bite * 3, 24), 0.12, 4.5)
	hud.show_float("-%d" % bite, false)
	if smoke:
		print("SMOKE_BITE ", JSON.stringify({"level": world.level, "bite": bite, "left": squad.count, "frame": _frames}))
	# A heavy bite can take a veteran with it. The loss is named.
	if heavy and squad.count > 0:
		var lost := squad.veterans.roll_loss(world.gen.rng)
		if not lost.is_empty():
			squad.lose_veteran(lost)
			_refresh_pause_perks()
			hud.show_banner("%s IS DOWN" % lost.name, 1.4)
			sfx.play("wipe", -8.0, 1.2)
			if smoke:
				print("SMOKE_VETERAN_LOST ", JSON.stringify({"name": lost.name, "trait": lost.trait, "level": world.level, "frame": _frames}))
	# A near miss: the bite left you with a handful. Let it land in slow motion.
	if not smoke and squad.count > 0 and squad.count <= 4 and bite >= 2:
		Engine.time_scale = 0.35
		_slowmo_until = Time.get_ticks_msec() * 0.001 + 0.6


func _on_boss_spawned(boss: Boss) -> void:
	if smoke:
		print("SMOKE_BOSS ", JSON.stringify({"level": world.level, "kind": boss.kind_name(), "squad": squad.count, "boss_hp": boss.max_hp, "frame": _frames}))
	hud.show_boss(true)
	hud.show_banner("BOSS", 1.2)
	_teach(Lessons.boss_lesson(boss.kind_name()))
	sfx.play("boss_roar")
	_shake = 0.6


func _on_boss_hit(boss: Boss, is_core: bool) -> void:
	hud.set_boss_ratio(boss.hp / boss.max_hp)
	if is_core:
		sfx.play("boss_hit", -4.0, 1.4)
		Burst.spawn(world, boss.position + Vector3(boss.core_x, 1.9, 1.2), Boss.CORE_COLOR, 3, 0.1, 3.0, 0.3)
		if not smoke and randf() < 0.3:
			Fx.sparks(world, boss.position + Vector3(boss.core_x, 1.9, 1.2), 6)


func _on_boss_killed(level: int, squad_left: int) -> void:
	bosses_killed += 1
	if smoke:
		print("SMOKE_BOSS_DOWN ", JSON.stringify({"level": level, "squad_left": squad_left, "frame": _frames}))
	_hitstop(0.14)
	var b := Difficulty.level_bonus(level, squad_left, squad.vehicles_alive())
	var letter := Grades.grade(_level_perfect, _level_gates, _level_peak, squad_left, _run_time - _boss_start)
	grades.append(letter)
	b += Grades.bonus(letter)
	bonus += b
	if smoke:
		print("SMOKE_GRADE ", JSON.stringify({"level": level, "grade": letter, "boss_seconds": snappedf(_run_time - _boss_start, 0.1)}))
	hud.show_boss(false)
	hud.show_banner("LEVEL %d CLEAR   GRADE %s\n+%d" % [level, letter, b], 1.8)
	# A survivor steps up: a name, a beret, a trait the squad feels.
	if squad_left > 0 and not squad.veterans.is_full():
		var v := squad.veterans.promote(world.gen.rng)
		if not v.is_empty():
			_vets_made += 1
			squad.mark_veterans()
			_refresh_pause_perks()
			if smoke:
				print("SMOKE_VETERAN ", JSON.stringify({"name": v.name, "trait": v.trait, "level": level, "frame": _frames}))
			get_tree().create_timer(2.0).timeout.connect(func() -> void:
				if state == State.RUNNING:
					hud.show_banner("%s STEPS UP\n%s: %s" % [v.name, Veterans.title(v.trait), Veterans.description(v.trait)], 2.4)
					sfx.play("rally", -2.0, 1.2)
					_teach("veterans"))
	if character_mode:
		hud.show_float(Wardrobe.cheer_line(wardrobe.hero_name(), letter, level + bosses_killed), true)
	squad.cheer()
	hud.flash(0.35)
	sfx.play("level_clear")
	_punch(6.0)
	_shake = 0.8
	if world.boss != null:
		Burst.spawn(world, world.boss.position + Vector3(0.0, 2.0, 0.0), Boss.CORE_COLOR, 40, 0.22, 7.0, 0.9)
		Burst.spawn(world, world.boss.position + Vector3(0.0, 1.5, 0.0), Boss.SKIN, 30, 0.2, 6.0, 0.9)


func _on_level_started(level: int) -> void:
	if level <= 1:
		return
	hud.show_banner("LEVEL %d" % level, 1.0)
	hud.show_hint(Progression.hint_for(level), 3.6)
	for id in Lessons.for_level(level):
		if _teach(id):
			break
	_level_peak = 1
	_level_gates = 0
	_level_perfect = 0
	_horde_warned = false
	if not world.endless:
		var carried := Difficulty.carry_over(squad.count, run_meta.start_squad())
		squad.redeploy(carried)
		if run_meta.level("start") > 0 and carried == run_meta.start_squad():
			hud.show_float("RECRUITS  %d" % carried, true)
		sfx.play("spawn")


func _on_perk_chosen(id: String) -> void:
	perks.take(id)
	world.perk_count = perks.total()
	hud.show_banner(Perks.title(id) + ("  x%d" % perks.stack(id) if perks.stack(id) > 1 else ""), 1.0)
	_refresh_pause_perks()
	sfx.play("gate_good")
	_punch(3.0)


## The bounty spent on the road: fewer coins home, more squad now.
func _on_supply_bought(id: String, amount: int, cost: int) -> void:
	bounty = maxi(0, bounty - cost)
	world.supply_funds = bounty
	hud.set_bounty(int(round(float(bounty) * perks.coin_mult())))
	var what := "+%d SOLDIERS" % amount if id == "soldiers" else Powerups.title(id)
	hud.show_banner("SUPPLY: %s\n-%d COINS" % [what, cost], 1.2)
	sfx.play("gate_good", -2.0, 1.1)
	_punch(3.0)
	if smoke:
		print("SMOKE_SUPPLY ", JSON.stringify({"id": id, "amount": amount, "cost": cost, "left": bounty, "level": world.level, "frame": _frames}))


## The pause menu's line: perks held, then the veterans by name.
func _refresh_pause_perks() -> void:
	var parts := []
	var perk_text := Perks.summary(perks.stacks)
	if perk_text != "":
		parts.append(perk_text)
	var vets := squad.veterans.summary()
	if vets != "":
		parts.append("VETERANS: " + vets)
	hud.set_perks("\n".join(parts))


## A perk did its job: say so, every time, so the gate was worth it.
func _on_perk_felt(id: String, amount: int) -> void:
	match id:
		"skin":
			hud.show_banner("THICK SKIN\nSAVED %d" % amount, 0.8)
		"recruit":
			hud.show_banner("RECRUITER  +%d" % amount, 0.6)


func _on_powerup_granted(id: String, from_crate: bool) -> void:
	var changed := powerups.grant(id, _run_time)
	hud.set_bombs(powerups.bombs)
	if smoke:
		print("SMOKE_POWER ", JSON.stringify({"id": id, "crate": from_crate, "frame": _frames}))
	if id == "bomb":
		hud.show_float("+BOMB" if changed else "BOMBS FULL", changed)
	else:
		hud.show_float("%s!" % Powerups.title(id), true)
	sfx.play("crate" if from_crate else "powerup")
	if id != "bomb":
		sfx.play("powerup", -3.0, 0.9)
	_punch(2.0)


func _on_shield_blocked() -> void:
	hud.show_float("BLOCKED", true)
	sfx.play("block", -4.0)
	Burst.spawn(world, squad.position + Vector3(0.0, 1.0, -1.0), Color(0.4, 0.8, 1.0), 8, 0.1, 3.5, 0.35)


func _on_bomb_exploded(at: Vector3, kills: int) -> void:
	sfx.play("explosion")
	_shake = 1.0
	_punch(5.0)
	Burst.spawn(world, at + Vector3(0.0, 0.5, 0.0), Color(1.0, 0.6, 0.15), 40, 0.25, 9.0, 0.7)
	Burst.spawn(world, at + Vector3(0.0, 0.3, 0.0), Color(0.2, 0.2, 0.2), 24, 0.2, 5.0, 0.9)
	if kills > 0:
		hud.show_float("BOOM  %d" % kills, true)


func _on_fork_ahead(routes: Dictionary) -> void:
	hud.show_fork(routes)
	sfx.play("click", -2.0, 0.8)


func _on_fork_chosen(route: Dictionary, _side: int) -> void:
	if smoke:
		print("SMOKE_FORK ", JSON.stringify({"level": world.level, "threat": route.threat, "needs": route.needs, "squad": squad.count, "frame": _frames}))
	hud.hide_fork()
	var heavy := int(route.threat) >= 3
	hud.show_banner("INTO THE THICK OF IT" if heavy else "THE QUIET ROAD", 0.9)
	sfx.play("powerup" if heavy else "spawn", -4.0)
	_punch(2.0)


## A frame of frozen time on the big hits: the eye reads the moment.
func _hitstop(seconds: float) -> void:
	if smoke:
		return
	Engine.time_scale = 0.05
	_slowmo_until = Time.get_ticks_msec() * 0.001 + seconds


func _on_vehicle_formed(id: String) -> void:
	_hitstop(0.08)
	if smoke:
		print("SMOKE_VEHICLE ", JSON.stringify({"id": id, "level": world.level, "squad": squad.count, "frame": _frames}))
	hud.show_banner("%s JOINS THE CONVOY" % Convoy.title(id), 1.4)
	sfx.play("rally")
	squad.rally()
	_punch(5.0)
	_vehicles_formed += 1


func _on_vehicle_lost(id: String) -> void:
	hud.show_float("%s LOST" % Convoy.title(id), false)
	if not smoke:
		Fx.smoke(world, squad.position + Vector3(0.0, 0.8, -0.5), 10)
		Fx.sparks(world, squad.position + Vector3(0.0, 0.8, -0.5), 14)
	sfx.play("wipe", -6.0, 1.4)
	_shake = minf(1.0, _shake + 0.6)
	Burst.spawn(world, squad.position + Vector3(0.0, 0.8, -0.5), Color(1.0, 0.55, 0.2), 24, 0.2, 6.0, 0.7)


func _on_shell_exploded(at: Vector3, kills: int) -> void:
	Burst.spawn(world, at + Vector3(0.0, 0.5, 0.0), Color(1.0, 0.65, 0.25), 6 + kills, 0.16, 5.0, 0.45)
	if not smoke:
		Fx.sparks(world, at + Vector3(0.0, 0.4, 0.0), 10)
		Fx.dust(world, at + Vector3(0.0, 0.2, 0.0), 8, 0.3)
		Fx.smoke(world, at + Vector3(0.0, 0.6, 0.0), 4)
	if kills >= 3:
		_punch(1.5)


func _on_saw_hit(hit: bool) -> void:
	if smoke:
		print("SMOKE_SAW ", JSON.stringify({"hit": hit, "level": world.level, "squad": squad.count, "frame": _frames}))
	if hit:
		sfx.play("explosion", -6.0, 1.3)
		_shake = minf(1.0, _shake + 0.7)
		hud.flash(0.2)
	else:
		sfx.play("throw", -8.0, 0.7)


func _on_bet_placed() -> void:
	hud.show_banner("BET ON!\nCLEAR THE WAVE, NO BITES", 1.4)
	sfx.play("powerup", -4.0, 1.2)


func _bot_panel(g: Gate) -> int:
	for i in range(g.panels.size()):
		if GateMath.is_vehicle(g.panels[i]) and squad.count >= Convoy.cost(g.panels[i].power) * 2:
			return i
	if squad.count >= 24:
		for i in range(g.panels.size()):
			if GateMath.is_bet(g.panels[i]):
				return i
	# Supply when the bounty covers it: soldiers for a small squad, a
	# power-up otherwise. Spending on the road is a plan the bot tests.
	for i in range(g.panels.size()):
		var sp: GateMath.GatePanel = g.panels[i]
		if GateMath.is_supply(sp) and world.supply_funds >= GateMath.supply_cost(sp):
			if sp.power == "soldiers" and squad.count < 60:
				return i
			if sp.power != "soldiers" and squad.count >= 10:
				return i
	return GateMath.best_index(g.panels, squad.count)


func _on_bet_resolved(won: bool, before: int, after: int) -> void:
	if smoke:
		print("SMOKE_BET ", JSON.stringify({"won": won, "before": before, "after": after, "level": world.level, "frame": _frames}))
	if won:
		_bets_won += 1
	else:
		_bets_lost += 1
	if won:
		hud.show_banner("BET WON   x2\n%d > %d" % [before, after], 1.6)
		squad.rally()
		sfx.play("rally")
		_punch(6.0)
	else:
		hud.show_banner("BET LOST   ÷2\n%d > %d" % [before, after], 1.6)
		sfx.play("gate_bad", -2.0, 0.8)
		_shake = 0.5


func _on_horde_bit(bite: int) -> void:
	hud.show_float("THE HORDE  -%d" % bite, false)
	sfx.play("bite", -4.0, 0.7)
	_shake = minf(1.0, _shake + 0.4)


func _on_fork_merged() -> void:
	hud.show_banner("MERGE", 0.6)


## The road widened: pull the camera back so the whole thing fits, and say so.
func _on_lanes_changed(n: int, animated: bool) -> void:
	_fit_camera(n, animated)
	if state == State.RUNNING and animated:
		hud.show_banner("%d LANES" % n, 1.4)
		sfx.play("powerup", -4.0, 0.7)
		_punch(-4.0)


func _fit_camera(n: int, animate: bool) -> void:
	var extra := float(n - 2)
	var target_pos := Vector3(0.0, 11.0 + extra * 3.2, 9.0 + extra * 2.4)
	var look := Vector3(0.0, 0.0, -7.0 - extra * 2.0)
	_drag_scale = (world.road_half * 2.0) / (get_viewport().get_visible_rect().size.x * 0.5)
	if animate:
		var tw := create_tween()
		tw.tween_property(camera, "position", target_pos, 1.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		tw.parallel().tween_method(func(v: Vector3) -> void: camera.look_at(v, Vector3.UP), camera.position + camera.basis.z * -10.0, look, 1.4)
	else:
		camera.position = target_pos
		camera.look_at(look, Vector3.UP)


func _on_dodged() -> void:
	bonus += Progression.DODGE_BONUS
	hud.show_float("DODGED  +%d" % Progression.DODGE_BONUS, true)
	sfx.play("block", -6.0, 1.3)
	_punch(2.0)


func _on_latched(zombie: Zombie) -> void:
	sfx.play("bite", -8.0, 1.4)
	hud.show_float("CLINGER! TAP IT", false)
	Burst.spawn(world, zombie.position + Vector3(0.0, 0.9, 0.0), Zombie.LATCHER_SKIN, 6, 0.1, 3.0, 0.3)
	_shake = minf(1.0, _shake + 0.3)


func _on_shaken_off(n: int) -> void:
	hud.show_float("SHOOK OFF %d" % n, true)
	sfx.play("block", -4.0, 0.8)


func _on_strike_landed(at: Vector3, hit: bool) -> void:
	sfx.play("explosion", -2.0 if hit else -8.0, 1.5)
	hud.flash(0.25 if hit else 0.1)
	_shake = minf(1.0, _shake + (0.8 if hit else 0.3))
	Burst.spawn(world, at + Vector3(0.0, 0.4, 0.0), Strike.BOLT, 18, 0.14, 7.0, 0.5)


func _on_wave_cleared(level: int) -> void:
	waves_cleared += 1
	var b := Difficulty.wave_clear_bonus(level)
	bonus += b
	hud.show_float("WAVE CLEAR  +%d" % b, true)
	sfx.play("spawn", -4.0, 1.2)


func _on_gate_perfect(_gate, _index: int) -> void:
	perfect_gates += 1
	_level_perfect += 1
	bonus += Difficulty.PERFECT_BONUS
	hud.show_banner("PERFECT  +%d" % Difficulty.PERFECT_BONUS, 0.7)
	sfx.play("level_clear", -8.0, 1.5)
	_punch(2.0)


func _on_count_changed(new_count: int) -> void:
	peak_squad = maxi(peak_squad, new_count)
	_level_peak = maxi(_level_peak, new_count)


func _on_wiped_out() -> void:
	# Second wind: the shop's one comeback. Deferred either way, since the
	# wipe can fire from inside the world's update loop.
	if _second_wind_pending or _revive_open:
		return
	if _lesson_open:
		_close_lesson()
	if state == State.RUNNING and run_meta.has_second_wind() and not _second_wind_used:
		_second_wind_used = true
		_second_wind_pending = true
		call_deferred("_second_wind")
		return
	# The rally: once a run, stars buy a squad back. Not for the bot, not
	# in the daily or weekly.
	var price := Revive.price(Revive.uses_today(revives, _today()))
	if state == State.RUNNING and not smoke and not _revive_used and Revive.allowed(mode) and wardrobe.stars >= price:
		_revive_open = true
		call_deferred("_offer_revive", price)
		return
	call_deferred("end_run")


func _today() -> int:
	return Daily.day_number(int(Time.get_unix_time_from_system()))


func _offer_revive(price: int) -> void:
	if state != State.RUNNING:
		_revive_open = false
		return
	# The last bite may have slowed time; the countdown runs at full speed.
	Engine.time_scale = 1.0
	_slowmo_until = 0.0
	Diag.set_state("revive_offer")
	Diag.note("revive_offer", {"price": price, "stars": wardrobe.stars, "level": world.level})
	get_tree().paused = true
	hud.show_revive(price, wardrobe.stars, Revive.SOLDIERS, Revive.OFFER_SECONDS)
	sfx.play("boss_roar", -10.0, 1.6)


func _on_revive_accepted() -> void:
	if not _revive_open:
		return
	_revive_open = false
	_revive_used = true
	Diag.set_state("running")
	Diag.note("revive_accepted")
	var price := Revive.price(Revive.uses_today(revives, _today()))
	wardrobe.stars = maxi(0, wardrobe.stars - price)
	revives = Revive.note_use(revives, _today())
	SaveData.save_wardrobe(wardrobe.to_dict())
	SaveData.save_revives(revives)
	hud.hide_revive()
	get_tree().paused = false
	squad.set_count(Revive.SOLDIERS)
	powerups.grant("shield", _run_time)
	world.shake_off()
	hud.show_banner("RALLY!\n%d SOLDIERS BACK" % Revive.SOLDIERS, 1.6)
	hud.flash(0.6)
	sfx.play("rally")
	squad.rally()
	_punch(6.0)


func _on_revive_declined() -> void:
	if not _revive_open:
		return
	_revive_open = false
	Diag.note("revive_declined")
	hud.hide_revive()
	get_tree().paused = false
	end_run()


func _second_wind() -> void:
	_second_wind_pending = false
	if state != State.RUNNING:
		return
	Diag.note("second_wind", {"level": world.level})
	if smoke:
		print("SMOKE_WIND ", JSON.stringify({"level": world.level, "frame": _frames}))
	squad.set_count(Meta.SECOND_WIND_SOLDIERS)
	powerups.grant("shield", _run_time)
	world.shake_off()
	hud.show_banner("SECOND WIND!\n%d SOLDIERS BACK" % Meta.SECOND_WIND_SOLDIERS, 1.6)
	hud.flash(0.6)
	sfx.play("rally")
	squad.rally()
	_punch(6.0)


func _on_sound_toggled(on: bool) -> void:
	Sfx.enabled = on
	SaveData.save_sound_on(on)
	if on:
		sfx.play("click")


func _on_music_toggled(on: bool) -> void:
	Sfx.music_on = on
	SaveData.save_music_on(on)
	sfx.play("click")


# --- smoke and screenshots ------------------------------------------------

func _smoke_tick() -> void:
	if _quitting:
		return
	if _frames < _smoke_frames and state == State.RUNNING:
		if _smoke_wipe_at > 0 and _frames >= _smoke_wipe_at and _smoke_retries == 0:
			print("SMOKE_WIPE ", JSON.stringify({"frame": _frames, "level": world.level}))
			squad.set_count(0)
			return
		_bot_steer()
		return
	if _shots_dir != "":
		return
	# --smoke-retry: sit on the results for a second and a half, check the
	# clock is back to normal, then tap through and play again, once.
	if _smoke_retry and state == State.GAME_OVER and _smoke_retries == 0 and _frames < _smoke_frames:
		# Frames, not the clock: headless frames on a frozen road are fast.
		if _frames - _game_over_frame < 90:
			return
		_smoke_retries += 1
		if Engine.time_scale != 1.0:
			push_error("game over left the clock at %s" % Engine.time_scale)
		print("SMOKE_RETRY ", JSON.stringify({"frame": _frames, "level": world.level, "time_scale": Engine.time_scale, "stalls": Diag.stalls.size()}))
		start_run(mode)
		return
	if _frames >= _smoke_frames or state == State.GAME_OVER:
		var summary := {
			"frames": _frames,
			"mode": mode,
			"level": world.level,
			"distance": int(total_distance),
			"gates": gates_passed,
			"bosses": bosses_killed,
			"perks": perks.stacks,
			"best_combo": combo.best,
			"bombs_left": powerups.bombs,
			"waves_cleared": waves_cleared,
			"perfect_gates": perfect_gates,
			"kills": kills,
			"bounty": bounty,
			"squad": squad.count,
			"peak_squad": peak_squad,
			"score": score,
			"state": state,
			"retries": _smoke_retries,
		}
		print("SMOKE_RESULT ", JSON.stringify(summary))
		var ok := gates_passed >= 3 and total_distance > 100.0
		_quit_with(0 if ok else 1)


## Play like a person: track the boss core, shoot whatever is close,
## otherwise line up the better panel of the next gate.
func _bot_steer() -> void:
	# Spread for crowds, tighten for gates and the boss; bomb the heavies.
	var near := world.nearest_zombie(18.0)
	var heavy_near := false
	for z in world.zombies:
		if (z.brute or z.is_tank()) and z.position.z > -16.0:
			heavy_near = true
			break
	if powerups.bombs > 0 and (heavy_near or (world.phase == World.Phase.BOSS and world.boss != null and world.boss.alive and world.boss.position.z > -16.0)):
		throw_bomb()
	# A saw rolling at us outranks everything, the boss included: step
	# round it, and dash if it is close.
	var saw := world.nearest_saw(18.0)
	if saw != null and absf(saw.position.x - squad.position.x) < squad.reach() + 1.2:
		var away := -2.6 if saw.position.x > 0.0 else 2.6
		squad.target_x = clampf(saw.position.x + away, -squad.road_half + 0.5, squad.road_half - 0.5)
		if saw.position.z > -5.0 and Progression.dash_enabled(world.level) and squad.can_dash():
			if squad.dash(signf(away)):
				_on_dash()
		if _bot_spread:
			squad.set_spread(0.6)
		return
	# Lightning ring on top of us: head for the nearest safe spot, and dash
	# there if it is far.
	if world.strike_threat_at(squad.position.x, squad.reach() + 0.6):
		var safe := world.safe_x_near(squad.position.x, squad.reach() + 0.6)
		if Progression.dash_enabled(world.level) and absf(safe - squad.position.x) > 1.5 and squad.can_dash():
			if squad.dash(signf(safe - squad.position.x)):
				_on_dash()
		if world.phase == World.Phase.BOSS:
			squad.target_x = clampf(safe, -squad.road_half, squad.road_half)
			if _bot_spread:
				squad.set_spread(0.6)
			return
	# Straight fire when something heavy is lined up ahead; spray
	# otherwise. The bot plays both plans.
	var drill := false
	if world.phase == World.Phase.BOSS and world.boss != null and world.boss.alive:
		drill = absf(world.boss.position.x + world.boss.core_x - squad.position.x) < 1.0
	else:
		for z in world.zombies:
			if (z.brute or z.is_tank()) and z.position.z > -20.0 and absf(z.position.x - squad.position.x) < 0.8:
				drill = true
				break
	if drill != squad.straight and _bot_spread:
		squad.set_straight(drill)
	var focus := world.focus_target(24.0)
	if focus != null:
		squad.set_focus(focus.position)
	elif world.phase == World.Phase.BOSS and world.boss != null and world.boss.alive:
		squad.set_focus(Vector3(world.boss.position.x + world.boss.core_x, 0.0, world.boss.position.z))
	else:
		squad.clear_focus()
	if world.phase == World.Phase.BOSS and world.boss != null and world.boss.alive:
		if _bot_spread:
			squad.set_spread(0.6)
		squad.target_x = clampf(world.boss.position.x + world.boss.core_x, -squad.road_half, squad.road_half)
		return
	var g_near := world.nearest_upcoming_gate()
	if _bot_spread:
		squad.set_spread(1.6 if (near != null and (g_near == null or near.position.z > g_near.position.z)) else 0.7)
	# A thief about to reach a gate outranks everything else.
	for z in world.zombies:
		if z.is_thief():
			squad.target_x = clampf(z.position.x, -squad.road_half, squad.road_half)
			return
	# At a fork, go rich when the squad can afford the crowd, else safe.
	if world.fork != null and not world.fork.chosen:
		# Read the signs: take the heavier route when the squad meets its number.
		var left: Dictionary = world.fork.routes.left
		var right: Dictionary = world.fork.routes.right
		var heavy: Dictionary = left if int(left.threat) >= int(right.threat) else right
		var light: Dictionary = right if heavy == left else left
		var pick: Dictionary = heavy if squad.count >= int(heavy.needs) else light
		var go_left: bool = pick == left
		squad.target_x = (-1.0 if go_left else 1.0) * world.road_half * 0.5
		if world.fork.position.z > -24.0:
			return
	var z := world.nearest_zombie(22.0)
	var g := world.nearest_upcoming_gate()
	var pg := world.nearest_upcoming_perk_gate()
	# A gate about to arrive outranks a zombie: pick the panel first. The
	# bot takes a bet when it can afford to lose, so that path gets tested.
	if g != null and g.position.z > -12.0:
		squad.target_x = g.panel_center_x(_bot_panel(g))
		return
	if pg != null and (g == null or pg.position.z > g.position.z):
		if z != null and z.position.z > pg.position.z:
			squad.target_x = clampf(z.position.x, -squad.road_half, squad.road_half)
		else:
			squad.target_x = 0.0
		return
	if z != null and (g == null or z.position.z > g.position.z):
		squad.target_x = clampf(z.position.x, -squad.road_half, squad.road_half)
	elif g != null:
		squad.target_x = g.panel_center_x(_bot_panel(g))


func _shots_walkthrough() -> void:
	DirAccess.make_dir_recursive_absolute(_shots_dir)
	await _capture("1_title.png", 20)
	if _shots_quick:
		# The menus only: every state of the home screen, the cards.
		stats.runs = 3
		trophies = 640
		modifier = "hard"
		show_title()
		await _capture("q1_title_full.png", 5)
		character_mode = true
		hud.set_characters(true)
		wardrobe.stars = 12
		show_title()
		await _capture("q2_title_hero.png", 5)
		open_settings()
		await _capture("q3_settings.png", 5)
		show_title()
		hud._show_more()
		await _capture("q4_more.png", 5)
		show_title()
		hud.show_lesson(Lessons.title("perk"), Lessons.perk_body(["rapid", "skin", "greed"]))
		await _capture("q5_lesson.png", 5)
		hud.hide_lesson()
		# Three veterans in the front ranks of a small squad.
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		for i in range(3):
			squad.veterans.promote(rng)
		squad.set_count(8)
		squad.set_spread(1.3)
		await _capture("q6_veterans.png", 10)
		var foreman := Boss.new()
		foreman.setup(100.0, Boss.Kind.FOREMAN)
		foreman.position = Vector3(0.0, 0.0, -12.0)
		world.add_child(foreman)
		world.spawn_saw(-1.5, -7.0, true)
		await _capture("q7_foreman.png", 8)
		foreman.queue_free()
		_quit_with(0)
		return
	open_shop()
	await _capture("2_shop.png", 5)
	open_daily()
	await _capture("2b_daily.png", 5)
	open_settings()
	await _capture("2c_settings.png", 5)
	show_title()
	hud.show_crash_card()
	await _capture("2c2_crash.png", 5)
	hud.hide_crash_card()
	stats = Stats.merge(stats, {"runs": 12, "kills": 2400, "bosses": 11, "gates": 130, "perfect": 31, "distance": 9000, "best_combo": 140, "best_level": 6})
	open_records()
	await _capture("2h_records.png", 5)
	season_state = {"season": Season.number(Daily.day_number(int(Time.get_unix_time_from_system()))), "points": 460, "claimed": 4}
	open_quests()
	await _capture("2j_quests.png", 5)
	trophies = 640
	open_road()
	await _capture("2k_road.png", 5)
	trophies = 0
	open_help()
	await _capture("2i_help.png", 5)
	close_help()
	show_title()
	modifier = "hard"
	show_title()
	await _capture("2g_title_hard.png", 5)
	modifier = "normal"
	character_mode = true
	hud.set_characters(true)
	wardrobe.stars = 12
	wardrobe.tap("luna")
	wardrobe.tap("sunny")
	wardrobe.tap("cat")
	wardrobe.tap("cape_red")
	_apply_looks()
	open_locker()
	await _capture("2d_locker.png", 30)
	_on_locker_tab("hat")
	await _capture("2e_locker_hats.png", 5)
	wardrobe.tap("rainbow")
	_on_locker_tab("crew")
	await _capture("2e_locker_crew.png", 5)
	close_locker()
	await _capture("2f_title_hero.png", 20)
	smoke = true
	start_run("levels")
	await _capture("3_play_early.png", 240)
	for i in range(3000):
		var pg := world.nearest_upcoming_perk_gate()
		if pg != null and pg.position.z > -16.0:
			break
		await get_tree().process_frame
	await _capture("4_perk_gate.png", 2)
	_bot_spread = false
	squad.set_spread(1.7)
	await _capture("5_play_wide.png", 120)
	squad.set_spread(0.5)
	await _capture("5b_play_tight.png", 60)
	squad.set_count(maxi(squad.count, 160))
	squad.set_spread(1.0)
	await _capture("5c_army.png", 40)
	squad.add_vehicle("jeep")
	squad.add_vehicle("tank")
	squad.add_vehicle("heli")
	squad.add_vehicle("mech")
	await _capture("5c2_convoy.png", 90)
	_bot_spread = true
	for i in range(3000):
		if world.fork != null and world.fork.position.z > -30.0 and not world.fork.chosen:
			break
		await get_tree().process_frame
	await _capture("5d_fork.png", 2)
	for i in range(6000):
		var wide: Gate = world.nearest_upcoming_gate()
		if world.lanes >= 3 and wide != null and wide.panels.size() >= 3 and wide.position.z > -22.0:
			break
		await get_tree().process_frame
	await _capture("5f_three_lanes.png", 2)
	world.horde_z = 3.0
	world._place_horde()
	await _capture("5g_horde.png", 2)
	hud.show_revive(3, 12, Revive.SOLDIERS, Revive.OFFER_SECONDS)
	await _capture("5h_rally.png", 2)
	hud.hide_revive()
	hud.show_lesson(Lessons.title("perk"), Lessons.perk_body(["rapid", "skin", "greed"]))
	await _capture("5k_lesson.png", 2)
	hud.hide_lesson()
	world.spawn_saw(0.8, -12.0)
	await _capture("5i_saw.png", 2)
	squad.set_count(maxi(1, squad.count - 12))
	await _capture("5j_tumble.png", 14)
	world.horde_z = World.HORDE_REST_Z
	world._place_horde()
	for i in range(600):
		if world.fork != null and world.fork.chosen:
			break
		await get_tree().process_frame
	await _capture("5e_route.png", 30)
	for i in range(3000):
		if state != State.RUNNING or (world.phase == World.Phase.BOSS and world.boss != null and world.boss.position.z > -14.0):
			break
		await get_tree().process_frame
	await _capture("6_boss.png", 5)
	for i in range(3000):
		if state != State.RUNNING or world.phase != World.Phase.BOSS:
			break
		await get_tree().process_frame
	await _capture("7_level_clear.png", 20)
	await _capture("8_level_two.png", 400)
	pause_game()
	await _capture("9_paused.png", 5)
	resume_game()
	smoke = false
	squad.set_count(0)
	await _capture("10_game_over.png", 30)
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
	# Tear the scene down first so the shared materials have no users left,
	# then drop the cache and quit on the following frame. queue_free, not
	# free(): the release export template refuses to parse a bare free()
	# on self, which left the whole game script unloaded on phones.
	var tree := get_tree()
	tree.root.remove_child(self)
	queue_free()
	tree.process_frame.connect(func() -> void:
		Mats.clear()
		tree.quit(code)
	, CONNECT_ONE_SHOT)
