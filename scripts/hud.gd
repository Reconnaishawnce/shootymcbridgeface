class_name Hud
extends CanvasLayer
## All 2D overlay: stats bar, title card, game-over card, floating gate text.
## Every control ignores the mouse so taps fall through to the game.

const OUTLINE := Color(0.05, 0.05, 0.08)
const GAIN := Color(0.45, 0.9, 1.0)
const LOSS := Color(1.0, 0.4, 0.4)
## Gate result text starts a little above centre so it never covers the squad.
const FLOAT_START_Y := -140.0

var _count: Label
var _distance: Label
var _score: Label
var _overlay: Control
var _title: Label
var _lines: Label
var _prompt: Label
var _float_anchor: Control
var _float: Label
var _float_tween: Tween
var _prompt_tween: Tween


func _init() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_distance = _label(34, HORIZONTAL_ALIGNMENT_LEFT)
	_place(root, _distance, 0.0, 0.34, 28.0)
	_count = _label(64, HORIZONTAL_ALIGNMENT_CENTER)
	_place(root, _count, 0.3, 0.7, 14.0)
	_score = _label(34, HORIZONTAL_ALIGNMENT_RIGHT)
	_place(root, _score, 0.66, 1.0, 28.0)

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

	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_overlay)
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.45)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(center)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)
	_title = _label(64, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_title)
	_lines = _label(34, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_lines)
	_prompt = _label(40, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_prompt)


func update_stats(count: int, distance: float, score: int) -> void:
	_count.text = "%d" % count
	_distance.text = "%d m" % int(distance)
	_score.text = "%d" % score


func show_title(best: int) -> void:
	_overlay.visible = true
	_title.text = "SHOOTY\nMcBRIDGEFACE"
	_lines.text = "Drag to steer. Pick a gate.\nShoot the numbers to grow them.\n\nBest: %d" % best
	_prompt.text = "TAP TO START"
	_pulse_prompt()


func show_running() -> void:
	_overlay.visible = false
	if _prompt_tween != null:
		_prompt_tween.kill()


func show_game_over(score: int, best: int, is_best: bool, distance: int, kills: int, peak: int) -> void:
	_overlay.visible = true
	_title.text = "WIPED OUT"
	var head := "NEW BEST!  %d" % score if is_best else "Score %d   (best %d)" % [score, best]
	_lines.text = "%s\n\n%d m   %d kills   peak squad %d" % [head, distance, kills, peak]
	_prompt.text = "TAP TO RETRY"
	_pulse_prompt()


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


func _pulse_prompt() -> void:
	if _prompt_tween != null:
		_prompt_tween.kill()
	_prompt.modulate.a = 1.0
	_prompt_tween = create_tween().set_loops()
	_prompt_tween.tween_property(_prompt, "modulate:a", 0.35, 0.6)
	_prompt_tween.tween_property(_prompt, "modulate:a", 1.0, 0.6)


func _label(size: int, align: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", OUTLINE)
	l.add_theme_constant_override("outline_size", int(size * 0.18))
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


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
