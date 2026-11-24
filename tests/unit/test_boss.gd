extends GutTest
## The bronze bull keeps to its arena: it chases the hero only as far as a step
## inside the ring of columns.

const CENTRE := Vector3(4.0, 20.0, -107.0)


func test_the_bulls_moves_are_tuned_in_data() -> void:
	var moves := DB.enemy(&"bronze_bull").get("moves", {}) as Dictionary
	for key: String in ["gore_knock", "trample_mult", "breath_tick", "breath_burn", "breath_turn", "mend_away", "mend_watched", "out_of_reach"]:
		assert_true(moves.has(key), "bronze_bull.moves.%s" % key)
	assert_lt(float(moves["mend_away"]), float(moves["mend_watched"]), "a fallen hero finds it still wounded; a sniper doesn't")


func test_points_inside_the_arena_stay_put() -> void:
	var inside := Vector3(8.0, 20.0, -100.0)
	assert_eq(BronzeBull.within_arena(inside, CENTRE, 15.0), inside)


func test_points_beyond_the_edge_come_back_a_step_inside() -> void:
	var gate := Vector3(10.0, 20.0, -79.0)
	var held := BronzeBull.within_arena(gate, CENTRE, 15.0)
	var offset := Vector2(held.x - CENTRE.x, held.z - CENTRE.z)
	assert_almost_eq(offset.length(), 14.0, 0.001)
	var toward := Vector2(gate.x - CENTRE.x, gate.z - CENTRE.z).normalized()
	assert_almost_eq(offset.normalized().dot(toward), 1.0, 0.0001, "it waits on the hero's side")
