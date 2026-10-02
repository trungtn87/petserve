extends SceneTree

const Session = preload("res://tools/image_lab/image_lab_session.gd")
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var seed := 246813579
	var session := Session.new()
	var randomized := session.reset_random(seed)
	_check(randomized.get("ok", false), "random identity")
	if not randomized.get("ok", false):
		_finish()
		return

	var expected_egg := EggGenerator.new(RandomService.new()).create(seed)
	_check(expected_egg != null, "egg generator")
	_check(
		session.identity.species() == PetSpeciesCatalog.pick_for_seed(seed),
		"species uses PetHome weighted catalog"
	)
	if expected_egg != null:
		_check(
			session.identity.element() == StringName(expected_egg.egg_type),
			"element uses PetHome EggGenerator"
		)

	var image := Image.create(32, 48, false, Image.FORMAT_RGBA8)
	image.fill(Color.DARK_BLUE)
	var path := "user://image_lab_random_contract.png"
	image.save_png(path)

	var identity_id := session.identity.pet_id()
	var species := session.identity.species()
	var element := session.identity.element()

	for stage in range(1, 5):
		var selections: Array[Dictionary] = []
		if stage > 1:
			var first := session.random_gene_selections(stage - 1)
			var second := session.random_gene_selections(stage - 1)
			_check(first == second, "random genes deterministic stage %d" % stage)
			selections = first
			_check(not selections.is_empty(), "random genes exist stage %d" % stage)
			_validate_selections(session, stage - 1, selections)

		var prepared: Dictionary = session.prepare(stage, selections)
		_check(
			prepared.get("ok", false),
			"prepare stage %d: %s" % [stage, prepared.get("error", "")]
		)
		if not prepared.get("ok", false):
			break

		var request: PetRenderRequest = prepared.request
		_check(request != null and request.is_valid(), "valid request stage %d" % stage)
		if request != null:
			_check(not request.positive_prompt.is_empty(), "positive prompt stage %d" % stage)
			_check(not request.negative_prompt.is_empty(), "negative prompt stage %d" % stage)

		var result := PetRenderResult.ok(
			path,
			&"contract_test",
			&"no_ai",
			{"seed": request.seed}
		)
		_check(session.accept(result), "accept stage %d" % stage)
		_check(session.identity.pet_id() == identity_id, "identity stable stage %d" % stage)
		_check(session.identity.species() == species, "species stable stage %d" % stage)
		_check(session.identity.element() == element, "element stable stage %d" % stage)

	for stage in range(1, 5):
		_check(session.snapshots.has(stage), "snapshot stage %d" % stage)
	_check(not session.snapshots.has(5), "auto contract stops at stage 4")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_finish()


func _validate_selections(
	session,
	source_stage: int,
	selections: Array[Dictionary]
) -> void:
	var allowed: Array[GeneDefinition] = session.available_genes(source_stage)
	var catalog := GeneCatalog.new()
	var seen_loci: Dictionary = {}

	for selection in selections:
		var gene_id := StringName(String(selection.get("gene_id", "")))
		var definition := catalog.find_by_id(allowed, gene_id)
		_check(definition != null, "gene allowed: %s" % String(gene_id))
		if definition == null:
			continue
		_check(
			definition.is_element_compatible(session.identity.element()),
			"gene element compatible: %s" % String(gene_id)
		)
		_check(
			not seen_loci.has(definition.locus()),
			"auto random keeps unique loci"
		)
		seen_loci[definition.locus()] = true


func _finish() -> void:
	print(
		"Image Lab random Stage 1-4 contracts: %s"
		% ("PASS" if failures == 0 else "FAIL %d" % failures)
	)
	quit(0 if failures == 0 else 1)


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
