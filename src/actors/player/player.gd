class_name Player
extends Actor
## The Threadless: the hero. Click to move, click a foe to fight it until it falls,
## click things to use them; skills on the right mouse button and Q W E R, potions
## on 1 and 2. Owns the hero's progress: level, attributes, skills, bag, gear, belt.

signal ichor_changed(current: float, maximum: float)
signal xp_changed(current: int, needed: int, at_level: int)
signal leveled_up(at_level: int)
signal hover_changed(target: Node3D)
signal belt_changed()
signal gear_changed()
signal gold_changed(total: int)
signal attributes_changed()

enum Command { NONE, MOVE, ATTACK, INTERACT }

const MODEL := preload("res://assets/models/characters/hero/hero.glb")
const HIDDEN_VARIANTS: Array[String] = ["Cuirass_Linen", "Cuirass_Bronze", "Greaves_Bronze", "Wraps_Leather"]
const BASE_MOVE_SPEED := 6.0
const FIST_DAMAGE := Vector2(2, 4)
const RANGE_PAD := 0.3
const POTION_COOLDOWN := 1.0
const BELT_MAX := 9
const PICK_RADIUS := 1.1
## How near (on the ground plane) a path point must be to count as reached.
const PATH_REACH := 0.35

var ichor := 40.0
var xp := 0
var attribute_points := 0
var attributes: Dictionary = {&"might": 10, &"cunning": 10, &"spirit": 10}
var inventory := Inventory.new(10, 6)
var equipment := Equipment.new()
var belt: Dictionary = {&"potion_health": 3, &"potion_ichor": 2}
var gold := 0
var skills := SkillBook.new()
var input_enabled := true
var hovered: Node3D
## The way to the current goal over the navigation mesh, and the point walked to.
var path := PackedVector3Array()
var path_index := 0
var caster: SkillCaster

var _command := Command.NONE
var _move_target := Vector3.ZERO
var _target: Actor
var _interactable: Node3D
var _ground_point := Vector3.ZERO
var _ground_valid := false
var _potion_cooldown := 0.0
var _hold_repath := 0.0
var _force_attack := false
var _stuck_time := 0.0
var _path_goal := Vector3.INF
var _path_stamp := 0


func _init() -> void:
	faction = Faction.PLAYER
	display_name = "The Threadless"


func _ready() -> void:
	super._ready()
	add_to_group(&"player")
	radius = 0.45
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)
	body = ActorBody.new()
	body.name = "Body"
	add_child(body)
	body.setup(MODEL, HIDDEN_VARIANTS)
	caster = SkillCaster.new()
	caster.name = "SkillCaster"
	add_child(caster)
	caster.player = self
	stats.derive = _derive
	stats.set_bases({Stats.ATTACK_SPEED: 100.0, Stats.MOVE_SPEED: BASE_MOVE_SPEED, Stats.CRIT_MULTIPLIER: 1.75, Stats.MAGIC_FIND: 100.0})
	equipment.changed.connect(_on_equipment_changed)
	skills.grant(&"lunge")
	skills.points = 1
	_start_kit()
	health = max_health()
	ichor = max_ichor()
	Game.player = self


func _start_kit() -> void:
	var spear := Item.create(&"dory", 1, Item.Rarity.MORTAL)
	var shield := Item.create(&"pelte", 1, Item.Rarity.MORTAL)
	var tunic := Item.create(&"chiton", 1, Item.Rarity.MORTAL)
	equipment.equip("weapon", spear)
	equipment.equip("shield", shield)
	equipment.equip("chest", tunic)


# --- stats ---------------------------------------------------------------------

