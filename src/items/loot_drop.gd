class_name LootDrop
extends RefCounted
## Spills loot from a dying foe, a smashed pot or an opened chest onto the ground.


static func drop_for(enemy: Enemy) -> void:
	var table := String(enemy.def.get("loot", "trash"))
	if enemy.is_champion:
		table = "champion"
	spill(table, enemy.level, enemy.global_position)


static func spill(table: String, level: int, at: Vector3) -> void:
	var magic_find := 0.0
	if Game.player:
		magic_find = Game.player.stats.value(Stats.MAGIC_FIND) - 100.0
	var result := Loot.roll_table(table, level, magic_find, Game.rng)
	var items := result["items"] as Array
	var total := items.size() + (1 if int(result["gold"]) > 0 else 0)
	var index := 0
	for item: Variant in items:
		GroundItem.spawn(item as Item, _scatter(at, index, total), at)
		index += 1
	if int(result["gold"]) > 0:
		GroundItem.spawn(null, _scatter(at, index, total), at, int(result["gold"]))


static func _scatter(center: Vector3, index: int, total: int) -> Vector3:
	if total <= 1:
		return center + Vector3(randf_range(-0.6, 0.6), 0.0, randf_range(-0.6, 0.6))
	var angle := TAU * float(index) / float(total) + randf() * 0.5
	var distance := 1.0 + randf() * 0.9
	return center + Vector3(cos(angle), 0.0, sin(angle)) * distance
