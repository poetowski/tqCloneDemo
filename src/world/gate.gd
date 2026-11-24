class_name SanctuaryGate
extends Node3D
## The sealed gate of the Sanctuary of the Moirai. It opens only for the bearer of
## the Seal of the Sanctuary (Captain Lykos carries it). The doors swing out and a
## barrier in the opening goes away.

var interact_range := 4.5
var opened := false
var _doors: Array[Node3D] = []
var _barrier: StaticBody3D


func _ready() -> void:
	add_to_group(&"interactable")
	var model := Interact.load_model(self, "sanctuary_gate")
	if model:
		for door_name: String in ["DoorLeft", "DoorRight"]:
			var door := model.find_child(door_name, true, false) as Node3D
			if door:
				_doors.append(door)
	Interact.add_area(self, 2.4, 4.6)
	_barrier = StaticBody3D.new()
	_barrier.collision_layer = Actor.LAYER_WORLD
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.8, 4.6, 0.6)
	shape.shape = box
	shape.position = Vector3(0, 2.3, 0)
	_barrier.add_child(shape)
	add_child(_barrier)
	if Game.flag("gate_open"):
		_open(true)


func interact(player: Player) -> void:
	if opened:
		return
	var seal: Item = null
	for item: Variant in player.inventory.items():
		if (item as Item).base_id == &"seal_of_sanctuary":
			seal = item as Item
	if seal == null:
		Events.notified.emit("The gate is sealed. A spindle is carved where the bar should be.", UIStyle.MUTED)
		Sfx.play(&"denied")
		return
	player.inventory.remove(seal)
	Events.notified.emit("The seal turns in the spindle's eye. The gate of the Moirai opens.", UIStyle.GOLD_BRIGHT)
	_open(false)


func _open(instant: bool) -> void:
	opened = true
	Game.set_flag("gate_open")
	_barrier.collision_layer = 0
	for door in _doors:
		var side := -1.0 if door.name == "DoorLeft" else 1.0
		var target := door.rotation.y + side * deg_to_rad(105)
		if instant:
			door.rotation.y = target
		else:
			var tween := door.create_tween()
			tween.tween_property(door, "rotation:y", target, 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if not instant:
		Vfx.motes(global_position + Vector3.UP * 2.5, Vfx.GOLD, 30, 2.0, 2.0)
		Sfx.play_at(&"gate", global_position)
		Game.shake(0.3)
		Quests.flag_set("gate_open")
