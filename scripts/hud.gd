class_name Hud
extends CanvasLayer
## All 2D overlay: stats, boss bar, title menu, shop, perk cards, game-over
## card, pause menu, floating gate text, level banner and the new-best
## flash. Keeps processing while the tree is paused so menus work. Every
## passive control ignores the mouse so taps fall through to the game;
## only buttons catch.

signal play_pressed(mode: String)
signal daily_opened
signal copy_pressed
signal shop_opened
signal shop_closed
signal buy_pressed(id: String)
signal squad_toggled
signal menu_pressed
signal pause_pressed
signal resume_pressed
signal sound_toggled(on: bool)
signal music_toggled(on: bool)
signal formation_pressed
signal bomb_pressed
signal quit_pressed
signal settings_opened
signal settings_closed
signal characters_toggled(on: bool)
signal locker_opened
signal locker_closed
signal locker_tab(cat: String)
signal item_pressed(id: String)

const OUTLINE := Color(0.05, 0.05, 0.08)
const GAIN := Color(0.45, 0.9, 1.0)
const LOSS := Color(1.0, 0.4, 0.4)
const COIN := Color(1.0, 0.85, 0.3)
const STAR := Color(1.0, 0.95, 0.5)
const BOSS_BAR := Color(0.95, 0.25, 0.3)
const BOSS_BAR_BG := Color(0.1, 0.1, 0.12, 0.8)
## Gate result text starts a little above centre so it never covers the squad.
const FLOAT_START_Y := -140.0

var _level: Label
var _count: Label
var _subline: Label
var _pause_button: Button
var _boss_box: Control
var _boss_fill: ColorRect
var _boss_label: Label

var _title_card: Control
var _title: Label
var _records: Label
var _coins_title: Label
var _endless_button: Button
var _squad_button: Button
var _locker_button: Button
var _stars_title: Label

var _settings_card: Control
var _settings_sound: Button
var _settings_music: Button
var _settings_characters: Button
var _pause_characters: Button

var _locker_card: Control
var _locker_stars: Label
var _locker_tabs: Dictionary = {}
var _locker_grid: GridContainer
var _locker_line: Label
var _locker_tab := "hero"

var _shop_card: Control
var _daily_card: Control
var _daily_title: Label
var _daily_lines: Label
var _toast: Label
var _toast_tween: Tween
var _over_copy: Button
var _shop_coins: Label
var _shop_rows: Dictionary = {}

var _combo: Label
var _combo_bar: ColorRect
var _danger: ColorRect
var _combo_tween: Tween

var _over_card: Control
var _over_title: Label
var _over_lines: Label
var _over_prompt: Label

var _pause_card: Control
var _sound_button: Button
var _music_button: Button
var _formation_button: Button
var _bomb_button: Button
var _powers: Label
var _fork_box: Control
var _hint: Label
var _hint_tween: Tween
var _dash: Label
var _fork_left: Label
var _fork_right: Label

