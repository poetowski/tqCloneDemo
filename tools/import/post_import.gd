@tool
extends EditorScenePostImport
## Runs on every imported scene (the project's import default, see project.godot
## [importer_defaults]). Blender exports materials by name only; this swaps them for
## the project's own: "Palette" -> the palette shader (flash, tint, fade, dissolve),
## "Terrain" -> the vertex-painted ground, "Water" -> the sea. Terrain colliders go
## on the terrain layer.

const MATERIALS := {
	"Palette": "res://assets/materials/palette.tres",
	"Terrain": "res://assets/materials/terrain.tres",
	"Water": "res://assets/materials/water.tres",
}
const TERRAIN_LAYER := 1 << 5

var _loaded: Dictionary = {}


func _post_import(scene: Node) -> Object:
	_walk(scene)
	return scene


func _walk(node: Node) -> void:
	if node is ImporterMeshInstance3D:
		var importer_mesh := (node as ImporterMeshInstance3D).mesh
		if importer_mesh != null:
			for index in importer_mesh.get_surface_count():
				var swap := _replacement(importer_mesh.get_surface_material(index))
				if swap:
					importer_mesh.set_surface_material(index, swap)
	elif node is MeshInstance3D:
		var mesh := (node as MeshInstance3D).mesh
		if mesh != null:
			for index in mesh.get_surface_count():
				var swap := _replacement(mesh.surface_get_material(index))
				if swap:
					mesh.surface_set_material(index, swap)
	# A "-col" mesh gets a child body named StaticBody3D: look at its parent's name too.
	var parent_name := String(node.get_parent().name).to_lower() if node.get_parent() else ""
	if node is StaticBody3D and (String(node.name).to_lower().begins_with("terrain") or parent_name.begins_with("terrain")):
		var body := node as StaticBody3D
		body.collision_layer = TERRAIN_LAYER
		body.collision_mask = 0
	if node is GeometryInstance3D and String(node.name).begins_with("Sea"):
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_walk(child)


func _replacement(material: Material) -> Material:
	if material == null:
		return null
	for prefix: String in MATERIALS:
		if material.resource_name.begins_with(prefix):
			if not _loaded.has(prefix):
				_loaded[prefix] = load(String(MATERIALS[prefix]))
			return _loaded[prefix] as Material
	return null
