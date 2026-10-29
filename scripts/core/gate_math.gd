class_name GateMath
extends RefCounted
## Pure gate arithmetic. No nodes, no scene tree, fully unit-testable.
##
## A gate is a row of panels, one per lane. The squad passes through exactly one and
## that panel's operation is applied to the squad count. Panels can be shot:
## every STEP of accumulated bullet damage nudges the panel's value upward.
## That is the core "your aim is a resource" decision of the game.

enum Kind { ADD, MUL, POWER, EXPR, TRADE, BET, SCOUT, VEHICLE, SUPPLY }
## Gates a scout party reveals ahead.
const SCOUT_GATES := 3

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
	## EXPR panels: a short sum applied left to right, [[kind, value], ...].
	var ops: Array = []
	## SUPPLY panels: soldiers delivered when the power is "soldiers".
	var amount: int = 0

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


## A trade: pay [param cost] soldiers for power-up [param id], now.
static func trade(cost: int, id: String) -> GatePanel:
	var p := GatePanel.new(Kind.TRADE, float(-absi(cost)), false)
	p.power = id
	return p


## A convoy vehicle: [param cost] soldiers climb aboard a [param id].
static func vehicle(id: String) -> GatePanel:
	var p := GatePanel.new(Kind.VEHICLE, float(-Convoy.cost(id)), false)
	p.power = id
	return p


static func is_vehicle(panel: GatePanel) -> bool:
	return panel.kind == Kind.VEHICLE


## Supply: pay [param cost] coins out of this run's bounty for power-up
## [param id] now, or for [param amount] soldiers when [param id] is
## "soldiers". The world checks the funds; the count only changes when
## the squad can pay.
static func supply(cost: int, id: String, amount: int = 0) -> GatePanel:
	var p := GatePanel.new(Kind.SUPPLY, float(-absi(cost)), false)
	p.power = id
	p.amount = amount
	return p


static func is_supply(panel: GatePanel) -> bool:
	return panel.kind == Kind.SUPPLY


static func supply_cost(panel: GatePanel) -> int:
	return int(round(-panel.value))


## Scouts: send [param cost] soldiers ahead and the next SCOUT_GATES gates
## show every panel, hidden or not, as soon as they appear.
static func scout(cost: int) -> GatePanel:
	return GatePanel.new(Kind.SCOUT, float(-absi(cost)), false)


static func is_scout(panel: GatePanel) -> bool:
	return panel.kind == Kind.SCOUT


## A bet: walk through and clear the next wave without a bite to double the
## squad; take a bite and it halves. The world resolves it.
static func bet() -> GatePanel:
	return GatePanel.new(Kind.BET, 0.0, false)


## A sum: [[Kind.ADD, 3], [Kind.MUL, 2.0]] reads "+3 x2" and is applied in
## that order. The player has to think, which is the point.
static func expr(ops: Array, hidden: bool = false) -> GatePanel:
	var p := GatePanel.new(Kind.EXPR, 0.0, hidden)
	for op in ops:
		p.ops.append([int(op[0]), float(op[1])])
	return p


static func _apply_op(count: int, kind: int, value: float) -> int:
	match kind:
		Kind.ADD:
			return maxi(0, count + int(round(value)))
		Kind.MUL:
			return maxi(0, int(floor(float(count) * value)))
	return count


static func _op_label(kind: int, value: float) -> String:
	match kind:
		Kind.ADD:
			var v := int(round(value))
			return ("+%d" % v) if v >= 0 else ("%d" % v)
		Kind.MUL:
			if is_equal_approx(value, 0.5):
				return "÷2"
			if is_equal_approx(value, round(value)):
				return "x%d" % int(round(value))
			return "x%.1f" % value
	return "?"


## The squad count after walking through [param panel].
static func apply(count: int, panel: GatePanel) -> int:
	match panel.kind:
		Kind.ADD:
			return maxi(0, count + int(round(panel.value)))
		Kind.MUL:
			return maxi(0, int(floor(float(count) * panel.value)))
		Kind.EXPR:
			var c := count
			for op in panel.ops:
				c = _apply_op(c, int(op[0]), float(op[1]))
			return c
		Kind.TRADE, Kind.SCOUT, Kind.VEHICLE:
			return maxi(0, count + int(round(panel.value)))
	return count


## Reference squad size used to colour and rank panels without a count.
const REF_COUNT := 12