var _float_anchor: Control
var _float: Label
var _banner: Label
var _flash: ColorRect
var _float_tween: Tween
var _prompt_tween: Tween
var _banner_tween: Tween
var _count_tween: Tween


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_level = _label(34, HORIZONTAL_ALIGNMENT_LEFT)
	_place(root, _level, 0.0, 0.34, 28.0)
	_count = _label(64, HORIZONTAL_ALIGNMENT_CENTER)
	_place(root, _count, 0.3, 0.7, 14.0)
	_count.pivot_offset = Vector2(0.0, 40.0)
	_subline = _label(26, HORIZONTAL_ALIGNMENT_CENTER)
	_place(root, _subline, 0.2, 0.8, 92.0)

	_pause_button = _button("II", 34)
	_pause_button.anchor_left = 1.0
	_pause_button.anchor_right = 1.0
	_pause_button.offset_left = -92.0
	_pause_button.offset_right = -20.0
	_pause_button.offset_top = 22.0
	_pause_button.offset_bottom = 86.0
	_pause_button.pressed.connect(func() -> void: pause_pressed.emit())
	root.add_child(_pause_button)

	_boss_box = Control.new()
	_boss_box.anchor_left = 0.08
	_boss_box.anchor_right = 0.92
	_boss_box.offset_top = 154.0
	_boss_box.offset_bottom = 186.0
	_boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_box.visible = false
	root.add_child(_boss_box)
	var boss_bg := ColorRect.new()
	boss_bg.color = BOSS_BAR_BG
	boss_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	boss_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_box.add_child(boss_bg)
	_boss_fill = ColorRect.new()
	_boss_fill.color = BOSS_BAR
	_boss_fill.anchor_bottom = 1.0
	_boss_fill.offset_left = 3.0
	_boss_fill.offset_top = 3.0
	_boss_fill.offset_bottom = -3.0
	_boss_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_box.add_child(_boss_fill)
	_boss_label = _label(22, HORIZONTAL_ALIGNMENT_CENTER)
	_boss_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_boss_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_boss_label.text = "BOSS"
	_boss_box.add_child(_boss_label)

	_float_anchor = Control.new()
	_float_anchor.set_anchors_preset(Control.PRESET_CENTER)
	_float_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_float_anchor)
	_float = _label(72, HORIZONTAL_ALIGNMENT_CENTER)
	_float.set_anchors_preset(Control.PRESET_CENTER)
	_float.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_float.grow_vertical = Control.GROW_DIRECTION_BOTH
	_float.modulate.a = 0.0
	_float_anchor.add_child(_float)

	_banner = _label(56, HORIZONTAL_ALIGNMENT_CENTER)
	_banner.anchor_left = 0.0
	_banner.anchor_right = 1.0
	_banner.anchor_top = 0.3
	_banner.anchor_bottom = 0.3
	_banner.offset_bottom = 160.0
	_banner.modulate.a = 0.0
	root.add_child(_banner)

	_flash = ColorRect.new()
	_flash.color = Color(1.0, 1.0, 1.0, 0.0)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_flash)

	_formation_button = _button("NORMAL", 26)
	_formation_button.anchor_left = 1.0
	_formation_button.anchor_right = 1.0
	_formation_button.anchor_top = 1.0
	_formation_button.anchor_bottom = 1.0
	_formation_button.offset_left = -220.0
	_formation_button.offset_right = -20.0
	_formation_button.offset_top = -92.0
	_formation_button.offset_bottom = -24.0
	_formation_button.pressed.connect(func() -> void: formation_pressed.emit())
	root.add_child(_formation_button)
	_bomb_button = _button("BOMB x1", 26)
	_bomb_button.anchor_top = 1.0
	_bomb_button.anchor_bottom = 1.0
	_bomb_button.offset_left = 20.0
	_bomb_button.offset_right = 220.0
	_bomb_button.offset_top = -92.0
	_bomb_button.offset_bottom = -24.0
	_bomb_button.add_theme_color_override("font_color", COIN)
	_bomb_button.pressed.connect(func() -> void: bomb_pressed.emit())
	_bomb_button.visible = false
	root.add_child(_bomb_button)
	_powers = _label(24, HORIZONTAL_ALIGNMENT_CENTER)
	_place(root, _powers, 0.15, 0.85, 124.0)
	_powers.add_theme_color_override("font_color", Color(0.8, 0.6, 1.0))

	# Teaching line: one new thing per level, big, then gone.
	_hint = _label(34, HORIZONTAL_ALIGNMENT_CENTER)
	_hint.anchor_left = 0.0
	_hint.anchor_right = 1.0
	_hint.anchor_top = 0.44
	_hint.anchor_bottom = 0.44
	_hint.offset_bottom = 120.0
	_hint.modulate.a = 0.0
	_hint.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))
	root.add_child(_hint)
	_dash = _label(22, HORIZONTAL_ALIGNMENT_CENTER)
	_dash.anchor_left = 0.3
	_dash.anchor_right = 0.7
	_dash.anchor_top = 1.0
	_dash.anchor_bottom = 1.0
	_dash.offset_top = -60.0
	_dash.offset_bottom = -30.0
	_dash.modulate.a = 0.0
	root.add_child(_dash)

	# The fork preview: what each route offers, before you have to choose.
	_fork_box = Control.new()
	_fork_box.anchor_left = 0.04
	_fork_box.anchor_right = 0.96
	_fork_box.offset_top = 194.0
	_fork_box.offset_bottom = 276.0
	_fork_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fork_box.visible = false
	root.add_child(_fork_box)
	var fork_bg := ColorRect.new()
	fork_bg.color = Color(0.05, 0.05, 0.08, 0.7)
	fork_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fork_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fork_box.add_child(fork_bg)
	var fork_head := _label(20, HORIZONTAL_ALIGNMENT_CENTER)
	fork_head.text = "FORK AHEAD"
	fork_head.anchor_right = 1.0
	fork_head.offset_top = 2.0
	fork_head.offset_bottom = 26.0
	_fork_box.add_child(fork_head)
	_fork_left = _label(26, HORIZONTAL_ALIGNMENT_LEFT)
	_fork_left.anchor_right = 0.5
	_fork_left.offset_left = 14.0
	_fork_left.offset_top = 28.0
	_fork_left.offset_bottom = 80.0
	_fork_box.add_child(_fork_left)
	_fork_right = _label(26, HORIZONTAL_ALIGNMENT_RIGHT)
	_fork_right.anchor_left = 0.5
	_fork_right.anchor_right = 1.0
	_fork_right.offset_right = -14.0
	_fork_right.offset_top = 28.0
	_fork_right.offset_bottom = 80.0
	_fork_box.add_child(_fork_right)

	_build_title(root)
	_build_settings(root)
	_build_locker(root)
	_build_shop(root)
	_build_daily(root)
	_build_combo(root)
	_build_over(root)
	_build_pause(root)


