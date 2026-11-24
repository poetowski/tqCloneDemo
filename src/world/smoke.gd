class_name Smoke
extends GPUParticles3D
## A thread of smoke from a village hearth: soft grey puffs rising, swelling and
## leaning away with the wind. Placed by the level script ("smoke" things).

## How thick the smoke is (puffs alive at once).
@export var puffs := 18


func _ready() -> void:
	amount = puffs
	lifetime = 7.0
	preprocess = 7.0
	local_coords = false
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visibility_aabb = AABB(Vector3(-6, -1, -6), Vector3(12, 14, 12))
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0, 1, 0)
	process.spread = 8.0
	process.initial_velocity_min = 0.6
	process.initial_velocity_max = 0.9
	var drift: Variant = Atmosphere.shader_global("wind_direction", Vector2(0.95, -0.3))
	var wind := drift as Vector2 if drift is Vector2 else Vector2(0.95, -0.3)
	process.gravity = Vector3(wind.x * 0.35, 0.12, wind.y * 0.35)
	process.damping_min = 0.05
	process.damping_max = 0.1
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.35))
	grow.add_point(Vector2(1.0, 1.0))
	var grow_texture := CurveTexture.new()
	grow_texture.curve = grow
	process.scale_curve = grow_texture
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.15, Color(1, 1, 1, 0.75))
	fade.add_point(0.6, Color(1, 1, 1, 0.45))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	process.color_ramp = ramp
	process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2(2.2, 2.2)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color("#7A746A")
	material.albedo_texture = Atmosphere.soft_dot()
	quad.material = material
	draw_pass_1 = quad
	emitting = true
