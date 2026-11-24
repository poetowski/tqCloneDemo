class_name HUD
extends CanvasLayer
## The in-game interface: health and ichor orbs, the skill bar and belt, the XP
## thread, the hovered foe's frame, the boss bar, messages, area banners, the
## minimap with the quest tracker under it, and the panels (bag, hero, Loom, map,
## dialogue, pause).

const ORB := preload("res://src/shaders/orb.gdshader")
const ORB_SIZE := 172.0

var player: Player
var panels: Dictionary = {}

var _root: Control
var _health_orb: ColorRect
var _ichor_orb: ColorRect
var _health_text: Label
var _ichor_text: Label
var _xp_bar: UIBar
var _level_label: Label
var _target_box: Control
var _target_name: Label
var _target_bar: UIBar
var _target_info: Label
var _boss_box: Control
var _boss_name: Label
var _boss_bar: UIBar
var _boss: Actor
var _messages: VBoxContainer
var _banner: Label
var _banner_sub: Label
var _quest_box: VBoxContainer
var _points_button_c: Button
var _points_button_k: Button
var _buff_label: Label
var _death_veil: ColorRect
var _death_text: Label


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.hud = self
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var numbers := FloatingNumbers.new()
	_root.add_child(numbers)
	_build_orbs()
	_build_bar()
	_build_target()
	_build_boss()
	_build_messages()
	_build_minimap()
	_build_quests()
	_build_death()
	Events.notified.connect(notify)
	Events.area_entered.connect(show_banner)
	Events.boss_engaged.connect(_on_boss_engaged)
	Events.boss_defeated.connect(_on_boss_defeated)
	Events.boss_reset.connect(_on_boss_defeated)
	Events.player_died.connect(_on_player_died)
	Events.player_respawned.connect(_on_player_respawned)
	Events.quest_updated.connect(func(_id: StringName) -> void: refresh_quests())


func bind_player(p: Player) -> void:
	player = p
	player.health_changed.connect(_on_health)
	player.ichor_changed.connect(_on_ichor)
	player.xp_changed.connect(_on_xp)
	player.leveled_up.connect(func(_l: int) -> void: _refresh_points())
	player.hover_changed.connect(_on_hover)
	player.attributes_changed.connect(_refresh_points)
	player.skills.changed.connect(_refresh_points)
	for slot: Variant in _bar_slots:
		(slot as SkillSlot).player = player
	_on_health(player.health, player.max_health())
	_on_ichor(player.ichor, player.max_ichor())
	_on_xp(player.xp, Game.xp_to_next(player.level), player.level)
	_refresh_points()
	for panel_name: Variant in panels:
		if (panels[panel_name] as Node).has_method(&"bind_player"):
			(panels[panel_name] as Node).call(&"bind_player", player)


func add_panel(panel_name: StringName, panel: Control) -> void:
	panels[panel_name] = panel
	_root.add_child(panel)
	panel.visible = false
	if player and panel.has_method(&"bind_player"):
		panel.call(&"bind_player", player)


func toggle_panel(panel_name: StringName) -> void:
	var panel := panels.get(panel_name) as Control
	if panel == null:
		return
	panel.visible = not panel.visible
	if panel.visible and panel.has_method(&"refresh"):
		panel.call(&"refresh")
	Sfx.play(&"ui_open" if panel.visible else &"ui_close")


func any_panel_open() -> bool:
	for p: Variant in panels.values():
		if (p as Control).visible:
			return true
	return false


func close_panels() -> bool:
	var closed := false
	for p: Variant in panels.values():
		if (p as Control).visible:
			(p as Control).visible = false
			closed = true
	return closed


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"inventory"):
		toggle_panel(&"inventory")
	elif event.is_action_pressed(&"character"):
		toggle_panel(&"character")
	elif event.is_action_pressed(&"skills_panel"):
		toggle_panel(&"loom")
	elif event.is_action_pressed(&"map_toggle"):
		toggle_panel(&"map")
	elif event.is_action_pressed(&"pause"):
		if not close_panels():
			toggle_panel(&"pause")
	else:
		return
	get_viewport().set_input_as_handled()


# --- layout helpers ------------------------------------------------------------

static func anchor(c: Control, ax: float, ay: float, pos: Vector2, size: Vector2) -> void:
	c.anchor_left = ax
	c.anchor_right = ax
	c.anchor_top = ay
	c.anchor_bottom = ay
	c.offset_left = pos.x
	c.offset_top = pos.y
	c.offset_right = pos.x + size.x
	c.offset_bottom = pos.y + size.y


