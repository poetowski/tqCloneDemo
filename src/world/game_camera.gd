class_name GameCamera
extends Node3D
## The isometric follow camera: a fixed pitch and yaw looking down at the hero,
## wheel zoom, screen shake, and mouse rays into the world. Models standing
## between the camera and the hero fade (dither) so the hero stays visible.

@export var pitch_degrees := 54.0
@export var yaw_degrees := 0.0
@export var distance := 17.0
@export var min_distance := 10.0
@export var max_distance := 25.0
@export var follow_sharpness := 9.0
@export var fov := 38.0

var target: Node3D
var camera: Camera3D

var _shake := 0.0
var _goal_distance := 17.0
var _faded: Dictionary = {}
var _fade_timer := 0.0


func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = fov
	camera.near = 0.3
	camera.far = 500.0
	add_child(camera)
	camera.make_current()
	_goal_distance = distance
	_place(0.0)
	Game.camera = self


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"zoom_in"):
		_goal_distance = maxf(min_distance, _goal_distance - 1.5)
	elif event.is_action_pressed(&"zoom_out"):
		_goal_distance = minf(max_distance, _goal_distance + 1.5)


func _process(delta: float) -> void:
	if target and is_instance_valid(target):
		global_position = global_position.lerp(target.global_position, 1.0 - exp(-follow_sharpness * delta))
	distance = lerpf(distance, _goal_distance, 1.0 - exp(-8.0 * delta))
	_shake = move_toward(_shake, 0.0, delta * 2.2)
	_place(delta)
	_fade_timer -= delta
	if _fade_timer <= 0.0:
		_fade_timer = 0.1
		_update_fades()


## Snaps to the target at once (after teleports and level loads).
func snap() -> void:
	if target:
		global_position = target.global_position
	_place(0.0)


func shake(amount: float) -> void:
	_shake = clampf(maxf(_shake, amount), 0.0, 1.0)


## The world point and collider under a screen position, or {} if none.
func ray(screen_position: Vector2, mask: int, areas: bool = false) -> Dictionary:
	var from := camera.project_ray_origin(screen_position)
	var to := from + camera.project_ray_normal(screen_position) * 400.0
	var query := PhysicsRayQueryParameters3D.create(from, to, mask)
	query.collide_with_areas = areas
	return get_world_3d().direct_space_state.intersect_ray(query)


func _place(_delta: float) -> void:
	var pitch := deg_to_rad(pitch_degrees)
	var yaw := deg_to_rad(yaw_degrees)
	var back := Vector3(sin(yaw), 0.0, cos(yaw))
	var offset := back * cos(pitch) * distance + Vector3.UP * sin(pitch) * distance
	var jitter := Vector3.ZERO
	if _shake > 0.0:
		var s := _shake * _shake * 0.35
		jitter = Vector3(randf_range(-s, s), randf_range(-s, s), randf_range(-s, s))
	camera.global_position = global_position + offset + jitter
	camera.look_at(global_position + Vector3.UP * 1.0 + jitter, Vector3.UP)


## Fades models that block the line from the camera to the hero.
func _update_fades() -> void:
	if target == null or not is_instance_valid(target):
		return
	var still: Dictionary = {}
	var from := camera.global_position
	var to := target.global_position + Vector3.UP * 1.2
	var space := get_world_3d().direct_space_state
	var exclude: Array[RID] = []
	for i in 4:
		var query := PhysicsRayQueryParameters3D.create(from, to, Actor.LAYER_WORLD)
		query.exclude = exclude
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			break
		var collider := hit["collider"] as CollisionObject3D
		exclude.append(collider.get_rid())
		var owner_model := _fade_root(collider)
		if owner_model:
			still[owner_model] = true
	for node: Variant in _faded.keys():
		if not still.has(node):
			_set_fade(node as Node3D, 1.0)
			_faded.erase(node)
	for node: Variant in still.keys():
		if not _faded.has(node):
			_set_fade(node as Node3D, 0.35)
			_faded[node] = true


func _fade_root(collider: Node) -> Node3D:
	var node := collider
	while node and not node.is_in_group(&"fadeable"):
		node = node.get_parent()
	return node as Node3D


func _set_fade(root: Node3D, amount: float) -> void:
	if not is_instance_valid(root):
		return
	for geometry in root.find_children("*", "GeometryInstance3D", true, false):
		(geometry as GeometryInstance3D).set_instance_shader_parameter(&"fade", amount)
