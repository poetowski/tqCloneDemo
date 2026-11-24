class_name ElaionLevel
extends Level
## Elaion, the slice's zone (docs/LEVEL_ELAION.md). Adds the story beats to Level:
## waking on the beach, the first quest, the boss's spawn, and the end of the demo
## once the First Blade of Atropos is claimed.

const INTRO: Array[String] = [
	"The shears closed halfway.",
	"You died on the sand at Elaion, and then you got up.",
]

var boss: BronzeBull
var _finished := false


func _ready() -> void:
	super._ready()
	Quests.reset()
	Quests.completed.connect(_on_quest_completed)
	# The blade ends the slice even for a hero who skipped the quests.
	Events.item_picked_up.connect(func(item: RefCounted) -> void:
		if (item as Item).base_id == &"blade_of_atropos":
			_finish_demo())
	_spawn_boss.call_deferred()
	if not DevTools.has_option("shot-scenario"):
		_intro.call_deferred()
	else:
		Quests.start(&"weaver")


func _intro() -> void:
	player.input_enabled = false
	player.body.play_once(&"rise", 2.2)
	for i in INTRO.size():
		get_tree().create_timer(0.6 + i * 2.2, false).timeout.connect(Events.notified.emit.bind(INTRO[i], UIStyle.GOLD_BRIGHT))
	await get_tree().create_timer(4.6, false).timeout
	player.input_enabled = true
	Quests.start(&"weaver")


func _spawn_boss() -> void:
	var marker := find_child("BossSpawn", true, false) as Marker3D
	if marker == null:
		return
	boss = Enemy.create(&"bronze_bull", int(marker.get_meta("level", 7))) as BronzeBull
	boss.name = "Khalkotauros"
	boss.position = marker.global_position
	boss.rotation.y = marker.rotation.y
	boss.arena_radius = float(marker.get_meta("arena_radius", 16.0))
	if marker.has_meta("arena_center"):
		var centre := marker.get_meta("arena_center") as Vector2
		boss.arena_center = Vector3(centre.x, marker.global_position.y, centre.y)
	add_child(boss)


func _on_scenario(scenario: String) -> void:
	if scenario == "tour":
		_tour()
	elif scenario == "playthrough":
		_playthrough()
	elif scenario == "boss":
		_tour()
		Engine.time_scale = 1.0
		player.global_position = Vector3(4.0, 20.3, -93.0)
		camera.snap()
		for node in get_children():
			if node is Autopilot:
				(node as Autopilot).route.clear()
	elif scenario == "talk":
		var klotho := find_child("Klotho", true, false)
		if klotho:
			player.global_position = (klotho as Node3D).global_position + Vector3(1.6, 0.0, 1.6)
			camera.snap()
			klotho.call(&"interact", player)
	elif scenario == "paths":
		_check_paths.call_deferred()
	else:
		super._on_scenario(scenario)


## A fair run for balance: a level-1 hero on autopilot who levels, learns, equips
## and drinks like a player would. Reports deaths and the level at each area.
func _playthrough() -> void:
	Engine.time_scale = float(DevTools.option("speed", "3"))
	var pilot := Autopilot.new()
	pilot.player = player
	pilot.manage_hero = true
	# Like a player following the quest log: after the terraces, back to Klotho for
	# her reward, then on up the road.
	# (Route: 0 start, 1-3 to Klotho and back, 4-5 the terraces, 6+ the road.)
	var route := _route()
	var back: Array[Vector3] = [route[4]]
	back.append_array(route.slice(1, 4))
	back.append(route[4])
	back.append(route[5])
	for i in back.size():
		route.insert(6 + i, back[i])
	pilot.route = route
	add_child(pilot)
	Events.area_entered.connect(func(area: String) -> void:
		print("[balance] %s at level %d, %d deaths, %d kills, belt %s" % [area, player.level, pilot.deaths, Game.kills, player.belt]))
	Events.demo_completed.connect(func() -> void:
		print("[balance] demo completed at level %d with %d deaths in %d s of game time" % [player.level, pilot.deaths, Game.play_seconds() * int(Engine.time_scale)])
		get_tree().create_timer(4.0, false).timeout.connect(DevTools.finish_shot))


