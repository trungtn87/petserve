extends SceneTree

const SessionScript = preload("res://tools/image_lab/image_lab_session.gd")

const ELEMENTS: Array[StringName] = [
	&"metal", &"wood", &"water", &"fire", &"earth", &"light", &"dark"
]

var _rng := RandomNumberGenerator.new()
var _session = SessionScript.new()
var _renderer: ProxyPetRenderer
var _summary: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_rng.randomize()

	var config := PetRenderConfig.load_default()
	if config == null or not config.is_configured():
		push_error("Render proxy config missing")
		quit(1)
		return

	_renderer = ProxyPetRenderer.new(config)
	root.add_child(_renderer)

	var profiles := InitialSpeciesCatalog.new().load_default()
	if profiles.is_empty():
		push_error("Species catalog empty")
		quit(1)
		return

	var species_profile = profiles[_rng.randi_range(0, profiles.size() - 1)]
	var species: StringName = species_profile.species
	var element: StringName = ELEMENTS[_rng.randi_range(0, ELEMENTS.size() - 1)]
	var lineage_seed := _rng.randi_range(1, 2147483646)

	_session.reset(element, lineage_seed)
	_session.identity = PetIdentityFactory.new().create_initial(
		lineage_seed,
		element,
		species
	)

	if _session.identity == null or not _session.identity.is_valid():
		push_error("Random identity invalid")
		quit(1)
		return

	_summary = {
		"species": String(species),
		"element": String(element),
		"lineage_seed": lineage_seed,
		"model": String(config.model_id()),
		"stages": [],
	}

	print("RANDOM PET: ", species, " / ", element, " / seed ", lineage_seed)

	for target_stage in range(1, 5):
		var selections: Array[Dictionary] = []
		if target_stage > 1:
			selections = _random_gene_selections(target_stage - 1)

		var prepared: Dictionary = _session.prepare(target_stage, selections)
		if not bool(prepared.get("ok", false)):
			push_error(
				"Stage %d prepare failed: %s"
				% [target_stage, str(prepared.get("error", "unknown"))]
			)
			quit(1)
			return

		var request: PetRenderRequest = prepared.get("request") as PetRenderRequest
		if request == null or not request.is_valid():
			push_error("Stage %d request invalid" % target_stage)
			quit(1)
			return

		var wire_prompt := _renderer._compose_prompt(request)
		print(
			"STAGE %d mode=%d seed=%d genes=%s"
			% [
				target_stage,
				int(request.mode),
				request.seed,
				JSON.stringify(selections),
			]
		)

		var result: PetRenderResult = await _renderer.render(request)
		if result == null or not result.success:
			push_error(
				"Stage %d render failed: %s / %s"
				% [
					target_stage,
					result.error_code if result != null else "null",
					result.error_message if result != null else "null result",
				]
			)
			quit(1)
			return

		if not _session.accept(result):
			push_error("Stage %d commit rejected" % target_stage)
			quit(1)
			return

		var out_path := "/tmp/cloudflare_stage_%d.png" % target_stage
		if not _copy_file(result.image_path, out_path):
			push_error("Could not copy Stage %d image" % target_stage)
			quit(1)
			return

		var stage_report := {
			"stage": target_stage,
			"mode": int(request.mode),
			"render_seed": request.seed,
			"genes": selections,
			"model": String(result.model_id),
			"image_path": out_path,
			"positive_prompt": request.positive_prompt,
			"negative_prompt": request.negative_prompt,
			"wire_prompt": wire_prompt,
			"metadata": result.metadata,
		}
		(_summary["stages"] as Array).append(stage_report)

	var summary_file := FileAccess.open("/tmp/cloudflare_4stage_summary.json", FileAccess.WRITE)
	if summary_file == null:
		push_error("Could not write summary")
		quit(1)
		return
	summary_file.store_string(JSON.stringify(_summary, "\t"))
	summary_file.close()

	print("FOUR STAGE CLOUDFLARE RENDER PASS")
	quit(0)


func _random_gene_selections(source_stage: int) -> Array[Dictionary]:
	var allowed: Array[GeneDefinition] = _session.available_genes(source_stage)
	var result: Array[Dictionary] = []
	if allowed.is_empty():
		return result

	var remaining: Array[GeneDefinition] = allowed.duplicate()
	var wanted := mini(_rng.randi_range(2, 4), remaining.size())
	var generator := ItemGenerator.new()

	for index in range(wanted):
		var pick_index := _rng.randi_range(0, remaining.size() - 1)
		var definition: GeneDefinition = remaining[pick_index]
		remaining.remove_at(pick_index)

		var item_seed := _rng.randi_range(1, 2147483646)
		var generated := generator.generate_gene(definition, item_seed)
		var rarity := String(generated.get("rarity", "common"))

		result.append({
			"gene_id": String(definition.id()),
			"rarity": rarity,
			"count": 1,
			"rolled_item_seed": item_seed,
		})

	return result


func _copy_file(source_path: String, target_path: String) -> bool:
	var bytes := FileAccess.get_file_as_bytes(source_path)
	if bytes.is_empty():
		return false
	var file := FileAccess.open(target_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(bytes)
	file.close()
	return true
