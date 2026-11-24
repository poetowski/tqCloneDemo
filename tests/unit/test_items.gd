extends GutTest
## Items: level scaling, names from affixes, modifiers, uniques, saving.


func test_weapon_damage_scales_with_item_level() -> void:
	var low := Item.create(&"dory", 1)
	var high := Item.create(&"dory", 5)
	assert_eq(low.damage_range(), Vector2(8, 13))
	assert_gt(high.damage_range().x, low.damage_range().x)


func test_name_takes_prefix_and_suffix() -> void:
	var item := Item.create(&"aspis", 2, Item.Rarity.BLESSED)
	item.affixes = [{"id": "spartan", "value": 12.0}, {"id": "of_the_olive", "value": 1.0}]
	assert_eq(item.display_name(), "Spartan Aspis of the Olive")


func test_mods_include_base_and_affixes() -> void:
	var item := Item.create(&"linothorax", 1, Item.Rarity.BLESSED)
	item.affixes = [{"id": "nemean", "value": 15.0}]
	var armor := 0.0
	var health := 0.0
	for mod: Variant in item.mods():
		var m := mod as Dictionary
		if m["stat"] == Stats.ARMOR:
			armor += float(m["flat"])
		if m["stat"] == Stats.MAX_HEALTH:
			health += float(m["flat"])
	assert_eq(armor, 10.0)
	assert_eq(health, 15.0)


func test_brazen_adds_both_damage_ends() -> void:
	var item := Item.create(&"xiphos", 1, Item.Rarity.BLESSED)
	item.affixes = [{"id": "brazen", "value": 3.0}]
	var stats := Stats.new()
	stats.set_source(&"w", item.mods())
	assert_eq(stats.value(Stats.DAMAGE_MIN), 9.0)
	assert_eq(stats.value(Stats.DAMAGE_MAX), 15.0)


func test_unique_has_fixed_name_and_lore() -> void:
	var item := Item.create_unique(&"ember_of_hephaestus")
	assert_eq(item.display_name(), "Ember of Hephaestus")
	assert_eq(item.rarity, Item.Rarity.MYTHIC)
	assert_eq(item.model_slug(), "kopis_ember")
	var lines := item.describe()
	var has_lore := false
	for line: Variant in lines:
		if String((line as Dictionary)["text"]).contains("forge"):
			has_lore = true
	assert_true(has_lore)


func test_round_trip_through_a_dictionary() -> void:
	var item := Item.create(&"helm_attic", 3, Item.Rarity.HEROIC)
	item.affixes = [{"id": "keen", "value": 4.0}]
	var copy := Item.from_dict(item.to_dict())
	assert_eq(copy.display_name(), item.display_name())
	assert_eq(copy.item_level, 3)
	assert_eq(copy.rarity, Item.Rarity.HEROIC)
