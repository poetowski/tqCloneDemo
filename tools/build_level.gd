extends SceneTree
## Builds src/world/elaion/elaion.tscn from data/level/elaion_layout.json (written by
## tools/blender/level/elaion.py): the light and sky, the terrain and every prop under
## a NavigationRegion3D (baked here, so the level loads ready), the gameplay nodes
## (spawners, people, hearths, chests, pots, the gate, zones, the boss's mark) and the
## grass. Run it with `npm run level`. The scene is a normal, editable Godot scene,
## but rebuilding it replaces hand edits; put lasting changes in the level script.

const LAYOUT := "res://data/level/elaion_layout.json"
const OUT := "res://src/world/elaion/elaion.tscn"
const TERRAIN := "res://assets/models/level/elaion_terrain/elaion_terrain.glb"
const PROPS := "res://assets/models/props/%s/%s.glb"

const LAYER_WORLD := 1
const LAYER_TERRAIN := 1 << 5
## Ground below this height is under the sea (the waterline is at 0; the beach sand
## starts at 0.25).
const SEA_WALK_LINE := 0.1
## Loaded in _initialize: a --script file is compiled before the autoloads exist,
## so it must not name game classes that use them.
const SCRIPTS := {
	"spawner": "res://src/world/spawner.gd", "npc": "res://src/world/npc.gd", "shrine": "res://src/world/shrine.gd",
	"chest": "res://src/world/chest.gd", "breakable": "res://src/world/breakable.gd", "gate": "res://src/world/gate.gd",
	"fire": "res://src/world/fire.gd", "zone": "res://src/world/zone.gd", "grass": "res://src/world/grass_field.gd", "mist": "res://src/world/mist.gd",
}

var _root: Node3D
var _owned: Array[Node] = []
var _scenes: Dictionary = {}


func _initialize() -> void:
	# The root window enters the tree after _initialize; build once it has.
	_build.call_deferred()


