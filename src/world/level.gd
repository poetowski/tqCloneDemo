class_name Level
extends Node3D
## A playable place: bakes its navigation, puts the hero at the start, brings the
## camera and the HUD, and brings the hero back at the last lit hearth after death.
## Nodes in the "navigation_geometry" group (and their children) shape the walkable
## ground; their static colliders are what the navigation mesh is baked from.

signal ready_to_play()

@export var start_marker: NodePath
@export var title := ""
@export var subtitle := ""
@export var music := &""
@export var ambience := &""
@export var player_level := 1

var player: Player
var camera: GameCamera
var hud: HUD
var navigation: NavigationRegion3D


func _ready() -> void:
	Game.level = self
	navigation = _find_navigation()
	player = Player.new()
	player.name = "Player"
	add_child(player)
	var start := get_node_or_null(start_marker) as Node3D
	player.global_position = start.global_position if start else Vector3.ZERO
	if start:
		player.rotation.y = start.rotation.y
	Game.respawn_point = player.global_position
	camera = GameCamera.new()
	camera.name = "GameCamera"
	add_child(camera)
	camera.target = player
	camera.snap()
	hud = HUD.new()
	hud.name = "HUD"
	add_child(hud)
	_add_panels()
	hud.bind_player(player)
	Events.player_died.connect(_on_player_died)
	# Levels built by tools/build_level.gd arrive with their navigation baked.
	if navigation and navigation.navigation_mesh and navigation.navigation_mesh.get_polygon_count() == 0:
		navigation.bake_finished.connect(_on_baked, CONNECT_ONE_SHOT)
		navigation.bake_navigation_mesh(true)
	else:
		_on_baked.call_deferred()
	if music != &"":
		Sfx.play_music(music)
	if ambience != &"":
		Sfx.play_ambience(ambience)
	DevTools.scenario_requested.connect(_on_scenario)


## Panels are added by the game's levels (inventory, hero, Loom, dialogue, pause).
func _add_panels() -> void:
	for entry: Array in [[&"inventory", "res://src/ui/panels/inventory_panel.gd"], [&"character", "res://src/ui/panels/character_panel.gd"],
			[&"loom", "res://src/ui/panels/loom_panel.gd"], [&"dialogue", "res://src/ui/panels/dialogue_panel.gd"],
			[&"pause", "res://src/ui/panels/pause_panel.gd"]]:
		var path := String(entry[1])
		if ResourceLoader.exists(path):
			var panel := (load(path) as GDScript).new() as Control
			hud.add_panel(entry[0] as StringName, panel)


func _find_navigation() -> NavigationRegion3D:
	for node in find_children("*", "NavigationRegion3D", true, false):
		return node as NavigationRegion3D
	return null


func _on_baked() -> void:
	if title != "":
		hud.show_banner(title, subtitle)
	ready_to_play.emit()


func _on_player_died() -> void:
	await get_tree().create_timer(3.2, false).timeout
	player.respawn(Game.respawn_point)


## Dev scenarios for `npm run shot -- --scenario=<name>` (see src/autoload/dev_tools.gd).
func _on_scenario(scenario: String) -> void:
	match scenario:
		"fight":
			for spawner in get_tree().get_nodes_in_group(&"spawners"):
				(spawner as Spawner).wake()
		"brawl":
			# A seasoned hero on autopilot: level 5, every skill learned.
			for i in 4:
				player.gain_xp(Game.xp_to_next(player.level))
			for id: StringName in [&"aspis_bash", &"fates_lash", &"war_cry", &"bound_shades", &"atropos_mercy"]:
				player.skills.learn(id, player.level)
			var pilot := Autopilot.new()
			pilot.player = player
			add_child(pilot)
		"panels":
			hud.toggle_panel(&"inventory")
		"loom":
			hud.toggle_panel(&"loom")
		"hero":
			hud.toggle_panel(&"character")
