class_name DialoguePanel
extends GamePanel
## Talking to someone: their name, their words appearing as if spoken, and the
## hero's possible answers. NPCs drive it with `open()`.

var _name: Label
var _text: RichTextLabel
var _options: VBoxContainer
var _reveal := 1.0


func _init() -> void:
	super._init()
	set_title("")
	_name = UIStyle.label("", 22, UIStyle.GOLD_BRIGHT)
	content.add_child(_name)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.custom_minimum_size = Vector2(760, 80)
	_text.add_theme_font_size_override(&"normal_font_size", 19)
	_text.add_theme_font_size_override(&"italics_font_size", 19)
	_text.add_theme_color_override(&"default_color", UIStyle.BONE)
	content.add_child(_text)
	_options = VBoxContainer.new()
	_options.add_theme_constant_override(&"separation", 6)
	content.add_child(_options)
	custom_minimum_size = Vector2(820, 260)
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = -410
	offset_right = 410
	offset_top = -520
	offset_bottom = -180


## Shows `text` from `speaker`; options are [label, Callable] pairs.
func open(speaker: String, text: String, options: Array) -> void:
	set_title("")
	_name.text = speaker
	_text.text = text
	_text.visible_ratio = 0.0
	_reveal = 0.0
	for child in _options.get_children():
		child.queue_free()
	for option: Variant in options:
		var pair := option as Array
		var b := UIStyle.button("» " + String(pair[0]), 17)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var action := pair[1] as Callable
		b.pressed.connect(func() -> void:
			Sfx.play(&"ui_click")
			action.call())
		_options.add_child(b)
	visible = true


func close() -> void:
	visible = false


func _process(delta: float) -> void:
	if visible and _reveal < 1.0:
		_reveal = minf(1.0, _reveal + delta * 55.0 / maxf(20.0, float(_text.get_total_character_count())))
		_text.visible_ratio = _reveal


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click and click.pressed and _reveal < 1.0:
		_reveal = 1.0
		_text.visible_ratio = 1.0
		accept_event()
