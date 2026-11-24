class_name InventoryPanel
extends GamePanel
## The bag and the worn gear (I). Click to lift an item, click again to put it
## down (swapping with what's there); right-click to wear or take off; click
## outside the window to drop what you hold. Items cover their size in cells.

const CELL := 46.0
const DOLL_HEIGHT := 352.0
## slot: [top-left in the doll area, size in cells, label]
const SLOTS := {
	"head": [Vector2(198, 4), Vector2i(2, 2), "Helm"],
	"amulet": [Vector2(306, 26), Vector2i(1, 1), "Amulet"],
	"weapon": [Vector2(42, 70), Vector2i(2, 4), "Weapon"],
	"chest": [Vector2(198, 108), Vector2i(2, 3), "Armour"],
	"shield": [Vector2(352, 92), Vector2i(2, 2), "Shield"],
	"ring1": [Vector2(132, 250), Vector2i(1, 1), "Ring"],
	"ring2": [Vector2(306, 250), Vector2i(1, 1), "Ring"],
	"legs": [Vector2(198, 258), Vector2i(2, 2), "Greaves"],
}

var held: Item
var _view: Control
var _tooltip: ItemTooltip
var _gold: Label
var _held_icon: TextureRect
var _hover_cell := Vector2i(-1, -1)
var _hover_slot := ""
var _icons: Dictionary = {}


func _init() -> void:
	super._init()
	set_title("Pack and Arms")
	_view = Control.new()
	_view.custom_minimum_size = Vector2(10 * CELL, DOLL_HEIGHT + 6 * CELL + 8)
	_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_view.draw.connect(_draw_view)
	_view.gui_input.connect(_view_input)
	_view.mouse_exited.connect(func() -> void:
		_hover_cell = Vector2i(-1, -1)
		_hover_slot = ""
		_tooltip.visible = false
		_view.queue_redraw())
	content.add_child(_view)
	_gold = UIStyle.label("", 18, Color("#E8C547"))
	content.add_child(_gold)
	var hint := UIStyle.label("Right-click to wear or take off · click outside to drop", 13, UIStyle.DIM, 3)
	content.add_child(hint)
	dock(1.0, Vector2(10 * CELL + 24, DOLL_HEIGHT + 6 * CELL + 150))
	_tooltip = ItemTooltip.new()
	_held_icon = TextureRect.new()
	_held_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_held_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_held_icon.z_index = 40
	visibility_changed.connect(_on_visibility)


func _ready() -> void:
	get_parent().add_child.call_deferred(_tooltip)
	get_parent().add_child.call_deferred(_held_icon)


func bind_player(p: Player) -> void:
	super.bind_player(p)
	player.inventory.changed.connect(refresh)
	player.equipment.changed.connect(func(_slot: String) -> void: refresh())
	player.gold_changed.connect(func(_total: int) -> void: refresh())
	refresh()


func refresh() -> void:
	if player:
		_gold.text = "%d drachmae" % player.gold
	_view.queue_redraw()


func _on_visibility() -> void:
	if not visible:
		_tooltip.visible = false
		if held:
			if not player.inventory.add(held):
				player.drop_item(held)
			held = null
			_held_icon.visible = false


func _process(_delta: float) -> void:
	if held and visible:
		_held_icon.visible = true
		var s := Vector2(held.size()) * CELL
		_held_icon.size = s
		_held_icon.global_position = get_global_mouse_position() - s * 0.5
	elif _held_icon:
		_held_icon.visible = false


## Clicks outside the window while holding an item drop it on the ground.
func _input(event: InputEvent) -> void:
	if not visible or held == null:
		return
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT and not get_global_rect().has_point(click.global_position):
		player.drop_item(held)
		held = null
		Sfx.play(&"drop_item")
		get_viewport().set_input_as_handled()
		refresh()


# --- geometry ---------------------------------------------------------------------

func _grid_origin() -> Vector2:
	return Vector2(0, DOLL_HEIGHT + 8)


func _cell_at(point: Vector2) -> Vector2i:
	var local := point - _grid_origin()
	if local.x < 0 or local.y < 0:
		return Vector2i(-1, -1)
	var cell := Vector2i(int(local.x / CELL), int(local.y / CELL))
	if cell.x >= player.inventory.width or cell.y >= player.inventory.height:
		return Vector2i(-1, -1)
	return cell


