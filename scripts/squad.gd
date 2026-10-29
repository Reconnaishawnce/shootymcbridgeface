class_name Squad
extends Node3D
## The player. Holds the logical soldier count, lays out the visible soldiers,
## steers on drag input and auto-fires down the lane. Rifles fire one tracer
## per shot; shotguns fire three pellets in a fan for more total damage.

signal count_changed(new_count: int)
signal wiped_out
signal dashed

## How far the squad's centre may steer from the middle on a two-lane
## road. The world widens this with the road.
const LANE_HALF := 2.6
var road_half := LANE_HALF
const MAX_VISUAL := 60
## Formation presets the button cycles through: tight, normal, wide.
const PRESETS := [0.55, 1.0, 1.7]
## Soldier counts at which flags appear, and the colour tier of each.
const FLAG_TIERS := [25, 75, 150, 300]
const TIER_COLORS := [Color(0.3, 0.6, 1.0), Color(1.0, 0.8, 0.2), Color(1.0, 0.3, 0.25), Color(0.75, 0.4, 1.0)]
const FLAG_SLOTS := [Vector3(0.0, 0.0, 0.35), Vector3(-1.1, 0.0, 0.9), Vector3(1.1, 0.0, 0.9), Vector3(-0.7, 0.0, -0.9), Vector3(0.7, 0.0, -0.9)]
## Soldiers in the front rings get the detailed build.
const DETAILED := 19
## Soldiers mid-tumble at once; past that they just vanish in dust.
const MAX_TUMBLING := 10
const STEER_LERP := 16.0
const MAX_SHOTS_PER_SECOND := 30.0
const DPS_PER_SOLDIER := 2.5
const SHOTGUN_PELLETS := 3
const SHOTGUN_DAMAGE_MULT := 1.35
const SHOTGUN_SPREAD := 1.6
## Medics trade a little damage for a steady trickle of revived soldiers
## and tougher skin against brutes.
const MEDIC_DAMAGE_MULT := 0.85
const MEDIC_REVIVE_SECONDS := 3.0
const MEDIC_BITE_MULT := 0.75

var count := 1
var target_x := 0.0
var active := false
var world: World
var perks: Perks
var meta: Meta
var powerups: Powerups
var squad_type := "rifle"
## Sideways stretch of the formation, player-controlled.
var spread := 1.0
## Straight fire: every round leaves from the middle of the formation and
## flies dead ahead, harder and through one more body. The drill for
## what is in front of you; the sides of the road go unwatched.
var straight := false
var _tumbling := 0
## Named soldiers with traits; see Veterans. One per boss beaten.
var veterans := Veterans.new()
var _vet_revive_timer := 0.0
## Run seconds, kept current by the game for timed power-ups.
var now := 0.0
## Estimated sideways speed, for the spitter's lead.
var velocity_x := 0.0
## Steering bounds. A fork narrows them to one side of the divider.
var lane_min := -LANE_HALF
var lane_max := LANE_HALF
## Focus fire: when set, every bullet converges on this road point.
var focus_on := false
var focus_point := Vector3.ZERO
## Dash state. Invulnerable until [member invulnerable_until] (run seconds).
var dash_ready_at := 0.0
var invulnerable_until := 0.0
var _dash_tween: Tween
var _laser: MeshInstance3D

var _soldiers: Array[Soldier] = []
## What the squad wears. The hero look dresses the front soldier; the
## crew look dresses everyone else. Empty means the classic military kit.
var hero_look: Dictionary = {}
var crew_look: Dictionary = {}
## The convoy: vehicles riding with the squad. They survive a level
## reset and die with the run.
var vehicles: Array[Vehicle] = []
signal vehicle_lost(id: String)
signal vehicle_ranked(id: String, rank: int)
var _fire_accum := 0.0
var _fire_index := 0
var _revive_timer := 0.0
var _flags: Array[Node3D] = []
var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _shield: MeshInstance3D
var _prev_x := 0.0


