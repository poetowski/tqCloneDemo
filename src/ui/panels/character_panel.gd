class_name CharacterPanel
extends GamePanel
## The hero (C): level, attributes to raise, and what they add up to.

var _level: Label
var _points: Label
var _rows: Dictionary = {}
var _stats: RichTextLabel


func _init() -> void:
	super._init()
	set_title("The Threadless")
	_level = UIStyle.label("", 18, UIStyle.BONE)
	content.add_child(_level)
	_points = UIStyle.label("", 16, UIStyle.GOLD_BRIGHT)
	content.add_child(_points)
	for entry: Array in [[&"might", "Might", "+2 health, +1.5% damage"], [&"cunning", "Cunning", "+1% attack speed, +0.25% critical chance"],
			[&"spirit", "Spirit", "+2 ichor, +2% skill damage, faster ichor"]]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 10)
		var name := UIStyle.label(String(entry[1]), 20, UIStyle.GOLD)
		name.custom_minimum_size = Vector2(110, 0)
		row.add_child(name)
		var value := UIStyle.label("10", 20, UIStyle.BONE)
		value.custom_minimum_size = Vector2(44, 0)
		row.add_child(value)
		var plus := UIStyle.button("+", 18)
		plus.custom_minimum_size = Vector2(36, 32)
		plus.pressed.connect(_raise.bind(entry[0] as StringName))
		row.add_child(plus)
		var what := UIStyle.label(String(entry[2]), 13, UIStyle.MUTED, 3)
		row.add_child(what)
		content.add_child(row)
		_rows[entry[0]] = [value, plus]
	var band := Control.new()
	band.custom_minimum_size = Vector2(0, 14)
	band.draw.connect(func() -> void: UIStyle.draw_meander(band, Rect2(Vector2.ZERO, band.size), Color(0.7, 0.5, 0.25, 0.6), 4.0))
	content.add_child(band)
	_stats = RichTextLabel.new()
	_stats.bbcode_enabled = true
	_stats.fit_content = true
	_stats.scroll_active = false
	_stats.custom_minimum_size = Vector2(440, 0)
	_stats.add_theme_font_size_override(&"normal_font_size", 16)
	_stats.add_theme_color_override(&"default_color", UIStyle.BONE)
	content.add_child(_stats)
	dock(0.0, Vector2(520, 640))


func bind_player(p: Player) -> void:
	super.bind_player(p)
	player.attributes_changed.connect(refresh)
	player.leveled_up.connect(func(_l: int) -> void: refresh())
	player.gear_changed.connect(refresh)
	refresh()


func _raise(stat: StringName) -> void:
	if player.spend_attribute(stat):
		Sfx.play(&"ui_click")
		refresh()


func refresh() -> void:
	if player == null:
		return
	_level.text = "Level %d · %d / %d experience" % [player.level, player.xp, Game.xp_to_next(player.level)]
	_points.text = ("%d attribute points to spend" % player.attribute_points) if player.attribute_points > 0 else ""
	for stat: Variant in _rows:
		var row := _rows[stat] as Array
		(row[0] as Label).text = str(int(player.stats.value(stat as StringName)))
		(row[1] as Button).disabled = player.attribute_points <= 0
	var s := player.stats
	var low := s.value(Stats.DAMAGE_MIN)
	var high := maxf(low, s.value(Stats.DAMAGE_MAX))
	var bonus := 1.0 + 0.015 * s.value(Stats.MIGHT) + s.value(Stats.DAMAGE_PCT) / 100.0
	var armor := s.value(Stats.ARMOR)
	var lines: PackedStringArray = [
		_line("Health", "%d" % int(player.max_health())),
		_line("Ichor", "%d" % int(player.max_ichor())),
		_line("Damage", "%d–%d" % [int(low * bonus), int(high * bonus)]),
		_line("Attacks per second", "%.2f" % player.attacks_per_second()),
		_line("Critical chance", "%.1f%%" % player.crit_chance()),
		_line("Critical damage", "×%.2f" % s.value(Stats.CRIT_MULTIPLIER)),
		_line("Armour", "%d  (takes %d%% less)" % [int(armor), int(round(100.0 - 10000.0 / (100.0 + armor)))]),
		_line("Movement", "%.1f m/s" % player.move_speed()),
		_line("Health per second", "%.1f" % s.value(Stats.HEALTH_REGEN)),
		_line("Ichor per second", "%.1f" % s.value(Stats.ICHOR_REGEN)),
	]
	for extra: Array in [[Stats.SKILL_DAMAGE_PCT, "Skill damage", "+%d%%"], [Stats.LIFE_ON_HIT, "Health per hit", "+%d"],
			[Stats.FIRE_DAMAGE, "Fire damage (burning)", "+%d"]]:
		var v := s.value(extra[0] as StringName)
		if v > 0.0:
			lines.append(_line(String(extra[1]), String(extra[2]) % int(v)))
	var find := s.value(Stats.MAGIC_FIND) - 100.0
	if find > 0.0:
		lines.append(_line("Finer loot", "+%d%%" % int(find)))
	lines.append("")
	lines.append(_line("Unthreaded severed", str(Game.kills)))
	_stats.text = "\n".join(lines)


func _line(label: String, value: String) -> String:
	return "[color=#A89D86]%s[/color]  [color=#EFE6D2]%s[/color]" % [label, value]
