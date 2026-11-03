class_name ShopIcon
extends Control
## A picture for a thing you can buy, drawn in code (this game has no
## textures). It idles with a small bob, bombs spark, eyes blink, and
## pop() bounces it when the thing is bought. Only draws while visible.

const INK := Color(0.05, 0.05, 0.08)
const BLUE := Color(0.35, 0.65, 1.0)
const RED := Color(1.0, 0.3, 0.3)
const GOLD := Color(1.0, 0.85, 0.3)
const STEEL := Color(0.75, 0.78, 0.85)
const OLIVE := Color(0.55, 0.6, 0.35)
const WHITE := Color(0.95, 0.95, 0.98)
const SKIN := Color(0.95, 0.75, 0.6)

var kind := "start"
## Dimmed when the thing cannot be bought.
var lit := true
var _t := 0.0
var _pop := 0.0
var _rng := RandomNumberGenerator.new()


func setup(p_kind: String, p_size: Vector2 = Vector2(120.0, 104.0)) -> void:
	kind = p_kind
	custom_minimum_size = p_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = hash(p_kind)
	_t = _rng.randf() * 6.0
	visibility_changed.connect(func() -> void: set_process(is_visible_in_tree()))
	set_process(is_visible_in_tree())


func pop() -> void:
	_pop = 1.0


func _process(delta: float) -> void:
	_t += delta
	_pop = maxf(0.0, _pop - delta * 2.2)
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var s := minf(size.x, size.y) * 0.42
	s *= 1.0 + 0.22 * sin(_pop * PI)
	c.y += sin(_t * 2.0) * s * 0.04
	var dim := 1.0 if lit else 0.45
	match kind:
		"start":
			_soldiers(c, s, dim)
		"power", "rounds":
			_bullet(c, s, dim)
		"gate":
			_gate(c, s, dim)
		"armor":
			_shield(c, s, dim)
		"belt", "bomb":
			_bomb(c, s, dim)
		"wind":
			_heart(c, s, dim)
		"slayer":
			_skull(c, s, dim)
		"magnet":
			_magnet(c, s, dim)
		"scout":
			_eye(c, s, dim)
		"shotgun":
			_shotgun(c, s, dim)
		"medic", "dressing":
			_cross(c, s, dim)
		"rifles":
			_rifle(c, s, dim)
		_:
			draw_circle(c, s * 0.5, GOLD * dim)


func _col(col: Color, dim: float) -> Color:
	return Color(col.r * dim, col.g * dim, col.b * dim, col.a)


func _soldier(p: Vector2, s: float, col: Color, dim: float) -> void:
	draw_circle(p + Vector2(0.0, -s * 0.55), s * 0.26, _col(SKIN, dim))
	draw_rect(Rect2(p.x - s * 0.3, p.y - s * 0.68, s * 0.6, s * 0.16), _col(col, dim))
	draw_colored_polygon(PackedVector2Array([p + Vector2(-s * 0.3, -s * 0.25), p + Vector2(s * 0.3, -s * 0.25), p + Vector2(s * 0.36, s * 0.5), p + Vector2(-s * 0.36, s * 0.5)]), _col(col, dim))
	draw_line(p + Vector2(s * 0.1, 0.0), p + Vector2(s * 0.62, -s * 0.22), _col(INK, dim), s * 0.1)


func _soldiers(c: Vector2, s: float, dim: float) -> void:
	_soldier(c + Vector2(-s * 0.7, s * 0.2), s * 0.8, BLUE, dim)
	_soldier(c + Vector2(s * 0.7, s * 0.2), s * 0.8, BLUE, dim)
	_soldier(c + Vector2(0.0, 0.0), s, BLUE.lightened(0.15), dim)
	draw_circle(c + Vector2(s * 0.85, -s * 0.65), s * 0.22, _col(GOLD, dim))
	draw_line(c + Vector2(s * 0.73, -s * 0.65), c + Vector2(s * 0.97, -s * 0.65), INK, s * 0.07)
	draw_line(c + Vector2(s * 0.85, -s * 0.77), c + Vector2(s * 0.85, -s * 0.53), INK, s * 0.07)


