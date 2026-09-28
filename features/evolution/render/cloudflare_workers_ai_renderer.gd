class_name CloudflareWorkersAIRenderer
extends PetRenderer


const OUTPUT_DIR: String = "user://pet_renders"
const BOUNDARY: String = "----PetVerseM6Boundary7MA4YWxk"


var _config: PetRenderConfig


func _init(
	config: PetRenderConfig = null
) -> void:
	_config = config


func renderer_id() -> StringName:
	return &"cloudflare_workers_ai_dev"


func has_credentials() -> bool:
	if _config == null:
		return false

	return (
		not OS.get_environment(
			_config.account_id_env
		).strip_edges().is_empty()
		and not OS.get_environment(
			_config.api_token_env
		).strip_edges().is_empty()
	)


func render(
	request: PetRenderRequest
) -> PetRenderResult:
	if request == null or not request.is_valid():
		return PetRenderResult.fail(
			&"invalid_request",
			"Render request không hợp lệ.",
			renderer_id()
		)

	if _config == null or not _config.is_valid():
		return PetRenderResult.fail(
			&"invalid_config",
			"Cloudflare renderer config không hợp lệ.",
			renderer_id()
		)

	if (
		request.mode
		!= PetRenderRequest.RenderMode.INITIAL_TEXT_TO_IMAGE
	):
		return PetRenderResult.fail(
			&"unsupported_mode",
			"M5/M6 hiện chỉ chạy text-to-image ban đầu.",
			renderer_id(),
			StringName(_config.initial_model)
		)

	var account_id := OS.get_environment(
		_config.account_id_env
	).strip_edges()

	var api_token := OS.get_environment(
		_config.api_token_env
	).strip_edges()

	if account_id.is_empty():
		return PetRenderResult.fail(
			&"missing_account_id",
			"Thiếu biến môi trường %s."
			% _config.account_id_env,
			renderer_id(),
			StringName(_config.initial_model)
		)

	if api_token.is_empty():
		return PetRenderResult.fail(
			&"missing_api_token",
			"Thiếu biến môi trường %s."
			% _config.api_token_env,
			renderer_id(),
			StringName(_config.initial_model)
		)

	var http := HTTPRequest.new()
	http.timeout = _config.timeout_seconds
	add_child(http)

	var headers := PackedStringArray([
		"Authorization: Bearer " + api_token,
		"Accept: application/json",
		"Content-Type: multipart/form-data; boundary=" + BOUNDARY,
	])

	var body := _build_initial_body(
		_compose_prompt(request)
	)

	var request_error := http.request_raw(
		_build_endpoint(
			account_id,
			_config.initial_model
		),
		headers,
		HTTPClient.METHOD_POST,
		body
	)

	if request_error != OK:
		http.queue_free()

		return PetRenderResult.fail(
			&"http_start_failed",
			"Không bắt đầu được Cloudflare request: %s"
			% error_string(request_error),
			renderer_id(),
			StringName(_config.initial_model)
		)

	var response: Array = await http.request_completed
	http.queue_free()

	if response.size() < 4:
		return PetRenderResult.fail(
			&"invalid_http_response",
			"Cloudflare HTTP response không đúng định dạng.",
			renderer_id(),
			StringName(_config.initial_model)
		)

	var transport_result := int(response[0])
	var response_code := int(response[1])
	var body_bytes: PackedByteArray = response[3]

	if transport_result != HTTPRequest.RESULT_SUCCESS:
		return PetRenderResult.fail(
			&"transport_failed",
			"Cloudflare HTTP transport lỗi: %d"
			% transport_result,
			renderer_id(),
			StringName(_config.initial_model)
		)

	if response_code < 200 or response_code >= 300:
		return PetRenderResult.fail(
			&"api_error",
			_extract_api_error(
				body_bytes,
				response_code
			),
			renderer_id(),
			StringName(_config.initial_model)
		)

	var image_bytes := _extract_image_bytes(
		body_bytes
	)

	if image_bytes.is_empty():
		return PetRenderResult.fail(
			&"missing_image",
			"Cloudflare không trả dữ liệu ảnh hợp lệ.",
			renderer_id(),
			StringName(_config.initial_model)
		)

	var image := Image.new()
	var image_error := image.load_png_from_buffer(
		image_bytes
	)

	if image_error != OK:
		image_error = image.load_jpg_from_buffer(
			image_bytes
		)

	if image_error != OK:
		return PetRenderResult.fail(
			&"invalid_image",
			"Không giải mã được ảnh Cloudflare: %s"
			% error_string(image_error),
			renderer_id(),
			StringName(_config.initial_model)
		)

	if not _ensure_output_dir():
		return PetRenderResult.fail(
			&"output_dir_failed",
			"Không tạo được thư mục lưu ảnh.",
			renderer_id(),
			StringName(_config.initial_model)
		)

	var output_path := _output_path(
		request.output_key
	)

	var save_error := image.save_png(
		output_path
	)

	if save_error != OK:
		return PetRenderResult.fail(
			&"write_failed",
			"Không lưu được PNG: %s"
			% error_string(save_error),
			renderer_id(),
			StringName(_config.initial_model)
		)

	return PetRenderResult.ok(
		output_path,
		renderer_id(),
		StringName(_config.initial_model),
		{
			"response_code": response_code,
			"width": image.get_width(),
			"height": image.get_height(),
			"provider": "cloudflare_workers_ai",
		}
	)


