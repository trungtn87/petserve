class_name PetRenderConfig
extends RefCounted


const DEFAULT_PATH: String = (
	"res://data/evolution/render/cloudflare_dev.json"
)


var base_url: String = (
	"https://api.cloudflare.com/client/v4/accounts"
)
var account_id_env: String = "CLOUDFLARE_ACCOUNT_ID"
var api_token_env: String = "CLOUDFLARE_API_TOKEN"

var initial_model: String = (
	"@cf/black-forest-labs/flux-2-klein-4b"
)
var edit_model: String = (
	"@cf/black-forest-labs/flux-2-klein-4b"
)

var width: int = 1024
var height: int = 1024

var timeout_seconds: float = 180.0


func is_valid() -> bool:
	return (
		not base_url.is_empty()
		and not account_id_env.is_empty()
		and not api_token_env.is_empty()
		and not initial_model.is_empty()
		and not edit_model.is_empty()
		and width > 0
		and height > 0
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

	config.base_url = str(
		data.get(
			"base_url",
			config.base_url
		)
	)
	config.account_id_env = str(
		data.get(
			"account_id_env",
			config.account_id_env
		)
	)
	config.api_token_env = str(
		data.get(
			"api_token_env",
			config.api_token_env
		)
	)
	config.initial_model = str(
		data.get(
			"initial_model",
			config.initial_model
		)
	)
	config.edit_model = str(
		data.get(
			"edit_model",
			config.edit_model
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
