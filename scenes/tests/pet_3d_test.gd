extends Control
## Standalone F6 test screen, intentionally outside GameApp / hatch routing.

const Actor = preload("res://pet/presentation/pet_3d_test_actor.gd")
var actor: Node3D
var status: Label
var pause_button: CheckButton

func _ready() -> void:
	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.add_theme_constant_override("separation", 6)
	add_child(layout)
	var title := Label.new()
	title.text = "DARK PET · 3D TEST"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(title)
	var container := SubViewportContainer.new()
	container.stretch = true
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.custom_minimum_size = Vector2(0, 240)
	layout.add_child(container)
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)
	_build_world(viewport)
	status = Label.new()
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.text = "Idle · chuyển động xương thử nghiệm"
	layout.add_child(status)
	var grid := GridContainer.new()
	grid.columns = 2
	layout.add_child(grid)
	for entry: Array in [["Thở / nghỉ", "idle"], ["Tò mò", "curious"], ["Vẫy tai–đuôi", "happy"], ["Bước tại chỗ", "walk_test"]]:
		var button := Button.new()
		button.text = entry[0]
		button.custom_minimum_size.y = 44
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_select_clip.bind(entry[1]))
		grid.add_child(button)
	var reset := Button.new()
	reset.text = "Tư thế gốc"
	reset.custom_minimum_size.y = 44
	reset.pressed.connect(_reset_pose)
	grid.add_child(reset)
	pause_button = CheckButton.new()
	pause_button.text = "Tạm dừng"
	pause_button.toggled.connect(actor.set_paused)
	grid.add_child(pause_button)
	var rotate_label := Label.new()
	rotate_label.text = "Xoay để kiểm tra model"
	layout.add_child(rotate_label)
	var rotation_slider := HSlider.new()
	rotation_slider.min_value = -180
	rotation_slider.max_value = 180
	rotation_slider.value = 0
	rotation_slider.custom_minimum_size.y = 40
	rotation_slider.value_changed.connect(_rotate_actor)
	layout.add_child(rotation_slider)
	var note := Label.new()
	note.text = "Test rig; chưa phải dáng đi hoàn chỉnh.\nKhông ghi dữ liệu đời pet."
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(note)

func _build_world(viewport: SubViewport) -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("252d40")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("d4dffc")
	settings.ambient_light_energy = 0.65
	environment.environment = settings
	viewport.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, -30, 0)
	light.light_energy = 1.3
	viewport.add_child(light)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(12, 12)
	floor_mesh.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("495368")
	material.roughness = 1.0
	floor_mesh.material_override = material
	floor_mesh.position.y = -0.02
	viewport.add_child(floor_mesh)
	actor = Actor.new()
	viewport.add_child(actor)
	var camera := Camera3D.new()
	camera.position = Vector3(2.6, 1.8, 4.5)
	camera.fov = 38
	viewport.add_child(camera)
	camera.look_at(Vector3(0, 0.85, 0))
	camera.current = true

func _select_clip(clip_name: String) -> void:
	pause_button.set_pressed_no_signal(false)
	actor.play_clip(clip_name)
	status.text = clip_name + " · chuyển động xương thử nghiệm"

func _reset_pose() -> void:
	pause_button.set_pressed_no_signal(false)
	actor.reset_pose()
	status.text = "Tư thế gốc · không animation"

func _rotate_actor(degrees: float) -> void:
	actor.rotation_degrees.y = degrees