func _init() -> void:
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.albedo_color = Color(TIER_COLORS[0], 0.0)
	_ring = Mats.torus(0.8, 1.0, Color.WHITE, true)
	_ring.material_override = _ring_mat
	_ring.position.y = 0.04
	add_child(_ring)
	var shield_mat := StandardMaterial3D.new()
	shield_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shield_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shield_mat.albedo_color = Color(0.4, 0.8, 1.0, 0.22)
	_shield = Mats.sphere(1.0, Color.WHITE)
	_shield.material_override = shield_mat
	_shield.position.y = 0.8
	_shield.visible = false
	add_child(_shield)
	var laser_mat := StandardMaterial3D.new()
	laser_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	laser_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	laser_mat.albedo_color = Color(1.0, 0.3, 0.2, 0.55)
	_laser = Mats.box(Vector3(0.06, 0.06, 1.0), Color.WHITE, true)
	_laser.material_override = laser_mat
	_laser.visible = false
	_laser.top_level = true
	add_child(_laser)


func reset(start_count: int = 1) -> void:
	target_x = 0.0
	position.x = 0.0
	set_lane(-road_half, road_half)
	_prev_x = 0.0
	velocity_x = 0.0
	spread = 1.0
	straight = false
	_fire_accum = 0.0
	# Run clocks restart at zero: a dash from the last run must not leave
	# this one invulnerable, or unable to dash, for minutes.
	now = 0.0
	dash_ready_at = 0.0
	invulnerable_until = 0.0
	_revive_timer = 0.0
	veterans = Veterans.new()
	_vet_revive_timer = 0.0
	if _dash_tween != null:
		_dash_tween.kill()
		_dash_tween = null
	for s in _soldiers:
		s.queue_free()
	_soldiers.clear()
	for v in vehicles:
		v.queue_free()
	vehicles.clear()
	set_count(start_count)


## A vehicle joins. Returns false when there is no room for that kind.
func add_vehicle(id: String) -> bool:
	if not has_room(id):
		return false
	var v := Vehicle.new(id)
	v.destroyed.connect(_on_vehicle_destroyed)
	v.ranked.connect(func(vid: String, r: int) -> void: vehicle_ranked.emit(vid, r))
	add_child(v)
	vehicles.append(v)
	_layout()
	return true


func has_room(id: String) -> bool:
	return vehicle_count(id) < int(Convoy.spec(id).max)


func vehicle_count(id: String) -> int:
	var n := 0
	for v in vehicles:
		if v.alive and v.id == id:
			n += 1
	return n


func vehicle_counts() -> Dictionary:
	var out := {}
	for id in Convoy.ORDER:
		out[id] = vehicle_count(id)
	return out


func vehicles_alive() -> int:
	var n := 0
	for v in vehicles:
		if v.alive:
			n += 1
	return n


## Something heavy hit the squad: a random vehicle takes [param amount].
## Ground hits (brutes, chews, the horde) cannot reach what flies;
## lightning can.
func damage_vehicle(amount: float, ground_only: bool = true) -> void:
	var live: Array[Vehicle] = []
	for v in vehicles:
		if v.alive and not (ground_only and Convoy.flies(v.id)):
			live.append(v)
	if live.is_empty():
		return
	var mult := perks.vehicle_damage_mult() if perks != null else 1.0
	live[randi() % live.size()].take_damage(amount * mult)


func _on_vehicle_destroyed(id: String) -> void:
	for v in vehicles.duplicate():
		if not v.alive:
			vehicles.erase(v)
	vehicle_lost.emit(id)
	_layout()


## The road widened or narrowed: keep the squad inside it.
func set_road_half(h: float) -> void:
	road_half = h
	if lane_min < -0.1 and lane_max > 0.1:
		set_lane(-road_half, road_half)


## Restrict steering to a strip of the road (a fork route), or free it.
func set_lane(lo: float, hi: float) -> void:
	lane_min = lo
	lane_max = hi
	target_x = clampf(target_x, lane_min, lane_max)
	set_spread(spread)


func lane_half() -> float:
	return (lane_max - lane_min) * 0.5


## Where the squad's centre may go: the lane, minus the formation's own
## half-width, so no soldier ends up inside a fork divider or a curb.
func _bounds() -> Vector2:
	var hw := Formation.half_width(mini(count, MAX_VISUAL), spread)
	# Only an inner edge (a fork divider) pushes the formation in; the road
	# edges are soft and a few soldiers on the curb look fine.
	var lo := lane_min + (hw if lane_min > -road_half + 0.01 else 0.0)
	var hi := lane_max - (hw if lane_max < road_half - 0.01 else 0.0)
	if lo > hi:
		var mid := (lane_min + lane_max) * 0.5
		return Vector2(mid, mid)
	return Vector2(lo, hi)


