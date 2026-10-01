class_name FinalRecordCard
extends Control


const BASE_SIZE := Vector2(1920.0, 1080.0)


var _scale_factor: float = 1.0


func setup(
	record: Dictionary,
	canvas_size: Vector2 = BASE_SIZE
) -> void:
	for child in get_children():
		child.queue_free()

	size = canvas_size
	custom_minimum_size = canvas_size
	_scale_factor = (
		canvas_size.x / BASE_SIZE.x
		if BASE_SIZE.x > 0.0
		else 1.0
	)

	var element_id := StringName(
		String(
			record.get(
				"element_id",
				"dark"
			)
		)
	)
	var palette := PetHomeTheme.for_element(
		element_id
	)
	var panel_color: Color = palette.get(
		"panel",
		Color("#171229")
	)
	var accent: Color = palette.get(
		"accent",
		Color("#A98AF4")
	)
	var text_color: Color = palette.get(
		"text",
		Color.WHITE
	)
	var muted: Color = palette.get(
		"muted",
		Color("#C3B2E8")
	)

	var background := ColorRect.new()
	background.position = Vector2.ZERO
	background.size = canvas_size
	background.color = panel_color.darkened(
		0.24
	)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	_add_glow(
		Vector2(
			_s(1320.0),
			_s(180.0)
		),
		_s(420.0),
		accent
	)
	_add_glow(
		Vector2(
			_s(340.0),
			_s(900.0)
		),
		_s(330.0),
		accent.lightened(0.18)
	)

	var title := Label.new()
	title.text = "PET LIFE RECORD"
	title.position = Vector2(
		_s(60.0),
		_s(44.0)
	)
	title.size = Vector2(
		_s(1160.0),
		_s(58.0)
	)
	title.add_theme_font_size_override(
		"font_size",
		int(_s(38.0))
	)
	title.add_theme_color_override(
		"font_color",
		text_color
	)
	title.add_theme_constant_override(
		"outline_size",
		int(_s(5.0))
	)
	title.add_theme_color_override(
		"font_outline_color",
		panel_color.darkened(0.45)
	)
	add_child(title)

	var subtitle := Label.new()
	subtitle.text = (
		String(
			record.get(
				"display_name",
				"Pet"
			)
		)
		+ "  •  Generation #"
		+ str(
			int(
				record.get(
					"generation",
					0
				)
			) + 1
		)
	)
	subtitle.position = Vector2(
		_s(62.0),
		_s(98.0)
	)
	subtitle.size = Vector2(
		_s(1500.0),
		_s(38.0)
	)
	subtitle.add_theme_font_size_override(
		"font_size",
		int(_s(21.0))
	)
	subtitle.add_theme_color_override(
		"font_color",
		muted
	)
	add_child(subtitle)

	var snapshots_value: Variant = record.get(
		"card_snapshots",
		[]
	)
	var snapshots: Array = (
		snapshots_value as Array
		if typeof(snapshots_value) == TYPE_ARRAY
		else []
	)
	var labels := [
		"STAGE I",
		"STAGE II",
		"STAGE III",
		"FINAL",
	]
	var panel_width := _s(432.0)
	var panel_height := _s(768.0)
	var panel_y := _s(152.0)
	var left := _s(60.0)
	var gap := _s(24.0)

	for index in range(4):
		var snapshot: Dictionary = {}

		if (
			index < snapshots.size()
			and typeof(
				snapshots[index]
			) == TYPE_DICTIONARY
		):
			snapshot = (
				snapshots[index] as Dictionary
			)

		_add_stage_panel(
			Vector2(
				left
				+ float(index)
				* (
					panel_width
					+ gap
				),
				panel_y
			),
			Vector2(
				panel_width,
				panel_height
			),
			String(
				snapshot.get(
					"image_path",
					""
				)
			),
			labels[index],
			index == 3,
			panel_color,
			accent,
			text_color
		)

	var footer := Label.new()
	footer.position = Vector2(
		_s(60.0),
		_s(944.0)
	)
	footer.size = Vector2(
		_s(1360.0),
		_s(56.0)
	)
	footer.text = (
		"Hoàn thành • "
		+ _format_date(
			int(
				record.get(
					"completed_at_unix",
					0
				)
			)
		)
	)
	footer.add_theme_font_size_override(
		"font_size",
		int(_s(20.0))
	)
	footer.add_theme_color_override(
		"font_color",
		muted
	)
	add_child(footer)

	var brand := Label.new()
	brand.text = "PETVERSE"
	brand.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_RIGHT
	)
	brand.position = Vector2(
		_s(1450.0),
		_s(944.0)
	)
	brand.size = Vector2(
		_s(410.0),
		_s(56.0)
	)
	brand.add_theme_font_size_override(
		"font_size",
		int(_s(20.0))
	)
	brand.add_theme_color_override(
		"font_color",
		accent
	)
	add_child(brand)


