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
var steps_up: Array = []
## Hot panels flash on a timer; neighbouring panels are out of phase.
var hot_enabled := false
var hot_phase := 0.0
## Lane width this gate was built for; panels sit one per lane.
var lane_w := Progression.LANE_W
var _views: Array[GatePanelView] = []


## One panel per lane, left to right.
func setup(p_panels: Array, p_lane_w: float = Progression.LANE_W) -> void:
	panels = p_panels
	lane_w = p_lane_w
	steps_up = []
	var half := lane_w * float(panels.size()) * 0.5
	for i in range(panels.size()):
		steps_up.append(0)
		var v := GatePanelView.new(lane_w - 0.2)
		v.position = Vector3(panel_center_x(i), GatePanelView.HEIGHT * 0.5, 0.0)
		add_child(v)
		_views.append(v)
		v.refresh(panels[i])
	for i in range(panels.size() + 1):
		var post := Mats.box(Vector3(0.2, GatePanelView.HEIGHT + 0.3, 0.3), POST)
		post.position = Vector3(-half + float(i) * lane_w, (GatePanelView.HEIGHT + 0.3) * 0.5, 0.0)
		add_child(post)


func panel_center_x(i: int) -> float:
	var half := lane_w * float(panels.size()) * 0.5
	return -half + lane_w * (float(i) + 0.5)


## Panel index under x, or -1 outside the road.
func panel_index_at_x(x: float) -> int:
	var half := lane_w * float(panels.size()) * 0.5
	if absf(x) > half:
		return -1
	return clampi(int(floor((x + half) / lane_w)), 0, panels.size() - 1)


func is_hot(index: int, t: float) -> bool:
	return hot_enabled and Progression.is_hot(t, hot_phase + float(index) * Progression.HOT_PERIOD / float(maxi(panels.size(), 1)))


func update_hot(t: float) -> void:
	for i in range(_views.size()):
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
	for i in range(panels.size()):
		if not panels[i].revealed:
			panels[i].revealed = true
			_views[i].refresh(panels[i])


## Lock in the squad's choice. Returns the chosen panel.
func choose(index: int) -> GateMath.GatePanel:
	passed = true
	for i in range(_views.size()):
		if i == index:
			_views[i].highlight()
		else:
			_views[i].dim()
	return panels[index]