func _derive(stat: StringName) -> float:
	match stat:
		Stats.MIGHT, Stats.CUNNING, Stats.SPIRIT:
			return float(attributes.get(stat, 0)) + stats.value(Stats.ALL_ATTRIBUTES)
		Stats.MAX_HEALTH:
			return 80.0 + 12.0 * float(level - 1) + 2.0 * stats.value(Stats.MIGHT)
		Stats.MAX_ICHOR:
			return 40.0 + 4.0 * float(level - 1) + 2.0 * stats.value(Stats.SPIRIT)
		Stats.HEALTH_REGEN:
			return 0.6 + 0.08 * float(level)
		Stats.ICHOR_REGEN:
			return 2.0 + 0.05 * stats.value(Stats.SPIRIT)
		Stats.CRIT_CHANCE:
			return 5.0 + 0.25 * stats.value(Stats.CUNNING)
	return 0.0


func max_ichor() -> float:
	return maxf(1.0, stats.value(Stats.MAX_ICHOR))


func weapon() -> Item:
	return equipment.get_item("weapon")


func weapon_range() -> float:
	var w := weapon()
	return float(w.base().get("range", 1.6)) if w else 1.6


func attacks_per_second() -> float:
	var w := weapon()
	var speed := float(w.base().get("speed", 1.3)) if w else 1.3
	var bonus := stats.value(Stats.ATTACK_SPEED) / 100.0 + 0.01 * (stats.value(Stats.CUNNING) - 10.0)
	return speed * maxf(0.4, bonus)


func move_speed() -> float:
	return stats.value(Stats.MOVE_SPEED) * speed_factor()


func crit_chance() -> float:
	return stats.value(Stats.CRIT_CHANCE)


## Rolls a hit: weapon damage × (Might, % bonuses, skill bonuses) × multiplier.
func roll_hit(multiplier: float, is_skill: bool = false) -> DamageInfo:
	var low := stats.value(Stats.DAMAGE_MIN)
	var high := maxf(low, stats.value(Stats.DAMAGE_MAX))
	if weapon() == null:
		low += FIST_DAMAGE.x
		high += FIST_DAMAGE.y
	var amount := Game.rng.randf_range(low, high)
	var bonus := 1.0 + 0.015 * stats.value(Stats.MIGHT) + stats.value(Stats.DAMAGE_PCT) / 100.0
	if is_skill:
		bonus += stats.value(Stats.SKILL_DAMAGE_PCT) / 100.0 + 0.02 * (stats.value(Stats.SPIRIT) - 10.0)
	var info := DamageInfo.make(self, amount * bonus * multiplier)
	if Game.rng.randf() * 100.0 < crit_chance():
		info.is_crit = true
		info.amount *= stats.value(Stats.CRIT_MULTIPLIER)
	var fire := stats.value(Stats.FIRE_DAMAGE)
	if fire > 0.0:
		info.burn = fire
	return info


## Applies a rolled hit to `target`, with Atropos' Mercy, life on hit and feedback.
func deal(target: Actor, info: DamageInfo) -> void:
	if target == null or target.is_dead:
		return
	if skills.knows(&"atropos_mercy") and not target.is_boss:
		var threshold := skills.param(&"atropos_mercy", "threshold") / 100.0
		var mitigated := info.amount * 100.0 / (100.0 + maxf(0.0, target.stats.value(Stats.ARMOR)))
		var after := target.health - mitigated
		if after > 0.0 and after / target.max_health() < threshold:
			info.is_sever = true
	target.take_damage(info)
	var on_hit := stats.value(Stats.LIFE_ON_HIT)
	if on_hit > 0.0:
		heal(on_hit)
	var at := target.global_position + Vector3.UP * (1.1 * target.scale.y)
	Vfx.sparks(at, Vfx.SPARK if not info.is_crit else Vfx.GOLD, 12 if info.is_crit else 7)
	if info.is_sever:
		Vfx.sever(target.global_position)
	if info.is_crit or target.is_dead:
		Game.hit_stop(0.05 if target.is_dead else 0.035)
		Game.shake(0.35 if info.is_crit else 0.25)
	Sfx.play_at(&"hit_flesh" if target.is_dead else &"hit", at)


