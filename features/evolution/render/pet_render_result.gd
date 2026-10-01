class_name PetRenderResult
extends RefCounted


var success: bool = false
var image_path: String = ""

var renderer_id: StringName = &""
var model_id: StringName = &""

var error_code: StringName = &""
var error_message: String = ""

var metadata: Dictionary = {}


static func ok(
	path: String,
	renderer: StringName,
	model: StringName,
	meta: Dictionary = {}
) -> PetRenderResult:
	var result := PetRenderResult.new()

	result.success = true
	result.image_path = path
	result.renderer_id = renderer
	result.model_id = model
	result.metadata = meta.duplicate(true)

	return result


static func fail(
	code: StringName,
	message: String,
	renderer: StringName = &"",
	model: StringName = &""
) -> PetRenderResult:
	var result := PetRenderResult.new()

	result.success = false
	result.error_code = code
	result.error_message = message
	result.renderer_id = renderer
	result.model_id = model

	return result