## Asks the navigation for a path between each pair of route waypoints and
## reports the ones that don't arrive (npm run shot -- ... --scenario=paths).
func _check_paths() -> void:
	var map := get_world_3d().navigation_map
	for i in 180:
		await get_tree().physics_frame
		if i % 30 == 0:
			print("[paths] frame %d: iteration %d, closest to start %s" % [i, NavigationServer3D.map_get_iteration_id(map),
				NavigationServer3D.map_get_closest_point(map, player.global_position)])
	var region_rid := navigation.get_rid() if navigation else RID()
	print("[paths] map regions %d, iteration %d, active %s, cell %.2f; region enabled %s, on map %s, polygons %d" % [
		NavigationServer3D.map_get_regions(map).size(), NavigationServer3D.map_get_iteration_id(map), NavigationServer3D.map_is_active(map),
		NavigationServer3D.map_get_cell_size(map), navigation.enabled if navigation else false,
		NavigationServer3D.region_get_map(region_rid) == map if navigation else false,
		navigation.navigation_mesh.get_polygon_count() if navigation and navigation.navigation_mesh else -1])
	var points := _route()
	var broken := 0
	for i in points.size() - 1:
		var a := NavigationServer3D.map_get_closest_point(map, points[i])
		var b := NavigationServer3D.map_get_closest_point(map, points[i + 1])
		var path := NavigationServer3D.map_get_path(map, a, b, true)
		var arrives := not path.is_empty() and path[path.size() - 1].distance_to(b) < 1.0
		var length := 0.0
		for k in range(1, path.size()):
			length += path[k - 1].distance_to(path[k])
		if not arrives:
			broken += 1
		print("[paths] %d -> %d %s: %s .. %s, %.0f m, ends %s" % [i, i + 1, "OK" if arrives else "BROKEN", points[i], points[i + 1], length,
			path[path.size() - 1] if not path.is_empty() else Vector3.ZERO])
	print("[paths] %d broken link(s)" % broken)
	# Every walkable polygon should connect to the start: an island strands whoever
	# is knocked onto it. And none should lie under the sea.
	if navigation and navigation.navigation_mesh:
		var mesh := navigation.navigation_mesh
		var vertices := mesh.get_vertices()
		var start := NavigationServer3D.map_get_closest_point(map, points[0])
		var islands := 0
		var underwater := 0
		for p in mesh.get_polygon_count():
			var centre := Vector3.ZERO
			var polygon := mesh.get_polygon(p)
			for index in polygon:
				centre += vertices[index]
			centre = navigation.global_transform * (centre / float(polygon.size()))
			if centre.y < 0.1:
				underwater += 1
			var path := NavigationServer3D.map_get_path(map, centre, start, false)
			if path.is_empty() or path[path.size() - 1].distance_to(start) > 1.0:
				islands += 1
				if islands <= 8:
					print("[paths] cut off: polygon %d at %s" % [p, centre])
		print("[paths] %d of %d polygon(s) cut off from the start, %d under the sea" % [islands, mesh.get_polygon_count(), underwater])
		_detours(map, mesh)
	await _walk_tests()
	DevTools.finish_shot()


