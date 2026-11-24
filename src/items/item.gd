class_name Item
extends RefCounted
## One rolled item: a base (data/items/bases.json), a rarity, an item level and
## the affixes it rolled, or a mythic unique (data/items/uniques.json).

enum Rarity { MORTAL, BLESSED, HEROIC, MYTHIC }

const RARITY_NAMES: Array[String] = ["Mortal", "Blessed", "Heroic", "Mythic"]
const RARITY_COLORS: Array[Color] = [Color("#D8D2C4"), Color("#5AA6E8"), Color("#7CCF6A"), Color("#F2C14E")]
const QUEST_COLOR := Color("#E8C547")
const LEVEL_SCALE := 0.09

var base_id := &""
var rarity: int = Rarity.MORTAL
var item_level := 1
## [{"id": affix id, "value": rolled number}]
var affixes: Array = []
var unique_id := &""
var count := 1


static func create(id: StringName, level: int = 1, item_rarity: int = Rarity.MORTAL) -> Item:
	var item := Item.new()
	item.base_id = id
	item.item_level = level
	item.rarity = item_rarity
	return item


static func create_unique(id: StringName) -> Item:
	var data := DB.uniques.get(String(id), {}) as Dictionary
	var item := Item.new()
	item.unique_id = id
	item.base_id = StringName(String(data.get("base", "")))
	item.rarity = Rarity.MYTHIC
	item.item_level = int(data.get("level", 1))
	return item


func base() -> Dictionary:
	return DB.item_base(base_id)


func unique() -> Dictionary:
	return DB.uniques.get(String(unique_id), {}) as Dictionary if unique_id != &"" else {}


func slot() -> String:
	return String(base().get("slot", ""))


func size() -> Vector2i:
	var s := base().get("size", [1, 1]) as Array
	return Vector2i(int(s[0]), int(s[1]))


func is_gear() -> bool:
	return slot() in ["weapon", "shield", "head", "chest", "legs", "ring", "amulet"]


func is_potion() -> bool:
	return slot() == "potion"


func is_quest() -> bool:
	return slot() == "quest"


func max_stack() -> int:
	return int(base().get("stack", 1))


func display_name() -> String:
	if unique_id != &"":
		return String(unique().get("name", "?"))
	var name := String(base().get("name", String(base_id)))
	if is_potion() or is_quest():
		return name
	var prefix := ""
	var suffix := ""
	for entry: Variant in affixes:
		var affix := Loot.affix(StringName(String((entry as Dictionary)["id"])))
		if affix.get("kind", "") == "prefix":
			prefix = String(affix["name"])
		else:
			suffix = String(affix["name"])
	if prefix != "":
		name = prefix + " " + name
	if suffix != "":
		name += " " + suffix
	return name


func color() -> Color:
	if is_quest():
		return QUEST_COLOR
	return RARITY_COLORS[clampi(rarity, 0, 3)]


func model_slug() -> String:
	var own := String(unique().get("model", ""))
	return own if own != "" else String(base().get("model", ""))


func icon_path() -> String:
	var own := String(unique().get("model", ""))
	var icon := own if own != "" else String(base().get("icon", String(base_id)))
	return "res://assets/icons/items/%s.png" % icon


func level_factor() -> float:
	return 1.0 + LEVEL_SCALE * float(item_level - 1)


## Weapon damage range before modifiers.
func damage_range() -> Vector2:
	var d := base().get("damage", [0, 0]) as Array
	var f := level_factor()
	return Vector2(round(float(d[0]) * f), round(float(d[1]) * f))


func armor() -> float:
	return round(float(base().get("armor", 0.0)) * level_factor())


## Every stat modifier this item gives (see Stats.mod).
func mods() -> Array:
	var out: Array = []
	var b := base()
	if b.has("damage"):
		var range_ := damage_range()
		out.append(Stats.mod(Stats.DAMAGE_MIN, range_.x))
		out.append(Stats.mod(Stats.DAMAGE_MAX, range_.y))
	if b.has("armor"):
		out.append(Stats.mod(Stats.ARMOR, armor()))
	if b.has("health"):
		out.append(Stats.mod(Stats.MAX_HEALTH, round(float(b["health"]) * level_factor())))
	if unique_id != &"":
		for row: Variant in unique().get("mods", []):
			var r := row as Array
			out.append(Stats.mod(StringName(String(r[0])), float(r[1]), float(r[2])))
		return out
	for entry: Variant in affixes:
		var e := entry as Dictionary
		var affix := Loot.affix(StringName(String(e["id"])))
		if affix.is_empty():
			continue
		var stat := StringName(String(affix["stat"]))
		var value := float(e["value"])
		if affix.has("pct"):
			out.append(Stats.mod(stat, 0.0, value))
		else:
			out.append(Stats.mod(stat, value))
		if affix.has("also"):
			var also := affix["also"] as Dictionary
			out.append(Stats.mod(StringName(String(also["stat"])), round(value * float(also.get("mult", 1.0)))))
	return out