# --- orbs ------------------------------------------------------------------------

func _orb(dark: Color, light: Color) -> ColorRect:
	var rect := ColorRect.new()
	var material := ShaderMaterial.new()
	material.shader = ORB
	material.set_shader_parameter(&"liquid_dark", dark)
	material.set_shader_parameter(&"liquid_light", light)
	rect.material = material
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(rect)
	return rect


func _build_orbs() -> void:
	_health_orb = _orb(Color(0.36, 0.03, 0.04), Color(0.9, 0.22, 0.16))
	anchor(_health_orb, 0.0, 1.0, Vector2(28, -ORB_SIZE - 22), Vector2(ORB_SIZE, ORB_SIZE))
	_ichor_orb = _orb(Color(0.5, 0.3, 0.04), Color(1.0, 0.84, 0.36))
	anchor(_ichor_orb, 1.0, 1.0, Vector2(-ORB_SIZE - 28, -ORB_SIZE - 22), Vector2(ORB_SIZE, ORB_SIZE))
	_health_text = UIStyle.label("", 17)
	_health_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	anchor(_health_text, 0.0, 1.0, Vector2(28, -ORB_SIZE - 52), Vector2(ORB_SIZE, 28))
	_root.add_child(_health_text)
	_ichor_text = UIStyle.label("", 17)
	_ichor_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	anchor(_ichor_text, 1.0, 1.0, Vector2(-ORB_SIZE - 28, -ORB_SIZE - 52), Vector2(ORB_SIZE, 28))
	_root.add_child(_ichor_text)


func _on_health(current: float, maximum: float) -> void:
	(_health_orb.material as ShaderMaterial).set_shader_parameter(&"fill", clampf(current / maximum, 0.0, 1.0))
	_health_text.text = "%d / %d" % [ceili(current), int(maximum)]


func _on_ichor(current: float, maximum: float) -> void:
	(_ichor_orb.material as ShaderMaterial).set_shader_parameter(&"fill", clampf(current / maximum, 0.0, 1.0))
	_ichor_text.text = "%d / %d" % [int(current), int(maximum)]


# --- the bar ---------------------------------------------------------------------

var _bar_slots: Array = []


func _build_bar() -> void:
	var holder := PanelContainer.new()
	holder.add_theme_stylebox_override(&"panel", UIStyle.panel(Color(0.45, 0.3, 0.18), Color(0.08, 0.06, 0.05, 0.86), 2, 8))
	var width := 7 * 64 + 6 * 8 + 28 + 24
	anchor(holder, 0.5, 1.0, Vector2(-width * 0.5, -112), Vector2(width, 86))
	_root.add_child(holder)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	holder.add_child(row)
	var keys := ["RMB", "Q", "W", "E", "R"]
	for i in 5:
		var slot := SkillSlot.new()
		slot.setup(null, keys[i], SkillCaster.skill_in_slot(i + 1))
		row.add_child(slot)
		_bar_slots.append(slot)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(20, 1)
	row.add_child(gap)
	for entry: Array in [["1", &"potion_health"], ["2", &"potion_ichor"]]:
		var slot := SkillSlot.new()
		slot.setup(null, String(entry[0]), &"", entry[1] as StringName)
		row.add_child(slot)
		_bar_slots.append(slot)
	_xp_bar = UIBar.new()
	_xp_bar.fill_color = Color("#E2B04A")
	_xp_bar.frame_color = Color("#4E3826")
	_xp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor(_xp_bar, 0.5, 1.0, Vector2(-380, -20), Vector2(760, 10))
	_root.add_child(_xp_bar)
	_level_label = UIStyle.label("Level 1", 16, UIStyle.GOLD)
	anchor(_level_label, 0.5, 1.0, Vector2(-470, -26), Vector2(84, 22))
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_root.add_child(_level_label)
	_buff_label = UIStyle.label("", 15, Color(1.0, 0.55, 0.3))
	_buff_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	anchor(_buff_label, 0.5, 1.0, Vector2(-200, -142), Vector2(400, 24))
	_root.add_child(_buff_label)
	_points_button_c = UIStyle.button("+ Attributes (C)", 15)
	anchor(_points_button_c, 0.5, 1.0, Vector2(width * 0.5 + 16, -110), Vector2(170, 36))
	_points_button_c.pressed.connect(toggle_panel.bind(&"character"))
	_root.add_child(_points_button_c)
	_points_button_k = UIStyle.button("+ Loom (K)", 15)
	anchor(_points_button_k, 0.5, 1.0, Vector2(width * 0.5 + 16, -68), Vector2(170, 36))
	_points_button_k.pressed.connect(toggle_panel.bind(&"loom"))
	_root.add_child(_points_button_k)


