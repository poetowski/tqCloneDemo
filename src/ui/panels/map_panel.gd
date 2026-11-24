extends GamePanel
## The full map (Tab or M): the whole level from above, with the area names, the
## hearths, the people, the gate, the boss, every quest goal and the hero. The game
## runs on behind it.

const MAP_SIZE := Vector2(720, 690)

var _canvas: Control
var _marks: Array[Dictionary] = []
var _refresh := 0.0


func _ready() -> void:
	set_title("Elaion")
	var map_size := MAP_SIZE
	custom_minimum_size = map_size + Vector2(32, 96)
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.5
	anchor_bottom = 0.5
	offset_left = -custom_minimum_size.x * 0.5
	offset_right = custom_minimum_size.x * 0.5
	offset_top = -custom_minimum_size.y * 0.5 - 20.0
	offset_bottom = custom_minimum_size.y * 0.5 - 20.0
	_canvas = Control.new()
	_canvas.custom_minimum_size = map_size
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_map)
	content.add_child(_canvas)
	var legend := UIStyle.label("◆ your goal    ▲ Hearth of Hestia    ● people    ■ the gate    Tab / M to close", 14, UIStyle.MUTED, 4)
	content.add_child(legend)


func refresh() -> void:
	if Game.level and String(Game.level.get(&"title")) != "":
		set_title(String(Game.level.get(&"title")))


func _process(delta: float) -> void:
	if not visible:
		return
	_refresh -= delta
	if _refresh <= 0.0:
		_refresh = 0.4
		_marks = MapMarkers.collect(get_tree())
	_canvas.queue_redraw()


func _draw_map() -> void:
	var level := Game.level
	if level == null:
		return
	var texture := level.get(&"minimap") as Texture2D
	var bounds := level.get(&"map_bounds") as Rect2
	if texture == null or bounds.size.x <= 0.0:
		return
	# Fit the picture into the canvas, keeping its shape.
	var zoom := minf(_canvas.size.x / bounds.size.x, _canvas.size.y / bounds.size.y)
	var area := Rect2(Vector2.ZERO, bounds.size * zoom)
	area.position = (_canvas.size - area.size) * 0.5
	_canvas.draw_texture_rect(texture, area, false)
	_canvas.draw_rect(area, UIStyle.BRONZE, false, 2.0)
	var font := ThemeDB.fallback_font
	for node in get_tree().get_nodes_in_group(&"zones"):
		var zone := node as Node3D
		var at := _to_map(zone.global_position, area, bounds, zoom) + Vector2(0, -16)
		var text := String(zone.get(&"zone_name"))
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		_canvas.draw_string_outline(font, at - Vector2(width * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 5, UIStyle.OUTLINE)
		_canvas.draw_string(font, at - Vector2(width * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UIStyle.BONE)
	var t := Time.get_ticks_msec() / 1000.0
	for mark: Dictionary in _marks:
		var kind := int(mark["kind"])
		MapMarkers.draw(_canvas, kind, _to_map(mark["position"] as Vector3, area, bounds, zoom), 8.0 if kind == MapMarkers.Kind.OBJECTIVE else 6.5, t)
	if Game.player:
		var facing := Game.player.global_transform.basis.z
		MapMarkers.draw_hero(_canvas, _to_map(Game.player.global_position, area, bounds, zoom), Vector2(facing.x, facing.z), 9.0)


## A world point on the drawn map.
func _to_map(p: Vector3, area: Rect2, bounds: Rect2, zoom: float) -> Vector2:
	return area.position + (Vector2(p.x, p.z) - bounds.position) * zoom
