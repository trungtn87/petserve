class_name EvolutionTransitionScreen
extends Control


const PetSceneProfileScript = preload(
	"res://features/evolution/domain/pet_scene_profile.gd"
)
const PETHOME_SCENE: PackedScene = preload(
	"res://scenes/pet/pet_home.tscn"
)


signal transition_completed(image_path: String)


enum TransitionMode {
	INITIAL_BIRTH,
	EVOLUTION_UPDATE,
}


const MIN_TRANSITION_SECONDS: float = 3.0
const MIN_INITIAL_HATCH_SECONDS: float = 1.2

const CURRENT_INITIAL_RENDER_SOURCE_MODE: StringName = (
	&"initial_pethome_v14_habitat_frame"
)

const TRANSITION_BG := Color("#090617")
const HATCH_BACKGROUND_TEXTURE: Texture2D = preload(
	"res://assets/eggs/backgroud.png"
)
const DNA_LEFT := Color(0.72, 0.56, 1.0, 0.94)
const DNA_RIGHT := Color(0.48, 0.90, 1.0, 0.94)
const DNA_RUNG := Color(0.86, 0.94, 1.0, 0.42)
const DNA_CORE := Color(0.94, 0.98, 1.0, 0.92)


@export_enum("Initial Birth", "Evolution Update")
var mode: int = TransitionMode.INITIAL_BIRTH


var _identity: PetIdentity
var _genome: PetGenome
var _scene_profile
var _pet_name: String = ""
var _mythic_destiny: Dictionary = {}
var _egg_stage: int = 1

var _coordinator: InitialPetRenderCoordinator

var _retry_button: Button
var _back_button: Button
var _busy: bool = false
var _status_label: Label
var _result_image: TextureRect
var _hatch_background: TextureRect
var _hatch_egg: TextureRect
var _hatch_flash: ColorRect
var _hatch_waiting: bool = false

var _effect_time: float = 0.0
var _effect_strength: float = 1.0
var _completed: bool = false
var _fatal: bool = false
var _transition_started_msec: int = 0
var _pet_home_scheduled: bool = false


func _ready() -> void:
	_transition_started_msec = Time.get_ticks_msec()
	mouse_filter = Control.MOUSE_FILTER_STOP

	theme = PetHomeGameplayTheme.build()
	_build_ui()

	_coordinator = InitialPetRenderCoordinator.new()
	add_child(_coordinator)

	call_deferred("_begin_transition")


func _process(delta: float) -> void:
	_effect_time += maxf(delta, 0.0)

	if _status_label != null and not _completed and not _fatal:
		_status_label.modulate.a = (
			0.82
			+ 0.18
			* (
				0.5
				+ 0.5 * sin(_effect_time * 2.4)
			)
		)

	_update_hatch_wait_motion()
	queue_redraw()


func _draw() -> void:
	var viewport_size := size

	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	draw_rect(
		Rect2(Vector2.ZERO, viewport_size),
		TRANSITION_BG,
		true
	)

	if mode == TransitionMode.INITIAL_BIRTH:
		return

	var center := Vector2(
		viewport_size.x * 0.5,
		viewport_size.y * 0.44
	)
	var pulse := (
		0.5
		+ 0.5 * sin(_effect_time * 2.15)
	)
	var slow_pulse := (
		0.5
		+ 0.5 * sin(
			_effect_time * 1.1
			+ 0.8
		)
	)

	_draw_energy_beam(
		center,
		pulse
	)
	_draw_mystic_glow(
		center,
		pulse,
		slow_pulse
	)
	_draw_dna_helix(
		center,
		pulse
	)
	_draw_mystic_rings(
		center,
		pulse
	)
	_draw_rune_orbit(
		center,
		pulse
	)
	_draw_transition_particles(
		center,
		slow_pulse
	)


