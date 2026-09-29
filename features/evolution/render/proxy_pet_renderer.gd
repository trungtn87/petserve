class_name ProxyPetRenderer
extends PetRenderer


const OUTPUT_DIR: String = "user://pet_renders"
const MAX_TRANSPORT_ATTEMPTS: int = 2
const TRANSPORT_RETRY_DELAY_SECONDS: float = 1.25


var _config: PetRenderConfig


func _init(
	config: PetRenderConfig = null
) -> void:
	_config = config


func renderer_id() -> StringName:
	return &"petverse_render_proxy"


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
			"Proxy renderer config không hợp lệ.",
			renderer_id()
		)

	if not _config.is_configured():
		return PetRenderResult.fail(
			&"proxy_not_configured",
			"Chưa cấu hình URL Cloudflare Worker proxy.",
			renderer_id(),
			StringName(_config.model_id)
		)

	var cached_path := _output_path(request.output_key)
	if FileAccess.file_exists(cached_path) and Image.load_from_file(cached_path) != null:
		return PetRenderResult.ok(
			cached_path,
			renderer_id(),
			StringName(
				_config.model_id
			),
			{
				"cached": true,
				"seed": request.seed,
			}
		)
	var reference_base64 := ""
	if request.mode == PetRenderRequest.RenderMode.EVOLUTION_IMAGE_EDIT:
		var reference := Image.load_from_file(request.source_image_path)
		if reference == null:
			return PetRenderResult.fail(&"invalid_request", "Không đọc được ảnh pet trước tiến hóa.", renderer_id())
		var scale := minf(1.0, 511.0 / maxf(reference.get_width(), reference.get_height()))
		reference.resize(maxi(1, int(reference.get_width() * scale)), maxi(1, int(reference.get_height() * scale)), Image.INTERPOLATE_LANCZOS)
		reference_base64 = Marshalls.raw_to_base64(reference.save_png_to_buffer())

	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Accept: application/json",
	])

	if not _config.client_key.is_empty():
		headers.append(
			"X-PetVerse-Key: "
			+ _config.client_key
		)

	var payload := {
		"prompt": _compose_prompt(request),
		"width": _config.width,
		"height": _config.height,
	}

	if request.seed > 0:
		payload["seed"] = request.seed

	var endpoint := _config.proxy_url
	if request.mode == PetRenderRequest.RenderMode.EVOLUTION_IMAGE_EDIT:
		payload["source_image"] = reference_base64
		endpoint = endpoint.trim_suffix("/initial") + "/evolution"

	var request_body := JSON.stringify(
		payload
	)
	var response: Array = []
	var transport_result := -1
	var response_code := 0

	for attempt in range(
		MAX_TRANSPORT_ATTEMPTS
	):
		var http := HTTPRequest.new()
		http.timeout = _config.timeout_seconds
		http.use_threads = true
		add_child(
			http
		)

		var request_error := http.request(
			endpoint,
			headers,
			HTTPClient.METHOD_POST,
			request_body
		)

		if request_error != OK:
			http.queue_free()

			return PetRenderResult.fail(
				&"http_start_failed",
				"Không bắt đầu được proxy request: %s"
				% error_string(request_error),
				renderer_id(),
				StringName(_config.model_id)
			)

		response = await http.request_completed
		http.queue_free()

		if response.size() < 4:
			return PetRenderResult.fail(
				&"invalid_http_response",
				"Proxy HTTP response không đúng định dạng.",
				renderer_id(),
				StringName(_config.model_id)
			)

		transport_result = int(
			response[0]
		)
		response_code = int(
			response[1]
		)

		if (
			transport_result
			== HTTPRequest.RESULT_SUCCESS
		):
			break

		var can_retry := (
			_is_retryable_transport(
				transport_result
			)
			and response_code == 0
			and attempt
				< MAX_TRANSPORT_ATTEMPTS - 1
		)

		if not can_retry:
			return PetRenderResult.fail(
				&"transport_failed",
				_transport_error_message(
					transport_result,
					attempt + 1
				),
				renderer_id(),
				StringName(_config.model_id)
			)

		push_warning(
			"ProxyPetRenderer: transport %d (%s), "
			+ "thử lại lần %d/%d."
			% [
				transport_result,
				_transport_result_label(
					transport_result
				),
				attempt + 2,
				MAX_TRANSPORT_ATTEMPTS,
			]
		)

		await get_tree().create_timer(
			TRANSPORT_RETRY_DELAY_SECONDS
		).timeout

	var body: PackedByteArray = response[3]
	var body_text := body.get_string_from_utf8()

	var parsed: Variant = JSON.parse_string(
		body_text
	)

	if response_code < 200 or response_code >= 300:
		var proxy_error := _extract_proxy_error(
			parsed,
			response_code,
			body_text
		)

		if (
			request.mode == PetRenderRequest.RenderMode.EVOLUTION_IMAGE_EDIT
			and response_code == 404
		):
			return PetRenderResult.fail(
				&"proxy_contract_outdated",
				(
					"Cloudflare Worker đang chạy bản cũ, chưa có "
					+ "endpoint /v1/render/evolution. Deploy Worker "
					+ "trong infrastructure/cloudflare/pet-render-proxy "
					+ "rồi thử lại. Provider: "
					+ proxy_error
				),
				renderer_id(),
				StringName(_config.model_id)
			)

		return PetRenderResult.fail(
			&"proxy_error",
			proxy_error,
			renderer_id(),
			StringName(_config.model_id)
		)

	if typeof(parsed) != TYPE_DICTIONARY:
		return PetRenderResult.fail(
			&"invalid_json",
			"Proxy trả JSON không hợp lệ.",
			renderer_id(),
			StringName(_config.model_id)
		)

	var root := parsed as Dictionary

	if not bool(root.get("ok", false)):
		return PetRenderResult.fail(
			&"proxy_failed",
			str(root.get(
				"error",
				"Proxy không tạo được ảnh."
			)),
			renderer_id(),
			StringName(_config.model_id)
		)

	var image_base64 := str(
		root.get("image", "")
	).strip_edges()

	if image_base64.is_empty():
		return PetRenderResult.fail(
			&"missing_image",
			"Proxy không trả dữ liệu ảnh.",
			renderer_id(),
			StringName(_config.model_id)
		)

	if image_base64.begins_with("data:"):
		var comma_index := image_base64.find(",")

		if comma_index >= 0:
			image_base64 = image_base64.substr(
				comma_index + 1
			)

	image_base64 = (
		image_base64
		.replace("\n", "")
		.replace("\r", "")
		.replace(" ", "")
	)

	var image_bytes := Marshalls.base64_to_raw(
		image_base64
	)

	if image_bytes.is_empty():
		return PetRenderResult.fail(
			&"decode_failed",
			"Không giải mã được ảnh base64 từ proxy.",
			renderer_id(),
			StringName(_config.model_id)
		)

	var image := Image.new()
	var image_format := _detect_image_format(
		image_bytes
	)
	var image_error := _load_image_buffer(
		image,
		image_bytes,
		image_format
	)

	if image_error != OK:
		return PetRenderResult.fail(
			&"invalid_image",
			"Ảnh proxy không decode được (%s, %d bytes): %s"
			% [
				image_format,
				image_bytes.size(),
				error_string(image_error),
			],
			renderer_id(),
			StringName(_config.model_id)
		)

	if not _ensure_output_dir():
		return PetRenderResult.fail(
			&"output_dir_failed",
			"Không tạo được thư mục lưu ảnh.",
			renderer_id(),
			StringName(_config.model_id)
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
			StringName(_config.model_id)
		)

	return PetRenderResult.ok(
		output_path,
		renderer_id(),
		StringName(str(
			root.get(
				"model",
				_config.model_id
			)
		)),
		{
			"response_code": response_code,
			"width": image.get_width(),
			"height": image.get_height(),
			"provider": "cloudflare_worker_proxy",
			"seed": request.seed,
		}
	)


