class_name MapMarkers
extends RefCounted
## What the minimap and the full map show, and how each mark is drawn: the next goal
## of every active quest (gold), the hearths (fire, dim until lit), the people
## (bone white), the sanctuary gate (bronze) and the boss (red-orange, the enemy's
## colour). Quest goals are found from the stage: a `marker` in data/quests.json if
## it names one (a zone or a node), else from its goal (who to talk to, what to kill,
## what to pick up).

enum Kind { OBJECTIVE, HEARTH, HEARTH_LIT, PERSON, GATE, BOSS }


## Every mark in the level: [{"kind": Kind, "position": Vector3, "label": String}].
static func collect(tree: SceneTree) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for node in tree.get_nodes_in_group(&"shrines"):
		var hearth := node as Node3D
		out.append({"kind": Kind.HEARTH_LIT if bool(hearth.get(&"lit")) else Kind.HEARTH, "position": hearth.global_position,
			"label": "Hearth of Hestia"})
	for node in tree.get_nodes_in_group(&"npcs"):
		var person := node as Node3D
		var lines := DB.dialogue.get(String(person.get(&"npc_id")), {}) as Dictionary
		out.append({"kind": Kind.PERSON, "position": person.global_position, "label": String(lines.get("name", ""))})
	if Game.level:
		var gate := Game.level.find_child("SanctuaryGate", true, false) as Node3D
		if gate:
			out.append({"kind": Kind.GATE, "position": gate.global_position, "label": "Sanctuary gate"})
		# (The level's reference may outlive the boss: check before casting.)
		var boss_ref: Variant = Game.level.get(&"boss")
		if boss_ref != null and is_instance_valid(boss_ref):
			var boss := boss_ref as Actor
			if boss and not boss.is_dead:
				out.append({"kind": Kind.BOSS, "position": boss.global_position, "label": boss.display_name})
	out.append_array(objectives(tree))
	return out


## The next goal of each active quest, where it can be placed.
static func objectives(tree: SceneTree) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: Variant in DB.quests:
		var quest_id := StringName(String(id))
		if not Quests.is_active(quest_id):
			continue
		var stages := (DB.quests[id] as Dictionary)["stages"] as Array
		var stage := stages[Quests.stage(quest_id)] as Dictionary
		var at := _where(stage, tree)
		if at.is_finite():
			out.append({"kind": Kind.OBJECTIVE, "position": at, "label": String(stage.get("text", ""))})
	return out


static func _where(stage: Dictionary, tree: SceneTree) -> Vector3:
	var marker := stage.get("marker", {}) as Dictionary
	if marker.has("zone"):
		for node in tree.get_nodes_in_group(&"zones"):
			if String(node.get(&"zone_name")) == String(marker["zone"]):
				return (node as Node3D).global_position
	if marker.has("node") and Game.level:
		var named := Game.level.find_child(String(marker["node"]), true, false) as Node3D
		if named:
			return named.global_position
	var goal := stage.get("goal", {}) as Dictionary
	match String(goal.get("type", "")):
		"talk":
			for node in tree.get_nodes_in_group(&"npcs"):
				if String(node.get(&"npc_id")) == String(goal["npc"]):
					return (node as Node3D).global_position
		"kill":
			if goal.has("enemy"):
				for node in tree.get_nodes_in_group(&"enemy_team"):
					var foe := node as Enemy
					if foe and not foe.is_dead and String(foe.id) == String(goal["enemy"]):
						return foe.global_position
		"item":
			for node in tree.get_nodes_in_group(&"ground_items"):
				var ground := node as GroundItem
				if ground.item and String(ground.item.base_id) == String(goal["item"]):
					return ground.global_position
	return Vector3.INF


## Draws one mark centred at `at` on `canvas`; `size` is its radius in pixels and
## `t` the time, for the goal's pulse.
static func draw(canvas: CanvasItem, kind: int, at: Vector2, size: float, t: float) -> void:
	match kind:
		Kind.OBJECTIVE:
			var r := size * (1.15 + 0.15 * sin(t * 4.0))
			var diamond := PackedVector2Array([at + Vector2(0, -r), at + Vector2(r, 0), at + Vector2(0, r), at + Vector2(-r, 0)])
			canvas.draw_colored_polygon(diamond, UIStyle.GOLD_BRIGHT)
			diamond.append(diamond[0])
			canvas.draw_polyline(diamond, UIStyle.OUTLINE, 2.0)
			canvas.draw_circle(at, r * 0.3, UIStyle.OUTLINE)
		Kind.HEARTH, Kind.HEARTH_LIT:
			var lit := kind == Kind.HEARTH_LIT
			var flame := PackedVector2Array([at + Vector2(0, -size * 1.2), at + Vector2(size * 0.8, size * 0.6), at + Vector2(-size * 0.8, size * 0.6)])
			canvas.draw_colored_polygon(flame, Color("#FF8A2A") if lit else Color("#8A6A4A"))
			canvas.draw_circle(at + Vector2(0, size * 0.15), size * 0.35, Color("#FFD27A") if lit else Color("#5A4A3A"))
			flame.append(flame[0])
			canvas.draw_polyline(flame, UIStyle.OUTLINE, 1.5)
		Kind.PERSON:
			canvas.draw_circle(at, size * 0.75, UIStyle.OUTLINE)
			canvas.draw_circle(at, size * 0.55, UIStyle.BONE)
		Kind.GATE:
			canvas.draw_rect(Rect2(at - Vector2(size, size) * 0.7, Vector2(size, size) * 1.4), UIStyle.OUTLINE)
			canvas.draw_rect(Rect2(at - Vector2(size, size) * 0.5, Vector2(size, size)), UIStyle.BRONZE)
		Kind.BOSS:
			canvas.draw_circle(at, size * 0.95, UIStyle.OUTLINE)
			canvas.draw_circle(at, size * 0.75, Color("#E0502A"))
			canvas.draw_circle(at + Vector2(-size * 0.25, -size * 0.1), size * 0.16, UIStyle.OUTLINE)
			canvas.draw_circle(at + Vector2(size * 0.25, -size * 0.1), size * 0.16, UIStyle.OUTLINE)


## The hero: a gold arrowhead pointing where they face (`facing`, a ground-plane
## direction: x east, y south).
static func draw_hero(canvas: CanvasItem, at: Vector2, facing: Vector2, size: float) -> void:
	var f := facing.normalized() if facing.length() > 0.01 else Vector2(0, -1)
	var side := Vector2(-f.y, f.x)
	var arrow := PackedVector2Array([at + f * size * 1.3, at - f * size * 0.8 + side * size * 0.85, at - f * size * 0.35,
		at - f * size * 0.8 - side * size * 0.85])
	canvas.draw_colored_polygon(arrow, UIStyle.GOLD_BRIGHT)
	arrow.append(arrow[0])
	canvas.draw_polyline(arrow, UIStyle.OUTLINE, 2.0)
