extends Node3D
## The title: Elaion itself as the backdrop (its terrain and the props around the
## village and the shore, read from the level layout), a slow camera drifting over
## the bay at golden hour, the logo, and the menu.

const LAYOUT := "res://data/level/elaion_layout.json"
const TERRAIN := "res://assets/models/level/elaion_terrain/elaion_terrain.glb"
const LOGO := "res://assets/ui/title_logo.png"
const FOCUS := Vector3(-48.0, 2.0, 36.0)
const RADIUS := 70.0

var _camera: Camera3D
var _t := 0.0
var _controls: RichTextLabel


func _ready() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	_world()
	_ui()
	Sfx.play_music(&"title")
	Sfx.play_ambience(&"shore")


func _world() -> void:
	var env := Environment.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.28, 0.42, 0.68)
	sky_material.sky_horizon_color = Color(1.0, 0.78, 0.52)
	sky_material.ground_horizon_color = Color(0.9, 0.7, 0.5)
	var sky := Sky.new()
	sky.sky_material = sky_material
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 0.95
	env.glow_enabled = true
	env.ssao_enabled = true
	env.fog_enabled = true
	env.fog_light_color = Color(0.95, 0.75, 0.55)
	env.fog_density = 0.004
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.15
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-18.0), deg_to_rad(-70.0), 0.0)
	sun.light_color = Color(1.0, 0.8, 0.55)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	add_child(sun)
	if ResourceLoader.exists(TERRAIN):
		add_child((load(TERRAIN) as PackedScene).instantiate())
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT)) if FileAccess.file_exists(LAYOUT) else null
	if data is Dictionary:
		for entry: Variant in (data as Dictionary)["items"] as Array:
			var item := entry as Dictionary
			if String(item["type"]) != "prop":
				continue
			var p := item["pos"] as Array
			var at := Vector3(float(p[0]), float(p[1]), float(p[2]))
			if at.distance_to(FOCUS) > RADIUS:
				continue
			var path := "res://assets/models/props/%s/%s.glb" % [item["model"], item["model"]]
			if not ResourceLoader.exists(path):
				continue
			var node := (load(path) as PackedScene).instantiate() as Node3D
			node.position = at
			node.rotation.y = deg_to_rad(float(item.get("rot", 0.0)))
			node.scale = Vector3.ONE * float(item.get("scale", 1.0))
			add_child(node)
		var grass := GrassField.new()
		grass.layout_path = LAYOUT
		add_child(grass)
	_camera = Camera3D.new()
	_camera.fov = 45.0
	_camera.far = 600.0
	add_child(_camera)
	_camera.make_current()
	_place_camera()


func _ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var shade := ColorRect.new()
	shade.color = Color(0.05, 0.03, 0.02, 0.0)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)
	var gradient := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.04, 0.03, 0.02, 0.0))
	g.set_color(1, Color(0.04, 0.03, 0.02, 0.75))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0, 0.35)
	tex.fill_to = Vector2(0, 1)
	gradient.texture = tex
	gradient.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gradient.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(gradient)
	if ResourceLoader.exists(LOGO):
		var logo := TextureRect.new()
		logo.texture = load(LOGO) as Texture2D
		logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		HUD.anchor(logo, 0.5, 0.0, Vector2(-640, 70), Vector2(1280, 336))
		logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(logo)
	var tagline := UIStyle.label("A myth of the severed thread", 30, UIStyle.BONE, 8)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	HUD.anchor(tagline, 0.5, 0.0, Vector2(-500, 390), Vector2(1000, 44))
	root.add_child(tagline)
	var menu := VBoxContainer.new()
	menu.add_theme_constant_override(&"separation", 12)
	HUD.anchor(menu, 0.5, 1.0, Vector2(-170, -400), Vector2(340, 260))
	root.add_child(menu)
	for entry: Array in [["Begin", _begin], ["Controls", _toggle_controls], ["Quit", func() -> void: get_tree().quit()]]:
		var b := UIStyle.button(String(entry[0]), 24)
		b.custom_minimum_size = Vector2(340, 54)
		b.pressed.connect(entry[1] as Callable)
		b.mouse_entered.connect(Sfx.play.bind(&"ui_hover"))
		menu.add_child(b)
	_controls = RichTextLabel.new()
	_controls.bbcode_enabled = true
	_controls.fit_content = true
	_controls.text = PausePanel.CONTROLS
	_controls.add_theme_font_size_override(&"normal_font_size", 18)
	_controls.add_theme_color_override(&"default_color", UIStyle.BONE)
	HUD.anchor(_controls, 0.5, 1.0, Vector2(220, -400), Vector2(620, 220))
	_controls.visible = false
	root.add_child(_controls)
	var credit := UIStyle.label("Vertical slice · every model, icon and sound made with Blender scripts · Godot 4.7", 15, UIStyle.MUTED, 4)
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	HUD.anchor(credit, 0.5, 1.0, Vector2(-600, -44), Vector2(1200, 26))
	root.add_child(credit)


func _toggle_controls() -> void:
	_controls.visible = not _controls.visible
	Sfx.play(&"ui_click")


func _begin() -> void:
	Sfx.play(&"ui_click")
	Game.new_game()


func _process(delta: float) -> void:
	_t += delta
	_place_camera()


## Out over the bay, swaying slowly, looking back at the village and the hill.
func _place_camera() -> void:
	var angle := -1.75 + sin(_t * 0.045) * 0.32
	var at := FOCUS + Vector3(sin(angle) * 52.0, 20.0 + sin(_t * 0.2) * 1.5, cos(angle) * 52.0 + 6.0)
	_camera.global_position = at
	_camera.look_at(FOCUS + Vector3(6.0, 4.0, -6.0), Vector3.UP)
