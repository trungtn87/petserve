extends ColorRect


func _ready() -> void:
	color = GameTheme.BG

	mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	set_anchors_preset(
		Control.PRESET_FULL_RECT
	)

	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
