extends GutTest
## Loot rolls: affix counts by rarity, tables, magic find.


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func test_affix_counts_follow_rarity() -> void:
	var rng := _rng(1)
	for i in 30:
		assert_eq(Loot.roll_item(3, Item.Rarity.MORTAL, rng).affixes.size(), 0)
		var blessed := Loot.roll_item(3, Item.Rarity.BLESSED, rng).affixes.size()
		assert_between(blessed, 1, 2)
		var heroic := Loot.roll_item(3, Item.Rarity.HEROIC, rng).affixes.size()
		assert_between(heroic, 2, 3)


func test_affixes_fit_their_slot() -> void:
	var rng := _rng(2)
	for i in 40:
		var item := Loot.roll_item(4, Item.Rarity.HEROIC, rng)
		for entry: Variant in item.affixes:
			var affix := Loot.affix(StringName(String((entry as Dictionary)["id"])))
			var slots := affix["slots"] as Array
			assert_true("any" in slots or item.slot() in slots, "%s on %s" % [affix["id"], item.slot()])


func test_boss_table_drops_the_blade_and_the_ember() -> void:
	var result := Loot.roll_table("boss", 7, 0.0, _rng(3))
	var ids: Array[String] = []
	for item: Variant in result["items"] as Array:
		ids.append(String((item as Item).base_id) + "/" + String((item as Item).unique_id))
	assert_true(ids.any(func(s: String) -> bool: return s.begins_with("blade_of_atropos")))
	assert_true(ids.any(func(s: String) -> bool: return s.ends_with("ember_of_hephaestus")))
	assert_gt(int(result["gold"]), 0)


func test_magic_find_moves_drops_off_mortal() -> void:
	var weights := [70, 24, 5.5, 0.5]
	var plain := 0
	var lucky := 0
	var rng_a := _rng(4)
	var rng_b := _rng(4)
	for i in 2000:
		if Loot.roll_rarity(weights, 0.0, rng_a) > 0:
			plain += 1
		if Loot.roll_rarity(weights, 80.0, rng_b) > 0:
			lucky += 1
	assert_gt(lucky, plain)


func test_bases_respect_drop_level() -> void:
	var rng := _rng(5)
	for i in 50:
		var id := Loot.pick_base(1, Item.Rarity.MORTAL, rng)
		assert_lte(int(DB.item_base(id).get("level", 1)), 1)
