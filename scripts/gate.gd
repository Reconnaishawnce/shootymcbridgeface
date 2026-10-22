class_name Gate
extends Node3D
## A pair of panels spanning the lane. Scrolled by the world; chosen by the
## squad's x position at the moment it passes z = 0.

const POST := Color(0.25, 0.25, 0.28)

var panels: Array = []
var passed := false
## 0-based position inside its level.
var index := 0
## Steps the player shot each panel up, for the PERFECT bonus.
var steps_up := [0, 0]
## Hot panels flash on a timer; the two sides are out of phase.
var hot_enabled := false
var hot_phase := 0.0
var _views: Array[GatePanelView] = []


func setup(left: GateMath.GatePanel, right: GateMath.GatePanel) -> void:
	panels = [left, right]
	for i in range(2):
		var v := GatePanelView.new()
		v.position = Vector3(-GatePanelView.CENTER_X if i == 0 else GatePanelView.CENTER_X, GatePanelView.HEIGHT * 0.5, 0.0)
		add_child(v)
		_views.append(v)
		v.refresh(panels[i])
	for x in [-3.3, 0.0, 3.3]:
		var post := Mats.box(Vector3(0.2, GatePanelView.HEIGHT + 0.3, 0.3), POST)
		post.position = Vector3(x, (GatePanelView.HEIGHT + 0.3) * 0.5, 0.0)
		add_child(post)


## 0 for the left panel, 1 for the right, -1 for the gap or outside the lane.
func panel_index_at_x(x: float) -> int:
	var half := GatePanelView.WIDTH * 0.5
	if absf(x + GatePanelView.CENTER_X) <= half:
		return 0
	if absf(x - GatePanelView.CENTER_X) <= half:
		return 1
	return -1


func is_hot(index: int, t: float) -> bool:
	return hot_enabled and Progression.is_hot(t, hot_phase + float(index) * Progression.HOT_PERIOD * 0.5)


func update_hot(t: float) -> void:
	for i in range(2):
		_views[i].set_hot(not passed and is_hot(i, t))


## Returns true when the hit stepped the panel's value up.
func register_hit(index: int, damage: float, step_cost: float) -> bool:
	var steps := GateMath.register_hit(panels[index], damage, step_cost)
	_views[index].refresh(panels[index])
	if steps > 0:
		steps_up[index] += steps
		_views[index].pop()
	return steps > 0


## World position of a panel's centre, for effects.
func panel_position(index: int) -> Vector3:
	return _views[index].global_position


## A thief got here: knock the panel down and show it.
func rob(index: int) -> void:
	GateMath.steal(panels[index])
	_views[index].refresh(panels[index])
	_views[index].pop()


func reveal_all() -> void:
	for i in range(2):
		if not panels[i].revealed:
			panels[i].revealed = true
			_views[i].refresh(panels[i])


## Lock in the squad's choice. Returns the chosen panel.
func choose(index: int) -> GateMath.GatePanel:
	passed = true
	_views[index].highlight()
	_views[1 - index].dim()
	return panels[index]
