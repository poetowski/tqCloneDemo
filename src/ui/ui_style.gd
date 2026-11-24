class_name UIStyle
extends RefCounted
## The black-figure UI look (docs/ART_BIBLE.md#ui): near-black glaze panels with a
## terracotta border and a gold meander band; bone-white text, gold headers.

const GLAZE := Color(0.102, 0.078, 0.071, 0.93)
const GLAZE_LIGHT := Color(0.16, 0.12, 0.1, 0.95)
const TERRACOTTA := Color("#B5562E")
const CLAY := Color("#C8643C")
const GOLD := Color("#E2B04A")
const GOLD_BRIGHT := Color("#F2C14E")
const BONE := Color("#EFE6D2")
const MUTED := Color("#A89D86")
const DIM := Color("#6E665A")
const BRONZE := Color("#B07A3A")
const TEAL := Color("#5FD3C6")
const WINE := Color("#8E1B1B")
const OUTLINE := Color(0.05, 0.035, 0.03, 0.95)


static func panel(border: Color = TERRACOTTA, background: Color = GLAZE, width: int = 2, radius: int = 6) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(10)
	box.shadow_color = Color(0, 0, 0, 0.45)
	box.shadow_size = 6
	return box


static func slot_box(border: Color = Color(0.42, 0.3, 0.2), background: Color = Color(0.07, 0.055, 0.05, 0.9)) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = border
	box.set_border_width_all(2)
	box.set_corner_radius_all(4)
	return box


static func label(text: String, size: int = 16, color: Color = BONE, outline: int = 5) -> Label:
	var l := Label.new()
	l.text = text
	style_label(l, size, color, outline)
	return l


static func style_label(l: Control, size: int, color: Color, outline: int = 5) -> void:
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", color)
	l.add_theme_color_override(&"font_outline_color", OUTLINE)
	l.add_theme_constant_override(&"outline_size", outline)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE


static func button(text: String, size: int = 18) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override(&"font_size", size)
	b.add_theme_color_override(&"font_color", BONE)
	b.add_theme_color_override(&"font_hover_color", GOLD_BRIGHT)
	b.add_theme_color_override(&"font_pressed_color", GOLD)
	b.add_theme_color_override(&"font_disabled_color", DIM)
	b.add_theme_stylebox_override(&"normal", panel(Color(0.45, 0.28, 0.18), GLAZE_LIGHT, 2, 4))
	b.add_theme_stylebox_override(&"hover", panel(GOLD, Color(0.22, 0.16, 0.12, 0.96), 2, 4))
	b.add_theme_stylebox_override(&"pressed", panel(GOLD_BRIGHT, Color(0.1, 0.07, 0.06, 0.96), 2, 4))
	b.add_theme_stylebox_override(&"disabled", panel(Color(0.25, 0.2, 0.16), GLAZE, 2, 4))
	b.add_theme_stylebox_override(&"focus", StyleBoxEmpty.new())
	return b


## A gold meander (Greek key) band drawn into a control's canvas.
static func draw_meander(canvas: CanvasItem, rect: Rect2, color: Color = GOLD, unit: float = 6.0) -> void:
	var y := rect.position.y
	var h := unit * 2.0
	var x := rect.position.x
	canvas.draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), color, 1.5)
	canvas.draw_line(Vector2(rect.position.x, y + h + unit * 0.5), Vector2(rect.end.x, y + h + unit * 0.5), color, 1.5)
	while x + unit * 3.0 <= rect.end.x:
		var pts := PackedVector2Array([
			Vector2(x, y + h), Vector2(x, y + unit * 0.5), Vector2(x + unit * 2.0, y + unit * 0.5),
			Vector2(x + unit * 2.0, y + unit * 1.4), Vector2(x + unit, y + unit * 1.4), Vector2(x + unit, y + h),
			Vector2(x + unit * 3.0, y + h)])
		canvas.draw_polyline(pts, color, 1.5)
		x += unit * 3.0
