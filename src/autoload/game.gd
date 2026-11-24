extends Node
## Global game state: the player, the current level and camera, the shared RNG,
## hit-stop, the XP curve, respawning and the world's remembered flags (opened
## chests, lit shrines, the sanctuary gate).

const LEVEL_SCENE := "res://src/world/elaion/elaion.tscn"
const TITLE_SCENE := "res://src/ui/title/title_screen.tscn"

var player: Player
var level: Node3D
var camera: GameCamera
var hud: CanvasLayer
var rng := RandomNumberGenerator.new()
var respawn_point := Vector3.ZERO
var flags: Dictionary = {}
var kills := 0
var started_msec := 0
var paused_by_ui := false

var _hit_stop_until := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()
	Events.actor_died.connect(_on_actor_died)


func _exit_tree() -> void:
	# Static caches would otherwise keep resources alive past exit.
	Vfx.clear_cache()
	player = null
	level = null
	camera = null
	hud = null


## XP needed to go from `level` to the next (data/progression.json).
static func xp_to_next(at_level: int) -> int:
	var curve := DB.progression.get("xp_curve", {}) as Dictionary
	return int(round(float(curve.get("base", 45.0)) * pow(float(at_level), float(curve.get("exponent", 1.5)))))


## A brief freeze on heavy hits (crits, kills): the hit lands harder.
func hit_stop(seconds: float = 0.045) -> void:
	var now := Time.get_ticks_msec()
	if now < _hit_stop_until:
		return
	_hit_stop_until = now + int(seconds * 1000.0) + 120
	Engine.time_scale = 0.05
	await get_tree().create_timer(seconds, true, false, true).timeout
	Engine.time_scale = 1.0


func shake(amount: float) -> void:
	if camera:
		camera.shake(amount)


func set_flag(key: String, value: Variant = true) -> void:
	flags[key] = value


func flag(key: String) -> bool:
	return bool(flags.get(key, false))


func new_game() -> void:
	flags.clear()
	kills = 0
	started_msec = Time.get_ticks_msec()
	get_tree().paused = false
	get_tree().change_scene_to_file(LEVEL_SCENE)


func to_title() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file(TITLE_SCENE)


func play_seconds() -> int:
	return int((Time.get_ticks_msec() - started_msec) / 1000.0)


func _on_actor_died(actor: Node3D, _killer: Node3D) -> void:
	if actor is Actor and (actor as Actor).faction == Actor.Faction.ENEMY:
		kills += 1