func _build_title(root: Control) -> void:
	_title_card = _card(root)
	var box: VBoxContainer = _title_card.get_meta("box")
	_title = _label(64, HORIZONTAL_ALIGNMENT_CENTER)
	_title.text = "SHOOTY\nMcBRIDGEFACE"
	box.add_child(_title)
	_records = _label(28, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_records)
	var play := _button("PLAY", 44)
	play.pressed.connect(func() -> void: play_pressed.emit("levels"))
	box.add_child(play)
	_endless_button = _button("ENDLESS", 36)
	_endless_button.pressed.connect(func() -> void: play_pressed.emit("endless"))
	box.add_child(_endless_button)
	var daily := _button("DAILY", 36)
	daily.pressed.connect(func() -> void: daily_opened.emit())
	box.add_child(daily)
	_squad_button = _button("SQUAD: RIFLES", 30)
	_squad_button.pressed.connect(func() -> void: squad_toggled.emit())
	box.add_child(_squad_button)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	var shop := _button("SHOP", 36)
	shop.custom_minimum_size.x = 200.0
	shop.pressed.connect(func() -> void: shop_opened.emit())
	row.add_child(shop)
	_locker_button = _button("LOCKER", 36)
	_locker_button.custom_minimum_size.x = 200.0
	_locker_button.pressed.connect(func() -> void: locker_opened.emit())
	row.add_child(_locker_button)
	var settings := _button("SETTINGS", 30)
	settings.pressed.connect(func() -> void: settings_opened.emit())
	box.add_child(settings)
	_coins_title = _label(28, HORIZONTAL_ALIGNMENT_CENTER)
	_coins_title.add_theme_color_override("font_color", COIN)
	box.add_child(_coins_title)
	_stars_title = _label(26, HORIZONTAL_ALIGNMENT_CENTER)
	_stars_title.add_theme_color_override("font_color", STAR)
	box.add_child(_stars_title)


func _build_settings(root: Control) -> void:
	_settings_card = _card(root)
	_settings_card.visible = false
	var box: VBoxContainer = _settings_card.get_meta("box")
	var head := _label(48, HORIZONTAL_ALIGNMENT_CENTER)
	head.text = "SETTINGS"
	box.add_child(head)
	_settings_sound = _button("SOUND: ON", 34)
	_settings_sound.pressed.connect(_on_sound_pressed)
	box.add_child(_settings_sound)
	_settings_music = _button("MUSIC: ON", 34)
	_settings_music.pressed.connect(_on_music_pressed)
	box.add_child(_settings_music)
	_settings_characters = _button("CHARACTERS: OFF", 34)
	_settings_characters.pressed.connect(_on_characters_pressed)
	box.add_child(_settings_characters)
	var blurb := _label(22, HORIZONTAL_ALIGNMENT_CENTER)
	blurb.text = "Characters on: pick a hero, outfits, hats,\nweapons and more in the LOCKER. Stars pay for them."
	blurb.modulate = Color(0.85, 0.85, 0.9)
	box.add_child(blurb)
	var back := _button("BACK", 34)
	back.pressed.connect(func() -> void: settings_closed.emit())
	box.add_child(back)


