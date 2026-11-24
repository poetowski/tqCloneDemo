class_name GroundItem
extends Node3D
## An item (or a pile of drachmae) lying on the ground: its model, its name in
## its rarity colour, a beam for the finest, and a click area. Click to pick it up;
## coins and draughts are taken just by walking over them.

const MODELS := "res://assets/models/items/%s/%s.glb"
const COIN_MODEL := "coins"
const AUTO_PICKUP_RADIUS := 1.3

var item: Item
var gold := 0
var interact_range := 1.8

var _label: Label3D
var _beam: MeshInstance3D
var _ready_to_take := false


static func spawn(the_item: Item, at: Vector3, from: Vector3, amount_gold: int = 0) -> GroundItem:
	var g := GroundItem.new()
	g.item = the_item
	g.gold = amount_gold
	Game.level.add_child(g)
	g.global_position = from + Vector3.UP * 0.8
	g._fly_to(at)
	return g


func _ready() -> void:
	add_to_group(&"interactable")
	add_to_group(&"ground_items")
	var area := Area3D.new()
	area.collision_layer = Actor.LAYER_INTERACT
	area.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, 0.6, 1.0)
	shape.shape = box
	shape.position.y = 0.3
	area.add_child(shape)
	add_child(area)
	var slug := COIN_MODEL if gold > 0 else item.model_slug()
	var path := MODELS % [slug, slug]
	if ResourceLoader.exists(path):
		var model := (load(path) as PackedScene).instantiate() as Node3D
		add_child(model)
		_lay_down(model)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.fixed_size = true
	_label.pixel_size = 0.0011
	_label.font_size = 22
	_label.outline_size = 8
	_label.outline_modulate = Color(0.06, 0.04, 0.03, 0.9)
	_label.position = Vector3(0, 0.75, 0)
	_label.text = ("%d drachmae" % gold) if gold > 0 else item.display_name()
	_label.modulate = Color("#E8C547") if gold > 0 else item.color()
	add_child(_label)
	if item and (item.rarity >= Item.Rarity.HEROIC or item.is_quest()):
		_beam = Vfx.beam(global_position, item.color(), 0.18, 5.0, 0.0)
		_beam.reparent(self)
		_beam.position = Vector3.ZERO


## Weapons lie flat; everything else sits upright, turned at random.
func _lay_down(model: Node3D) -> void:
	model.rotation.y = randf() * TAU
	if item and item.slot() == "weapon":
		model.rotation = Vector3(PI * 0.5, randf() * TAU, 0.0)
		model.position.y = 0.06
	elif item and item.slot() == "shield":
		model.rotation = Vector3(-PI * 0.5, randf() * TAU, 0.0)
		model.position.y = 0.08
	elif item and item.slot() == "head":
		model.position.y = -0.08


func _fly_to(at: Vector3) -> void:
	# Land where the hero can walk: never on a wall top or a column.
	var map := get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(map) > 0:
		var walkable := NavigationServer3D.map_get_closest_point(map, at)
		if walkable.distance_to(at) < 8.0:
			at = walkable
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 4.0, at + Vector3.DOWN * 6.0, Actor.LAYER_TERRAIN | Actor.LAYER_WORLD)
	var hit := space.intersect_ray(query)
	var land := (hit["position"] as Vector3) if not hit.is_empty() else at
	var start := global_position
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void:
		global_position = start.lerp(land, t) + Vector3.UP * sin(t * PI) * 1.4, 0.0, 1.0, 0.45)
	tween.tween_callback(func() -> void:
		_ready_to_take = true
		Sfx.play_at(&"drop_gold" if gold > 0 else &"drop_item", global_position))


func _physics_process(_delta: float) -> void:
	if not _ready_to_take or Game.player == null or Game.player.is_dead:
		return
	var auto := gold > 0 or (item and item.is_potion())
	if auto and global_position.distance_to(Game.player.global_position) < AUTO_PICKUP_RADIUS:
		interact(Game.player)


func _process(_delta: float) -> void:
	if _label and item and item.rarity == Item.Rarity.MORTAL and not item.is_potion():
		_label.visible = Input.is_action_pressed(&"show_loot") or Game.player == null or Game.player.hovered == self \
			or global_position.distance_to(Game.player.global_position) < 9.0


func interact(player: Player) -> void:
	if not _ready_to_take:
		return
	if player.pick_up(item, gold):
		_ready_to_take = false
		queue_free()
