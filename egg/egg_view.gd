extends Control
class_name EggView


signal egg_tapped
signal egg_pressed
signal egg_released
signal hatch_effect_finished
signal hatch_whiteout

var egg_type: String = "unknown"
var egg_stage: int = 1

var egg_texture: TextureRect

var _is_pressed: bool = false
var _is_hatch_effect_playing: bool = false


func _ready() -> void:
	# Vùng EggView cao hơn ảnh trứng.
	# Phần trống phía dưới dùng để đẩy toàn bộ
	# StatusLabel + HatchTaskLabel xuống khung thông tin.
	custom_minimum_size = Vector2(320, 325)

	mouse_filter = Control.MOUSE_FILTER_STOP

	_create_ui()

	set_egg({
		"egg_type": "unknown",
		"egg_stage": 1
	})


# =========================================================
# UI
# =========================================================

func _create_ui() -> void:
	for child in get_children():
		child.queue_free()


	egg_texture = TextureRect.new()
	egg_texture.name = "EggTexture"

	egg_texture.position = Vector2(64, 54)
	egg_texture.size = Vector2(192, 192)
	egg_texture.pivot_offset = Vector2(96, 96)
	egg_texture.custom_minimum_size = Vector2(192, 192)
	egg_texture.expand_mode = (
		TextureRect.EXPAND_IGNORE_SIZE
	)

	egg_texture.stretch_mode = (
		TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	)

	# Input được xử lý bởi EggView cha.
	egg_texture.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	add_child(
		egg_texture
	)


# =========================================================
# INPUT
# =========================================================

func _gui_input(
	event: InputEvent
) -> void:

	# =========================
	# MOUSE
	# =========================

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:

			if event.pressed:
				_is_pressed = true

				egg_pressed.emit()

				_play_press_motion()

				accept_event()

			else:
				if _is_pressed:
					_is_pressed = false

					egg_released.emit()
					egg_tapped.emit()

					_play_release_motion()

					accept_event()


	# =========================
	# TOUCH
	# =========================

	if event is InputEventScreenTouch:

		if event.pressed:
			_is_pressed = true

			egg_pressed.emit()

			_play_press_motion()

			accept_event()

		else:
			if _is_pressed:
				_is_pressed = false

				egg_released.emit()
				egg_tapped.emit()

				_play_release_motion()

				accept_event()


# =========================================================
# EGG DATA
# =========================================================

func set_egg(
	data: Dictionary
) -> void:

	egg_type = str(
		data.get(
			"egg_type",
			data.get(
				"type",
				"unknown"
			)
		)
	)


	egg_stage = int(
		data.get(
			"egg_stage",
			data.get(
				"stage",
				1
			)
		)
	)


	egg_stage = clamp(
		egg_stage,
		1,
		4
	)


	_refresh()


func clear_egg() -> void:
	egg_type = "unknown"
	egg_stage = 1

	_is_pressed = false


	if egg_texture != null:
		egg_texture.texture = null

		egg_texture.scale = Vector2.ONE
		egg_texture.rotation = 0.0


# =========================================================
# REFRESH
# =========================================================

func _refresh() -> void:
	if egg_texture == null:
		return


	var path: String = (
		_get_texture_path()
	)


	print(
		"EggView load: ",
		path
	)


	if not ResourceLoader.exists(
		path
	):
		push_error(
			"EggView: Không tìm thấy ảnh: "
			+ path
		)

		egg_texture.texture = null

		return


	var texture: Texture2D = load(
		path
	)


	if texture == null:
		push_error(
			"EggView: Load ảnh thất bại: "
			+ path
		)

		egg_texture.texture = null

		return


	egg_texture.texture = texture


# =========================================================
# TEXTURE PATH
# =========================================================

func _get_texture_path() -> String:

	# Stage 1 dùng chung một ảnh.
	if egg_stage == 1:
		return (
			"res://assets/eggs/"
			+ "stage_1/common.png"
		)


	var normalized: String = (
		_normalize_type(
			egg_type
		)
	)


	return (
		"res://assets/eggs/"
		+ "stage_%d/%s.png"
		% [
			egg_stage,
			normalized
		]
	)


# =========================================================
# EGG TYPE
# =========================================================

func _normalize_type(
	value: String
) -> String:

	var result: String = (
		value
		.strip_edges()
		.to_lower()
	)


	match result:

		"kim", "metal":
			return "metal"


		"mộc", "moc", "wood":
			return "wood"


		"thủy", "thuy", "water":
			return "water"


		"hỏa", "hoa", "fire":
			return "fire"


		"thổ", "tho", "earth":
			return "earth"


		"ám", "am", "dark":
			return "dark"


		"quang", "light":
			return "light"


		_:
			return result


# =========================================================
# MOTION
# =========================================================

func _play_press_motion() -> void:
	if egg_texture == null:
		return


	var tween: Tween = create_tween()

	tween.set_parallel(
		true
	)


	tween.tween_property(
		egg_texture,
		"scale",
		Vector2(
			0.94,
			0.94
		),
		0.08
	)


	tween.tween_property(
		egg_texture,
		"rotation",
		deg_to_rad(
			-3.0
		),
		0.08
	)


