extends PetHomeMenu
## Keeps the existing drawer; actions here control presentation, not inventory.
func _ready() -> void:
	super._ready()
	var entries: Dictionary = {&"lie": "Nằm nghỉ", &"sleep": "Ngủ", &"wake": "Đánh thức"}
	var container: Node = food_button.get_parent()
	var index: int = food_button.get_index() + 1
	for action_id: StringName in entries:
		var button := Button.new()
		button.text = entries[action_id]
		button.custom_minimum_size.y = 42.0
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 17)
		for style_name: StringName in [&"normal", &"hover", &"pressed"]:
			button.add_theme_stylebox_override(style_name, food_button.get_theme_stylebox(style_name))
		button.focus_mode = Control.FOCUS_NONE
		container.add_child(button)
		container.move_child(button, index)
		index += 1
		button.pressed.connect(_request_action.bind(action_id))

func _show_action_toast(action_id: StringName) -> void:
	if action_id in [&"food", &"lie", &"sleep", &"wake"]:
		return
	super._show_action_toast(action_id)
