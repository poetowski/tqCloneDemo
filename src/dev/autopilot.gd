class_name Autopilot
extends Node
## Plays the hero for automated checks (`npm run shot -- --scenario=brawl|tour`):
## fights the nearest foe, uses skills as they come off cooldown, drinks when low,
## picks up loot when the field is clear, and walks a route of waypoints, talking
## to Klotho and opening the sanctuary gate on the way. Prints what happens.

signal route_finished()

var player: Player
var route: Array[Vector3] = []
var log_events := true
## How far a foe may be for the pilot to go after it.
var hunt_radius := 22.0

var _skill_timer := 0.8
var _route_index := 0
var _stuck_time := 0.0
var _last_position := Vector3.ZERO
var _best_remaining := INF


## Plays like a person: spends points as levels come and wears better finds.
var manage_hero := false
var deaths := 0

const SKILL_ORDER: Array[StringName] = [&"fates_lash", &"aspis_bash", &"atropos_mercy", &"war_cry", &"bound_shades", &"fates_lash",
	&"lunge", &"aspis_bash", &"fates_lash", &"atropos_mercy", &"war_cry", &"lunge"]


func _ready() -> void:
	Events.player_died.connect(func() -> void:
		deaths += 1
		# The hero wakes at a hearth far from the next waypoint: that isn't being stuck.
		_best_remaining = INF
		_stuck_time = 0.0)
	if manage_hero:
		Events.level_reached.connect(func(_level: int) -> void: _spend_points.call_deferred())
		Events.item_picked_up.connect(func(item: RefCounted) -> void: _consider.call_deferred(item as Item))
		_spend_points.call_deferred()
	if log_events:
		Events.actor_died.connect(func(actor: Node3D, _killer: Node3D) -> void:
			if actor is Enemy and not (actor as Enemy).is_ally:
				print("[auto] %6.1fs died: %s" % [_t(), actor.name]))
		Events.level_reached.connect(func(level: int) -> void: print("[auto] %6.1fs level %d" % [_t(), level]))
		Events.item_picked_up.connect(func(item: RefCounted) -> void: print("[auto] %6.1fs picked up %s" % [_t(), (item as Item).display_name()]))
		Events.quest_updated.connect(func(id: StringName) -> void: print("[auto] %6.1fs quest %s stage %d" % [_t(), id, Quests.stage(id)]))
		Events.area_entered.connect(func(area: String) -> void: print("[auto] %6.1fs entered %s" % [_t(), area]))
		Events.player_died.connect(func() -> void: print("[auto] %6.1fs THE HERO DIED at %s" % [_t(), player.global_position]))
		Events.boss_engaged.connect(func(_b: Node3D) -> void: print("[auto] %6.1fs boss engaged" % _t()))
		Events.boss_defeated.connect(func(_b: Node3D) -> void: print("[auto] %6.1fs boss defeated" % _t()))
		Events.demo_completed.connect(func() -> void: print("[auto] %6.1fs DEMO COMPLETED" % _t()))


func _t() -> float:
	return Time.get_ticks_msec() / 1000.0


var _status_timer := 0.0


func _physics_process(delta: float) -> void:
	if player == null or player.is_dead or not player.input_enabled:
		return
	_status_timer -= delta
	if _status_timer <= 0.0 and log_events:
		_status_timer = 5.0
		var p := player.global_position
		var target := player.current_target()
		var fighting := ""
		if target:
			fighting = "fighting %s%s" % [target.name, (" (%d/%d)" % [int(target.health), int(target.max_health())]) if target.is_boss else ""]
		print("[auto] %6.1fs at (%.0f, %.0f, %.0f) lvl %d hp %d/%d waypoint %d/%d %s" % [_t(), p.x, p.y, p.z, player.level, int(player.health),
			int(player.max_health()), _route_index, route.size(), fighting])
	if player.health_ratio() < 0.4:
		player.use_potion(&"potion_health")
	if player.ichor < 15.0:
		player.use_potion(&"potion_ichor")
	var foe := _reachable_foe(delta)
	if foe is BronzeBull and _dodge(foe as BronzeBull):
		return
	if foe and not (foe is BronzeBull and not (foe as BronzeBull).engaged and _route_index < route.size() - 1):
		if player.current_target() != foe:
			player.command_attack(foe)
		_skill_timer -= delta
		if _skill_timer <= 0.0:
			_skill_timer = 1.0
			for slot: int in [4, 5, 3, 2, 1]:
				var id := SkillCaster.skill_in_slot(slot)
				if not player.skills.knows(id) or player.caster.cooldown_left(id) > 0.0 or player.ichor < player.skills.cost(id):
					continue
				if player.caster.cast_slot(slot, foe.global_position, foe):
					break
		return
	var loot := _nearest_loot()
	if loot:
		player.command_interact(loot)
		return
	_talk_and_open()
	_follow_route(delta)


