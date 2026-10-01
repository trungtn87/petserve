class_name InitialPetVisualSpec
extends RefCounted


var pet_id: String = ""
var style_id: StringName = &""

var identity_section: String = ""
var style_section: String = ""
var form_section: String = ""
var scene_section: String = ""
var composition_section: String = ""
var ui_safe_section: String = ""
var future_space_section: String = ""

var negative_prompt: String = ""


func is_valid() -> bool:
	return (
		not pet_id.is_empty()
		and not String(style_id).is_empty()
		and not identity_section.is_empty()
		and not style_section.is_empty()
		and not form_section.is_empty()
		and not scene_section.is_empty()
		and not composition_section.is_empty()
		and not ui_safe_section.is_empty()
		and not future_space_section.is_empty()
		and not negative_prompt.is_empty()
	)
