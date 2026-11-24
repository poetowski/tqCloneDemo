class_name UIBar
extends Control
## A drawn bar: dark trough, coloured fill with a lighter top edge, a trailing
## "recent damage" ghost, and an optional bronze frame. Used for XP, enemy and
## boss health.

@export var fill_color := Color("#9E2B25")
@export var ghost_color := Color(1.0, 0.85, 0.6, 0.55)
@export var frame_color := Color("#7A5226")
@export var show_frame := true

var value := 1.0
var _ghost := 1.0


func set_value(ratio: float, instant: bool = false) -> void:
	ratio = clampf(ratio, 0.0, 1.0)
	if instant or ratio > value:
		_ghost = ratio
	value = ratio
	queue_redraw()


func _process(delta: float) -> void:
	if _ghost > value:
		_ghost = move_toward(_ghost, value, delta * 0.6)
		queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color(0.04, 0.03, 0.025, 0.9))
	var inner := r.grow(-2.0)
	if _ghost > value:
		draw_rect(Rect2(inner.position, Vector2(inner.size.x * _ghost, inner.size.y)), ghost_color)
	var filled := Rect2(inner.position, Vector2(inner.size.x * value, inner.size.y))
	draw_rect(filled, fill_color)
	draw_rect(Rect2(filled.position, Vector2(filled.size.x, maxf(1.0, filled.size.y * 0.3))), fill_color.lightened(0.3))
	if show_frame:
		draw_rect(r, frame_color, false, 2.0)
