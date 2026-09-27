extends Control
## Standalone F6 test screen, intentionally outside GameApp / hatch routing.

const Actor = preload("res://pet/presentation/pet_3d_test_actor.gd")
var actor: Node3D
var status: Label
var pause_button: CheckButton
var camera: Camera3D
var viewport_container: SubViewportContainer
var active_finger: int = -1

func _ready() -> void:
	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.add_theme_constant_override("separation", 6)
	add_child(layout)
	var title := Label.new()
	title.text = "DARK PET · RIG V4"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(title)
	var container := SubViewportContainer.new()
	container.stretch = true
	viewport_container = container
	container.gui_input.connect(_viewport_input)
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
	status.text = "Chạm / kéo trong khung để pet nhìn theo"
	layout.add_child(status)
	var grid := GridContainer.new()
	grid.columns = 2
	layout.add_child(grid)
	for entry: Array in [["Thở / nghỉ", "idle"], ["Tò mò", "curious"], ["Vẫy tai–đuôi", "happy"], ["Test chân", "walk_test"]]:
		var button := Button.new()
		button.text = entry[0]
		button.custom_minimum_size.y = 44
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_select_clip.bind(entry[1]))
		grid.add_child(button)
	var appearance_choice := OptionButton.new()
	appearance_choice.add_item("Ngoại hình: Trăng tím")
	appearance_choice.add_item("Ngoại hình: Băng xanh")
	appearance_choice.custom_minimum_size.y = 40
	appearance_choice.item_selected.connect(func(index: int) -> void:
		var paths := ["res://data/pet/appearance/moon_shadow.tres", "res://data/pet/appearance/moon_frost.tres"]
		actor.set_appearance(load(paths[index]))
	)
	layout.add_child(appearance_choice)
	var living := Button.new()
	living.text = "Sống động"
	living.custom_minimum_size.y = 44
	living.pressed.connect(_start_living)
	grid.add_child(living)
	var react := Button.new()
	react.text = "Gọi pet"
	react.custom_minimum_size.y = 44
	react.pressed.connect(_call_pet)
	grid.add_child(react)
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
	note.text = "Chớp mắt: model chưa có mí mắt.\nF5: game · F6: bản test này."
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(note)

func _build_world(viewport: SubViewport) -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("252d40")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("dbe4f5")
	settings.ambient_light_energy = 0.35
	environment.environment = settings
	viewport.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, -30, 0)
	light.light_energy = 0.9
	light.shadow_enabled = true
	viewport.add_child(light)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25, 140, 0)
	fill.light_color = Color("c8d9ff")
	fill.light_energy = 0.3
	viewport.add_child(fill)
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
	camera = Camera3D.new()
	camera.position = Vector3(1.2, 1.5, 3.8)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.55
	camera.near = 0.05
	camera.far = 30.0
	viewport.add_child(camera)
	camera.look_at(Vector3(0, 0.82, 0))
	camera.current = true

func _select_clip(clip_name: String) -> void:
	pause_button.set_pressed_no_signal(false)
	actor.play_clip(clip_name)
	status.text = "Test chân · chưa có khớp gối / IK" if clip_name == "walk_test" else clip_name + " · rig v4"

func _reset_pose() -> void:
	pause_button.set_pressed_no_signal(false)
	actor.reset_pose()
	status.text = "Tư thế gốc · không animation"

func _rotate_actor(degrees: float) -> void:
	actor.rotation_degrees.y = degrees

func _start_living() -> void:
	pause_button.set_pressed_no_signal(false)
	actor.start_living()
	status.text = "Chạm / kéo trong khung để pet nhìn theo"

func _call_pet() -> void:
	if actor.current_clip != "living":
		_start_living()
	actor.focus(camera.global_position)

func _viewport_input(event: InputEvent) -> void:
	if actor.current_clip != "living" or pause_button.button_pressed:
		return
	if event is InputEventScreenTouch:
		if event.pressed and active_finger == -1:
			active_finger = event.index
			_focus_screen(event.position, true)
		elif not event.pressed and event.index == active_finger:
			active_finger = -1
	elif event is InputEventScreenDrag and event.index == active_finger:
		_focus_screen(event.position, false)
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_focus_screen(event.position, true)
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_focus_screen(event.position, false)

func _focus_screen(point: Vector2, touched: bool) -> void:
	var viewport := camera.get_viewport()
	# GUI event positions are local to the container; account for viewport scaling.
	var uv := point / viewport_container.size
	var pixel := uv * Vector2(viewport.size)
	var head_index: int = actor.skeleton.find_bone("Head")
	var head_position: Vector3 = actor.skeleton.global_transform * actor.skeleton.get_bone_global_rest(head_index).origin
	var normal := (camera.global_position - head_position).normalized()
	var anchor := head_position + normal * 1.2
	var plane := Plane(normal, normal.dot(anchor))
	var hit: Variant = plane.intersects_ray(camera.project_ray_origin(pixel), camera.project_ray_normal(pixel))
	if hit is Vector3:
		actor.focus(hit, touched)
