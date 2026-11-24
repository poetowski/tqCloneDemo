class_name Chest
extends Node3D
## A chest: click to open; the lid swings up and its loot spills out. Remembered
## by the world flags so it stays open.

@export var chest_id := "chest"
@export var loot_table := "chest"
@export var loot_level := 2

var interact_range := 2.0
var opened := false
var _lid: Node3D


func _ready() -> void:
	add_to_group(&"interactable")
	var model := Interact.load_model(self, "chest")
	if model:
		_lid = model.find_child("Lid", true, false) as Node3D
	Interact.add_area(self, 0.9, 1.0)
	opened = Game.flag("chest_" + chest_id)
	if opened and _lid:
		_lid.rotation.x = deg_to_rad(-100)


func interact(player: Player) -> void:
	if opened:
		return
	opened = true
	Game.set_flag("chest_" + chest_id)
	if _lid:
		var tween := create_tween()
		tween.tween_property(_lid, "rotation:x", deg_to_rad(-100), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play_at(&"chest", global_position)
	Vfx.motes(global_position + Vector3.UP * 0.7, Vfx.GOLD, 16, 0.4, 1.2)
	var level := maxi(loot_level, player.level)
	get_tree().create_timer(0.3, false).timeout.connect(func() -> void: LootDrop.spill(loot_table, level, global_position + Vector3.UP * 0.4))