var _foe_ignored: Dictionary = {}
var _foe_best := INF
var _foe_time := 0.0
var _foe_last: Actor
var _foe_health := INF
var _foe_idle := 0.0


## The nearest foe the hero is getting closer to; one it can't reach for 6 s, or
## can't hurt for 15 s, is ignored for 20 s (it may stand where no path goes).
func _reachable_foe(delta: float) -> Actor:
	var now := _t()
	for key: Variant in _foe_ignored.keys():
		if float(_foe_ignored[key]) < now or not is_instance_valid(key):
			_foe_ignored.erase(key)
	var best: Actor = null
	var best_d := hunt_radius
	for node in get_tree().get_nodes_in_group(&"enemy_team"):
		var actor := node as Actor
		if actor == null or not actor.is_targetable() or _foe_ignored.has(actor):
			continue
		var d := actor.global_position.distance_to(player.global_position)
		if d < best_d:
			best_d = d
			best = actor
	if best != _foe_last:
		_foe_last = best
		_foe_best = INF
		_foe_time = 0.0
		_foe_health = best.health if best else INF
		_foe_idle = 0.0
	elif best and not (best is BronzeBull):
		# (The bull keeps to its open arena: always reachable, and stepping out of
		# its moves isn't failing to reach it.)
		if best.health < _foe_health - 0.5:
			_foe_health = best.health
			_foe_idle = 0.0
		else:
			_foe_idle += delta
		if not player.is_busy():
			if best_d < _foe_best - 0.3:
				_foe_best = best_d
				_foe_time = 0.0
			else:
				_foe_time += delta
		var cant_reach := _foe_time > 6.0 and best_d > player.weapon_range() + 1.5
		if cant_reach or _foe_idle > 15.0:
			print("[auto] %6.1fs can't %s %s, leaving it" % [_t(), "reach" if cant_reach else "hurt", best.name])
			_foe_ignored[best] = now + 20.0
			_foe_time = 0.0
			_foe_idle = 0.0
			return null
	return best


## Steps out of the bull's telegraphed moves as a player who reads them would:
## sideways out of the fire cone and the charge lane, back out of the quake ring.
func _dodge(bull: BronzeBull) -> bool:
	if not bull.engaged:
		return false
	var away := player.global_position - bull.global_position
	away.y = 0.0
	var distance := maxf(away.length(), 0.01)
	var ahead := bull.forward()
	var side := ahead.cross(Vector3.UP).normalized()
	if side.dot(away) < 0.0:
		side = -side
	var in_front := ahead.dot(away / distance) > 0.5
	match bull.current_action():
		&"breath":
			if in_front and distance < 11.0:
				player.command_move(player.global_position + side * 4.0)
				return true
		&"stomp":
			if distance < 9.0:
				player.command_move(player.global_position + away / distance * 4.0)
				return true
		&"charge_windup":
			if in_front:
				player.command_move(player.global_position + side * 4.0)
				return true
	return false


