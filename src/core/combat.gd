class_name Combat
extends RefCounted
## Finding who a blow reaches. Works on the actor groups (a few dozen actors at
## most), measured on the ground plane, counting each victim's radius.


## Living actors hostile to `source` within `radius` of `center`.
static func in_radius(source: Actor, center: Vector3, radius: float) -> Array[Actor]:
	var found: Array[Actor] = []
	for actor in _hostiles(source):
		var d := Vector2(actor.global_position.x - center.x, actor.global_position.z - center.z).length()
		if d <= radius + actor.radius:
			found.append(actor)
	return found


## Living hostile actors within `radius` and `half_angle` degrees of `direction`.
static func in_cone(source: Actor, center: Vector3, direction: Vector3, radius: float, half_angle: float) -> Array[Actor]:
	var found: Array[Actor] = []
	var dir := Vector2(direction.x, direction.z).normalized()
	var limit := cos(deg_to_rad(half_angle))
	for actor in _hostiles(source):
		var to := Vector2(actor.global_position.x - center.x, actor.global_position.z - center.z)
		var d := to.length()
		if d > radius + actor.radius:
			continue
		if d < actor.radius + 0.3 or to.normalized().dot(dir) >= limit:
			found.append(actor)
	found.sort_custom(func(a: Actor, b: Actor) -> bool: return a.global_position.distance_squared_to(center) < b.global_position.distance_squared_to(center))
	return found


## Living hostile actors within `width` / 2 of the segment a→b.
static func along(source: Actor, a: Vector3, b: Vector3, width: float) -> Array[Actor]:
	var found: Array[Actor] = []
	var p := Vector2(a.x, a.z)
	var q := Vector2(b.x, b.z)
	for actor in _hostiles(source):
		var c := Vector2(actor.global_position.x, actor.global_position.z)
		var closest := Geometry2D.get_closest_point_to_segment(c, p, q)
		if closest.distance_to(c) <= width * 0.5 + actor.radius:
			found.append(actor)
	return found


## The closest living hostile actor within `radius`, or null.
static func nearest(source: Actor, center: Vector3, radius: float) -> Actor:
	var best: Actor = null
	var best_d := radius
	for actor in _hostiles(source):
		var d := actor.global_position.distance_to(center)
		if d < best_d:
			best_d = d
			best = actor
	return best


static func _hostiles(source: Actor) -> Array[Actor]:
	var group := &"enemy_team" if source.faction == Actor.Faction.PLAYER else &"player_team"
	var out: Array[Actor] = []
	for node in source.get_tree().get_nodes_in_group(group):
		var actor := node as Actor
		if actor and actor.is_targetable():
			out.append(actor)
	return out