func _slot_at(point: Vector2) -> String:
	for slot: Variant in SLOTS:
		var spec := SLOTS[slot] as Array
		if Rect2(spec[0] as Vector2, Vector2(spec[1] as Vector2i) * CELL).has_point(point):
			return String(slot)
	return ""


## Where a held item's top-left lands: centred on the cursor, snapped to cells.
func _placement(point: Vector2, item: Item) -> Vector2i:
	var local := point - _grid_origin() - Vector2(item.size() - Vector2i.ONE) * CELL * 0.5
	return Vector2i(int(floor(local.x / CELL)), int(floor(local.y / CELL)))


# --- input --------------------------------------------------------------------------

func _view_input(event: InputEvent) -> void:
	if player == null:
		return
	var motion := event as InputEventMouseMotion
	if motion:
		_hover_cell = _cell_at(motion.position)
		_hover_slot = _slot_at(motion.position)
		_update_tooltip(motion.global_position)
		_view.queue_redraw()
		return
	var click := event as InputEventMouseButton
	if click == null or not click.pressed:
		return
	if click.button_index == MOUSE_BUTTON_LEFT:
		_left_click(click.position)
	elif click.button_index == MOUSE_BUTTON_RIGHT:
		_right_click(click.position)
	_update_tooltip(click.global_position)
	accept_event()
	refresh()


func _left_click(point: Vector2) -> void:
	var slot := _slot_at(point)
	if slot != "":
		if held:
			if player.equipment.accepts(slot, held):
				var previous := player.equipment.equip(slot, held)
				held = previous
				Sfx.play(&"equip")
			else:
				Sfx.play(&"denied")
		elif player.equipment.get_item(slot):
			held = player.equipment.unequip(slot)
			Sfx.play(&"lift")
		return
	var cell := _cell_at(point)
	if cell.x < 0 and held == null:
		return
	if held:
		var at := _placement(point, held)
		if player.inventory.can_place(held, at):
			player.inventory.place(held, at)
			held = null
			Sfx.play(&"place")
			return
		var blocking := player.inventory.overlapping(held, at)
		if blocking.size() == 1:
			var other := blocking[0] as Item
			player.inventory.remove(other)
			if player.inventory.can_place(held, at):
				player.inventory.place(held, at)
				held = other
				Sfx.play(&"place")
				return
			player.inventory.place(other, player.inventory.position_of(other))
		Sfx.play(&"denied")
		return
	var item := player.inventory.item_at(cell)
	if item:
		player.inventory.remove(item)
		held = item
		Sfx.play(&"lift")


func _right_click(point: Vector2) -> void:
	if held:
		return
	var slot := _slot_at(point)
	if slot != "":
		player.unequip_to_inventory(slot)
		Sfx.play(&"lift")
		return
	var cell := _cell_at(point)
	if cell.x < 0:
		return
	var item := player.inventory.item_at(cell)
	if item == null:
		return
	if item.is_potion():
		var have := int(player.belt.get(item.base_id, 0))
		if have < Player.BELT_MAX:
			player.belt[item.base_id] = have + item.count
			player.inventory.remove(item)
			player.belt_changed.emit()
		return
	if item.is_gear() and player.equip_from_inventory(item):
		Sfx.play(&"equip")


func _update_tooltip(global_point: Vector2) -> void:
	var item: Item = null
	var compare: Item = null
	var hint := ""
	if held:
		_tooltip.visible = false
		return
	if _hover_slot != "":
		item = player.equipment.get_item(_hover_slot)
		hint = "Right-click to take off"
	elif _hover_cell.x >= 0:
		item = player.inventory.item_at(_hover_cell)
		if item and item.is_gear():
			compare = player.equipment.get_item(player.equipment.slot_for(item) if item.slot() != "ring" else "ring1")
			hint = "Right-click to wear"
	if item:
		_tooltip.show_item(item, global_point, compare, hint)
	else:
		_tooltip.visible = false


# --- drawing ------------------------------------------------------------------------

