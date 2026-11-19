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
## 0 to 1: how hard the picture rattles (a chest about to open).
var shake := 0.0
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
	if shake > 0.0:
		c.x += sin(_t * 46.0) * s * 0.07 * shake
		c.y += cos(_t * 39.0) * s * 0.03 * shake
	if kind.begins_with("chest"):
		# "chest:silver" closed, "chestopen:silver" open.
		_chest(c, s, dim, kind.get_slice(":", 1), kind.begins_with("chestopen"))
		return
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
		"turret":
			_turret(c, s, dim)
		"hero":
			_hero(c, s, dim)
		"ricochet":
			_ricochet(c, s, dim)
		"burn":
			_flame(c, s, dim)
		"frost":
			_frost(c, s, dim)
		"charge":
			_charge(c, s, dim)
		"martyr":
			_burst(c, s, dim)
		"crit":
			_crosshair(c, s, dim)
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


func _hero(c: Vector2, s: float, dim: float) -> void:
	# A blue soldier with a burst of rays: the move.
	var pulse := 1.0 + 0.08 * sin(_t * 4.0)
	for i in range(8):
		var a := float(i) * TAU / 8.0 + _t * 0.6
		draw_line(c + Vector2(cos(a), sin(a)) * s * 0.55 * pulse, c + Vector2(cos(a), sin(a)) * s * (0.95 + 0.08 * sin(_t * 7.0 + float(i))) * pulse, _col(GOLD, dim), s * 0.07)
	_soldier(c + Vector2(0.0, s * 0.1), s * 1.05, BLUE, dim)


func _turret(c: Vector2, s: float, dim: float) -> void:
	# A gold drum, a head with twin barrels, a flash at the muzzle.
	draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.9, s * 0.9), c + Vector2(s * 0.9, s * 0.9), c + Vector2(s * 0.6, s * 0.35), c + Vector2(-s * 0.6, s * 0.35)]), _col(GOLD.darkened(0.25), dim))
	draw_rect(Rect2(c.x - s * 0.55, c.y - s * 0.2, s * 1.1, s * 0.6), _col(GOLD, dim))
	draw_rect(Rect2(c.x - s * 0.3, c.y - s * 0.05, s * 0.9, s * 0.12), _col(STEEL.darkened(0.3), dim))
	draw_rect(Rect2(c.x - s * 0.3, c.y + s * 0.15, s * 0.9, s * 0.12), _col(STEEL.darkened(0.3), dim))
	draw_circle(c + Vector2(-s * 0.2, -s * 0.4), s * 0.16, _col(WHITE, dim))
	var ph := fmod(_t * 3.0, 1.0)
	for i in range(4):
		var a := ph * TAU * 0.5 + float(i) * TAU / 4.0
		draw_line(c + Vector2(s * 0.75, s * 0.1), c + Vector2(s * 0.75, s * 0.1) + Vector2(cos(a), sin(a)) * s * (0.2 + 0.1 * sin(_t * 9.0)), _col(GOLD, dim), s * 0.06)


# --- chests ----------------------------------------------------------------

const CHEST_COLORS := {"wood": Color(0.6, 0.38, 0.2), "silver": Color(0.72, 0.76, 0.86), "gold": Color(1.0, 0.8, 0.25)}


