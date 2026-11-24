class_name LoomPanel
extends GamePanel
## The Loom (K): every skill is a golden thread with five knots. Spend a point to
## tie the next knot.

const ICONS := "res://assets/icons/skills/%s.png"
const ORDER: Array[StringName] = [&"lunge", &"aspis_bash", &"fates_lash", &"war_cry", &"bound_shades", &"atropos_mercy"]

var _points: Label
var _rows: Dictionary = {}


func _init() -> void:
	super._init()
	set_title("The Loom")
	_points = UIStyle.label("", 17, UIStyle.GOLD_BRIGHT)
	content.add_child(_points)
	for id in ORDER:
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 12)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(64, 64)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var path := ICONS % String(DB.skill(id).get("icon", String(id)))
		if ResourceLoader.exists(path):
			icon.texture = load(path) as Texture2D
		row.add_child(icon)
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override(&"separation", 2)
		var name := UIStyle.label("", 19, UIStyle.GOLD)
		column.add_child(name)
		var knots := Control.new()
		knots.custom_minimum_size = Vector2(300, 16)
		column.add_child(knots)
		var desc := UIStyle.label("", 14, UIStyle.BONE, 3)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size = Vector2(380, 0)
		column.add_child(desc)
		var next := UIStyle.label("", 13, UIStyle.MUTED, 3)
		next.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		next.custom_minimum_size = Vector2(380, 0)
		column.add_child(next)
		row.add_child(column)
		var learn := UIStyle.button("Weave", 16)
		learn.custom_minimum_size = Vector2(88, 40)
		learn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		learn.pressed.connect(_learn.bind(id))
		row.add_child(learn)
		content.add_child(row)
		knots.draw.connect(_draw_knots.bind(knots, id))
		_rows[id] = {"name": name, "knots": knots, "desc": desc, "next": next, "learn": learn, "icon": icon}
	dock(0.0, Vector2(620, 780))
	offset_top -= 40.0
	offset_bottom -= 40.0


func bind_player(p: Player) -> void:
	super.bind_player(p)
	player.skills.changed.connect(refresh)
	player.leveled_up.connect(func(_l: int) -> void: refresh())
	refresh()


func _learn(id: StringName) -> void:
	if player.skills.learn(id, player.level):
		Sfx.play(&"weave")
		Vfx.motes(player.global_position + Vector3.UP, Vfx.GOLD, 12, 0.5, 1.0)
	refresh()


func _draw_knots(canvas: Control, id: StringName) -> void:
	if player == null:
		return
	var rank := player.skills.rank(id)
	var maximum := int(DB.skill(id).get("max_rank", 5))
	var y := canvas.size.y * 0.5
	canvas.draw_line(Vector2(0, y), Vector2(maximum * 34 + 8, y), Color(0.89, 0.69, 0.29, 0.8 if rank > 0 else 0.25), 2.0)
	for i in maximum:
		var at := Vector2(14 + i * 34, y)
		if i < rank:
			canvas.draw_circle(at, 6.5, UIStyle.GOLD_BRIGHT)
			canvas.draw_circle(at, 3.0, Color(1, 0.95, 0.8))
		else:
			canvas.draw_arc(at, 6.0, 0, TAU, 16, Color(0.6, 0.48, 0.3, 0.7), 1.5)


func refresh() -> void:
	if player == null:
		return
	var book := player.skills
	_points.text = ("%d thread%s to weave" % [book.points, "" if book.points == 1 else "s"]) if book.points > 0 else "No threads to weave. Each level brings one."
	for id: Variant in _rows:
		var sid := id as StringName
		var row := _rows[sid] as Dictionary
		var data := DB.skill(sid)
		var rank := book.rank(sid)
		var maximum := int(data.get("max_rank", 5))
		var unlock := int(data.get("unlock", 1))
		var kind := "passive" if String(data.get("kind", "")) == "passive" else ("%d ichor · %.1f s" % [int(data.get("cost", 0)), book.cooldown(sid)])
		var key: String = ["", "Right mouse", "Q", "W", "E", "R"][int(data.get("slot", 0))]
		(row["name"] as Label).text = "%s  %d/%d   [%s%s]" % [String(data.get("name", "")), rank, maximum, kind, (" · " + key) if key != "" else ""]
		(row["desc"] as Label).text = book.describe(sid, maxi(1, rank))
		if rank > 0 and rank < maximum:
			(row["next"] as Label).text = "Next knot: " + book.describe(sid, rank + 1)
		elif rank == 0:
			(row["next"] as Label).text = "Unlocks at level %d." % unlock if player.level < unlock else "Not yet woven."
		else:
			(row["next"] as Label).text = "Fully woven."
		(row["learn"] as Button).disabled = not book.can_learn(sid, player.level)
		(row["icon"] as TextureRect).modulate = Color(1, 1, 1, 1.0 if rank > 0 else 0.4)
		(row["knots"] as Control).queue_redraw()
