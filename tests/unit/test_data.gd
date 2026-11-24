extends GutTest
## The data and the assets agree: every model, icon and sound the data names exists.


func test_palette_has_its_swatches() -> void:
	assert_eq(DB.palette.size(), 64)
	assert_true(DB.palette.has("ichor_glow") and DB.palette.has("styx_glow"))


func test_every_enemy_model_and_attachment_exists() -> void:
	for id: Variant in DB.enemies:
		var def := DB.enemies[id] as Dictionary
		assert_true(ResourceLoader.exists(String(def["model"])), "model of %s" % id)
		var attach := def.get("attach", {}) as Dictionary
		for slot: Variant in attach:
			var slug := String(attach[slot])
			assert_true(ResourceLoader.exists("res://assets/models/items/%s/%s.glb" % [slug, slug]), "%s on %s" % [slug, id])
			assert_false(ActorBody.attachment_spec(String(slot)).is_empty(), "slot %s" % slot)


func test_every_item_has_a_model_and_an_icon() -> void:
	for id: Variant in DB.item_bases:
		var item := Item.create(StringName(String(id)))
		var slug := item.model_slug()
		assert_true(ResourceLoader.exists("res://assets/models/items/%s/%s.glb" % [slug, slug]), "model of %s" % id)
		assert_true(ResourceLoader.exists(item.icon_path()), "icon of %s" % id)
	for id: Variant in DB.uniques:
		var unique := Item.create_unique(StringName(String(id)))
		assert_true(ResourceLoader.exists(unique.icon_path()), "icon of %s" % id)


func test_every_skill_has_an_icon() -> void:
	for id: Variant in DB.skills:
		assert_true(ResourceLoader.exists("res://assets/icons/skills/%s.png" % (DB.skills[id] as Dictionary)["icon"]), "icon of %s" % id)


func test_loot_tables_name_real_items() -> void:
	for table: Variant in DB.loot_tables:
		var t := DB.loot_tables[table] as Dictionary
		if t.has("unique"):
			assert_true(DB.uniques.has(String(t["unique"])), "%s unique" % table)
		if t.has("quest_item"):
			assert_false(DB.item_base(StringName(String(t["quest_item"]))).is_empty(), "%s quest item" % table)


func test_quests_talk_to_people_who_exist() -> void:
	for id: Variant in DB.quests:
		for stage: Variant in (DB.quests[id] as Dictionary)["stages"] as Array:
			var goal := (stage as Dictionary).get("goal", {}) as Dictionary
			if String(goal.get("type", "")) == "talk":
				assert_true(DB.dialogue.has(String(goal["npc"])), "%s talks to %s" % [id, goal["npc"]])
			if String(goal.get("type", "")) == "kill" and goal.has("enemy"):
				assert_true(DB.enemies.has(String(goal["enemy"])), "%s kills %s" % [id, goal["enemy"]])


func test_every_zone_has_a_mood_and_every_flock_a_model() -> void:
	var atmosphere := DB.load_json("res://data/atmosphere.json") as Dictionary
	var moods := atmosphere["moods"] as Dictionary
	assert_true(moods.has(String(atmosphere["start"])), "the starting mood")
	var layout := DB.load_json("res://data/level/elaion_layout.json") as Dictionary
	for entry: Variant in layout["items"] as Array:
		var item := entry as Dictionary
		match String(item["type"]):
			"zone":
				assert_true(moods.has(String(item.get("mood", ""))), "mood of %s" % item["name"])
			"birds":
				var species := String(item.get("species", ""))
				assert_true(ResourceLoader.exists("res://assets/models/characters/%s/%s.glb" % [species, species]), "model of %s" % species)


func test_core_sounds_exist() -> void:
	for sound: StringName in [&"swing", &"hit", &"level_up", &"bull_roar", &"village", &"boss", &"shore"]:
		assert_not_null(Sfx.stream(sound), String(sound))
