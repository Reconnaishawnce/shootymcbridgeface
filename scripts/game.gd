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
var achievements_done: Array = []
var _bets_won := 0
var _bets_lost := 0
var _help_from_pause := false
## Second wind: one comeback per run from the shop.
var _second_wind_used := false
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
var _since_game_over := 0.0
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
	if args.has("--hard"):
		modifier = "hard"
	elif args.has("--nightmare"):
		modifier = "nightmare"
	for a in args:
		if a.begins_with("--smoke-frames="):
			_smoke_frames = maxi(60, int(a.get_slice("=", 1)))
		elif a.begins_with("--smoke-seed="):
			_smoke_seed = int(a.get_slice("=", 1))
		elif a.begins_with("--shots="):
			_shots_dir = a.get_slice("=", 1)
	modifier = SaveData.load_modifier()
	if not Modifiers.unlocked(modifier, SaveData.load_best_level("normal"), SaveData.load_best_level("hard")):
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
	achievements_done = SaveData.load_achievements()
	# The auto-player dresses up so the character code runs in CI too.
	character_mode = SaveData.load_character_mode() or smoke
	# Headless CI has no audio device; the dummy driver releases playbacks
	# on its own thread and can report them as leaked at exit. Keep the
	# auto-player silent so its exit is deterministic.
	Sfx.enabled = SaveData.load_sound_on() and not smoke
	Sfx.music_on = SaveData.load_music_on()
	_build_scene()
	_drag_scale = (squad.road_half * 2.0) / (get_viewport().get_visible_rect().size.x * 0.5)
	hud.set_sound(Sfx.enabled)
	hud.set_music(Sfx.music_on)
	hud.set_characters(character_mode)
	_apply_looks()
	show_title()
	if smoke:
		start_run("weekly" if _smoke_weekly else ("daily" if _smoke_daily else ("endless" if _smoke_endless else "levels")))
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
	squad.reset()

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
	hud.help_opened.connect(open_help)
	hud.help_closed.connect(close_help)
	hud.settings_closed.connect(show_title)
	hud.characters_toggled.connect(_on_characters_toggled)
	hud.locker_opened.connect(open_locker)
	hud.locker_closed.connect(close_locker)
	hud.locker_tab.connect(_on_locker_tab)
	hud.item_pressed.connect(_on_item_pressed)


# --- menus -----------------------------------------------------------------

func show_title() -> void:
	state = State.TITLE
	sfx.set_music("calm")
	# A daily or weekly forces rifles; the title squad shows the real pick.
	if squad.squad_type != squad_type:
		squad.squad_type = squad_type
		_apply_looks()
	var normal_level := SaveData.load_best_level("normal")
	var hard_level := SaveData.load_best_level("hard")
	var hint := ""
	if modifier == "normal" and not Modifiers.unlocked("hard", normal_level, hard_level):
		hint = "Hard mode: %s" % Modifiers.unlock_text("hard")
	elif modifier == "hard" and not Modifiers.unlocked("nightmare", normal_level, hard_level):
		hint = "Nightmare: %s" % Modifiers.unlock_text("nightmare")
	hud.show_title({
		"best": best, "best_level": best_level, "best_endless": best_endless, "coins": coins,
		"endless_unlocked": Meta.endless_unlocked(normal_level), "squad_type": squad_type,
		"shotgun_unlocked": meta.shotgun_unlocked() or meta.squad_unlocked("medic"),
		"stars": wardrobe.stars, "hero_name": wardrobe.hero_name() if character_mode else "",
		"modifier": modifier, "mode_hint": hint,
	})


func _load_bests() -> void:
	best = SaveData.load_best(modifier)
	best_level = SaveData.load_best_level(modifier)
	best_endless = SaveData.load_best_endless(modifier)


func cycle_mode() -> void:
	modifier = Modifiers.next(modifier, SaveData.load_best_level("normal"), SaveData.load_best_level("hard"))
	SaveData.save_modifier(modifier)
	_load_bests()
	sfx.play("click")
	show_title()
	if modifier != "normal":
		hud.toast(Modifiers.blurb(modifier))


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
	total_distance = 0.0
	kills = 0
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
	squad.active = true
	hud.show_running()
	hud.set_formation(squad.formation_name())
	hud.update_stats(squad.count, world.level, total_distance, score)
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
	squad.active = false
	world.frozen = true
	Engine.time_scale = 1.0
	hud.set_combo(0, 1.0, 0.0)
	hud.set_danger(0.0)
	sfx.set_music("")
	_since_game_over = 0.0
	var earned := 0 if mode in ["daily", "weekly"] else int(round(float(Meta.coins_for_run(kills, bosses_killed, gates_passed)) * perks.coin_mult() * meta.coin_mult() * world.mod("coins")))
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
		"escapes": 1 if character_mode else 0, "vehicles": _vehicles_formed,
	}
	var new_achievements: Array = []
	if not smoke:
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
	hud.update_stats(squad.count, world.level, total_distance, score)
	hud.show_game_over({
		"score": score, "best": shown_best, "is_best": is_best, "level": world.level,
		"distance": int(total_distance), "kills": kills, "peak": peak_squad, "coins_earned": earned,
		"mode": mode, "stars_earned": stars_earned, "hero_name": wardrobe.hero_name() if character_mode else "",
		"locker_nudge": character_mode and wardrobe.can_afford_something(),
		"grades": " ".join(grades), "modifier": world.modifier, "achievements": new_achievements,
	})
	if character_mode:
		squad.cheer()
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
		State.GAME_OVER:
			_since_game_over += delta
	_keyboard_steer(delta)
	_apply_shake(delta)
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
	var ws := world.advance(delta, squad)
	total_distance += ws * delta
	score = int((total_distance + float(bonus)) * world.mod("score"))
	if world.horde_z < World.HORDE_REST_Z - 0.5 and not _horde_warned:
		_horde_warned = true
		hud.show_banner("THE HORDE IS COMING\nKILL IT FAST", 1.6)
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
	if state == State.GAME_OVER and _since_game_over >= RETRY_LOCKOUT:
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
	var chain := combo.kill(_run_time)
	bonus += int(10.0 * combo.multiplier())
	sfx.play_hit()
	if chain > 0 and chain % Combo.STEP == 0:
		sfx.play("step", -6.0, 1.0 + 0.08 * float(chain / Combo.STEP))
		hud.show_float("%d COMBO" % chain, true)
	var color := Zombie.BRUTE_SKIN if zombie.brute else Zombie.SKIN
	Burst.spawn(world, zombie.position + Vector3(0.0, 0.8, 0.0), color, 10 if zombie.brute else 5, 0.16 if zombie.brute else 0.12)


