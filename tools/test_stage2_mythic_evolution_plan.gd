extends Node

var _failures: int = 0

func _ready() -> void:
	_test_locus_recipe_builds_retry_safe_mythic_plan()

	if _failures == 0:
		print("Stage 2 Mythic Evolution Plan: PASS")
		get_tree().quit(0)
		return

	push_error("Stage 2 Mythic Evolution Plan: FAIL (%d)" % _failures)
	get_tree().quit(1)


func _test_locus_recipe_builds_retry_safe_mythic_plan() -> void:
	_clear_evolution_save()
	var source_path := "user://stage2_mythic_plan_source.png"
	var image := Image.create(32, 48, false, Image.FORMAT_RGBA8)
	image.fill(Color("#221833"))
	_expect(image.save_png(source_path) == OK, "create source image")

	var identity := PetIdentityFactory.new().create_initial(7301, &"dark", &"cat")
	var scene := PetSceneProfileFactory.new().create_initial(identity)
	var traits := PetGenomeSchema.base_traits()
	traits[&"whiskers"] = &"starlight"
	traits[&"mark"] = &"dark"
	var genome := PetGenomeFactory.new().create_snapshot(
		2,
		0.0,
		traits,
		[&"gene_expr_whiskers_starlight_s1", &"gene_expr_mark_dark_s1"]
	)
	_expect(identity != null and scene != null and genome != null, "build Stage 2 fixture")
	if identity == null or scene == null or genome == null:
		return

	var visual := PetVisualRecord.new()
	visual.pet_id = identity.pet_id()
	visual.visual_index = 1
	visual.image_path = source_path
	visual.source_mode = &"evolution_pethome_v12_full_regenerate"
	visual.renderer_id = &"test"
	visual.model_id = &"test"

	var data := {
		"schema": EvolutionSaveService.CURRENT_SCHEMA,
		"pet_name": "Mythic Test",
		"identity": identity.to_dict(),
		"genome": genome.to_dict(),
		"scene_profile": scene.to_dict(),
		"current_visual": visual.to_dict(),
		"evolution_history": [
			{
				"from_stage": 1,
				"to_stage": 2,
				"gene_resolution": {
					"selected_gene_id": "whiskers_starlight",
					"selected_changes": [
						{"gene_id": "whiskers_starlight", "locus": "whiskers", "direction": "starlight", "resolved_trait": "starlight"},
						{"gene_id": "mark_dark", "locus": "mark", "direction": "dark", "resolved_trait": "dark"}
					]
				}
			}
		]
	}
	_expect(EvolutionSaveService.new().save_data(data), "save Stage 2 fixture")

	var policy := StageGenePolicy.load_default()
	var gene_state := GeneDevelopmentState.new(2)
	_expect(
		bool(gene_state.record_gene_item(
			policy, "recipe_ears", &"ears_tufted", &"ears", &"tufted", 20.0, {}
		).get("ok", false)),
		"record Stage 2 ears Gene"
	)
	_expect(
		bool(gene_state.record_gene_item(
			policy, "recipe_tail", &"tail_long", &"tail", &"long", 20.0, {}
		).get("ok", false)),
		"record second Stage 2 form Gene"
	)

	var runtime_state := {
		"stage_index": 2,
		"ready_to_evolve": true,
		"can_evolve": true,
		"gene_items_used": 2,
		"gene_development": gene_state.to_dict()
	}
	var service := StageEvolutionService.new()
	var prepared := service.prepare(runtime_state)
	_expect(bool(prepared.get("ok", false)), "prepare Stage 2 -> 3 locus-combo Mythic evolution")
	if not bool(prepared.get("ok", false)):
		_clear_evolution_save()
		return

	var prepared_data: Dictionary = prepared.get("data", {})
	var pending: Dictionary = prepared_data.get("pending_evolution", {})
	var destiny: Dictionary = pending.get("mythic_destiny", {})
	var mythic: Dictionary = pending.get("mythic_resolution", {})
	var deltas_value: Variant = pending.get("deltas", [])
	var next := PetGenome.from_dict(pending.get("genome", {}))
	var request := service.build_request(prepared_data)

	_expect(
		StringName(destiny.get("mutation_id", "")) == &"cat_horned_spirit"
		and _string_array(destiny.get("recipe_loci", [])) == ["ears", "mark", "whiskers"],
		"whiskers+mark+ears loci lock Giác Linh Miêu destiny"
	)
	_expect(
		StringName(mythic.get("mode", "")) == SpeciesMythicMutationResolver.MODE_AWAKEN
		and String(mythic.get("trigger_source", "")) == "gene_recipe",
		"Mythic branch awakens from species locus recipe"
	)
	_expect(
		typeof(deltas_value) == TYPE_ARRAY
		and (deltas_value as Array).size() == 2
		and next != null
		and next.get_trait(&"whiskers", &"base") == &"starlight"
		and next.get_trait(&"mark", &"base") == &"dark"
		and next.get_trait(&"ears", &"base") == &"tufted"
		and next.get_trait(&"tail", &"base") == &"long"
		and next.has_mutation(&"cat_horned_spirit"),
		"Stage 1 small traits + Stage 2 form traits + Mythic branch are locked together"
	)
	_expect(
		request != null
		and request.mode == PetRenderRequest.RenderMode.EVOLUTION_IMAGE_EDIT
		and request.source_image_path == source_path
		and request.positive_prompt.contains("[CODE-LOCKED MYTHIC RESULT]")
		and request.positive_prompt.contains("[ACCUMULATED GENE SCORE PHENOTYPE]"),
		"renderer receives reference-based composite Gene + Mythic plan"
	)
	if request == null:
		_clear_evolution_save()
		return

	var retry := StageEvolutionService.new().prepare(runtime_state)
	var retry_pending: Dictionary = retry.get("data", {}).get("pending_evolution", {})
	var retry_request := StageEvolutionService.new().build_request(retry.get("data", {}))
	_expect(
		bool(retry.get("ok", false))
		and retry_request != null
		and retry_request.seed == request.seed
		and _same_destiny(retry_pending.get("mythic_destiny", {}), destiny),
		"retry reuses the same Mythic destiny and render seed"
	)

	_expect(
		StageEvolutionService.new().commit(
			PetRenderResult.ok(source_path, &"test", &"test", {"seed": request.seed})
		),
		"commit composite Mythic evolution"
	)
	var committed := EvolutionSaveService.new().load_data()
	var committed_genome := PetGenome.from_dict(committed.get("genome", {}))
	_expect(
		committed_genome != null
		and committed_genome.stage() == 3
		and committed_genome.has_mutation(&"cat_horned_spirit")
		and not committed.has("pending_evolution"),
		"successful render commits Stage 3 Mythic branch exactly once"
	)
	_clear_evolution_save()


func _same_destiny(a_value: Variant, b_value: Variant) -> bool:
	if typeof(a_value) != TYPE_DICTIONARY or typeof(b_value) != TYPE_DICTIONARY:
		return false
	var a := a_value as Dictionary
	var b := b_value as Dictionary
	for key in ["schema", "locked", "source", "species", "mutation_id", "display_name"]:
		if a.get(key) != b.get(key):
			return false
	return _string_array(a.get("recipe_loci", [])) == _string_array(b.get("recipe_loci", []))


func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for item in value as Array:
		result.append(String(item))
	result.sort()
	return result


func _clear_evolution_save() -> void:
	if FileAccess.file_exists(EvolutionSaveService.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(EvolutionSaveService.SAVE_PATH))


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