func _play_release_motion() -> void:
	if egg_texture == null:
		return


	var tween: Tween = create_tween()

	tween.set_parallel(
		true
	)


	tween.tween_property(
		egg_texture,
		"scale",
		Vector2.ONE,
		0.12
	).set_trans(
		Tween.TRANS_BACK
	)


	tween.tween_property(
		egg_texture,
		"rotation",
		0.0,
		0.12
	).set_trans(
		Tween.TRANS_BACK
	)
# =========================================================
# HATCH EFFECT
# =========================================================

func play_hatch_effect() -> void:
	if _is_hatch_effect_playing:
		return

	if egg_texture == null:
		return

	_is_hatch_effect_playing = true
	_is_pressed = false

	mouse_filter = Control.MOUSE_FILTER_IGNORE

	egg_texture.scale = Vector2.ONE
	egg_texture.rotation = 0.0

	await _play_hatch_shake()
	await _play_hatch_glow()

	egg_texture.scale = Vector2.ONE
	egg_texture.rotation = 0.0

	mouse_filter = Control.MOUSE_FILTER_STOP

	_is_hatch_effect_playing = false

	hatch_effect_finished.emit()


func _play_hatch_shake() -> void:
	var tween: Tween = create_tween()

	tween.tween_property(
		egg_texture,
		"rotation",
		deg_to_rad(-5.0),
		0.07
	)

	tween.tween_property(
		egg_texture,
		"rotation",
		deg_to_rad(5.0),
		0.07
	)

	tween.tween_property(
		egg_texture,
		"rotation",
		deg_to_rad(-8.0),
		0.06
	)

	tween.tween_property(
		egg_texture,
		"rotation",
		deg_to_rad(8.0),
		0.06
	)

	tween.tween_property(
		egg_texture,
		"rotation",
		deg_to_rad(-11.0),
		0.05
	)

	tween.tween_property(
		egg_texture,
		"rotation",
		deg_to_rad(11.0),
		0.05
	)

	tween.tween_property(
		egg_texture,
		"rotation",
		0.0,
		0.05
	)

	await tween.finished


func _play_hatch_glow() -> void:
	if egg_texture == null:
		return


	egg_texture.rotation = 0.0
	egg_texture.scale = Vector2.ONE
	egg_texture.modulate = Color.WHITE


	# =====================================================
	# 1. CHARGE
	# Trứng phồng nhẹ trước khi bùng nở.
	# =====================================================

	var charge: Tween = create_tween()

	charge.set_parallel(true)

	charge.tween_property(
		egg_texture,
		"scale",
		Vector2(1.20, 1.20),
		0.18
	).set_trans(
		Tween.TRANS_BACK
	).set_ease(
		Tween.EASE_OUT
	)

	charge.tween_property(
		egg_texture,
		"modulate",
		Color(1.5, 1.5, 1.5, 1.0),
		0.18
	)

	await charge.finished


	# =====================================================
	# 2. BURST
	# Trứng phóng mạnh từ chính giữa.
	# =====================================================

	var burst: Tween = create_tween()

	burst.set_parallel(true)

	burst.tween_property(
		egg_texture,
		"scale",
		Vector2(2.8, 2.8),
		0.28
	).set_trans(
		Tween.TRANS_EXPO
	).set_ease(
		Tween.EASE_IN
	)

	burst.tween_property(
		egg_texture,
		"modulate",
		Color(3.0, 3.0, 3.0, 1.0),
		0.22
	)

	await burst.finished


	# =====================================================
	# 3. WHITE OUT
	# Phủ trắng toàn màn hình để chuẩn bị chuyển cảnh.
	# =====================================================

	var flash: ColorRect = ColorRect.new()

	flash.name = "HatchWhiteOut"
	flash.color = Color.WHITE
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.modulate.a = 0.0

	var root_control: Control = (
		get_tree().current_scene as Control
	)

	if root_control != null:
		root_control.add_child(flash)

		flash.set_anchors_and_offsets_preset(
			Control.PRESET_FULL_RECT
		)

		flash.move_to_front()

	else:
		add_child(flash)

		flash.set_anchors_and_offsets_preset(
			Control.PRESET_FULL_RECT
		)


	var white_out: Tween = create_tween()

	white_out.tween_property(
		flash,
		"modulate:a",
		1.0,
		0.18
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_OUT
	)

	await white_out.finished


# =====================================================
# MÀN HÌNH ĐÃ TRẮNG HOÀN TOÀN
# Đây là thời điểm an toàn để đổi gameplay phía dưới.
# =====================================================

	hatch_whiteout.emit()


	await get_tree().create_timer(
		0.12
	).timeout


	egg_texture.scale = Vector2.ONE
	egg_texture.rotation = 0.0
	egg_texture.modulate = Color.WHITE


	# Fade trắng trở lại để hiện màn hình tiếp theo.
	var fade_out: Tween = create_tween()

	fade_out.tween_property(
		flash,
		"modulate:a",
		0.0,
		0.35
	)

	await fade_out.finished

	flash.queue_free()
