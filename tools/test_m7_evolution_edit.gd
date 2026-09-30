extends Node


var failures: int = 0


func _ready() -> void:
	call_deferred("run")


func check(
	ok: bool,
	label: String
) -> void:
	if ok:
		return

	failures += 1
	push_error(
		"M7: " + label
	)


func run() -> void:
	var image := Image.create(
		32,
		48,
		false,
		Image.FORMAT_RGBA8
	)
	image.fill(
		Color("#241d39")
	)
	check(
		image.save_png(
			"user://m7_source.png"
		) == OK,
		"create source image"
	)

	var identity := (
		PetIdentityFactory.new()
		.create_initial(
			777,
			&"dark"
		)
	)
	check(
		identity != null,
		"identity"
	)

	var previous := PetGenome.new(
		1,
		0.0,
		{
			"eyes": "base",
			"tail": "base",
		},
		[]
	)
	var mutated := PetGenome.new(
		1,
		0.0,
		{
			"eyes": "galaxy_ring",
			"tail": "base",
		},
		[
			"galaxy_eye_ring",
		]
	)
	var delta := EvolutionDelta.new(
		&"galaxy_eye_ring",
		&"eyes",
		&"base",
		&"galaxy_ring",
		1
	)

	var source := PetVisualRecord.new()
	source.pet_id = identity.pet_id()
	source.visual_index = 0
	source.image_path = (
		"user://m7_source.png"
	)
	source.source_mode = (
		&"initial_pethome_v5_text_to_image"
	)
	source.renderer_id = &"test"
	source.model_id = &"test"

	var coordinator := (
		EvolutionEditCoordinator.new()
	)
	var plan := coordinator.build_request(
		identity,
		previous,
		mutated,
		delta,
		source,
		2
	)

	check(
		bool(
			plan.get(
				"ok",
				false
			)
		),
		"valid image-edit plan"
	)

	var request := (
		plan.get("request")
		as PetRenderRequest
	)
	check(
		request != null,
		"request exists"
	)

	if request != null:
		check(
			request.mode
				== PetRenderRequest.RenderMode.EVOLUTION_IMAGE_EDIT,
			"image edit mode"
		)
		check(
			request.source_image_path
				== source.image_path,
			"source image preserved"
		)
		check(
			request.target_region
				== &"whole_pet_gene",
			"Stage 1 -> 2 Gene edit must allow whole-pet maturation while keeping the Gene code-locked"
		)
		check(
			request.output_key.ends_with(
				"_pethome_v11_stage_2"
			),
			"stage output key"
		)
		check(
			request.positive_prompt.contains(
				"Keep the same individual face"
			)
			and request.positive_prompt.contains(
				"Make it slightly older and more developed"
			)
			and request.positive_prompt.contains(
				"slight chibi"
			)
			and request.positive_prompt.contains(
				"Smoky blue-black and violet fur"
			)
			and request.positive_prompt.contains(
				"Selected Gene change:"
			),
			"Stage 1 -> 2 Gene prompt must preserve lineage and apply Dark Stage 2 morphology"
		)
		check(
			request.positive_prompt.contains(
				"Background occupies most of the image"
			),
			"world continuity prompt"
		)

		var serialized := (
			coordinator.serialize_request(
				request
			)
		)
		var restored := (
			coordinator.request_from_dict(
				serialized
			)
		)

		check(
			restored != null,
			"persisted request restores"
		)

		if restored != null:
			check(
				restored.to_debug_dict()
					== request.to_debug_dict(),
				"retry request is stable"
			)

	var natural_plan := coordinator.build_natural_request(
		identity,
		previous,
		source,
		2
	)
	check(
		bool(
			natural_plan.get(
				"ok",
				false
			)
		),
		"Stage 1 -> 2 natural continuity plan"
	)
	var natural_request := (
		natural_plan.get("request")
		as PetRenderRequest
	)
	check(
		natural_request != null
		and natural_request.mode
			== PetRenderRequest.RenderMode.EVOLUTION_IMAGE_EDIT
		and natural_request.source_image_path
			== source.image_path
		and natural_request.target_region
			== &"whole_pet_age"
		and natural_request.positive_prompt.contains(
			"Keep the same individual face"
		)
		and natural_request.positive_prompt.contains(
			"Make it slightly older and more developed"
		)
		and natural_request.positive_prompt.contains(
			"Smoky blue-black and violet fur"
		),
		"Natural Stage 1 -> 2 must image-edit the same pet with Dark Stage 2 morphology"
	)

	var bad_stage := coordinator.build_request(
		identity,
		previous,
		mutated,
		delta,
		source,
		3
	)
	check(
		not bool(
			bad_stage.get(
				"ok",
				false
			)
		),
		"cannot skip a stage"
	)

	var wrong_source := PetVisualRecord.new()
	wrong_source.pet_id = "other_pet"
	wrong_source.visual_index = 0
	wrong_source.image_path = source.image_path
	wrong_source.source_mode = source.source_mode

	var bad_identity := coordinator.build_request(
		identity,
		previous,
		mutated,
		delta,
		wrong_source,
		2
	)
	check(
		not bool(
			bad_identity.get(
				"ok",
				false
			)
		),
		"source must belong to same pet"
	)

	print(
		"M7 EVOLUTION EDIT failures=",
		failures
	)
	get_tree().quit(
		1 if failures else 0
	)