func _is_retryable_transport(
	result: int
) -> bool:
	return result in [
		HTTPRequest.RESULT_CANT_CONNECT,
		HTTPRequest.RESULT_CANT_RESOLVE,
		HTTPRequest.RESULT_CONNECTION_ERROR,
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR,
		HTTPRequest.RESULT_NO_RESPONSE,
		HTTPRequest.RESULT_TIMEOUT,
	]


func _transport_result_label(
	result: int
) -> String:
	match result:
		HTTPRequest.RESULT_CHUNKED_BODY_SIZE_MISMATCH:
			return "dữ liệu truyền về không đầy đủ"
		HTTPRequest.RESULT_CANT_CONNECT:
			return "không kết nối được proxy"
		HTTPRequest.RESULT_CANT_RESOLVE:
			return "không phân giải được tên miền proxy"
		HTTPRequest.RESULT_CONNECTION_ERROR:
			return "kết nối bị ngắt khi đang gửi/nhận dữ liệu"
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
			return "lỗi bắt tay TLS"
		HTTPRequest.RESULT_NO_RESPONSE:
			return "proxy không trả phản hồi"
		HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED:
			return "phản hồi vượt giới hạn kích thước"
		HTTPRequest.RESULT_BODY_DECOMPRESS_FAILED:
			return "không giải nén được phản hồi"
		HTTPRequest.RESULT_REQUEST_FAILED:
			return "request thất bại"
		HTTPRequest.RESULT_DOWNLOAD_FILE_CANT_OPEN:
			return "không mở được file tải về"
		HTTPRequest.RESULT_DOWNLOAD_FILE_WRITE_ERROR:
			return "không ghi được file tải về"
		HTTPRequest.RESULT_REDIRECT_LIMIT_REACHED:
			return "vượt giới hạn chuyển hướng"
		HTTPRequest.RESULT_TIMEOUT:
			return "hết thời gian chờ"
		_:
			return "lỗi transport không xác định"


