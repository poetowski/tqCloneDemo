class_name Loot
extends RefCounted
## Rolls items and loot drops from data/items/*.json. Pure functions of their
## inputs and an RNG, so tests can seed them.

const AFFIX_LEVEL_SCALE := 0.08

static var _affix_index: Dictionary = {}


static func affix(id: StringName) -> Dictionary:
	if _affix_index.is_empty():
		for entry: Variant in DB.affixes:
			var e := entry as Dictionary
			_affix_index[StringName(String(e["id"]))] = e
	return _affix_index.get(id, {}) as Dictionary


## Picks a gear base that may drop at `level` (and allows `rarity`).
static func pick_base(level: int, rarity: int, rng: RandomNumberGenerator) -> StringName:
	var pool: Array[StringName] = []
	var weights: Array[float] = []
	for id: Variant in DB.item_bases:
		var b := DB.item_bases[id] as Dictionary
		if not b.has("weight"):
			continue
		if int(b.get("level", 1)) > level:
			continue
		if rarity < int(b.get("min_rarity", 0)):
			continue
		pool.append(StringName(String(id)))
		weights.append(float(b["weight"]))
	if pool.is_empty():
		return &"dory"
	return pool[_weighted(weights, rng)]


## Rolls one item of a given rarity at an item level.
static func roll_item(level: int, rarity: int, rng: RandomNumberGenerator, base_id: StringName = &"") -> Item:
	if base_id == &"":
		base_id = pick_base(level, rarity, rng)
	var item := Item.create(base_id, level, rarity)
	var count := 0
	match rarity:
		Item.Rarity.BLESSED:
			count = 1 if rng.randf() < 0.6 else 2
		Item.Rarity.HEROIC:
			count = 2 if rng.randf() < 0.55 else 3
	var slot := item.slot()
	var used_kinds: Dictionary = {}
	var used_ids: Dictionary = {}
	for i in count:
		var candidates: Array = []
		var weights: Array[float] = []
		for entry: Variant in DB.affixes:
			var e := entry as Dictionary
			var kind := String(e["kind"])
			if used_ids.has(e["id"]):
				continue
			# One prefix and one suffix make the name; a third affix may repeat a kind.
			if used_kinds.has(kind) and used_kinds.size() < 2:
				continue
			var slots := e["slots"] as Array
			if not ("any" in slots or slot in slots):
				continue
			candidates.append(e)
			weights.append(float(e.get("weight", 1)))
		if candidates.is_empty():
			break
		var chosen := candidates[_weighted(weights, rng)] as Dictionary
		used_ids[chosen["id"]] = true
		used_kinds[String(chosen["kind"])] = true
		item.affixes.append({"id": String(chosen["id"]), "value": roll_affix_value(chosen, level, rarity, rng)})
	return item


static func roll_affix_value(entry: Dictionary, level: int, rarity: int, rng: RandomNumberGenerator) -> float:
	var span := (entry["pct"] if entry.has("pct") else entry["flat"]) as Array
	var low := float(span[0])
	var high := float(span[1])
	# Heroic rolls lean high.
	var t := rng.randf()
	if rarity >= Item.Rarity.HEROIC:
		t = 1.0 - (1.0 - t) * (1.0 - t)
	var value := lerpf(low, high, t) * (1.0 + AFFIX_LEVEL_SCALE * float(level - 1))
	return round(value * 10.0) / 10.0 if high < 3.0 else round(value)


static func roll_rarity(weights_in: Array, magic_find: float, rng: RandomNumberGenerator) -> int:
	var weights: Array[float] = []
	for w: Variant in weights_in:
		weights.append(float(w))
	# Magic find moves weight from Mortal to the better tiers.
	var shift := weights[0] * clampf(magic_find / 100.0, 0.0, 0.8) * 0.5
	weights[0] -= shift
	weights[1] += shift * 0.75
	weights[2] += shift * 0.22
	weights[3] += shift * 0.03
	return _weighted(weights, rng)


## Everything a loot table drops: {"items": Array[Item], "gold": int}.
static func roll_table(table_id: String, level: int, magic_find: float, rng: RandomNumberGenerator) -> Dictionary:
	var table := DB.loot_tables.get(table_id, {}) as Dictionary
	var items: Array[Item] = []
	var gold := 0
	if table.is_empty():
		return {"items": items, "gold": gold}
	var rolls := int(table.get("rolls", 1))
	for i in rolls:
		if rng.randf() < float(table.get("item_chance", 0.0)):
			var rarity := roll_rarity(table.get("rarity", [100, 0, 0, 0]) as Array, magic_find, rng)
			rarity = maxi(rarity, int(table.get("min_rarity", 0)))
			if rarity == Item.Rarity.MYTHIC:
				items.append(_random_unique(level, rng))
			else:
				items.append(roll_item(maxi(1, level + rng.randi_range(-1, 1)), rarity, rng))
	var gold_spec := table.get("gold", [0, 0, 0]) as Array
	if rng.randf() < float(gold_spec[0]):
		gold = int(round(rng.randf_range(float(gold_spec[1]), float(gold_spec[2])) * (1.0 + 0.25 * float(level - 1))))
	if rng.randf() < float(table.get("potion", 0.0)):
		items.append(Item.create(&"potion_health" if rng.randf() < 0.62 else &"potion_ichor"))
	if table.has("unique"):
		items.append(Item.create_unique(StringName(String(table["unique"]))))
	if table.has("unique_chance"):
		var spec := table["unique_chance"] as Array
		if rng.randf() < float(spec[0]):
			items.append(Item.create_unique(StringName(String(spec[1]))))
	if table.has("quest_item"):
		items.append(Item.create(StringName(String(table["quest_item"]))))
	return {"items": items, "gold": gold}


static func _random_unique(level: int, rng: RandomNumberGenerator) -> Item:
	var ids: Array[String] = []
	for id: Variant in DB.uniques:
		if int((DB.uniques[id] as Dictionary).get("level", 1)) <= level + 2 and String(id) != "ember_of_hephaestus":
			ids.append(String(id))
	if ids.is_empty():
		return roll_item(level, Item.Rarity.HEROIC, rng)
	return Item.create_unique(StringName(ids[rng.randi_range(0, ids.size() - 1)]))


static func _weighted(weights: Array[float], rng: RandomNumberGenerator) -> int:
	var total := 0.0
	for w in weights:
		total += maxf(0.0, w)
	var pick := rng.randf() * total
	for i in weights.size():
		pick -= maxf(0.0, weights[i])
		if pick <= 0.0:
			return i
	return weights.size() - 1