func _on_squad_bitten(bite: int, heavy: bool) -> void:
	_shake = minf(1.0, _shake + (0.5 if heavy else 0.2))
	sfx.play("bite", 0.0 if heavy else -6.0)
	Burst.spawn(world, squad.position + Vector3(0.0, 0.9, -0.5), Soldier.BODY, mini(bite * 3, 24), 0.12, 4.5)
	hud.show_float("-%d" % bite, false)
	if smoke:
		print("SMOKE_BITE ", JSON.stringify({"level": world.level, "bite": bite, "left": squad.count, "frame": _frames}))
	# A near miss: the bite left you with a handful. Let it land in slow motion.
	if not smoke and squad.count > 0 and squad.count <= 4 and bite >= 2:
		Engine.time_scale = 0.35
		_slowmo_until = Time.get_ticks_msec() * 0.001 + 0.6


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
	var b := Difficulty.level_bonus(level, squad_left, squad.vehicles_alive())
	var letter := Grades.grade(_level_perfect, _level_gates, _level_peak, squad_left, _run_time - _boss_start)
	grades.append(letter)
	b += Grades.bonus(letter)
	bonus += b
	if smoke:
		print("SMOKE_GRADE ", JSON.stringify({"level": level, "grade": letter, "boss_seconds": snappedf(_run_time - _boss_start, 0.1)}))
	hud.show_boss(false)
	hud.show_banner("LEVEL %d CLEAR   GRADE %s\n+%d" % [level, letter, b], 1.8)
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
	hud.show_banner(Perks.title(id), 0.9)
	sfx.play("gate_good")
	_punch(3.0)


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


func _on_vehicle_formed(id: String) -> void:
	if smoke:
		print("SMOKE_VEHICLE ", JSON.stringify({"id": id, "level": world.level, "squad": squad.count, "frame": _frames}))
	hud.show_banner("%s JOINS THE CONVOY" % Convoy.title(id), 1.4)
	sfx.play("rally")
	squad.rally()
	_punch(5.0)
	_vehicles_formed += 1


func _on_vehicle_lost(id: String) -> void:
	hud.show_float("%s LOST" % Convoy.title(id), false)
	sfx.play("wipe", -6.0, 1.4)
	_shake = minf(1.0, _shake + 0.6)
	Burst.spawn(world, squad.position + Vector3(0.0, 0.8, -0.5), Color(1.0, 0.55, 0.2), 24, 0.2, 6.0, 0.7)


func _on_shell_exploded(at: Vector3, kills: int) -> void:
	Burst.spawn(world, at + Vector3(0.0, 0.5, 0.0), Color(1.0, 0.65, 0.25), 10 + kills * 2, 0.16, 5.0, 0.45)
	if kills >= 3:
		_punch(1.5)


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
	if state == State.RUNNING and run_meta.has_second_wind() and not _second_wind_used:
		_second_wind_used = true
		call_deferred("_second_wind")
		return
	call_deferred("end_run")


func _second_wind() -> void:
	if state != State.RUNNING:
		return
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
		_bot_steer()
		return
	if _shots_dir != "":
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
	# Spread for crowds, tighten for gates and the boss; bomb the heavies.
	var near := world.nearest_zombie(18.0)
	var heavy_near := false
	for z in world.zombies:
		if (z.brute or z.is_tank()) and z.position.z > -16.0:
			heavy_near = true
			break
	if powerups.bombs > 0 and (heavy_near or (world.phase == World.Phase.BOSS and world.boss != null and world.boss.alive and world.boss.position.z > -16.0)):
		throw_bomb()
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
	open_shop()
	await _capture("2_shop.png", 5)
	open_daily()
	await _capture("2b_daily.png", 5)
	open_settings()
	await _capture("2c_settings.png", 5)
	stats = Stats.merge(stats, {"runs": 12, "kills": 2400, "bosses": 11, "gates": 130, "perfect": 31, "distance": 9000, "best_combo": 140, "best_level": 6})
	open_records()
	await _capture("2h_records.png", 5)
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
