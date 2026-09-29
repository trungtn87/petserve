class_name PetRenderRequest
extends RefCounted


enum RenderMode {
	INITIAL_TEXT_TO_IMAGE,
	EVOLUTION_IMAGE_EDIT,
}


var mode: RenderMode = RenderMode.INITIAL_TEXT_TO_IMAGE

var pet_id: String = ""
var positive_prompt: String = ""
var negative_prompt: String = ""

var source_image_path: String = ""
var target_region: StringName = &""
var edit_strength: float = 0.0
var seed: int = 0

var output_key: String = ""


func is_valid() -> bool:
	if (
		pet_id.is_empty()
		or positive_prompt.is_empty()
		or output_key.is_empty()
	):
		return false

	match mode:
		RenderMode.INITIAL_TEXT_TO_IMAGE:
			return source_image_path.is_empty()

		RenderMode.EVOLUTION_IMAGE_EDIT:
			return (
				not source_image_path.is_empty()
				and not String(target_region).is_empty()
				and edit_strength > 0.0
				and edit_strength <= 1.0
				and seed >= 0
			)

	return false


func to_debug_dict() -> Dictionary:
	return {
		"mode": int(mode),
		"pet_id": pet_id,
		"positive_prompt": positive_prompt,
		"negative_prompt": negative_prompt,
		"source_image_path": source_image_path,
		"target_region": String(target_region),
		"edit_strength": edit_strength,
		"seed": seed,
		"output_key": output_key,
	}
