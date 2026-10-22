class_name GateMath
extends RefCounted
## Pure gate arithmetic. No nodes, no scene tree, fully unit-testable.
##
## A gate is a pair of panels. The squad passes through exactly one panel and
## that panel's operation is applied to the squad count. Panels can be shot:
## every STEP of accumulated bullet damage nudges the panel's value upward.
## That is the core "your aim is a resource" decision of the game.

enum Kind { ADD, MUL, POWER }

## Multiplier panels cannot be shot past this.
const MUL_CAP := 5.0
## How much a multiplier panel grows per step.
const MUL_STEP := 0.5
## Multiplier panels are far more valuable per step, so each step costs more.
const MUL_COST_FACTOR := 3.0
## What a thief takes off an additive panel.
const STEAL_AMOUNT := 2.0
## How many soldiers a power-up is worth when weighing a gate.
const POWER_WORTH := 4


class GatePanel:
	var kind: int
	## ADD: signed integer count. MUL: multiplier >= 1.0. POWER: unused.
	var value: float
	## Hidden panels show "?" until revealed by proximity or by a bullet.
	var revealed: bool
	var shot_progress: float = 0.0
	## POWER panels carry a power-up id, or Powerups.MYSTERY.
	var power: String = ""

	func _init(p_kind: int, p_value: float, p_hidden: bool = false) -> void:
		kind = p_kind
		value = p_value
		revealed = not p_hidden


static func add(value: int, hidden: bool = false) -> GatePanel:
	return GatePanel.new(Kind.ADD, float(value), hidden)


static func mul(value: float, hidden: bool = false) -> GatePanel:
	return GatePanel.new(Kind.MUL, value, hidden)


## A panel that grants a power-up instead of changing the count.
static func power(id: String) -> GatePanel:
	var p := GatePanel.new(Kind.POWER, 0.0, false)
	p.power = id
	return p


## The squad count after walking through [param panel].
static func apply(count: int, panel: GatePanel) -> int:
	match panel.kind:
		Kind.ADD:
			return maxi(0, count + int(round(panel.value)))
		Kind.MUL:
			return maxi(0, int(floor(float(count) * panel.value)))
	return count


## True when the panel can only help (used for colouring, never for choice).
static func is_good(panel: GatePanel) -> bool:
	match panel.kind:
		Kind.ADD:
			return panel.value > 0.0
		Kind.MUL:
			return panel.value > 1.0
		Kind.POWER:
			return true
	return false


static func is_power(panel: GatePanel) -> bool:
	return panel.kind == Kind.POWER


## What the panel prints on its face.
static func label(panel: GatePanel) -> String:
	if not panel.revealed:
		return "?"
	match panel.kind:
		Kind.ADD:
			var v := int(round(panel.value))
			if v >= 0:
				return "+%d" % v
			return "%d" % v
		Kind.MUL:
			if is_equal_approx(panel.value, round(panel.value)):
				return "x%d" % int(round(panel.value))
			return "x%.1f" % panel.value
		Kind.POWER:
			return Powerups.title(panel.power)
	return "?"


## Register bullet damage on a panel. Returns how many steps the value climbed
## (usually 0 or 1; a heavy bullet can climb several at once).
## Callers pass a step cost scaled to the squad's damage output, so farming a
## gate yields about one step per second of committed fire at any squad size.
static func register_hit(panel: GatePanel, damage: float, step_cost: float) -> int:
	panel.revealed = true
	if step_cost <= 0.0 or panel.kind == Kind.POWER:
		return 0
	var cost := step_cost
	if panel.kind == Kind.MUL:
		cost *= MUL_COST_FACTOR
	panel.shot_progress += maxf(damage, 0.0)
	var steps := 0
	while panel.shot_progress >= cost:
		panel.shot_progress -= cost
		steps += 1
		match panel.kind:
			Kind.ADD:
				panel.value += 1.0
			Kind.MUL:
				panel.value = minf(panel.value + MUL_STEP, MUL_CAP)
	return steps


## A thief reached the panel: knock it down a notch. Additive panels lose
## STEAL_AMOUNT; multipliers lose a half step but never below x1.
static func steal(panel: GatePanel) -> void:
	panel.revealed = true
	match panel.kind:
		Kind.POWER:
			# A thief turns a known power-up into a mystery.
			panel.power = Powerups.MYSTERY
		Kind.ADD:
			panel.value -= STEAL_AMOUNT
		Kind.MUL:
			panel.value = maxf(1.0, panel.value - MUL_STEP)


## Index (0 or 1) of the panel that leaves the squad larger. Ties go left.
static func better_index(left: GatePanel, right: GatePanel, count: int) -> int:
	# A power-up counts as a handful of soldiers for the comparison.
	var l := apply(count, left) + (POWER_WORTH if is_power(left) else 0)
	var r := apply(count, right) + (POWER_WORTH if is_power(right) else 0)
	if l >= r:
		return 0
	return 1
