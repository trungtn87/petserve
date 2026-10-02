extends Node
## Portable, allowlisted ZIP snapshots. Restore journal rolls back before any save reader starts.
const FORMAT := 1
const MAX_TOTAL := 128 * 1024 * 1024
const MAX_FILE := 16 * 1024 * 1024
const MAX_FILES := 512
const DATA_FILES := ["save_v11.json", "meta_v1.json", "hatch_v11.json", "evolution_pet_v1.json", "legacy_inheritance_v1.json", "final_record_archive_v1.json", "tetris_records_v1.json", "tank_records_solo.json", "tank_records_duo.json", "settings_v1.json", "jigsaw_v1.json", "daily_rewards_v2.json"]
const IMAGE_DIRS := ["pet_renders", "final_records", "mock"]
const JOURNAL := "user://backups/restore_pending.json"
const ROLLBACK := "user://backups/before_restore.petbackup"
var recovery_ok := true

func _enter_tree() -> void:
	recovery_ok = recover_interrupted_restore()
	if not recovery_ok:
		AtomicJson.blocked = true
		push_error("Không khôi phục được bản dự phòng. Giữ nguyên các file để thử lại.")
		get_tree().quit(1)

func _ready() -> void:
	var settings := AtomicJson.read("user://settings_v1.json")
	AudioServer.set_bus_mute(0, not bool(settings.get("sound", true)))

func _error(message: String) -> Dictionary:
	return {"ok": false, "message": message}

func _allowed(path: String) -> bool:
	if path.is_empty() or path.begins_with("/") or path.contains("\\") or path.contains(":"):
		return false
	for part in path.split("/"):
		if part in ["", ".", ".."] or part.begins_with("."):
			return false
	if path in DATA_FILES:
		return true
	return path.get_base_dir() in IMAGE_DIRS and path.get_extension().to_lower() in ["png", "jpg", "jpeg", "webp"]

func _paths() -> PackedStringArray:
	var paths := PackedStringArray()
	for path in DATA_FILES:
		if AtomicJson.exists("user://" + path):
			paths.append(path)
	for folder in IMAGE_DIRS:
		if not DirAccess.dir_exists_absolute("user://" + folder):
			continue
		for name in DirAccess.get_files_at("user://" + folder):
			var path: String = folder + "/" + name
			if _allowed(path):
				paths.append(path)
	paths.sort()
	return paths

func _hash(bytes: PackedByteArray) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	return hash.finish().hex_encode()

func _summary(files: Dictionary) -> Dictionary:
	var pet: Dictionary = JSON.parse_string(files.get("evolution_pet_v1.json", PackedByteArray()).get_string_from_utf8()) if files.has("evolution_pet_v1.json") else {}
	var genome: Dictionary = pet.get("genome", {}) if pet.get("genome") is Dictionary else {}
	var visual: Dictionary = pet.get("current_visual", {}) if pet.get("current_visual") is Dictionary else {}
	return {"pet_name": str(pet.get("pet_name", "Trứng / chưa có pet")), "stage": int(genome.get("stage", 0)), "image_path": str(visual.get("image_path", ""))}

func create_backup(path: String) -> Dictionary:
	if FileAccess.file_exists(JOURNAL):
		return _error("Đang chờ khôi phục bản dự phòng. Hãy mở lại game.")
	var files := {}
	var total := 0
	for name in _paths():
		var source: String = "user://" + name
		if name in DATA_FILES and (not FileAccess.file_exists(source) or not AtomicJson._parse(FileAccess.get_file_as_string(source)) is Dictionary):
			source += ".bak"
		var file := FileAccess.open(source, FileAccess.READ)
		if file == null or file.get_length() > MAX_FILE:
			return _error("Không đọc được dữ liệu hoặc ảnh quá lớn: " + name)
		var bytes := file.get_buffer(file.get_length())
		file.close()
		if name in DATA_FILES and not AtomicJson._parse(bytes.get_string_from_utf8()) is Dictionary:
			return _error("Dữ liệu không hợp lệ: " + name)
		files[name] = bytes
		total += bytes.size()
	if total > MAX_TOTAL or files.size() > MAX_FILES:
		return _error("Dữ liệu vượt giới hạn backup 128 MB / 512 file.")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var entries := []
	for name in files:
		entries.append({"path": name, "size": files[name].size(), "sha256": _hash(files[name])})
	var manifest := {"app": "PetVerse", "format": FORMAT, "created_at": int(Time.get_unix_time_from_system()), "game_version": ProjectSettings.get_setting("application/config/version"), "summary": _summary(files), "entries": entries}
	var zip := ZIPPacker.new()
	if zip.open(path + ".tmp") != OK:
		return _error("Không tạo được file backup.")
	var ok := zip.start_file("manifest.json") == OK
	ok = zip.write_file(JSON.stringify(manifest).to_utf8_buffer()) == OK and ok
	ok = zip.close_file() == OK and ok
	for name in files:
		ok = zip.start_file("data/" + name) == OK and ok
		ok = zip.write_file(files[name]) == OK and ok
		ok = zip.close_file() == OK and ok
	ok = zip.close() == OK and ok
	if not ok:
		return _error("Không ghi được toàn bộ backup.")
	var checked := inspect_backup(path + ".tmp")
	if not checked.ok:
		return checked
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path)) != OK:
		return _error("Không hoàn tất được file backup.")
	return {"ok": true, "path": path, "manifest": manifest}

