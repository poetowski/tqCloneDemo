class_name Atmosphere
extends Node3D
## The air of a level (docs/ART_BIBLE.md#lighting). As the hero walks from one zone
## into another, that zone's mood (data/atmosphere.json) blends in: haze, colour
## grading, the sun, wind and cloud shade (shader globals, weather.gdshaderinc) and what
## drifts in the air around the hero: pollen, dust, Styx wisps or embers.

const DATA := "res://data/atmosphere.json"
## What each kind of mote looks like: colour (sRGB), glow, size, rise speed (m/s).
const MOTES := {
	"pollen": {"color": Color("#F4E3A6"), "glow": 0.6, "size": 0.07, "rise": 0.05, "life": 9.0},
	"dust": {"color": Color("#E9DECB"), "glow": 0.0, "size": 0.06, "rise": 0.02, "life": 8.0},
	"wisps": {"color": Color("#5FD3C6"), "glow": 2.2, "size": 0.16, "rise": 0.35, "life": 6.0},
	"embers": {"color": Color("#FF8A2A"), "glow": 3.0, "size": 0.05, "rise": 0.9, "life": 4.0},
}

var mood := &""

var _moods: Dictionary = {}
var _blend := 3.5
var _env: Environment
var _sun: DirectionalLight3D
var _tween: Tween
var _motes: GPUParticles3D
var _mote_material: StandardMaterial3D
var _mote_process: ParticleProcessMaterial
var _mote_kind := ""
var _globals: Dictionary = {}


func _ready() -> void:
	var data: Variant = DB.load_json(DATA)
	if not data is Dictionary:
		return
	_moods = (data as Dictionary).get("moods", {}) as Dictionary
	_blend = float((data as Dictionary).get("blend", 3.5))
	var root := get_parent()
	var world := root.get_node_or_null("WorldEnvironment") as WorldEnvironment
	_env = world.environment if world else null
	_sun = root.get_node_or_null("Sun") as DirectionalLight3D
	_build_motes()
	Events.zone_changed.connect(func(zone: Node3D) -> void:
		var wanted := StringName(String(zone.get(&"mood")))
		if wanted != &"":
			set_mood(wanted))
	set_mood(StringName(String((data as Dictionary).get("start", "village"))), true)


func _process(_delta: float) -> void:
	if _motes and Game.player:
		_motes.global_position = Game.player.global_position + Vector3.UP * 1.5


## Blends to a mood from data/atmosphere.json (at once when `instant`).
func set_mood(name: StringName, instant: bool = false) -> void:
	if name == mood or not _moods.has(String(name)):
		return
	mood = name
	var m := _moods[String(name)] as Dictionary
	var time := 0.01 if instant else _blend
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	if _env:
		_tween.tween_property(_env, "fog_light_color", Color(String(m.get("fog", "#E0D0B8"))), time)
		_tween.tween_property(_env, "fog_density", float(m.get("fog_density", 0.0028)), time)
		_tween.tween_property(_env, "adjustment_saturation", float(m.get("saturation", 1.1)), time)
		_tween.tween_property(_env, "adjustment_contrast", float(m.get("contrast", 1.05)), time)
		_tween.tween_property(_env, "ambient_light_energy", float(m.get("ambient", 0.7)), time)
	if _sun:
		_tween.tween_property(_sun, "light_color", Color(String(m.get("sun", "#FFE0B0"))), time)
		_tween.tween_property(_sun, "light_energy", float(m.get("sun_energy", 1.45)), time)
	_tween_global(&"wind_strength", float(m.get("wind", 1.0)), time)
	_tween_global(&"cloud_cover", float(m.get("clouds", 0.4)), time)
	_set_motes(String(m.get("motes", "")), int(m.get("mote_amount", 0)))


## Blends a weather shader global. Its current value is kept here: reading it back from
## the RenderingServer stalls rendering (and gives nothing in headless runs).
func _tween_global(param: StringName, to: float, time: float) -> void:
	var from := float(_globals.get(param, shader_global(String(param), to)))
	_globals[param] = to
	_tween.tween_method(func(v: float) -> void: RenderingServer.global_shader_parameter_set(param, v), from, to, time)


## A weather global's starting value, from project.godot's [shader_globals].
static func shader_global(param: String, fallback: Variant) -> Variant:
	var setting: Variant = ProjectSettings.get_setting("shader_globals/" + param)
	return (setting as Dictionary).get("value", fallback) if setting is Dictionary else fallback


# --- motes -------------------------------------------------------------------------------

func _build_motes() -> void:
	_motes = GPUParticles3D.new()
	_motes.name = "Motes"
	_motes.local_coords = false
	_motes.emitting = false
	_motes.visibility_aabb = AABB(Vector3(-30, -8, -30), Vector3(60, 18, 60))
	_motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mote_process = ParticleProcessMaterial.new()
	_mote_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_mote_process.emission_box_extents = Vector3(20.0, 3.0, 16.0)
	_mote_process.direction = Vector3(1.0, 0.3, -0.3)
	_mote_process.spread = 180.0
	_mote_process.initial_velocity_min = 0.1
	_mote_process.initial_velocity_max = 0.45
	_mote_process.turbulence_enabled = true
	_mote_process.turbulence_noise_strength = 0.6
	_mote_process.turbulence_noise_scale = 6.0
	_mote_process.scale_min = 0.6
	_mote_process.scale_max = 1.3
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.2, Color(1, 1, 1, 1))
	fade.add_point(0.8, Color(1, 1, 1, 1))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	_mote_process.color_ramp = ramp
	_motes.process_material = _mote_process
	var quad := QuadMesh.new()
	_mote_material = StandardMaterial3D.new()
	_mote_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mote_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mote_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mote_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_mote_material.vertex_color_use_as_albedo = true
	_mote_material.albedo_texture = soft_dot()
	quad.material = _mote_material
	_motes.draw_pass_1 = quad
	add_child(_motes)


func _set_motes(kind: String, amount: int) -> void:
	if not MOTES.has(kind) or amount <= 0:
		_motes.emitting = false
		return
	var spec := MOTES[kind] as Dictionary
	if kind != _mote_kind or _motes.amount != amount:
		_mote_kind = kind
		_motes.amount = amount
		_motes.lifetime = float(spec["life"])
		_motes.preprocess = float(spec["life"])
		var size := float(spec["size"])
		(_motes.draw_pass_1 as QuadMesh).size = Vector2(size, size)
		_mote_process.gravity = Vector3(0.0, float(spec["rise"]), 0.0)
		var colour := spec["color"] as Color
		_mote_material.albedo_color = Color(colour.r, colour.g, colour.b, 0.85)
		_mote_material.emission_enabled = float(spec["glow"]) > 0.0
		_mote_material.emission = colour
		_mote_material.emission_energy_multiplier = float(spec["glow"])
		_motes.restart()
	_motes.emitting = true


## A soft round dot (no texture files: drawn by a gradient).
static func soft_dot() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 32
	tex.height = 32
	return tex
