class_name Barricade
extends Node3D
## A wall across half the road: stacked concrete blocks under a striped
## board, with its own health. Shoot it down before it arrives or steer
## onto the open half; run into it and it takes a slice of the squad as
## it shatters. The world moves it and checks the hit; this is the look.

const BLOCK := Color(0.62, 0.62, 0.6)
const STRIPE_A := Color(1.0, 0.85, 0.2)
const STRIPE_B := Color(0.1, 0.1, 0.12)
const HEIGHT := 1.3

## -1 covers the left half of the road, 1 the right.
var side := 1
var hp := 10.0
var max_hp := 10.0
var passed := false
var half_width := 1.6
var center_x := 0.0
var _bar: MeshInstance3D
var _bar_bg: MeshInstance3D
var _hit_t := 0.0
var _body: Node3D


func setup(p_side: int, road_half: float, p_hp: float) -> void:
	side = p_side
	hp = p_hp
	max_hp = p_hp
	half_width = road_half * 0.5 - 0.15
	center_x = float(side) * road_half * 0.5
	position.x = center_x
	_body = Node3D.new()
	add_child(_body)
	var w := half_width * 2.0
	# Two courses of blocks, the upper one offset like brickwork.
	for row in range(2):
		var n := maxi(2, int(w / 1.1))
		var bw := w / float(n)
		for i in range(n):
			var block := Mats.gbox(Vector3(bw - 0.06, 0.52, 0.7), BLOCK.darkened(0.08 * float(row)), 0.7, 0.25, 7)
			block.position = Vector3(-w * 0.5 + bw * (float(i) + 0.5) + (bw * 0.5 if row == 1 and i < n - 1 else 0.0), 0.26 + float(row) * 0.54, 0.0)
			if row == 1 and i == n - 1:
				block.scale.x = 0.5
				block.position.x -= bw * 0.25
			Mats.ink(block, 0.02)
			_body.add_child(block)
	# The striped board on top, so the wall reads from far off.
	var stripes := maxi(4, int(w / 0.5))
	for i in range(stripes):
		var s := Mats.box(Vector3(w / float(stripes), 0.22, 0.12), STRIPE_A if i % 2 == 0 else STRIPE_B, true)
		s.position = Vector3(-w * 0.5 + (w / float(stripes)) * (float(i) + 0.5), HEIGHT - 0.11, 0.38)
		_body.add_child(s)
	# Health, shown once it has taken a hit.
	_bar_bg = Mats.box(Vector3(w * 0.8 + 0.04, 0.1, 0.1), Color(0.1, 0.1, 0.1), true)
	_bar_bg.position = Vector3(0.0, HEIGHT + 0.25, 0.0)
	_bar_bg.visible = false
	_body.add_child(_bar_bg)
	_bar = Mats.box(Vector3(w * 0.8, 0.08, 0.12), Color(1.0, 0.75, 0.2), true)
	_bar.position = Vector3(0.0, HEIGHT + 0.25, 0.0)
	_bar.visible = false
	_body.add_child(_bar)


func covers_x(x: float) -> bool:
	return absf(x - center_x) <= half_width


## Returns true when this hit broke the wall.
func take_damage(amount: float) -> bool:
	hp -= amount
	_hit_t = 1.0
	var ratio := clampf(hp / max_hp, 0.0, 1.0)
	_bar.scale.x = maxf(ratio, 0.001)
	_bar.position.x = -(1.0 - ratio) * half_width * 0.8
	_bar.visible = true
	_bar_bg.visible = true
	return hp <= 0.0


## Broken: the blocks drop and fade.
func shatter() -> void:
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_body, "scale", Vector3(1.15, 0.05, 1.15), 0.18)
	tw.tween_property(_body, "position:y", -0.1, 0.18)
	tw.chain().tween_callback(queue_free)


func _process(delta: float) -> void:
	if _hit_t > 0.0:
		_hit_t = maxf(0.0, _hit_t - delta * 6.0)
		_body.rotation.z = sin(_hit_t * 20.0) * 0.04 * _hit_t
