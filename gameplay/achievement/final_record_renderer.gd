class_name FinalRecordRenderer
extends RefCounted


const EXPORT_SIZE := Vector2i(
	1920,
	1080
)


func render_preview(
	record: Dictionary,
	parent: Node,
	size: Vector2i = Vector2i(
		960,
		540
	)
) -> Image:
	return await _render(
		record,
		parent,
		size
	)


func export_png(
	record: Dictionary,
	parent: Node
) -> Dictionary:
	var image := await _render(
		record,
		parent,
		EXPORT_SIZE
	)

	if image == null or image.is_empty():
		return {
			"ok": false,
			"error": "Không render được ảnh Final Record.",
		}

	var record_id := String(
		record.get(
			"record_id",
			"final_record"
		)
	).validate_filename()

	var app_dir := "user://final_records"
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(
			app_dir
		)
	)
	var app_path := app_dir.path_join(
		record_id + ".png"
	)
	var save_error := image.save_png(
		app_path
	)

	if save_error != OK:
		return {
			"ok": false,
			"error": "Không lưu được ảnh Final Record.",
		}

	var gallery_path := _try_save_to_pictures(
		image,
		record_id + ".png"
	)
	var durable_path := (
		gallery_path
		if not gallery_path.is_empty()
		else app_path
	)

	FinalRecordService.new().set_card_path(
		String(
			record.get(
				"record_id",
				""
			)
		),
		app_path
	)

	return {
		"ok": true,
		"path": durable_path,
		"app_path": app_path,
		"gallery_path": gallery_path,
	}


func _render(
	record: Dictionary,
	parent: Node,
	render_size: Vector2i
) -> Image:
	if (
		parent == null
		or not parent.is_inside_tree()
		or render_size.x <= 0
		or render_size.y <= 0
	):
		return null

	var viewport := SubViewport.new()
	viewport.name = "FinalRecordRenderViewport"
	viewport.size = render_size
	viewport.disable_3d = true
	viewport.transparent_bg = false
	viewport.render_target_update_mode = (
		SubViewport.UPDATE_ALWAYS
	)
	parent.add_child(viewport)

	var card := FinalRecordCard.new()
	card.name = "FinalRecordCard"
	viewport.add_child(card)
	card.setup(
		record,
		Vector2(
			render_size.x,
			render_size.y
		)
	)

	await parent.get_tree().process_frame
	await RenderingServer.frame_post_draw

	var image := viewport.get_texture().get_image()
	viewport.queue_free()
	return image


func _try_save_to_pictures(
	image: Image,
	file_name: String
) -> String:
	var pictures := OS.get_system_dir(
		OS.SYSTEM_DIR_PICTURES
	)

	if pictures.strip_edges().is_empty():
		return ""

	var target_dir := pictures.path_join(
		"PetVerse"
	)
	var make_error := (
		DirAccess.make_dir_recursive_absolute(
			target_dir
		)
	)

	if (
		make_error != OK
		and make_error != ERR_ALREADY_EXISTS
	):
		return ""

	var target_path := target_dir.path_join(
		file_name
	)

	if image.save_png(
		target_path
	) != OK:
		return ""

	return target_path
