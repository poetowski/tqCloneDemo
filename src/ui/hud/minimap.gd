class_name Minimap
extends Control
## The round map in the corner: the level seen from above (Level.minimap, rendered in
## Blender by the level script), north up like the camera, centred on the hero. Marks
## from MapMarkers: the next quest goal sits on the rim when it is off the map, so it
## points the way; the rest show when near. The area's name sits under it.

const RADIUS := 100.0
## Metres from the centre to the rim.
const VIEW := 42.0
const SEGMENTS := 64

var _marks: Array[Dictionary] = []
var _refresh := 0.0
var _zone_label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(RADIUS, RADIUS) * 2.0 + Vector2(24, 24)
	_zone_label = UIStyle.label("", 15, UIStyle.GOLD, 5)
	_zone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_zone_label.position = Vector2(-40, RADIUS * 2.0 + 26)
	_zone_label.size = Vector2(RADIUS * 2.0 + 104, 22)
	add_child(_zone_label)
	Events.zone_changed.connect(func(zone: Node3D) -> void: _zone_label.text = String(zone.get(&"zone_name")))


func _process(delta: float) -> void:
	_refresh -= delta
	if _refresh <= 0.0:
		_refresh = 0.4
		_marks = MapMarkers.collect(get_tree())
	visible = Game.level != null and Game.level.get(&"minimap") != null
	queue_redraw()


func _draw() -> void:
	var level := Game.level
	var player := Game.player
	if level == null or player == null:
		return
	var texture := level.get(&"minimap") as Texture2D
	var bounds := level.get(&"map_bounds") as Rect2
	if texture == null or bounds.size.x <= 0.0:
		return
	var c := Vector2(RADIUS, RADIUS) + Vector2(12, 12)
	var here := Vector2(player.global_position.x, player.global_position.z)
	draw_circle(c, RADIUS + 9.0, UIStyle.OUTLINE)
	# The map: a disc of points carrying their spot on the picture.
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()
	for i in SEGMENTS:
		var dir := Vector2.from_angle(TAU * float(i) / float(SEGMENTS))
		points.append(c + dir * RADIUS)
		uvs.append((here + dir * VIEW - bounds.position) / bounds.size)
	draw_polygon(points, PackedColorArray([Color.WHITE]), uvs, texture)
	# A dark rim pulls the eye to the middle; bronze and gold rings close it.
	draw_arc(c, RADIUS - 5.0, 0.0, TAU, SEGMENTS, Color(0, 0, 0, 0.32), 10.0)
	draw_arc(c, RADIUS + 3.0, 0.0, TAU, SEGMENTS, UIStyle.BRONZE, 6.0)
	draw_arc(c, RADIUS + 7.0, 0.0, TAU, SEGMENTS, UIStyle.GOLD, 1.5)
	var font := ThemeDB.fallback_font
	draw_string_outline(font, c + Vector2(-6, -RADIUS + 18), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, UIStyle.OUTLINE)
	draw_string(font, c + Vector2(-6, -RADIUS + 18), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UIStyle.GOLD)
	var t := Time.get_ticks_msec() / 1000.0
	for mark: Dictionary in _marks:
		var at := mark["position"] as Vector3
		var offset := (Vector2(at.x, at.z) - here) / VIEW * RADIUS
		var kind := int(mark["kind"])
		if offset.length() > RADIUS - 8.0:
			if kind != MapMarkers.Kind.OBJECTIVE:
				continue
			offset = offset.normalized() * (RADIUS - 8.0)
		MapMarkers.draw(self, kind, c + offset, 7.0 if kind == MapMarkers.Kind.OBJECTIVE else 6.0, t)
	var facing := player.global_transform.basis.z
	MapMarkers.draw_hero(self, c, Vector2(facing.x, facing.z), 8.0)
