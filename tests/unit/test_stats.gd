extends GutTest
## Stats: base + flat modifiers, then percent; sources replace each other; derive.


func test_flat_then_percent() -> void:
	var stats := Stats.new()
	stats.set_base(Stats.ARMOR, 10.0)
	stats.set_source(&"eq_chest", [Stats.mod(Stats.ARMOR, 20.0), Stats.mod(Stats.ARMOR, 0.0, 50.0)])
	assert_almost_eq(stats.value(Stats.ARMOR), 45.0, 0.001)


func test_source_replaces_and_clears() -> void:
	var stats := Stats.new()
	stats.set_source(&"buff", [Stats.mod(Stats.DAMAGE_PCT, 25.0)])
	stats.set_source(&"buff", [Stats.mod(Stats.DAMAGE_PCT, 10.0)])
	assert_almost_eq(stats.value(Stats.DAMAGE_PCT), 10.0, 0.001)
	stats.clear_source(&"buff")
	assert_almost_eq(stats.value(Stats.DAMAGE_PCT), 0.0, 0.001)
	assert_false(stats.has_source(&"buff"))


func test_derive_adds_before_percent() -> void:
	var stats := Stats.new()
	var might := [10.0]
	stats.derive = func(stat: StringName) -> float: return float(might[0]) * 2.0 if stat == Stats.MAX_HEALTH else 0.0
	stats.set_base(Stats.MAX_HEALTH, 80.0)
	stats.set_source(&"gear", [Stats.mod(Stats.MAX_HEALTH, 0.0, 10.0)])
	assert_almost_eq(stats.value(Stats.MAX_HEALTH), 110.0, 0.001)
	might[0] = 20.0
	stats.refresh()
	assert_almost_eq(stats.value(Stats.MAX_HEALTH), 132.0, 0.001)
