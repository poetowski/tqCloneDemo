class_name GrassField
extends Node3D
## Grass, poppies and asphodel scattered by the level script (the layout's
## "scatter" lists), drawn as MultiMeshes in 32 m chunks so the camera culls them.

const CHUNK := 32.0
const MODELS := "res://assets/models/props/%s/%s.glb"

@export_file("*.json") var layout_path := ""


func _ready() -> void:
	if layout_path == "":
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(layout_path))
	if not data is Dictionary:
		return
	var scatter := (data as Dictionary).get("scatter", {}) as Dictionary
	for kind: Variant in scatter:
		_build(String(kind), scatter[kind] as Array)


func _build(kind: String, points: Array) -> void:
	var path := MODELS % [kind, kind]
	if not ResourceLoader.exists(path):
		return
	var model := (load(path) as PackedScene).instantiate()
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	if meshes.is_empty():
		model.free()
		return
	var mesh := (meshes[0] as MeshInstance3D).mesh
	model.free()
	var chunks: Dictionary = {}
	for p: Variant in points:
		var row := p as Array
		var key := Vector2i(int(floor(float(row[0]) / CHUNK)), int(floor(float(row[2]) / CHUNK)))
		if not chunks.has(key):
			chunks[key] = []
		(chunks[key] as Array).append(row)
	for key: Variant in chunks:
		var rows := chunks[key] as Array
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = mesh
		multimesh.instance_count = rows.size()
		for i in rows.size():
			var row := rows[i] as Array
			var s := float(row[4])
			var basis := Basis(Vector3.UP, float(row[3])).scaled(Vector3(s, s, s))
			multimesh.set_instance_transform(i, Transform3D(basis, Vector3(float(row[0]), float(row[1]), float(row[2]))))
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multimesh
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.visibility_range_end = 70.0
		add_child(instance)
