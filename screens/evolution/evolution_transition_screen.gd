class_name EvolutionTransitionScreen
extends Control


const PetSceneProfileScript = preload(
	"res://features/evolution/domain/pet_scene_profile.gd"
)


signal transition_completed(image_path: String)


enum TransitionMode {
	INITIAL_BIRTH,
	EVOLUTION_UPDATE,
}


const RETRY_DELAYS := [
	2.0,
	4.0,
	6.0,
	8.0,
]

const MIN_TRANSITION_SECONDS: float = 3.0


@export_enum("Initial Birth", "Evolution Update")
var mode: int = TransitionMode.INITIAL_BIRTH


var _identity: PetIdentity
var _genome: PetGenome
var _scene_profile
var _pet_name: String = ""

var _coordinator: InitialPetRenderCoordinator

var _status_label: Label
var _result_image: TextureRect

var _effect_time: float = 0.0
var _effect_strength: float = 1.0
var _retry_count: int = 0
var _completed: bool = false
var _fatal: bool = false
var _transition_started_msec: int = 0


func _ready() -> void:
	_transition_started_msec = Time.get_ticks_msec()
	mouse_filter = Control.MOUSE_FILTER_STOP

	_build_ui()

	_coordinator = InitialPetRenderCoordinator.new()
	add_child(_coordinator)

	call_deferred("_begin_transition")


func _process(delta: float) -> void:
	_effect_time += maxf(delta, 0.0)

	if _status_label != null and not _completed and not _fatal:
		_status_label.modulate.a = (
			0.72
			+ 0.28
			* (
				0.5
				+ 0.5 * sin(_effect_time * 2.0)
			)
		)

	queue_redraw()


func _draw() -> void:
	var viewport_size := size

	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	draw_rect(
		Rect2(Vector2.ZERO, viewport_size),
		Color("#080611"),
		true
	)

	var center := Vector2(
		viewport_size.x * 0.5,
		viewport_size.y * 0.46
	)

	var pulse := (
		0.5
		+ 0.5 * sin(_effect_time * 2.4)
	)

	var glow_alpha := (
		0.10
		+ pulse * 0.08
	) * _effect_strength

	draw_circle(
		center,
		86.0 + pulse * 7.0,
		Color(0.43, 0.24, 0.72, glow_alpha),
		true
	)

	draw_circle(
		center,
		60.0 + pulse * 4.0,
		Color(0.22, 0.55, 0.95, glow_alpha * 0.8),
		true
	)

	for ring_index in range(3):
		var radius := 74.0 + float(ring_index) * 24.0
		var speed := (
			0.42
			+ float(ring_index) * 0.16
		)
		var direction := (
			1.0
			if ring_index % 2 == 0
			else -1.0
		)
		var start_angle := (
			_effect_time * speed * direction
			+ float(ring_index)
		)
		var arc_length := (
			PI * (1.15 + float(ring_index) * 0.12)
		)

		draw_arc(
			center,
			radius,
			start_angle,
			start_angle + arc_length,
			64,
			Color(
				0.64,
				0.48 + float(ring_index) * 0.08,
				1.0,
				0.55 * _effect_strength
			),
			2.0,
			true
		)

	for particle_index in range(18):
		var seed := float(particle_index) * 0.73
		var orbit := (
			52.0
			+ fmod(
				_effect_time * (12.0 + float(particle_index % 5) * 2.0)
				+ float(particle_index) * 19.0,
				138.0
			)
		)
		var angle := (
			seed
			+ _effect_time
			* (
				0.20
				+ float(particle_index % 4) * 0.04
			)
		)

		var position := (
			center
			+ Vector2(cos(angle), sin(angle))
			* orbit
		)

		var alpha := (
			0.18
			+ 0.42
			* (
				0.5
				+ 0.5
				* sin(
					_effect_time * 2.0
					+ seed
				)
			)
		)

		draw_circle(
			position,
			1.5 + float(particle_index % 3),
			Color(
				0.74,
				0.82,
				1.0,
				alpha * _effect_strength
			),
			true
		)

	if not _completed:
		var core_radius := 22.0 + pulse * 5.0

		draw_circle(
			center,
			core_radius,
			Color(
				0.82,
				0.90,
				1.0,
				0.48 * _effect_strength
			),
			true
		)


