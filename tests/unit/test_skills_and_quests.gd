extends GutTest
## The Loom (ranks, unlocks, parameters) and the quest log.


func test_learning_spends_points_and_respects_unlocks() -> void:
	var book := SkillBook.new()
	book.points = 2
	assert_false(book.can_learn(&"bound_shades", 1), "Bound Shades unlocks at level 5")
	assert_true(book.learn(&"lunge", 1))
	assert_eq(book.rank(&"lunge"), 1)
	assert_eq(book.points, 1)
	assert_true(book.can_learn(&"bound_shades", 5))


func test_parameters_grow_per_rank() -> void:
	var book := SkillBook.new()
	book.grant(&"lunge")
	assert_almost_eq(book.param(&"lunge", "distance"), 6.0, 0.001)
	assert_almost_eq(book.param(&"lunge", "distance", 3), 7.0, 0.001)
	assert_almost_eq(book.cooldown(&"lunge"), 3.0, 0.001)
	assert_string_contains(book.describe(&"lunge"), "130%")


func test_weaver_quest_counts_unthreaded_kills() -> void:
	Quests.reset()
	Quests.start(&"weaver")
	assert_eq(Quests.stage(&"weaver"), 0)
	Quests.talked_to("klotho")
	assert_eq(Quests.stage(&"weaver"), 1)
	var shade := Enemy.new()
	shade.def = {"tags": ["unthreaded"]}
	shade.id = &"shade_hoplite"
	for i in 10:
		Events.actor_died.emit(shade, null)
	assert_eq(Quests.stage(&"weaver"), 2)
	shade.free()
	Quests.reset()


func test_beasts_do_not_count_for_the_weaver() -> void:
	Quests.reset()
	Quests.start(&"weaver")
	Quests.talked_to("klotho")
	var boar := Enemy.new()
	boar.def = {"tags": ["beast"]}
	boar.id = &"styx_boar"
	Events.actor_died.emit(boar, null)
	assert_eq(int((Quests.state[&"weaver"] as Dictionary)["count"]), 0)
	boar.free()
	Quests.reset()