# --- input ---------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled or is_dead:
		return
	if event.is_action_pressed(&"move_click"):
		_force_attack = Input.is_action_pressed(&"force_attack")
		_click()
		get_viewport().set_input_as_handled()
	for i in 5:
		if event.is_action_pressed(StringName("skill_%d" % (i + 1))):
			caster.cast_slot(i + 1, _ground_point, hovered as Actor if hovered is Actor else null)
			get_viewport().set_input_as_handled()
	if event.is_action_pressed(&"potion_health"):
		use_potion(&"potion_health")
	elif event.is_action_pressed(&"potion_ichor"):
		use_potion(&"potion_ichor")


func _click() -> void:
	_update_hover()
	if hovered is Actor and is_hostile_to(hovered as Actor):
		_command = Command.ATTACK
		_target = hovered as Actor
	elif hovered and hovered.is_in_group(&"interactable"):
		_command = Command.INTERACT
		_interactable = hovered
	elif _ground_valid:
		if _force_attack:
			_attack_toward(_ground_point)
			return
		_command = Command.MOVE
		_move_target = _ground_point
		_target = null
		Vfx.ring(_ground_point, Vfx.GOLD, 0.15, 0.45, 0.3)


## Holding the button keeps walking toward the cursor (or keeps attacking).
func _held_click(delta: float) -> void:
	_hold_repath -= delta
	if _hold_repath > 0.0:
		return
	_hold_repath = 0.12
	if _command == Command.MOVE and _ground_valid:
		_move_target = _ground_point
	elif _command == Command.NONE and _ground_valid and not is_busy():
		if hovered is Actor and is_hostile_to(hovered as Actor):
			_command = Command.ATTACK
			_target = hovered as Actor
		else:
			_command = Command.MOVE
			_move_target = _ground_point


func command_attack(foe: Actor) -> void:
	_command = Command.ATTACK
	_target = foe


func command_move(point: Vector3) -> void:
	_command = Command.MOVE
	_move_target = point
	_target = null


func command_interact(thing: Node3D) -> void:
	_command = Command.INTERACT
	_interactable = thing


func current_target() -> Actor:
	return _target if _command == Command.ATTACK else null


## Stops whatever the hero was told to do (dialogue, cutscenes).
func halt() -> void:
	_command = Command.NONE
	_target = null
	_interactable = null


func _update_hover() -> void:
	if Game.camera == null:
		return
	var mouse := get_viewport().get_mouse_position()
	var ground := Game.camera.ray(mouse, LAYER_TERRAIN | LAYER_WORLD)
	_ground_valid = not ground.is_empty()
	if _ground_valid:
		_ground_point = ground["position"] as Vector3
	var found: Node3D = null
	var hit := Game.camera.ray(mouse, LAYER_ENEMY_TEAM | LAYER_INTERACT, true)
	if not hit.is_empty():
		var collider := hit["collider"] as Node
		if collider is Actor and not (collider as Actor).is_dead:
			found = collider as Actor
		elif collider.get_parent() and collider.get_parent().is_in_group(&"interactable"):
			found = collider.get_parent() as Node3D
	if found == null and _ground_valid:
		found = _nearest_enemy_to(_ground_point, PICK_RADIUS)
	if found != hovered:
		_highlight(hovered, false)
		hovered = found
		_highlight(hovered, true)
		hover_changed.emit(hovered)


func _highlight(thing: Node3D, on: bool) -> void:
	if thing == null or not is_instance_valid(thing):
		return
	var thing_body := thing.get(&"body") as ActorBody
	if thing_body == null:
		return
	var hostile := thing is Actor and is_hostile_to(thing as Actor)
	thing_body.set_highlight(Color(1.0, 0.35, 0.15) if hostile else Vfx.GOLD, 0.9 if on else 0.0)


func _nearest_enemy_to(point: Vector3, max_distance: float) -> Actor:
	var best: Actor = null
	var best_d := max_distance
	for node in get_tree().get_nodes_in_group(&"enemy_team"):
		var actor := node as Actor
		if not actor.is_targetable():
			continue
		var d := Vector2(actor.global_position.x - point.x, actor.global_position.z - point.z).length() - actor.radius * 0.5
		if d < best_d:
			best_d = d
			best = actor
	return best