func _bullet(c: Vector2, s: float, dim: float) -> void:
	var tip := c + Vector2(s * 0.95, 0.0)
	draw_rect(Rect2(c.x - s * 0.9, c.y - s * 0.3, s * 1.2, s * 0.6), _col(STEEL.darkened(0.3), dim))
	draw_rect(Rect2(c.x - s * 0.9, c.y - s * 0.3, s * 0.35, s * 0.6), _col(GOLD, dim))
	draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.3, -s * 0.3), tip, c + Vector2(s * 0.3, s * 0.3)]), _col(STEEL, dim))
	for i in range(3):
		var y := c.y + (float(i) - 1.0) * s * 0.28
		var w := s * (0.5 + 0.3 * sin(_t * 9.0 + float(i)))
		draw_line(Vector2(c.x - s * 1.0 - w, y), Vector2(c.x - s * 1.05, y), _col(GOLD, dim), s * 0.06)
	var bolt := PackedVector2Array([c + Vector2(s * 0.3, -s * 1.0), c + Vector2(s * 0.0, -s * 0.5), c + Vector2(s * 0.25, -s * 0.5), c + Vector2(-s * 0.05, -s * 0.05), c + Vector2(s * 0.35, -s * 0.6), c + Vector2(s * 0.12, -s * 0.6)])
	draw_colored_polygon(bolt, _col(GOLD, dim))


func _gate(c: Vector2, s: float, dim: float) -> void:
	draw_arc(c + Vector2(0.0, s * 0.2), s * 0.85, PI, TAU, 24, _col(BLUE, dim), s * 0.22)
	draw_rect(Rect2(c.x - s * 0.96, c.y + s * 0.2, s * 0.22, s * 0.7), _col(BLUE, dim))
	draw_rect(Rect2(c.x + s * 0.74, c.y + s * 0.2, s * 0.22, s * 0.7), _col(BLUE, dim))
	var glow := 0.75 + 0.25 * sin(_t * 3.0)
	draw_line(c + Vector2(-s * 0.35, s * 0.2), c + Vector2(s * 0.35, s * 0.2), _col(WHITE * glow, dim), s * 0.14)
	draw_line(c + Vector2(0.0, -s * 0.15), c + Vector2(0.0, s * 0.55), _col(WHITE * glow, dim), s * 0.14)


func _shield(c: Vector2, s: float, dim: float) -> void:
	var pts := PackedVector2Array([c + Vector2(-s * 0.8, -s * 0.7), c + Vector2(0.0, -s * 0.9), c + Vector2(s * 0.8, -s * 0.7), c + Vector2(s * 0.7, s * 0.2), c + Vector2(0.0, s * 0.95), c + Vector2(-s * 0.7, s * 0.2)])
	draw_colored_polygon(pts, _col(STEEL.darkened(0.2), dim))
	var inner := PackedVector2Array()
	for p in pts:
		inner.append(c + (p - c) * 0.72)
	draw_colored_polygon(inner, _col(OLIVE, dim))
	draw_line(c + Vector2(0.0, -s * 0.55), c + Vector2(0.0, s * 0.6), _col(STEEL, dim), s * 0.1)
	draw_line(c + Vector2(-s * 0.45, -s * 0.1), c + Vector2(s * 0.45, -s * 0.1), _col(STEEL, dim), s * 0.1)
	var sheen := fmod(_t * 0.4, 1.0)
	draw_line(c + Vector2(-s * 0.9 + sheen * s * 1.8, -s * 0.9), c + Vector2(-s * 0.6 + sheen * s * 1.8, s * 0.9), Color(1.0, 1.0, 1.0, 0.18 * dim), s * 0.12)