func _build_ui() -> void:
	_result_image = TextureRect.new()
	_result_image.name = "ResultImage"
	_result_image.visible = false
	_result_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_result_image.stretch_mode = (
		TextureRect.STRETCH_KEEP_ASPECT_COVERED
	)
	_result_image.set_anchors_preset(
		Control.PRESET_FULL_RECT
	)
	_result_image.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_result_image.grow_vertical = Control.GROW_DIRECTION_BOTH
	_result_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_result_image)

	_status_label = Label.new()
	_status_label.name = "GameStatusLabel"
	_status_label.text = "Đang thức tỉnh..."
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.anchor_left = 0.08
	_status_label.anchor_top = 0.82
	_status_label.anchor_right = 0.92
	_status_label.anchor_bottom = 0.90
	_status_label.add_theme_font_size_override(
		"font_size",
		16
	)
	_status_label.add_theme_constant_override(
		"outline_size",
		3
	)
	_status_label.add_theme_color_override(
		"font_outline_color",
		Color(0.04, 0.03, 0.08, 0.85)
	)
	add_child(_status_label)


func _begin_transition() -> void:
	match mode:
		TransitionMode.INITIAL_BIRTH:
			await _run_initial_birth()

		TransitionMode.EVOLUTION_UPDATE:
			_show_fatal(
				"Chế độ tiến hóa sau chưa được nối renderer."
			)

		_:
			_show_fatal(
				"EvolutionTransitionScreen nhận mode không hợp lệ."
			)


func _run_initial_birth() -> void:
	_status_label.text = "Đang thức tỉnh..."

	var data := (
		EvolutionBootstrapService.new()
		.build_from_hatch()
	)

	if not bool(data.get("ok", false)):
		_show_fatal(
			str(data.get(
				"error",
				"Bootstrap pet thất bại."
			))
		)
		return

	_identity = data.get("identity") as PetIdentity
	_genome = data.get("genome") as PetGenome
	_scene_profile = data.get(
		"scene_profile"
	)
	_pet_name = str(
		data.get("pet_name", "")
	)

	if (
		_identity == null
		or _genome == null
		or _scene_profile == null
	):
		_show_fatal(
			"Không tạo được Identity/Genome/Scene Profile cho pet."
		)
		return


	var existing_path := _get_existing_visual_path()

	if not existing_path.is_empty():
		_status_label.text = "Đang trở về..."

		await _wait_for_minimum_duration()

		if not _load_result_image(
			existing_path
		):
			_show_fatal(
				"Không load được ảnh pet đã lưu."
			)
			return

		_finish_success(
			existing_path,
			true
		)
		return

	var request_data := _coordinator.build_request(
		_identity,
		_genome,
		_scene_profile
	)

	if not bool(request_data.get("ok", false)):
		_show_fatal(
			str(request_data.get(
				"error",
				"Không tạo được yêu cầu render."
			))
		)
		return

	var request := (
		request_data.get("request")
		as PetRenderRequest
	)

	if request == null:
		_show_fatal(
			"Render request bị rỗng."
		)
		return

	if not _coordinator.has_render_endpoint():
		_show_fatal(
			"Chưa cấu hình Worker render trong proxy_dev.json."
		)
		return

	await _render_until_success(request)


func _render_until_success(
	request: PetRenderRequest
) -> void:
	_retry_count = 0

	while is_inside_tree():
		if _retry_count == 0:
			_status_label.text = "Đang định hình thế giới..."
		else:
			_status_label.text = "Dòng năng lượng đang ổn định lại..."

		var result: PetRenderResult = await (
			_coordinator.render_initial(
				request
			)
		)

		if not is_inside_tree():
			return

		if result != null and result.success:
			await _complete_initial_render(result)
			return

		if result == null:
			_show_fatal(
				"Renderer không trả kết quả."
			)
			return

		if not _is_retryable(result):
			_show_fatal(
				result.error_message
			)
			return

		_retry_count += 1

		var retry_delay := _retry_delay(
			_retry_count
		)

		push_warning(
			"Evolution render retry %d after %.0fs: %s"
			% [
				_retry_count,
				retry_delay,
				result.error_message,
			]
		)
		_status_label.text = "Dòng năng lượng đang ổn định lại..."

		await get_tree().create_timer(
			retry_delay
		).timeout