func _on_xp(current: int, needed: int, at_level: int) -> void:
	_xp_bar.set_value(float(current) / float(maxi(1, needed)), true)
	_level_label.text = "Level %d" % at_level


func _refresh_points() -> void:
	if player == null:
		return
	_points_button_c.visible = player.attribute_points > 0
	_points_button_c.text = "+%d Attributes (C)" % player.attribute_points
	_points_button_k.visible = player.skills.points > 0
	_points_button_k.text = "+%d Loom (K)" % player.skills.points


func _process(_delta: float) -> void:
	if player == null:
		return
	var war := player.caster.buff_left(&"buff_war_cry")
	_buff_label.text = ("War Cry of Ares  %.0f s" % war) if war > 0.0 else ""
	if _target_box.visible and _hovered_actor and is_instance_valid(_hovered_actor):
		_target_bar.set_value(_hovered_actor.health_ratio())
		if _hovered_actor.is_dead:
			_target_box.visible = false
	if _boss and is_instance_valid(_boss):
		_boss_bar.set_value(_boss.health_ratio())


# --- target and boss ---------------------------------------------------------------

var _hovered_actor: Actor


func _build_target() -> void:
	_target_box = PanelContainer.new()
	_target_box.add_theme_stylebox_override(&"panel", UIStyle.panel(Color(0.4, 0.27, 0.17), Color(0.08, 0.06, 0.05, 0.85), 2, 6))
	anchor(_target_box, 0.5, 0.0, Vector2(-220, 18), Vector2(440, 70))
	_target_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_target_box)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 4)
	_target_box.add_child(column)
	_target_name = UIStyle.label("", 18)
	_target_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_target_name)
	_target_bar = UIBar.new()
	_target_bar.custom_minimum_size = Vector2(400, 12)
	column.add_child(_target_bar)
	_target_info = UIStyle.label("", 13, UIStyle.MUTED)
	_target_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_target_info)
	_target_box.visible = false


func _on_hover(target: Node3D) -> void:
	_hovered_actor = target as Actor
	if _hovered_actor and not _hovered_actor.is_dead and _hovered_actor != _boss:
		_target_box.visible = true
		var enemy := _hovered_actor as Enemy
		var color := UIStyle.BONE
		var info := "Level %d" % _hovered_actor.level
		if enemy:
			if enemy.is_ally:
				color = UIStyle.GOLD
				info = "Bound to you"
			elif enemy.is_champion:
				color = Color("#9FE3DA")
				info += " · Champion"
			elif bool(enemy.def.get("unique", false)):
				color = UIStyle.GOLD_BRIGHT
				info += " · Hero of the dead"
			if "unthreaded" in (enemy.def.get("tags", []) as Array) and not enemy.is_ally:
				info += " · Unthreaded"
		_target_name.text = _hovered_actor.display_name
		_target_name.add_theme_color_override(&"font_color", color)
		_target_info.text = info
		_target_bar.set_value(_hovered_actor.health_ratio(), true)
	else:
		_target_box.visible = false


func _build_boss() -> void:
	_boss_box = VBoxContainer.new()
	anchor(_boss_box, 0.5, 0.0, Vector2(-400, 96), Vector2(800, 60))
	_boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_boss_box)
	_boss_name = UIStyle.label("", 24, UIStyle.GOLD_BRIGHT, 7)
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_box.add_child(_boss_name)
	_boss_bar = UIBar.new()
	_boss_bar.custom_minimum_size = Vector2(800, 18)
	_boss_bar.fill_color = Color("#B4643C")
	_boss_bar.frame_color = UIStyle.GOLD
	_boss_box.add_child(_boss_bar)
	_boss_box.visible = false


func _on_boss_engaged(boss: Node3D) -> void:
	_boss = boss as Actor
	_boss_name.text = _boss.display_name
	_boss_bar.set_value(_boss.health_ratio(), true)
	_boss_box.visible = true


