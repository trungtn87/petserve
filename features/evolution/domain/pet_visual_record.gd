class_name PetVisualRecord
extends RefCounted


const SCHEMA_VERSION: int = 1


var pet_id: String = ""
var visual_index: int = 0

var image_path: String = ""
var source_mode: StringName = &""
var mutation_id: StringName = &""

var renderer_id: StringName = &""
var model_id: StringName = &""


func is_valid() -> bool:
	return (
		not pet_id.is_empty()
		and visual_index >= 0
		and not image_path.is_empty()
		and not String(source_mode).is_empty()
	)


func to_dict() -> Dictionary:
	return {
		"schema": SCHEMA_VERSION,
		"pet_id": pet_id,
		"visual_index": visual_index,
		"image_path": image_path,
		"source_mode": String(source_mode),
		"mutation_id": String(mutation_id),
		"renderer_id": String(renderer_id),
		"model_id": String(model_id),
	}


static func from_dict(
	data: Dictionary
) -> PetVisualRecord:
	var record := PetVisualRecord.new()

	record.pet_id = str(
		data.get("pet_id", "")
	)
	record.visual_index = int(
		data.get("visual_index", 0)
	)
	record.image_path = str(
		data.get("image_path", "")
	)
	record.source_mode = StringName(
		str(data.get("source_mode", ""))
	)
	record.mutation_id = StringName(
		str(data.get("mutation_id", ""))
	)
	record.renderer_id = StringName(
		str(data.get("renderer_id", ""))
	)
	record.model_id = StringName(
		str(data.get("model_id", ""))
	)

	if not record.is_valid():
		return null

	return record
