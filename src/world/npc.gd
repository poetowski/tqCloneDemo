class_name NPC
extends Node3D
## A person of Elaion (data/dialogue.json): stands at their post doing their idle
## work, shows a gold mark when they have something new to say, and talks through
## the dialogue panel. What they say follows the quests.

const MODELS := {"klotho": "res://assets/models/characters/klotho/klotho.glb", "dion": "res://assets/models/characters/dion/dion.glb"}

@export var npc_id := "klotho"

var interact_range := 2.4
var body: ActorBody
var _mark: Label3D
var _name_label: Label3D
var _lines: Dictionary = {}
var _talked: Dictionary = {}
var _idle := &"idle"


func _ready() -> void:
	add_to_group(&"interactable")
	add_to_group(&"npcs")
	_lines = DB.dialogue.get(npc_id, {}) as Dictionary
	body = ActorBody.new()
	add_child(body)
	body.setup(load(String(MODELS[npc_id])) as PackedScene)
	_idle = &"weave" if npc_id == "klotho" else &"idle"
	body.play(_idle, 0.0)
	var area := Area3D.new()
	area.collision_layer = Actor.LAYER_INTERACT
	area.collision_mask = 0
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.5
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	area.add_child(shape)
	add_child(area)
	var blocker := StaticBody3D.new()
	blocker.collision_layer = Actor.LAYER_WORLD
	var blocker_shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.35
	cylinder.height = 1.6
	blocker_shape.shape = cylinder
	blocker_shape.position.y = 0.8
	blocker.add_child(blocker_shape)
	add_child(blocker)
	_name_label = _label(String(_lines.get("name", npc_id)), 22, UIStyle.BONE, 2.0)
	_mark = _label("!", 64, UIStyle.GOLD_BRIGHT, 2.9)
	Events.quest_updated.connect(func(_id: StringName) -> void: _refresh_mark())
	_refresh_mark.call_deferred()


func _label(text: String, font_size: int, color: Color, height: float) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = font_size
	l.outline_size = 10
	l.modulate = color
	l.outline_modulate = Color(0.05, 0.03, 0.02)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = true
	l.pixel_size = 0.0012
	l.position = Vector3.UP * height
	add_child(l)
	return l


func _process(delta: float) -> void:
	if _mark.visible:
		_mark.position.y = 2.9 + sin(Time.get_ticks_msec() / 300.0) * 0.08
	if Game.player:
		_name_label.visible = Game.player.hovered == self or global_position.distance_to(Game.player.global_position) < 7.0


func _has_news() -> bool:
	if npc_id == "klotho":
		var weaver := Quests.stage(&"weaver")
		if weaver == 0 or weaver == 2:
			return true
		if Quests.is_done(&"bronze_heart") and not _talked.has("done"):
			return true
		return false
	return not _talked.has("intro") or (Quests.is_done(&"bronze_heart") and not _talked.has("after_bull"))


func _refresh_mark() -> void:
	_mark.visible = _has_news()


func interact(player: Player) -> void:
	player.halt()
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	if to_player.length() > 0.1:
		look_at(global_position + to_player, Vector3.UP, true)
	body.play(&"talk", 0.2)
	Sfx.play(&"talk")
	match npc_id:
		"klotho":
			_klotho()
		"dion":
			_dion()


func _say(key: String, options: Array) -> void:
	_talked[key] = true
	var panel := Game.hud.panels.get(&"dialogue") as DialoguePanel
	panel.open(String(_lines.get("name", "")), String(_lines.get(key, "...")), options)
	_refresh_mark()


func _close() -> void:
	(Game.hud.panels.get(&"dialogue") as DialoguePanel).close()
	body.play(_idle, 0.3)


func _klotho() -> void:
	var stage := Quests.stage(&"weaver")
	if stage == 0:
		_say("intro", [["Who are you?", _klotho_topic.bind("who")], ["What happened to me?", _klotho_topic.bind("what")],
			["Tell me of the Unthreaded.", _klotho_topic.bind("unthreaded")], ["What would you have me do?", _klotho_task]])
	elif stage == 1:
		_say("progress", [["I'm going.", _close]])
	elif stage == 2:
		Quests.talked_to("klotho")
		_say("reward", [["Where is the necropolis?", func() -> void: _say("lykos", [["Farewell.", _close]])], ["Farewell.", _close]])
	elif Quests.is_active(&"dead_walk"):
		_say("lykos", [["Farewell.", _close]])
	elif Quests.is_active(&"bronze_heart"):
		_say("bull", [["Farewell.", _close]])
	elif Quests.is_done(&"bronze_heart"):
		_say("done", [["Farewell, Spinner.", _close]])
	else:
		_say("progress", [["Farewell.", _close]])


func _klotho_topic(topic: String) -> void:
	_say(topic, [["What would you have me do?", _klotho_task], ["Tell me more.", _klotho]])


func _klotho_task() -> void:
	if Quests.stage(&"weaver") == 0:
		Quests.talked_to("klotho")
	_say("task", [["I'll cut them.", _close]])


func _dion() -> void:
	if Quests.is_done(&"bronze_heart"):
		_say("after_bull", [["Farewell.", _close]])
		return
	if not _talked.has("intro"):
		_say("intro", [["What happened to your brother?", func() -> void: _say("brother", [["...", _dion_gift]])], ["I have to go.", _dion_gift]])
		return
	_say("later", [["Farewell.", _close]])


func _dion_gift() -> void:
	if not Game.flag("dion_gift") and Game.player:
		Game.set_flag("dion_gift")
		Game.player.belt[&"potion_health"] = mini(Player.BELT_MAX, int(Game.player.belt.get(&"potion_health", 0)) + 2)
		Game.player.belt_changed.emit()
		Events.notified.emit("Dion gives you two Healing Draughts.", UIStyle.GOLD)
		_say("gift", [["Thank you.", _close]])
	else:
		_close()
