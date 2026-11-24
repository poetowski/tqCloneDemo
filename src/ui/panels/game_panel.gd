class_name GamePanel
extends PanelContainer
## A window in the black-figure style: glaze background, terracotta border, a
## title over a gold meander band, and a close button. Subclasses fill `content`.

var content: VBoxContainer
var player: Player
var _title: Label


func _init() -> void:
	add_theme_stylebox_override(&"panel", UIStyle.panel(UIStyle.TERRACOTTA, UIStyle.GLAZE, 2, 8))
	mouse_filter = Control.MOUSE_FILTER_STOP
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override(&"separation", 8)
	add_child(outer)
	var header := HBoxContainer.new()
	outer.add_child(header)
	_title = UIStyle.label("", 24, UIStyle.GOLD, 6)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	var close := UIStyle.button("✕", 16)
	close.custom_minimum_size = Vector2(34, 30)
	close.pressed.connect(func() -> void:
		visible = false
		Sfx.play(&"ui_close"))
	header.add_child(close)
	var band := Control.new()
	band.custom_minimum_size = Vector2(0, 16)
	band.draw.connect(func() -> void: UIStyle.draw_meander(band, Rect2(Vector2.ZERO, band.size), UIStyle.GOLD, 5.0))
	outer.add_child(band)
	content = VBoxContainer.new()
	content.add_theme_constant_override(&"separation", 6)
	outer.add_child(content)


func set_title(text: String) -> void:
	_title.text = text


func bind_player(p: Player) -> void:
	player = p


## Places the panel against a screen edge (0 = left, 1 = right), vertically centred.
func dock(side: float, panel_size: Vector2, margin: float = 24.0) -> void:
	custom_minimum_size = panel_size
	anchor_left = side
	anchor_right = side
	anchor_top = 0.5
	anchor_bottom = 0.5
	var x := margin if side < 0.5 else -panel_size.x - margin
	offset_left = x
	offset_right = x + panel_size.x
	offset_top = -panel_size.y * 0.5 - 80.0
	offset_bottom = panel_size.y * 0.5 - 80.0
