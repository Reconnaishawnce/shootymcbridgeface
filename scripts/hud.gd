class_name Hud
extends CanvasLayer
## All 2D overlay: stats, boss bar, title menu, shop, perk cards, game-over
## card, pause menu, floating gate text, level banner and the new-best
## flash. Keeps processing while the tree is paused so menus work. Every
## passive control ignores the mouse so taps fall through to the game;
## only buttons catch.

signal play_pressed(mode: String)
signal shop_opened
signal shop_closed
signal buy_pressed(id: String)
signal squad_toggled
signal menu_pressed
signal perk_chosen(id: String)
signal pause_pressed
signal resume_pressed
signal sound_toggled(on: bool)
signal quit_pressed

const OUTLINE := Color(0.05, 0.05, 0.08)
const GAIN := Color(0.45, 0.9, 1.0)
const LOSS := Color(1.0, 0.4, 0.4)
const COIN := Color(1.0, 0.85, 0.3)
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

var _shop_card: Control
var _shop_coins: Label
var _shop_rows: Dictionary = {}

var _perk_card: Control
var _perk_buttons: Array[Button] = []

var _over_card: Control
var _over_title: Label
var _over_lines: Label
var _over_prompt: Label

var _pause_card: Control
var _sound_button: Button

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
	_boss_box.offset_top = 140.0
	_boss_box.offset_bottom = 172.0
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

	_build_title(root)
	_build_shop(root)
	_build_perks(root)
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
	_squad_button = _button("SQUAD: RIFLES", 30)
	_squad_button.pressed.connect(func() -> void: squad_toggled.emit())
	box.add_child(_squad_button)
	var shop := _button("SHOP", 36)
	shop.pressed.connect(func() -> void: shop_opened.emit())
	box.add_child(shop)
	_coins_title = _label(28, HORIZONTAL_ALIGNMENT_CENTER)
	_coins_title.add_theme_color_override("font_color", COIN)
	box.add_child(_coins_title)


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


func _build_perks(root: Control) -> void:
	_perk_card = _card(root)
	_perk_card.visible = false
	var box: VBoxContainer = _perk_card.get_meta("box")
	var head := _label(44, HORIZONTAL_ALIGNMENT_CENTER)
	head.text = "CHOOSE A PERK"
	box.add_child(head)
	for i in range(Perks.CARDS):
		var b := _button("", 30)
		b.custom_minimum_size = Vector2(560.0, 120.0)
		b.add_theme_color_override("font_color", GAIN)
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.pressed.connect(_on_perk_button.bind(i))
		box.add_child(b)
		_perk_buttons.append(b)


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


func _hide_cards() -> void:
	_title_card.visible = false
	_shop_card.visible = false
	_perk_card.visible = false
	_over_card.visible = false
	_pause_card.visible = false


func show_title(best: int, best_level: int, best_endless: int, coins: int, endless_unlocked: bool, squad_type: String, shotgun_unlocked: bool) -> void:
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
	_squad_button.text = "SQUAD: SHOTGUNS" if squad_type == "shotgun" else "SQUAD: RIFLES"
	_coins_title.text = "%d COINS" % coins


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


func show_perks(ids: Array) -> void:
	_hide_cards()
	_perk_card.visible = true
	_pause_button.visible = false
	for i in range(_perk_buttons.size()):
		var b := _perk_buttons[i]
		if i < ids.size():
			b.visible = true
			b.text = "%s\n%s" % [Perks.title(ids[i]), Perks.description(ids[i])]
			b.set_meta("id", ids[i])
		else:
			b.visible = false


func show_running() -> void:
	_hide_cards()
	_pause_button.visible = true
	if _prompt_tween != null:
		_prompt_tween.kill()


func show_game_over(score: int, best: int, is_best: bool, level: int, distance: int, kills: int, peak: int, coins_earned: int, endless: bool) -> void:
	_hide_cards()
	_over_card.visible = true
	_pause_button.visible = false
	_boss_box.visible = false
	_over_title.text = "WIPED OUT"
	var head := "NEW BEST!  %d" % score if is_best else "Score %d   (best %d)" % [score, best]
	var where := "Endless   %d m" % distance if endless else "Level %d   %d m" % [level, distance]
	_over_lines.text = "%s\n\n%s\n%d kills   peak squad %d\n\n+%d coins" % [head, where, kills, peak, coins_earned]
	_over_prompt.text = "TAP TO RETRY"
	_pulse_prompt()
	if is_best:
		flash(0.5)


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


func _on_perk_button(i: int) -> void:
	var b := _perk_buttons[i]
	if b.has_meta("id"):
		perk_chosen.emit(b.get_meta("id"))


func _on_sound_pressed() -> void:
	var on := not _sound_button.text.ends_with("ON")
	set_sound(on)
	sound_toggled.emit(on)


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
