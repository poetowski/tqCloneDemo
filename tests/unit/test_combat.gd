extends GutTest
## Taking damage: armour softens physical blows, a sever kills outright.


func _target(health: float, armor: float) -> Actor:
	var actor := Actor.new()
	actor.stats.set_bases({Stats.MAX_HEALTH: health, Stats.ARMOR: armor})
	actor.health = health
	return actor


func test_armour_softens_physical_damage() -> void:
	var actor := _target(100.0, 100.0)
	var info := DamageInfo.make(null, 40.0)
	actor.take_damage(info)
	assert_almost_eq(info.final_amount, 20.0, 0.001)
	assert_almost_eq(actor.health, 80.0, 0.001)
	actor.free()


func test_fire_ignores_armour() -> void:
	var actor := _target(100.0, 100.0)
	actor.take_damage(DamageInfo.make(null, 30.0, DamageInfo.Kind.FIRE))
	assert_almost_eq(actor.health, 70.0, 0.001)
	actor.free()


func test_sever_kills_outright() -> void:
	var actor := _target(100.0, 0.0)
	var info := DamageInfo.make(null, 1.0)
	info.is_sever = true
	actor.take_damage(info)
	assert_true(actor.is_dead)
	actor.free()


func test_xp_curve_rises() -> void:
	assert_eq(Game.xp_to_next(1), 45)
	assert_gt(Game.xp_to_next(5), Game.xp_to_next(4))


## A hero who clears Elaion earns about level 7 before the bull (docs/GAME_DESIGN.md).
func test_xp_curve_reaches_level_seven_by_the_bull() -> void:
	var to_seven := 0
	for level in range(1, 7):
		to_seven += Game.xp_to_next(level)
	assert_between(to_seven, 1700, 2300)
