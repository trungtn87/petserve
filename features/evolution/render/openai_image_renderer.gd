class_name OpenAIImageRenderer
extends PetRenderer


const OUTPUT_DIR: String = "user://pet_renders"


var _config: PetRenderConfig


func _init(
	config: PetRenderConfig = null
) -> void:
	_config = config


func renderer_id() -> StringName:
	return &"openai_image_api_dev"


func has_api_key() -> bool:
	if _config == null:
		return false

	return not OS.get_environment(
		_config.api_key_env
	).strip_edges().is_empty()


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
			"Renderer config không hợp lệ.",
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

	var api_key := OS.get_environment(
		_config.api_key_env
	).strip_edges()

	if api_key.is_empty():
		return PetRenderResult.fail(
			&"missing_api_key",
			"Thiếu biến môi trường %s."
			% _config.api_key_env,
			renderer_id(),
			StringName(_config.initial_model)
		)

	var http := HTTPRequest.new()
	http.timeout = _config.timeout_seconds
	add_child(http)

	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer " + api_key,
	])

	var payload := {
		"model": _config.initial_model,
		"prompt": _compose_prompt(request),
		"n": 1,
		"size": _config.size,
		"quality": _config.quality,
		"background": _config.background,
		"output_format": _config.output_format,
	}

	var request_error := http.request(
		_config.endpoint,
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)

	if request_error != OK:
		http.queue_free()

		return PetRenderResult.fail(
			&"http_start_failed",
			"Không bắt đầu được HTTP request: %s"
			% error_string(request_error),
			renderer_id(),
			StringName(_config.initial_model)
		)

	var response: Array = await http.request_completed
	http.queue_free()

	if response.size() < 4:
		return PetRenderResult.fail(
			&"invalid_http_response",
			"HTTP response không đúng định dạng.",
			renderer_id(),
			StringName(_config.initial_model)
		)

	var transport_result := int(response[0])
	var response_code := int(response[1])
	var body := response[3] as PackedByteArray
	var body_text := body.get_string_from_utf8()

	if transport_result != HTTPRequest.RESULT_SUCCESS:
		return PetRenderResult.fail(
			&"transport_failed",
			"HTTP transport lỗi: %d" % transport_result,
			renderer_id(),
			StringName(_config.initial_model)
		)

	var parsed: Variant = JSON.parse_string(
		body_text
	)

	if response_code < 200 or response_code >= 300:
		return PetRenderResult.fail(
			&"api_error",
			_extract_api_error(
				parsed,
				response_code,
				body_text
			),
			renderer_id(),
			StringName(_config.initial_model)
		)

	if typeof(parsed) != TYPE_DICTIONARY:
		return PetRenderResult.fail(
			&"invalid_json",
			"Image API trả JSON không hợp lệ.",
			renderer_id(),
			StringName(_config.initial_model)
		)

	var root := parsed as Dictionary
	var data_value: Variant = root.get(
		"data",
		[]
	)

	if (
		typeof(data_value) != TYPE_ARRAY
		or (data_value as Array).is_empty()
	):
		return PetRenderResult.fail(
			&"missing_image",
			"Image API không trả dữ liệu ảnh.",
			renderer_id(),
			StringName(_config.initial_model)
		)

	var first_value: Variant = (
		data_value as Array
	)[0]

	if typeof(first_value) != TYPE_DICTIONARY:
		return PetRenderResult.fail(
			&"invalid_image_record",
			"Image record không hợp lệ.",
			renderer_id(),
			StringName(_config.initial_model)
		)

	var first := first_value as Dictionary
	var b64 := str(
		first.get("b64_json", "")
	)

	if b64.is_empty():
		return PetRenderResult.fail(
			&"missing_base64",
			"Image API không trả b64_json.",
			renderer_id(),
			StringName(_config.initial_model)
		)

	var image_bytes := Marshalls.base64_to_raw(
		b64
	)

	if image_bytes.is_empty():
		return PetRenderResult.fail(
			&"decode_failed",
			"Không giải mã được ảnh base64.",
			renderer_id(),
			StringName(_config.initial_model)
		)

	var image := Image.new()
	var image_error := image.load_png_from_buffer(
		image_bytes
	)

	if image_error != OK:
		return PetRenderResult.fail(
			&"invalid_png",
			"Ảnh trả về không phải PNG hợp lệ: %s"
			% error_string(image_error),
			renderer_id(),
			StringName(_config.initial_model)
		)

	var output_path := _output_path(
		request.output_key
	)

	if not _ensure_output_dir():
		return PetRenderResult.fail(
			&"output_dir_failed",
			"Không tạo được thư mục lưu ảnh.",
			renderer_id(),
			StringName(_config.initial_model)
		)

	var file := FileAccess.open(
		output_path,
		FileAccess.WRITE
	)

	if file == null:
		return PetRenderResult.fail(
			&"write_failed",
			"Không mở được file ảnh để ghi.",
			renderer_id(),
			StringName(_config.initial_model)
		)

	file.store_buffer(image_bytes)
	file.close()

	return PetRenderResult.ok(
		output_path,
		renderer_id(),
		StringName(_config.initial_model),
		{
			"response_code": response_code,
			"size": str(root.get("size", _config.size)),
			"quality": str(root.get("quality", _config.quality)),
			"background": str(
				root.get(
					"background",
					_config.background
				)
			),
			"output_format": str(
				root.get(
					"output_format",
					_config.output_format
				)
			),
			"revised_prompt": str(
				first.get("revised_prompt", "")
			),
		}
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
		safe = safe.replace(character, "_")

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

	return result == OK or result == ERR_ALREADY_EXISTS


func _extract_api_error(
	parsed: Variant,
	response_code: int,
	raw_text: String
) -> String:
	if typeof(parsed) == TYPE_DICTIONARY:
		var root := parsed as Dictionary
		var error_value: Variant = root.get(
			"error",
			{}
		)

		if typeof(error_value) == TYPE_DICTIONARY:
			var message := str(
				(error_value as Dictionary).get(
					"message",
					""
				)
			)

			if not message.is_empty():
				return "HTTP %d: %s" % [
					response_code,
					message,
				]

	if raw_text.length() > 300:
		raw_text = raw_text.substr(0, 300)

	return "HTTP %d: %s" % [
		response_code,
		raw_text,
	]
