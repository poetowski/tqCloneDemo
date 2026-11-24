class_name ActorBody
extends Node3D
## The visible body of an actor: an imported character model (a .glb from
## tools/blender/characters/), its AnimationPlayer, the items mounted on its bones
## (data/attachments.json) and its per-instance shader effects (flash, tint, fade,
## dissolve; see src/shaders/palette.gdshader).
##
## Models face +Z (Godot's MODEL_FRONT); the actor turns the whole body.

const LOOPS: Array[StringName] = [&"idle", &"combat_idle", &"walk", &"run", &"stunned", &"talk", &"weave"]
## Fraction of each one-shot where the blow lands (tools/blender/lib/humanoid.py IMPACT).
const IMPACT := {
	&"attack_thrust": 0.47, &"attack_slash": 0.47, &"bash": 0.47, &"lash": 0.4, &"war_cry": 0.35,
	&"cast": 0.5, &"shoot": 0.68, &"gore": 0.45, &"stomp": 0.55, &"breath": 0.35, &"charge_windup": 1.0,
}
const ITEM_MODELS := "res://assets/models/items/%s/%s.glb"

static var _attachments: Dictionary = {}

var animation_player: AnimationPlayer
var skeleton: Skeleton3D
var model: Node3D
var current := &""

var _geometry: Array[GeometryInstance3D] = []
var _bone_nodes: Dictionary = {}
var _slots: Dictionary = {}
var _flash_tween: Tween
var _flash := 0.0


## Instances `scene` as this body. `hidden` names meshes to hide (equipment variants).
func setup(scene: PackedScene, hidden: Array = []) -> void:
	if model:
		model.queue_free()
	model = scene.instantiate() as Node3D
	add_child(model)
	var players := model.find_children("*", "AnimationPlayer", true, false)
	animation_player = players.front() as AnimationPlayer if not players.is_empty() else null
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	skeleton = skeletons.front() as Skeleton3D if not skeletons.is_empty() else null
	if animation_player:
		for animation_name in LOOPS:
			if animation_player.has_animation(animation_name):
				animation_player.get_animation(animation_name).loop_mode = Animation.LOOP_LINEAR
	for mesh_name: Variant in hidden:
		set_variant(String(mesh_name), false)
	_collect_geometry()


func has_animation(animation_name: StringName) -> bool:
	return animation_player != null and animation_player.has_animation(animation_name)


func animation_length(animation_name: StringName) -> float:
	if not has_animation(animation_name):
		return 0.0
	return animation_player.get_animation(animation_name).length


## Plays a looping or held animation, blending from the current one.
func play(animation_name: StringName, blend: float = 0.15, speed: float = 1.0) -> void:
	if not has_animation(animation_name):
		return
	if current == animation_name and animation_player.is_playing():
		animation_player.speed_scale = speed
		return
	current = animation_name
	animation_player.speed_scale = speed
	animation_player.play(animation_name, blend)


## Plays a one-shot from its start so that it lasts `duration` seconds.
func play_once(animation_name: StringName, duration: float, blend: float = 0.08) -> void:
	if not has_animation(animation_name):
		return
	var length := animation_length(animation_name)
	current = animation_name
	animation_player.speed_scale = length / maxf(duration, 0.05)
	animation_player.play(animation_name, blend)
	animation_player.seek(0.0, true)


## Where in a one-shot the blow lands, 0..1.
static func impact_of(animation_name: StringName) -> float:
	return float(IMPACT.get(animation_name, 0.5))


func set_variant(mesh_name: String, shown: bool) -> void:
	if model == null:
		return
	var found := model.find_child(mesh_name, true, false) as Node3D
	if found:
		found.visible = shown


## Mounts an item model ("dory", "aspis_hero"...) in an attachment slot
## ("weapon", "shield", "helmet", "bow"); an empty slug clears the slot.
func attach(slot: String, slug: String) -> void:
	if _slots.has(slot):
		(_slots[slot] as Node).queue_free()
		_slots.erase(slot)
	if slug.is_empty() or skeleton == null:
		_collect_geometry.call_deferred()
		return
	var spec := attachment_spec(slot)
	if spec.is_empty():
		return
	var path := ITEM_MODELS % [slug, slug]
	if not ResourceLoader.exists(path):
		push_warning("no item model %s" % path)
		return
	var holder := Node3D.new()
	holder.name = "Slot_" + slot
	var rotation_deg := spec["rotation"] as Array
	holder.transform = Transform3D(
		Basis.from_euler(Vector3(deg_to_rad(float(rotation_deg[0])), deg_to_rad(float(rotation_deg[1])), deg_to_rad(float(rotation_deg[2]))), EULER_ORDER_XYZ),
		_vec(spec["offset"] as Array))
	holder.add_child((load(path) as PackedScene).instantiate())
	_bone_node(String(spec["bone"])).add_child(holder)
	_slots[slot] = holder
	_collect_geometry()


func slot_node(slot: String) -> Node3D:
	return _slots.get(slot) as Node3D


## A bone's position in world space (for effects: the thread hand, the muzzle).
func bone_position(bone: String) -> Vector3:
	if skeleton == null:
		return global_position
	var index := skeleton.find_bone(bone)
	if index < 0:
		return global_position
	return skeleton.global_transform * skeleton.get_bone_global_pose(index).origin


## A short white flash on every mesh, for hits.
func flash(strength: float = 1.0) -> void:
	if _flash_tween:
		_flash_tween.kill()
	_set_flash(strength)
	_flash_tween = create_tween()
	_flash_tween.tween_method(_set_flash, strength, 0.0, 0.16)


## A rim glow while the mouse is over this body; strength 0 removes it.
func set_highlight(color: Color, strength: float) -> void:
	_set_all(&"highlight", Color(color.r, color.g, color.b, strength))


func set_tint(color: Color, strength: float) -> void:
	_set_all(&"tint", Color(color.r, color.g, color.b, strength))


func set_fade(amount: float) -> void:
	_set_all(&"fade", amount)


func set_dissolve(amount: float) -> void:
	_set_all(&"dissolve", amount)


## Unravels the body over `seconds`, then calls `done`.
func dissolve(seconds: float, done: Callable = Callable()) -> void:
	var tween := create_tween()
	tween.tween_method(set_dissolve, 0.0, 1.0, seconds).set_ease(Tween.EASE_IN)
	if done.is_valid():
		tween.tween_callback(done)


static func attachment_spec(slot: String) -> Dictionary:
	if _attachments.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/attachments.json"))
		if parsed is Dictionary:
			_attachments = parsed
	return _attachments.get(slot, {}) as Dictionary


func _bone_node(bone: String) -> Node3D:
	if _bone_nodes.has(bone):
		return _bone_nodes[bone] as Node3D
	var attachment := BoneAttachment3D.new()
	attachment.name = bone + "Attachment"
	attachment.bone_name = bone
	skeleton.add_child(attachment)
	_bone_nodes[bone] = attachment
	return attachment


func _collect_geometry() -> void:
	_geometry.clear()
	if model == null:
		return
	for node in model.find_children("*", "GeometryInstance3D", true, false):
		_geometry.append(node as GeometryInstance3D)


func _set_flash(amount: float) -> void:
	_flash = amount
	_set_all(&"flash", amount)


func _set_all(parameter: StringName, value: Variant) -> void:
	for geometry in _geometry:
		if is_instance_valid(geometry):
			geometry.set_instance_shader_parameter(parameter, value)


static func _vec(values: Array) -> Vector3:
	return Vector3(float(values[0]), float(values[1]), float(values[2]))