func _draw_energy_beam(
	center: Vector2,
	pulse: float
) -> void:
	var beam_height := minf(
		size.y * 0.62,
		390.0
	)
	var beam_width := 34.0 + pulse * 10.0
	var beam_rect := Rect2(
		center.x - beam_width * 0.5,
		center.y - beam_height * 0.5,
		beam_width,
		beam_height
	)

	draw_rect(
		beam_rect,
		Color(
			0.48,
			0.73,
			1.0,
			0.035 * _effect_strength
		),
		true
	)

	var core_width := 5.0 + pulse * 2.0
	draw_rect(
		Rect2(
			center.x - core_width * 0.5,
			center.y - beam_height * 0.5,
			core_width,
			beam_height
		),
		Color(
			0.82,
			0.92,
			1.0,
			0.10 * _effect_strength
		),
		true
	)


func _draw_rune_orbit(
	center: Vector2,
	pulse: float
) -> void:
	var orbit_radius := 122.0 + pulse * 5.0

	for index in range(8):
		var angle := (
			_effect_time * 0.34
			+ float(index) / 8.0 * TAU
		)
		var point := (
			center
			+ Vector2(
				cos(angle),
				sin(angle)
			) * orbit_radius
		)
		var alpha := (
			0.34
			+ 0.30
			* (
				0.5
				+ 0.5
				* sin(
					_effect_time * 1.7
					+ float(index)
				)
			)
		) * _effect_strength

		var rune_color := Color(
			0.72,
			0.82,
			1.0,
			alpha
		)

		if index % 2 == 0:
			_draw_diamond_rune(
				point,
				4.0 + pulse,
				rune_color
			)
		else:
			draw_circle(
				point,
				2.1 + pulse * 0.4,
				rune_color,
				true
			)


func _draw_diamond_rune(
	center: Vector2,
	radius: float,
	color: Color
) -> void:
	var points := PackedVector2Array([
		center + Vector2(0, -radius),
		center + Vector2(radius * 0.65, 0),
		center + Vector2(0, radius),
		center + Vector2(-radius * 0.65, 0),
	])

	for index in range(points.size()):
		draw_line(
			points[index],
			points[(index + 1) % points.size()],
			color,
			1.2,
			true
		)


func _draw_mystic_glow(
	center: Vector2,
	pulse: float,
	slow_pulse: float
) -> void:
	for index in range(5, 0, -1):
		var radius := (
			68.0
			+ float(index) * 30.0
			+ pulse * 8.0
		)
		var alpha := (
			0.018
			+ float(index) * 0.010
		) * _effect_strength

		var color := (
			Color(
				0.36,
				0.20,
				0.82,
				alpha
			)
			if index % 2 == 0
			else Color(
				0.18,
				0.62,
				0.96,
				alpha * 0.86
			)
		)

		draw_circle(
			center,
			radius,
			color,
			true
		)

	draw_circle(
		center,
		52.0 + pulse * 8.0,
		Color(
			0.55,
			0.40,
			1.0,
			(0.10 + slow_pulse * 0.05)
			* _effect_strength
		),
		true
	)

	draw_circle(
		center,
		24.0 + pulse * 4.0,
		Color(
			DNA_CORE.r,
			DNA_CORE.g,
			DNA_CORE.b,
			(0.70 + pulse * 0.20)
			* _effect_strength
		),
		true
	)


func _draw_dna_helix(
	center: Vector2,
	pulse: float
) -> void:
	var helix_height := 270.0
	var amplitude := 40.0 + pulse * 2.0
	var segments := 34
	var phase := _effect_time * 1.35

	var left_points: Array[Vector2] = []
	var right_points: Array[Vector2] = []

	for index in range(segments + 1):
		var ratio := float(index) / float(segments)
		var y := (
			center.y
			- helix_height * 0.5
			+ ratio * helix_height
		)
		var wave := sin(
			ratio * TAU * 2.35
			+ phase
		)
		var depth := (
			0.72
			+ 0.28
			* (
				0.5
				+ 0.5 * cos(
					ratio * TAU * 2.35
					+ phase
				)
			)
		)

		left_points.append(
			Vector2(
				center.x
				+ wave * amplitude,
				y
			)
		)
		right_points.append(
			Vector2(
				center.x
				- wave * amplitude,
				y
			)
		)

		if index % 2 == 0:
			var rung := DNA_RUNG
			rung.a *= (
				depth
				* _effect_strength
			)

			draw_line(
				left_points[index],
				right_points[index],
				rung,
				1.6,
				true
			)

	for index in range(segments):
		var left_color := DNA_LEFT
		var right_color := DNA_RIGHT
		left_color.a *= _effect_strength
		right_color.a *= _effect_strength

		draw_line(
			left_points[index],
			left_points[index + 1],
			left_color,
			3.0,
			true
		)
		draw_line(
			right_points[index],
			right_points[index + 1],
			right_color,
			3.0,
			true
		)

	for index in range(0, segments + 1, 5):
		var travel := (
			0.5
			+ 0.34
			* sin(
				_effect_time * 2.2
				+ float(index)
			)
		)
		var point := left_points[index].lerp(
			right_points[index],
			travel
		)

		draw_circle(
			point,
			2.2 + pulse * 1.1,
			Color(
				0.90,
				0.96,
				1.0,
				0.82 * _effect_strength
			),
			true
		)


