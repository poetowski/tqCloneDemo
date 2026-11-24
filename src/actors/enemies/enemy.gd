class_name Enemy
extends Actor
## Every foe from data/enemies.json, and the hero's Bound Shades (allies). The AI
## is a few states: dormant under the earth, rising, idle, chasing, attacking
## (melee, ranged or a boar's charge) and going home when led too far.

enum State { DORMANT, RISING, IDLE, CHASE, WINDUP, CHARGING, RETURN }

const CHAMPION_TITLES: Array[String] = ["Restless", "Bronze-bound", "Hateful", "Ever-hungry", "Oathbreaker", "Grave-cold"]
const ALERT_RADIUS := 9.0
const ALLY_TINT := Color(1.0, 0.8, 0.35)
const CHAMPION_TINT := Color(0.45, 1.0, 0.92)

var id := &""
var def: Dictionary = {}
var is_champion := false
var is_ally := false
var xp_value := 0
var home := Vector3.ZERO
var aggro_range := 12.0
var leash := 30.0
var base_speed := 3.6
var attack: Dictionary = {}
var lifetime := -1.0
var state: State = State.IDLE
var target: Actor
var nav: NavigationAgent3D
var spawner: Node
## How fast it keeps turning toward its target mid-attack (radians per second).
var busy_turn_rate := 3.0

var _attack_cooldown := 0.0
var _charge_cooldown := 2.0
var _think := 0.0
var _charge_direction := Vector3.ZERO
var _charge_left := 0.0
var _charge_hit := false
var _swings := 0
var _wander_wait := 2.0
var _wander_goal := Vector3.ZERO
var _rises := false
var _strafe_sign := 1.0
var _pending_delta := 0.0
var _steered_frame := -10


static func create(enemy_id: StringName, at_level: int, champion: bool = false) -> Enemy:
	var data := DB.enemy(enemy_id)
	var enemy: Enemy
	if String(data.get("ai", "")) == "boss":
		enemy = (load("res://src/actors/enemies/bronze_bull.gd") as GDScript).new() as Enemy
	else:
		enemy = Enemy.new()
	enemy.setup(enemy_id, at_level, champion)
	return enemy


## A golden shade bound to the hero (Bound Shades).
static func create_ally(enemy_id: StringName, at_level: int, power: float, seconds: float) -> Enemy:
	var enemy := Enemy.new()
	enemy.faction = Faction.PLAYER
	enemy.is_ally = true
	enemy.setup(enemy_id, at_level, false)
	enemy.lifetime = seconds
	enemy.display_name = "Bound Shade"
	enemy.stats.set_base(Stats.MAX_HEALTH, enemy.stats.value(Stats.MAX_HEALTH) * 1.5)
	enemy.stats.set_base(Stats.DAMAGE_MIN, enemy.stats.value(Stats.DAMAGE_MIN) * power * 2.0)
	enemy.stats.set_base(Stats.DAMAGE_MAX, enemy.stats.value(Stats.DAMAGE_MAX) * power * 2.0)
	enemy.health = enemy.max_health()
	return enemy


func setup(enemy_id: StringName, at_level: int, champion: bool) -> void:
	id = enemy_id
	def = DB.enemy(enemy_id)
	level = at_level
	is_champion = champion and not bool(def.get("unique", false)) and not bool(def.get("boss", false))
	is_boss = bool(def.get("boss", false))
	display_name = String(def.get("name", "?"))
	var health_mult := 1.0 + 0.28 * float(level - 1)
	var damage_mult := 1.0 + 0.18 * float(level - 1)
	xp_value = int(round(float(def.get("xp", 10)) * (1.0 + 0.2 * float(level - 1))))
	if is_champion:
		health_mult *= 2.2
		damage_mult *= 1.4
		xp_value *= 3
		display_name = "%s %s" % [CHAMPION_TITLES[Game.rng.randi_range(0, CHAMPION_TITLES.size() - 1)], display_name]
	var damage := def.get("damage", [3, 5]) as Array
	stats.set_bases({
		Stats.MAX_HEALTH: float(def.get("health", 40)) * health_mult,
		Stats.DAMAGE_MIN: float(damage[0]) * damage_mult,
		Stats.DAMAGE_MAX: float(damage[1]) * damage_mult,
		Stats.ARMOR: float(def.get("armor", 0)) * (1.0 + 0.1 * float(level - 1)),
	})
	health = max_health()
	aggro_range = float(def.get("aggro", 12))
	leash = float(def.get("leash", 30))
	base_speed = float(def.get("speed", 3.6))
	attack = def.get("attack", {}) as Dictionary
	radius = float(def.get("radius", 0.45))
	_rises = bool(def.get("rises", false)) and not is_ally