func _transport_error_message(
	result: int,
	attempts: int
) -> String:
	return (
		"Kết nối tới proxy bị lỗi: %s "
		+ "(mã %d, đã thử %d lần). "
		+ "Kiểm tra mạng rồi thử lại."
	) % [
		_transport_result_label(
			result
		),
		result,
		attempts,
	]


func _detect_image_format(
	bytes: PackedByteArray
) -> String:
	if (
		bytes.size() >= 8
		and bytes[0] == 0x89
		and bytes[1] == 0x50
		and bytes[2] == 0x4E
		and bytes[3] == 0x47
	):
		return "png"

	if (
		bytes.size() >= 3
		and bytes[0] == 0xFF
		and bytes[1] == 0xD8
		and bytes[2] == 0xFF
	):
		return "jpeg"

	if (
		bytes.size() >= 12
		and bytes[0] == 0x52
		and bytes[1] == 0x49
		and bytes[2] == 0x46
		and bytes[3] == 0x46
		and bytes[8] == 0x57
		and bytes[9] == 0x45
		and bytes[10] == 0x42
		and bytes[11] == 0x50
	):
		return "webp"

	return "unknown"


func _load_image_buffer(
	image: Image,
	bytes: PackedByteArray,
	format: String
) -> Error:
	match format:
		"png":
			return image.load_png_from_buffer(
				bytes
			)

		"jpeg":
			return image.load_jpg_from_buffer(
				bytes
			)

		"webp":
			return image.load_webp_from_buffer(
				bytes
			)

	var error := image.load_webp_from_buffer(
		bytes
	)

	if error == OK:
		return OK

	error = image.load_jpg_from_buffer(
		bytes
	)

	if error == OK:
		return OK

	return image.load_png_from_buffer(
		bytes
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


func _extract_proxy_error(
	parsed: Variant,
	response_code: int,
	raw_text: String
) -> String:
	if typeof(parsed) == TYPE_DICTIONARY:
		var root := parsed as Dictionary
		var message := str(
			root.get("error", "")
		)

		if not message.is_empty():
			return "HTTP %d: %s" % [
				response_code,
				message,
			]

	if raw_text.length() > 400:
		raw_text = raw_text.substr(0, 400)

	return "HTTP %d: %s" % [
		response_code,
		raw_text,
	]
