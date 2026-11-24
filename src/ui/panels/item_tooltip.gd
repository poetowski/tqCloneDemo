class_name ItemTooltip
extends PanelContainer
## The card shown over an item: its name in its rarity colour, its numbers, its
## affixes, its lore, and how it compares with what the hero wears.

var _text: RichTextLabel


func _init() -> void:
	add_theme_stylebox_override(&"panel", UIStyle.panel(UIStyle.BRONZE, Color(0.06, 0.045, 0.04, 0.97), 2, 6))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.custom_minimum_size = Vector2(320, 0)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.add_theme_font_size_override(&"normal_font_size", 16)
	_text.add_theme_font_size_override(&"italics_font_size", 15)
	_text.add_theme_color_override(&"default_color", UIStyle.BONE)
	add_child(_text)
	visible = false
	z_index = 50


func show_item(item: Item, at: Vector2, compare: Item = null, hint: String = "") -> void:
	if item == null:
		visible = false
		return
	var parts: PackedStringArray = []
	for line: Variant in item.describe():
		var entry := line as Dictionary
		var colour := (entry["color"] as Color).to_html(false)
		var text := String(entry["text"])
		if entry.get("size", 0) == 1:
			parts.append("[font_size=21][color=#%s]%s[/color][/font_size]" % [colour, text])
		elif bool(entry.get("italic", false)):
			parts.append("[i][color=#%s]%s[/color][/i]" % [colour, text])
		else:
			parts.append("[color=#%s]%s[/color]" % [colour, text])
	if compare and compare != item:
		parts.append("")
		parts.append("[color=#A89D86]Compared with %s:[/color]" % compare.display_name())
		parts.append_array(_comparison(item, compare))
	if hint != "":
		parts.append("[color=#7D7466]%s[/color]" % hint)
	_text.text = "\n".join(parts)
	visible = true
	reset_size()
	var viewport := get_viewport_rect().size
	var pos := at + Vector2(22, 16)
	if pos.x + size.x > viewport.x - 8:
		pos.x = at.x - size.x - 22
	if pos.y + size.y > viewport.y - 8:
		pos.y = viewport.y - size.y - 8
	global_position = pos


func _comparison(item: Item, other: Item) -> PackedStringArray:
	var totals: Dictionary = {}
	for mod: Variant in item.mods():
		var m := mod as Dictionary
		var key := String(m["stat"]) + ("%" if float(m["pct"]) != 0.0 else "")
		totals[key] = float(totals.get(key, 0.0)) + float(m["flat"]) + float(m["pct"])
	for mod: Variant in other.mods():
		var m := mod as Dictionary
		var key := String(m["stat"]) + ("%" if float(m["pct"]) != 0.0 else "")
		totals[key] = float(totals.get(key, 0.0)) - float(m["flat"]) - float(m["pct"])
	var out: PackedStringArray = []
	for key: Variant in totals:
		var delta := float(totals[key])
		if absf(delta) < 0.05:
			continue
		var is_pct := String(key).ends_with("%")
		var stat := StringName(String(key).trim_suffix("%"))
		var label := String(Item.STAT_LABELS.get(stat, String(stat)))
		var colour := "#7CCF6A" if delta > 0.0 else "#E06A5A"
		var amount := ("%+d%%" % int(round(delta))) if is_pct else (("%+.1f" % delta) if absf(delta) < 3.0 and absf(delta - round(delta)) > 0.05 else ("%+d" % int(round(delta))))
		out.append("[color=%s]%s %s[/color]" % [colour, amount, label])
	if out.is_empty():
		out.append("[color=#A89D86]No difference.[/color]")
	return out
