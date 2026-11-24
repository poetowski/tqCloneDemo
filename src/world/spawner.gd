@tool
class_name Spawner
extends Marker3D
## A pack of foes waiting at a spot. Beasts are there from the start; the
## Unthreaded lie dormant under the earth and rise when the hero comes near.
## Place it in a level and list the pack (data/enemies.json ids).

signal cleared()

@export var pack: PackedStringArray = PackedStringArray(["shade_hoplite", "shade_hoplite"])
@export var level := 1
@export_range(4.0, 40.0) var activation_radius := 15.0
@export_range(0.5, 10.0) var spread := 3.0
@export_range(0.0, 1.0) var champion_chance := 0.12
## Quest or boss packs set this so the pack always appears the same.
@export var no_champion := false

var enemies: Array[Enemy] = []
var _spawned := false
var _awake := false
var _alive := 0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group(&"spawners")
	_spawn.call_deferred()


func _spawn() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(name) ^ hash(global_position)
	var champion_index := -1
	if not no_champion and rng.randf() < champion_chance and pack.size() > 1:
		champion_index = rng.randi_range(0, pack.size() - 1)
	for i in pack.size():
		var enemy := Enemy.create(StringName(pack[i]), level, i == champion_index)
		enemy.name = "%s_%s_%d" % [name, pack[i], i]
		enemy.spawner = self
		var angle := TAU * float(i) / float(pack.size()) + rng.randf() * 0.6
		var offset := Vector3(cos(angle), 0.0, sin(angle)) * (spread * (0.4 + 0.6 * rng.randf())) if pack.size() > 1 else Vector3.ZERO
		if bool(enemy.def.get("rises", false)):
			enemy.make_dormant()
		# Placed before entering the tree, so _ready knows where home is.
		var parent := get_parent() as Node3D
		enemy.position = parent.to_local(_ground(global_position + offset)) if parent else _ground(global_position + offset)
		enemy.rotation.y = rng.randf() * TAU
		get_parent().add_child(enemy)
		enemy.home = enemy.global_position
		enemies.append(enemy)
		_alive += 1
	_spawned = true


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or _awake or not _spawned or Game.player == null:
		return
	if global_position.distance_to(Game.player.global_position) <= activation_radius:
		wake()


## Raises the dormant ones, a beat apart.
func wake() -> void:
	if _awake:
		return
	if not _spawned:
		_spawn_then_wake.call_deferred()
		return
	_awake = true
	var delay := 0.0
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.state == Enemy.State.DORMANT:
			get_tree().create_timer(delay, false).timeout.connect(enemy.rise)
			delay += 0.28


func _spawn_then_wake() -> void:
	if not _spawned:
		await get_tree().process_frame
	wake()


func on_enemy_died(_enemy: Enemy) -> void:
	_alive -= 1
	if _alive <= 0:
		cleared.emit()


func _ground(at: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 30.0, at + Vector3.DOWN * 30.0, Actor.LAYER_TERRAIN | Actor.LAYER_WORLD)
	var hit := space.intersect_ray(query)
	return (hit["position"] as Vector3) if not hit.is_empty() else at
