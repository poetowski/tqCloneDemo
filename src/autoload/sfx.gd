extends Node
## Sound playback. Every sound is synthesized in Blender (tools/blender/audio/) into
## assets/audio/<name>.wav; a name with no file plays nothing, so code can ask for
## sounds before they exist. Pooled 2D players for UI, 3D players for the world,
## and two looping layers: music and ambience.

const AUDIO_DIR := "res://assets/audio/%s.wav"
const POOL_2D := 8
const POOL_3D := 24

var music_volume_db := -8.0
var _streams: Dictionary = {}
var _players_2d: Array[AudioStreamPlayer] = []
var _players_3d: Array[AudioStreamPlayer3D] = []
var _next_2d := 0
var _next_3d := 0
var _music: AudioStreamPlayer
var _ambience: AudioStreamPlayer
var _last_played: Dictionary = {}
## Headless runs (tests, tours) make no sound: nothing to hear, and playbacks that
## outlive a quick exit show up as leaks.
var _silent := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_silent = DisplayServer.get_name() == "headless"
	for i in POOL_2D:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players_2d.append(p)
	for i in POOL_3D:
		var p := AudioStreamPlayer3D.new()
		p.unit_size = 8.0
		p.max_distance = 45.0
		add_child(p)
		_players_3d.append(p)
	_music = AudioStreamPlayer.new()
	_music.volume_db = music_volume_db
	add_child(_music)
	_ambience = AudioStreamPlayer.new()
	_ambience.volume_db = -12.0
	add_child(_ambience)


## Stops everything before letting go of the streams: a playing stream's playback
## would otherwise outlive the audio server at exit.
func _exit_tree() -> void:
	for p: AudioStreamPlayer in _players_2d + [_music, _ambience]:
		p.stop()
		p.stream = null
	for p: AudioStreamPlayer3D in _players_3d:
		p.stop()
		p.stream = null
	_streams.clear()


func stream(sound: StringName) -> AudioStream:
	if _streams.has(sound):
		return _streams[sound] as AudioStream
	var s: AudioStream = null
	for path: String in [AUDIO_DIR % sound, (AUDIO_DIR % sound).replace(".wav", ".ogg")]:
		if ResourceLoader.exists(path):
			s = load(path) as AudioStream
			break
	_streams[sound] = s
	return s


## Music and ambience play forever.
func _looping(s: AudioStream) -> AudioStream:
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	elif s is AudioStreamWAV:
		var wav := s as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = int(wav.get_length() * wav.mix_rate)
	return s


## A UI or non-positional sound.
func play(sound: StringName, volume_db: float = 0.0, pitch_jitter: float = 0.04) -> void:
	if _silent:
		return
	var s := stream(sound)
	if s == null or _too_soon(sound):
		return
	var p := _players_2d[_next_2d]
	_next_2d = (_next_2d + 1) % POOL_2D
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()


## A sound in the world.
func play_at(sound: StringName, at: Vector3, volume_db: float = 0.0, pitch_jitter: float = 0.08) -> void:
	if _silent:
		return
	var s := stream(sound)
	if s == null or _too_soon(sound):
		return
	var p := _players_3d[_next_3d]
	_next_3d = (_next_3d + 1) % POOL_3D
	p.stream = s
	p.global_position = at
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()


func play_music(sound: StringName, fade: float = 1.5) -> void:
	_crossfade(_music, sound, music_volume_db, fade)


func play_ambience(sound: StringName, fade: float = 2.0) -> void:
	_crossfade(_ambience, sound, -12.0, fade)


func _crossfade(player: AudioStreamPlayer, sound: StringName, volume: float, fade: float) -> void:
	if _silent:
		return
	var s := stream(sound)
	if s == null or player.stream == s:
		return
	_looping(s)
	var tween := create_tween()
	if player.playing:
		tween.tween_property(player, "volume_db", -40.0, fade * 0.5)
	tween.tween_callback(func() -> void:
		player.stream = s
		player.volume_db = -40.0
		player.play())
	tween.tween_property(player, "volume_db", volume, fade * 0.5)


## The same sound at most every 40 ms, so a crowd's hits don't stack into noise.
func _too_soon(sound: StringName) -> bool:
	var now := Time.get_ticks_msec()
	if now - int(_last_played.get(sound, -1000)) < 40:
		return true
	_last_played[sound] = now
	return false
