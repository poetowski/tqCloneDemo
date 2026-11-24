extends Node
## Boot scene: hands over to the title screen, or straight to a scene given with
## --level=<res path> (used by shots and tests).


func _ready() -> void:
	var target := DevTools.option("level", Game.TITLE_SCENE)
	if not ResourceLoader.exists(target):
		target = Game.LEVEL_SCENE
	if target == Game.LEVEL_SCENE:
		Game.started_msec = Time.get_ticks_msec()
	get_tree().change_scene_to_file.call_deferred(target)
