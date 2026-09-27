class_name GameThemeController
extends RefCounted


static func apply(
	root: Control
) -> void:
	if root == null:
		return

	root.theme = GameTheme.create()

	_apply_existing_labels(
		root
	)


static func _apply_existing_labels(
	root: Control
) -> void:
	var status: Label = (
		root.find_child(
			"StatusLabel",
			true,
			false
		) as Label
	)

	var seed: Label = (
		root.find_child(
			"SeedLabel",
			true,
			false
		) as Label
	)

	var task: Label = (
		root.find_child(
			"HatchTaskLabel",
			true,
			false
		) as Label
	)


	if status != null:
		status.add_theme_font_size_override(
			"font_size",
			GameTheme.FONT_HEADING
		)

		status.add_theme_color_override(
			"font_color",
			GameTheme.TEXT_PRIMARY
		)


	if seed != null:
		seed.add_theme_font_size_override(
			"font_size",
			GameTheme.FONT_SMALL
		)

		seed.add_theme_color_override(
			"font_color",
			GameTheme.TEXT_SECONDARY
		)


	if task != null:
		task.add_theme_font_size_override(
			"font_size",
			GameTheme.FONT_BODY
		)

		task.add_theme_color_override(
			"font_color",
			GameTheme.TEXT_PRIMARY
		)