## Tooltip lines: [{"text": String, "color": Color}].
func describe() -> Array:
	var lines: Array = []
	var b := base()
	lines.append({"text": display_name(), "color": color(), "size": 1})
	if unique_id != &"":
		lines.append({"text": "Mythic " + String(b.get("name", "")), "color": color().darkened(0.2)})
	elif is_gear():
		lines.append({"text": "%s %s" % [RARITY_NAMES[rarity], _slot_label()], "color": Color("#A89D86")})
	if b.has("damage"):
		var r := damage_range()
		lines.append({"text": "%d–%d damage · %.2f attacks/s" % [int(r.x), int(r.y), float(b.get("speed", 1.0))], "color": Color("#EFE6D2")})
	if b.has("armor"):
		lines.append({"text": "%d armour" % int(armor()), "color": Color("#EFE6D2")})
	if b.has("health"):
		lines.append({"text": "+%d health" % int(round(float(b["health"]) * level_factor())), "color": Color("#EFE6D2")})
	if is_potion():
		var heal := float(b.get("heal", 0.0))
		var restore := float(b.get("restore", 0.0))
		lines.append({"text": ("Restores %d%% health" % int(heal * 100)) if heal > 0.0 else ("Restores %d%% ichor" % int(restore * 100)), "color": Color("#EFE6D2")})
		lines.append({"text": "%d in the belt" % count, "color": Color("#A89D86")})
	var affix_color := Color("#8FC3F0")
	if unique_id != &"":
		for row: Variant in unique().get("mods", []):
			var r := row as Array
			lines.append({"text": Item.mod_text(StringName(String(r[0])), float(r[1]), float(r[2])), "color": RARITY_COLORS[3].lightened(0.2)})
	else:
		for entry: Variant in affixes:
			var e := entry as Dictionary
			var affix := Loot.affix(StringName(String(e["id"])))
			if affix.is_empty():
				continue
			var value := float(e["value"])
			var stat := StringName(String(affix["stat"]))
			if affix.has("pct"):
				lines.append({"text": Item.mod_text(stat, 0.0, value), "color": affix_color})
			else:
				lines.append({"text": Item.mod_text(stat, value, 0.0), "color": affix_color})
				if affix.has("also"):
					var also := affix["also"] as Dictionary
					lines.append({"text": Item.mod_text(StringName(String(also["stat"])), round(value * float(also.get("mult", 1.0))), 0.0), "color": affix_color})
	var lore := String(unique().get("lore", b.get("lore", "")))
	if lore != "":
		lines.append({"text": "“%s”" % lore, "color": Color("#C9B98F"), "italic": true})
	if is_gear():
		lines.append({"text": "Item level %d" % item_level, "color": Color("#7D7466")})
	return lines


func _slot_label() -> String:
	match slot():
		"weapon":
			return String(base().get("kind", "weapon")).capitalize()
		"head":
			return "Helm"
		"chest":
			return "Armour"
		"legs":
			return "Greaves"
		_:
			return slot().capitalize()


static func mod_text(stat: StringName, flat: float, pct: float) -> String:
	var label := String(STAT_LABELS.get(stat, String(stat).capitalize()))
	if pct != 0.0:
		return "+%d%% %s" % [int(round(pct)), label]
	if stat in [Stats.DAMAGE_PCT, Stats.SKILL_DAMAGE_PCT, Stats.CRIT_CHANCE]:
		return "+%d%% %s" % [int(round(flat)), label]
	if stat in [Stats.HEALTH_REGEN, Stats.ICHOR_REGEN, Stats.CRIT_MULTIPLIER]:
		return "+%.1f %s" % [flat, label]
	return "+%d %s" % [int(round(flat)), label]


const STAT_LABELS := {
	&"max_health": "health", &"max_ichor": "ichor", &"health_regen": "health per second",
	&"ichor_regen": "ichor per second", &"armor": "armour", &"damage_min": "minimum damage",
	&"damage_max": "maximum damage", &"damage_pct": "damage", &"skill_damage_pct": "skill damage",
	&"attack_speed": "attack speed", &"crit_chance": "critical chance", &"crit_multiplier": "critical damage",
	&"move_speed": "movement speed", &"life_on_hit": "health per hit", &"fire_damage": "fire damage",
	&"might": "Might", &"cunning": "Cunning", &"spirit": "Spirit", &"all_attributes": "all attributes",
	&"magic_find": "chance of finer loot",
}


func to_dict() -> Dictionary:
	return {"base": String(base_id), "rarity": rarity, "level": item_level, "affixes": affixes.duplicate(true),
		"unique": String(unique_id), "count": count}


static func from_dict(data: Dictionary) -> Item:
	var item := Item.new()
	item.base_id = StringName(String(data.get("base", "")))
	item.rarity = int(data.get("rarity", 0))
	item.item_level = int(data.get("level", 1))
	item.affixes = (data.get("affixes", []) as Array).duplicate(true)
	item.unique_id = StringName(String(data.get("unique", "")))
	item.count = int(data.get("count", 1))
	return item
