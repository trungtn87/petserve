class_name MainScreen
extends RefCounted


signal next_phase_requested


const UI_REFRESH_INTERVAL: float = 0.10


var _root: Control

var _egg: EggFacade
var _hatch: HatchFacade

var _egg_view: Control
var _info_box: Control

var _task_label: Label
var _progress_label: Label

var _name_dialog: PetNameDialog
var _hatch_controller: EggHatchController

var _ui_refresh_timer: float = 0.0
var _ui_dirty: bool = false


func _init(
	root: Control,
	egg_facade: EggFacade,
	hatch_facade: HatchFacade
) -> void:
	_root = root
	_egg = egg_facade
	_hatch = hatch_facade


# =========================================================
# SETUP
# =========================================================

func setup() -> bool:
	_egg_view = _find_node("EggView") as Control
	_info_box = _find_node("InfoBox") as Control
	_task_label = _find_node("TaskLabel") as Label
	_progress_label = _find_node("ProgressLabel") as Label

	if _egg_view == null:
		push_error("MainScreen: Không tìm thấy EggView.")
		return false

	if _info_box == null:
		push_error("MainScreen: Không tìm thấy InfoBox.")
		return false

	if _task_label == null:
		push_error("MainScreen: Không tìm thấy TaskLabel.")
		return false

	if _progress_label == null:
		push_error("MainScreen: Không tìm thấy ProgressLabel.")
		return false

	_hatch_controller = EggHatchController.new(
		_egg,
		_hatch,
		_egg_view
	)

	if not _hatch_controller.setup():
		push_error(
			"MainScreen: Không setup được EggHatchController."
		)
		return false
	_setup_info_box()
	_create_name_dialog()
	_connect_signals()

	return true
func _find_node(
	node_name: String
) -> Node:
	return _root.find_child(
		node_name,
		true,
		false
	)


# =========================================================
# INFO BOX SETUP
# =========================================================

func _setup_info_box() -> void:
	_info_box.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_task_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progress_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_task_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_task_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_task_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progress_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	_task_label.add_theme_font_size_override(
		"font_size",
		17
	)

	_task_label.add_theme_color_override(
		"font_color",
		Color("#6B4A32")
	)

	_progress_label.add_theme_font_size_override(
		"font_size",
		18
	)

	_progress_label.add_theme_color_override(
		"font_color",
		Color("#6B4A32")
	)

# =========================================================
# NAME DIALOG
# =========================================================

func _create_name_dialog() -> void:
	_name_dialog = PetNameDialog.new()

	_name_dialog.name = "PetNameDialog"

	_root.add_child(
		_name_dialog
	)


# =========================================================
# SIGNALS
# =========================================================

func _connect_signals() -> void:

	var tapped_callable := Callable(
		self,
		"_on_egg_tapped"
	)

	var pressed_callable := Callable(
		self,
		"_on_egg_pressed"
	)

	var released_callable := Callable(
		self,
		"_on_egg_released"
	)


	if _egg_view.has_signal(
		"egg_tapped"
	):
		if not _egg_view.is_connected(
			"egg_tapped",
			tapped_callable
		):
			_egg_view.connect(
				"egg_tapped",
				tapped_callable
			)


	if _egg_view.has_signal(
		"egg_pressed"
	):
		if not _egg_view.is_connected(
			"egg_pressed",
			pressed_callable
		):
			_egg_view.connect(
				"egg_pressed",
				pressed_callable
			)


	if _egg_view.has_signal(
		"egg_released"
	):
		if not _egg_view.is_connected(
			"egg_released",
			released_callable
		):
			_egg_view.connect(
				"egg_released",
				released_callable
			)


	if not _name_dialog.submitted.is_connected(
		_on_name_submitted
	):
		_name_dialog.submitted.connect(
			_on_name_submitted
		)

	if (
		_hatch_controller != null
		and
		not _hatch_controller.hatch_completed.is_connected(
			_on_hatch_completed
		)
	):
		_hatch_controller.hatch_completed.connect(
			_on_hatch_completed
		)

	if (
		_hatch_controller != null
		and
		not _hatch_controller.next_phase_requested.is_connected(
			_on_next_phase_requested
		)
	):
		_hatch_controller.next_phase_requested.connect(
			_on_next_phase_requested
		)

