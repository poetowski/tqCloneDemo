class_name BronzeBull
extends Enemy
## Khalkotauros, the bronze bull of Hephaestus (docs/GAME_DESIGN.md#boss). Waits in
## its arena; when the hero steps in it bellows and fights with four moves:
##   gore         a hooking blow in front (close range)
##   trample      paws twice over a lane, then charges; slamming into a column
##                stuns it for 2.5 s and it takes +50% damage meanwhile
##   forge breath a cone of fire for 2.5 s after the chest grille glows
##   hoof quake   rears and slams; a ring of force rolls out from 2 to 7 m
## Under half health its furnace cracks open: it moves faster and calls three
## Unthreaded up out of the arena floor every 20 s.
## It never leaves its arena: charges stop at the edge. When the hero falls, leaves,
## or lingers beyond its reach, it walks home and mends: slowly for a fallen hero
## (a second try finds it still wounded), fast for one who would snipe it from
## outside. Move numbers live in data/enemies.json (bronze_bull.moves).

signal enraged()

const ARENA_GROUP := &"boss_arena"

## The middle of the ring of columns; left infinite, it is where the bull stands.
var arena_center := Vector3.INF
var arena_radius := 16.0
var engaged := false
var phase := 1
var _outside := 0.0

var _move_cooldowns := {&"trample": 4.0, &"breath": 7.0, &"quake": 10.0}
var _summon_timer := 6.0
var _breathing := 0.0
var _breath_tick := 0.0
var _vulnerable := 0.0
var _furnace: GeometryInstance3D


func _ready() -> void:
	super._ready()
	if not arena_center.is_finite():
		arena_center = global_position
	is_boss = true
	state = State.IDLE
	if body.model:
		_furnace = body.model.find_child("Furnace", true, false) as GeometryInstance3D
	body.play(&"idle", 0.0)


func _physics_process(delta: float) -> void:
	if not engaged:
		tick(delta)
		if is_dead:
			return
		if Game.player and not Game.player.is_dead and _flat(Game.player.global_position - arena_center) < arena_radius:
			_engage_boss()
			return
		_mend(delta)
		if not is_busy():
			_idle(delta)
		return
	if _breathing > 0.0 and not is_dead:
		_tick_breath(delta)
	# The fire cone sweeps slowly: a hero who reads it can step out of it.
	busy_turn_rate = _move(&"breath_turn", 0.6) if current_action() == &"breath" else 3.0
	if _vulnerable > 0.0:
		_vulnerable -= delta
	var player := Game.player
	if player and _flat(player.global_position - arena_center) > arena_radius + 3.0:
		_outside += delta
	else:
		_outside = 0.0
	for key: Variant in _move_cooldowns.keys():
		_move_cooldowns[key] = float(_move_cooldowns[key]) - delta * (1.3 if phase == 2 else 1.0)
	if phase == 2 and not is_dead:
		_summon_timer -= delta
		if _summon_timer <= 0.0:
			_summon_timer = 20.0
			_summon()
	if _furnace:
		var glow := 0.35 + 0.25 * sin(Time.get_ticks_msec() / 160.0) if phase == 2 else (0.6 if _breathing > 0.0 else 0.0)
		_furnace.set_instance_shader_parameter(&"flash", glow)
	super._physics_process(delta)


func _engage_boss() -> void:
	engaged = true
	_outside = 0.0
	target = Game.player
	state = State.CHASE
	Events.boss_engaged.emit(self)
	start_action(&"bellow", 1.4, Callable(), Callable(), 0.3)
	Game.shake(0.5)
	Sfx.play_at(&"bull_roar", global_position)
	Sfx.play_music(&"boss")


func _choose_target() -> void:
	var player := Game.player
	var gone := player == null or player.is_dead or _outside > _move(&"out_of_reach", 6.0) \
		or _flat(player.global_position - arena_center) > arena_radius + 10.0
	if gone:
		_disengage()
		return
	target = player


## A number from data/enemies.json (bronze_bull.moves).
func _move(key: StringName, default: float) -> float:
	return float((def.get("moves", {}) as Dictionary).get(String(key), default))