func _chest(c: Vector2, s: float, dim: float, tier: String, open: bool) -> void:
	var body: Color = CHEST_COLORS.get(tier, CHEST_COLORS["wood"])
	var trim := GOLD if tier != "gold" else Color(1.0, 0.97, 0.75)
	if open:
		# Light pours out: slow rays behind, then the glow in the mouth.
		for i in range(10):
			var a := _t * 0.6 + float(i) * TAU / 10.0
			var d := Vector2(cos(a), sin(a))
			var side := Vector2(-d.y, d.x)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0.0, -s * 0.2), c + Vector2(0.0, -s * 0.2) + d * s * 1.9 + side * s * 0.2, c + Vector2(0.0, -s * 0.2) + d * s * 1.9 - side * s * 0.2]), Color(1.0, 0.9, 0.45, 0.22 * dim))
	# The box.
	draw_rect(Rect2(c.x - s * 0.95, c.y - s * 0.05, s * 1.9, s * 0.95), _col(body, dim))
	draw_rect(Rect2(c.x - s * 0.95, c.y - s * 0.05, s * 1.9, s * 0.95), _col(INK, dim), false, s * 0.07)
	for x in [-0.6, 0.6]:
		draw_rect(Rect2(c.x + s * x - s * 0.09, c.y - s * 0.05, s * 0.18, s * 0.95), _col(trim.darkened(0.15), dim))
	if open:
		# The lid stands up behind; coins and sparks hop out.
		draw_rect(Rect2(c.x - s * 0.95, c.y - s * 0.95, s * 1.9, s * 0.42), _col(body.darkened(0.25), dim))
		draw_rect(Rect2(c.x - s * 0.95, c.y - s * 0.95, s * 1.9, s * 0.42), _col(INK, dim), false, s * 0.07)
		draw_rect(Rect2(c.x - s * 0.85, c.y - s * 0.5, s * 1.7, s * 0.46), _col(Color(1.0, 0.92, 0.5), dim))
		for i in range(5):
			var ph := fmod(_t * 0.9 + float(i) * 0.2, 1.0)
			var x := c.x + (float(i) - 2.0) * s * 0.34
			draw_circle(Vector2(x, c.y - s * 0.35 - sin(ph * PI) * s * 0.75), s * 0.13, _col(GOLD, dim))
	else:
		# A rounded lid, a band, a lock.
		draw_rect(Rect2(c.x - s * 0.95, c.y - s * 0.62, s * 1.9, s * 0.6), _col(body.lightened(0.12), dim))
		draw_circle(Vector2(c.x - s * 0.65, c.y - s * 0.62), s * 0.3, _col(body.lightened(0.12), dim))
		draw_circle(Vector2(c.x + s * 0.65, c.y - s * 0.62), s * 0.3, _col(body.lightened(0.12), dim))
		draw_rect(Rect2(c.x - s * 0.65, c.y - s * 0.92, s * 1.3, s * 0.32), _col(body.lightened(0.12), dim))
		draw_rect(Rect2(c.x - s * 0.95, c.y - s * 0.1, s * 1.9, s * 0.12), _col(trim, dim))
		draw_rect(Rect2(c.x - s * 0.17, c.y - s * 0.2, s * 0.34, s * 0.42), _col(trim, dim))
		draw_circle(Vector2(c.x, c.y - s * 0.02), s * 0.07, _col(INK, dim))


# --- build cards -----------------------------------------------------------

func _ricochet(c: Vector2, s: float, dim: float) -> void:
	# A tracer that zigzags off two heads.
	var pts := [c + Vector2(-s * 1.0, s * 0.6), c + Vector2(-s * 0.2, -s * 0.45), c + Vector2(s * 0.35, s * 0.4), c + Vector2(s * 1.0, -s * 0.55)]
	for i in range(pts.size() - 1):
		draw_line(pts[i], pts[i + 1], _col(GOLD, dim), s * 0.11)
	for i in [1, 2]:
		draw_circle(pts[i], s * (0.24 + 0.05 * sin(_t * 7.0 + float(i))), _col(Color(0.45, 0.75, 0.4), dim))
		draw_circle(pts[i] + Vector2(-s * 0.08, -s * 0.04), s * 0.05, _col(RED, dim))
		draw_circle(pts[i] + Vector2(s * 0.08, -s * 0.04), s * 0.05, _col(RED, dim))
	var ph := fmod(_t * 1.6, 1.0) * 3.0
	var seg := mini(2, int(ph))
	draw_circle(pts[seg].lerp(pts[seg + 1], ph - float(seg)), s * 0.12, _col(WHITE, dim))


func _flame(c: Vector2, s: float, dim: float) -> void:
	var w := 0.12 * sin(_t * 8.0)
	var outer := PackedVector2Array([c + Vector2(0.0, -s * (1.0 + w)), c + Vector2(s * 0.55, -s * 0.15), c + Vector2(s * 0.6, s * 0.45), c + Vector2(s * 0.25, s * 0.9), c + Vector2(-s * 0.25, s * 0.9), c + Vector2(-s * 0.6, s * 0.45), c + Vector2(-s * 0.45, -s * 0.25), c + Vector2(-s * 0.15, -s * 0.1)])
	draw_colored_polygon(outer, _col(Color(1.0, 0.45, 0.1), dim))
	var inner := PackedVector2Array([c + Vector2(s * 0.05, -s * (0.35 - w)), c + Vector2(s * 0.3, s * 0.3), c + Vector2(s * 0.15, s * 0.8), c + Vector2(-s * 0.15, s * 0.8), c + Vector2(-s * 0.3, s * 0.35)])
	draw_colored_polygon(inner, _col(GOLD, dim))