func _bomb(c: Vector2, s: float, dim: float) -> void:
	draw_circle(c + Vector2(0.0, s * 0.2), s * 0.72, _col(Color(0.12, 0.12, 0.15), dim))
	draw_circle(c + Vector2(-s * 0.25, -s * 0.05), s * 0.18, Color(1.0, 1.0, 1.0, 0.25 * dim))
	draw_rect(Rect2(c.x - s * 0.2, c.y - s * 0.68, s * 0.4, s * 0.22), _col(STEEL, dim))
	draw_arc(c + Vector2(s * 0.45, -s * 0.75), s * 0.45, PI, PI * 1.6, 10, _col(Color(0.8, 0.6, 0.3), dim), s * 0.08)
	var spark := c + Vector2(s * 0.45 + cos(PI * 1.6) * s * 0.45, -s * 0.75 + sin(PI * 1.6) * s * 0.45)
	for i in range(5):
		var a := _t * 10.0 + float(i) * TAU / 5.0
		var r := s * (0.18 + 0.1 * sin(_t * 17.0 + float(i)))
		draw_line(spark, spark + Vector2(cos(a), sin(a)) * r, _col(GOLD, dim), s * 0.06)
	draw_circle(spark, s * 0.1, _col(WHITE, dim))


func _heart(c: Vector2, s: float, dim: float) -> void:
	var beat := 1.0 + 0.08 * maxf(0.0, sin(_t * 4.0))
	var pts := PackedVector2Array()
	for i in range(28):
		var a := float(i) / 28.0 * TAU
		var x := 16.0 * pow(sin(a), 3.0)
		var y := -(13.0 * cos(a) - 5.0 * cos(2.0 * a) - 2.0 * cos(3.0 * a) - cos(4.0 * a))
		pts.append(c + Vector2(x, y) * s * 0.055 * beat)
	draw_colored_polygon(pts, _col(RED, dim))
	draw_circle(c + Vector2(-s * 0.3, -s * 0.3), s * 0.14, Color(1.0, 1.0, 1.0, 0.35 * dim))
	for i in range(3):
		var y := c.y + (float(i) - 1.0) * s * 0.3
		var w := s * (0.4 + 0.2 * sin(_t * 6.0 + float(i) * 2.0))
		draw_line(Vector2(c.x + s * 1.0, y), Vector2(c.x + s * 1.0 + w, y), _col(WHITE, dim), s * 0.06)


func _skull(c: Vector2, s: float, dim: float) -> void:
	draw_circle(c + Vector2(0.0, -s * 0.15), s * 0.7, _col(WHITE, dim))
	draw_rect(Rect2(c.x - s * 0.42, c.y + s * 0.25, s * 0.84, s * 0.45), _col(WHITE, dim))
	draw_circle(c + Vector2(-s * 0.28, -s * 0.2), s * 0.2, _col(INK, dim))
	draw_circle(c + Vector2(s * 0.28, -s * 0.2), s * 0.2, _col(INK, dim))
	var glow := 0.5 + 0.5 * sin(_t * 5.0)
	draw_circle(c + Vector2(-s * 0.28, -s * 0.2), s * 0.08, _col(RED * glow, dim))
	draw_circle(c + Vector2(s * 0.28, -s * 0.2), s * 0.08, _col(RED * glow, dim))
	for i in range(3):
		draw_line(c + Vector2((float(i) - 1.0) * s * 0.22, s * 0.35), c + Vector2((float(i) - 1.0) * s * 0.22, s * 0.65), _col(INK, dim), s * 0.05)
	draw_line(c + Vector2(-s * 0.95, s * 0.9), c + Vector2(s * 0.95, -s * 0.9), _col(GOLD, dim), s * 0.12)


func _magnet(c: Vector2, s: float, dim: float) -> void:
	draw_arc(c + Vector2(0.0, -s * 0.1), s * 0.6, PI, TAU, 20, _col(RED, dim), s * 0.34)
	for sx in [-1.0, 1.0]:
		draw_rect(Rect2(c.x + sx * s * 0.6 - s * 0.17, c.y - s * 0.1, s * 0.34, s * 0.55), _col(RED, dim))
		draw_rect(Rect2(c.x + sx * s * 0.6 - s * 0.17, c.y + s * 0.3, s * 0.34, s * 0.3), _col(STEEL, dim))
	for i in range(3):
		var ph := fmod(_t * 0.8 + float(i) * 0.33, 1.0)
		var p := c + Vector2((float(i) - 1.0) * s * 0.55, s * 1.1 - ph * s * 0.6)
		draw_circle(p, s * 0.16, _col(GOLD, dim) * Color(1, 1, 1, 1.0 - ph * 0.7))


