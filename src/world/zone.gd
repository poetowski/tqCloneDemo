class_name Zone
extends Marker3D
## A named area: the first time the hero walks in, its name rises like a chapter
## heading; while inside, its music and ambience play. Checked by distance (no
## physics), innermost zone wins.

@export var zone_name := ""
@export var subtitle := ""
@export var radius := 20.0
@export var music := &""
@export var ambience := &""

static var _current: Zone

var _announced := false


func _ready() -> void:
	add_to_group(&"zones")


func _physics_process(_delta: float) -> void:
	if Game.player == null:
		return
	var p := Game.player.global_position
	var inside := Vector2(p.x - global_position.x, p.z - global_position.z).length() < radius
	if not inside:
		return
	if _current != self and (_current == null or not is_instance_valid(_current) or not _current.contains(p) or _current.radius > radius):
		_current = self
		if music != &"":
			Sfx.play_music(music)
		if ambience != &"":
			Sfx.play_ambience(ambience)
		if not _announced:
			_announced = true
			Events.area_entered.emit(zone_name)
			if Game.hud:
				(Game.hud as HUD).show_banner(zone_name, subtitle)


func contains(p: Vector3) -> bool:
	return Vector2(p.x - global_position.x, p.z - global_position.z).length() < radius
