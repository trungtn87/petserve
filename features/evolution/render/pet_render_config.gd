class_name PetRenderConfig
extends RefCounted


const DEFAULT_PATH: String = (
	"res://data/evolution/render/openai_dev.json"
)


var endpoint: String = ""
var api_key_env: String = "OPENAI_API_KEY"

var initial_model: String = ""
var edit_model: String = ""

var size: String = "1024x1024"
var quality: String = "high"
var background: String = "transparent"
var output_format: String = "png"

var timeout_seconds: float = 180.0


func is_valid() -> bool:
	return (
		not endpoint.is_empty()
		and not api_key_env.is_empty()
		and not initial_model.is_empty()
		and not edit_model.is_empty()
		and not size.is_empty()
		and not quality.is_empty()
		and not output_format.is_empty()
		and timeout_seconds > 0.0
	)


static func load_default() -> PetRenderConfig:
	return load_from_path(DEFAULT_PATH)


static func load_from_path(
	path: String
) -> PetRenderConfig:
	if not FileAccess.file_exists(path):
		push_error(
			"PetRenderConfig: Không tìm thấy file: "
			+ path
		)
		return null

	var file := FileAccess.open(
		path,
		FileAccess.READ
	)

	if file == null:
		push_error(
			"PetRenderConfig: Không mở được file: "
			+ path
		)
		return null

	var parsed: Variant = JSON.parse_string(
		file.get_as_text()
	)
	file.close()

	if typeof(parsed) != TYPE_DICTIONARY:
		push_error(
			"PetRenderConfig: Root JSON phải là Dictionary."
		)
		return null

	var data := parsed as Dictionary
	var config := PetRenderConfig.new()

	config.endpoint = str(
		data.get("endpoint", "")
	)
	config.api_key_env = str(
		data.get(
			"api_key_env",
			"OPENAI_API_KEY"
		)
	)
	config.initial_model = str(
		data.get("initial_model", "")
	)
	config.edit_model = str(
		data.get("edit_model", "")
	)
	config.size = str(
		data.get("size", "1024x1024")
	)
	config.quality = str(
		data.get("quality", "high")
	)
	config.background = str(
		data.get("background", "transparent")
	)
	config.output_format = str(
		data.get("output_format", "png")
	)
	config.timeout_seconds = float(
		data.get("timeout_seconds", 180.0)
	)

	if not config.is_valid():
		return null

	return config
