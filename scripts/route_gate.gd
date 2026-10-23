class_name RouteGate
extends Node3D
## A single-panel gate on one side of a fork. Only the squad on that route
## walks through it; bullets from either side can still shoot it up.

const COLOR_POST := Color(0.25, 0.25, 0.28)

var panel: GateMath.GatePanel
var side := -1
var passed := false
var steps_up := 0
var hot_enabled := false
var hot_phase := 0.0
var _view: GatePanelView


var width := GatePanelView.WIDTH


## [param road_half] is half the road; the route is one side of it.
func setup(p_panel: GateMath.GatePanel, p_side: int, road_half: float = 3.3) -> void:
	panel = p_panel
	side = p_side
	width = road_half - 0.35
	position.x = float(side) * road_half * 0.5
	_view = GatePanelView.new(width)
	_view.position = Vector3(0.0, GatePanelView.HEIGHT * 0.5, 0.0)
	add_child(_view)
	_view.refresh(panel)
	for x in [-width * 0.5 - 0.1, width * 0.5 + 0.1]:
		var post := Mats.box(Vector3(0.2, GatePanelView.HEIGHT + 0.3, 0.3), COLOR_POST)
		post.position = Vector3(x, (GatePanelView.HEIGHT + 0.3) * 0.5, 0.0)
		add_child(post)


func covers_x(x: float) -> bool:
	return absf(x - position.x) <= width * 0.5


func is_hot(t: float) -> bool:
	return hot_enabled and Progression.is_hot(t, hot_phase)


func update_hot(t: float) -> void:
	_view.set_hot(not passed and is_hot(t))


func register_hit(damage: float, step_cost: float) -> bool:
	var steps := GateMath.register_hit(panel, damage, step_cost)
	_view.refresh(panel)
	if steps > 0:
		steps_up += steps
		_view.pop()
	return steps > 0


func reveal() -> void:
	if not panel.revealed:
		panel.revealed = true
		_view.refresh(panel)


func choose() -> GateMath.GatePanel:
	passed = true
	_view.highlight()
	return panel


func skip() -> void:
	passed = true
	_view.dim()


func panel_position() -> Vector3:
	return _view.global_position