func _build_locker(root: Control) -> void:
	_locker_card = _card(root)
	_locker_card.visible = false
	# A lighter shade than the other cards: the hero preview stands behind it.
	var shade: ColorRect = _locker_card.get_child(0)
	shade.color = Color(0.0, 0.0, 0.0, 0.3)
	var center: CenterContainer = _locker_card.get_child(1)
	center.anchor_top = 0.3
	var box: VBoxContainer = _locker_card.get_meta("box")
	box.add_theme_constant_override("separation", 10)
	var head := _label(44, HORIZONTAL_ALIGNMENT_CENTER)
	head.text = "LOCKER"
	box.add_child(head)
	_locker_stars = _label(28, HORIZONTAL_ALIGNMENT_CENTER)
	_locker_stars.add_theme_color_override("font_color", STAR)
	box.add_child(_locker_stars)
	var tabs := HBoxContainer.new()
	tabs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 6)
	box.add_child(tabs)
	for cat in Wardrobe.CATEGORIES:
		var b := _button(Wardrobe.CATEGORY_TITLES[cat], 20)
		b.custom_minimum_size = Vector2(126.0, 48.0)
		b.toggle_mode = true
		b.pressed.connect(func() -> void: locker_tab.emit(cat))
		tabs.add_child(b)
		_locker_tabs[cat] = b
	_locker_grid = GridContainer.new()
	_locker_grid.columns = 3
	_locker_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_locker_grid.add_theme_constant_override("h_separation", 8)
	_locker_grid.add_theme_constant_override("v_separation", 8)
	box.add_child(_locker_grid)
	_locker_line = _label(22, HORIZONTAL_ALIGNMENT_CENTER)
	_locker_line.modulate = Color(0.9, 0.9, 0.95)
	box.add_child(_locker_line)
	var back := _button("BACK", 34)
	back.pressed.connect(func() -> void: locker_closed.emit())
	box.add_child(back)


func _build_shop(root: Control) -> void:
	_shop_card = _card(root)
	_shop_card.visible = false
	var box: VBoxContainer = _shop_card.get_meta("box")
	box.add_theme_constant_override("separation", 10)
	var head := _label(48, HORIZONTAL_ALIGNMENT_CENTER)
	head.text = "SHOP"
	box.add_child(head)
	_shop_coins = _label(30, HORIZONTAL_ALIGNMENT_CENTER)
	_shop_coins.add_theme_color_override("font_color", COIN)
	box.add_child(_shop_coins)
	for id in Meta.ORDER:
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 14)
		row.custom_minimum_size = Vector2(620.0, 0.0)
		var text := VBoxContainer.new()
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_theme_constant_override("separation", 0)
		var name := _label(26, HORIZONTAL_ALIGNMENT_LEFT)
		text.add_child(name)
		var desc := _label(20, HORIZONTAL_ALIGNMENT_LEFT)
		desc.modulate = Color(0.85, 0.85, 0.9)
		desc.text = Meta.description(id)
		text.add_child(desc)
		row.add_child(text)
		var buy := _button("BUY", 24)
		buy.custom_minimum_size = Vector2(150.0, 52.0)
		buy.pressed.connect(func() -> void: buy_pressed.emit(id))
		row.add_child(buy)
		box.add_child(row)
		_shop_rows[id] = {"name": name, "buy": buy}
	var back := _button("BACK", 34)
	back.pressed.connect(func() -> void: shop_closed.emit())
	box.add_child(back)


