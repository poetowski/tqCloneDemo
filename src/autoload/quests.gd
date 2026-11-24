extends Node
## The quest log (data/quests.json): which stage each quest is at, counting kills
## and pickups, handing out rewards and starting the next quest.

signal completed(quest_id: StringName)

## quest id -> {"stage": int, "count": int, "done": bool}
var state: Dictionary = {}


func _ready() -> void:
	Events.actor_died.connect(_on_actor_died)
	Events.item_picked_up.connect(_on_item_picked_up)


func reset() -> void:
	state.clear()


func start(id: StringName) -> void:
	if state.has(id) or not DB.quests.has(String(id)):
		return
	state[id] = {"stage": 0, "count": 0, "done": false}
	var data := DB.quests[String(id)] as Dictionary
	Events.notified.emit("New quest: %s" % String(data["title"]), UIStyle.GOLD_BRIGHT)
	Sfx.play(&"quest")
	Events.quest_updated.emit(id)
	_settle(id)


## Moves past stages the world has already satisfied (Lykos killed before the quest
## asked for him, the seal already in the bag, the gate already open).
func _settle(id: StringName) -> void:
	var guard := 0
	while is_active(id) and guard < 8:
		guard += 1
		var g := goal(id)
		var met := false
		match String(g.get("type", "")):
			"kill":
				met = g.has("enemy") and Game.flag("killed_" + String(g["enemy"]))
			"flag":
				met = Game.flag(String(g.get("flag", "")))
			"item":
				met = Game.player != null and Game.player.inventory.items().any(
					func(it: Variant) -> bool: return String((it as Item).base_id) == String(g.get("item", "")))
		if not met:
			return
		advance(id)


func is_active(id: StringName) -> bool:
	return state.has(id) and not bool((state[id] as Dictionary)["done"])


func is_done(id: StringName) -> bool:
	return state.has(id) and bool((state[id] as Dictionary)["done"])


func stage(id: StringName) -> int:
	return int((state[id] as Dictionary)["stage"]) if state.has(id) else -1


func goal(id: StringName) -> Dictionary:
	if not is_active(id):
		return {}
	var stages := (DB.quests[String(id)] as Dictionary)["stages"] as Array
	return (stages[stage(id)] as Dictionary).get("goal", {}) as Dictionary


## Finishes the current stage of `id` (talking, a flag) and moves on.
func advance(id: StringName) -> void:
	if not is_active(id):
		return
	var data := DB.quests[String(id)] as Dictionary
	var stages := data["stages"] as Array
	var entry := state[id] as Dictionary
	var finished := stages[int(entry["stage"])] as Dictionary
	_reward(finished.get("reward", {}) as Dictionary)
	entry["stage"] = int(entry["stage"]) + 1
	entry["count"] = 0
	if int(entry["stage"]) >= stages.size():
		entry["done"] = true
		Events.notified.emit("Quest complete: %s" % String(data["title"]), UIStyle.GOLD_BRIGHT)
		Sfx.play(&"quest_done")
		completed.emit(id)
		if data.has("next"):
			start(StringName(String(data["next"])))
	else:
		Sfx.play(&"quest")
	Events.quest_updated.emit(id)


## Talking to an NPC: advances any quest whose stage waits for that NPC.
func talked_to(npc: String) -> void:
	for id: Variant in state.keys():
		var g := goal(id as StringName)
		if String(g.get("type", "")) == "talk" and String(g.get("npc", "")) == npc:
			advance(id as StringName)
			return


func flag_set(flag_name: String) -> void:
	for id: Variant in state.keys():
		var g := goal(id as StringName)
		if String(g.get("type", "")) == "flag" and String(g.get("flag", "")) == flag_name:
			advance(id as StringName)


func _on_actor_died(actor: Node3D, _killer: Node3D) -> void:
	var enemy := actor as Enemy
	if enemy == null or enemy.is_ally:
		return
	var tags := enemy.def.get("tags", []) as Array
	for id: Variant in state.keys():
		var g := goal(id as StringName)
		if String(g.get("type", "")) != "kill":
			continue
		var matches := (g.has("tag") and String(g["tag"]) in tags) or (g.has("enemy") and String(g["enemy"]) == String(enemy.id))
		if not matches:
			continue
		var entry := state[id] as Dictionary
		entry["count"] = int(entry["count"]) + 1
		if int(entry["count"]) >= int(g.get("count", 1)):
			advance(id as StringName)
		else:
			Events.quest_updated.emit(id as StringName)


func _on_item_picked_up(item: RefCounted) -> void:
	var it := item as Item
	if it == null:
		return
	for id: Variant in state.keys():
		var g := goal(id as StringName)
		if String(g.get("type", "")) == "item" and String(g.get("item", "")) == String(it.base_id):
			advance(id as StringName)


func _reward(reward: Dictionary) -> void:
	if reward.is_empty() or Game.player == null:
		return
	if reward.has("xp"):
		Game.player.gain_xp(int(reward["xp"]))
	if reward.has("unique"):
		var item := Item.create_unique(StringName(String(reward["unique"])))
		if not Game.player.pick_up(item):
			GroundItem.spawn(item, Game.player.global_position + Vector3(1, 0, 0), Game.player.global_position)
		Events.notified.emit("Received: %s" % item.display_name(), item.color())


## Lines for the HUD's tracker: [{"text", "color", "size"}].
func tracker_lines() -> Array:
	var lines: Array = []
	for id: Variant in state.keys():
		if not is_active(id as StringName):
			continue
		var data := DB.quests[String(id)] as Dictionary
		var stages := data["stages"] as Array
		var entry := state[id] as Dictionary
		var current := stages[int(entry["stage"])] as Dictionary
		var text := String(current["text"])
		var g := current.get("goal", {}) as Dictionary
		if String(g.get("type", "")) == "kill" and int(g.get("count", 1)) > 1:
			text += " (%d/%d)" % [int(entry["count"]), int(g["count"])]
		lines.append({"text": String(data["title"]), "color": UIStyle.GOLD, "size": 17})
		lines.append({"text": "• " + text, "color": UIStyle.BONE, "size": 15})
	return lines
