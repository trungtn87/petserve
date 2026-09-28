class_name CatPet2D
extends PetActor
## Presentation only: no simulation/save mutations and no element-specific branches.
signal action_finished(action_id: StringName)
var profile: CatPresentationProfile
var action: StringName = &"idle"
var _expression: StringName = PetState.STATE_NEUTRAL
var _action_remaining: float = 0.0
var _pivots: Dictionary = {}
var _sprites: Dictionary = {}
var _bases: Dictionary = {}
var _textures: Dictionary = {}
var _motion := CatMotionController.new()
var _face := CatFaceController.new()
var _groups: Dictionary = {}
var _last_tap_ms: int = -1000

func _ready() -> void:
	for group_name: String in ["BackFX", "Tail", "Body", "Head", "Face", "FrontFX"]:
		_groups[group_name] = get_node("VisualRoot/" + group_name)

func _on_definition_applied(definition: PetDefinition) -> void:
	set_profile(definition.presentation_profile as CatPresentationProfile)

func set_profile(value: CatPresentationProfile) -> bool:
	if value == null or not value.is_valid():
		push_error("CatPet2D requires a valid CatPresentationProfile.")
		return false
	for group: Node2D in _groups.values():
		for child: Node in group.get_children():
			child.free()
	_pivots.clear()
	_sprites.clear()
	_bases.clear()
	_textures.clear()
	profile = value
	scale = Vector2.ONE * profile.display_scale
	# Build in two passes: profile ordering never constrains parent references.
	for key: StringName in profile.parts:
		var part: Dictionary = profile.parts[key]
		var pivot := Node2D.new()
		pivot.name = str(key)
		pivot.z_index = int(part.get("z", 0))
		pivot.position = part.get("pivot", Vector2.ZERO)
		_pivots[key] = pivot
		_bases[key] = pivot.position
		var sprite := Sprite2D.new()
		sprite.texture = profile.texture_for(part["region"])
		sprite.position = part.get("offset", Vector2.ZERO)
		sprite.scale = Vector2.ONE * float(part.get("width", 100.0)) / sprite.texture.get_width()
		pivot.add_child(sprite)
		_sprites[key] = sprite
		_textures[key] = sprite.texture
	for key: StringName in profile.parts:
		var part: Dictionary = profile.parts[key]
		var parent_key: StringName = part.get("parent", &"")
		var parent_node: Node2D = _pivots.get(parent_key, _groups.get(part.get("group", "Body")))
		parent_node.add_child(_pivots[key])
	for key: StringName in profile.variants:
		_textures[key] = profile.texture_for(profile.variants[key])
	_face.reset(profile)
	return true

func play_action(action_id: StringName) -> bool:
	if profile == null or not action_id in [&"idle", &"eat", &"lie", &"sleep", &"wake"]:
		return false
	if action_id == &"eat" and not has_capability(&"eat"):
		return false
	if action_id in [&"sleep", &"lie"] and not has_capability(action_id):
		return false
	action = &"idle" if action_id == &"wake" else action_id
	_action_remaining = profile.eat_seconds if action == &"eat" else 0.0
	return true

func _on_state_presented(state_id: StringName) -> void:
	_expression = state_id

func _process(delta: float) -> void:
	if profile == null:
		return
	if _action_remaining > 0.0:
		_action_remaining = maxf(0.0, _action_remaining - delta)
		if _action_remaining == 0.0:
			var finished: StringName = action
			action = &"idle"
			action_finished.emit(finished)
	_motion.tick(delta, action, _expression, profile, _pivots, _bases)
	var body: Sprite2D = _sprites.get(&"body")
	var lying: bool = action in [&"lie", &"sleep"]
	if body != null:
		body.texture = _textures.get(&"body_lie", _textures[&"body"]) if lying else _textures[&"body"]
		var width: float = profile.parts[&"body"].get("width", 250.0)
		body.scale = Vector2.ONE * width / body.texture.get_width()
		body.position.y = -body.texture.get_height() * body.scale.y * 0.5
	_face.tick(delta, self, action, _expression, profile, _sprites, _pivots, _textures)

func _unhandled_input(event: InputEvent) -> void:
	if profile == null or not has_capability(&"tap_reaction"):
		return
	var pressed: bool = false
	var point := Vector2.ZERO
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = event.pressed
		point = event.position
	elif event is InputEventScreenTouch:
		pressed = event.pressed
		point = event.position
	if not pressed:
		return
	var local_point: Vector2 = get_global_transform_with_canvas().affine_inverse() * point
	if not profile.hit_rect.has_point(local_point):
		return
	get_viewport().set_input_as_handled()
	var now: int = Time.get_ticks_msec()
	if now - _last_tap_ms < 180:
		return
	_last_tap_ms = now
	play_action(&"wake")
	_motion.react()
	notify_tapped()