func _build() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT))
	if not data is Dictionary:
		printerr("level: cannot read ", LAYOUT)
		quit(1)
		return
	var layout := data as Dictionary
	_root = Node3D.new()
	_root.name = "Elaion"
	_root.set_script(load("res://src/world/elaion/elaion.gd"))
	_root.set(&"start_marker", NodePath("Start"))
	_root.set(&"music", &"village")
	_root.set(&"ambience", &"shore")
	_environment()
	var nav := NavigationRegion3D.new()
	nav.name = "Navigation"
	nav.navigation_mesh = _navmesh()
	_add(_root, nav)
	var terrain := (load(TERRAIN) as PackedScene).instantiate() as Node3D
	terrain.name = "Terrain"
	_add(nav, terrain)
	terrain.add_to_group(&"navigation_geometry", true)
	var groups: Dictionary = {}
	var gameplay := _child(_root, "Gameplay")
	var counts: Dictionary = {}
	for entry: Variant in layout["items"] as Array:
		var item := entry as Dictionary
		var kind := String(item["type"])
		counts[kind] = int(counts.get(kind, 0)) + 1
		var p := item["pos"] as Array
		var at := Vector3(float(p[0]), float(p[1]), float(p[2]))
		var yaw := deg_to_rad(float(item.get("rot", 0.0)))
		match kind:
			"prop":
				var group := String(item.get("group", "Props"))
				if not groups.has(group):
					groups[group] = _child(nav, group)
					(groups[group] as Node).add_to_group(&"navigation_geometry", true)
				var model := String(item["model"])
				var node := _instance(model)
				if node == null:
					continue
				node.name = "%s_%d" % [model, counts[kind]]
				node.position = at
				node.rotation.y = yaw
				node.scale = Vector3.ONE * float(item.get("scale", 1.0))
				_add(groups[group] as Node, node)
				if group in ["Village", "Terraces", "Sanctuary", "Arena", "Necropolis"]:
					node.add_to_group(&"fadeable", true)
			"start":
				var start := Marker3D.new()
				start.name = "Start"
				start.position = at
				start.rotation.y = yaw
				_add(_root, start)
			"spawner":
				var spawner := _scripted("spawner", Marker3D.new())
				spawner.set(&"name", "Pack_%d" % counts[kind])
				spawner.set(&"position", at)
				spawner.set(&"pack", PackedStringArray(item["pack"] as Array))
				spawner.set(&"level", int(item.get("level", 1)))
				spawner.set(&"activation_radius", float(item.get("radius", 15.0)))
				spawner.set(&"no_champion", bool(item.get("no_champion", false)))
				_add(_child(gameplay, "Spawners"), spawner)
			"npc":
				var npc := _scripted("npc", Node3D.new())
				npc.set(&"npc_id", String(item["id"]))
				npc.name = String(item["id"]).capitalize()
				npc.set(&"position", at)
				npc.rotation.y = yaw
				_add(_child(gameplay, "People"), npc)
			"shrine":
				var shrine := _scripted("shrine", Node3D.new())
				shrine.set(&"shrine_id", String(item["id"]))
				shrine.name = String(item["id"]).capitalize().replace(" ", "")
				shrine.set(&"position", at)
				_add(_child(gameplay, "Hearths"), shrine)
			"chest":
				var chest := _scripted("chest", Node3D.new())
				chest.set(&"chest_id", "chest_%d" % counts[kind])
				chest.set(&"loot_table", String(item.get("table", "chest")))
				chest.set(&"name", "Chest_%d" % counts[kind])
				chest.set(&"position", at)
				chest.rotation.y = yaw
				_add(_child(gameplay, "Chests"), chest)
			"breakable":
				var pot := _scripted("breakable", Node3D.new())
				pot.set(&"model", String(item.get("model", "amphora")))
				pot.set(&"loot_table", String(item.get("table", "amphora")))
				pot.set(&"name", "Pot_%d" % counts[kind])
				pot.set(&"position", at)
				pot.rotation.y = randf() * TAU
				_add(_child(gameplay, "Pots"), pot)
			"gate":
				var gate := _scripted("gate", Node3D.new())
				gate.name = "SanctuaryGate"
				gate.position = at
				gate.rotation.y = yaw
				_add(gameplay, gate)
			"brazier":
				var holder := _child(_child(gameplay, "Braziers"), "Brazier_%d" % counts[kind])
				holder.position = at
				var model := _instance("brazier")
				_add(holder, model)
				var fire := _scripted("fire", Node3D.new())
				fire.set(&"name", "Fire")
				fire.set(&"position", Vector3.UP * 1.35)
				fire.set(&"size", 0.7)
				fire.set(&"light_energy", 1.6)
				_add(holder, fire)
			"zone":
				var zone := _scripted("zone", Marker3D.new())
				zone.set(&"zone_name", String(item["name"]))
				zone.set(&"subtitle", String(item.get("subtitle", "")))
				zone.set(&"radius", float(item.get("radius", 20.0)))
				zone.set(&"music", StringName(String(item.get("music", ""))))
				zone.set(&"ambience", StringName(String(item.get("ambience", ""))))
				zone.name = "Zone_" + String(item["name"]).replace(" ", "")
				if bool(item.get("fog", false)):
					var mist := _scripted("mist", Node3D.new())
					mist.name = "Mist"
					mist.set(&"radius", float(item.get("radius", 20.0)) * 0.9)
					_add(zone, mist)
				zone.set(&"position", at)
				_add(_child(gameplay, "Zones"), zone)
			"boss":
				var mark := Marker3D.new()
				mark.name = "BossSpawn"
				mark.position = at
				mark.rotation.y = yaw
				mark.set_meta("level", int(item.get("level", 7)))
				mark.set_meta("arena_radius", float(item.get("arena_radius", 16.0)))
				if item.has("arena"):
					var centre := item["arena"] as Array
					mark.set_meta("arena_center", Vector2(float(centre[0]), float(centre[1])))
				_add(gameplay, mark)
	var grass := _scripted("grass", Node3D.new())
	grass.set(&"name", "Grass")
	grass.set(&"layout_path", LAYOUT)
	_add(_root, grass)
	var route := Node3D.new()
	route.name = "Route"
	route.set_meta("points", layout.get("route", []))
	_add(gameplay, route)
	# Bake with only the navigation subtree in the tree: the gameplay nodes stay out,
	# so their _ready (spawning, loading models) never runs in this tool. The models
	# they load at runtime (hearths, chests, pots, the gate) stand in as proxies, so
	# paths go around them; the proxies are not saved.
	var proxies := Node3D.new()
	proxies.name = "NavProxies"
	proxies.add_to_group(&"navigation_geometry")
	nav.add_child(proxies)
	for entry: Variant in layout["items"] as Array:
		var item := entry as Dictionary
		var model := ""
		match String(item["type"]):
			"shrine":
				model = "hearth_of_hestia"
			"chest":
				model = "chest"
			"breakable":
				model = String(item.get("model", "amphora"))
			"gate":
				model = "sanctuary_gate"
		if model == "":
			continue
		var proxy := _instance(model)
		if proxy:
			var p := item["pos"] as Array
			proxy.position = Vector3(float(p[0]), float(p[1]), float(p[2]))
			proxy.rotation.y = deg_to_rad(float(item.get("rot", 0.0)))
			proxies.add_child(proxy)
	proxies.add_child(_sea_floor(layout.get("bounds", [-150, -150, 150, 150]) as Array))
	var index := nav.get_index()
	_root.remove_child(nav)
	get_root().add_child(nav)
	await process_frame
	var started := Time.get_ticks_msec()
	nav.bake_navigation_mesh(false)
	print("level: navigation baked in %d ms, %d polygons" % [Time.get_ticks_msec() - started, nav.navigation_mesh.get_polygon_count()])
	var route_points := layout.get("route", []) as Array
	if not route_points.is_empty():
		var first := route_points[0] as Array
		_keep_reachable(nav, Vector3(float(first[0]), float(first[1]), float(first[2])))
	get_root().remove_child(nav)
	nav.remove_child(proxies)
	proxies.free()
	_root.add_child(nav)
	_root.move_child(nav, index)
	for node in _owned:
		node.owner = _root
	var packed := PackedScene.new()
	var error := packed.pack(_root)
	if error == OK:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT.get_base_dir()))
		error = ResourceSaver.save(packed, OUT)
	print("level: %s -> %s (%s)" % [JSON.stringify(counts), OUT, error_string(error)])
	_root.free()
	quit(0 if error == OK else 1)


