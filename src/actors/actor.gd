class_name Actor
extends CharacterBody3D
## Anything that fights: the player, enemies, summoned allies. Health, a faction,
## statuses (stun, slow, burn, knockback), timed actions with an impact moment
## (attacks and skills), and grounded movement. Subclasses decide what to do;
## Actor decides what happens to them.

signal health_changed(current: float, maximum: float)
signal died(actor: Actor)

enum Faction { PLAYER, ENEMY }

const GRAVITY := 28.0
## The tallest ledge a walk lifts over. The navmesh climbs ledges up to 0.25 m; a
## capsule sliding along rides over only ~0.14 m and would stall at the rest.
const STEP_HEIGHT := 0.3
const LAYER_WORLD := 1
const LAYER_PLAYER_TEAM := 1 << 1
const LAYER_ENEMY_TEAM := 1 << 2
const LAYER_INTERACT := 1 << 3
const LAYER_PROJECTILE := 1 << 4
const LAYER_TERRAIN := 1 << 5

var faction: Faction = Faction.ENEMY
var display_name := ""
var level := 1
var stats := Stats.new()
var health := 1.0
var is_dead := false
var is_boss := false
var radius := 0.45
var body: ActorBody
var last_attacker: Actor

var _action := &""
var _action_elapsed := 0.0
var _action_duration := 0.0
var _action_impact := -1.0
var _action_on_impact: Callable
var _action_on_end: Callable
var _stun := 0.0
var _slow := 0.0
var _slow_time := 0.0
var _knock := Vector3.ZERO
var _burn_dps := 0.0
var _burn_time := 0.0
var _burn_source: Actor
var _burn_tick := 0.0
var _hurt_cooldown := 0.0
var _offmesh_check := 0.0


func _ready() -> void:
	add_to_group(&"actors")
	add_to_group(&"player_team" if faction == Faction.PLAYER else &"enemy_team")
	collision_layer = LAYER_PLAYER_TEAM if faction == Faction.PLAYER else LAYER_ENEMY_TEAM
	# Bump into the world and the other team, slide past friends (avoidance spaces them).
	collision_mask = LAYER_WORLD | LAYER_TERRAIN | (LAYER_ENEMY_TEAM if faction == Faction.PLAYER else LAYER_PLAYER_TEAM)
	floor_snap_length = 0.6
	floor_max_angle = deg_to_rad(50.0)


func max_health() -> float:
	return maxf(1.0, stats.value(Stats.MAX_HEALTH))


func health_ratio() -> float:
	return clampf(health / max_health(), 0.0, 1.0)


func is_hostile_to(other: Actor) -> bool:
	return other != null and other.faction != faction


## Alive and out in the world: dormant Unthreaded under the earth don't count.
func is_targetable() -> bool:
	return not is_dead and is_inside_tree() and is_visible_in_tree()


func heal(amount: float) -> void:
	if is_dead:
		return
	health = minf(max_health(), health + amount)
	health_changed.emit(health, max_health())


## Applies a hit. Armour softens physical damage; the info records what was taken.
func take_damage(info: DamageInfo) -> void:
	if is_dead:
		return
	var amount := info.amount
	if info.kind == DamageInfo.Kind.PHYSICAL:
		amount *= 100.0 / (100.0 + maxf(0.0, stats.value(Stats.ARMOR)))
	if info.is_sever:
		amount = maxf(amount, health)
	info.final_amount = amount
	health -= amount
	if info.source is Actor:
		last_attacker = info.source as Actor
	if body:
		body.flash(0.9 if not info.is_crit else 1.0)
	health_changed.emit(maxf(health, 0.0), max_health())
	Events.damage_dealt.emit(self, info)
	if info.knockback != Vector3.ZERO and not is_boss:
		_knock += info.knockback
	if info.stun > 0.0 and not is_dead:
		stun(info.stun)
	if info.slow > 0.0:
		slow(info.slow, info.slow_time)
	if info.burn > 0.0:
		_burn_dps = maxf(_burn_dps, info.burn)
		_burn_time = 3.0
		_burn_source = info.source as Actor
	if health <= 0.0:
		die(info.source)
	else:
		_on_hurt(info)


func die(killer: Node3D = null) -> void:
	if is_dead:
		return
	is_dead = true
	health = 0.0
	cancel_action()
	collision_layer = 0
	collision_mask = LAYER_TERRAIN | LAYER_WORLD
	velocity = Vector3.ZERO
	died.emit(self)
	Events.actor_died.emit(self, killer)
	_on_died(killer)


func stun(seconds: float) -> void:
	if is_boss:
		seconds *= 0.35
	_stun = maxf(_stun, seconds)
	cancel_action()
	if body:
		body.play(&"stunned", 0.1)


func is_stunned() -> bool:
	return _stun > 0.0


func slow(amount: float, seconds: float) -> void:
	_slow = maxf(_slow, amount)
	_slow_time = maxf(_slow_time, seconds)


func speed_factor() -> float:
	return 1.0 - (_slow if _slow_time > 0.0 else 0.0)


func is_busy() -> bool:
	return _action != &""


func current_action() -> StringName:
	return _action


