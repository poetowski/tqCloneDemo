class_name Breakable
extends Node3D
## A pot (amphora, pithos, krater): click it, or hit it, and it shatters into the
## shards Blender made, sometimes spilling coins and draughts.

@export var model := "amphora"
@export var loot_table := "amphora"

var interact_range := 2.2
var broken := false
var _model: Node3D
var _body: StaticBody3D


func _ready() -> void:
	add_to_group(&"interactable")
	add_to_group(&"breakables")
	_model = Interact.load_model(self, model)
	if _model:
		for node in _model.find_children("*", "StaticBody3D", true, false):
			_body = node as StaticBody3D
	Interact.add_area(self, 0.6, 1.2)


func interact(player: Player) -> void:
	if broken:
		return
	player.face(global_position)
	shatter()


func shatter() -> void:
	if broken:
		return
	broken = true
	if _model:
		_model.visible = false
	if _body:
		_body.collision_layer = 0
	for child in get_children():
		if child is Area3D:
			(child as Area3D).collision_layer = 0
	var shards := Interact.load_model(self, "shards")
	if shards:
		for piece in shards.get_children():
			var node := piece as Node3D
			var direction := Vector3(randf_range(-1, 1), 0.0, randf_range(-1, 1)).normalized()
			var land := node.position + direction * randf_range(0.6, 1.4)
			var tween := node.create_tween().set_parallel()
			tween.tween_property(node, "position", Vector3(land.x, 0.02, land.z), 0.4).set_ease(Tween.EASE_OUT)
			tween.tween_property(node, "rotation", Vector3(PI * 0.5, randf() * TAU, randf() * 0.6), 0.4)
		get_tree().create_timer(6.0, false).timeout.connect(shards.queue_free)
	Vfx.sparks(global_position + Vector3.UP * 0.5, Color(0.8, 0.45, 0.3), 10, 4.0)
	Sfx.play_at(&"pot_break", global_position)
	var level := Game.player.level if Game.player else 1
	LootDrop.spill(loot_table, level, global_position)
