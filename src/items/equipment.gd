class_name Equipment
extends RefCounted
## What the hero wears: one item per slot. Rings take either ring slot.

signal changed(slot: String)

const SLOTS: Array[String] = ["weapon", "shield", "head", "chest", "legs", "ring1", "ring2", "amulet"]

var _items: Dictionary = {}


func get_item(slot: String) -> Item:
	return _items.get(slot) as Item


## The slot an item would go to: rings fill the first empty ring slot.
func slot_for(item: Item) -> String:
	var s := item.slot()
	if s == "ring":
		return "ring1" if get_item("ring1") == null or get_item("ring2") != null else "ring2"
	return s if s in SLOTS else ""


func accepts(slot: String, item: Item) -> bool:
	if item == null:
		return true
	var s := item.slot()
	if s == "ring":
		return slot == "ring1" or slot == "ring2"
	return s == slot


## Puts `item` in `slot`; returns whatever was there (or null).
func equip(slot: String, item: Item) -> Item:
	if not accepts(slot, item):
		return item
	var previous := get_item(slot)
	if item == null:
		_items.erase(slot)
	else:
		_items[slot] = item
	changed.emit(slot)
	return previous


func unequip(slot: String) -> Item:
	return equip(slot, null)


func to_dict() -> Dictionary:
	var out: Dictionary = {}
	for slot: Variant in _items:
		out[slot] = (_items[slot] as Item).to_dict()
	return out