func _frost(c: Vector2, s: float, dim: float) -> void:
	# A six-armed snowflake that turns slowly.
	var ice := Color(0.6, 0.88, 1.0)
	for i in range(6):
		var a := _t * 0.5 + float(i) * TAU / 6.0
		var d := Vector2(cos(a), sin(a))
		draw_line(c, c + d * s * 0.95, _col(ice, dim), s * 0.1)
		var mid := c + d * s * 0.6
		var side := Vector2(-d.y, d.x)
		draw_line(mid, mid + (d + side).normalized() * s * 0.28, _col(ice, dim), s * 0.07)
		draw_line(mid, mid + (d - side).normalized() * s * 0.28, _col(ice, dim), s * 0.07)
	draw_circle(c, s * 0.16, _col(WHITE, dim))


func _charge(c: Vector2, s: float, dim: float) -> void:
	# A dial filling up around a bolt.
	draw_arc(c, s * 0.85, 0.0, TAU, 32, _col(STEEL.darkened(0.4), dim), s * 0.14)
	draw_arc(c, s * 0.85, -PI * 0.5, -PI * 0.5 + TAU * fmod(_t * 0.6, 1.0), 32, _col(GOLD, dim), s * 0.14)
	var bolt := PackedVector2Array([c + Vector2(s * 0.2, -s * 0.6), c + Vector2(-s * 0.3, s * 0.05), c + Vector2(-s * 0.02, s * 0.05), c + Vector2(-s * 0.2, s * 0.6), c + Vector2(s * 0.3, -s * 0.1), c + Vector2(s * 0.03, -s * 0.1)])
	draw_colored_polygon(bolt, _col(GOLD, dim))


func _burst(c: Vector2, s: float, dim: float) -> void:
	# A soldier's helmet in the middle of a starburst.
	var pts := PackedVector2Array()
	for i in range(16):
		var a := float(i) * TAU / 16.0 + _t * 0.4
		var r := s * (1.0 if i % 2 == 0 else 0.55) * (1.0 + 0.06 * sin(_t * 9.0))
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(pts, _col(Color(1.0, 0.5, 0.15), dim))
	draw_circle(c, s * 0.34, _col(BLUE, dim))
	draw_rect(Rect2(c.x - s * 0.36, c.y - s * 0.02, s * 0.72, s * 0.14), _col(BLUE.darkened(0.3), dim))


func _crosshair(c: Vector2, s: float, dim: float) -> void:
	draw_arc(c, s * 0.75, 0.0, TAU, 32, _col(RED, dim), s * 0.1)
	for i in range(4):
		var d := Vector2(cos(float(i) * PI * 0.5), sin(float(i) * PI * 0.5))
		draw_line(c + d * s * 0.45, c + d * s * 1.05, _col(RED, dim), s * 0.1)
	draw_circle(c, s * (0.14 + 0.05 * sin(_t * 6.0)), _col(WHITE, dim))


func _rifle(c: Vector2, s: float, dim: float) -> void:
	draw_rect(Rect2(c.x - s * 0.9, c.y - s * 0.08, s * 1.8, s * 0.16), _col(STEEL.darkened(0.35), dim))
	draw_rect(Rect2(c.x - s * 0.9, c.y - s * 0.02, s * 0.5, s * 0.36), _col(Color(0.5, 0.33, 0.2), dim))
	draw_rect(Rect2(c.x - s * 0.1, c.y + s * 0.08, s * 0.2, s * 0.4), _col(INK, dim))
	draw_rect(Rect2(c.x - s * 0.3, c.y - s * 0.3, s * 0.5, s * 0.08), _col(STEEL, dim))
	for i in range(3):
		var ph := fmod(_t * 2.5 + float(i) * 0.33, 1.0)
		draw_circle(c + Vector2(s * 0.95 + ph * s * 0.5, 0.0), s * 0.07, _col(GOLD, dim) * Color(1, 1, 1, 1.0 - ph))