func _complete_initial_render(
	result: PetRenderResult
) -> void:
	var visual := PetVisualRecord.new()
	visual.pet_id = _identity.pet_id()
	visual.visual_index = 0
	visual.image_path = result.image_path
	visual.source_mode = &"initial_pethome_text_to_image"
	visual.renderer_id = result.renderer_id
	visual.model_id = result.model_id

	var saved := EvolutionSaveService.new().save_initial(
		_identity,
		_genome,
		visual,
		_pet_name,
		_scene_profile
	)

	if not saved:
		_show_fatal(
			"Ảnh đã tạo nhưng không lưu được dữ liệu pet."
		)
		return

	await _wait_for_minimum_duration()

	if not _load_result_image(
		result.image_path
	):
		_show_fatal(
			"Ảnh đã tạo nhưng không load được PNG."
		)
		return

	_finish_success(
		result.image_path,
		false
	)


func _get_existing_visual_path() -> String:
	var data := EvolutionSaveService.new().load_data()

	if data.is_empty():
		return ""

	var identity_value: Variant = data.get(
		"identity",
		{}
	)

	if typeof(identity_value) != TYPE_DICTIONARY:
		return ""

	var saved_identity := PetIdentity.from_dict(
		identity_value as Dictionary
	)

	if (
		saved_identity == null
		or not saved_identity.same_identity(
			_identity
		)
	):
		return ""

	var scene_value: Variant = data.get(
		"scene_profile",
		{}
	)

	if typeof(scene_value) != TYPE_DICTIONARY:
		return ""

	var saved_scene = PetSceneProfileScript.from_dict(
		scene_value as Dictionary
	)

	if (
		saved_scene == null
		or _scene_profile == null
		or not saved_scene.same_profile(
			_scene_profile
		)
	):
		return ""

	var visual_value: Variant = data.get(
		"current_visual",
		{}
	)

	if typeof(visual_value) != TYPE_DICTIONARY:
		return ""

	var visual := PetVisualRecord.from_dict(
		visual_value as Dictionary
	)

	if (
		visual == null
		or visual.source_mode
			!= &"initial_pethome_text_to_image"
	):
		return ""

	if visual.image_path.is_empty():
		return ""

	return visual.image_path


func _wait_for_minimum_duration() -> void:
	var elapsed := (
		float(
			Time.get_ticks_msec()
			- _transition_started_msec
		)
		/ 1000.0
	)

	var remaining := maxf(
		0.0,
		MIN_TRANSITION_SECONDS - elapsed
	)

	if remaining <= 0.0:
		return

	await get_tree().create_timer(
		remaining
	).timeout


func _load_result_image(
	path: String
) -> bool:
	if path.is_empty():
		return false

	var image := Image.new()
	var error := image.load(path)

	if error != OK:
		return false

	_result_image.texture = (
		ImageTexture.create_from_image(
			image
		)
	)
	_result_image.visible = true

	return true


func _finish_success(
	image_path: String,
	reused: bool
) -> void:
	_completed = true
	_fatal = false
	_effect_strength = 0.0

	_status_label.visible = false
	_result_image.visible = true

	queue_redraw()

	transition_completed.emit(
		image_path
	)


func _show_fatal(
	message: String
) -> void:
	_fatal = true
	_completed = false
	_effect_strength = 0.45

	push_error(
		"EvolutionTransition: " + message
	)

	_status_label.modulate.a = 1.0
	_status_label.text = "Kết nối thế giới bị gián đoạn."


func _retry_delay(
	retry_count: int
) -> float:
	var index := clampi(
		retry_count - 1,
		0,
		RETRY_DELAYS.size() - 1
	)

	return float(
		RETRY_DELAYS[index]
	)


func _is_retryable(
	result: PetRenderResult
) -> bool:
	match result.error_code:
		&"invalid_request":
			return false

		&"invalid_config":
			return false

		&"proxy_not_configured":
			return false

		&"unsupported_mode":
			return false

		&"not_implemented":
			return false

		&"output_dir_failed":
			return false

		&"write_failed":
			return false

		&"proxy_error":
			return not _is_fatal_http_error(
				result.error_message
			)

		_:
			return true


func _is_fatal_http_error(
	message: String
) -> bool:
	for status in [
		400,
		401,
		403,
		404,
		405,
		413,
		415,
		422,
	]:
		if message.begins_with(
			"HTTP %d" % status
		):
			return true

	return false