func ground_point() -> Vector3:
	return _ground_point


# --- the frame -----------------------------------------------------------------

func _physics_process(delta: float) -> void:
	tick(delta)
	_regenerate(delta)
	if _potion_cooldown > 0.0:
		_potion_cooldown -= delta
	if is_dead:
		move_with(Vector3.ZERO, delta)
		return
	if input_enabled:
		_update_hover()
		if Input.is_action_pressed(&"move_click") and not _ui_has_mouse():
			_held_click(delta)
	if is_stunned():
		move_with(Vector3.ZERO, delta)
		return
	if caster.dashing():
		caster.tick_dash(delta)
		return
	if is_busy():
		move_with(Vector3.ZERO, delta)
		return
	var moving := false
	match _command:
		Command.MOVE:
			moving = _walk_to(_move_target, 0.25, delta)
			if not moving:
				_command = Command.NONE
		Command.ATTACK:
			moving = _pursue(delta)
		Command.INTERACT:
			moving = _approach_interactable(delta)
		_:
			move_with(Vector3.ZERO, delta)
	if not is_busy():
		if moving:
			body.play(&"run", 0.12, clampf(move_speed() / BASE_MOVE_SPEED, 0.6, 1.5) * 1.05)
		else:
			body.play(&"idle", 0.2)


func _ui_has_mouse() -> bool:
	var hovered_control := get_viewport().gui_get_hovered_control()
	return hovered_control != null and hovered_control.mouse_filter == Control.MOUSE_FILTER_STOP


## Walks toward `goal` along the navigation mesh; false once there.
func _walk_to(goal: Vector3, arrive: float, delta: float) -> bool:
	var flat := Vector2(goal.x - global_position.x, goal.z - global_position.z)
	if flat.length() <= arrive:
		move_with(Vector3.ZERO, delta)
		return false
	var direction := _path_direction(goal)
	if direction == Vector3.ZERO:
		move_with(Vector3.ZERO, delta)
		return false
	turn_toward(direction, delta, 16.0)
	var before := global_position
	move_with(direction * move_speed(), delta)
	_check_stuck(before, delta)
	return true


## Trying to walk but not getting anywhere (wedged by a blow between a wall and a
## slope): ease back onto the walkable ground.
func _check_stuck(before: Vector3, delta: float) -> void:
	var moved := Vector2(global_position.x - before.x, global_position.z - before.z).length()
	if moved > move_speed() * delta * 0.2:
		_stuck_time = 0.0
		return
	_stuck_time += delta
	if _stuck_time < 0.75:
		return
	_stuck_time = 0.0
	var map := get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(map) == 0:
		return
	# Back onto the walkable ground, and a fresh path from here: the old one may be
	# aiming at a point beyond the wall.
	var ground := NavigationServer3D.map_get_closest_point(map, global_position)
	global_position = ground + Vector3.UP * 0.15
	_path_goal = Vector3.INF


## The way toward `goal`, as a direction on the ground. The path comes from the
## navigation server and is followed on the ground plane: the mesh floats up to half
## a metre above the ground, so a point counts as reached by its horizontal distance
## (tight turns round a wall's end are walked, not cut). Paths are renewed when the
## goal moves and every 1.5 s (a blow may have knocked the hero off them).
func _path_direction(goal: Vector3) -> Vector3:
	var now := Time.get_ticks_msec()
	if not _path_goal.is_finite() or _path_goal.distance_squared_to(goal) > 0.09 or now - _path_stamp > 1500:
		_path_goal = goal
		_path_stamp = now
		path_index = 0
		var map := get_world_3d().navigation_map
		path = NavigationServer3D.map_get_path(map, global_position, goal, true) \
			if NavigationServer3D.map_get_iteration_id(map) > 0 else PackedVector3Array()
	while path_index < path.size() and Vector2(path[path_index].x - global_position.x, path[path_index].z - global_position.z).length() < PATH_REACH:
		path_index += 1
	if path_index >= path.size():
		# No navigation mesh here (or at the end of the path): head straight there.
		var direct := Vector3(goal.x - global_position.x, 0.0, goal.z - global_position.z)
		return direct.normalized() if direct.length() > 0.3 else Vector3.ZERO
	var next := path[path_index]
	return Vector3(next.x - global_position.x, 0.0, next.z - global_position.z).normalized()


