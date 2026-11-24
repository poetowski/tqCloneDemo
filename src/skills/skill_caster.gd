class_name SkillCaster
extends Node
## Casts the hero's skills (data/skills.json, docs/GAME_DESIGN.md): checks rank,
## ichor and cooldown, plays the action and applies the effect at its impact.
## Slots: 1 = right mouse, 2..5 = Q W E R.

signal cooldown_started(id: StringName, seconds: float)

const SLOT_SKILLS := {1: &"lunge", 2: &"aspis_bash", 3: &"fates_lash", 4: &"war_cry", 5: &"bound_shades"}
const SKILL_ACTIONS: Array[StringName] = [&"lunge", &"bash", &"lash", &"war_cry", &"cast"]
const DASH_TIME := 0.3
const MUTED := Color("#C9B98F")

var player: Player
var cooldowns: Dictionary = {}
var durations: Dictionary = {}

var _dash_time := 0.0
var _dash_velocity := Vector3.ZERO
var _dash_hit: Dictionary = {}
var _dash_damage := 1.0
var _buffs: Dictionary = {}


func _physics_process(delta: float) -> void:
	for id: Variant in cooldowns.keys():
		cooldowns[id] = float(cooldowns[id]) - delta
		if float(cooldowns[id]) <= 0.0:
			cooldowns.erase(id)
	for source: Variant in _buffs.keys():
		_buffs[source] = float(_buffs[source]) - delta
		if float(_buffs[source]) <= 0.0:
			_buffs.erase(source)
			player.stats.clear_source(StringName(source))


static func skill_in_slot(slot: int) -> StringName:
	return SLOT_SKILLS.get(slot, &"") as StringName


func cooldown_left(id: StringName) -> float:
	return float(cooldowns.get(id, 0.0))


func cooldown_fraction(id: StringName) -> float:
	if not cooldowns.has(id):
		return 0.0
	return clampf(float(cooldowns[id]) / maxf(0.01, float(durations.get(id, 1.0))), 0.0, 1.0)


func buff_left(source: StringName) -> float:
	return float(_buffs.get(source, 0.0))


func cast_slot(slot: int, point: Vector3, target: Actor) -> bool:
	var id := skill_in_slot(slot)
	if id == &"" or player.is_dead or player.is_stunned() or dashing():
		return false
	var data := DB.skill(id)
	if not player.skills.knows(id):
		Events.notified.emit("%s is not yet woven into your Loom (K)." % String(data.get("name", id)), MUTED)
		return false
	if cooldowns.has(id):
		return false
	if player.is_busy() and player.current_action() in SKILL_ACTIONS:
		return false
	# Check the cost before touching anything: a failed cast must not cancel a swing.
	if player.ichor < player.skills.cost(id):
		Events.notified.emit("Not enough ichor.", Vfx.GOLD)
		Sfx.play(&"denied")
		return false
	if player.is_busy():
		player.cancel_action()
	player.spend_ichor(player.skills.cost(id))
	var seconds := player.skills.cooldown(id)
	if seconds > 0.0:
		cooldowns[id] = seconds
		durations[id] = seconds
		cooldown_started.emit(id, seconds)
	player.halt()
	if target and not target.is_dead and id != &"lunge":
		point = target.global_position
	match id:
		&"lunge":
			_lunge(point)
		&"aspis_bash":
			_bash(point)
		&"fates_lash":
			_lash()
		&"war_cry":
			_war_cry()
		&"bound_shades":
			_bound_shades(point)
	return true


# --- Lunge -----------------------------------------------------------------------

func dashing() -> bool:
	return _dash_time > 0.0


func _lunge(point: Vector3) -> void:
	var to := Vector3(point.x - player.global_position.x, 0.0, point.z - player.global_position.z)
	var direction := to.normalized() if to.length() > 0.5 else player.forward()
	var distance := clampf(to.length() + 0.8, 3.0, player.skills.param(&"lunge", "distance"))
	player.face(player.global_position + direction)
	_dash_time = DASH_TIME
	_dash_velocity = direction * distance / DASH_TIME
	_dash_hit.clear()
	_dash_damage = player.skills.param(&"lunge", "damage")
	player.start_action(&"lunge", DASH_TIME + 0.18)
	Sfx.play_at(&"lunge", player.global_position)


func tick_dash(delta: float) -> void:
	_dash_time -= delta
	var before := player.global_position
	player.move_with(_dash_velocity, delta)
	var after := player.global_position
	for victim in Combat.along(player, before, after + _dash_velocity.normalized() * 0.9, 1.7):
		if _dash_hit.has(victim):
			continue
		_dash_hit[victim] = true
		var info := player.roll_hit(_dash_damage, true)
		info.knockback = _dash_velocity.normalized() * 3.5
		player.deal(victim, info)
	Vfx.thread(before + Vector3.UP * 1.0, after + Vector3.UP * 1.0, Vfx.GOLD, 0.35, 0.06)
	if _dash_time <= 0.0:
		player.velocity = Vector3.ZERO
		Vfx.arc(after + Vector3.UP * 1.1, player.global_basis, Vfx.GOLD, 2.2, 0.2)


