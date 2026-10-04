extends Node
var failures := 0
var checks := 0

func _ready() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func zip_fixture(path: String, manifest: Dictionary, files: Dictionary) -> void:
	var zip := ZIPPacker.new()
	zip.open(path)
	zip.start_file("manifest.json")
	zip.write_file(JSON.stringify(manifest).to_utf8_buffer())
	zip.close_file()
	for name in files:
		zip.start_file("data/" + name)
		zip.write_file(files[name])
		zip.close_file()
	zip.close()

func run() -> void:
	var backup := get_tree().root.get_node("BackupService")
	check(AtomicJson.write("user://save_v11.json", {"schema": 1, "marker": "old"}), "write initial")
	check(AtomicJson.write("user://save_v11.json", {"schema": 1, "marker": "new"}), "write new")
	check(AtomicJson.read("user://save_v11.json").marker == "new", "read latest")
	var corrupt := FileAccess.open("user://save_v11.json", FileAccess.WRITE)
	corrupt.store_string("{")
	corrupt.close()
	check(AtomicJson.read("user://save_v11.json").marker == "old", "damaged primary falls back")
	check(AtomicJson.write("user://save_v11.json", {"schema": 1, "marker": "snapshot"}), "repair primary")
	var identity := PetIdentityFactory.new().create_initial(456, &"dark")
	var genome := PetGenomeFactory.new().create_initial()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://pet_renders"))
	var image := Image.create(32, 48, false, Image.FORMAT_RGBA8)
	image.fill(Color("252139"))
	image.save_png("user://pet_renders/test.png")
	var visual := PetVisualRecord.new()
	visual.pet_id = identity.pet_id()
	visual.image_path = "user://pet_renders/test.png"
	visual.source_mode = &"initial_pethome_v14_habitat_frame"
	visual.renderer_id = &"test"
	visual.model_id = &"test"
	check(EvolutionSaveService.new().save_initial(identity, genome, visual, "Mèo"), "save pet fixture")
	check(AtomicJson.write("user://meta_v1.json", {"schema": 1, "inventory": [{"uid": "item1"}], "chest_queue": [], "chest_fragments": 9}), "save inventory")
	check(AtomicJson.write("user://settings_v1.json", {"sound": false}), "save settings")
	check(AtomicJson.write("user://tetris_records_v1.json", {"schema": 1, "score": 321}), "save leaderboard")
	check(AtomicJson.write("user://food_catch_records_v1.json", {"best_score": 1500}), "save food catch leaderboard")
	var secret := FileAccess.open("user://credentials.json", FileAccess.WRITE)
	secret.store_string("token never exported")
	secret.close()
	var exported: Dictionary = backup.create_backup("user://snapshot.petbackup")
	check(exported.ok, "create portable backup: " + str(exported.get("message", "")))
	if not exported.ok:
		get_tree().quit(1)
		return
	var original: Dictionary = backup.inspect_backup("user://snapshot.petbackup")
	check(original.ok, "inspect backup")
	check(original.files.has("food_catch_records_v1.json"), "include food catch leaderboard")
	check(original.files.has("pet_renders/test.png"), "include actual image")
	check(not original.files.has("credentials.json"), "exclude secrets and unknown files")
	check(original.manifest.summary.pet_name == "Mèo", "pet preview data")
	check(original.manifest.summary.stage == 1, "stage preview data")
	var manifest: Dictionary = original.manifest.duplicate(true)
	manifest.format = 999
	zip_fixture("user://future.petbackup", manifest, original.files)
	check(not backup.inspect_backup("user://future.petbackup").ok, "reject future format")
	manifest = original.manifest.duplicate(true)
	var broken: Dictionary = original.files.duplicate()
	broken["meta_v1.json"] = "{}".to_utf8_buffer()
	zip_fixture("user://damaged.petbackup", manifest, broken)
	check(not backup.inspect_backup("user://damaged.petbackup").ok, "reject checksum mismatch")
	manifest.entries[0].path = "../outside.json"
	zip_fixture("user://traversal.petbackup", manifest, original.files)
	check(not backup.inspect_backup("user://traversal.petbackup").ok, "reject traversal")
	manifest = original.manifest.duplicate(true)
	manifest.entries.append(manifest.entries[0])
	zip_fixture("user://duplicate.petbackup", manifest, original.files)
	check(not backup.inspect_backup("user://duplicate.petbackup").ok, "reject duplicate entries")
	manifest = original.manifest.duplicate(true)
	var forged: Dictionary = original.files.duplicate()
	forged["meta_v1.json"] = "[]".to_utf8_buffer()
	for item in manifest.entries:
		if item.path == "meta_v1.json":
			item.size = forged[item.path].size()
			item.sha256 = backup._hash(forged[item.path])
	zip_fixture("user://wrongtype.petbackup", manifest, forged)
	check(not backup.inspect_backup("user://wrongtype.petbackup").ok, "reject non-dictionary game data")
	AtomicJson.write("user://save_v11.json", {"marker": "current"})
	AtomicJson.write("user://tank_records_solo.json", {"score": 999})
	var saved_bytes := FileAccess.get_file_as_bytes("user://save_v11.json")
	check(not backup.restore_backup("user://damaged.petbackup").ok, "bad restore rejected")
	check(FileAccess.get_file_as_bytes("user://save_v11.json") == saved_bytes, "bad restore leaves current untouched")
	AtomicJson.write("user://food_catch_records_v1.json", {"best_score": 9999})
	var restored: Dictionary = backup.restore_backup("user://snapshot.petbackup")
	check(AtomicJson.read("user://food_catch_records_v1.json").get("best_score", 0) == 1500, "restore food catch leaderboard")
	check(restored.ok, "restore complete snapshot: " + str(restored.get("message", "")))
	check(AtomicJson.read("user://save_v11.json").marker == "snapshot", "restore progress")
	check(AtomicJson.read("user://meta_v1.json").inventory[0].uid == "item1", "restore inventory")
	check(FileAccess.get_file_as_bytes("user://pet_renders/test.png") == original.files["pet_renders/test.png"], "restore identical image bytes")
	check(not AtomicJson.exists("user://tank_records_solo.json"), "remove records absent in incoming backup including fallback")
	check(FileAccess.file_exists("user://credentials.json"), "leave unmanaged local data untouched")
	check(not FileAccess.file_exists(backup.JOURNAL), "clear journal after commit")
	check(backup.inspect_backup(backup.ROLLBACK).ok, "retain valid pre-restore backup")
	check(backup.inspect_backup(backup.ROLLBACK).files.has("tank_records_solo.json"), "pre-restore includes old records")
	# Simulate process death after only some target files have changed.
	check(backup.create_backup(backup.ROLLBACK).ok, "prepare crash recovery snapshot")
	AtomicJson.write(backup.JOURNAL, {"targets": ["save_v11.json", "meta_v1.json", "tank_records_duo.json"]})
	AtomicJson.write("user://save_v11.json", {"marker": "half_written"})
	AtomicJson.write("user://tank_records_duo.json", {"score": 888})
	check(backup.recover_interrupted_restore(), "recover interrupted multi-file restore")
	check(AtomicJson.read("user://save_v11.json").marker == "snapshot", "recovery restores original generation")
	check(not AtomicJson.exists("user://tank_records_duo.json"), "recovery deletes files introduced by failed restore")
	check(not FileAccess.file_exists(backup.JOURNAL), "recovery clears marker")
	check(AtomicJson.erase("user://save_v11.json"), "delete save safely")
	check(not AtomicJson.exists("user://save_v11.json"), "deleted life cannot resurrect fallback")
	check(backup._allowed("pet_renders/test.png") and not backup._allowed("pet_renders/../test.png"), "path allowlist")
	# Mutate central-directory unpacked length; reject before decompression.
	var bomb := FileAccess.get_file_as_bytes("user://snapshot.petbackup")
	for i in range(bomb.size() - 46):
		if bomb.decode_u32(i) == 0x02014b50:
			bomb.encode_u32(i + 24, backup.MAX_TOTAL + 1)
			break
	var bomb_file := FileAccess.open("user://bomb.petbackup", FileAccess.WRITE)
	bomb_file.store_buffer(bomb)
	bomb_file.close()
	check(not backup.inspect_backup("user://bomb.petbackup").ok, "reject decompression bomb before read")
	var panel := BackupPanel.new()
	get_tree().root.add_child(panel)
	check(panel.get_child_count() >= 4, "backup UI available on fresh install")
	panel._inspect("user://snapshot.petbackup")
	check(panel._preview.visible and panel._preview_text.text.contains("Mèo"), "restore confirmation opens with verified pet details")
	check(panel._preview_image.visible and panel._preview_image.texture != null, "restore preview includes actual pet image")
	print("BACKUP TESTS: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)
