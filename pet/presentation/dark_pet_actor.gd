class_name DarkPetActor
extends PetActor

const RUNTIME_TEXTURE_PATH: String = "res://assets/pets/dark/runtime/dark_pet_base.png"
const BASE_VISUAL_SCALE: float = 0.4104

@onready var visual_root: Node2D = $VisualRoot
@onready var visual_sprite: Sprite2D = $VisualRoot/VisualSprite
@onready var placeholder_root: Node2D = $VisualRoot/PlaceholderRoot
@onready var body: Polygon2D = $VisualRoot/PlaceholderRoot/Body
@onready var tail: Polygon2D = $VisualRoot/PlaceholderRoot/Tail
@onready var left_ear: Polygon2D = $VisualRoot/PlaceholderRoot/LeftEar
@onready var right_ear: Polygon2D = $VisualRoot/PlaceholderRoot/RightEar
@onready var face: Node2D = $VisualRoot/PlaceholderRoot/Face
@onready var left_eye: Polygon2D = $VisualRoot/PlaceholderRoot/Face/LeftEye
@onready var right_eye: Polygon2D = $VisualRoot/PlaceholderRoot/Face/RightEye
@onready var expression_root: Node2D = $ExpressionRoot
@onready var left_lid: Polygon2D = $ExpressionRoot/LeftLid
@onready var right_lid: Polygon2D = $ExpressionRoot/RightLid
@onready var happy_mouth: Polygon2D = $ExpressionRoot/HappyMouth
@onready var surprise_mouth: Polygon2D = $ExpressionRoot/SurpriseMouth

var _time: float = 0.0
var _reaction_tween: Tween = null
var _using_runtime_art: bool = false
var _blink_elapsed: float = 0.0
var _next_blink_delay: float = 2.8
var _blink_tween: Tween = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	_schedule_next_blink()
	_apply_runtime_art_if_available()
	$InteractionArea.input_event.connect(_on_interaction_input)

func _process(delta: float) -> void:
	_time += delta
	_blink_elapsed += delta
	var breathe: float = sin(_time * 2.0) * 2.2
	visual_root.position.y = -38.0 + breathe
	expression_root.position.y = visual_root.position.y
	visual_root.rotation = deg_to_rad(sin(_time * 0.8) * 0.7)
	expression_root.rotation = visual_root.rotation
	if not _using_runtime_art:
		tail.rotation = deg_to_rad(sin(_time * 1.7) * 7.0)
		left_ear.rotation = deg_to_rad(sin(_time * 1.3) * 1.5)
		right_ear.rotation = deg_to_rad(-sin(_time * 1.3) * 1.5)
	if _blink_elapsed >= _next_blink_delay:
		_blink_elapsed = 0.0
		_schedule_next_blink()
		_play_blink()

func _apply_runtime_art_if_available() -> void:
	if not ResourceLoader.exists(RUNTIME_TEXTURE_PATH):
		visual_sprite.visible = false
		placeholder_root.visible = true
		expression_root.visible = false
		return
	var texture: Texture2D = load(RUNTIME_TEXTURE_PATH) as Texture2D
	if texture == null:
		return
	visual_sprite.texture = texture
	visual_sprite.visible = true
	placeholder_root.visible = false
	expression_root.visible = true
	_using_runtime_art = true

func _schedule_next_blink() -> void:
	_next_blink_delay = _rng.randf_range(2.2, 5.0)

func _play_blink() -> void:
	if _blink_tween != null:
		_blink_tween.kill()
	_blink_tween = create_tween()
	if _using_runtime_art:
		left_lid.visible = true
		right_lid.visible = true
		left_lid.scale.y = 0.05
		right_lid.scale.y = 0.05
		_blink_tween.set_parallel(true)
		_blink_tween.tween_property(left_lid, "scale:y", 1.0, 0.065)
		_blink_tween.tween_property(right_lid, "scale:y", 1.0, 0.065)
		_blink_tween.set_parallel(false)
		_blink_tween.tween_interval(0.045)
		_blink_tween.set_parallel(true)
		_blink_tween.tween_property(left_lid, "scale:y", 0.05, 0.075)
		_blink_tween.tween_property(right_lid, "scale:y", 0.05, 0.075)
		_blink_tween.set_parallel(false)
		_blink_tween.tween_callback(_hide_blink_layers)
	else:
		_blink_tween.set_parallel(true)
		_blink_tween.tween_property(left_eye, "scale:y", 0.08, 0.055)
		_blink_tween.tween_property(right_eye, "scale:y", 0.08, 0.055)
		_blink_tween.set_parallel(false)
		_blink_tween.set_parallel(true)
		_blink_tween.tween_property(left_eye, "scale:y", 1.0, 0.085)
		_blink_tween.tween_property(right_eye, "scale:y", 1.0, 0.085)

func _hide_blink_layers() -> void:
	left_lid.visible = false
	right_lid.visible = false

func _on_state_presented(state_id: StringName) -> void:
	_reset_pose()
	match state_id:
		PetState.STATE_HAPPY:
			happy_mouth.visible = _using_runtime_art
			_play_happy_reaction()
		PetState.STATE_CURIOUS:
			visual_root.rotation += deg_to_rad(-4.0)
			expression_root.rotation = visual_root.rotation
		PetState.STATE_SURPRISED:
			surprise_mouth.visible = _using_runtime_art
		PetState.STATE_SLEEPY:
			if _using_runtime_art:
				left_lid.visible = true
				right_lid.visible = true
				left_lid.scale.y = 0.72
				right_lid.scale.y = 0.72
			else:
				left_eye.scale.y = 0.25
				right_eye.scale.y = 0.25

func _play_happy_reaction() -> void:
	if _reaction_tween != null:
		_reaction_tween.kill()
	_reaction_tween = create_tween()
	_reaction_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_reaction_tween.tween_property(visual_root, "position:y", visual_root.position.y - 8.0, 0.12)
	_reaction_tween.tween_property(visual_root, "position:y", -38.0, 0.22)

func _on_interaction_input(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		notify_tapped()
	elif event is InputEventScreenTouch and event.pressed:
		notify_tapped()

func _reset_pose() -> void:
	happy_mouth.visible = false
	surprise_mouth.visible = false
	_hide_blink_layers()
	if not _using_runtime_art:
		face.position = Vector2(0.0, -32.0)
		left_eye.scale = Vector2.ONE
		right_eye.scale = Vector2.ONE
