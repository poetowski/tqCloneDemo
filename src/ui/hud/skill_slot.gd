class_name SkillSlot
extends Control
## One button of the skill bar: the skill's icon, its key, a cooldown sweep, and
## dimming when it's unknown or there isn't enough ichor. Also used for the two
## potion slots (count instead of cooldown).

const ICONS := "res://assets/icons/skills/%s.png"
const ITEM_ICONS := "res://assets/icons/items/%s.png"

var skill_id := &""
var potion_id := &""
var key_text := ""
var player: Player

var _icon: Texture2D
var _cooldown := 0.0
var _usable := true
var _known := true
var _count := 0


func setup(for_player: Player, key: String, skill: StringName = &"", potion: StringName = &"") -> void:
	player = for_player
	key_text = key
	skill_id = skill
	potion_id = potion
	custom_minimum_size = Vector2(64, 64)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var path := (ICONS % DB.skill(skill).get("icon", String(skill))) if skill != &"" else (ITEM_ICONS % String(potion))
	if ResourceLoader.exists(path):
		_icon = load(path) as Texture2D
	tooltip_text = ""


func _process(_delta: float) -> void:
	if player == null:
		return
	if skill_id != &"":
		_known = player.skills.knows(skill_id)
		_cooldown = player.caster.cooldown_fraction(skill_id)
		_usable = _known and player.ichor >= player.skills.cost(skill_id)
	else:
		_count = int(player.belt.get(potion_id, 0))
		_usable = _count > 0
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_style_box(UIStyle.slot_box(UIStyle.GOLD if _known and _usable and _cooldown <= 0.0 else Color(0.4, 0.3, 0.2)), r)
	var inner := r.grow(-4.0)
	if _icon:
		draw_texture_rect(_icon, inner, false, Color(1, 1, 1, 1.0 if _known else 0.25))
	else:
		var name := String(DB.skill(skill_id).get("name", "?")) if skill_id != &"" else ("♥" if potion_id == &"potion_health" else "✦")
		draw_circle(inner.get_center(), inner.size.x * 0.38, Color(0.55, 0.27, 0.15, 0.9 if _known else 0.3))
		var font := get_theme_default_font()
		draw_string(font, inner.get_center() + Vector2(-7, 8), name.substr(0, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UIStyle.BONE)
	if skill_id != &"" and not _known:
		draw_rect(inner, Color(0, 0, 0, 0.55))
	elif not _usable:
		draw_rect(inner, Color(0.05, 0.05, 0.2, 0.45))
	if _cooldown > 0.0:
		var points := PackedVector2Array([inner.get_center()])
		var steps := 24
		for i in steps + 1:
			var a := -PI / 2.0 + TAU * _cooldown * float(i) / float(steps)
			points.append(inner.get_center() + Vector2(cos(a), sin(a)) * inner.size.x)
		if points.size() >= 3:
			var clipped := Geometry2D.intersect_polygons(points, PackedVector2Array([inner.position, Vector2(inner.end.x, inner.position.y), inner.end, Vector2(inner.position.x, inner.end.y)]))
			for poly in clipped:
				draw_colored_polygon(poly, Color(0, 0, 0, 0.6))
	var font2 := get_theme_default_font()
	draw_string_outline(font2, Vector2(5, 17), key_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, UIStyle.OUTLINE)
	draw_string(font2, Vector2(5, 17), key_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UIStyle.GOLD)
	if potion_id != &"":
		draw_string_outline(font2, Vector2(size.x - 18, size.y - 6), str(_count), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, UIStyle.OUTLINE)
		draw_string(font2, Vector2(size.x - 18, size.y - 6), str(_count), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UIStyle.BONE)
	elif _known and skill_id != &"":
		var rank := player.skills.rank(skill_id)
		for i in rank:
			draw_circle(Vector2(size.x - 8 - i * 7, size.y - 7), 2.5, UIStyle.GOLD_BRIGHT)


func _get_tooltip(_at: Vector2) -> String:
	if skill_id != &"":
		var data := DB.skill(skill_id)
		var rank := player.skills.rank(skill_id) if player else 0
		var text := "%s  (rank %d)\n%s\nIchor %d · cooldown %.1f s" % [String(data.get("name", "")), rank,
			player.skills.describe(skill_id) if player else "", int(data.get("cost", 0)), player.skills.cooldown(skill_id) if player else 0.0]
		if rank == 0:
			text += "\nUnlocks at level %d — learn it on the Loom (K)." % int(data.get("unlock", 1))
		return text
	return "%s (%s)" % [String(DB.item_base(potion_id).get("name", "")), key_text]