func _draw_mystic_rings(
	center: Vector2,
	pulse: float
) -> void:
	for ring_index in range(3):
		var radius := (
			72.0
			+ float(ring_index) * 24.0
			+ pulse * 3.0
		)
		var direction := (
			1.0
			if ring_index % 2 == 0
			else -1.0
		)
		var start_angle := (
			_effect_time
			* (
				0.44
				+ float(ring_index) * 0.18
			)
			* direction
			+ float(ring_index)
		)
		var alpha := (
			0.58
			- float(ring_index) * 0.12
		) * _effect_strength

		draw_arc(
			center,
			radius,
			start_angle,
			start_angle + PI * 0.86,
			42,
			Color(
				0.68,
				0.60 + float(ring_index) * 0.08,
				1.0,
				alpha
			),
			2.0,
			true
		)


func _draw_transition_particles(
	center: Vector2,
	pulse: float
) -> void:
	for particle_index in range(22):
		var particle_seed := float(particle_index) * 0.71
		var orbit := (
			64.0
			+ fmod(
				float(particle_index) * 19.0
				+ _effect_time
				* (
					10.0
					+ float(
						particle_index % 5
					)
				),
				150.0
			)
		)
		var angle := (
			particle_seed
			+ _effect_time
			* (
				0.16
				+ float(
					particle_index % 4
				) * 0.035
			)
		)
		var point := (
			center
			+ Vector2(
				cos(angle),
				sin(angle)
			) * orbit
		)
		var alpha := (
			0.20
			+ 0.42
			* (
				0.5
				+ 0.5
				* sin(
					_effect_time * 1.8
					+ particle_seed
				)
			)
		) * _effect_strength

		draw_circle(
			point,
			1.2
			+ float(
				particle_index % 3
			) * 0.65
			+ pulse * 0.25,
			Color(
				0.82,
				0.91,
				1.0,
				alpha
			),
			true
		)


func _build_ui() -> void:
	_hatch_background = TextureRect.new()
	_hatch_background.name = "HatchBackground"
	_hatch_background.texture = HATCH_BACKGROUND_TEXTURE
	_hatch_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hatch_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_hatch_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hatch_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hatch_background.visible = (
		mode == TransitionMode.INITIAL_BIRTH
	)
	add_child(_hatch_background)

	var egg_holder := CenterContainer.new()
	egg_holder.name = "HatchEggHolder"
	egg_holder.anchor_left = 0.0
	egg_holder.anchor_top = 0.18
	egg_holder.anchor_right = 1.0
	egg_holder.anchor_bottom = 0.76
	egg_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	egg_holder.visible = (
		mode == TransitionMode.INITIAL_BIRTH
	)
	add_child(egg_holder)

	_hatch_egg = TextureRect.new()
	_hatch_egg.name = "HatchEgg"
	_hatch_egg.custom_minimum_size = Vector2(230.0, 230.0)
	_hatch_egg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hatch_egg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_hatch_egg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hatch_egg.visible = false
	egg_holder.add_child(_hatch_egg)

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
	_status_label.text = "Đang thức tỉnh huyết mạch..."
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.anchor_left = 0.10
	_status_label.anchor_top = 0.81
	_status_label.anchor_right = 0.90
	_status_label.anchor_bottom = 0.89
	_status_label.add_theme_font_size_override(
		"font_size",
		17
	)
	_status_label.add_theme_constant_override(
		"outline_size",
		4
	)
	_status_label.add_theme_color_override(
		"font_color",
		Color(0.93, 0.96, 1.0, 0.96)
	)
	_status_label.add_theme_color_override(
		"font_outline_color",
		Color(0.10, 0.05, 0.24, 0.96)
	)
	add_child(_status_label)
	_retry_button = Button.new()
	_retry_button.text = "THỬ LẠI"
	_retry_button.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_retry_button.position = Vector2(size.x * 0.5 - 145, size.y - 54)
	_retry_button.custom_minimum_size = Vector2(140, 44)
	_retry_button.visible = false
	_retry_button.pressed.connect(_begin_transition)
	add_child(_retry_button)
	_back_button = Button.new()
	_back_button.text = "TRỞ VỀ"
	_back_button.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_back_button.position = Vector2(size.x * 0.5 + 5, size.y - 54)
	_back_button.custom_minimum_size = Vector2(140, 44)
	_back_button.visible = false
	_back_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/pet/pet_home.tscn" if mode == TransitionMode.EVOLUTION_UPDATE else "res://scenes/main.tscn"))
	add_child(_back_button)

	_hatch_flash = ColorRect.new()
	_hatch_flash.name = "HatchFlash"
	_hatch_flash.color = Color.WHITE
	_hatch_flash.modulate.a = 0.0
	_hatch_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hatch_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hatch_flash.visible = false
	_hatch_flash.z_index = 100
	add_child(_hatch_flash)


