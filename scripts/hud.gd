class_name Hud
extends CanvasLayer
## All 2D overlay: stats, boss bar, title card, game-over card, pause menu,
## floating gate text, level banner and the new-best flash. Keeps processing
## while the tree is paused so the pause menu works. Every passive control
## ignores the mouse so taps fall through to the game; only buttons catch.

signal pause_pressed
signal resume_pressed
signal sound_toggled(on: bool)
signal quit_pressed

const OUTLINE := Color(0.05, 0.05, 0.08)
const GAIN := Color(0.45, 0.9, 1.0)
const LOSS := Color(1.0, 0.4, 0.4)
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
var _overlay: Control
var _title: Label
var _lines: Label
var _prompt: Label
var _pause_overlay: Control
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

	_overlay = _card(root)
	_title = _label(64, HORIZONTAL_ALIGNMENT_CENTER)
	_lines = _label(34, HORIZONTAL_ALIGNMENT_CENTER)
	_prompt = _label(40, HORIZONTAL_ALIGNMENT_CENTER)
	var box: VBoxContainer = _overlay.get_meta("box")
	box.add_child(_title)
	box.add_child(_lines)
	box.add_child(_prompt)

	_pause_overlay = _card(root)
	_pause_overlay.visible = false
	var pbox: VBoxContainer = _pause_overlay.get_meta("box")
	var paused := _label(56, HORIZONTAL_ALIGNMENT_CENTER)
	paused.text = "PAUSED"
	pbox.add_child(paused)
	var resume := _button("RESUME", 40)
	resume.pressed.connect(func() -> void: resume_pressed.emit())
	pbox.add_child(resume)
	_sound_button = _button("SOUND: ON", 34)
	_sound_button.pressed.connect(_on_sound_pressed)
	pbox.add_child(_sound_button)
	var quit := _button("QUIT TO TITLE", 34)
	quit.pressed.connect(func() -> void: quit_pressed.emit())
	pbox.add_child(quit)


func update_stats(count: int, level: int, distance: float, score: int) -> void:
	if _count.text != "%d" % count:
		_bump_count()
	_count.text = "%d" % count
	_level.text = "LV %d" % level
	_subline.text = "%d m   ·   %d" % [int(distance), score]


func set_sound(on: bool) -> void:
	_sound_button.text = "SOUND: ON" if on else "SOUND: OFF"


func show_title(best: int, best_level: int) -> void:
	_overlay.visible = true
	_pause_overlay.visible = false
	_pause_button.visible = false
	_boss_box.visible = false
	_title.text = "SHOOTY\nMcBRIDGEFACE"
	var record := "Best: %d   ·   Level %d" % [best, best_level] if best > 0 else "Every level starts with one soldier."
	_lines.text = "Drag to steer. Pick a gate.\nShoot the numbers to grow them.\nKill the boss before it eats you.\n\n%s" % record
	_prompt.text = "TAP TO START"
	_pulse_prompt()


func show_running() -> void:
	_overlay.visible = false
	_pause_overlay.visible = false
	_pause_button.visible = true
	if _prompt_tween != null:
		_prompt_tween.kill()


func show_game_over(score: int, best: int, is_best: bool, level: int, distance: int, kills: int, peak: int) -> void:
	_overlay.visible = true
	_pause_overlay.visible = false
	_pause_button.visible = false
	_boss_box.visible = false
	_title.text = "WIPED OUT"
	var head := "NEW BEST!  %d" % score if is_best else "Score %d   (best %d)" % [score, best]
	_lines.text = "%s\n\nLevel %d   %d m\n%d kills   peak squad %d" % [head, level, distance, kills, peak]
	_prompt.text = "TAP TO RETRY"
	_pulse_prompt()
	if is_best:
		flash(0.5)


func show_paused(paused: bool) -> void:
	_pause_overlay.visible = paused
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


## Level banner: slides in, holds, fades.
func show_banner(text: String, seconds: float = 1.6) -> void:
	_banner.text = text
	_banner.modulate.a = 0.0
	_banner.scale = Vector2.ONE
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


func _pulse_prompt() -> void:
	if _prompt_tween != null:
		_prompt_tween.kill()
	_prompt.modulate.a = 1.0
	_prompt_tween = create_tween().set_loops()
	_prompt_tween.tween_property(_prompt, "modulate:a", 0.35, 0.6)
	_prompt_tween.tween_property(_prompt, "modulate:a", 1.0, 0.6)


func _card(parent: Control) -> Control:
	var card := Control.new()
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(card)
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.5)
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
	box.add_theme_constant_override("separation", 22)
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
