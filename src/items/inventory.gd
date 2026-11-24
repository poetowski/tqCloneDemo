class_name Inventory
extends RefCounted
## The hero's bag: a grid where each item covers its size in cells
## (Item.size()). Positions are the item's top-left cell.

signal changed()

var width := 10
var height := 6
## Item -> Vector2i
var _positions: Dictionary = {}


func _init(w: int = 10, h: int = 6) -> void:
	width = w
	height = h


func items() -> Array:
	return _positions.keys()


func position_of(item: Item) -> Vector2i:
	return _positions.get(item, Vector2i(-1, -1)) as Vector2i


func has_item(item: Item) -> bool:
	return _positions.has(item)


func item_at(cell: Vector2i) -> Item:
	for item: Variant in _positions:
		var it := item as Item
		var p := _positions[it] as Vector2i
		var s := it.size()
		if cell.x >= p.x and cell.x < p.x + s.x and cell.y >= p.y and cell.y < p.y + s.y:
			return it
	return null


## Whether `item` fits at `cell`, ignoring `ignore` (the item being moved).
func can_place(item: Item, cell: Vector2i, ignore: Item = null) -> bool:
	var s := item.size()
	if cell.x < 0 or cell.y < 0 or cell.x + s.x > width or cell.y + s.y > height:
		return false
	for other: Variant in _positions:
		var o := other as Item
		if o == item or o == ignore:
			continue
		var p := _positions[o] as Vector2i
		var os := o.size()
		if cell.x < p.x + os.x and cell.x + s.x > p.x and cell.y < p.y + os.y and cell.y + s.y > p.y:
			return false
	return true


## The first cell where `item` fits, column by column like the old games, or (-1, -1).
func find_space(item: Item) -> Vector2i:
	for x in width:
		for y in height:
			if can_place(item, Vector2i(x, y)):
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func add(item: Item) -> bool:
	var cell := find_space(item)
	if cell.x < 0:
		return false
	_positions[item] = cell
	changed.emit()
	return true


func place(item: Item, cell: Vector2i) -> bool:
	if not can_place(item, cell):
		return false
	_positions[item] = cell
	changed.emit()
	return true


func remove(item: Item) -> void:
	if _positions.erase(item):
		changed.emit()


## Items overlapping a rectangle (for swaps when dropping onto the grid).
func overlapping(item: Item, cell: Vector2i) -> Array:
	var found: Array = []
	var s := item.size()
	for other: Variant in _positions:
		var o := other as Item
		if o == item:
			continue
		var p := _positions[o] as Vector2i
		var os := o.size()
		if cell.x < p.x + os.x and cell.x + s.x > p.x and cell.y < p.y + os.y and cell.y + s.y > p.y:
			found.append(o)
	return found


func to_array() -> Array:
	var out: Array = []
	for item: Variant in _positions:
		var p := _positions[item] as Vector2i
		out.append({"item": (item as Item).to_dict(), "x": p.x, "y": p.y})
	return out
