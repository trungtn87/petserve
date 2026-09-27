class_name PetHomeMenu
extends Control


signal action_requested(action_id: StringName)


const DRAWER_WIDTH_RATIO: float = 0.74
const DRAWER_MIN_WIDTH: float = 238.0
const DRAWER_MAX_WIDTH: float = 276.0
const OPEN_TIME: float = 0.22
const CLOSE_TIME: float = 0.18
const TOAST_TIME: float = 1.35


@onready var menu_button: Button = %MenuButton
@onready var scrim: ColorRect = %Scrim
@onready var drawer: PanelContainer = %Drawer
@onready var close_button: Button = %CloseButton

@onready var food_button: Button = %FoodButton
@onready var item_button: Button = %ItemButton
@onready var explore_button: Button = %ExploreButton
@onready var journal_button: Button = %JournalButton
@onready var decor_button: Button = %DecorButton
@onready var settings_button: Button = %SettingsButton

@onready var action_toast: PanelContainer = %ActionToast
@onready var toast_label: Label = %ToastLabel


var _is_open: bool = false
var _drawer_width: float = DRAWER_MIN_WIDTH
var _transition: Tween = null
var _toast_tween: Tween = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	menu_button.pressed.connect(open_menu)
	close_button.pressed.connect(close_menu)

	food_button.pressed.connect(_request_action.bind(&"food"))
	item_button.pressed.connect(_request_action.bind(&"items"))
	explore_button.pressed.connect(_request_action.bind(&"explore"))
	journal_button.pressed.connect(_request_action.bind(&"journal"))
	decor_button.pressed.connect(_request_action.bind(&"decor"))
	settings_button.pressed.connect(_request_action.bind(&"settings"))

	scrim.gui_input.connect(_on_scrim_gui_input)
	resized.connect(_on_resized)

	call_deferred("_layout_closed")


func open_menu() -> void:
	if _is_open:
		return

	_is_open = true
	_kill_transition()

	_update_drawer_size()

	drawer.visible = true
	scrim.visible = true
	menu_button.visible = false

	scrim.modulate.a = 0.0
	drawer.position = _closed_position()

	_transition = create_tween()
	_transition.set_parallel(true)

	_transition.tween_property(
		drawer,
		"position",
		_open_position(),
		OPEN_TIME
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	_transition.tween_property(
		scrim,
		"modulate:a",
		1.0,
		OPEN_TIME
	)


func close_menu() -> void:
	if not _is_open:
		return

	_is_open = false
	_kill_transition()

	_transition = create_tween()
	_transition.set_parallel(true)

	_transition.tween_property(
		drawer,
		"position",
		_closed_position(),
		CLOSE_TIME
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	_transition.tween_property(
		scrim,
		"modulate:a",
		0.0,
		CLOSE_TIME
	)

	_transition.finished.connect(
		_finish_close,
		CONNECT_ONE_SHOT
	)


func is_open() -> bool:
	return _is_open


func _finish_close() -> void:
	if _is_open:
		return

	drawer.visible = false
	scrim.visible = false
	menu_button.visible = true


func _request_action(action_id: StringName) -> void:
	action_requested.emit(action_id)
	_show_action_toast(action_id)
	close_menu()


func _show_action_toast(action_id: StringName) -> void:
	var title: String = _action_title(action_id)

	toast_label.text = title + " • sẽ nối gameplay ở bước tiếp theo"
	action_toast.visible = true
	action_toast.modulate.a = 1.0

	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()

	_toast_tween = create_tween()
	_toast_tween.tween_interval(TOAST_TIME)
	_toast_tween.tween_property(
		action_toast,
		"modulate:a",
		0.0,
		0.22
	)
	_toast_tween.tween_callback(
		func() -> void:
			action_toast.visible = false
	)


func _action_title(action_id: StringName) -> String:
	match action_id:
		&"food":
			return "Thức ăn"
		&"items":
			return "Đồ dùng"
		&"explore":
			return "Khám phá"
		&"journal":
			return "Nhật ký"
		&"decor":
			return "Trang trí"
		&"settings":
			return "Cài đặt"
		_:
			return "PetVerse"


func _on_scrim_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			close_menu()
			accept_event()

	elif event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed:
			close_menu()
			accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if _is_open and event.is_action_pressed("ui_cancel"):
		close_menu()
		get_viewport().set_input_as_handled()


func _on_resized() -> void:
	_update_drawer_size()

	if _is_open:
		drawer.position = _open_position()
	else:
		drawer.position = _closed_position()


func _layout_closed() -> void:
	_update_drawer_size()
	drawer.position = _closed_position()
	drawer.visible = false
	scrim.visible = false
	menu_button.visible = true
	action_toast.visible = false


func _update_drawer_size() -> void:
	_drawer_width = clampf(
		size.x * DRAWER_WIDTH_RATIO,
		DRAWER_MIN_WIDTH,
		DRAWER_MAX_WIDTH
	)

	drawer.size = Vector2(
		_drawer_width,
		size.y
	)


func _open_position() -> Vector2:
	return Vector2(
		size.x - _drawer_width,
		0.0
	)


func _closed_position() -> Vector2:
	return Vector2(
		size.x + 4.0,
		0.0
	)


func _kill_transition() -> void:
	if _transition != null and _transition.is_valid():
		_transition.kill()

	_transition = null