# --- Aspis Bash -------------------------------------------------------------------

func _bash(point: Vector3) -> void:
	player.face(point)
	player.start_action(&"bash", 0.55, _bash_impact)


func _bash_impact() -> void:
	var radius := player.skills.param(&"aspis_bash", "radius")
	var origin := player.global_position
	for victim in Combat.in_cone(player, origin, player.forward(), radius, 55.0):
		var info := player.roll_hit(player.skills.param(&"aspis_bash", "damage"), true)
		info.stun = player.skills.param(&"aspis_bash", "stun")
		info.knockback = (victim.global_position - origin).normalized() * 6.0
		info.knockback.y = 0.0
		player.deal(victim, info)
	Vfx.arc(origin + Vector3.UP * 0.9, player.global_basis, Color(1.0, 0.85, 0.55), radius, 0.18, 0.0)
	Vfx.sparks(origin + player.forward() * 1.2 + Vector3.UP * 1.0, Vfx.SPARK, 14, 7.0)
	Game.shake(0.3)
	Sfx.play_at(&"bash", origin)


# --- Fate's Lash ------------------------------------------------------------------

func _lash() -> void:
	player.start_action(&"lash", 0.72, _lash_impact)


func _lash_impact() -> void:
	var origin := player.global_position
	var radius := player.skills.param(&"fates_lash", "radius")
	var pull := player.skills.param(&"fates_lash", "pull")
	Vfx.ring(origin, Vfx.GOLD, 0.6, radius, 0.35)
	Vfx.ring(origin, Color(1.0, 0.95, 0.7), 0.3, radius * 0.7, 0.25)
	var hand := player.body.bone_position("RightHand")
	for victim in Combat.in_radius(player, origin, radius):
		var info := player.roll_hit(player.skills.param(&"fates_lash", "damage"), true)
		var inward := origin - victim.global_position
		inward.y = 0.0
		info.knockback = inward.normalized() * pull * 4.5 if inward.length() > 1.4 else Vector3.ZERO
		player.deal(victim, info)
		Vfx.thread(hand, victim.global_position + Vector3.UP * 1.1, Vfx.GOLD, 0.3, 0.035)
	Game.shake(0.25)
	Sfx.play_at(&"lash", origin)


# --- War Cry of Ares --------------------------------------------------------------

func _war_cry() -> void:
	player.start_action(&"war_cry", 0.95, _war_cry_impact)


func _war_cry_impact() -> void:
	var skills := player.skills
	var source := &"buff_war_cry"
	player.stats.set_source(source, [
		Stats.mod(Stats.DAMAGE_PCT, skills.param(&"war_cry", "damage_pct")),
		Stats.mod(Stats.ATTACK_SPEED, 0.0, skills.param(&"war_cry", "speed_pct")),
	])
	_buffs[source] = skills.param(&"war_cry", "duration")
	var origin := player.global_position
	for victim in Combat.in_radius(player, origin, skills.param(&"war_cry", "radius")):
		victim.slow(skills.param(&"war_cry", "slow"), 3.0)
	Vfx.ring(origin, Color(1.0, 0.42, 0.18), 0.5, skills.param(&"war_cry", "radius"), 0.55)
	Vfx.beam(origin, Color(1.0, 0.55, 0.25), 0.7, 3.5, 0.6, 0.6)
	Game.shake(0.45)
	Sfx.play_at(&"war_cry", origin)


# --- Bound Shades -----------------------------------------------------------------

func _bound_shades(point: Vector3) -> void:
	player.face(point)
	player.start_action(&"cast", 0.8, _bound_shades_impact)


func _bound_shades_impact() -> void:
	var skills := player.skills
	var count := int(floor(skills.param(&"bound_shades", "count")))
	var lifetime := skills.param(&"bound_shades", "duration")
	var power := skills.param(&"bound_shades", "power")
	var hand := player.body.bone_position("RightHand")
	for i in count:
		var angle := TAU * float(i) / float(count) + player.rotation.y
		var at := player.global_position + Vector3(sin(angle), 0.0, cos(angle)) * 1.8
		var ally := Enemy.create_ally(&"shade_swordsman" if i % 2 == 0 else &"shade_hoplite", player.level, power, lifetime)
		Game.level.add_child(ally)
		ally.global_position = at
		ally.rise()
		Vfx.thread(hand, at + Vector3.UP * 1.0, Vfx.GOLD, 0.6, 0.04)
	Vfx.motes(player.global_position + Vector3.UP, Vfx.GOLD, 24, 1.0, 1.2)
	Sfx.play_at(&"bind", player.global_position)
