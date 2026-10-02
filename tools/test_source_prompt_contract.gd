extends SceneTree

const Composer = preload("res://features/evolution/visual/source_gene_prompt_composer.gd")
var failures := 0

func _initialize() -> void:
	var builder := InitialPetPromptBuilder.new()
	var renderer := ProxyPetRenderer.new(PetRenderConfig.load_default())
	var composer := Composer.new()
	for species in PetSpeciesCatalog.all():
		var identity := PetIdentityFactory.new().create(20261002, &"water", species, 0)
		var coordinator := InitialPetRenderCoordinator.new()
		var plan := coordinator.build_request(identity, PetGenomeFactory.new().create_initial())
		_check(plan.get("ok", false), "initial request for " + String(species))
		if not plan.get("ok", false):
			coordinator.free()
			continue
		var spec: InitialPetVisualSpec = plan.spec
		var request: PetRenderRequest = plan.request
		var exact_source_order := " ".join([spec.identity_section, spec.style_section, spec.form_section, spec.scene_section, spec.composition_section, spec.ui_safe_section, spec.future_space_section]).strip_edges()
		_check(builder.build_positive(spec) == exact_source_order, "exact 47d8688 initial section order")
		_check(request.positive_prompt.find("evolved chibi proportions") < request.positive_prompt.find("PETHOME HABITAT"), "character style before habitat")
		_check(request.positive_prompt.find("glossy expressive eyes") < request.positive_prompt.find("Approximate design ratios"), "stylization before anatomy ratios")
		_check(request.negative_prompt.contains("photorealistic animal"), "transport exclusion covers ordinary animal photos")
		_check(renderer._compose_prompt(request) == request.positive_prompt.strip_edges() + "\n\nSTRICTLY AVOID:\n" + request.negative_prompt.strip_edges(), "exact 47d8688 transport composition")
		var scores := {"eyes.gentle": 75.0, "ears.rounded": 90.0, "tail.long": 110.0, "body.sturdy": 110.0, "fur.layered": 60.0, "coat.striped": 75.0}
		var full := composer.compose("BASE-FIXTURE: canonical reference and element brief", identity, 4, scores)
		_check(full.contains("BASE-FIXTURE: canonical reference and element brief"), "coordinator prompt never overwritten")
		_check(full.contains("[ACCUMULATED GENE SCORE PHENOTYPE]") and full.contains("[INDIVIDUAL MORPHOLOGY V4"), "source appends score phenotype and individual morphology")
		for direction in ["gentle", "rounded", "long", "sturdy", "layered", "striped"]:
			_check(full.contains(" / " + direction + ":"), "all six scored directions preserved: " + direction)
		_check(full.find("evolved chibi proportions") < full.find("BASE-FIXTURE"), "evolution style precedes species and environment")
		if species == &"horse":
			var payload := {"prompt": renderer._compose_prompt(request), "width": 576, "height": 1024, "seed": request.seed}
			var file := FileAccess.open("/tmp/pet-horse-source47-request.json", FileAccess.WRITE)
			file.store_string(JSON.stringify(payload))
		coordinator.free()
	renderer.free()
	print("Source 47d8688 production prompt order, append flow and transport: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
