class_name InitialPetRenderCoordinator
extends Node


var _render_service: PetRenderService


func _ready() -> void:
	_render_service = PetRenderService.new()
	add_child(_render_service)


func build_request(
	identity: PetIdentity,
	genome: PetGenome
) -> Dictionary:
	var style := MythicStyleProfile.load_default()

	if style == null:
		return {
			"ok": false,
			"error": "Không load được MythicStyleProfile.",
		}

	var species_catalog := InitialSpeciesCatalog.new()
	var species_profile := species_catalog.find_by_species(
		species_catalog.load_default(),
		identity.species()
	)

	if species_profile == null:
		return {
			"ok": false,
			"error": "Chưa có initial species profile cho %s."
			% String(identity.species()),
		}

	var spec := InitialPetVisualSpecBuilder.new().build(
		identity,
		genome,
		style,
		species_profile
	)

	if spec == null:
		return {
			"ok": false,
			"error": "Không tạo được InitialPetVisualSpec.",
		}

	var prompt_builder := InitialPetPromptBuilder.new()

	var request := PetRenderRequest.new()
	request.mode = (
		PetRenderRequest.RenderMode.INITIAL_TEXT_TO_IMAGE
	)
	request.pet_id = identity.pet_id()
	request.positive_prompt = (
		prompt_builder.build_positive(spec)
	)
	request.negative_prompt = (
		prompt_builder.build_negative(spec)
	)
	request.output_key = (
		identity.pet_id()
		+ "_infant_base"
	)

	if not request.is_valid():
		return {
			"ok": false,
			"error": "Initial render request không hợp lệ.",
		}

	return {
		"ok": true,
		"spec": spec,
		"request": request,
	}


func render_initial(
	request: PetRenderRequest
) -> PetRenderResult:
	var config := PetRenderConfig.load_default()

	if config == null:
		return PetRenderResult.fail(
			&"invalid_config",
			"Không load được Cloudflare render config."
		)

	var renderer := CloudflareWorkersAIRenderer.new(
		config
	)

	_render_service.set_renderer(
		renderer
	)

	return await _render_service.render(
		request
	)


func has_direct_dev_credentials() -> bool:
	var config := PetRenderConfig.load_default()

	if config == null:
		return false

	return (
		not OS.get_environment(
			config.account_id_env
		).strip_edges().is_empty()
		and not OS.get_environment(
			config.api_token_env
		).strip_edges().is_empty()
	)
