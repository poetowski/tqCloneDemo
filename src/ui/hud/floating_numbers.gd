class_name FloatingNumbers
extends Control
## Damage numbers that rise from whoever was hit: white for the hero's blows,
## gold and larger for criticals, "SEVERED" when Atropos' Mercy cuts a thread,
## red for damage the hero takes.

const LIFE := 0.9

var _numbers: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Events.damage_dealt.connect(_on_damage)


func _on_damage(target: Node3D, info: RefCounted) -> void:
	var hit := info as DamageInfo
	if hit == null or hit.final_amount < 0.5 and not hit.is_sever:
		return
	var against_player := target is Player
	var text := str(int(round(hit.final_amount)))
	var color := Color(1.0, 0.97, 0.9)
	var font_size := 22
	if against_player:
		color = Color(0.95, 0.3, 0.25)
		font_size = 20
	elif hit.is_sever:
		text = "SEVERED"
		color = Vfx.GOLD
		font_size = 26
	elif hit.is_crit:
		color = Color("#F2C14E")
		font_size = 30
		text += "!"
	elif hit.kind == DamageInfo.Kind.FIRE:
		color = Color(1.0, 0.55, 0.2)
		font_size = 18
	elif hit.source is Enemy and (hit.source as Enemy).is_ally:
		color = Color(1.0, 0.85, 0.5)
		font_size = 18
	_numbers.append({
		"text": text, "color": color, "size": font_size, "age": 0.0,
		"world": target.global_position + Vector3.UP * (2.0 * target.scale.y + randf_range(0.0, 0.4)),
		"drift": Vector2(randf_range(-30.0, 30.0), 0.0),
	})


func _process(delta: float) -> void:
	for n in _numbers:
		n["age"] = float(n["age"]) + delta
	_numbers = _numbers.filter(func(n: Dictionary) -> bool: return float(n["age"]) < LIFE)
	queue_redraw()


func _draw() -> void:
	if Game.camera == null or Game.camera.camera == null:
		return
	var cam := Game.camera.camera
	var font := get_theme_default_font()
	for n in _numbers:
		var world := n["world"] as Vector3
		if cam.is_position_behind(world):
			continue
		var t := float(n["age"]) / LIFE
		var at := cam.unproject_position(world) + (n["drift"] as Vector2) * t + Vector2(0, -60.0 * t)
		var pop := 1.0 + 0.35 * maxf(0.0, 1.0 - t * 6.0)
		var font_size := int(float(n["size"]) * pop)
		var colour := n["color"] as Color
		colour.a = 1.0 - smoothstep(0.6, 1.0, t)
		var text := String(n["text"])
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var pos := at - Vector2(width * 0.5, 0)
		draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 6, Color(0.05, 0.03, 0.02, colour.a))
		draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, colour)