func icon(item: Item) -> Texture2D:
	var path := item.icon_path()
	if not _icons.has(path):
		_icons[path] = load(path) if ResourceLoader.exists(path) else null
	return _icons[path] as Texture2D


func _draw_item(canvas: Control, item: Item, rect: Rect2) -> void:
	var tint := item.color()
	canvas.draw_rect(rect.grow(-2), Color(tint.r, tint.g, tint.b, 0.12 if item.rarity > 0 or item.is_quest() else 0.05))
	var texture := icon(item)
	if texture:
		var side := minf(rect.size.x, rect.size.y)
		var icon_rect := Rect2(rect.position + (rect.size - Vector2(side, side)) * 0.5, Vector2(side, side))
		if rect.size.y > rect.size.x * 1.4:
			icon_rect = rect.grow(-3)
		canvas.draw_texture_rect(texture, icon_rect, false)
	else:
		var font := canvas.get_theme_default_font()
		canvas.draw_string(font, rect.get_center() + Vector2(-8, 8), item.display_name().substr(0, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, tint)
	if item.count > 1:
		var font2 := canvas.get_theme_default_font()
		canvas.draw_string_outline(font2, rect.end - Vector2(16, 6), str(item.count), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, UIStyle.OUTLINE)
		canvas.draw_string(font2, rect.end - Vector2(16, 6), str(item.count), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UIStyle.BONE)
	canvas.draw_rect(rect.grow(-1), Color(tint.r, tint.g, tint.b, 0.55 if item.rarity > 0 or item.is_quest() else 0.2), false, 1.5)


func _draw_view() -> void:
	if player == null:
		return
	var font := _view.get_theme_default_font()
	# The doll: a figure drawn in gold lines behind the slots.
	var mid := Vector2(244, 0)
	var figure := Color(0.89, 0.69, 0.29, 0.14)
	_view.draw_circle(mid + Vector2(0, 48), 34, figure)
	_view.draw_rect(Rect2(mid + Vector2(-58, 92), Vector2(116, 150)), figure)
	_view.draw_line(mid + Vector2(-58, 110), mid + Vector2(-150, 220), figure, 22.0)
	_view.draw_line(mid + Vector2(58, 110), mid + Vector2(150, 220), figure, 22.0)
	_view.draw_line(mid + Vector2(-30, 240), mid + Vector2(-38, 350), figure, 26.0)
	_view.draw_line(mid + Vector2(30, 240), mid + Vector2(38, 350), figure, 26.0)
	for slot: Variant in SLOTS:
		var spec := SLOTS[slot] as Array
		var rect := Rect2(spec[0] as Vector2, Vector2(spec[1] as Vector2i) * CELL)
		var hovered := String(slot) == _hover_slot
		var accepts := held != null and player.equipment.accepts(String(slot), held)
		var border := UIStyle.GOLD if hovered or accepts else Color(0.42, 0.3, 0.2)
		_view.draw_style_box(UIStyle.slot_box(border), rect)
		var item := player.equipment.get_item(String(slot))
		if item:
			_draw_item(_view, item, rect)
		else:
			_view.draw_string(font, rect.position + Vector2(5, rect.size.y - 6), String(spec[2]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UIStyle.DIM)
	# The grid.
	var origin := _grid_origin()
	var inv := player.inventory
	for x in inv.width:
		for y in inv.height:
			_view.draw_rect(Rect2(origin + Vector2(x, y) * CELL, Vector2(CELL, CELL)).grow(-1), Color(0.07, 0.055, 0.05, 0.9))
	for entry: Variant in inv.items():
		var item := entry as Item
		var at := inv.position_of(item)
		_draw_item(_view, item, Rect2(origin + Vector2(at) * CELL, Vector2(item.size()) * CELL))
	if held and _hover_cell.x >= 0:
		var at := _placement(_view.get_local_mouse_position(), held)
		var fits := inv.can_place(held, at) or inv.overlapping(held, at).size() == 1
		_view.draw_rect(Rect2(origin + Vector2(at) * CELL, Vector2(held.size()) * CELL), Color(0.3, 0.9, 0.4, 0.25) if fits else Color(0.9, 0.2, 0.2, 0.25))
	if held:
		var texture := icon(held)
		_held_icon.texture = texture