## True when the panel can only help (used for colouring, never for choice).
static func is_good(panel: GatePanel) -> bool:
	match panel.kind:
		Kind.ADD:
			return panel.value > 0.0
		Kind.MUL:
			return panel.value > 1.0
		Kind.POWER:
			return true
		Kind.EXPR:
			return apply(REF_COUNT, panel) > REF_COUNT
	return false


static func is_power(panel: GatePanel) -> bool:
	return panel.kind == Kind.POWER


static func is_trade(panel: GatePanel) -> bool:
	return panel.kind == Kind.TRADE


static func is_bet(panel: GatePanel) -> bool:
	return panel.kind == Kind.BET


## Panels that carry a deal rather than a number: coloured amber.
static func is_deal(panel: GatePanel) -> bool:
	return is_trade(panel) or is_bet(panel) or is_scout(panel)


static func is_expr(panel: GatePanel) -> bool:
	return panel.kind == Kind.EXPR


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
		Kind.EXPR:
			var parts := []
			for op in panel.ops:
				parts.append(_op_label(int(op[0]), float(op[1])))
			return " ".join(parts)
		Kind.TRADE:
			return "%s %d" % [Powerups.title(panel.power), int(round(panel.value))]
		Kind.BET:
			return "BET x2"
		Kind.SCOUT:
			return "SCOUT %d" % int(round(panel.value))
		Kind.VEHICLE:
			return "%s %d" % [Convoy.title(panel.power), int(round(panel.value))]
		Kind.SUPPLY:
			var what := "+%d SOLDIERS" % panel.amount if panel.power == "soldiers" else Powerups.title(panel.power)
			return "%s\n%dc" % [what, supply_cost(panel)]
	return "?"


## Index of the first additive term of a sum, adding one if there is none,
## so shooting and theft always have something to move.
static func _first_add(panel: GatePanel) -> int:
	for i in range(panel.ops.size()):
		if int(panel.ops[i][0]) == Kind.ADD:
			return i
	panel.ops.append([Kind.ADD, 0.0])
	return panel.ops.size() - 1


## Register bullet damage on a panel. Returns how many steps the value climbed
## (usually 0 or 1; a heavy bullet can climb several at once).
## Callers pass a step cost scaled to the squad's damage output, so farming a
## gate yields about one step per second of committed fire at any squad size.
static func register_hit(panel: GatePanel, damage: float, step_cost: float) -> int:
	panel.revealed = true
	if step_cost <= 0.0 or panel.kind in [Kind.POWER, Kind.BET, Kind.VEHICLE]:
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
			Kind.ADD, Kind.TRADE, Kind.SCOUT:
				# A deal shot up gets cheaper, never below free.
				panel.value = minf(panel.value + 1.0, 0.0) if panel.kind != Kind.ADD else panel.value + 1.0
			Kind.MUL:
				panel.value = minf(panel.value + MUL_STEP, MUL_CAP)
			Kind.EXPR:
				var i := _first_add(panel)
				panel.ops[i][1] = float(panel.ops[i][1]) + 1.0
	return steps


## A thief reached the panel: knock it down a notch. Additive panels lose
## STEAL_AMOUNT; multipliers lose a half step but never below x1.
static func steal(panel: GatePanel) -> void:
	panel.revealed = true
	match panel.kind:
		Kind.POWER:
			# A thief turns a known power-up into a mystery.
			panel.power = Powerups.MYSTERY
		Kind.EXPR:
			var i := _first_add(panel)
			panel.ops[i][1] = float(panel.ops[i][1]) - STEAL_AMOUNT
		Kind.ADD, Kind.TRADE, Kind.SCOUT:
			panel.value -= STEAL_AMOUNT
		Kind.MUL:
			panel.value = maxf(1.0, panel.value - MUL_STEP)


## What a panel is worth to a squad of [param count], for ranking.
static func worth(panel: GatePanel, count: int) -> int:
	return apply(count, panel) + (POWER_WORTH if is_power(panel) else 0)


## Index (0 or 1) of the panel that leaves the squad larger. Ties go left.
static func better_index(left: GatePanel, right: GatePanel, count: int) -> int:
	if worth(left, count) >= worth(right, count):
		return 0
	return 1


## Index of the best of any number of panels. Ties go to the lower index.
static func best_index(panels: Array, count: int) -> int:
	var best := 0
	for i in range(1, panels.size()):
		if worth(panels[i], count) > worth(panels[best], count):
			best = i
	return best
