extends SceneTree

const Session = preload("res://tools/image_lab/image_lab_session.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var real_save := EvolutionSaveService.new().load_data()
	var session := Session.new()
	var image := Image.create(32, 48, false, Image.FORMAT_RGBA8)
	image.fill(Color.DARK_BLUE)
	var path := "user://image_lab_contract_fixture.png"
	image.save_png(path)
	for element in ["metal", "wood", "water", "fire", "earth", "light", "dark"]:
		session.reset(StringName(element), 12345)
		_check(not session.prepare(3, []).get("ok", false), "cannot skip missing source")
		var genes: Array[Dictionary] = [{"gene_id": "tail_long", "rarity": "rare", "count": 2}]
		for stage in range(1, 6):
			var stage_genes: Array[Dictionary] = []
			if stage > 1:
				stage_genes = genes
			var prepared: Dictionary = session.prepare(stage, stage_genes)
			_check(prepared.get("ok", false), "%s stage %d: %s" % [element, stage, prepared.get("error", "")])
			if not prepared.get("ok", false):
				break
			var request: PetRenderRequest = prepared.request
			if stage > 1:
				var game_request: PetRenderRequest = session.service.build_request(session.save.load_data())
				_check(game_request != null and game_request.positive_prompt == request.positive_prompt and game_request.negative_prompt == request.negative_prompt and game_request.mode == request.mode and game_request.seed == request.seed and game_request.source_image_path == request.source_image_path, "exact production request except output cache key")
			if stage >= 2:
				_check(request.mode == PetRenderRequest.RenderMode.EVOLUTION_IMAGE_EDIT and request.source_image_path == path, "reference edit for stage 2+")
			var result := PetRenderResult.ok(path, &"contract_test", &"no_ai", {"seed": request.seed})
			_check(session.accept(result), "accept stage %d" % stage)
			if stage > 1:
				_check(session.pending_genes.score_for(&"tail", &"long") == (stage - 1) * 70.0, "scores accumulate once")
		for gene in session.available_genes(1):
			_check(gene.is_element_compatible(StringName(element)), "element lock filter")
		var rejected: Dictionary = session.prepare(2, [{"gene_id": "invalid", "rarity": "common", "count": 1}])
		_check(not rejected.get("ok", false), "reject invalid gene")
		var first: Dictionary = session.prepare(2, genes)
		var second: Dictionary = session.prepare(2, genes)
		if first.get("ok", false) and second.get("ok", false):
			_check(first.request.positive_prompt == second.request.positive_prompt, "re-preview does not accumulate twice")
			_check(first.request.output_key != second.request.output_key, "fresh cache key")
			_check(session.accept(PetRenderResult.ok(path, &"test", &"test", {"seed": second.request.seed})), "rerender earlier stage")
			_check(not session.snapshots.has(3), "invalidate descendants after rerender")
	var lab: Control = load("res://tools/image_lab/image_lab.tscn").instantiate()
	root.add_child(lab)
	lab._prepare()
	_check(lab.request != null and not lab.generate.disabled, "UI initial prompt")
	_check(lab.session.accept(PetRenderResult.ok(path, &"test", &"test", {"seed": lab.request.seed})), "UI fixture")
	lab.target.select(1)
	lab._refresh()
	lab._add_gene()
	lab._prepare()
	_check(lab.rows.get_child_count() == 1 and lab.request != null and not lab.prompt.text.is_empty(), "UI gene selection and production prompt")
	lab._invalidate()
	_check(lab.request == null and lab.generate.disabled, "changed controls invalidate stale request")
	lab.free()
	_check(real_save == EvolutionSaveService.new().load_data(), "player save unchanged")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("Image Lab contracts: %s" % ("PASS" if failures == 0 else "FAIL %d" % failures))
	quit(0 if failures == 0 else 1)

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
