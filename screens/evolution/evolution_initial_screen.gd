class_name EvolutionInitialScreen
extends Control


@onready var _pet_name_label: Label = %PetNameLabel
@onready var _identity_label: Label = %IdentityLabel
@onready var _status_label: Label = %StatusLabel
@onready var _image: TextureRect = %PetImage
@onready var _generate_button: Button = %GenerateButton
@onready var _prompt_label: Label = %PromptLabel


var _identity: PetIdentity
var _genome: PetGenome
var _scene_profile: PetSceneProfile
var _pet_name: String = ""

var _coordinator: InitialPetRenderCoordinator


func _ready() -> void:
	_generate_button.pressed.connect(
		_on_generate_pressed
	)

	_coordinator = InitialPetRenderCoordinator.new()
	add_child(_coordinator)

	_bootstrap()


func _bootstrap() -> void:
	var data := (
		EvolutionBootstrapService.new()
		.build_from_hatch()
	)

	if not bool(data.get("ok", false)):
		_show_error(
			str(data.get(
				"error",
				"Bootstrap thất bại."
			))
		)
		return

	_identity = data.get("identity") as PetIdentity
	_genome = data.get("genome") as PetGenome
	_scene_profile = data.get(
		"scene_profile"
	) as PetSceneProfile
	_pet_name = str(
		data.get("pet_name", "")
	)

	_pet_name_label.text = _pet_name
	_identity_label.text = (
		"%s • %s • INFANT"
		% [
			String(_identity.species()).to_upper(),
			String(_identity.element()).to_upper(),
		]
	)

	var request_data := _coordinator.build_request(
		_identity,
		_genome,
		_scene_profile
	)

	if not bool(
		request_data.get("ok", false)
	):
		_show_error(
			str(request_data.get(
				"error",
				"Không tạo được prompt."
			))
		)
		return

	var request := (
		request_data.get("request")
		as PetRenderRequest
	)

	_prompt_label.text = (
		request.positive_prompt
	)

	var existing := (
		_try_load_existing_visual()
	)

	if existing:
		_status_label.text = (
			"Ấu thể đã được tạo • dùng lại ảnh đã lưu."
		)
		_generate_button.text = "TẠO LẠI ẢNH"
		return

	if _coordinator.has_render_endpoint():
		_start_generate(request)
		return

	_status_label.text = (
		"Sẵn sàng tạo pet từ prompt. "
		+ "Chưa cấu hình URL Worker proxy nên chưa gửi request."
	)
	_generate_button.disabled = false
	_generate_button.text = "TẠO PET ẤU THỂ"


func _on_generate_pressed() -> void:
	if _identity == null or _genome == null:
		return

	var request_data := _coordinator.build_request(
		_identity,
		_genome,
		_scene_profile
	)

	if not bool(
		request_data.get("ok", false)
	):
		_show_error(
			str(request_data.get(
				"error",
				"Không tạo được render request."
			))
		)
		return

	var request := (
		request_data.get("request")
		as PetRenderRequest
	)

	_start_generate(request)


func _start_generate(
	request: PetRenderRequest
) -> void:
	_generate_button.disabled = true
	_status_label.text = (
		"Đang tạo PetHome %s từ một prompt..."
		% String(_identity.element()).to_upper()
	)

	var result: PetRenderResult = await (
		_coordinator.render_initial(
			request
		)
	)

	if not result.success:
		_generate_button.disabled = false
		_generate_button.text = "THỬ LẠI"
		_show_error(
			result.error_message
		)
		return

	if not _load_image_path(
		result.image_path
	):
		_generate_button.disabled = false
		_show_error(
			"Đã render nhưng không load được ảnh PNG."
		)
		return

	var visual := PetVisualRecord.new()
	visual.pet_id = _identity.pet_id()
	visual.visual_index = 0
	visual.image_path = result.image_path
	visual.source_mode = &"initial_pethome_text_to_image"
	visual.renderer_id = result.renderer_id
	visual.model_id = result.model_id

	EvolutionSaveService.new().save_initial(
		_identity,
		_genome,
		visual,
		_pet_name,
		_scene_profile
	)

	_status_label.text = (
		"Ấu thể Mythic đã tạo xong."
	)
	_generate_button.disabled = false
	_generate_button.text = "TẠO LẠI ẢNH"


func _try_load_existing_visual() -> bool:
	var data := EvolutionSaveService.new().load_data()

	if data.is_empty():
		return false

	var identity_value: Variant = data.get(
		"identity",
		{}
	)

	if typeof(identity_value) != TYPE_DICTIONARY:
		return false

	var saved_identity := PetIdentity.from_dict(
		identity_value as Dictionary
	)

	if (
		saved_identity == null
		or _identity == null
		or not saved_identity.same_identity(
			_identity
		)
	):
		return false

	var visual_value: Variant = data.get(
		"current_visual",
		{}
	)

	if typeof(visual_value) != TYPE_DICTIONARY:
		return false

	var visual := PetVisualRecord.from_dict(
		visual_value as Dictionary
	)

	if visual == null:
		return false

	return _load_image_path(
		visual.image_path
	)


func _load_image_path(
	path: String
) -> bool:
	if path.is_empty():
		return false

	var image := Image.new()
	var error := image.load(path)

	if error != OK:
		return false

	_image.texture = ImageTexture.create_from_image(
		image
	)
	_image.visible = true

	return true


func _show_error(
	message: String
) -> void:
	_status_label.text = "Lỗi: " + message
