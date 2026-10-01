class_name PetRenderConfig
extends RefCounted


const DEFAULT_PATH: String = (
	"res://data/evolution/render/proxy_dev.json"
)


var proxy_url: String = ""
var client_key: String = ""

var model_id: String = (
	"@cf/black-forest-labs/flux-2-klein-4b"
)

var width: int = 1024
var height: int = 1024

var timeout_seconds: float = 180.0


func is_valid() -> bool:
	return (
		not proxy_url.is_empty()
		and not model_id.is_empty()
		and width > 0
		and height > 0
		and timeout_seconds > 0.0
	)


func is_configured() -> bool:
	return (
		is_valid()
		and proxy_url.begins_with("https://")
		and not proxy_url.contains("REPLACE_ME")
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

	config.proxy_url = str(
		data.get("proxy_url", "")
	)
	config.client_key = str(
		data.get("client_key", "")
	)
	config.model_id = str(
		data.get(
			"model_id",
			config.model_id
		)
	)
	config.width = int(
		data.get("width", config.width)
	)
	config.height = int(
		data.get("height", config.height)
	)
	config.timeout_seconds = float(
		data.get(
			"timeout_seconds",
			config.timeout_seconds
		)
	)

	if not config.is_valid():
		return null

	return config