func _talk_and_open() -> void:
	for node in get_tree().get_nodes_in_group(&"npcs"):
		var npc := node as Node3D
		if npc.global_position.distance_to(player.global_position) < 4.0 and String(npc.get(&"npc_id")) == "klotho":
			var stage := Quests.stage(&"weaver")
			if stage == 0 or stage == 2:
				Quests.talked_to("klotho")
	var gate := get_tree().current_scene.find_child("SanctuaryGate", true, false) as Node3D
	if gate and not bool(gate.get(&"opened")) and gate.global_position.distance_to(player.global_position) < 6.0:
		gate.call(&"interact", player)


func _follow_route(delta: float) -> void:
	if _route_index >= route.size():
		return
	var goal := route[_route_index]
	if Vector2(goal.x - player.global_position.x, goal.z - player.global_position.z).length() < 3.0:
		_route_index += 1
		_best_remaining = INF
		_stuck_time = 0.0
		print("[auto] %6.1fs waypoint %d/%d" % [_t(), _route_index, route.size()])
		if _route_index >= route.size():
			route_finished.emit()
		return
	player.command_move(goal)
	# Stuck means no progress toward the goal, even if the hero jitters on the spot.
	var remaining := player.global_position.distance_to(goal)
	if remaining < _best_remaining - 0.5:
		_best_remaining = remaining
		_stuck_time = 0.0
	else:
		_stuck_time += delta
		if _stuck_time > 5.0:
			print("[auto] %6.1fs stuck at %s on the way to %s" % [_t(), player.global_position, goal])
			_stuck_time = 0.0
			_best_remaining = INF
			_route_index += 1


var _loot_target: Node3D
var _loot_time := 0.0
var _skipped: Dictionary = {}


func _spend_points() -> void:
	for id in SKILL_ORDER:
		if player.skills.points <= 0:
			break
		if player.skills.learn(id, player.level):
			print("[auto] %6.1fs learned %s (rank %d)" % [_t(), id, player.skills.rank(id)])
	# Two thirds Might, a third Cunning.
	while player.attribute_points > 0:
		player.spend_attribute(&"cunning" if player.attribute_points % 3 == 0 else &"might")


## Wears a find if it beats what's worn by a rough score.
func _consider(item: Item) -> void:
	if item == null or not item.is_gear() or not player.inventory.has_item(item):
		return
	var slot := player.equipment.slot_for(item)
	var worn := player.equipment.get_item(slot)
	if worn == null or _score(item) > _score(worn) * 1.05:
		player.equip_from_inventory(item, slot)
		print("[auto] %6.1fs equipped %s" % [_t(), item.display_name()])


func _score(item: Item) -> float:
	var total := 0.0
	for mod: Variant in item.mods():
		var m := mod as Dictionary
		var w := {Stats.DAMAGE_MIN: 3.0, Stats.DAMAGE_MAX: 3.0, Stats.ARMOR: 1.0, Stats.MAX_HEALTH: 0.6, Stats.DAMAGE_PCT: 1.5,
			Stats.MIGHT: 1.5, Stats.CUNNING: 1.2, Stats.CRIT_CHANCE: 2.0}.get(m["stat"], 0.5) as float
		total += (float(m["flat"]) + float(m["pct"]) * 0.5) * w
	return total + float(item.rarity) * 2.0


## The closest item the hero can actually take; gives up on one after 6 s. Story
## items always fit (the hero sets gear down for them) and are worth a longer walk.
func _nearest_loot() -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group(&"ground_items"):
		var ground := node as GroundItem
		if _skipped.has(ground):
			continue
		var it := ground.item
		var reach := 10.0
		if it and it.is_quest():
			reach = 40.0
		elif it:
			var belt_room := it.is_potion() and int(player.belt.get(it.base_id, 0)) < Player.BELT_MAX
			if not belt_room and player.inventory.find_space(it).x < 0:
				continue
		var d := ground.global_position.distance_to(player.global_position)
		if d < reach and d < best_d:
			best_d = d
			best = ground
	if best != _loot_target:
		_loot_target = best
		_loot_time = 0.0
	elif best:
		_loot_time += get_physics_process_delta_time()
		if _loot_time > (30.0 if best.item and best.item.is_quest() else 6.0):
			print("[auto] %6.1fs gave up on %s" % [_t(), best.name])
			_skipped[best] = true
			return null
	return best