## A node of the given base type carrying one of the game's scripts.
func _scripted(key: String, base: Node3D) -> Node3D:
	base.set_script(load(String(SCRIPTS[key])))
	return base


func _add(parent: Node, node: Node) -> void:
	parent.add_child(node)
	_owned.append(node)


func _child(parent: Node, child_name: String) -> Node3D:
	var found := parent.get_node_or_null(child_name) as Node3D
	if found:
		return found
	var node := Node3D.new()
	node.name = child_name
	_add(parent, node)
	return node


func _instance(model: String) -> Node3D:
	if not _scenes.has(model):
		var path := PROPS % [model, model]
		_scenes[model] = load(path) if ResourceLoader.exists(path) else null
		if _scenes[model] == null:
			printerr("level: missing prop model ", path)
	var scene := _scenes[model] as PackedScene
	return scene.instantiate() as Node3D if scene else null


func _navmesh() -> NavigationMesh:
	var mesh := NavigationMesh.new()
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_collision_mask = LAYER_WORLD | LAYER_TERRAIN
	mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	mesh.geometry_source_group_name = &"navigation_geometry"
	mesh.cell_size = 0.25
	mesh.cell_height = 0.25
	mesh.agent_height = 2.0
	mesh.agent_radius = 0.5
	# One cell: enough for 42° slopes; a taller ledge (a wall's end beside a riser)
	# is no step a walking actor can take (Actor lifts over up to 0.3 m).
	mesh.agent_max_climb = 0.25
	mesh.agent_max_slope = 42.0
	# Drop isolated islands under 16 m² (16² cells of 0.25 m): pockets between a wall
	# end and a tree, flat rock tops. A hero knocked onto one could never path off it.
	mesh.region_min_size = 16.0
	return mesh