func _build_daily(root: Control) -> void:
	_daily_card = _card(root)
	_daily_card.visible = false
	var box: VBoxContainer = _daily_card.get_meta("box")
	_daily_title = _label(48, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_daily_title)
	var blurb := _label(24, HORIZONTAL_ALIGNMENT_CENTER)
	blurb.text = "Same gates for everyone today.\nNo upgrades, rifles only. Best of the day counts."
	box.add_child(blurb)
	_daily_lines = _label(28, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_daily_lines)
	var play := _button("PLAY TODAY", 40)
	play.pressed.connect(func() -> void: play_pressed.emit("daily"))
	box.add_child(play)
	var copy := _button("COPY TODAY'S RESULT", 28)
	copy.pressed.connect(func() -> void: copy_pressed.emit())
	box.add_child(copy)
	var back := _button("BACK", 34)
	back.pressed.connect(func() -> void: shop_closed.emit())
	box.add_child(back)
	_toast = _label(30, HORIZONTAL_ALIGNMENT_CENTER)
	_toast.anchor_left = 0.0
	_toast.anchor_right = 1.0
	_toast.anchor_top = 0.86
	_toast.anchor_bottom = 0.86
	_toast.offset_bottom = 60.0
	_toast.modulate.a = 0.0
	_toast.add_theme_color_override("font_color", COIN)
	root.add_child(_toast)


func _build_combo(root: Control) -> void:
	_danger = ColorRect.new()
	_danger.color = Color(0.9, 0.1, 0.1, 0.0)
	_danger.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_danger.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_danger)
	_combo = _label(44, HORIZONTAL_ALIGNMENT_CENTER)
	_combo.anchor_left = 0.0
	_combo.anchor_right = 1.0
	_combo.anchor_top = 0.62
	_combo.anchor_bottom = 0.62
	_combo.offset_bottom = 60.0
	_combo.add_theme_color_override("font_color", COIN)
	_combo.modulate.a = 0.0
	_combo.pivot_offset = Vector2(360.0, 30.0)
	root.add_child(_combo)
	_combo_bar = ColorRect.new()
	_combo_bar.color = COIN
	_combo_bar.anchor_left = 0.4
	_combo_bar.anchor_right = 0.6
	_combo_bar.anchor_top = 0.62
	_combo_bar.anchor_bottom = 0.62
	_combo_bar.offset_top = 62.0
	_combo_bar.offset_bottom = 68.0
	_combo_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combo_bar.modulate.a = 0.0
	root.add_child(_combo_bar)


func _build_over(root: Control) -> void:
	_over_card = _card(root)
	_over_card.visible = false
	var box: VBoxContainer = _over_card.get_meta("box")
	_over_title = _label(64, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_over_title)
	_over_lines = _label(34, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_over_lines)
	_over_prompt = _label(40, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_over_prompt)
	_over_copy = _button("COPY RESULT", 28)
	_over_copy.pressed.connect(func() -> void: copy_pressed.emit())
	box.add_child(_over_copy)
	var menu := _button("MENU", 30)
	menu.pressed.connect(func() -> void: menu_pressed.emit())
	box.add_child(menu)


func _build_pause(root: Control) -> void:
	_pause_card = _card(root)
	_pause_card.visible = false
	var box: VBoxContainer = _pause_card.get_meta("box")
	var paused := _label(56, HORIZONTAL_ALIGNMENT_CENTER)
	paused.text = "PAUSED"
	box.add_child(paused)
	var resume := _button("RESUME", 40)
	resume.pressed.connect(func() -> void: resume_pressed.emit())
	box.add_child(resume)
	_sound_button = _button("SOUND: ON", 34)
	_sound_button.pressed.connect(_on_sound_pressed)
	box.add_child(_sound_button)
	_music_button = _button("MUSIC: ON", 34)
	_music_button.pressed.connect(_on_music_pressed)
	box.add_child(_music_button)
	_pause_characters = _button("CHARACTERS: OFF", 34)
	_pause_characters.pressed.connect(_on_characters_pressed)
	box.add_child(_pause_characters)
	var quit := _button("QUIT TO TITLE", 34)
	quit.pressed.connect(func() -> void: quit_pressed.emit())
	box.add_child(quit)


# --- state -----------------------------------------------------------------

func update_stats(count: int, level: int, distance: float, score: int) -> void:
	if _count.text != "%d" % count:
		_bump_count()
	_count.text = "%d" % count
	_level.text = "LV %d" % level
	_subline.text = "%d m   ·   %d" % [int(distance), score]


func set_sound(on: bool) -> void:
	_sound_button.text = "SOUND: ON" if on else "SOUND: OFF"
	_settings_sound.text = _sound_button.text


func set_music(on: bool) -> void:
	_music_button.text = "MUSIC: ON" if on else "MUSIC: OFF"
	_settings_music.text = _music_button.text


