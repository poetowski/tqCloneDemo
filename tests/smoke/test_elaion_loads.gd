extends GutTest
## The zone loads and wires together: hero, camera, HUD, packs, people, boss.

var _level: Node


func before_all() -> void:
	DevTools.options["shot-scenario"] = "test"
	_level = (load("res://src/world/elaion/elaion.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_level)
	await wait_frames(20)


func after_all() -> void:
	DevTools.options.erase("shot-scenario")
	_level.queue_free()
	await wait_frames(2)


func test_hero_camera_and_hud() -> void:
	assert_not_null(Game.player)
	assert_not_null(Game.camera)
	assert_not_null(Game.hud)
	assert_true((Game.hud as HUD).panels.has(&"inventory"))
	assert_true((Game.hud as HUD).panels.has(&"loom"))


func test_packs_people_and_boss_are_there() -> void:
	assert_gte(get_tree().get_nodes_in_group(&"spawners").size(), 10)
	assert_eq(get_tree().get_nodes_in_group(&"npcs").size(), 2)
	assert_eq(get_tree().get_nodes_in_group(&"shrines").size(), 3)
	assert_not_null(_level.find_child("Khalkotauros", true, false))


func test_a_lit_hearth_heals_only_once() -> void:
	var hearth := get_tree().get_nodes_in_group(&"shrines")[0] as Shrine
	var player := Game.player
	hearth.interact(player)
	player.health = player.max_health() * 0.5
	hearth.interact(player)
	assert_almost_eq(player.health, player.max_health() * 0.5, 0.01, "a lit hearth is no well")
	assert_eq(Game.respawn_point, hearth.global_position + Vector3(0, 0, 2.6), "but it is where the hero wakes")
	player.health = player.max_health()


func test_a_freed_hover_target_is_forgotten() -> void:
	var item := GroundItem.spawn(Item.create(&"potion_health"), Game.player.global_position + Vector3(3, 0, 0), Game.player.global_position)
	Game.player.hovered = item
	item.free()
	# A freed object already compares equal to null; what matters is that it is gone,
	# so `hovered is Actor` and typed calls on it no longer error (they froze the hero).
	Game.player._unhandled_input(InputEventAction.new())
	assert_eq(Game.player._hovered_id, 0, "the picked-up item no longer counts as under the cursor")
	assert_false(Game.player.hovered is Actor, "testing the hover no longer touches a freed object")
	Game.player._update_hover()
	assert_true(Game.player.hovered == null or is_instance_valid(Game.player.hovered), "hovering again works")


func test_the_maps_point_at_the_next_goal() -> void:
	Quests.reset()
	Quests.start(&"weaver")
	var marks := MapMarkers.objectives(get_tree())
	assert_eq(marks.size(), 1)
	var klotho: Node3D = null
	for node in get_tree().get_nodes_in_group(&"npcs"):
		if String(node.get(&"npc_id")) == "klotho":
			klotho = node as Node3D
	assert_almost_eq((marks[0]["position"] as Vector3).distance_to(klotho.global_position), 0.0, 0.01, "a talk goal points at the person")
	Quests.talked_to("klotho")
	marks = MapMarkers.objectives(get_tree())
	var terraces := _level.find_child("Zone_TheOliveTerraces", true, false) as Node3D
	assert_almost_eq((marks[0]["position"] as Vector3).distance_to(terraces.global_position), 0.0, 0.01, "a marker names the zone")
	Quests.reset()
	Quests.start(&"weaver")


func test_moods_colour_the_air() -> void:
	var atmosphere := _level.find_child("Atmosphere", true, false) as Atmosphere
	assert_not_null(atmosphere)
	atmosphere.set_mood(&"necropolis", true)
	await wait_frames(6)
	var env := (_level.get_node("WorldEnvironment") as WorldEnvironment).environment
	assert_eq(atmosphere.mood, &"necropolis")
	assert_almost_eq(env.fog_density, 0.0062, 0.0005, "the necropolis is hazier")
	assert_lt(env.adjustment_saturation, 1.0, "and greyer")
	atmosphere.set_mood(&"village", true)
	await wait_frames(6)
	assert_gt(env.adjustment_saturation, 1.0)


func test_first_quest_started() -> void:
	assert_true(Quests.is_active(&"weaver"))


func test_hero_starts_armed() -> void:
	assert_not_null(Game.player.equipment.get_item("weapon"))
	assert_true(Game.player.skills.knows(&"lunge"))
	assert_eq(Game.player.skills.points, 1)


func test_the_story_runs_to_the_end() -> void:
	# Klotho's errand: talk, ten Unthreaded, talk again -> her chiton and the next quest.
	Quests.reset()
	Quests.start(&"weaver")
	Quests.talked_to("klotho")
	var shade := Enemy.new()
	shade.def = {"tags": ["unthreaded"]}
	shade.id = &"shade_hoplite"
	for i in 10:
		Events.actor_died.emit(shade, null)
	shade.free()
	Quests.talked_to("klotho")
	assert_true(Quests.is_done(&"weaver"))
	var has_chiton := Game.player.inventory.items().any(func(it: Variant) -> bool: return (it as Item).unique_id == &"thread_woven_chiton")
	assert_true(has_chiton, "Klotho's reward is in the bag")
	assert_true(Quests.is_active(&"dead_walk"))
	# Lykos already fell and the gate is already open: those stages settle at once.
	Quests.reset()
	Game.set_flag("killed_captain_lykos")
	Game.set_flag("gate_open")
	Quests.start(&"dead_walk")
	assert_true(Quests.is_done(&"dead_walk"), "goals the world already met are skipped")
	assert_true(Quests.is_active(&"bronze_heart"))
	# Taking the First Blade ends the slice.
	var ended := [false]
	Events.demo_completed.connect(func() -> void: ended[0] = true, CONNECT_ONE_SHOT)
	Game.player.pick_up(Item.create(&"blade_of_atropos"))
	assert_true(ended[0], "the blade ends the demo")
	Game.flags.clear()
	Quests.reset()


func test_story_items_fit_a_full_bag() -> void:
	var bag := Game.player.inventory
	var filler: Array[Item] = []
	while true:
		var ring := Item.create(&"bronze_ring", 1, Item.Rarity.BLESSED)
		if not bag.add(ring):
			break
		filler.append(ring)
	var seal := Item.create(&"seal_of_sanctuary")
	var on_ground := get_tree().get_nodes_in_group(&"ground_items").size()
	assert_true(Game.player.pick_up(seal), "the seal goes in even when the bag is full")
	assert_true(bag.has_item(seal))
	assert_gt(get_tree().get_nodes_in_group(&"ground_items").size(), on_ground, "plain gear was set down to make room")
	for it: Item in filler:
		bag.remove(it)
	bag.remove(seal)