## Keeps only the ground a hero can walk to from the start. The hills around the zone
## bake as walkable slopes behind steep banks: an actor knocked against a bank (or
## loot landing nearby) would be snapped up onto them and stranded.
## Polygons connect where they share an edge (two corners at the same place): flood
## from the polygon under the start.
func _keep_reachable(nav: NavigationRegion3D, start: Vector3) -> void:
	var mesh := nav.navigation_mesh
	var vertices := mesh.get_vertices()
	var total := mesh.get_polygon_count()
	# One id per corner on the bake grid. Neighbours meet at the same x/z grid point but
	# each keeps its own height there, so the key ignores y; heights are compared when
	# flooding (a platform over the ground shares its corners' x/z, not their height).
	var ids: Dictionary = {}
	var canonical := PackedInt32Array()
	for v in vertices:
		var key := Vector2i(roundi(v.x / mesh.cell_size), roundi(v.z / mesh.cell_size))
		if not ids.has(key):
			ids[key] = ids.size()
		canonical.append(int(ids[key]))
	# Which polygons meet at each corner. (A long edge on one side can face several
	# shorter ones on the other, so neighbours share corners, not always whole edges.)
	var at_corner: Array[PackedInt32Array] = []
	at_corner.resize(ids.size())
	var polygons: Array[PackedInt32Array] = []
	var seed := -1
	var seed_distance := INF
	for p in total:
		var polygon := mesh.get_polygon(p)
		polygons.append(polygon)
		var centre := Vector3.ZERO
		for index in polygon:
			centre += vertices[index]
			at_corner[canonical[index]].append(p)
		centre /= float(polygon.size())
		if centre.distance_to(start) < seed_distance:
			seed_distance = centre.distance_to(start)
			seed = p
	var reached := PackedByteArray()
	reached.resize(total)
	var queue := PackedInt32Array([seed])
	reached[seed] = 1
	var head := 0
	while head < queue.size():
		var polygon := polygons[queue[head]]
		head += 1
		for index in polygon:
			for other in at_corner[canonical[index]]:
				if reached[other] == 1 or not _meets_at(polygons[other], canonical, canonical[index], vertices[index].y, vertices):
					continue
				reached[other] = 1
				queue.append(other)
	if queue.size() < 100:
		printerr("level: only %d polygons reach the start (%.1f m away); keeping the whole mesh" % [queue.size(), seed_distance])
		return
	mesh.clear_polygons()
	for p in total:
		if reached[p] == 1:
			mesh.add_polygon(polygons[p])
	print("level: kept the %d of %d polygons that reach the start (%.1f m from it)" % [queue.size(), total, seed_distance])


## Whether `polygon` has the corner `corner` at about height `y`: neighbours differ
## a little there; a platform above the same spot (a temple's top) differs by metres.
func _meets_at(polygon: PackedInt32Array, canonical: PackedInt32Array, corner: int, y: float, vertices: PackedVector3Array) -> bool:
	for index in polygon:
		if canonical[index] == corner and absf(vertices[index].y - y) < 0.75:
			return true
	return false


## Under the sea the terrain slopes on to a seabed at -4 m: mark everything below the
## waterline unwalkable, so nothing chases or wanders out under the waves.
func _sea_floor(bounds: Array) -> NavigationObstacle3D:
	var sea := NavigationObstacle3D.new()
	sea.name = "SeaFloor"
	sea.avoidance_enabled = false
	sea.affect_navigation_mesh = true
	var x0 := float(bounds[0]) - 10.0
	var z0 := float(bounds[1]) - 10.0
	var x1 := float(bounds[2]) + 10.0
	var z1 := float(bounds[3]) + 10.0
	sea.vertices = PackedVector3Array([Vector3(x0, 0, z0), Vector3(x1, 0, z0), Vector3(x1, 0, z1), Vector3(x0, 0, z1)])
	sea.position = Vector3(0.0, -20.0, 0.0)
	sea.height = 20.0 + SEA_WALK_LINE
	return sea


func _environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.3, 0.48, 0.74)
	sky_material.sky_horizon_color = Color(0.96, 0.82, 0.62)
	sky_material.ground_horizon_color = Color(0.86, 0.73, 0.56)
	sky_material.ground_bottom_color = Color(0.32, 0.28, 0.24)
	sky_material.sun_angle_max = 25.0
	var sky := Sky.new()
	sky.sky_material = sky_material
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 0.9
	env.ssao_enabled = true
	env.ssao_radius = 1.4
	env.ssao_intensity = 1.8
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.15
	env.fog_enabled = true
	env.fog_light_color = Color(0.86, 0.76, 0.62)
	env.fog_density = 0.0028
	env.fog_sky_affect = 0.25
	env.fog_aerial_perspective = 0.35
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.14
	env.adjustment_contrast = 1.05
	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	world.environment = env
	_add(_root, world)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation = Vector3(deg_to_rad(-40.0), deg_to_rad(-62.0), 0.0)
	sun.light_color = Color(1.0, 0.87, 0.68)
	sun.light_energy = 1.45
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	_add(_root, sun)