func _begin_transition() -> void:
	if _busy:
		return
	_busy = true
	_fatal = false
	_retry_button.visible = false
	_back_button.visible = false
	_reset_hatch_flash()
	match mode:
		TransitionMode.INITIAL_BIRTH:
			await _run_initial_birth()

		TransitionMode.EVOLUTION_UPDATE:
			await _run_evolution()

		_:
			_show_fatal(
				"EvolutionTransitionScreen nhận mode không hợp lệ."
			)


func _run_initial_birth() -> void:
	_status_label.text = "Đang thức tỉnh huyết mạch..."

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
	_egg_stage = clampi(
		int(data.get("egg_stage", 1)),
		1,
		4
	)
	var destiny_value: Variant = data.get(
		"mythic_destiny",
		{}
	)
	_mythic_destiny = (
		(destiny_value as Dictionary).duplicate(
			true
		)
		if typeof(destiny_value) == TYPE_DICTIONARY
		else {}
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
		# Visual đã tồn tại = lần sinh đã hoàn tất trước đó.
		# Resume game phải vào thẳng PetHome, tuyệt đối không phát lại
		# rung trứng / flash nở.
		_completed = true
		_hatch_waiting = false
		_enter_pet_home()
		return

	_prepare_initial_hatch_visual(
		_identity.element(),
		_egg_stage
	)

	var request_data := _coordinator.build_request(
		_identity,
		_genome,
		_scene_profile,
		_mythic_destiny
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
	_status_label.text = "Đang định hình thế giới..."
	var result: PetRenderResult = await _coordinator.render(request)
	if not is_inside_tree():
		return
	if result == null or not result.success:
		_show_fatal(_render_failure_message(result))
		return
	if mode == TransitionMode.EVOLUTION_UPDATE:
		if not StageEvolutionService.new().commit(result):
			_show_fatal("Chưa lưu được hình thái mới. Hãy thử lại.")
			return
		await _wait_for_minimum_duration()
		_load_result_image(result.image_path)
		_finish_success(result.image_path, false)
	else:
		await _complete_initial_render(result)

func _render_failure_message(
	result: PetRenderResult
) -> String:
	if result == null:
		return (
			"Không tạo được hình thái [null_result]. "
			+ "Renderer không trả kết quả."
		)

	var code := String(result.error_code).strip_edges()
	var detail := result.error_message.strip_edges()

	if code.is_empty():
		code = "render_failed"

	if detail.is_empty():
		detail = "Renderer không cung cấp chi tiết lỗi."

	return (
		"Không tạo được hình thái [%s]: %s"
		% [code, detail]
	)


func _run_evolution() -> void:
	var saved := EvolutionSaveService.new().load_data()
	var identity := PetIdentity.from_dict(saved.get("identity", {}))
	var genome := PetGenome.from_dict(saved.get("genome", {}))
	if identity == null or genome == null:
		_show_fatal("Không đọc được dữ liệu pet.")
		return
	if genome.stage() >= StageLifecycle.FINAL_STAGE:
		_finish_success(
			str(
				saved.get(
					"current_visual",
					{}
				).get(
					"image_path",
					""
				)
			),
			true
		)
		return
	var game := InfantGameFacade.new()
	if not game.setup(
		identity.lineage_seed(),
		genome.stage()
	):
		_show_fatal("Chưa lưu được tiến trình.")
		return
	var service := StageEvolutionService.new()
	var prepared := service.prepare(game.snapshot())
	if not bool(prepared.get("ok", false)):
		_show_fatal(str(prepared.get("error", "Chưa thể tiến hóa.")))
		return
	var request := service.build_request(prepared.get("data", {}))
	if request == null:
		_show_fatal("Không tạo được yêu cầu tiến hóa.")
		return
	await _render_until_success(request)


func _complete_initial_render(
	result: PetRenderResult
) -> void:
	var visual := PetVisualRecord.new()
	visual.pet_id = _identity.pet_id()
	visual.visual_index = 0
	visual.image_path = result.image_path
	visual.source_mode = CURRENT_INITIAL_RENDER_SOURCE_MODE
	visual.renderer_id = result.renderer_id
	visual.model_id = result.model_id

	var saved := EvolutionSaveService.new().save_initial(
		_identity,
		_genome,
		visual,
		_pet_name,
		_scene_profile,
		_mythic_destiny,
		_egg_stage
	)

	if not saved:
		_show_fatal(
			"Ảnh đã tạo nhưng không lưu được dữ liệu pet."
		)
		return

	await _wait_for_initial_hatch_duration()
	await _finish_initial_hatch(
		result.image_path
	)


func _prepare_initial_hatch_visual(
	element: StringName,
	egg_stage: int
) -> void:
	if mode != TransitionMode.INITIAL_BIRTH:
		return

	if _hatch_background != null:
		_hatch_background.visible = true

	if _result_image != null:
		_result_image.visible = false

	if _hatch_egg == null:
		return

	var normalized_stage := clampi(
		egg_stage,
		1,
		4
	)
	var egg_path := ""

	if normalized_stage == 1:
		egg_path = (
			"res://assets/eggs/stage_1/common.png"
		)
	else:
		egg_path = (
			"res://assets/eggs/stage_%d/%s.png"
			% [
				normalized_stage,
				String(element).to_lower(),
			]
		)

	if not ResourceLoader.exists(egg_path):
		_show_fatal(
			"Không tìm thấy ảnh trứng chờ nở: "
			+ egg_path
		)
		return

	var texture := load(egg_path) as Texture2D

	if texture == null:
		_show_fatal(
			"Không load được ảnh trứng chờ nở."
		)
		return

	_hatch_egg.texture = texture
	_hatch_egg.visible = true
	_hatch_egg.rotation = 0.0
	_hatch_egg.scale = Vector2.ONE
	_hatch_egg.modulate = Color.WHITE
	_hatch_waiting = true
	_status_label.text = "Đang nở..."


func _update_hatch_wait_motion() -> void:
	if (
		mode != TransitionMode.INITIAL_BIRTH
		or not _hatch_waiting
		or _hatch_egg == null
		or not _hatch_egg.visible
	):
		return

	_hatch_egg.pivot_offset = (
		_hatch_egg.size * 0.5
	)

	var burst_wave := maxf(
		0.0,
		sin(_effect_time * 2.2)
	)
	var burst := pow(
		burst_wave,
		8.0
	)
	var shake_degrees := (
		sin(_effect_time * 27.0)
		* (2.2 + burst * 6.0)
	)
	var pulse := (
		1.0
		+ 0.012
		* (
			0.5
			+ 0.5 * sin(_effect_time * 4.0)
		)
		+ burst * 0.012
	)

	_hatch_egg.rotation = deg_to_rad(
		shake_degrees
	)
	_hatch_egg.scale = Vector2(
		pulse,
		pulse
	)


func _wait_for_initial_hatch_duration() -> void:
	var elapsed := (
		float(
			Time.get_ticks_msec()
			- _transition_started_msec
		)
		/ 1000.0
	)
	var remaining := maxf(
		0.0,
		MIN_INITIAL_HATCH_SECONDS - elapsed
	)

	if remaining > 0.0:
		await get_tree().create_timer(
			remaining
		).timeout


func _finish_initial_hatch(
	image_path: String
) -> void:
	if not is_inside_tree():
		return

	_completed = true
	_fatal = false
	_hatch_waiting = false
	_status_label.visible = false

	if _hatch_egg != null:
		_hatch_egg.pivot_offset = (
			_hatch_egg.size * 0.5
		)

		var burst := create_tween()
		burst.tween_property(
			_hatch_egg,
			"rotation",
			deg_to_rad(-10.0),
			0.05
		)
		burst.tween_property(
			_hatch_egg,
			"rotation",
			deg_to_rad(11.0),
			0.05
		)
		burst.tween_property(
			_hatch_egg,
			"rotation",
			deg_to_rad(-13.0),
			0.045
		)
		burst.tween_property(
			_hatch_egg,
			"rotation",
			deg_to_rad(13.0),
			0.045
		)
		burst.tween_property(
			_hatch_egg,
			"rotation",
			0.0,
			0.04
		)
		burst.parallel().tween_property(
			_hatch_egg,
			"scale",
			Vector2(1.10, 1.10),
			0.20
		)
		burst.parallel().tween_property(
			_hatch_egg,
			"modulate",
			Color(1.8, 1.8, 1.8, 1.0),
			0.20
		)

		await burst.finished

	if _hatch_flash != null:
		_hatch_flash.visible = true
		_hatch_flash.modulate.a = 0.0

		var flash := create_tween()
		flash.tween_property(
			_hatch_flash,
			"modulate:a",
			1.0,
			0.18
		).set_trans(
			Tween.TRANS_QUAD
		).set_ease(
			Tween.EASE_OUT
		)

		await flash.finished

	transition_completed.emit(
		image_path
	)

	await get_tree().create_timer(
		0.08
	).timeout

	_enter_pet_home()


func _reset_hatch_flash() -> void:
	if _hatch_flash == null:
		return

	_hatch_flash.visible = false
	_hatch_flash.modulate.a = 0.0


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
		or visual.source_mode not in [CURRENT_INITIAL_RENDER_SOURCE_MODE, &"evolution_pethome_v12_full_regenerate", &"evolution_pethome_v12_image_edit", &"evolution_pethome_v10_full_regenerate", &"evolution_pethome_v10_image_edit", &"evolution_pethome_v9_full_regenerate", &"evolution_pethome_v9_image_edit", &"evolution_pethome_v8_full_regenerate", &"evolution_pethome_v8_image_edit", &"evolution_pethome_v7_full_regenerate", &"evolution_pethome_v7_image_edit", &"evolution_pethome_v5_image_edit"]
	):
		return ""

	if visual.image_path.is_empty() or not FileAccess.file_exists(visual.image_path):
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

	transition_completed.emit(image_path)

	_schedule_pet_home()


func _schedule_pet_home() -> void:
	if _pet_home_scheduled:
		return

	_pet_home_scheduled = true

	var timer := get_tree().create_timer(
		0.25
	)
	timer.timeout.connect(
		_enter_pet_home,
		CONNECT_ONE_SHOT
	)


func _enter_pet_home() -> void:
	if not is_inside_tree():
		return

	var error := get_tree().change_scene_to_packed(
		PETHOME_SCENE
	)

	if error != OK:
		_pet_home_scheduled = false
		push_error(
			"EvolutionTransition: không chuyển được sang PetHome."
		)


func _show_fatal(
	message: String
) -> void:
	_fatal = true
	_busy = false
	_hatch_waiting = false
	if _hatch_egg != null:
		_hatch_egg.rotation = 0.0
		_hatch_egg.scale = Vector2.ONE
	_retry_button.visible = true
	_back_button.visible = true
	_completed = false
	_effect_strength = 0.45

	push_error(
		"EvolutionTransition: " + message
	)

	_status_label.modulate.a = 1.0
	_status_label.text = message
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
