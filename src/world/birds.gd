class_name Birds
extends Node3D
## A few birds wheeling over a place: gulls over the bay, crows over the necropolis.
## Models from tools/blender/characters/birds.py; their wings ("WingL", "WingR",
## pivoting at the shoulder) are flapped here in bursts, between long glides, and each
## bird banks into its turn. Placed by the level script ("birds" things).

const MODELS := "res://assets/models/characters/%s/%s.glb"

@export var kind := "gull"
@export var count := 5
@export var radius := 16.0
@export var height := 9.0
## Flying speed, metres per second.
@export var speed := 5.0

var _flock: Array[Dictionary] = []


func _ready() -> void:
	var path := MODELS % [kind, kind]
	if not ResourceLoader.exists(path):
		return
	var scene := load(path) as PackedScene
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(name))
	var turn := 1.0 if rng.randf() < 0.5 else -1.0
	for i in count:
		var bird := scene.instantiate() as Node3D
		add_child(bird)
		_flock.append({
			"node": bird,
			"wing_l": bird.find_child("WingL", true, false),
			"wing_r": bird.find_child("WingR", true, false),
			"angle": rng.randf() * TAU,
			"radius": radius * rng.randf_range(0.55, 1.15),
			"height": height + rng.randf_range(-2.0, 2.5),
			"speed": speed * rng.randf_range(0.85, 1.15),
			"turn": turn if rng.randf() < 0.85 else -turn,
			"clock": rng.randf() * 6.0,
		})


func _process(delta: float) -> void:
	for bird: Dictionary in _flock:
		var node := bird["node"] as Node3D
		var r := float(bird["radius"])
		var turn := float(bird["turn"])
		var angle := float(bird["angle"]) + turn * float(bird["speed"]) / r * delta
		bird["angle"] = angle
		var clock := float(bird["clock"]) + delta
		bird["clock"] = clock
		node.position = Vector3(cos(angle) * r, float(bird["height"]) + sin(clock * 0.6 + angle) * 0.7, sin(angle) * r)
		var ahead := Vector3(-sin(angle), 0.0, cos(angle)) * turn
		node.look_at(node.global_position + ahead, Vector3.UP, true)
		node.rotate_object_local(Vector3.FORWARD, -0.35 * turn)  # bank into the turn
		# Flap for a while, then glide with the wings a little raised.
		var cycle := fmod(clock, 4.2)
		var lift := sin(clock * 13.0) * 0.65 if cycle < 1.4 else 0.18 + sin(clock * 1.5) * 0.05
		var wing_l := bird["wing_l"] as Node3D
		var wing_r := bird["wing_r"] as Node3D
		if wing_l:
			wing_l.rotation.z = -lift
		if wing_r:
			wing_r.rotation.z = lift