func _ready() -> void:
	super._ready()
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = radius * 0.85
	capsule.height = maxf(capsule.radius * 2.0 + 0.1, 1.7 if radius < 1.0 else 2.6)
	shape.shape = capsule
	shape.position.y = capsule.height * 0.5
	add_child(shape)
	body = ActorBody.new()
	body.name = "Body"
	add_child(body)
	body.setup(load(String(def["model"])) as PackedScene, def.get("hide", []) as Array)
	var attach := def.get("attach", {}) as Dictionary
	for slot: Variant in attach:
		body.attach(String(slot), String(attach[slot]))
	var s := float(def.get("scale", 1.0)) * (1.15 if is_champion else 1.0)
	body.scale = Vector3.ONE * s
	nav = NavigationAgent3D.new()
	nav.radius = radius
	# (Measured in 3D against a mesh floating up to 0.5 m over the ground: smaller
	# and a point beside the feet may never count as reached.)
	nav.path_desired_distance = 1.0
	nav.target_desired_distance = 0.6
	nav.path_height_offset = 0.5
	nav.avoidance_enabled = true
	nav.max_speed = base_speed * 1.5
	nav.neighbor_distance = 6.0
	add_child(nav)
	nav.velocity_computed.connect(_on_velocity_computed)
	home = global_position
	if is_ally:
		body.set_tint(ALLY_TINT, 0.75)
	elif is_champion:
		body.set_tint(CHAMPION_TINT, 0.45)
	if _rises and state == State.DORMANT:
		_go_dormant()
	else:
		body.play(&"idle", 0.0)


## Hidden under the ground until the spawner wakes it.
func make_dormant() -> void:
	state = State.DORMANT


func _go_dormant() -> void:
	visible = false
	collision_layer = 0


## Claws up out of the earth in a column of Styx mist.
func rise() -> void:
	visible = true
	collision_layer = LAYER_PLAYER_TEAM if faction == Faction.PLAYER else LAYER_ENEMY_TEAM
	state = State.RISING
	home = global_position
	var mist := Vfx.TEAL if not is_ally else Vfx.GOLD
	Vfx.beam(global_position, mist, 0.75, 2.6, 1.3)
	Vfx.motes(global_position + Vector3.UP * 0.3, mist, 18, 0.7, 1.4)
	Vfx.ring(global_position, mist, 0.2, 1.6, 0.6)
	Sfx.play_at(&"rise", global_position)
	start_action(&"rise", 1.05, Callable(), _on_risen)


func _on_risen() -> void:
	state = State.IDLE
	_think = 0.0


func _physics_process(delta: float) -> void:
	tick(delta)
	if state == State.DORMANT:
		return
	if is_dead:
		move_with(Vector3.ZERO, delta)
		return
	if is_ally and lifetime > 0.0:
		lifetime -= delta
		if lifetime <= 0.0:
			die(null)
			return
	if state == State.RISING or is_stunned():
		move_with(Vector3.ZERO, delta)
		return
	if state == State.CHARGING:
		_tick_charge(delta)
		return
	_attack_cooldown -= delta
	_charge_cooldown -= delta
	if is_busy():
		move_with(Vector3.ZERO, delta)
		if target and state != State.WINDUP and is_instance_valid(target):
			turn_toward(target.global_position - global_position, delta, busy_turn_rate)
		return
	_think -= delta
	if _think <= 0.0:
		_think = 0.25 + Game.rng.randf() * 0.1
		_choose_target()
	if target == null:
		_idle(delta)
		return
	_fight(delta)


