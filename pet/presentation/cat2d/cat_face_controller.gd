class_name CatFaceController
extends RefCounted
var _rng := RandomNumberGenerator.new()
var _until_blink: float = 3.0
var _blink_time: float = -1.0
var _look := Vector2.ZERO

func _init() -> void:
	_rng.randomize()

func reset(profile: CatPresentationProfile) -> void:
	_until_blink = _rng.randf_range(profile.blink_range.x, profile.blink_range.y)
	_blink_time = -1.0
	_look = Vector2.ZERO

func tick(delta: float, actor: PetActor, action: StringName, expression: StringName, profile: CatPresentationProfile, sprites: Dictionary, pivots: Dictionary, textures: Dictionary) -> void:
	_until_blink -= delta
	if _until_blink <= 0.0:
		_blink_time = 0.0
		_until_blink = _rng.randf_range(profile.blink_range.x, profile.blink_range.y)
	if _blink_time >= 0.0:
		_blink_time += delta
		if _blink_time > 0.18:
			_blink_time = -1.0
	var closed: bool = action == &"sleep" or _blink_time >= 0.0
	var target: Vector2 = actor.get_local_mouse_position() - Vector2(profile.parts[&"head"].get("pivot", Vector2.ZERO))
	if not actor.has_capability(&"look_target"):
		target = Vector2.ZERO
	_look = _look.lerp(target.limit_length(profile.look_radius), 1.0 - exp(-delta * 6.0))
	for key: StringName in [&"eye_left", &"eye_right"]:
		var eye: Sprite2D = sprites.get(key)
		if eye == null:
			continue
		var alternate := StringName(str(key) + "_closed")
		var use_closed: bool = closed and textures.has(alternate)
		eye.texture = textures[alternate] if use_closed else textures[key]
		_fit(eye, profile.parts[key].get("width", 80.0))
		if use_closed:
			eye.scale.y *= 0.5
		elif expression == PetState.STATE_SLEEPY:
			eye.scale.y *= 0.65
		elif expression == PetState.STATE_SURPRISED:
			eye.scale *= 1.06
		var pivot: Node2D = pivots[key]
		if not closed:
			pivot.position += _look
	var mouth: Sprite2D = sprites.get(&"mouth")
	if mouth != null:
		var variant: StringName = &"mouth"
		if action == &"eat":
			variant = &"mouth_eat"
		elif expression == PetState.STATE_HAPPY:
			variant = &"mouth_happy"
		mouth.texture = textures.get(variant, textures[&"mouth"])
		_fit(mouth, profile.parts[&"mouth"].get("width", 32.0))
		if action == &"eat":
			mouth.scale.y *= 0.7 + sin(Time.get_ticks_msec() * 0.012) * 0.25

func _fit(sprite: Sprite2D, width: float) -> void:
	sprite.scale = Vector2.ONE * width / maxf(sprite.texture.get_width(), 1.0)