## The hero died or ran: go home and wait for the next challenger, mending.
func _disengage() -> void:
	engaged = false
	target = null
	state = State.RETURN
	_breathing = 0.0
	cancel_action()
	Events.boss_reset.emit(self)


## Mends while no one fights it: slowly once the hero fell or left, fast while they
## linger at the arena's edge (where a bow could still reach it).
func _mend(delta: float) -> void:
	if health >= max_health():
		return
	var player := Game.player
	var watched := player != null and not player.is_dead and _flat(player.global_position - arena_center) < arena_radius + 4.0
	heal(max_health() * _move(&"mend_watched" if watched else &"mend_away", 0.06 if watched else 0.01) * delta)


func _idle(delta: float) -> void:
	if not engaged and _flat(global_position - home) > 1.5:
		_move_toward(home, base_speed, delta, &"walk")
		return
	move_with(Vector3.ZERO, delta)
	body.play(&"idle", 0.25)


## The point itself, or the nearest one a step inside the arena's edge.
static func within_arena(point: Vector3, center: Vector3, radius: float) -> Vector3:
	var offset := Vector2(point.x - center.x, point.z - center.z)
	var limit := maxf(0.0, radius - 1.0)
	if offset.length() <= limit:
		return point
	offset = offset.normalized() * limit
	return Vector3(center.x + offset.x, point.y, center.z + offset.y)


## The bull never leaves its arena and never wanders: it fights or stands.
func _fight(delta: float) -> void:
	var to := target.global_position - global_position
	to.y = 0.0
	var distance := to.length()
	if _move_cooldowns[&"quake"] <= 0.0 and distance < 6.5:
		_quake()
		return
	if _move_cooldowns[&"breath"] <= 0.0 and distance < 9.0 and distance > 3.0:
		_breath()
		return
	if _move_cooldowns[&"trample"] <= 0.0 and distance > 6.0:
		_trample()
		return
	if distance <= float(attack.get("range", 3.4)) + target.radius:
		if _attack_cooldown <= 0.0:
			face(target.global_position)
			start_action(&"gore", float(attack.get("duration", 1.3)) / (1.2 if phase == 2 else 1.0), _gore_impact, _after_attack)
			Vfx.telegraph(global_position, forward(), 4.0, 0.5, 50.0)
		else:
			move_with(Vector3.ZERO, delta)
			turn_toward(to, delta, 3.0)
			body.play(&"idle", 0.2)
		return
	var goal := within_arena(target.global_position, arena_center, arena_radius)
	if _flat(goal - global_position) < 0.8:
		# The hero stands beyond the edge: hold the ground and glare.
		move_with(Vector3.ZERO, delta)
		turn_toward(to, delta, 3.0)
		body.play(&"idle", 0.2)
		return
	_move_toward(goal, base_speed * (1.3 if phase == 2 else 1.0), delta, &"walk")