## Stretch or squeeze the formation. Clamped so it always fits the lane.
func set_spread(v: float) -> void:
	var limit := Formation.max_spread_for(mini(count, MAX_VISUAL), lane_half() - 0.1)
	spread = clampf(v, Formation.SPREAD_MIN, limit)
	_layout()


func adjust_spread(d: float) -> void:
	# A drag on the width is a spray decision: straight fire ends.
	straight = false
	set_spread(spread + d)


func set_straight(on: bool) -> void:
	straight = on
	if on:
		set_spread(PRESETS[0])


## Jump to the next preset: tight, normal, wide, straight, and round.
func cycle_formation() -> void:
	if straight:
		straight = false
		set_spread(PRESETS[0])
		return
	var best := 0
	var best_d := 100.0
	for i in range(PRESETS.size()):
		var d := absf(float(PRESETS[i]) - spread)
		if d < best_d:
			best_d = d
			best = i
	if best == PRESETS.size() - 1:
		set_straight(true)
		return
	set_spread(PRESETS[best + 1])


## How the formation shoots. Tight is a focused column: little spray,
## bullets land where you point. Wide is a fan: the outer soldiers cover
## the sides of the road, at the cost of focus. The squad's footprint
## (reach) changes with it too, so tight fits a storm gap and takes
## fewer lightning hits, wide catches more.
func spray_mult() -> float:
	return clampf(0.45 + (spread - Formation.SPREAD_MIN) * 0.9, 0.45, 1.8)


func formation_name() -> String:
	if straight:
		return "STRAIGHT"
	if spread < 0.8:
		return "TIGHT"
	if spread > 1.3:
		return "WIDE"
	return "NORMAL"


## A cheer: an expanding ring under the squad, for a big gain.
func rally() -> void:
	var ring := Mats.torus(0.6, 0.8, Color(1.0, 0.9, 0.4), true)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.9, 0.4, 0.9)
	ring.material_override = mat
	ring.position.y = 0.06
	add_child(ring)
	var tw := create_tween()
	tw.tween_property(ring, "scale", Vector3(5.0, 1.0, 5.0), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.5)
	tw.tween_callback(ring.queue_free)
	for sol in _soldiers:
		var jump := create_tween()
		jump.tween_property(sol, "scale", Vector3(1.15, 1.25, 1.15), 0.08).set_delay(randf() * 0.12)
		jump.tween_property(sol, "scale", Vector3.ONE, 0.15)


func is_shielded() -> bool:
	return powerups != null and powerups.shielded(now)


func is_invulnerable() -> bool:
	return now < invulnerable_until


## Aim every gun at a point on the road, or stop.
func set_focus(point: Vector3) -> void:
	focus_on = true
	# z may come right up to the squad: that is how you hold fire on a
	# zombie clinging to your own flank.
	focus_point = Vector3(clampf(point.x, -road_half - 1.0, road_half + 1.0), 0.0, clampf(point.z, -70.0, 1.5))


func clear_focus() -> void:
	focus_on = false


func can_dash() -> bool:
	return active and now >= dash_ready_at


