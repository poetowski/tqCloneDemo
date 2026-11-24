extends Node
## Development helpers, active in every build for now (it's a demo):
## - `--shot=<png>` on the command line (npm run shot) plays a few frames, saves a
##   screenshot and quits. Options: --shot-frames, --shot-camera=x,y,z with
##   --shot-look=x,y,z, --shot-player=x,y,z, --shot-scenario=<name>, --shot-zoom,
##   --shot-yaw.
## - F12 saves a screenshot to .shots/, F3 toggles the debug overlay, F5 levels up.

signal scenario_requested(scenario: String)

var options: Dictionary = {}
var _shot_path := ""
var _frames_left := -1
var _overlay: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			var key := arg.substr(2, arg.find("=") - 2)
			options[key] = arg.substr(arg.find("=") + 1)
	if options.has("shot"):
		_shot_path = String(options["shot"])
		_frames_left = int(options.get("shot-frames", "90"))
		# The scene is ready one frame after the autoloads.
		_prepare_shot.call_deferred()


func has_option(key: String) -> bool:
	return options.has(key)


func option(key: String, fallback: String = "") -> String:
	return String(options.get(key, fallback))


## A Vector3 from an "x,y,z" option, or `fallback`.
func vector_option(key: String, fallback: Vector3) -> Vector3:
	if not options.has(key):
		return fallback
	var parts := String(options[key]).split(",")
	if parts.size() != 3:
		return fallback
	return Vector3(float(parts[0]), float(parts[1]), float(parts[2]))


func _prepare_shot() -> void:
	await get_tree().process_frame
	if options.has("shot-player") and Game.player:
		Game.player.global_position = vector_option("shot-player", Game.player.global_position)
		Game.player.input_enabled = true
		if Game.camera:
			Game.camera.snap()
	if options.has("shot-scenario"):
		scenario_requested.emit(String(options["shot-scenario"]))
	if options.has("shot-camera"):
		var camera := Camera3D.new()
		camera.name = "ShotCamera"
		camera.fov = 40.0
		camera.far = 600.0
		get_tree().current_scene.add_child(camera)
		camera.global_position = vector_option("shot-camera", Vector3(0, 10, 10))
		camera.look_at(vector_option("shot-look", Vector3.ZERO))
		camera.make_current()


func _process(_delta: float) -> void:
	if _frames_left > 0:
		_frames_left -= 1
		if _frames_left == 0:
			_capture_and_quit()
	if _overlay and _overlay.visible:
		_overlay.text = _overlay_text()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and _shot_path != "":
		print("[shot] window close requested at %.1f s" % (Time.get_ticks_msec() / 1000.0))
	elif what == NOTIFICATION_PREDELETE and _shot_path != "":
		print("[shot] DevTools freed at %.1f s (frames left %d)" % [Time.get_ticks_msec() / 1000.0, _frames_left])


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"dev_screenshot"):
		var dir := ProjectSettings.globalize_path("res://.shots")
		DirAccess.make_dir_recursive_absolute(dir)
		var stamp := Time.get_datetime_string_from_system().replace(":", "-")
		_save_viewport(dir.path_join("f12_%s.png" % stamp))
	elif event.is_action_pressed(&"dev_overlay"):
		_toggle_overlay()


## Ends a shot run now (a scenario reached its goal before the frame count).
func finish_shot() -> void:
	if _shot_path != "" and _frames_left > 0:
		_frames_left = -1
		_capture_and_quit()


func _capture_and_quit() -> void:
	print("[shot] capturing after %.1f s" % (Time.get_ticks_msec() / 1000.0))
	Engine.time_scale = 1.0
	# Headless runs (npm run tour) have nothing to photograph; they report in text.
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		_save_viewport(_shot_path)
	_log_actors()
	get_tree().quit()


## Prints every actor's place and state with the shot, for checking AI by text.
func _log_actors() -> void:
	for node in get_tree().get_nodes_in_group(&"actors"):
		var actor := node as Node3D
		var p := actor.global_position
		var details := ""
		if actor.get(&"health") != null:
			details += " hp %.0f" % float(actor.get(&"health"))
		if actor.get(&"state") != null:
			details += " state %d" % int(actor.get(&"state"))
		if actor.get(&"is_dead") != null and bool(actor.get(&"is_dead")):
			details += " dead"
		print("[shot] %s at (%.1f, %.1f, %.1f) visible %s%s" % [actor.name, p.x, p.y, p.z, actor.is_visible_in_tree(), details])


func _save_viewport(path: String) -> void:
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	if error != OK:
		push_error("could not save screenshot to %s (%s)" % [path, error_string(error)])
	else:
		print("[shot] saved ", path)


func _toggle_overlay() -> void:
	if _overlay == null:
		var layer := CanvasLayer.new()
		layer.layer = 100
		add_child(layer)
		_overlay = Label.new()
		_overlay.position = Vector2(12, 12)
		_overlay.add_theme_color_override(&"font_color", Color(1, 1, 0.8))
		_overlay.add_theme_color_override(&"font_outline_color", Color.BLACK)
		_overlay.add_theme_constant_override(&"outline_size", 4)
		layer.add_child(_overlay)
		_overlay.visible = false
	_overlay.visible = not _overlay.visible


func _overlay_text() -> String:
	var lines: Array[String] = []
	lines.append("FPS %d" % Engine.get_frames_per_second())
	lines.append("draw calls %d" % RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	lines.append("objects %d" % RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME))
	lines.append("primitives %d" % RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if player:
		lines.append("player %.1f, %.1f, %.1f" % [player.global_position.x, player.global_position.y, player.global_position.z])
	return "\n".join(lines)