## How easy the ground is to cross: for random pairs of walkable points 8–30 m apart
## (seeded, so runs compare), the walk over the straight line. A maze of risers and
## walls shows as long detours. Weighted by area, so big open ground counts more.
func _detours(map: RID, mesh: NavigationMesh) -> void:
	var vertices := mesh.get_vertices()
	var centres: Array[Vector3] = []
	var weights: Array[float] = []
	var total := 0.0
	for p in mesh.get_polygon_count():
		var polygon := mesh.get_polygon(p)
		var centre := Vector3.ZERO
		for index in polygon:
			centre += vertices[index]
		centres.append(navigation.global_transform * (centre / float(polygon.size())))
		var a := vertices[polygon[0]]
		var area := 0.0
		for k in range(1, polygon.size() - 1):
			area += (vertices[polygon[k]] - a).cross(vertices[polygon[k + 1]] - a).length() * 0.5
		total += area
		weights.append(total)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var ratios: Array[float] = []
	var worst: Array = []
	var tries := 0
	while ratios.size() < 400 and tries < 20000:
		tries += 1
		var a := centres[weights.bsearch(rng.randf() * total)]
		var b := centres[weights.bsearch(rng.randf() * total)]
		var straight := Vector2(b.x - a.x, b.z - a.z).length()
		if straight < 8.0 or straight > 30.0:
			continue
		var path := NavigationServer3D.map_get_path(map, a, b, true)
		var length := 0.0
		for k in range(1, path.size()):
			length += path[k - 1].distance_to(path[k])
		var ratio := length / straight
		ratios.append(ratio)
		worst.append([ratio, a, b])
	ratios.sort()
	worst.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) > float(y[0]))
	var mean := 0.0
	for r in ratios:
		mean += r
	mean /= maxf(1.0, float(ratios.size()))
	var walkable_area := total
	print("[paths] detours over %d pairs: mean %.2f, median %.2f, 90th %.2f, worst %.2f; walkable area %d m²" % [ratios.size(), mean,
		ratios[ratios.size() / 2], ratios[int(ratios.size() * 0.9)], ratios[ratios.size() - 1], int(walkable_area)])
	for k in 5:
		print("[paths]   long way round: x%.1f from %s to %s" % [float(worst[k][0]), worst[k][1], worst[k][2]])


## Spots where the hero once got pinned: put it there, order a walk, and see it
## arrive (or report where it stalled and what it was pressed against).
const WALK_TESTS: Array[Array] = [
	[Vector3(5.05, 3.41, 20.4), Vector3(12.0, 5.65, 42.0)],
	[Vector3(5.05, 3.45, 18.1), Vector3(12.0, 5.65, 42.0)],
	[Vector3(5.0, 3.4, 17.5), Vector3(12.0, 5.65, 42.0)],
	[Vector3(6.3, 4.3, 13.8), Vector3(42.0, 9.56, 26.0)],
]


func _walk_tests() -> void:
	# Nobody else on the field: the walk is the test.
	for node in get_tree().get_nodes_in_group(&"spawners") + get_tree().get_nodes_in_group(&"enemy_team"):
		node.queue_free()
	await get_tree().physics_frame
	var stalled := 0
	for test: Array in WALK_TESTS:
		# (Heights in the table are only hints: start on the ground as it is now.)
		var from := player.ground_below(test[0] as Vector3)
		var goal := test[1] as Vector3
		player.global_position = from
		player.velocity = Vector3.ZERO
		player.halt()
		await get_tree().physics_frame
		var arrived := false
		var trail: Array[String] = []
		var lowest := INF
		var fall_from := Vector3.ZERO
		var last := player.global_position
		for frame in 1800:
			# Ordered every frame, as the autopilot (and a held mouse button) does.
			player.command_move(goal)
			await get_tree().physics_frame
			if player.global_position.y < lowest:
				lowest = player.global_position.y
				if last.y - player.global_position.y > 0.5 and fall_from == Vector3.ZERO:
					fall_from = last
			last = player.global_position
			if frame % 120 == 0:
				trail.append("(%.1f, %.1f, %.1f)" % [player.global_position.x, player.global_position.y, player.global_position.z])
			if Vector2(player.global_position.x - goal.x, player.global_position.z - goal.z).length() < 1.5:
				arrived = true
				break
		var pressed: Array[String] = []
		for k in player.get_slide_collision_count():
			var collider := player.get_slide_collision(k).get_collider() as Node
			if collider:
				pressed.append("%s/%s" % [collider.get_parent().name if collider.get_parent() else "", collider.name])
		var fell := lowest < minf(from.y, goal.y) - 2.0
		if fell:
			print("[paths] walk %s -> %s FELL to y %.1f, first drop from %s" % [from, goal, lowest, fall_from])
		if not arrived or fell:
			stalled += 1
		var path := player.path
		var index := player.path_index
		print("[paths] walk %s -> %s: %s; trail %s; touching %s; path %d points (index %d): %s" % [from, goal,
			"ARRIVED" if arrived else "STALLED", " ".join(trail), pressed, path.size(), index, path.slice(maxi(0, index - 2), index + 3)])
		if not arrived:
			# The ground just ahead, every 0.25 m toward the next path point.
			var here := player.global_position
			var ahead := path[mini(index, path.size() - 1)] if not path.is_empty() else goal
			var heading := Vector3(ahead.x - here.x, 0.0, ahead.z - here.z).normalized()
			var space := get_world_3d().direct_space_state
			var profile: Array[String] = []
			for k in range(-2, 9):
				var at := here + heading * (0.25 * k)
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 3.0, at + Vector3.DOWN * 3.0, Actor.LAYER_WORLD | Actor.LAYER_TERRAIN))
				profile.append("%.2f" % ((hit["position"] as Vector3).y if not hit.is_empty() else NAN))
			print("[paths]   ground toward %s from %s: %s; on wall %s, on floor %s" % [ahead, here, " ".join(profile), player.is_on_wall(), player.is_on_floor()])
	print("[paths] %d stalled walk(s)" % stalled)