func _build_endpoint(
	account_id: String,
	model: String
) -> String:
	return (
		_config.base_url.trim_suffix("/")
		+ "/"
		+ account_id
		+ "/ai/run/"
		+ model
	)


func _build_initial_body(
	prompt: String
) -> PackedByteArray:
	var result := PackedByteArray()

	_append_text_field(
		result,
		"prompt",
		prompt
	)
	_append_text_field(
		result,
		"width",
		str(_config.width)
	)
	_append_text_field(
		result,
		"height",
		str(_config.height)
	)

	result.append_array(
		(
			"--"
			+ BOUNDARY
			+ "--\r\n"
		).to_utf8_buffer()
	)

	return result


func _append_text_field(
	body: PackedByteArray,
	field_name: String,
	value: String
) -> void:
	var header := (
		"--"
		+ BOUNDARY
		+ "\r\n"
		+ "Content-Disposition: form-data; name=\""
		+ field_name
		+ "\"\r\n\r\n"
	)

	body.append_array(
		header.to_utf8_buffer()
	)
	body.append_array(
		value.to_utf8_buffer()
	)
	body.append_array(
		"\r\n".to_utf8_buffer()
	)


func _compose_prompt(
	request: PetRenderRequest
) -> String:
	var prompt := request.positive_prompt.strip_edges()

	if not request.negative_prompt.strip_edges().is_empty():
		prompt += (
			"\n\nSTRICTLY AVOID:\n"
			+ request.negative_prompt.strip_edges()
		)

	return prompt


func _extract_image_bytes(
	response_body: PackedByteArray
) -> PackedByteArray:
	if _looks_like_png(response_body):
		return response_body

	if _looks_like_jpeg(response_body):
		return response_body

	var text := response_body.get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(text)

	if typeof(parsed) != TYPE_DICTIONARY:
		return PackedByteArray()

	var root := parsed as Dictionary
	var result_value: Variant = root.get(
		"result",
		{}
	)

	var image_base64 := ""

	if typeof(result_value) == TYPE_DICTIONARY:
		image_base64 = str(
			(result_value as Dictionary).get(
				"image",
				""
			)
		)

	if image_base64.is_empty():
		image_base64 = str(
			root.get("image", "")
		)

	if image_base64.is_empty():
		return PackedByteArray()

	if image_base64.begins_with("data:"):
		var comma_index := image_base64.find(",")

		if comma_index >= 0:
			image_base64 = image_base64.substr(
				comma_index + 1
			)

	return Marshalls.base64_to_raw(
		image_base64
	)


func _looks_like_png(
	data: PackedByteArray
) -> bool:
	return (
		data.size() >= 8
		and data[0] == 137
		and data[1] == 80
		and data[2] == 78
		and data[3] == 71
		and data[4] == 13
		and data[5] == 10
		and data[6] == 26
		and data[7] == 10
	)


func _looks_like_jpeg(
	data: PackedByteArray
) -> bool:
	return (
		data.size() >= 3
		and data[0] == 255
		and data[1] == 216
		and data[2] == 255
	)


func _output_path(
	output_key: String
) -> String:
	var safe := output_key.to_lower()

	for character in [
		"/",
		"\\",
		":",
		"*",
		"?",
		"\"",
		"<",
		">",
		"|",
		" ",
	]:
		safe = safe.replace(
			character,
			"_"
		)

	return "%s/%s.png" % [
		OUTPUT_DIR,
		safe,
	]


func _ensure_output_dir() -> bool:
	var absolute := ProjectSettings.globalize_path(
		OUTPUT_DIR
	)

	var result := DirAccess.make_dir_recursive_absolute(
		absolute
	)

	return (
		result == OK
		or result == ERR_ALREADY_EXISTS
	)


func _extract_api_error(
	response_body: PackedByteArray,
	response_code: int
) -> String:
	var text := response_body.get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(text)

	if typeof(parsed) == TYPE_DICTIONARY:
		var root := parsed as Dictionary
		var errors_value: Variant = root.get(
			"errors",
			[]
		)

		if (
			typeof(errors_value) == TYPE_ARRAY
			and not (errors_value as Array).is_empty()
		):
			var first: Variant = (
				errors_value as Array
			)[0]

			if typeof(first) == TYPE_DICTIONARY:
				var message := str(
					(first as Dictionary).get(
						"message",
						""
					)
				)

				if not message.is_empty():
					return "HTTP %d: %s" % [
						response_code,
						message,
					]

	if text.length() > 400:
		text = text.substr(0, 400)

	return "HTTP %d: %s" % [
		response_code,
		text,
	]
