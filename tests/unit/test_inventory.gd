extends GutTest
## The bag: sized items, finding room, overlaps.


func test_items_fill_columns_first() -> void:
	var bag := Inventory.new(10, 6)
	var spear := Item.create(&"dory")
	assert_true(bag.add(spear))
	assert_eq(bag.position_of(spear), Vector2i(0, 0))
	var sword := Item.create(&"xiphos")
	assert_true(bag.add(sword))
	assert_eq(bag.position_of(sword), Vector2i(1, 0))


func test_cannot_overlap_or_leave_the_grid() -> void:
	var bag := Inventory.new(4, 4)
	var shield := Item.create(&"aspis")
	assert_true(bag.place(shield, Vector2i(0, 0)))
	assert_false(bag.can_place(Item.create(&"helm_pilos"), Vector2i(1, 1)))
	assert_false(bag.can_place(Item.create(&"helm_pilos"), Vector2i(3, 3)))
	assert_true(bag.can_place(Item.create(&"helm_pilos"), Vector2i(2, 2)))
	assert_eq(bag.item_at(Vector2i(1, 1)), shield)


func test_full_bag_refuses() -> void:
	var bag := Inventory.new(2, 2)
	assert_true(bag.add(Item.create(&"aspis")))
	assert_false(bag.add(Item.create(&"bronze_ring")))


func test_overlapping_reports_the_item_to_swap() -> void:
	var bag := Inventory.new(6, 6)
	var helm := Item.create(&"helm_corinthian")
	bag.place(helm, Vector2i(2, 2))
	var found := bag.overlapping(Item.create(&"aspis"), Vector2i(1, 1))
	assert_eq(found.size(), 1)
	assert_eq(found[0], helm)