func _eye(c: Vector2, s: float, dim: float) -> void:
	var blink := 1.0 if fmod(_t, 3.2) > 0.15 else 0.1
	var pts := PackedVector2Array()
	for i in range(24):
		var a := float(i) / 24.0 * TAU
		pts.append(c + Vector2(cos(a) * s * 0.95, sin(a) * s * 0.55 * blink))
	draw_colored_polygon(pts, _col(WHITE, dim))
	draw_circle(c, s * 0.38 * blink, _col(BLUE, dim))
	draw_circle(c, s * 0.18 * blink, _col(INK, dim))
	draw_circle(c + Vector2(-s * 0.1, -s * 0.12), s * 0.07 * blink, WHITE)
	for i in range(6):
		var a := -PI * 0.9 + float(i) * PI * 0.8 / 5.0
		draw_line(c + Vector2(cos(a), sin(a)) * s * 0.75, c + Vector2(cos(a), sin(a)) * s * 1.0, _col(GOLD, dim), s * 0.06)


func _shotgun(c: Vector2, s: float, dim: float) -> void:
	draw_rect(Rect2(c.x - s * 1.0, c.y - s * 0.12, s * 0.9, s * 0.24), _col(STEEL.darkened(0.35), dim))
	draw_rect(Rect2(c.x - s * 1.0, c.y - s * 0.02, s * 0.5, s * 0.4), _col(Color(0.5, 0.33, 0.2), dim))
	draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.1, -s * 0.16), c + Vector2(s * 0.3, -s * 0.22), c + Vector2(s * 0.3, s * 0.22), c + Vector2(-s * 0.1, s * 0.16)]), _col(STEEL, dim))
	var ph := fmod(_t * 1.5, 1.0)
	for i in range(5):
		var a := (float(i) - 2.0) * 0.25
		var d := s * (0.4 + ph * 0.6)
		draw_circle(c + Vector2(s * 0.3 + cos(a) * d, sin(a) * d), s * 0.08, _col(GOLD, dim) * Color(1, 1, 1, 1.0 - ph * 0.6))


func _cross(c: Vector2, s: float, dim: float) -> void:
	draw_circle(c, s * 0.9, _col(WHITE, dim))
	draw_rect(Rect2(c.x - s * 0.2, c.y - s * 0.6, s * 0.4, s * 1.2), _col(RED, dim))
	draw_rect(Rect2(c.x - s * 0.6, c.y - s * 0.2, s * 1.2, s * 0.4), _col(RED, dim))
	var pulse := 0.9 + 0.1 * sin(_t * 4.0)
	draw_arc(c, s * 0.9 * pulse, 0.0, TAU, 32, Color(1.0, 0.4, 0.4, 0.35 * dim), s * 0.05)


func _rifle(c: Vector2, s: float, dim: float) -> void:
	draw_rect(Rect2(c.x - s * 0.9, c.y - s * 0.08, s * 1.8, s * 0.16), _col(STEEL.darkened(0.35), dim))
	draw_rect(Rect2(c.x - s * 0.9, c.y - s * 0.02, s * 0.5, s * 0.36), _col(Color(0.5, 0.33, 0.2), dim))
	draw_rect(Rect2(c.x - s * 0.1, c.y + s * 0.08, s * 0.2, s * 0.4), _col(INK, dim))
	draw_rect(Rect2(c.x - s * 0.3, c.y - s * 0.3, s * 0.5, s * 0.08), _col(STEEL, dim))
	for i in range(3):
		var ph := fmod(_t * 2.5 + float(i) * 0.33, 1.0)
		draw_circle(c + Vector2(s * 0.95 + ph * s * 0.5, 0.0), s * 0.07, _col(GOLD, dim) * Color(1, 1, 1, 1.0 - ph))
