extends Node
## Game data loaded once from data/*.json: palette, enemies, skills, items,
## affixes, loot tables, quests, dialogue and progression. Read-only at runtime.

var palette: Dictionary = {}
var enemies: Dictionary = {}
var skills: Dictionary = {}
var item_bases: Dictionary = {}
var affixes: Array = []
var uniques: Dictionary = {}
var loot_tables: Dictionary = {}
var quests: Dictionary = {}
var dialogue: Dictionary = {}
var progression: Dictionary = {}


func _ready() -> void:
	palette = _load_palette()
	enemies = _dict("res://data/enemies.json")
	skills = _dict("res://data/skills.json")
	item_bases = _dict("res://data/items/bases.json")
	uniques = _dict("res://data/items/uniques.json")
	loot_tables = _dict("res://data/items/loot_tables.json")
	quests = _dict("res://data/quests.json")
	dialogue = _dict("res://data/dialogue.json")
	progression = _dict("res://data/progression.json")
	var affix_data: Variant = load_json("res://data/items/affixes.json")
	if affix_data is Dictionary:
		affixes = (affix_data as Dictionary).get("affixes", []) as Array


## A palette swatch as a Color (sRGB), for UI and code-made effects.
func swatch(name: String) -> Color:
	return palette.get(name, Color.MAGENTA)


func enemy(id: StringName) -> Dictionary:
	return enemies.get(String(id), {}) as Dictionary


func skill(id: StringName) -> Dictionary:
	return skills.get(String(id), {}) as Dictionary


func item_base(id: StringName) -> Dictionary:
	return item_bases.get(String(id), {}) as Dictionary


func load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed == null:
		push_error("could not parse %s" % path)
	return parsed


func _dict(path: String) -> Dictionary:
	var data: Variant = load_json(path)
	if not data is Dictionary:
		return {}
	var out := (data as Dictionary).duplicate()
	out.erase("_doc")
	return out


func _load_palette() -> Dictionary:
	var colours: Dictionary = {}
	var data: Variant = load_json("res://data/palette.json")
	if data is Dictionary:
		for entry: Variant in (data as Dictionary)["swatches"]:
			var row := entry as Array
			colours[String(row[0])] = Color(String(row[1]))
	return colours
