extends SceneTree
const Morphology = preload("res://features/evolution/visual/lineage_morphology.gd")
var failures := 0

func _initialize() -> void:
	var model := Morphology.new()
	var unique: Dictionary = {}
	var scores := {"body.sturdy": 80.0, "structure.ancient": 80.0, "tail.long": 90.0}
	for seed_value in range(1, 65):
		var identity := PetIdentityFactory.new().create_initial(seed_value, &"water")
		var birth: Dictionary = model.profile(identity)
		_check(birth == model.profile(identity), "stable lineage")
		unique[JSON.stringify(birth)] = true
		var previous: Dictionary = model.resolve(identity, 1, {})
		for stage in range(2, 6):
			var grown: Dictionary = model.resolve(identity, stage, {})
			_check(float(grown.torso) > float(previous.torso) and float(grown.legs) > float(previous.legs), "natural maturation changes proportions")
			previous = grown
		var natural: Dictionary = model.resolve(identity, 4, {})
		var trained: Dictionary = model.resolve(identity, 4, scores)
		_check(float(trained.chest) > float(natural.chest), "sturdy and ancient alter chest")
		_check(float(trained.tail) > float(natural.tail), "tail gene alters ratio")
		_check(model.build(identity, 4, scores) == model.build(identity, 4, scores), "stable pose and prompt")
		var prompt := model.build(identity, 4, scores)
		_check(prompt.contains("Presentation:"), "production morphology exposes presentation pose")
		_check(prompt.contains("This pose only reveals the form; it must not reshape anatomy."), "pose cannot reshape anatomy")
	_check(unique.size() == 64, "distinct birth profiles for sampled seeds")
	var catalog := GeneCatalog.new().load_default()
	var visuals := MutationVisualCatalog.new()
	for gene in catalog:
		_check(gene.expression_chain().size() >= 4, "four feeding stages before Final")
		for stage in range(1, 5):
			var visual := visuals.find_by_id(visuals.load_default(), StringName("gene_expr_%s_s%d" % [gene.id(), stage]))
			_check(visual != null and visual.instruction().contains(gene.prompt_stem()), "catalog controls all Gene visuals")
	print("Lineage morphology: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)

func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)