func _on_hatch_completed() -> void:
	_force_refresh()


func _on_next_phase_requested() -> void:
	_prepare_next_phase_transition()
	next_phase_requested.emit()


func _prepare_next_phase_transition() -> void:
	if _name_dialog != null:
		_name_dialog.close_dialog()

	if _egg_view != null:
		if _egg_view.has_method("clear_egg"):
			_egg_view.call("clear_egg")

		_egg_view.visible = false
		_egg_view.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if _info_box != null:
		_info_box.visible = false
# =========================================================
# EGG INPUT
# =========================================================

func _on_egg_tapped() -> void:
	if (
		_hatch_controller != null
		and
		_hatch_controller.try_hatch()
	):
		return


	var event: String = (
		_egg.tap()
	)

	_process_egg_event(
		event
	)

func _on_egg_pressed() -> void:
	_egg.press()


func _on_egg_released() -> void:
	_egg.release()

	_force_refresh()


# =========================================================
# NAME INPUT
# =========================================================

func _on_name_submitted(
	raw_name: String
) -> void:

	var event: String = (
		_hatch.submit_name(
			raw_name
		)
	)


	match event:

		HatchFacade.EVENT_NAME_CONFIRMED:
			_name_dialog.close_dialog()

			_force_refresh()


		HatchFacade.EVENT_ALREADY_CONFIRMED:
			_name_dialog.close_dialog()

			_force_refresh()


		HatchFacade.EVENT_INVALID_NAME:
			_name_dialog.show_error(
				_hatch.get_last_error()
			)


		HatchFacade.EVENT_SAVE_FAILED:
			_name_dialog.show_error(
				_hatch.get_last_error()
			)


# =========================================================
# GAME LOOP
# =========================================================

func tick(
	delta: float
) -> void:

	_ui_refresh_timer += maxf(
		delta,
		0.0
	)


	if _egg.has_active_life():

		var event: String = (
			_egg.tick(
				delta
			)
		)

		_process_egg_event(
			event
		)


	if (
		_ui_dirty
		and
		_ui_refresh_timer >= UI_REFRESH_INTERVAL
	):
		refresh()


# =========================================================
# EGG EVENTS
# =========================================================

func _process_egg_event(
	event: String
) -> void:

	match event:

		EggFacade.EVENT_NONE:
			return


		EggFacade.EVENT_PROGRESS:
			_mark_dirty()


		EggFacade.EVENT_INTERRUPTED:
			_force_refresh()


		EggFacade.EVENT_STAGE_CHANGED:
			_force_refresh()


		EggFacade.EVENT_MUTATION:
			_force_refresh()


		EggFacade.EVENT_READY_TO_HATCH:
			_force_refresh()


		EggFacade.EVENT_NEW_LIFE:
			_force_refresh()


		EggFacade.EVENT_LOADED:
			_force_refresh()


		_:
			_mark_dirty()


func _mark_dirty() -> void:
	_ui_dirty = true


func _force_refresh() -> void:
	_ui_dirty = true

	_ui_refresh_timer = (
		UI_REFRESH_INTERVAL
	)

	refresh()


# =========================================================
# REFRESH
# =========================================================

func refresh() -> void:

	_ui_dirty = false
	_ui_refresh_timer = 0.0


	var data: Dictionary = (
		_egg.get_display_data()
	)


	if data.is_empty():
		_show_empty()
		return


	_sync_hatch_flow(
		data
	)


	var status: String = str(
		data.get(
			"status",
			"incubating"
		)
	)


	var task_value: Variant = data.get(
		"task",
		{}
	)


	var task: Dictionary = {}


	if typeof(
		task_value
	) == TYPE_DICTIONARY:
		task = (
			task_value as Dictionary
		)


	_update_info_box(
		status,
		task
	)


	_update_egg_view(
		data
	)


# =========================================================
# HATCH / NAME FLOW
# =========================================================