## Starts a timed action: plays `animation` over `duration` seconds, calls
## `on_impact` at its impact fraction and `on_end` when it finishes.
func start_action(animation: StringName, duration: float, on_impact: Callable = Callable(), on_end: Callable = Callable(),
		impact: float = -1.0) -> void:
	_action = animation
	_action_elapsed = 0.0
	_action_duration = maxf(0.05, duration)
	_action_impact = impact if impact >= 0.0 else ActorBody.impact_of(animation)
	_action_on_impact = on_impact
	_action_on_end = on_end
	if body:
		body.play_once(animation, _action_duration)


func cancel_action() -> void:
	_action = &""
	_action_on_impact = Callable()
	_action_on_end = Callable()


## Turns to face a point on the ground at once.
func face(point: Vector3) -> void:
	var flat := Vector3(point.x - global_position.x, 0.0, point.z - global_position.z)
	if flat.length_squared() > 0.0001:
		look_at(global_position + flat, Vector3.UP, true)


## Turns toward a direction at `rate` radians per second.
func turn_toward(direction: Vector3, delta: float, rate: float = 14.0) -> void:
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.length_squared() < 0.0001:
		return
	var target := atan2(flat.x, flat.z)
	rotation.y = rotate_toward(rotation.y, target, rate * delta)


func forward() -> Vector3:
	return global_transform.basis.z.normalized()


## Moves with a horizontal velocity, adding gravity and any knockback.
func move_with(horizontal: Vector3, delta: float) -> void:
	var v := Vector3(horizontal.x, velocity.y, horizontal.z)
	var knocked := false
	if _knock.length_squared() > 0.01:
		v.x += _knock.x
		v.z += _knock.z
		_knock = _knock.move_toward(Vector3.ZERO, 30.0 * delta)
		knocked = true
	else:
		_knock = Vector3.ZERO
	if is_on_floor():
		v.y = -1.0
	else:
		v.y -= GRAVITY * delta
	velocity = v
	var start := global_position
	move_and_slide()
	if not knocked and is_on_wall() and Vector2(horizontal.x, horizontal.z).length() > 0.5:
		_step_up(start, Vector3(horizontal.x, 0.0, horizontal.z) * delta)
	if knocked or _offmesh_check <= 0.0:
		_offmesh_check = 0.5
		_stay_on_navmesh()
	else:
		_offmesh_check -= delta



## A walk blocked by a low ledge: if there is headroom and the way is clear one
## step up, lift over it and settle onto the ledge.
func _step_up(start: Vector3, motion: Vector3) -> void:
	var moved := Vector2(global_position.x - start.x, global_position.z - start.z).length()
	if moved > motion.length() * 0.6:
		return
	var from := global_transform
	from.origin = start
	var lift := Vector3.UP * STEP_HEIGHT
	if test_move(from, lift):
		return
	from.origin += lift
	if test_move(from, motion):
		return
	global_position = start + lift + motion
	move_and_collide(Vector3.DOWN * (STEP_HEIGHT + 0.05))


## Blows can shove an actor somewhere it can't walk back from (onto a wall, down a
## riser). Pull it back toward the walkable ground when that happens.
func _stay_on_navmesh() -> void:
	var map := get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(map) == 0:
		return
	var closest := NavigationServer3D.map_get_closest_point(map, global_position)
	var gap := Vector2(closest.x - global_position.x, closest.z - global_position.z)
	if gap.length() > 0.8:
		var step := Vector3(gap.x, 0.0, gap.y).limit_length(0.25)
		global_position += step
	if gap.length() > 0.8 or global_position.y < closest.y - 1.5:
		if absf(closest.y - global_position.y) > 1.5:
			global_position = ground_below(Vector3(global_position.x, closest.y, global_position.z))


## The ground surface under (or a little over) a point. The navmesh only roughly
## follows the ground (it can sit a hand's width under a slope): an actor set down
## at its height can start inside the one-sided terrain and fall through.
func ground_below(point: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 2.5, point + Vector3.DOWN * 4.0, LAYER_TERRAIN | LAYER_WORLD)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return (hit["position"] as Vector3) + Vector3.UP * 0.05 if not hit.is_empty() else point + Vector3.UP * 0.3


## Ticks statuses and the current action. Call once per physics frame.
func tick(delta: float) -> void:
	if _stun > 0.0:
		_stun -= delta
	if _slow_time > 0.0:
		_slow_time -= delta
	if _hurt_cooldown > 0.0:
		_hurt_cooldown -= delta
	if _burn_time > 0.0 and not is_dead:
		_burn_time -= delta
		_burn_tick -= delta
		if _burn_tick <= 0.0:
			_burn_tick = 0.5
			var burn := DamageInfo.make(_burn_source, _burn_dps * 0.5, DamageInfo.Kind.FIRE)
			take_damage(burn)
	if _action != &"":
		_action_elapsed += delta
		var fraction := _action_elapsed / _action_duration
		if _action_impact >= 0.0 and fraction >= _action_impact:
			_action_impact = -1.0
			if _action_on_impact.is_valid():
				_action_on_impact.call()
		if fraction >= 1.0:
			var on_end := _action_on_end
			cancel_action()
			if on_end.is_valid():
				on_end.call()


## Override: a reaction to a hit that didn't kill.
func _on_hurt(_info: DamageInfo) -> void:
	if not is_busy() and not is_stunned() and _hurt_cooldown <= 0.0 and body and not is_boss:
		_hurt_cooldown = 0.8
		start_action(&"hit", 0.3)


## Override: what happens after dying (loot, dissolve, quests).
func _on_died(_killer: Node3D) -> void:
	if body:
		body.play_once(&"die", 0.95)