func set_characters(on: bool) -> void:
	_pause_characters.text = "CHARACTERS: ON" if on else "CHARACTERS: OFF"
	_settings_characters.text = _pause_characters.text
	_locker_button.visible = on
	_stars_title.visible = on


func set_formation(name: String) -> void:
	_formation_button.text = name


func set_bombs(n: int) -> void:
	_bomb_button.visible = n > 0 and _pause_button.visible
	_bomb_button.text = "BOMB x%d" % n


## A teaching line that holds for a while, then fades.
func show_hint(text: String, seconds: float = 3.2) -> void:
	if text == "":
		return
	_hint.text = text
	_hint.modulate.a = 0.0
	if _hint_tween != null:
		_hint_tween.kill()
	_hint_tween = create_tween()
	_hint_tween.tween_property(_hint, "modulate:a", 1.0, 0.3)
	_hint_tween.tween_interval(seconds)
	_hint_tween.tween_property(_hint, "modulate:a", 0.0, 0.5)


## Dash readiness under the squad: "DASH" when ready, cooling bar when not.
func set_dash(enabled: bool, ready: bool) -> void:
	_dash.modulate.a = 0.75 if enabled else 0.0
	_dash.text = "DASH READY" if ready else "..."


## Show both routes of the coming fork. [param routes] is the fork dict.
func show_fork(routes: Dictionary) -> void:
	_fork_box.visible = true
	for side in ["left", "right"]:
		var r: Dictionary = routes[side]
		var labels := []
		for p in r.panels:
			labels.append(GateMath.label(p))
		var text := "%s  %s
%s" % [r.name, "!".repeat(int(r.threat)), " · ".join(labels)]
		var l := _fork_left if side == "left" else _fork_right
		l.text = ("◀ " + text) if side == "left" else (text + " ▶")
		l.add_theme_color_override("font_color", Fork.RICH if r.name == "RICH" else Fork.SAFE)


func hide_fork() -> void:
	_fork_box.visible = false


## Active timed power-ups, e.g. "SLOW-MO 4s   SHIELD 2s".
func set_powers(text: String) -> void:
	_powers.text = text


func _hide_cards() -> void:
	_formation_button.visible = false
	_bomb_button.visible = false
	_powers.text = ""
	_fork_box.visible = false
	_hint.modulate.a = 0.0
	_dash.modulate.a = 0.0
	_title_card.visible = false
	_shop_card.visible = false
	_daily_card.visible = false
	_over_card.visible = false
	_pause_card.visible = false
	_settings_card.visible = false
	_locker_card.visible = false


func show_title(best: int, best_level: int, best_endless: int, coins: int, endless_unlocked: bool, squad_type: String, shotgun_unlocked: bool, stars: int = 0, hero_name: String = "") -> void:
	_hide_cards()
	_title_card.visible = true
	_pause_button.visible = false
	_boss_box.visible = false
	var lines := []
	if best > 0:
		lines.append("Best %d   ·   Level %d" % [best, best_level])
	if best_endless > 0:
		lines.append("Endless best %d" % best_endless)
	if lines.is_empty():
		lines.append("Every level starts with one soldier.")
	_records.text = "\n".join(lines)
	_endless_button.disabled = not endless_unlocked
	_endless_button.text = "ENDLESS" if endless_unlocked else "ENDLESS  (clear level %d)" % Meta.ENDLESS_UNLOCK_LEVEL
	_squad_button.visible = shotgun_unlocked
	_squad_button.text = "SQUAD: %s" % {"rifle": "RIFLES", "shotgun": "SHOTGUNS", "medic": "MEDICS"}.get(squad_type, "RIFLES")
	_coins_title.text = "%d COINS" % coins
	_stars_title.text = "%d STARS   ·   %s" % [stars, hero_name] if hero_name != "" else "%d STARS" % stars


func show_settings() -> void:
	_hide_cards()
	_settings_card.visible = true


