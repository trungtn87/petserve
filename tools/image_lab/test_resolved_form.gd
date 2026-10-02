extends SceneTree
const Builder = preload("res://features/evolution/visual/resolved_form_prompt.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var image := Image.create(32, 48, false, Image.FORMAT_RGBA8)
	image.fill(Color.FOREST_GREEN)
	var path := "user://resolved_form_fixture.png"
	image.save_png(path)
	var lab: Control = load("res://tools/image_lab/image_lab.tscn").instantiate()
	root.add_child(lab)
	lab._load_wood_preset()
	_check(lab.session.identity.lineage_seed() == 1420288088, "reproduce user's seed")
	for stage in range(1, 6):
		lab.target.select(stage - 1)
		lab._refresh()
		lab.render_mode.select(0)
		lab._prepare()
		_check(lab.request != null, "prepare stage %d" % stage)
		if lab.request == null:
			push_error(lab.status.text)
			break
		var positive: String = lab.request.positive_prompt
		var seed_value: int = lab.request.seed
		if stage >= 2:
			_check(lab.request.mode == PetRenderRequest.RenderMode.EVOLUTION_IMAGE_EDIT, "production reference mode")
			_check(not lab.request.source_image_path.is_empty(), "previous stage image supplied as reference")
			if stage in [2, 3, 4]:
				_check(positive.contains("[REFERENCE IMAGE]"), "Stage %d reference-image prompt" % stage)
				_check(positive.contains("[STAGE %d GROWTH]" % stage), "Stage %d growth prompt" % stage)
				_check(
					positive.contains("Use the supplied Stage %d image" % (stage - 1)),
					"Stage %d uses previous stage as visual source" % stage
				)
				_check(not positive.contains("Stage 1 ancestry cues:"), "previous stage is not verbally reconstructed")
				_check(not positive.contains("TARGET IMAGE:"), "old target-form prompt removed for Stage %d" % stage)
				_check(not positive.contains("Approximate silhouette ratios:"), "numeric morphology removed for Stage %d" % stage)
			lab.render_mode.select(1)
			lab._prepare()
			_check(lab.request.mode == PetRenderRequest.RenderMode.EVOLUTION_TEXT_TO_IMAGE and lab.request.source_image_path.is_empty(), "fresh mode removes reference")
			_check(lab.request.positive_prompt == positive and lab.request.seed == seed_value, "A/B same exact brief and seed")
		if stage == 4:
			_check(positive.contains("[STAGE 4 GROWTH]"), "Stage 4 mature growth block")
			_check(positive.contains("[GENE TRAITS]"), "Stage 4 accumulated Gene block")
			_check(positive.contains("[BACKGROUND]"), "Stage 4 background continuity")
			_check(positive.contains("mature Stage 4 form"), "Stage 4 mature form instruction")
			_check(not positive.contains("INDIVIDUAL FRAME:"), "Stage 4 does not verbally rebuild inherited frame")
			_check(not positive.contains("FAILURE CONDITION"), "meta failure block removed")
			print("Stage 4 reference prompt characters: ", positive.length())
		_check(lab.session.accept(PetRenderResult.ok(path, &"test", &"fixture", {"seed": seed_value})), "commit stage %d" % stage)
	var identity := lab.session.identity as PetIdentity
	var builder := Builder.new()
	var scores := {"ears.rounded": 55.0, "ears.softfan": 55.0, "tail.fluffy": 160.0}
	var reversed := {"tail.fluffy": 160.0, "ears.softfan": 55.0, "ears.rounded": 55.0}
	_check(builder.build(identity, 4, scores) == builder.build(identity, 4, reversed), "order independent blend")
	var mythic := builder.build(identity, 4, scores, {"mode": "awaken", "prompt": "authorized pair of wings"})
	_check(
		mythic.contains("[MYTHIC]")
		and mythic.contains("authorized pair of wings"),
		"mythic permission preserved"
	)
	lab.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("Resolved form + preset + A/B: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)

func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)
