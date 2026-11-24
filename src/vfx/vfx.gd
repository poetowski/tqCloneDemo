class_name Vfx
extends RefCounted
## Code-built effects on Blender-made meshes (assets/models/vfx/vfx_kit): sparks,
## motes, rings, swing arcs, beams, golden threads and ground telegraphs. Colours
## follow docs/ART_BIBLE.md: gold for the hero, teal for death, red-orange for warnings.

const KIT_PATH := "res://assets/models/vfx/vfx_kit/vfx_kit.glb"
const ADDITIVE := preload("res://src/shaders/vfx_additive.gdshader")
const TELEGRAPH := preload("res://src/shaders/telegraph.gdshader")

const GOLD := Color(1.0, 0.78, 0.32)
const TEAL := Color(0.37, 0.86, 0.8)
const FIRE := Color(1.0, 0.5, 0.15)
const WARN := Color(1.0, 0.36, 0.12)
const SPARK := Color(1.0, 0.92, 0.7)

static var _meshes: Dictionary = {}
static var _materials: Dictionary = {}


## Drops the cached meshes and materials (at exit, so nothing is left in use).
static func clear_cache() -> void:
	_meshes.clear()
	_materials.clear()


static func mesh(mesh_name: String) -> Mesh:
	if _meshes.is_empty():
		var scene := (load(KIT_PATH) as PackedScene).instantiate()
		for node in scene.find_children("*", "MeshInstance3D", true, false):
			_meshes[String(node.name)] = (node as MeshInstance3D).mesh
		scene.free()
	return _meshes.get(mesh_name) as Mesh


## An additive material for a colour and mode (cached).
static func glow_material(color: Color, mode: int = 0, energy: float = 2.5) -> ShaderMaterial:
	var key := "%s|%d|%.2f" % [color.to_html(), mode, energy]
	if _materials.has(key):
		return _materials[key] as ShaderMaterial
	var material := ShaderMaterial.new()
	material.shader = ADDITIVE
	material.set_shader_parameter(&"color", color)
	material.set_shader_parameter(&"mode", mode)
	material.set_shader_parameter(&"energy", energy)
	_materials[key] = material
	return material


static func _parent() -> Node:
	if Game.level and is_instance_valid(Game.level):
		return Game.level
	return (Engine.get_main_loop() as SceneTree).current_scene


static func _free_after(node: Node, seconds: float) -> void:
	var timer := node.get_tree().create_timer(seconds, false)
	timer.timeout.connect(node.queue_free)


## A burst of sparks.
static func sparks(at: Vector3, color: Color = SPARK, count: int = 10, speed: float = 6.0) -> void:
	var p := _particles(at, "Shard", color, count, 0.35)
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -14, 0)
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.4
	p.particle_flag_align_y = true


## Slow motes drifting upward (Styx light, embers, gold dust).
static func motes(at: Vector3, color: Color = TEAL, count: int = 16, spread_radius: float = 0.6, lifetime: float = 1.4) -> void:
	var p := _particles(at, "Mote", color, count, lifetime)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = spread_radius
	p.direction = Vector3.UP
	p.spread = 25.0
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 2.0
	p.gravity = Vector3(0, 0.6, 0)
	p.explosiveness = 0.7
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.6