func inspect_backup(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_TOTAL:
		return _error("Không mở được backup hoặc file lớn hơn 128 MB.")
	file.close()
	if not _archive_limits(path):
		return _error("Cấu trúc hoặc kích thước file nén không hợp lệ.")
	var zip := ZIPReader.new()
	if zip.open(path) != OK:
		return _error("File backup không hợp lệ.")
	var names := zip.get_files()
	# Archive central-directory limits are checked before decompression.
	var manifest_bytes := zip.read_file("manifest.json")
	var value: Variant = JSON.parse_string(manifest_bytes.get_string_from_utf8())
	if not value is Dictionary or value.get("app") != "PetVerse" or value.get("format") != FORMAT or not value.get("entries") is Array:
		zip.close()
		return _error("Backup khác game hoặc phiên bản chưa hỗ trợ.")
	var manifest: Dictionary = value
	if not manifest.get("created_at") is float and not manifest.get("created_at") is int:
		zip.close()
		return _error("Backup thiếu thời gian lưu.")
	if manifest.entries.size() > MAX_FILES or names.size() != manifest.entries.size() + 1 or not names.has("manifest.json"):
		zip.close()
		return _error("Danh sách file backup không hợp lệ.")
	var files := {}
	var total := 0
	for item in manifest.entries:
		if not item is Dictionary or not item.get("path") is String or not _allowed(item.path) or files.has(item.path):
			zip.close()
			return _error("Đường dẫn file backup không hợp lệ.")
		var size := int(item.get("size", -1))
		total += size
		if size < 0 or size > MAX_FILE or total > MAX_TOTAL or not names.has("data/" + item.path):
			zip.close()
			return _error("Kích thước hoặc nội dung backup không hợp lệ.")
		var bytes := zip.read_file("data/" + item.path)
		if bytes.size() != size or _hash(bytes) != item.get("sha256", ""):
			zip.close()
			return _error("Backup bị hỏng: " + item.path)
		if item.path in DATA_FILES and not AtomicJson._parse(bytes.get_string_from_utf8()) is Dictionary:
			zip.close()
			return _error("Dữ liệu game không hợp lệ: " + item.path)
		files[item.path] = bytes
	zip.close()
	# Do not accept a pet without its identity, genome, visual or image dependencies.
	if files.has("evolution_pet_v1.json"):
		var pet: Dictionary = JSON.parse_string(files["evolution_pet_v1.json"].get_string_from_utf8())
		if not pet.get("identity") is Dictionary or not pet.get("genome") is Dictionary or not pet.get("current_visual") is Dictionary:
			return _error("Backup thiếu thông tin pet.")
		if PetIdentity.from_dict(pet.identity) == null or PetGenome.from_dict(pet.genome) == null or PetVisualRecord.from_dict(pet.current_visual) == null:
			return _error("Thông tin pet không hợp lệ.")
		if int(pet.get("schema", 1)) > EvolutionSaveService.CURRENT_SCHEMA:
			return _error("Dữ liệu pet cần phiên bản game mới hơn.")
		var image_path: String = str(pet.current_visual.get("image_path", ""))
		if image_path.begins_with("user://") and not files.has(image_path.trim_prefix("user://")):
			return _error("Backup thiếu ảnh pet.")
	if files.has("meta_v1.json"):
		var meta: Dictionary = AtomicJson._parse(files["meta_v1.json"].get_string_from_utf8())
		if int(meta.get("schema", 1)) > InfantGameFacade.META_SCHEMA or not meta.get("inventory", []) is Array or not meta.get("chest_queue", []) is Array:
			return _error("Dữ liệu túi đồ không hợp lệ hoặc cần game mới hơn.")
	# Summary is rebuilt from verified data rather than trusting display metadata.
	manifest["summary"] = _summary(files)
	return {"ok": true, "manifest": manifest, "files": files}

func restore_backup(path: String) -> Dictionary:
	var checked := inspect_backup(path)
	if not checked.ok:
		return checked
	var before := create_backup(ROLLBACK)
	if not before.ok:
		return _error("Không tạo được bản dự phòng; chưa thay dữ liệu. " + before.message)
	var targets: Array = checked.files.keys()
	for name in _paths():
		if not targets.has(name):
			targets.append(name)
	if not AtomicJson.write(JOURNAL, {"targets": targets}):
		return _error("Không chuẩn bị được khôi phục. Dữ liệu vẫn giữ nguyên.")
	if not _apply(checked.files, targets):
		recovery_ok = recover_interrupted_restore()
		AtomicJson.blocked = not recovery_ok
		return _error("Khôi phục thất bại. " + ("Đã trả lại dữ liệu cũ." if recovery_ok else "Hãy đóng và mở lại game để phục hồi bản dự phòng."))
	# Removing the pending marker commits the transaction. Old snapshot remains recoverable.
	if not AtomicJson.erase(JOURNAL):
		recovery_ok = recover_interrupted_restore()
		AtomicJson.blocked = not recovery_ok
		return _error("Không hoàn tất được khôi phục. Đã thử trả lại dữ liệu cũ.")
	return {"ok": true, "message": "Đã khôi phục dữ liệu."}

func _apply(files: Dictionary, targets: Array) -> bool:
	for name in targets:
		if not name is String or not _allowed(name):
			return false
		var path: String = "user://" + name
		if not files.has(name):
			if not AtomicJson.erase(path):
				return false
		else:
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
			var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
			if file == null:
				return false
			file.store_buffer(files[name])
			file.flush()
			var error := file.get_error()
			file.close()
			if error != OK or DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path)) != OK:
				return false
			# Previous-life fallback must never resurrect after a successful restore.
			if not AtomicJson.erase(path + ".bak"):
				return false
	return true