func _pursue(delta: float) -> bool:
	if _target == null or not is_instance_valid(_target) or _target.is_dead:
		_command = Command.NONE
		_target = null
		move_with(Vector3.ZERO, delta)
		return false
	var reach := weapon_range() + _target.radius + RANGE_PAD
	var flat := Vector2(_target.global_position.x - global_position.x, _target.global_position.z - global_position.z)
	if flat.length() <= reach:
		move_with(Vector3.ZERO, delta)
		_attack(_target)
		return false
	return _walk_to(_target.global_position, reach * 0.8, delta)


func _approach_interactable(delta: float) -> bool:
	if _interactable == null or not is_instance_valid(_interactable):
		_command = Command.NONE
		move_with(Vector3.ZERO, delta)
		return false
	var reach := float(_interactable.get(&"interact_range")) if _interactable.get(&"interact_range") != null else 2.0
	var flat := Vector2(_interactable.global_position.x - global_position.x, _interactable.global_position.z - global_position.z)
	if flat.length() <= reach:
		move_with(Vector3.ZERO, delta)
		face(_interactable.global_position)
		var thing := _interactable
		_command = Command.NONE
		_interactable = null
		thing.call(&"interact", self)
		return false
	return _walk_to(_interactable.global_position, reach * 0.85, delta)


# --- attacks -------------------------------------------------------------------

func _attack(target: Actor) -> void:
	face(target.global_position)
	var w := weapon()
	var animation := StringName(String(w.base().get("anim", "attack_slash"))) if w else &"attack_slash"
	start_action(animation, 1.0 / attacks_per_second(), _attack_impact.bind(target), Callable())


func _attack_toward(point: Vector3) -> void:
	_command = Command.NONE
	face(point)
	var w := weapon()
	var animation := StringName(String(w.base().get("anim", "attack_slash"))) if w else &"attack_slash"
	start_action(animation, 1.0 / attacks_per_second(), _attack_impact.bind(null), Callable())


func _attack_impact(target: Actor) -> void:
	var reach := weapon_range() + RANGE_PAD
	var victims: Array[Actor] = []
	if target and is_instance_valid(target) and not target.is_dead:
		var d := Vector2(target.global_position.x - global_position.x, target.global_position.z - global_position.z).length()
		if d <= reach + target.radius + 0.6:
			victims.append(target)
	else:
		victims = Combat.in_cone(self, global_position, forward(), reach + 0.4, 50.0)
		if victims.size() > 1:
			victims.resize(1)
	var trail_color := Vfx.GOLD if buff_active(&"war_cry") else Color(1.0, 0.93, 0.78)
	Vfx.arc(global_position + Vector3.UP * 1.1, global_basis, trail_color, reach * 0.75, 0.18)
	Sfx.play_at(&"swing", global_position)
	for victim in victims:
		var info := roll_hit(1.0)
		info.knockback = (victim.global_position - global_position).normalized() * 2.0
		info.knockback.y = 0.0
		deal(victim, info)


# --- resources -----------------------------------------------------------------

func _regenerate(delta: float) -> void:
	if is_dead:
		return
	var max_h := max_health()
	if health < max_h:
		health = minf(max_h, health + stats.value(Stats.HEALTH_REGEN) * delta)
		health_changed.emit(health, max_h)
	var max_i := max_ichor()
	if ichor < max_i:
		ichor = minf(max_i, ichor + stats.value(Stats.ICHOR_REGEN) * delta)
		ichor_changed.emit(ichor, max_i)


