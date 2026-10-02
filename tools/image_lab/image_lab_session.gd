extends RefCounted

const MemorySave = preload("res://tools/image_lab/memory_save.gd")
var save := MemorySave.new()
var service := StageEvolutionService.new(save)
var policy := StageGenePolicy.load_default()
var catalog: Array[GeneDefinition] = GeneCatalog.new().load_default()
var identity: PetIdentity
var snapshots: Dictionary = {}
var gene_snapshots: Dictionary = {}
var pending_genes: GeneDevelopmentState
var pending_stage: int = 0
var initial_plan: Dictionary = {}
var serial: int = 0

func reset(
	element: StringName,
	seed_value: int,
	species: StringName = &"cat"
) -> void:
	identity = PetIdentityFactory.new().create(
		seed_value,
		element,
		species,
		0
	)
	_clear_run_state()


func reset_random(seed_value: int) -> Dictionary:
	var random_service := RandomService.new()
	var egg_state := EggGenerator.new(random_service).create(seed_value)
	if egg_state == null:
		return {"ok": false, "error": "Không random được hệ từ EggGenerator."}

	var species := PetSpeciesCatalog.pick_for_seed(seed_value)
	identity = PetIdentityFactory.new().create(
		seed_value,
		StringName(egg_state.egg_type),
		species,
		0
	)
	if identity == null or not identity.is_valid():
		return {"ok": false, "error": "Không tạo được random PetIdentity."}

	_clear_run_state()
	return {
		"ok": true,
		"seed": seed_value,
		"species": String(identity.species()),
		"element": String(identity.element()),
	}


func _clear_run_state() -> void:
	snapshots.clear()
	gene_snapshots.clear()
	save.delete_data()
	initial_plan.clear()
	pending_stage = 0

func available_genes(source_stage: int) -> Array[GeneDefinition]:
	var result: Array[GeneDefinition] = []
	var genome: PetGenome = null
	if snapshots.has(source_stage):
		genome = PetGenome.from_dict(snapshots[source_stage].genome)
	for gene in catalog:
		if policy.can_accept_gene(source_stage, gene.locus()) and gene.is_element_compatible(identity.element()):
			if genome != null and String(gene.next_expression(genome.get_trait(gene.locus()))).is_empty():
				continue
			result.append(gene)
	return result

func random_gene_selections(source_stage: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if identity == null or not identity.is_valid():
		return result

	var pool: Array[GeneDefinition] = available_genes(source_stage)
	if pool.is_empty():
		return result

	var desired_count := clampi(source_stage + 1, 2, 3)
	var rng := RandomService.new().create_stream(
		identity.lineage_seed(),
		"image_lab_gene_stage_%d" % source_stage,
		identity.generation()
	)
	var used_loci: Dictionary = {}

	while not pool.is_empty() and result.size() < desired_count:
		var index := rng.randi_range(0, pool.size() - 1)
		var definition: GeneDefinition = pool[index]
		pool.remove_at(index)
		if definition == null or used_loci.has(definition.locus()):
			continue
		used_loci[definition.locus()] = true
		result.append({
			"gene_id": String(definition.id()),
			"rarity": _random_gene_rarity(rng),
			"count": 1,
		})

	return result


func _random_gene_rarity(rng: RandomNumberGenerator) -> String:
	var roll := rng.randi_range(0, 99)
	if roll >= 90:
		return "legendary"
	if roll >= 55:
		return "epic"
	return "rare"


func prepare(target_stage: int, selections: Array[Dictionary]) -> Dictionary:
	pending_stage = 0
	if target_stage < 1 or target_stage > 5:
		return {"ok": false, "error": "Stage không hợp lệ."}
	var request: PetRenderRequest
	if target_stage == 1:
		var coordinator := InitialPetRenderCoordinator.new()
		initial_plan = coordinator.build_request(identity, PetGenomeFactory.new().create_initial())
		coordinator.free()
		if not initial_plan.get("ok", false):
			return initial_plan
		request = initial_plan.request
		pending_genes = GeneDevelopmentState.new(1)
	else:
		var source_stage := target_stage - 1
		if not snapshots.has(source_stage):
			return {"ok": false, "error": "Hãy tạo ảnh Stage %d trước để có đúng ảnh tham chiếu." % source_stage}
		save.save_data(snapshots[source_stage])
		pending_genes = GeneDevelopmentState.from_dict(gene_snapshots[source_stage], policy)
		pending_genes.reset_for_stage(source_stage)
		var allowed := available_genes(source_stage)
		var item_number := 0
		for selection in selections:
			var definition := GeneCatalog.new().find_by_id(allowed, StringName(selection.gene_id))
			var rarity := String(selection.rarity)
			var score := ItemGenerator.new().gene_score_for_rarity(rarity)
			var count := int(selection.count)
			if definition == null or score <= 0 or count < 1 or count > 100:
				return {"ok": false, "error": "Gene, độ hiếm hoặc số lượng không hợp lệ cho stage/hệ này."}
			var tags := definition.influence_tags()
			for key in tags:
				tags[key] = float(tags[key]) * score / maxf(1.0, definition.primary_influence())
			for index in range(count):
				item_number += 1
				var recorded := pending_genes.record_gene_item(policy, "lab_s%d_item%d" % [source_stage, item_number], definition.id(), definition.locus(), definition.direction(), score, tags, rarity, definition.element_lock())
				if not recorded.get("ok", false):
					return recorded
		var prepared := service.prepare({"stage_index": source_stage, "can_evolve": true, "gene_items_used": pending_genes.item_count(), "gene_development": pending_genes.to_dict()})
		if not prepared.get("ok", false):
			return prepared
		request = service.build_request(prepared.data)
	if request == null or not request.is_valid():
		return {"ok": false, "error": "Game không tạo được render request hợp lệ."}
	# Cache key only: prompts, seed, mode and reference stay exactly as in game.
	serial += 1
	request.output_key = "image_lab_%d_%d_stage_%d" % [Time.get_ticks_usec(), serial, target_stage]
	pending_stage = target_stage
	return {"ok": true, "request": request}

func accept(result: PetRenderResult) -> bool:
	if result == null or not result.success or pending_stage == 0:
		return false
	if pending_stage == 1:
		var visual := PetVisualRecord.new()
		visual.pet_id = identity.pet_id()
		visual.image_path = result.image_path
		visual.source_mode = &"initial_pethome_v6_text_to_image"
		visual.renderer_id = result.renderer_id
		visual.model_id = result.model_id
		if not save.save_initial(identity, PetGenomeFactory.new().create_initial(), visual, "Image Lab", initial_plan.scene_profile):
			return false
	elif not service.commit(result):
		return false
	for stage in snapshots.keys():
		if int(stage) >= pending_stage:
			snapshots.erase(stage)
			gene_snapshots.erase(stage)
	snapshots[pending_stage] = save.load_data()
	gene_snapshots[pending_stage] = pending_genes.to_dict()
	pending_stage = 0
	return true