func _flat(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()


# --- gore ----------------------------------------------------------------------------

func _gore_impact() -> void:
	Game.shake(0.3)
	Sfx.play_at(&"bull_hit", global_position)
	for victim in Combat.in_cone(self, global_position, forward(), 4.2, 50.0):
		_hit(victim, 1.0, _move(&"gore_knock", 5.0))


# --- trample -------------------------------------------------------------------------

func _trample() -> void:
	_move_cooldowns[&"trample"] = 9.0
	face(target.global_position)
	state = State.WINDUP
	_charge_direction = target.global_position - global_position
	_charge_direction.y = 0.0
	_charge_direction = _charge_direction.normalized()
	Vfx.telegraph(global_position, _charge_direction, 0.0, 1.3, 180.0, 20.0, 3.4)
	Sfx.play_at(&"snort", global_position)
	start_action(&"charge_windup", 1.3, Callable(), _begin_trample, 1.0)


func _begin_trample() -> void:
	state = State.CHARGING
	_charge_left = 20.0
	_charge_hit = false
	body.play(&"charge", 0.05, 1.2)


func _tick_charge(delta: float) -> void:
	var speed := 17.0
	var before := global_position
	if _flat(before + _charge_direction * 1.5 - arena_center) > arena_radius:
		# The arena's edge: it digs in its hooves rather than run out of it.
		state = State.CHASE
		body.play(&"idle", 0.2)
		return
	move_with(_charge_direction * speed, delta)
	var moved := Vector2(global_position.x - before.x, global_position.z - before.z).length()
	_charge_left -= moved
	if not _charge_hit:
		for victim in Combat.along(self, before, global_position + _charge_direction * 2.0, 3.0):
			_charge_hit = true
			_hit(victim, _move(&"trample_mult", 1.5), _move(&"trample_knock", 10.0))
			Game.shake(0.5)
	if moved < speed * delta * 0.3 and _charge_left < 19.0:
		_crash()
		return
	if _charge_left <= 0.0:
		state = State.CHASE
		body.play(&"idle", 0.2)


## Slammed into a column: dazed and open to the hero's blows.
func _crash() -> void:
	state = State.CHASE
	_vulnerable = 2.5
	Game.shake(0.8)
	Game.hit_stop(0.08)
	Vfx.sparks(global_position + forward() * 2.5 + Vector3.UP * 2.0, Vfx.SPARK, 30, 9.0)
	Vfx.ring(global_position + forward() * 2.0, Vfx.SPARK, 0.5, 5.0, 0.4)
	Sfx.play_at(&"bull_crash", global_position)
	var column := _column_near(global_position + forward() * 2.5, 4.0)
	if column:
		_shatter(column)
	Events.notified.emit("Khalkotauros is dazed! Strike now!", UIStyle.GOLD_BRIGHT)
	_stun = 2.5
	cancel_action()
	body.play(&"stunned", 0.1)


## A whole arena column near a point (the bull just rammed it), or null.
func _column_near(point: Vector3, max_distance: float) -> Node3D:
	var best: Node3D = null
	var best_d := max_distance
	for node in get_tree().get_nodes_in_group(&"fadeable"):
		var prop := node as Node3D
		if prop == null or not prop.visible or not String(prop.name).begins_with("column_"):
			continue
		var d := Vector2(prop.global_position.x - point.x, prop.global_position.z - point.z).length()
		if d < best_d:
			best_d = d
			best = prop
	return best


## The column breaks: a stump stays, marble dust and shards fly.
func _shatter(column: Node3D) -> void:
	column.visible = false
	for body in column.find_children("*", "StaticBody3D", true, false):
		(body as StaticBody3D).collision_layer = 0
	var stump_path := "res://assets/models/props/column_stump/column_stump.glb"
	if ResourceLoader.exists(stump_path):
		var stump := (load(stump_path) as PackedScene).instantiate() as Node3D
		column.get_parent().add_child(stump)
		stump.global_transform = column.global_transform
	Vfx.sparks(column.global_position + Vector3.UP * 2.0, Color(0.95, 0.92, 0.85), 30, 8.0)
	Vfx.motes(column.global_position + Vector3.UP * 1.5, Color(0.9, 0.88, 0.82), 30, 1.2, 1.8)
	Sfx.play_at(&"pot_break", column.global_position, 6.0, 0.0)
	Game.shake(0.9)


func take_damage(info: DamageInfo) -> void:
	# Struck by a hero at the arena's edge: it turns on them. Blows from farther out
	# are outpaced by its mending (see _mend).
	if not engaged and not is_dead and info.source is Actor and (info.source as Actor).faction == Faction.PLAYER \
			and Game.player and not Game.player.is_dead and _flat(Game.player.global_position - arena_center) < arena_radius + 3.0:
		_engage_boss()
	if _vulnerable > 0.0:
		info.amount *= 1.5
	super.take_damage(info)
	if not is_dead and phase == 1 and health_ratio() < 0.5:
		_enrage()


# --- forge breath ----------------------------------------------------------------------

func _breath() -> void:
	_move_cooldowns[&"breath"] = 11.0
	face(target.global_position)
	Vfx.telegraph(global_position, forward(), 9.0, 1.0, 36.0)
	start_action(&"breath", 3.4, func() -> void:
		_breathing = 2.4
		_breath_tick = 0.0, Callable(), 0.3)
	Sfx.play_at(&"furnace", global_position)


func _tick_breath(delta: float) -> void:
	_breathing -= delta
	_breath_tick -= delta
	var mouth := global_position + forward() * 3.0 + Vector3.UP * 1.9
	if _breath_tick <= 0.0:
		_breath_tick = 0.22
		Vfx.sparks(mouth, Vfx.FIRE, 14, 11.0)
		Vfx.motes(mouth + forward() * 3.0 - Vector3.UP * 1.2, Vfx.FIRE, 10, 1.6, 0.6)
		for victim in Combat.in_cone(self, global_position, forward(), 9.0, 36.0):
			var info := DamageInfo.make(self, stats.value(Stats.DAMAGE_MIN) * _move(&"breath_tick", 0.25), DamageInfo.Kind.FIRE)
			info.burn = stats.value(Stats.DAMAGE_MIN) * _move(&"breath_burn", 0.3)
			victim.take_damage(info)


# --- hoof quake --------------------------------------------------------------------------

func _quake() -> void:
	_move_cooldowns[&"quake"] = 13.0
	Vfx.telegraph(global_position, forward(), 7.5, 1.1, 180.0, 0.0, 2.0, 0.26)
	start_action(&"stomp", 1.9, _quake_impact, _after_attack)


func _quake_impact() -> void:
	Game.shake(0.9)
	Vfx.ring(global_position, Vfx.SPARK, 1.5, 7.5, 0.45)
	Vfx.ring(global_position, Vfx.FIRE, 1.0, 6.0, 0.6)
	Sfx.play_at(&"quake", global_position)
	for victim in Combat.in_radius(self, global_position, 7.5):
		var d := _flat(victim.global_position - global_position)
		if d >= 1.6:
			_hit(victim, _move(&"quake_mult", 1.2), _move(&"quake_knock", 6.0))
			victim.stun(0.6)


# --- phase two ---------------------------------------------------------------------------

func _enrage() -> void:
	phase = 2
	base_speed *= 1.25
	_summon_timer = 3.0
	enraged.emit()
	Events.notified.emit("The furnace heart cracks open. The dead answer its call.", Color(1.0, 0.6, 0.25))
	Vfx.beam(global_position, Vfx.FIRE, 1.8, 7.0, 1.5, 0.8)
	Vfx.motes(global_position + Vector3.UP * 2.0, Vfx.TEAL, 40, 2.5, 2.0)
	Game.shake(0.7)
	Sfx.play_at(&"bull_roar", global_position)


func _summon() -> void:
	for i in 3:
		var angle := TAU * float(i) / 3.0 + randf()
		var at := arena_center + Vector3(cos(angle), 0.0, sin(angle)) * 9.0
		var shade := Enemy.create(&"shade_hoplite", maxi(1, level - 2))
		shade.make_dormant()
		Game.level.add_child(shade)
		shade.global_position = at
		shade.rise()


# --- death -----------------------------------------------------------------------------------

func _on_died(killer: Node3D) -> void:
	_breathing = 0.0
	Game.set_flag("killed_" + String(id))
	body.play_once(&"die", 1.5)
	Events.boss_defeated.emit(self)
	Game.shake(1.0)
	Game.hit_stop(0.15)
	Sfx.play_at(&"bull_death", global_position)
	if Game.player:
		Game.player.gain_xp(xp_value)
	# The furnace door bursts and the first blade falls out with the loot.
	get_tree().create_timer(1.4, false).timeout.connect(func() -> void:
		Vfx.beam(global_position + forward() * 1.5, Vfx.GOLD, 1.2, 10.0, 3.0, 1.0)
		Vfx.motes(global_position + Vector3.UP * 2.0, Vfx.GOLD, 50, 2.0, 2.5)
		LootDrop.drop_for(self))
	for node in get_tree().get_nodes_in_group(&"enemy_team"):
		var other := node as Actor
		if other and other != self and not other.is_dead and other.global_position.distance_to(arena_center) < arena_radius + 6.0:
			other.die(killer)