func _choose_target() -> void:
	if is_ally:
		var player := Game.player
		var best := Combat.nearest(self, player.global_position if player else global_position, 11.0)
		target = best
		return
	if target and (not is_instance_valid(target) or target.is_dead):
		target = null
	if target == null and last_attacker and is_instance_valid(last_attacker) and not last_attacker.is_dead:
		_engage(last_attacker)
	if target == null:
		var seen := Combat.nearest(self, global_position, aggro_range)
		if seen:
			_engage(seen)
	if target and not is_ally and global_position.distance_to(home) > leash:
		target = null
		last_attacker = null
		state = State.RETURN
		health = max_health()
		health_changed.emit(health, max_health())


## Takes on a foe and calls the pack around it.
func _engage(foe: Actor) -> void:
	var first := target == null
	target = foe
	state = State.CHASE
	if first and not is_ally:
		if bool(def.get("unique", false)) and def.has("line"):
			Events.notified.emit("%s: “%s”" % [display_name, String(def["line"])], Color("#9FE3DA"))
		for node in get_tree().get_nodes_in_group(&"enemy_team"):
			var other := node as Enemy
			if other and other != self and not other.is_dead and other.target == null and other.state != State.DORMANT \
					and other.global_position.distance_to(global_position) < ALERT_RADIUS:
				other.alert(foe)


func alert(foe: Actor) -> void:
	if target == null and state != State.DORMANT and state != State.RISING:
		target = foe
		state = State.CHASE


func _idle(delta: float) -> void:
	if is_ally and Game.player:
		var to_player := Game.player.global_position - global_position
		to_player.y = 0.0
		if to_player.length() > 3.5:
			_move_toward(Game.player.global_position, base_speed * 1.4, delta)
			return
	if state == State.RETURN:
		if Vector2(home.x - global_position.x, home.z - global_position.z).length() > 1.0:
			_move_toward(home, base_speed * 1.2, delta)
			return
		state = State.IDLE
	_wander_wait -= delta
	if _wander_wait <= 0.0 and not is_ally and not is_boss:
		_wander_wait = Game.rng.randf_range(3.0, 7.0)
		var angle := Game.rng.randf() * TAU
		_wander_goal = home + Vector3(cos(angle), 0.0, sin(angle)) * Game.rng.randf_range(1.0, 3.5)
	if _wander_goal != Vector3.ZERO and Vector2(_wander_goal.x - global_position.x, _wander_goal.z - global_position.z).length() > 0.6:
		_move_toward(_wander_goal, base_speed * 0.35, delta, &"walk")
		return
	_wander_goal = Vector3.ZERO
	move_with(Vector3.ZERO, delta)
	body.play(&"idle", 0.25)


func _fight(delta: float) -> void:
	var to := target.global_position - global_position
	to.y = 0.0
	var distance := to.length()
	var reach := float(attack.get("range", 2.0)) + target.radius
	match String(def.get("ai", "melee")):
		"ranged":
			var keep_away := float(attack.get("keep_away", 7.0))
			if distance < keep_away * 0.6 and _attack_cooldown > 0.0:
				var away := global_position - to.normalized() * 3.0 + to.normalized().cross(Vector3.UP) * _strafe_sign * 2.0
				_move_toward(away, base_speed, delta)
				return
			if distance <= reach and _attack_cooldown <= 0.0:
				_start_shot()
				return
			if distance > reach * 0.85:
				_move_toward(target.global_position, base_speed, delta)
				return
			move_with(Vector3.ZERO, delta)
			turn_toward(to, delta, 6.0)
			body.play(&"combat_idle", 0.2)
		"charger":
			var charge := def.get("charge", {}) as Dictionary
			if _charge_cooldown <= 0.0 and distance >= float(charge.get("min_range", 4.0)) and distance <= float(charge.get("max_range", 10.0)):
				_start_charge(charge)
				return
			_melee_or_chase(distance, reach, delta)
		_:
			_melee_or_chase(distance, reach, delta)


