class_name PausePanel
extends GamePanel
## Esc: the game stops; resume, read the controls, or leave.

const CONTROLS := """[color=#E2B04A]Left mouse[/color]  move · attack · pick up · talk (hold to keep going)
[color=#E2B04A]Shift + left mouse[/color]  attack where you stand
[color=#E2B04A]Right mouse, Q W E R[/color]  skills
[color=#E2B04A]1 / 2[/color]  healing / ichor draught
[color=#E2B04A]I[/color] pack · [color=#E2B04A]C[/color] hero · [color=#E2B04A]K[/color] the Loom · [color=#E2B04A]Alt[/color] show all loot
[color=#E2B04A]Mouse wheel[/color]  zoom · [color=#E2B04A]F12[/color] screenshot"""


func _init() -> void:
	super._init()
	set_title("Paused")
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	var controls := RichTextLabel.new()
	controls.bbcode_enabled = true
	controls.fit_content = true
	controls.scroll_active = false
	controls.custom_minimum_size = Vector2(520, 0)
	controls.add_theme_font_size_override(&"normal_font_size", 16)
	controls.add_theme_color_override(&"default_color", UIStyle.BONE)
	controls.text = CONTROLS
	content.add_child(controls)
	for entry: Array in [["Resume", _resume], ["Return to the title", _title_screen], ["Quit", _quit]]:
		var b := UIStyle.button(String(entry[0]), 19)
		b.pressed.connect(entry[1] as Callable)
		content.add_child(b)
	custom_minimum_size = Vector2(580, 420)
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.5
	anchor_bottom = 0.5
	offset_left = -290
	offset_right = 290
	offset_top = -240
	offset_bottom = 240
	visibility_changed.connect(func() -> void:
		if is_inside_tree():
			get_tree().paused = visible)


func _resume() -> void:
	visible = false


func _title_screen() -> void:
	visible = false
	Game.to_title()


func _quit() -> void:
	get_tree().quit()