func _on_boss_defeated(_boss_node: Node3D) -> void:
	_boss_box.visible = false
	_boss = null


# --- messages, banners, quests ---------------------------------------------------------

func _build_messages() -> void:
	_messages = VBoxContainer.new()
	_messages.alignment = BoxContainer.ALIGNMENT_END
	anchor(_messages, 0.5, 0.0, Vector2(-450, 170), Vector2(900, 160))
	_messages.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_messages)
	_banner = UIStyle.label("", 46, UIStyle.GOLD_BRIGHT, 9)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	anchor(_banner, 0.5, 0.0, Vector2(-600, 330), Vector2(1200, 64))
	_banner.modulate.a = 0.0
	_root.add_child(_banner)
	_banner_sub = UIStyle.label("", 20, UIStyle.BONE, 6)
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	anchor(_banner_sub, 0.5, 0.0, Vector2(-600, 394), Vector2(1200, 30))
	_banner_sub.modulate.a = 0.0
	_root.add_child(_banner_sub)


func notify(text: String, color: Color = UIStyle.BONE) -> void:
	var l := UIStyle.label(text, 20, color, 6)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_messages.add_child(l)
	while _messages.get_child_count() > 4:
		_messages.get_child(0).queue_free()
		_messages.remove_child(_messages.get_child(0))
	var tween := l.create_tween()
	tween.tween_interval(3.2)
	tween.tween_property(l, "modulate:a", 0.0, 0.8)
	tween.tween_callback(l.queue_free)


## A place name fading in and out, like a chapter heading.
func show_banner(title: String, subtitle: String = "") -> void:
	_banner.text = title
	_banner_sub.text = subtitle
	for l: Label in [_banner, _banner_sub]:
		var tween := l.create_tween()
		tween.tween_property(l, "modulate:a", 1.0, 0.8)
		tween.tween_interval(2.6)
		tween.tween_property(l, "modulate:a", 0.0, 1.2)
	Sfx.play(&"banner")


func _build_minimap() -> void:
	var minimap := Minimap.new()
	var side := Minimap.RADIUS * 2.0 + 24.0
	anchor(minimap, 1.0, 0.0, Vector2(-side - 18, 12), Vector2(side, side))
	_root.add_child(minimap)


func _build_quests() -> void:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override(&"panel", UIStyle.panel(Color(0.35, 0.25, 0.16, 0.8), Color(0.06, 0.045, 0.04, 0.6), 1, 6))
	# Under the minimap (and its area name).
	anchor(box, 1.0, 0.0, Vector2(-430, Minimap.RADIUS * 2.0 + 74.0), Vector2(410, 10))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(box)
	_quest_box = VBoxContainer.new()
	_quest_box.add_theme_constant_override(&"separation", 2)
	box.add_child(_quest_box)
	refresh_quests()


func refresh_quests() -> void:
	if _quest_box == null:
		return
	for child in _quest_box.get_children():
		child.queue_free()
	var lines: Array = Quests.tracker_lines()
	_quest_box.get_parent().visible = not lines.is_empty()
	for line: Variant in lines:
		var entry := line as Dictionary
		var l := UIStyle.label(String(entry["text"]), int(entry.get("size", 16)), entry.get("color", UIStyle.BONE) as Color, 5)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(390, 0)
		_quest_box.add_child(l)


# --- death -------------------------------------------------------------------------------

func _build_death() -> void:
	_death_veil = ColorRect.new()
	_death_veil.color = Color(0.03, 0.02, 0.02, 0.0)
	_death_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_death_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_death_veil)
	_death_text = UIStyle.label("Your thread will not break.\nHestia's hearth calls you back.", 34, UIStyle.GOLD, 8)
	_death_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	anchor(_death_text, 0.5, 0.5, Vector2(-600, -60), Vector2(1200, 120))
	_death_text.modulate.a = 0.0
	_root.add_child(_death_text)


func _on_player_died() -> void:
	var tween := create_tween().set_parallel()
	tween.tween_property(_death_veil, "color:a", 0.72, 1.6)
	tween.tween_property(_death_text, "modulate:a", 1.0, 1.6)


func _on_player_respawned() -> void:
	var tween := create_tween().set_parallel()
	tween.tween_property(_death_veil, "color:a", 0.0, 1.0)
	tween.tween_property(_death_text, "modulate:a", 0.0, 0.6)