func _melee_or_chase(distance: float, reach: float, delta: float) -> void:
	if distance <= reach:
		if _attack_cooldown <= 0.0:
			_start_melee()
		else:
			move_with(Vector3.ZERO, delta)
			turn_toward(target.global_position - global_position, delta, 8.0)
			body.play(&"combat_idle", 0.2)
		return
	_move_toward(target.global_position, base_speed, delta)


func _move_toward(goal: Vector3, speed: float, delta: float, animation: StringName = &"run") -> void:
	if nav.target_position.distance_squared_to(goal) > 0.25:
		nav.target_position = goal
	var next := nav.get_next_path_position()
	var direction := Vector3(next.x - global_position.x, 0.0, next.z - global_position.z)
	if nav.is_navigation_finished() or direction.length() < 0.05:
		direction = Vector3(goal.x - global_position.x, 0.0, goal.z - global_position.z)
	direction = direction.normalized()
	var wanted := direction * speed * speed_factor()
	turn_toward(direction, delta, 10.0)
	if nav.avoidance_enabled:
		nav.velocity = wanted
		_pending_delta = delta
		_steered_frame = Engine.get_physics_frames()
	else:
		move_with(wanted, delta)
	var moving_speed := speed * speed_factor()
	body.play(animation, 0.15, clampf(moving_speed / (6.0 if animation == &"run" else 3.0), 0.5, 1.4))


func _on_velocity_computed(safe: Vector3) -> void:
	if is_dead or state == State.DORMANT:
		return
	# The server calls back every frame with the last wanted velocity. Move only on
	# frames the AI steered: a foe that stopped to strike or wait must stand still,
	# not drift on in its last direction.
	if Engine.get_physics_frames() - _steered_frame > 1:
		return
	move_with(safe, _pending_delta if _pending_delta > 0.0 else get_physics_process_delta_time())


func _start_melee() -> void:
	face(target.global_position)
	_swings += 1
	var cleave := def.get("cleave", {}) as Dictionary
	if not cleave.is_empty() and _swings % int(cleave.get("every", 3)) == 0:
		var duration := float(cleave.get("duration", 1.2))
		Vfx.telegraph(global_position, forward(), float(cleave.get("radius", 3.5)), duration * 0.4)
		start_action(StringName(String(cleave.get("anim", "lash"))), duration, _cleave_impact.bind(cleave), _after_attack)
		return
	var anim := StringName(String(attack.get("anim", "attack_slash")))
	start_action(anim, float(attack.get("duration", 1.0)) / (1.25 if is_champion else 1.0), _melee_impact, _after_attack)


func _after_attack() -> void:
	_attack_cooldown = float(attack.get("cooldown", 0.8)) * Game.rng.randf_range(0.8, 1.3)


func _melee_impact() -> void:
	if target == null or not is_instance_valid(target) or target.is_dead:
		return
	var to := target.global_position - global_position
	to.y = 0.0
	var reach := float(attack.get("range", 2.0)) + target.radius + 0.6
	Sfx.play_at(&"swing", global_position)
	if to.length() <= reach and forward().dot(to.normalized()) > 0.2:
		_hit(target, 1.0)


func _cleave_impact(cleave: Dictionary) -> void:
	Vfx.ring(global_position, Vfx.TEAL, 0.5, float(cleave.get("radius", 3.5)), 0.3)
	Game.shake(0.2)
	for victim in Combat.in_radius(self, global_position, float(cleave.get("radius", 3.5))):
		_hit(victim, float(cleave.get("damage_mult", 1.3)), 4.0)


func _hit(victim: Actor, multiplier: float, knock: float = 1.5) -> void:
	var low := stats.value(Stats.DAMAGE_MIN)
	var high := maxf(low, stats.value(Stats.DAMAGE_MAX))
	var info := DamageInfo.make(self, Game.rng.randf_range(low, high) * multiplier)
	var push := victim.global_position - global_position
	push.y = 0.0
	info.knockback = push.normalized() * knock
	victim.take_damage(info)
	Vfx.sparks(victim.global_position + Vector3.UP * 1.1, Color(0.9, 0.25, 0.2) if victim is Player else Vfx.SPARK, 6)
	if victim is Player:
		Sfx.play_at(&"hurt", victim.global_position)


# --- ranged -------------------------------------------------------------------