func spend_ichor(amount: float) -> bool:
	if ichor < amount:
		return false
	ichor -= amount
	ichor_changed.emit(ichor, max_ichor())
	return true


func restore_ichor(amount: float) -> void:
	ichor = minf(max_ichor(), ichor + amount)
	ichor_changed.emit(ichor, max_ichor())


func use_potion(id: StringName) -> void:
	if int(belt.get(id, 0)) <= 0:
		Events.notified.emit("No %s left." % ("healing draughts" if id == &"potion_health" else "ichor draughts"), Color("#C9B98F"))
		return
	if _potion_cooldown > 0.0:
		return
	_potion_cooldown = POTION_COOLDOWN
	belt[id] = int(belt[id]) - 1
	belt_changed.emit()
	var data := DB.item_base(id)
	if id == &"potion_health":
		_drip_heal(max_health() * float(data.get("heal", 0.45)))
		Vfx.motes(global_position + Vector3.UP, Color(0.85, 0.2, 0.15), 14, 0.5, 0.9)
	else:
		restore_ichor(max_ichor() * float(data.get("restore", 0.5)))
		Vfx.motes(global_position + Vector3.UP, Vfx.GOLD, 14, 0.5, 0.9)
	Sfx.play(&"potion")


func _drip_heal(total: float) -> void:
	for i in 6:
		get_tree().create_timer(0.1 * i, false).timeout.connect(heal.bind(total / 6.0))


# --- progress ------------------------------------------------------------------

func gain_xp(amount: int) -> void:
	if is_dead:
		return
	xp += amount
	Events.xp_gained.emit(amount)
	while xp >= Game.xp_to_next(level):
		xp -= Game.xp_to_next(level)
		_level_up()
	xp_changed.emit(xp, Game.xp_to_next(level), level)


func _level_up() -> void:
	level += 1
	attribute_points += 3
	skills.points += 1
	stats.refresh()
	health = max_health()
	ichor = max_ichor()
	health_changed.emit(health, max_health())
	ichor_changed.emit(ichor, max_ichor())
	Vfx.beam(global_position, Vfx.GOLD, 0.6, 6.0, 1.2, 0.7)
	Vfx.ring(global_position, Vfx.GOLD, 0.3, 4.0, 0.8)
	Vfx.motes(global_position + Vector3.UP, Vfx.GOLD, 30, 0.8, 1.8)
	Sfx.play(&"level_up")
	leveled_up.emit(level)
	Events.level_reached.emit(level)
	Events.notified.emit("Level %d — your thread grows longer." % level, Vfx.GOLD)


func spend_attribute(stat: StringName) -> bool:
	if attribute_points <= 0 or not attributes.has(stat):
		return false
	attribute_points -= 1
	attributes[stat] = int(attributes[stat]) + 1
	stats.refresh()
	attributes_changed.emit()
	health_changed.emit(health, max_health())
	ichor_changed.emit(ichor, max_ichor())
	return true


func buff_active(id: StringName) -> bool:
	return stats.has_source(StringName("buff_" + String(id)))


# --- items ---------------------------------------------------------------------

## Takes a ground item; false (and it stays) when there's no room.
func pick_up(item: Item, amount_gold: int = 0) -> bool:
	if amount_gold > 0:
		gold += amount_gold
		gold_changed.emit(gold)
		Events.gold_changed.emit(gold)
		Sfx.play(&"coins")
		return true
	if item == null:
		return false
	if item.is_potion():
		var have := int(belt.get(item.base_id, 0))
		if have < BELT_MAX:
			belt[item.base_id] = mini(BELT_MAX, have + item.count)
			belt_changed.emit()
			Events.item_picked_up.emit(item)
			Sfx.play(&"pickup")
			return true
	if item.is_quest():
		_make_room_for(item)
	if not inventory.add(item):
		Events.notified.emit("Your pack is full.", Color("#C9B98F"))
		return false
	Events.item_picked_up.emit(item)
	Sfx.play(&"pickup")
	return true


