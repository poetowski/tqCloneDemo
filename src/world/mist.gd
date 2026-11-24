class_name Mist
extends Node3D
## Low Styx mist over an area (the necropolis): flat drifting cards laid on the
## ground around this node.

const SHADER := preload("res://src/shaders/mist.gdshader")

@export var radius := 18.0
@export var count := 18
@export var colour := Color(0.45, 0.88, 0.82, 0.13)


func _ready() -> void:
	_spread.call_deferred()


func _spread() -> void:
	# The ground's collider joins the physics space on the first physics step.
	await get_tree().physics_frame
	await get_tree().physics_frame
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter(&"colour", colour)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(name)
	var space := get_world_3d().direct_space_state
	for i in count:
		var angle := rng.randf() * TAU
		var distance := sqrt(rng.randf()) * radius
		var at := global_position + Vector3(cos(angle), 0.0, sin(angle)) * distance
		var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 20.0, at + Vector3.DOWN * 20.0, Actor.LAYER_TERRAIN)
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			continue
		var card := MeshInstance3D.new()
		card.mesh = Vfx.mesh("Disc")
		card.material_override = material
		card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(card)
		card.global_position = (hit["position"] as Vector3) + Vector3.UP * rng.randf_range(0.15, 0.6)
		card.scale = Vector3.ONE * rng.randf_range(4.0, 7.5)
		card.rotation.y = rng.randf() * TAU