func _start_shot() -> void:
	face(target.global_position)
	_strafe_sign = -_strafe_sign
	start_action(&"shoot", float(attack.get("duration", 1.2)), _loose, _after_attack)


func _loose() -> void:
	if target == null or not is_instance_valid(target):
		return
	var from := body.bone_position("LeftHand") + Vector3.UP * 0.1
	var aim := target.global_position + Vector3.UP * 1.1 + target.velocity * 0.25
	var low := stats.value(Stats.DAMAGE_MIN)
	var info := DamageInfo.make(self, Game.rng.randf_range(low, maxf(low, stats.value(Stats.DAMAGE_MAX))))
	Projectile.fire(self, from, aim, float(attack.get("projectile_speed", 16.0)), info, String(attack.get("projectile", "arrow")))
	Sfx.play_at(&"bow", global_position)


# --- charge (boars) ---------------------------------------------------------------

func _start_charge(charge: Dictionary) -> void:
	face(target.global_position)
	state = State.WINDUP
	var windup := float(charge.get("windup", 0.9))
	_charge_direction = (target.global_position - global_position)
	_charge_direction.y = 0.0
	_charge_direction = _charge_direction.normalized()
	Vfx.telegraph(global_position, _charge_direction, 0.0, windup, 180.0, float(charge.get("distance", 12.0)), 1.8)
	start_action(&"charge_windup", windup, Callable(), _begin_charge.bind(charge), 1.0)
	Sfx.play_at(&"snort", global_position)


func _begin_charge(charge: Dictionary) -> void:
	state = State.CHARGING
	_charge_left = float(charge.get("distance", 12.0))
	_charge_hit = false
	_charge_cooldown = float(charge.get("cooldown", 5.0))
	body.play(&"charge", 0.05, 1.4)


func _tick_charge(delta: float) -> void:
	var charge := def.get("charge", {}) as Dictionary
	var speed := float(charge.get("speed", 14.0))
	var before := global_position
	move_with(_charge_direction * speed, delta)
	var moved := Vector2(global_position.x - before.x, global_position.z - before.z).length()
	_charge_left -= moved
	if not _charge_hit:
		for victim in Combat.along(self, before, global_position + _charge_direction * 0.8, radius * 2.0 + 0.4):
			_charge_hit = true
			_hit(victim, float(charge.get("damage_mult", 1.5)), 9.0)
			Game.shake(0.4)
	if _charge_left <= 0.0 or moved < speed * delta * 0.25:
		state = State.CHASE
		_attack_cooldown = 0.6
		body.play(&"idle", 0.2)


# --- death ----------------------------------------------------------------------

func take_damage(info: DamageInfo) -> void:
	if state == State.DORMANT:
		return
	super.take_damage(info)
	if not is_dead and target == null and info.source is Actor and is_hostile_to(info.source as Actor):
		_engage(info.source as Actor)


func _on_died(killer: Node3D) -> void:
	body.play_once(&"die", 0.9)
	if bool(def.get("unique", false)) or is_boss:
		Game.set_flag("killed_" + String(id))
	var undead := "unthreaded" in (def.get("tags", []) as Array) or is_ally
	if not is_ally:
		if Game.player and not Game.player.is_dead:
			Game.player.gain_xp(xp_value)
		LootDrop.drop_for(self)
		if spawner and spawner.has_method(&"on_enemy_died"):
			spawner.call(&"on_enemy_died", self)
	var color := Vfx.GOLD if is_ally else Vfx.TEAL
	if undead:
		get_tree().create_timer(0.55, false).timeout.connect(func() -> void:
			if is_instance_valid(self):
				Vfx.motes(global_position + Vector3.UP * 0.8, color, 22, 0.6, 1.6)
				body.dissolve(1.1, queue_free))
	else:
		get_tree().create_timer(5.0, false).timeout.connect(func() -> void:
			if is_instance_valid(self):
				var tween := create_tween()
				tween.tween_property(self, "position:y", position.y - 1.2, 1.5)
				tween.tween_callback(queue_free))
	if killer is Player and not is_ally:
		Sfx.play_at(&"death_shade" if undead else &"death_beast", global_position)
