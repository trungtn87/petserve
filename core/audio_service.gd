extends Node

const MUSIC = preload("res://assets/audio/quiet_arcade.ogg")
var settings: Dictionary = {}
var _music: AudioStreamPlayer
var _voices: Array[AudioStreamPlayer] = []
var _sounds: Dictionary = {}
var _voice := 0
var _last_sound := -1000
var _last_transition := -1000
var _last_kind := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus_name in ["Music", "UI"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
	for kind in ["click", "open", "close", "reward", "win", "lose"]:
		_sounds[kind] = _tone(kind)
	for i in 4:
		var player := AudioStreamPlayer.new()
		player.bus = "UI"
		add_child(player)
		_voices.append(player)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	_music.stream = MUSIC
	_music.volume_db = -7
	add_child(_music)
	_music.finished.connect(_music.play)
	reload_settings()
	_music.play()
	get_tree().node_added.connect(_hook_deferred)
	_scan(get_tree().root)

func reload_settings() -> void:
	settings = AtomicJson.read("user://settings_v1.json")
	_apply_settings()

func set_setting(key: String, value: Variant) -> bool:
	# Merge with current settings so backup and future options are preserved.
	var updated := AtomicJson.read("user://settings_v1.json")
	updated[key] = value
	if not AtomicJson.write("user://settings_v1.json", updated):
		return false
	settings = updated
	_apply_settings()
	return true

func _apply_settings() -> void:
	AudioServer.set_bus_mute(0, not bool(settings.get("sound", true)))
	for pair in [["Music", "music", "music_volume", 0.45], ["UI", "effects", "effects_volume", 0.65]]:
		var index := AudioServer.get_bus_index(pair[0])
		var volume := clampf(float(settings.get(pair[2], pair[3])), 0.0, 1.0)
		AudioServer.set_bus_mute(index, not bool(settings.get(pair[1], true)) or volume <= 0.0)
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume, 0.001)))

func play(kind: String = "click") -> void:
	if _voices.is_empty() or not _sounds.has(kind):
		return
	var now := Time.get_ticks_msec()
	if kind == _last_kind and now - _last_sound < 90:
		return
	if kind in ["open", "close"]:
		if now - _last_transition < 90:
			return
		_last_transition = now
	elif kind == "click" and (now - _last_sound < 45 or now - _last_transition < 90):
		return
	_last_sound = now
	_last_kind = kind
	var player := _voices[_voice % _voices.size()]
	_voice += 1
	player.stream = _sounds[kind]
	player.play()

func _hook_deferred(node: Node) -> void:
	_hook.call_deferred(node)

func _scan(node: Node) -> void:
	_hook(node)
	for child in node.get_children():
		_scan(child)

func _hook(node: Node) -> void:
	if not is_instance_valid(node) or node.has_meta("audio_hooked"):
		return
	node.set_meta("audio_hooked", true)
	if node is BaseButton:
		node.pressed.connect(play.bind("click"))
	if node is OptionButton:
		node.item_selected.connect(func(_index: int) -> void: play("click"))
	if node.has_signal("action_pressed"):
		node.connect("action_pressed", func(_action: String) -> void: play("click"))
	if node.has_signal("cell_selected"):
		node.connect("cell_selected", func(_index: int) -> void: play("click"))
	if node.has_signal("match_finished"):
		node.connect("match_finished", func(result: StringName) -> void: play("win" if result == &"win" else "lose"))
	if node.has_signal("reward_received"):
		node.connect("reward_received", play.bind("reward"))
	if node is Window:
		node.visibility_changed.connect(func() -> void: play("open" if node.visible else "close"))

func _notification(what: int) -> void:
	if _music == null:
		return
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		_music.stream_paused = true
		for voice in _voices:
			voice.stop()
	elif what in [NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN]:
		_music.stream_paused = false

func _tone(kind: String) -> AudioStreamWAV:
	var notes: Array = {"click": [880.0], "open": [523.25, 659.25], "close": [659.25, 440.0], "reward": [523.25, 659.25, 783.99], "win": [523.25, 659.25, 783.99, 1046.5], "lose": [440.0, 349.23]}[kind]
	var duration := 0.045 if kind == "click" else 0.11
	var rate := 22050
	var frames := int(rate * duration * notes.size())
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in frames:
		var t := float(i) / rate
		var phase := fmod(t, duration)
		var frequency: float = notes[mini(int(t / duration), notes.size() - 1)]
		var envelope := minf(phase / 0.004, 1.0) * pow(maxf(0.0, 1.0 - phase / duration), 2.0)
		var sample := (sin(TAU * frequency * t) + 0.18 * sin(TAU * frequency * 2 * t)) * envelope * 0.18
		data.encode_s16(i * 2, int(sample * 32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = data
	return stream
