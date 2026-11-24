class_name Fire
extends Node3D
## A flame: rising embers (Blender motes and shards), a flickering warm light. For
## braziers, the Hearth of Hestia and the bull's forge. Fire belongs to Hephaestus
## and Hestia only (docs/ART_BIBLE.md).

@export var size := 1.0
@export var color := Color(1.0, 0.55, 0.2)
@export var light_energy := 2.2
@export var light_range := 9.0
@export var lit := true

var _light: OmniLight3D
var _flames: CPUParticles3D
var _embers: CPUParticles3D
var _t := 0.0


func _ready() -> void:
	_flames = CPUParticles3D.new()
	_flames.mesh = Vfx.mesh("Shard")
	_flames.material_override = Vfx.glow_material(Color.WHITE, 0, 2.2)
	_flames.amount = int(18 * size)
	_flames.lifetime = 0.7
	_flames.direction = Vector3.UP
	_flames.spread = 12.0
	_flames.gravity = Vector3(0, 2.0, 0)
	_flames.initial_velocity_min = 0.6 * size
	_flames.initial_velocity_max = 1.6 * size
	_flames.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_flames.emission_sphere_radius = 0.18 * size
	_flames.scale_amount_min = 2.0 * size
	_flames.scale_amount_max = 3.6 * size
	_flames.particle_flag_align_y = true
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.85, 0.45, 1.0))
	ramp.set_color(1, Color(color.r, color.g * 0.6, color.b * 0.3, 0.0))
	_flames.color_ramp = ramp
	add_child(_flames)
	_embers = CPUParticles3D.new()
	_embers.mesh = Vfx.mesh("Mote")
	_embers.material_override = Vfx.glow_material(Color.WHITE, 0, 1.6)
	_embers.amount = int(8 * size)
	_embers.lifetime = 2.0
	_embers.direction = Vector3.UP
	_embers.spread = 25.0
	_embers.initial_velocity_min = 0.8
	_embers.initial_velocity_max = 2.2
	_embers.gravity = Vector3(0.3, 0.4, 0)
	_embers.scale_amount_min = 0.3
	_embers.scale_amount_max = 0.7
	var ember_ramp := Gradient.new()
	ember_ramp.set_color(0, Color(1.0, 0.7, 0.3, 1.0))
	ember_ramp.set_color(1, Color(1.0, 0.3, 0.1, 0.0))
	_embers.color_ramp = ember_ramp
	add_child(_embers)
	_light = OmniLight3D.new()
	_light.light_color = color
	_light.light_energy = light_energy
	_light.omni_range = light_range
	_light.shadow_enabled = false
	_light.position = Vector3.UP * 0.6 * size
	add_child(_light)
	set_lit(lit)


func set_lit(on: bool) -> void:
	lit = on
	if _flames:
		_flames.emitting = on
		_embers.emitting = on
		_light.visible = on


func _process(delta: float) -> void:
	if not lit or _light == null:
		return
	_t += delta
	_light.light_energy = light_energy * (0.85 + 0.15 * sin(_t * 13.0) * sin(_t * 7.3 + 1.0))
