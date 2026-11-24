class_name Shrine
extends Node3D
## A Hearth of Hestia: walk close (or click it) to light it. The last lit (or last
## clicked) hearth is where the hero wakes after dying; lighting one also mends body
## and ichor, once: a lit hearth is no well to run back to mid-fight.

@export var shrine_id := "hearth"
@export var shrine_name := "Hearth of Hestia"

var interact_range := 3.0
var lit := false
var _fire: Fire


func _ready() -> void:
	add_to_group(&"interactable")
	add_to_group(&"shrines")
	Interact.load_model(self, "hearth_of_hestia")
	Interact.add_area(self, 1.4, 1.5)
	_fire = Fire.new()
	_fire.size = 0.8
	_fire.position = Vector3.UP * 1.2
	_fire.lit = Game.flag("shrine_" + shrine_id)
	add_child(_fire)
	lit = _fire.lit


func _physics_process(_delta: float) -> void:
	if not lit and Game.player and not Game.player.is_dead and global_position.distance_to(Game.player.global_position) < 4.0:
		interact(Game.player)


func interact(player: Player) -> void:
	if not lit:
		lit = true
		Game.set_flag("shrine_" + shrine_id)
		_fire.set_lit(true)
		Events.shrine_lit.emit(self)
		Events.notified.emit("The hearth of Hestia burns for you. You will wake here.", UIStyle.GOLD)
		Vfx.ring(global_position, Vfx.FIRE, 0.5, 5.0, 0.8)
		Vfx.motes(global_position + Vector3.UP * 1.3, Vfx.FIRE, 26, 0.6, 1.6)
		Sfx.play_at(&"shrine", global_position)
		player.heal(player.max_health())
		player.restore_ichor(player.max_ichor())
	Game.respawn_point = global_position + Vector3(0, 0, 2.6)