## Story items always go in: with the bag full, the plainest gear in it (largest
## first) is set down on the ground until the item fits.
func _make_room_for(item: Item) -> void:
	var gear: Array = inventory.items().filter(func(other: Variant) -> bool: return not (other as Item).is_quest())
	gear.sort_custom(func(a: Variant, b: Variant) -> bool:
		var ia := a as Item
		var ib := b as Item
		if ia.rarity != ib.rarity:
			return ia.rarity < ib.rarity
		return ia.size().x * ia.size().y > ib.size().x * ib.size().y)
	for other: Variant in gear:
		if inventory.find_space(item).x >= 0:
			return
		var set_down := other as Item
		inventory.remove(set_down)
		drop_item(set_down)
		Events.notified.emit("No room in your pack: you set down the %s." % set_down.display_name(), Color("#C9B98F"))


## Moves an item from the bag to its slot; the old one goes back to the bag.
func equip_from_inventory(item: Item, slot: String = "") -> bool:
	if slot == "":
		slot = equipment.slot_for(item)
	if slot == "" or not equipment.accepts(slot, item):
		return false
	inventory.remove(item)
	var previous := equipment.equip(slot, item)
	if previous and not inventory.add(previous):
		drop_item(previous)
	return true


func unequip_to_inventory(slot: String) -> bool:
	var item := equipment.get_item(slot)
	if item == null:
		return false
	if inventory.find_space(item).x < 0:
		Events.notified.emit("Your pack is full.", Color("#C9B98F"))
		return false
	equipment.unequip(slot)
	inventory.add(item)
	return true


## Drops an item at the hero's feet.
func drop_item(item: Item) -> void:
	GroundItem.spawn(item, global_position + forward() * 0.8, global_position)


func _on_equipment_changed(slot: String) -> void:
	var item := equipment.get_item(slot)
	stats.set_source(StringName("eq_" + slot), item.mods() if item else [])
	match slot:
		"weapon":
			body.attach("weapon", item.model_slug() if item else "")
		"shield":
			body.attach("shield", "aspis_hero" if item and item.base_id == &"aspis" and item.rarity >= Item.Rarity.HEROIC else (item.model_slug() if item else ""))
		"head":
			body.attach("helmet", item.model_slug() if item else "")
		"chest":
			for variant: String in ["Cuirass_Linen", "Cuirass_Bronze"]:
				body.set_variant(variant, item != null and String(item.base().get("variant", "")) == variant)
		"legs":
			for variant: String in ["Greaves_Bronze", "Wraps_Leather"]:
				body.set_variant(variant, item != null and String(item.base().get("variant", "")) == variant)
	health = minf(health, max_health())
	health_changed.emit(health, max_health())
	ichor_changed.emit(ichor, max_ichor())
	gear_changed.emit()


# --- death ---------------------------------------------------------------------

func _on_hurt(info: DamageInfo) -> void:
	Game.shake(clampf(info.final_amount / max_health() * 2.5, 0.08, 0.5))
	if not is_busy() and not is_stunned() and info.final_amount > max_health() * 0.12:
		start_action(&"hit", 0.28)


func _on_died(_killer: Node3D) -> void:
	halt()
	body.play_once(&"die", 1.0)
	Events.player_died.emit()


## Wakes at the last lit hearth with full health and ichor.
func respawn(at: Vector3) -> void:
	global_position = at
	is_dead = false
	collision_layer = LAYER_PLAYER_TEAM
	collision_mask = LAYER_WORLD | LAYER_TERRAIN | LAYER_ENEMY_TEAM
	health = max_health()
	ichor = max_ichor()
	health_changed.emit(health, max_health())
	ichor_changed.emit(ichor, max_ichor())
	body.play(&"idle", 0.0)
	Vfx.beam(global_position, Vfx.FIRE, 0.8, 4.0, 1.2)
	Events.player_respawned.emit()
	if Game.camera:
		Game.camera.snap()