static func _particles(at: Vector3, mesh_name: String, color: Color, count: int, lifetime: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.mesh = mesh(mesh_name)
	p.material_override = glow_material(Color.WHITE, 0, 1.6)
	p.amount = count
	p.lifetime = lifetime
	p.one_shot = true
	p.explosiveness = 1.0
	var ramp := Gradient.new()
	ramp.set_color(0, color)
	ramp.set_color(1, Color(color.r, color.g, color.b, 0.0))
	p.color_ramp = ramp
	_parent().add_child(p)
	p.global_position = at
	p.emitting = true
	_free_after(p, lifetime + 0.3)
	return p


## A flat ring that grows from `from_radius` to `to_radius` and fades.
static func ring(at: Vector3, color: Color, from_radius: float, to_radius: float, seconds: float = 0.4) -> MeshInstance3D:
	var m := _mesh_node("Ring", glow_material(color, 1, 3.0), at + Vector3.UP * 0.08)
	m.scale = Vector3.ONE * maxf(0.01, from_radius)
	var tween := m.create_tween().set_parallel()
	tween.tween_property(m, "scale", Vector3.ONE * to_radius, seconds).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_method(func(v: float) -> void: m.set_instance_shader_parameter(&"alpha", v), 1.0, 0.0, seconds)
	_free_after(m, seconds + 0.05)
	return m


## A weapon-swing crescent in front of `basis` (model front +Z).
static func arc(at: Vector3, facing: Basis, color: Color, radius: float = 2.0, seconds: float = 0.22, tilt: float = 0.0) -> void:
	var m := _mesh_node("Arc", glow_material(color, 3, 3.0), at)
	m.global_basis = facing.orthonormalized() * Basis(Vector3.FORWARD, tilt)
	m.scale = Vector3.ONE * radius
	var tween := m.create_tween()
	tween.tween_method(func(v: float) -> void: m.set_instance_shader_parameter(&"progress", v), 0.0, 1.6, seconds)
	tween.parallel().tween_method(func(v: float) -> void: m.set_instance_shader_parameter(&"alpha", v), 1.0, 0.0, seconds * 1.4)
	_free_after(m, seconds * 1.5)


## A column of light (spawns, level-ups); `seconds` <= 0 keeps it until freed.
static func beam(at: Vector3, color: Color, radius: float = 0.5, height: float = 3.0, seconds: float = 0.8, energy: float = 0.9) -> MeshInstance3D:
	var m := _mesh_node("Beam", glow_material(color, 2, energy), at)
	m.scale = Vector3(radius, height, radius)
	if seconds > 0.0:
		var tween := m.create_tween()
		tween.tween_method(func(v: float) -> void: m.set_instance_shader_parameter(&"alpha", v), 1.0, 0.0, seconds).set_ease(Tween.EASE_IN)
		_free_after(m, seconds + 0.05)
	return m


## A golden thread from a to b, fading out.
static func thread(a: Vector3, b: Vector3, color: Color = GOLD, seconds: float = 0.35, width: float = 0.03) -> void:
	var m := _mesh_node("Beam", glow_material(color, 4, 4.0), a)
	var length := a.distance_to(b)
	if length < 0.01:
		m.queue_free()
		return
	var up := (b - a) / length
	var side := up.cross(Vector3.UP if absf(up.y) < 0.95 else Vector3.RIGHT).normalized()
	m.global_basis = Basis(side * width, up * length, side.cross(up) * width)
	var tween := m.create_tween()
	tween.tween_method(func(v: float) -> void: m.set_instance_shader_parameter(&"alpha", v), 1.0, 0.0, seconds)
	_free_after(m, seconds + 0.05)


## The thread snapping when a foe is severed: a gold line flicks up and breaks.
static func sever(at: Vector3) -> void:
	var top := at + Vector3(randf_range(-0.3, 0.3), 3.2, randf_range(-0.3, 0.3))
	thread(at + Vector3.UP * 0.8, top, GOLD, 0.5, 0.05)
	motes(top, GOLD, 10, 0.2, 0.9)
	motes(at + Vector3.UP, GOLD, 8, 0.4, 0.8)


## A warning on the ground: a circle, a cone (half_angle < 180) or, with
## `lane_length` > 0, a lane `width` wide. Fills over `seconds`, then frees itself.
static func telegraph(at: Vector3, facing: Vector3, radius: float, seconds: float, half_angle: float = 180.0,
		lane_length: float = 0.0, width: float = 2.0, inner: float = 0.0) -> MeshInstance3D:
	var material := ShaderMaterial.new()
	material.shader = TELEGRAPH
	material.set_shader_parameter(&"shape", 1 if lane_length > 0.0 else 0)
	material.set_shader_parameter(&"half_angle", half_angle)
	material.set_shader_parameter(&"inner", inner)
	var m := _mesh_node("Lane" if lane_length > 0.0 else "Disc", material, at + Vector3.UP * 0.06)
	var flat := Vector3(facing.x, 0.0, facing.z)
	if flat.length_squared() > 0.0001:
		m.look_at(m.global_position + flat, Vector3.UP, true)
	m.scale = Vector3(width, 1.0, lane_length) if lane_length > 0.0 else Vector3(radius, 1.0, radius)
	var tween := m.create_tween()
	tween.tween_method(func(v: float) -> void: m.set_instance_shader_parameter(&"fill", v), 0.0, 1.0, seconds)
	tween.tween_method(func(v: float) -> void: m.set_instance_shader_parameter(&"alpha", v), 1.0, 0.0, 0.18)
	_free_after(m, seconds + 0.2)
	return m


static func _mesh_node(mesh_name: String, material: Material, at: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh(mesh_name)
	m.material_override = material
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_parent().add_child(m)
	m.global_position = at
	return m