## A quick sideways burst with a moment of invulnerability.
func dash(direction: float) -> bool:
	if not can_dash():
		return false
	dash_ready_at = now + Progression.DASH_COOLDOWN
	invulnerable_until = now + Progression.DASH_IFRAMES
	var b := _bounds()
	target_x = clampf(target_x + signf(direction) * Progression.DASH_DISTANCE, b.x, b.y)
	if _dash_tween != null:
		_dash_tween.kill()
	_dash_tween = create_tween()
	_dash_tween.tween_property(self, "position:x", target_x, Progression.DASH_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	dashed.emit()
	return true


## Where a clinging zombie rides: alternating flanks, a little back each.
func latch_slot(i: int) -> Vector3:
	var side := -1.0 if i % 2 == 0 else 1.0
	var hw := Formation.half_width(mini(count, MAX_VISUAL), spread)
	return Vector3(side * (hw + 0.45), 0.0, -0.6 + 0.5 * float(i / 2))


## New level: back to the starting squad where you stand.
func redeploy(start_count: int) -> void:
	_fire_accum = 0.0
	set_count(start_count)


func set_count(n: int) -> void:
	var was := count
	count = maxi(0, n)
	_sync_visuals()
	count_changed.emit(count)
	# Only on the way down to zero: two bites in one frame are one wipe.
	if count == 0 and was > 0:
		wiped_out.emit()


func add(n: int) -> void:
	set_count(count + n)


## Half-width of the squad's footprint, for deciding whether a zombie that
## reaches z = 0 actually touches anyone or just shambles past.
func reach() -> float:
	return Formation.half_width(mini(count, MAX_VISUAL), spread) + 0.5


func nudge(dx: float) -> void:
	var b := _bounds()
	target_x = clampf(target_x + dx, b.x, b.y)


func is_shotgun() -> bool:
	return squad_type == "shotgun"


func is_medic() -> bool:
	return squad_type == "medic"


## Extra multiplier on what a brute or tank takes.
func bite_mult() -> float:
	return (MEDIC_BITE_MULT if is_medic() else 1.0) * veterans.bite_mult()


func _fire_mult() -> float:
	var m := perks.fire_rate_mult() if perks != null else 1.0
	if powerups != null:
		m *= powerups.fire_rate_mult(now)
	return m


func _damage_mult() -> float:
	var m := meta.damage_mult() if meta != null else 1.0
	if is_shotgun():
		m *= SHOTGUN_DAMAGE_MULT
	elif is_medic():
		m *= MEDIC_DAMAGE_MULT
	return m * veterans.damage_mult()


## Soldiers that count toward firepower. Past the cap, more soldiers are
## more to lose, not more damage.
func firing_count() -> int:
	return mini(count, Progression.DPS_CAP_SOLDIERS)


## Damage per second of the whole squad. Linear in count up to the cap.
func dps() -> float:
	return float(firing_count()) * DPS_PER_SOLDIER * _fire_mult() * _damage_mult()


## Total shots per second. Capped so a huge squad stays cheap to render.
func shots_per_second() -> float:
	return minf(float(firing_count()) * DPS_PER_SOLDIER * _fire_mult(), MAX_SHOTS_PER_SECOND)


## Damage per shot rises once the rate cap is hit, so DPS stays linear.
func damage_per_shot() -> float:
	if count <= 0:
		return 0.0
	return dps() / shots_per_second()


## Dress the squad: [param p_hero] leads, [param p_crew] is everyone else.
## Rebuilds the visible soldiers so a change in the locker shows at once.
func set_looks(p_hero: Dictionary, p_crew: Dictionary) -> void:
	hero_look = p_hero
	crew_look = p_crew
	for s in _soldiers:
		s.queue_free()
	_soldiers.clear()
	_sync_visuals()


## Everyone jumps: a level clear, a new best, a hero stepping out.
func cheer() -> void:
	for s in _soldiers:
		s.cheer()


func _sync_visuals() -> void:
	var want := mini(count, MAX_VISUAL)
	while _soldiers.size() < want:
		var i := _soldiers.size()
		var s := Soldier.new(i < DETAILED, squad_type, hero_look if (i == 0 and not hero_look.is_empty()) else crew_look)
		add_child(s)
		_soldiers.append(s)
	while _soldiers.size() > want:
		var s: Soldier = _soldiers.pop_back()
		if active and is_inside_tree() and world != null and _tumbling < MAX_TUMBLING:
			_tumble(s)
		else:
			s.queue_free()
	# A bigger squad may need a narrower spread to stay in the lane.
	spread = clampf(spread, Formation.SPREAD_MIN, Formation.max_spread_for(want, lane_half() - 0.1))
	_layout()
	_sync_army()
	mark_veterans()


## Veterans ride in the front ranks, behind the hero if there is one,
## wearing their beret and name. Only touches a soldier whose mark is
## wrong, so the crowd churn costs nothing.
func mark_veterans() -> void:
	var first := 1 if not hero_look.is_empty() else 0
	for i in range(_soldiers.size()):
		var s: Soldier = _soldiers[i]
		var k := i - first
		if k >= 0 and k < veterans.roster.size():
			if s.veteran_name() != str(veterans.roster[k].name):
				s.set_veteran(veterans.roster[k], k)
		elif s.veteran_name() != "":
			s.clear_veteran()


## A veteran is lost: their soldier goes over the side by name, and the
## crowd closes the gap.
func lose_veteran(v: Dictionary) -> void:
	for s in _soldiers:
		if s.veteran_name() == str(v.name):
			_soldiers.erase(s)
			if is_inside_tree() and world != null and _tumbling < MAX_TUMBLING:
				_tumble(s)
			else:
				s.queue_free()
			break
	_sync_visuals()


## A lost soldier goes over the side: knocked up and out toward the
## nearest curb, spinning, and down past the edge of the bridge.
func _tumble(s: Soldier) -> void:
	var gp := s.global_position
	remove_child(s)
	world.add_child(s)
	s.global_position = gp
	s.set_process(false)
	_tumbling += 1
	Fx.dust(world, gp + Vector3(0.0, 0.3, 0.0), 5, 0.18)
	var side := signf(gp.x) if absf(gp.x) > 0.2 else (1.0 if randf() < 0.5 else -1.0)
	var start := s.position
	var tw := s.create_tween()
	tw.set_parallel(true)
	tw.tween_property(s, "position:x", start.x + side * randf_range(3.0, 4.5), 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "position:z", start.z + randf_range(1.5, 3.0), 1.1)
	tw.tween_method(func(u: float) -> void: s.position.y = start.y + 2.4 * u - 7.5 * u * u, 0.0, 1.0, 1.1)
	tw.tween_property(s, "rotation", Vector3(randf_range(-6.0, 6.0), randf_range(-3.0, 3.0), side * randf_range(4.0, 8.0)), 1.1)
	tw.chain().tween_callback(func() -> void:
		_tumbling = maxi(0, _tumbling - 1)
		s.queue_free())


func _layout() -> void:
	var want := _soldiers.size()
	var pos := Formation.positions(want, spread)
	for i in range(want):
		_soldiers[i].target_offset = Vector3(pos[i].x, 0.0, pos[i].y)
	var hw := Formation.half_width(want, spread) + 0.7
	_ring.scale = Vector3(hw, 1.0, hw * 0.8)
	# Vehicles: the tank leads up the middle, jeeps ride the flanks.
	var jeep_side := -1.0
	for v in vehicles:
		if not v.alive:
			continue
		match v.id:
			"tank":
				v.target_offset = Vector3(0.0, 0.0, -(hw * 0.8 + 1.6))
			"mech":
				v.target_offset = Vector3(0.0, 0.0, -(hw * 0.8 + 3.4))
			"heli":
				v.target_offset = Vector3(0.0, 3.2, -0.4)
			_:
				v.target_offset = Vector3(jeep_side * (hw + 1.0), 0.0, -0.6)
				jeep_side = -jeep_side
	for i in range(_flags.size()):
		var slot: Vector3 = FLAG_SLOTS[i]
		_flags[i].position = Vector3(slot.x * spread, 0.0, slot.z / sqrt(spread))


## Flags and the ground glow: the squad should look like an army when it
## is one. Tier by count; more flags, hotter colour.
func _sync_army() -> void:
	var tier := -1
	for i in range(FLAG_TIERS.size()):
		if count >= int(FLAG_TIERS[i]):
			tier = i
	var want_flags := 0 if tier < 0 else mini(1 + tier * 2, FLAG_SLOTS.size())
	var color: Color = TIER_COLORS[maxi(tier, 0)]
	while _flags.size() < want_flags:
		_flags.append(_make_flag(color))
	while _flags.size() > want_flags:
		var f: Node3D = _flags.pop_back()
		f.queue_free()
	for f in _flags:
		var cloth: MeshInstance3D = f.get_meta("cloth")
		cloth.material_override = Mats.flat(color)
	_ring_mat.albedo_color = Color(color, 0.0 if tier < 0 else 0.25 + 0.15 * tier)
	_layout()


func _make_flag(color: Color) -> Node3D:
	var f := Node3D.new()
	var pole := Mats.box(Vector3(0.06, 2.4, 0.06), Color(0.2, 0.18, 0.15))
	pole.position.y = 1.2
	f.add_child(pole)
	var cloth := Mats.box(Vector3(0.75, 0.45, 0.04), color)
	cloth.position = Vector3(0.4, 2.1, 0.0)
	f.add_child(cloth)
	f.set_meta("cloth", cloth)
	add_child(f)
	f.scale = Vector3.ONE * 0.2
	var tw := create_tween()
	tw.tween_property(f, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return f


func _process(delta: float) -> void:
	var b := _bounds()
	target_x = clampf(target_x, b.x, b.y)
	if _dash_tween == null or not _dash_tween.is_running():
		position.x = lerpf(position.x, target_x, 1.0 - exp(-STEER_LERP * delta))
	_laser.visible = focus_on and active and count > 0
	if _laser.visible:
		var from := global_position + Vector3(0.0, 0.9, -0.6)
		var to := focus_point + Vector3(0.0, 0.3, 0.0)
		_laser.global_position = (from + to) * 0.5
		_laser.scale = Vector3(1.0, 1.0, from.distance_to(to))
		_laser.look_at(to, Vector3.UP)
	if delta > 0.0:
		velocity_x = lerpf(velocity_x, (position.x - _prev_x) / delta, 0.3)
	_prev_x = position.x
	var t := Time.get_ticks_msec() * 0.001
	for i in range(_flags.size()):
		_flags[i].rotation.y = sin(t * 3.0 + float(i)) * 0.25
	_shield.visible = is_shielded()
	if _shield.visible:
		var r := reach() + 0.4
		_shield.scale = Vector3(r, 1.3, r) * (1.0 + 0.04 * sin(t * 8.0))
	if not active or count == 0 or world == null:
		return
	_fire(delta)
	for v in vehicles:
		v.tick(delta, world, focus_on, focus_point, perks.vehicle_fire_mult() if perks != null else 1.0)
	if is_medic():
		_revive_timer += delta
		if _revive_timer >= MEDIC_REVIVE_SECONDS:
			_revive_timer -= MEDIC_REVIVE_SECONDS
			add(1)
	# Field medics: each one brings a soldier back every few seconds.
	if veterans.medics() > 0:
		_vet_revive_timer += delta * float(veterans.medics())
		if _vet_revive_timer >= Veterans.MEDIC_SECONDS:
			_vet_revive_timer -= Veterans.MEDIC_SECONDS
			add(1)


func _fire(delta: float) -> void:
	_fire_accum += delta * shots_per_second()
	while _fire_accum >= 1.0:
		_fire_accum -= 1.0
		if _soldiers.is_empty():
			return
		_fire_index = (_fire_index + 1) % _soldiers.size()
		var s := _soldiers[_fire_index]
		var origin := s.muzzle_world_position()
		if is_shotgun():
			var per := damage_per_shot() / float(SHOTGUN_PELLETS)
			for i in range(SHOTGUN_PELLETS):
				var spread := (float(i) - float(SHOTGUN_PELLETS - 1) * 0.5) * SHOTGUN_SPREAD
				_spawn_bullet(origin, per, spread, 0.9)
		else:
			_spawn_bullet(origin, damage_per_shot(), 0.0, 1.0)
		s.flash()


func _spawn_bullet(origin: Vector3, damage: float, vx: float, size: float) -> void:
	var b := Bullet.new(size * (perks.bullet_radius_mult() if perks != null else 1.0))
	b.damage = damage
	if straight and not focus_on:
		# Out of the middle, dead ahead, harder, and through one more.
		origin = Vector3(global_position.x, origin.y, origin.z)
		b.damage *= Bounty.STRAIGHT_DAMAGE_MULT
		b.hits_left_bonus = Bounty.STRAIGHT_PIERCE
	elif focus_on:
		# Converge on the focus point: sideways speed that gets there as the
		# bullet covers the distance. Focused rounds also hit harder.
		var dz := maxf(0.5, origin.z - focus_point.z)
		vx += (focus_point.x - origin.x) / (dz / Bullet.SPEED)
		b.damage *= Progression.FOCUS_DAMAGE_MULT
	else:
		# Spray. Close targets still get hit; far ones need aiming.
		vx += randf_range(-Progression.SPRAY, Progression.SPRAY) * spray_mult()
	b.vx = vx
	b.world = world
	b.radius_mult = perks.bullet_radius_mult() if perks != null else 1.0
	b.hits_left = 1 + (perks.pierce() if perks != null else 0) + b.hits_left_bonus
	world.bullets.add_child(b)
	b.global_position = origin
