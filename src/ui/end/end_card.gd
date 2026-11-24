extends Control
## The last beat of the slice: the screen darkens to black glaze, the logo returns
## and the thread runs on. Shows how the run went.

const LOGO := "res://assets/ui/title_logo.png"


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	modulate.a = 0.0
	var veil := ColorRect.new()
	veil.color = Color(0.05, 0.035, 0.03, 0.94)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(veil)
	if ResourceLoader.exists(LOGO):
		var logo := TextureRect.new()
		logo.texture = load(LOGO) as Texture2D
		logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		HUD.anchor(logo, 0.5, 0.0, Vector2(-560, 90), Vector2(1120, 294))
		add_child(logo)
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override(&"separation", 14)
	HUD.anchor(lines, 0.5, 0.0, Vector2(-500, 420), Vector2(1000, 500))
	add_child(lines)
	var verse := UIStyle.label("One blade of three. The thread runs on.", 34, UIStyle.GOLD_BRIGHT, 8)
	verse.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lines.add_child(verse)
	var thanks := UIStyle.label("Thank you for playing the UNTHREADED vertical slice.", 22, UIStyle.BONE, 6)
	thanks.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lines.add_child(thanks)
	var player := Game.player
	var minutes := Game.play_seconds() / 60
	var stats := "Level %d  ·  %d Unthreaded severed  ·  %d min %02d s" % [player.level if player else 1, Game.kills, minutes, Game.play_seconds() % 60]
	var stat_label := UIStyle.label(stats, 19, UIStyle.MUTED, 5)
	stat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lines.add_child(stat_label)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 30)
	lines.add_child(gap)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 24)
	lines.add_child(row)
	for entry: Array in [["Keep exploring", queue_free], ["Return to the title", Game.to_title], ["Quit", func() -> void: get_tree().quit()]]:
		var b := UIStyle.button(String(entry[0]), 20)
		b.custom_minimum_size = Vector2(260, 50)
		b.pressed.connect(entry[1] as Callable)
		row.add_child(b)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 2.0)
	Sfx.play_music(&"title")