## The locker: one tab of items. Owned items say so, the equipped one is
## pressed in, and anything you cannot afford is greyed.
func show_locker(w: Wardrobe, tab: String) -> void:
	_hide_cards()
	_locker_card.visible = true
	_locker_tab = tab
	_locker_stars.text = "%d STARS" % w.stars
	for cat in _locker_tabs.keys():
		var b: Button = _locker_tabs[cat]
		b.button_pressed = cat == tab
	for child in _locker_grid.get_children():
		_locker_grid.remove_child(child)
		child.queue_free()
	for id in Wardrobe.items_in(tab):
		var b := _button("", 20)
		b.custom_minimum_size = Vector2(196.0, 74.0)
		var state := ""
		if w.is_equipped(id):
			state = "WEARING"
		elif w.is_owned(id):
			state = "OWNED"
		else:
			state = "%d STARS" % Wardrobe.cost(id) if Wardrobe.cost(id) != 1 else "1 STAR"
			b.disabled = not w.can_buy(id)
		b.text = "%s\n%s" % [Wardrobe.title(id), state]
		b.toggle_mode = true
		b.button_pressed = w.is_equipped(id)
		b.pressed.connect(func() -> void: item_pressed.emit(id))
		_locker_grid.add_child(b)
	if tab == "hero":
		_locker_line.text = "%s: %s" % [w.hero_name(), Wardrobe.hero_line(w.equipped.get("hero", "max"))]
	else:
		_locker_line.text = "Stars come from bosses, perfect gates and finishing runs."


## [param results] maps day number to {score, level, kills, peak}.
func show_daily(day: int, results: Dictionary) -> void:
	_hide_cards()
	_daily_card.visible = true
	_daily_title.text = Daily.label(day)
	var lines := []
	var days := results.keys()
	days.sort()
	days.reverse()
	for d in days:
		var r: Dictionary = results[d]
		var tag := "today" if int(d) == day else "#%d" % int(d)
		lines.append("%s   %d pts   level %d" % [tag, int(r.get("score", 0)), int(r.get("level", 0))])
	if lines.is_empty():
		lines.append("No result yet today.")
	_daily_lines.text = "\n".join(lines)


func toast(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	if _toast_tween != null:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.2)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.4)


func show_shop(meta: Meta, coins: int) -> void:
	_hide_cards()
	_shop_card.visible = true
	_shop_coins.text = "%d COINS" % coins
	for id in Meta.ORDER:
		var row: Dictionary = _shop_rows[id]
		var lvl := meta.level(id)
		row.name.text = "%s   %d/%d" % [Meta.title(id), lvl, Meta.max_level(id)]
		var buy: Button = row.buy
		if meta.is_maxed(id):
			buy.text = "MAX"
			buy.disabled = true
		else:
			buy.text = "%d" % meta.cost(id)
			buy.disabled = not meta.can_buy(id, coins)


func show_running() -> void:
	_hide_cards()
	_pause_button.visible = true
	_formation_button.visible = true
	if _prompt_tween != null:
		_prompt_tween.kill()


func show_game_over(score: int, best: int, is_best: bool, level: int, distance: int, kills: int, peak: int, coins_earned: int, mode: String, stars_earned: int = 0, hero_name: String = "") -> void:
	_hide_cards()
	_over_card.visible = true
	_pause_button.visible = false
	_boss_box.visible = false
	# With characters on, the hero always gets out. Kids keep their people.
	_over_title.text = "%s ESCAPED" % hero_name if hero_name != "" else "WIPED OUT"
	var head := "NEW BEST!  %d" % score if is_best else "Score %d   (best %d)" % [score, best]
	var where := "Level %d   %d m" % [level, distance]
	if mode == "endless":
		where = "Endless   %d m" % distance
	elif mode == "daily":
		where = "Daily   level %d   %d m" % [level, distance]
	var coins_line := "no coins in the daily" if mode == "daily" else "+%d coins" % coins_earned
	if stars_earned > 0:
		coins_line += "   +%d %s" % [stars_earned, "star" if stars_earned == 1 else "stars"]
	_over_lines.text = "%s\n\n%s\n%d kills   peak squad %d\n\n%s" % [head, where, kills, peak, coins_line]
	_over_prompt.text = "TAP TO RETRY"
	_pulse_prompt()
	if is_best:
		flash(0.5)


