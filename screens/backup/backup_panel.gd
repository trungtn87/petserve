class_name BackupPanel
extends VBoxContainer

signal restore_started
signal restore_failed
signal restored
var save_callback: Callable
var _status: Label
var _export: Button
var _import: Button
var _native: Object
var _operation := ""
var _pending := ""
var _preview: ConfirmationDialog
var _preview_text: Label
var _preview_image: TextureRect
var _dialog: FileDialog

func _ready() -> void:
	add_theme_constant_override("separation", 12)
	var description := Label.new()
	description.text = "Backup gồm tiến trình, đồ, kỷ lục và ảnh pet.\nChọn bộ nhớ máy hoặc Google Drive trong trình chọn file Android.\nGiữ file ở ngoài game để dùng khi cài lại hoặc đổi máy."
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(description)
	_export = _button("Xuất bản sao lưu", _export_backup)
	_import = _button("Khôi phục từ file", _import_backup)
	if FileAccess.file_exists(BackupService.ROLLBACK):
		_button("Khôi phục bản trước lần nhập gần nhất", func(): _inspect(BackupService.ROLLBACK))
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)
	_preview = ConfirmationDialog.new()
	_preview.title = "Xác nhận khôi phục"
	_preview.ok_button_text = "Khôi phục"
	_preview.cancel_button_text = "Hủy"
	_preview.confirmed.connect(_restore)
	add_child(_preview)
	var preview_body := VBoxContainer.new()
	preview_body.add_theme_constant_override("separation", 10)
	_preview.add_child(preview_body)
	_preview_text = Label.new()
	_preview_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview_text.custom_minimum_size.x = 270
	preview_body.add_child(_preview_text)
	_preview_image = TextureRect.new()
	_preview_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview_image.custom_minimum_size = Vector2(0, 120)
	_preview_image.visible = false
	preview_body.add_child(_preview_image)
	if Engine.has_singleton("PetVerseBackup"):
		_native = Engine.get_singleton("PetVerseBackup")

func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 48
	button.pressed.connect(action)
	add_child(button)
	return button

func _busy(value: bool) -> void:
	_export.disabled = value
	_import.disabled = value

func _save_current() -> bool:
	if save_callback.is_valid() and not save_callback.call():
		_status.text = "Chưa lưu được tiến trình hiện tại. Chưa tạo backup."
		return false
	return true

func _export_backup() -> void:
	if not _save_current():
		return
	_status.text = "Đang tạo bản sao lưu…"
	_busy(true)
	var result := BackupService.snapshot_for_export()
	if not result.ok:
		_status.text = result.message
		_busy(false)
		return
	if _native != null:
		_operation = "export"
		if not _native.export_file(ProjectSettings.globalize_path(result.path), BackupService.suggested_name()):
			_status.text = "Không mở được trình chọn file."
			_busy(false)
	else:
		_show_dialog(FileDialog.FILE_MODE_SAVE_FILE, func(path: String):
			var error := DirAccess.copy_absolute(ProjectSettings.globalize_path(result.path), path)
			_status.text = "Đã xuất bản sao lưu." if error == OK else "Không ghi được file."
			_busy(false)
		)

func _import_backup() -> void:
	if _native != null:
		_busy(true)
		_operation = "import"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://backups"))
		if not _native.import_file(ProjectSettings.globalize_path("user://backups/import.petbackup")):
			_status.text = "Không mở được trình chọn file."
			_busy(false)
	else:
		_show_dialog(FileDialog.FILE_MODE_OPEN_FILE, _inspect)

func _show_dialog(mode: FileDialog.FileMode, selected: Callable) -> void:
	if is_instance_valid(_dialog):
		_dialog.queue_free()
	_dialog = FileDialog.new()
	_dialog.file_mode = mode
	_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_dialog.filters = PackedStringArray(["*.petbackup ; Bản sao lưu PetVerse"])
	_dialog.current_file = BackupService.suggested_name() if mode == FileDialog.FILE_MODE_SAVE_FILE else ""
	_dialog.file_selected.connect(selected)
	_dialog.canceled.connect(func(): _busy(false))
	add_child(_dialog)
	_dialog.popup_centered(Vector2i(320, 440))

func _process(_delta: float) -> void:
	if _native == null or _operation.is_empty():
		return
	var result_text: String = _native.take_result()
	if result_text.is_empty():
		return
	var result: Variant = JSON.parse_string(result_text)
	var operation := _operation
	_operation = ""
	_busy(false)
	if not result is Dictionary:
		_status.text = "Không đọc được kết quả chọn file."
		return
	_status.text = str(result.get("message", ""))
	if bool(result.get("ok", false)) and operation == "import":
		_inspect(str(result.path))

func _inspect(path: String) -> void:
	var result := BackupService.inspect_backup(path)
	if not result.ok:
		_status.text = result.message
		return
	# Copy selected archive to a stable cache: restoring the rollback snapshot must not overwrite its own source.
	_pending = "user://backups/selected.petbackup"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://backups"))
	if DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(_pending)) != OK:
		_status.text = "Không chuẩn bị được file khôi phục."
		return
	var summary: Dictionary = result.manifest.summary
	var date := Time.get_datetime_string_from_unix_time(int(result.manifest.get("created_at", 0))).replace("T", " ")
	_preview_text.text = "Pet: %s\nStage: %d\nLưu lúc: %s (UTC)\n\nDữ liệu hiện tại sẽ được thay bằng bản này.\nGame giữ một bản dự phòng trước khi thay." % [summary.pet_name, summary.stage, date]
	# Preview image comes from validated archive, never from an external path.
	_preview_image.visible = false
	_preview_image.texture = null
	var image_name: String = str(summary.image_path).trim_prefix("user://")
	if result.files.has(image_name):
		var image := Image.new()
		var bytes: PackedByteArray = result.files[image_name]
		var error := image.load_png_from_buffer(bytes)
		if error != OK:
			error = image.load_jpg_from_buffer(bytes)
		if error != OK:
			error = image.load_webp_from_buffer(bytes)
		if error == OK:
			_preview_image.texture = ImageTexture.create_from_image(image)
			_preview_image.visible = true
	_preview.popup_centered(Vector2i(320, 380))

func _restore() -> void:
	if not _save_current():
		return
	restore_started.emit()
	var result := BackupService.restore_backup(_pending)
	if not result.ok:
		_status.text = result.message
		restore_failed.emit()
		return
	_status.text = result.message
	restored.emit()
	LocalConnection.disconnect_session()
	RunManager.restore_or_prepare()
	AudioService.reload_settings()
	get_tree().change_scene_to_file("res://scenes/main.tscn")
