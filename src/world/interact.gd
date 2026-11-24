class_name Interact
extends RefCounted
## Helpers for things the hero clicks: a pick area on the interact layer and a
## blocking body on the world layer.


static func add_area(owner: Node3D, radius: float, height: float) -> Area3D:
	var area := Area3D.new()
	area.collision_layer = Actor.LAYER_INTERACT
	area.collision_mask = 0
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = radius
	cylinder.height = height
	shape.shape = cylinder
	shape.position.y = height * 0.5
	area.add_child(shape)
	owner.add_child(area)
	return area


static func load_model(owner: Node3D, slug: String, folder: String = "props") -> Node3D:
	var path := "res://assets/models/%s/%s/%s.glb" % [folder, slug, slug]
	if not ResourceLoader.exists(path):
		push_warning("no model " + path)
		return null
	var model := (load(path) as PackedScene).instantiate() as Node3D
	owner.add_child(model)
	return model