func recover_interrupted_restore() -> bool:
	if not FileAccess.file_exists(JOURNAL):
		return true
	var journal: Variant = JSON.parse_string(FileAccess.get_file_as_string(JOURNAL))
	if not journal is Dictionary or not journal.get("targets") is Array:
		return false
	var before := inspect_backup(ROLLBACK)
	if not before.ok or not _apply(before.files, journal.targets):
		return false
	return AtomicJson.erase(JOURNAL)

func snapshot_for_export() -> Dictionary:
	return create_backup("user://backups/export.petbackup")

func suggested_name() -> String:
	return "PetVerse_" + Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_") + ".petbackup"

func _archive_limits(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() < 22:
		return false
	var length := file.get_length()
	file.seek(maxi(0, length - 65557))
	var tail := file.get_buffer(mini(length, 65557))
	var end := -1
	for i in range(tail.size() - 22, -1, -1):
		if tail.decode_u32(i) == 0x06054b50 and i + 22 + tail.decode_u16(i + 20) == tail.size():
			end = i
			break
	if end < 0 or tail.decode_u16(end + 4) != 0 or tail.decode_u16(end + 6) != 0:
		return false
	var count := tail.decode_u16(end + 10)
	var size := tail.decode_u32(end + 12)
	var offset := tail.decode_u32(end + 16)
	if count < 1 or count > MAX_FILES + 1 or tail.decode_u16(end + 8) != count or size > 1024 * 1024 or offset + size > length - 22:
		return false
	file.seek(offset)
	var central := file.get_buffer(size)
	var cursor := 0
	var total := 0
	var seen := {}
	for i in range(count):
		if cursor + 46 > central.size() or central.decode_u32(cursor) != 0x02014b50:
			return false
		var unpacked := central.decode_u32(cursor + 24)
		var packed := central.decode_u32(cursor + 20)
		var name_size := central.decode_u16(cursor + 28)
		var extra := central.decode_u16(cursor + 30)
		var comment := central.decode_u16(cursor + 32)
		var local := central.decode_u32(cursor + 42)
		var flags := central.decode_u16(cursor + 8)
		var method := central.decode_u16(cursor + 10)
		if cursor + 46 + name_size + extra + comment > central.size() or local + 30 + packed > offset or flags & 1 or method not in [0, 8]:
			return false
		var name := central.slice(cursor + 46, cursor + 46 + name_size).get_string_from_utf8()
		if seen.has(name) or (name != "manifest.json" and (not name.begins_with("data/") or not _allowed(name.trim_prefix("data/")))):
			return false
		seen[name] = true
		total += unpacked
		if unpacked > (256 * 1024 if name == "manifest.json" else MAX_FILE) or total > MAX_TOTAL:
			return false
		# Require local header to agree with central directory before ZIPReader allocates.
		file.seek(local)
		var header := file.get_buffer(30)
		if header.size() != 30 or header.decode_u32(0) != 0x04034b50 or header.decode_u16(8) != method:
			return false
		var local_name_size := header.decode_u16(26)
		if local + 30 + local_name_size + header.decode_u16(28) + packed > offset or file.get_buffer(local_name_size).get_string_from_utf8() != name:
			return false
		cursor += 46 + name_size + extra + comment
	file.close()
	return cursor == central.size() and seen.has("manifest.json")