func _route() -> Array[Vector3]:
	var points: Array[Vector3] = []
	var route_node := find_child("Route", true, false)
	if route_node:
		for p: Variant in route_node.get_meta("points", []) as Array:
			var row := p as Array
			points.append(Vector3(float(row[0]), float(row[1]), float(row[2])))
	return points


## An automated run through the whole zone with a seasoned hero: checks that the
## route can be walked, every quest step can be done and the boss can be beaten.
func _tour() -> void:
	Engine.time_scale = float(DevTools.option("speed", "3"))
	for i in 7:
		player.gain_xp(Game.xp_to_next(player.level))
	for id: StringName in [&"fates_lash", &"war_cry", &"bound_shades", &"atropos_mercy", &"aspis_bash", &"fates_lash", &"lunge"]:
		player.skills.learn(id, player.level)
	for attribute: StringName in [&"might", &"might", &"might", &"cunning", &"cunning", &"spirit"]:
		for k in 3:
			player.spend_attribute(attribute)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for base: StringName in [&"muscle_cuirass", &"helm_corinthian", &"bronze_greaves", &"aspis"]:
		player.equipment.equip(player.equipment.slot_for(Item.create(base)), Loot.roll_item(6, Item.Rarity.HEROIC, rng, base))
	player.equipment.equip("weapon", Loot.roll_item(6, Item.Rarity.HEROIC, rng, &"dory"))
	player.belt[&"potion_health"] = 9
	player.belt[&"potion_ichor"] = 9
	player.health = player.max_health()
	var pilot := Autopilot.new()
	pilot.player = player
	var route_node := find_child("Route", true, false)
	if route_node:
		for p: Variant in route_node.get_meta("points", []) as Array:
			var row := p as Array
			pilot.route.append(Vector3(float(row[0]), float(row[1]), float(row[2])))
	add_child(pilot)
	Events.demo_completed.connect(func() -> void:
		get_tree().create_timer(4.0, false).timeout.connect(DevTools.finish_shot))


func _on_quest_completed(id: StringName) -> void:
	if id == &"bronze_heart":
		_finish_demo()


func _finish_demo() -> void:
	if _finished:
		return
	_finished = true
	Events.demo_completed.emit()
	await get_tree().create_timer(3.0, false).timeout
	var card := load("res://src/ui/end/end_card.gd") as GDScript
	if card:
		hud.add_child(card.new() as Control)