func _sync_hatch_flow(
	data: Dictionary
) -> void:

	var status: String = str(
		data.get(
			"status",
			""
		)
	)


	# =====================================================
	# CHƯA TỚI GIAI ĐOẠN NỞ
	# =====================================================

	if status != "ready_to_hatch":

		if _name_dialog != null:
			_name_dialog.close_dialog()

		return


	# =====================================================
	# READY TO HATCH
	# =====================================================

	var run_seed: int = int(
		data.get(
			"run_seed",
			0
		)
	)


	var event: String = (
		_hatch.prepare_for_run(
			run_seed
		)
	)


	match event:

		HatchFacade.EVENT_WAITING_NAME:
			_name_dialog.open_dialog()


		HatchFacade.EVENT_NAME_CONFIRMED:
			_name_dialog.close_dialog()


		HatchFacade.EVENT_SAVE_FAILED:
			_name_dialog.open_dialog()

			_name_dialog.show_error(
				"Không tạo được dữ liệu đặt tên."
			)


# =========================================================
# INFO BOX CONTENT
# =========================================================

func _update_info_box(
	status: String,
	task: Dictionary
) -> void:

	# =====================================================
	# READY TO HATCH
	# =====================================================

	if status == "ready_to_hatch":

		if _hatch.is_name_confirmed():
			_show_ready_to_hatch()

		else:
			_show_waiting_name()

		return


	# =====================================================
	# HATCHED
	# =====================================================

	if status == "hatched":

		_task_label.text = ""
		_progress_label.text = ""

		return


	# =====================================================
	# INCUBATING
	# =====================================================

	_show_incubation_task(
		task
	)


# =========================================================
# INCUBATION TASK
# =========================================================

func _show_incubation_task(
	task: Dictionary
) -> void:

	if task.is_empty():
		_task_label.text = "Đang chuẩn bị nhiệm vụ..."
		_progress_label.text = ""
		return

	var instruction: String = str(
		task.get(
			"instruction",
			""
		)
	)

	var mechanic: String = str(
		task.get(
			"mechanic",
			""
		)
	)

	var progress: float = float(
		task.get(
			"progress",
			0.0
		)
	)

	var target: float = float(
		task.get(
			"target",
			1.0
		)
	)

	_task_label.text = instruction

	_progress_label.text = _format_progress(
		mechanic,
		progress,
		target
	)
func _show_waiting_name() -> void:

	_task_label.text = "Hãy đặt tên cho pet"
	_progress_label.text = ""

# =========================================================
# READY TO HATCH
# =========================================================

func _show_ready_to_hatch() -> void:

	_task_label.text = "TRỨNG SẴN SÀNG NỞ"
	_progress_label.text = ""

# =========================================================
# PROGRESS FORMAT
# =========================================================

func _format_progress(
	mechanic: String,
	progress: float,
	target: float
) -> String:

	match mechanic:

		"tap":
			return (
				"%d / %d"
				% [
					int(progress),
					int(target)
				]
			)


		"warm", "rest":
			return (
				"%.1f / %.1f giây"
				% [
					progress,
					target
				]
			)


	return (
		"%.1f / %.1f"
		% [
			progress,
			target
		]
	)


# =========================================================
# EGG VIEW
# =========================================================

func _update_egg_view(
	data: Dictionary
) -> void:

	if _egg_view == null:
		return


	if not _egg_view.has_method(
		"set_egg"
	):
		return


	var egg_value: Variant = data.get(
		"egg",
		{}
	)


	if typeof(
		egg_value
	) != TYPE_DICTIONARY:
		return


	var egg_data: Dictionary = (
		egg_value as Dictionary
	).duplicate(
		true
	)


	_egg_view.call(
		"set_egg",
		egg_data
	)


# =========================================================
# EMPTY STATE
# =========================================================

func _show_empty() -> void:

	if _name_dialog != null:
		_name_dialog.close_dialog()

	if _task_label != null:
		_task_label.text = ""

	if _progress_label != null:
		_progress_label.text = ""

	if (
		_egg_view != null
		and
		_egg_view.has_method("clear_egg")
	):
		_egg_view.call("clear_egg")