func _add_stage_panel(
	panel_position: Vector2,
	panel_size: Vector2,
	image_path: String,
	label_text: String,
	is_final: bool,
	panel_color: Color,
	accent: Color,
	text_color: Color
) -> void:
	var holder := Control.new()
	holder.position = panel_position
	holder.size = panel_size
	holder.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)
	add_child(holder)

	var image_rect := TextureRect.new()
	image_rect.position = Vector2.ZERO
	image_rect.size = panel_size
	image_rect.expand_mode = (
		TextureRect.EXPAND_IGNORE_SIZE
	)
	image_rect.stretch_mode = (
		TextureRect.STRETCH_KEEP_ASPECT_COVERED
	)
	image_rect.texture = _load_texture(
		image_path
	)
	image_rect.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)
	holder.add_child(image_rect)

	if image_rect.texture == null:
		var placeholder := ColorRect.new()
		placeholder.position = Vector2.ZERO
		placeholder.size = panel_size
		placeholder.color = panel_color.lightened(
			0.07
		)
		placeholder.mouse_filter = (
			Control.MOUSE_FILTER_IGNORE
		)
		holder.add_child(placeholder)

	var shade := ColorRect.new()
	shade.position = Vector2(
		0.0,
		panel_size.y - _s(82.0)
	)
	shade.size = Vector2(
		panel_size.x,
		_s(82.0)
	)
	shade.color = Color(
		0.02,
		0.02,
		0.04,
		0.74
	)
	shade.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)
	holder.add_child(shade)

	var label := Label.new()
	label.text = label_text
	label.position = Vector2(
		_s(18.0),
		panel_size.y - _s(68.0)
	)
	label.size = Vector2(
		panel_size.x - _s(36.0),
		_s(50.0)
	)
	label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	label.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)
	label.add_theme_font_size_override(
		"font_size",
		int(
			_s(
				27.0
				if is_final
				else 22.0
			)
		)
	)
	label.add_theme_color_override(
		"font_color",
		(
			accent.lightened(0.24)
			if is_final
			else text_color
		)
	)
	label.add_theme_constant_override(
		"outline_size",
		int(_s(3.0))
	)
	label.add_theme_color_override(
		"font_outline_color",
		Color(0.02, 0.02, 0.04, 0.92)
	)
	holder.add_child(label)

	var border := Panel.new()
	border.position = Vector2.ZERO
	border.size = panel_size
	border.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = accent
	style.border_color.a = (
		0.98
		if is_final
		else 0.46
	)
	var width := (
		int(_s(5.0))
		if is_final
		else int(_s(2.0))
	)
	style.border_width_left = width
	style.border_width_top = width
	style.border_width_right = width
	style.border_width_bottom = width
	style.corner_radius_top_left = int(
		_s(18.0)
	)
	style.corner_radius_top_right = int(
		_s(18.0)
	)
	style.corner_radius_bottom_left = int(
		_s(18.0)
	)
	style.corner_radius_bottom_right = int(
		_s(18.0)
	)
	border.add_theme_stylebox_override(
		"panel",
		style
	)
	holder.add_child(border)


func _add_glow(
	center: Vector2,
	radius: float,
	color: Color
) -> void:
	var glow := GradientTexture2D.new()
	var gradient := Gradient.new()
	var transparent := color
	transparent.a = 0.0
	var visible := color
	visible.a = 0.18
	gradient.colors = PackedColorArray([
		visible,
		transparent,
	])
	gradient.offsets = PackedFloat32Array([
		0.0,
		1.0,
	])
	glow.gradient = gradient
	glow.fill = GradientTexture2D.FILL_RADIAL
	glow.fill_from = Vector2(0.5, 0.5)
	glow.fill_to = Vector2(1.0, 0.5)
	glow.width = maxi(
		2,
		int(radius * 2.0)
	)
	glow.height = glow.width

	var rect := TextureRect.new()
	rect.texture = glow
	rect.position = center - Vector2.ONE * radius
	rect.size = Vector2.ONE * radius * 2.0
	rect.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)
	add_child(rect)


func _load_texture(
	path: String
) -> Texture2D:
	if path.strip_edges().is_empty():
		return null

	var image := Image.load_from_file(
		path
	)

	if image == null:
		return null

	return ImageTexture.create_from_image(
		image
	)


func _format_date(
	unix_time: int
) -> String:
	if unix_time <= 0:
		return "--/--/----"

	var date := Time.get_datetime_dict_from_unix_time(
		unix_time
	)

	return "%02d/%02d/%04d" % [
		int(date.get("day", 0)),
		int(date.get("month", 0)),
		int(date.get("year", 0)),
	]


func _s(
	value: float
) -> float:
	return value * _scale_factor