## Kill streak readout: count, multiplier, and a bar that drains with the
## window. Hidden below a short chain so a single kill does not shout.
func set_combo(count: int, mult: float, remaining: float) -> void:
	if count < 3:
		_combo.modulate.a = 0.0
		_combo_bar.modulate.a = 0.0
		return
	var text := "%d COMBO" % count if mult <= 1.0 else "%d COMBO   x%.1f" % [count, mult]
	if _combo.text != text:
		_combo.scale = Vector2(1.2, 1.2)
		if _combo_tween != null:
			_combo_tween.kill()
		_combo_tween = create_tween()
		_combo_tween.tween_property(_combo, "scale", Vector2.ONE, 0.15)
	_combo.text = text
	_combo.modulate.a = 1.0
	_combo_bar.modulate.a = 0.9
	_combo_bar.anchor_right = 0.4 + 0.2 * remaining


## Red edge pulse when the squad is nearly gone. 0 = calm, 1 = last man.
func set_danger(level: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	_danger.color.a = level * (0.12 + 0.08 * sin(t * 9.0))


func show_paused(paused: bool) -> void:
	_pause_card.visible = paused
	_pause_button.visible = not paused


func show_boss(visible_now: bool) -> void:
	_boss_box.visible = visible_now
	if visible_now:
		set_boss_ratio(1.0)


func set_boss_ratio(ratio: float) -> void:
	var w := _boss_box.size.x - 6.0
	_boss_fill.offset_right = 3.0 + w * clampf(ratio, 0.0, 1.0)


## Big centred text that drifts up and fades, used for gate results.
func show_float(text: String, good: bool) -> void:
	_float.text = text
	_float.modulate = GAIN if good else LOSS
	_float.modulate.a = 1.0
	_float_anchor.position = Vector2(0.0, FLOAT_START_Y)
	if _float_tween != null:
		_float_tween.kill()
	_float_tween = create_tween()
	_float_tween.tween_property(_float_anchor, "position:y", FLOAT_START_Y - 120.0, 0.9)
	_float_tween.parallel().tween_property(_float, "modulate:a", 0.0, 0.9).set_delay(0.35)


## Level banner: fades in, holds, fades.
func show_banner(text: String, seconds: float = 1.6) -> void:
	_banner.text = text
	_banner.modulate.a = 0.0
	if _banner_tween != null:
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner, "modulate:a", 1.0, 0.2)
	_banner_tween.tween_interval(seconds)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.4)


func flash(strength: float) -> void:
	_flash.color.a = strength
	var tw := create_tween()
	tw.tween_property(_flash, "color:a", 0.0, 0.45)


func _bump_count() -> void:
	if _count_tween != null:
		_count_tween.kill()
	_count.scale = Vector2(1.25, 1.25)
	_count_tween = create_tween()
	_count_tween.tween_property(_count, "scale", Vector2.ONE, 0.18)


func _on_sound_pressed() -> void:
	var on := not _sound_button.text.ends_with("ON")
	set_sound(on)
	sound_toggled.emit(on)


func _on_characters_pressed() -> void:
	var on := not _pause_characters.text.ends_with("ON")
	set_characters(on)
	characters_toggled.emit(on)


func _on_music_pressed() -> void:
	var on := not _music_button.text.ends_with("ON")
	set_music(on)
	music_toggled.emit(on)


func _pulse_prompt() -> void:
	if _prompt_tween != null:
		_prompt_tween.kill()
	_over_prompt.modulate.a = 1.0
	_prompt_tween = create_tween().set_loops()
	_prompt_tween.tween_property(_over_prompt, "modulate:a", 0.35, 0.6)
	_prompt_tween.tween_property(_over_prompt, "modulate:a", 1.0, 0.6)


func _card(parent: Control) -> Control:
	var card := Control.new()
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(card)
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(center)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)
	card.set_meta("box", box)
	return card


func _label(size: int, align: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", OUTLINE)
	l.add_theme_constant_override("outline_size", int(size * 0.18))
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(text: String, size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_outline_color", OUTLINE)
	b.add_theme_constant_override("outline_size", int(size * 0.15))
	b.custom_minimum_size = Vector2(0.0, size * 1.9)
	b.focus_mode = Control.FOCUS_NONE
	return b


func _place(parent: Control, l: Label, left: float, right: float, top: float) -> void:
	l.anchor_left = left
	l.anchor_right = right
	l.anchor_top = 0.0
	l.anchor_bottom = 0.0
	l.offset_left = 20.0 if left == 0.0 else 0.0
	l.offset_right = -20.0 if right == 1.0 else 0.0
	l.offset_top = top
	l.offset_bottom = top + 80.0
	parent.add_child(l)
