class_name Projectile
extends Node3D
## A flying missile (ghost arrows, bull embers): moves straight, stops on the
## world, hurts the first foe of its source it passes.

const MODELS := "res://assets/models/items/%s/%s.glb"

var source: Actor
var info: DamageInfo
var velocity := Vector3.ZERO
var life := 2.2
var hit_radius := 0.35
var trail_color := Vfx.TEAL
var _hostile_group := &"player_team"


static func fire(from_actor: Actor, from: Vector3, at: Vector3, speed: float, damage: DamageInfo, model: String = "arrow") -> Projectile:
	var p := Projectile.new()
	p.source = from_actor
	p.info = damage
	p._hostile_group = &"player_team" if from_actor.faction == Actor.Faction.ENEMY else &"enemy_team"
	var path := MODELS % [model, model]
	if ResourceLoader.exists(path):
		p.add_child((load(path) as PackedScene).instantiate())
	Game.level.add_child(p)
	p.global_position = from
	p.velocity = (at - from).normalized() * speed
	p._orient()
	return p


func _orient() -> void:
	if velocity.length_squared() < 0.0001:
		return
	# Models point their tip up +Y; turn +Y along the flight.
	var up := velocity.normalized()
	var side := up.cross(Vector3.UP if absf(up.y) < 0.95 else Vector3.RIGHT).normalized()
	global_basis = Basis(side, up, side.cross(up))


func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	var from := global_position
	var to := from + velocity * delta
	var query := PhysicsRayQueryParameters3D.create(from, to, Actor.LAYER_WORLD | Actor.LAYER_TERRAIN)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		Vfx.sparks(hit["position"] as Vector3, trail_color, 5, 3.0)
		queue_free()
		return
	for node in get_tree().get_nodes_in_group(_hostile_group):
		var actor := node as Actor
		if actor == null or actor.is_dead:
			continue
		var chest := actor.global_position + Vector3.UP * 1.0
		var closest := Geometry3D.get_closest_point_to_segment(chest, from, to)
		if closest.distance_to(chest) <= hit_radius + actor.radius * 0.7:
			info.knockback = velocity.normalized() * 1.5
			info.knockback.y = 0.0
			actor.take_damage(info)
			Vfx.sparks(closest, trail_color, 8, 4.0)
			Sfx.play_at(&"hurt" if actor is Player else &"hit", closest)
			queue_free()
			return
	global_position = to
