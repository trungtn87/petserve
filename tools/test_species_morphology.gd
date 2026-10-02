extends SceneTree

const Morphology = preload("res://features/evolution/visual/lineage_morphology.gd")
const Resolved = preload("res://features/evolution/visual/resolved_form_prompt.gd")
var failures := 0

func _initialize() -> void:
	var model := Morphology.new()
	var builder := Resolved.new()
	var elements := [&"wood", &"water", &"fire", &"earth", &"metal", &"light", &"dark"]
	var scores := {"body.sturdy": 80.0, "structure.ancient": 80.0, "tail.long": 90.0, "ears.long": 90.0}
	for species in PetSpeciesCatalog.all():
		_check(Morphology.SPECIES.has(String(species)), "explicit calibration: " + String(species))
		var unique: Dictionary = {}
		for seed_value in range(1, 65):
			var identity := PetIdentityFactory.new().create(seed_value, &"water", species, 0)
			var born: Dictionary = model.profile(identity)
			_check(born == model.profile(identity), "same seed preserves individual")
			unique[JSON.stringify(born)] = true
			var previous: Dictionary = model.resolve(identity, 1, {})
			for stage in range(2, 6):
				var natural: Dictionary = model.resolve(identity, stage, {})
				var trained: Dictionary = model.resolve(identity, stage, scores)
				_check(float(natural.torso) > float(previous.torso) and float(natural.legs) > float(previous.legs), "each stage matures " + String(species))
				_check(float(trained.chest) > float(natural.chest), "structural score changes form")
				var config: Dictionary = Morphology.SPECIES[String(species)]
				_check(float(trained.tail) <= float(config.tail_max), "tail remains species bounded")
				_check(float(trained.ears) <= float(config.ears_max), "ear remains species bounded")
				var prompt: String = builder.build(identity, stage, scores)
				_check(prompt.contains("Approximate design ratios") and prompt.contains("Gene emphasis: ears"), "production brief includes resolved V1 form and focus")
				_check(prompt == builder.build(identity, stage, scores), "canonical request deterministic")
				if species in [&"bird", &"phoenix", &"lizard", &"dragon"]:
					_check(float(trained.ears) == 0.0 and not prompt.contains("Ear length relative"), "no mammal ears on bird or reptile")
				previous = natural
		_check(unique.size() == 64, "64 distinct lives within " + String(species))
		for element in elements:
			var identity := PetIdentityFactory.new().create(20261002, element, species, 0)
			var initial := InitialPetVisualSpecBuilder.new().build(identity, PetGenomeFactory.new().create_initial(), MythicStyleProfile.load_default(), InitialSpeciesCatalog.new().find_by_species(InitialSpeciesCatalog.new().load_default(), species))
			_check(initial != null, "initial visual spec for species/element")
			if initial != null:
				_check(initial.form_section.contains("INDIVIDUAL MORPHOLOGY V4"), "Stage 1 uses inherited V1 frame")
				if species in [&"bird", &"phoenix"]:
					_check(not initial.style_section.contains("ear fur") and not initial.style_section.contains("orange fur"), "avian element accents use feathers")
				if species in [&"lizard", &"dragon"]:
					_check(not initial.style_section.contains("ear fur") and not initial.style_section.contains("orange fur"), "reptile element accents use scales")
	_check(model.profile(null).is_empty(), "invalid identity safe")
	print("Species morphology: 12 species x 64 lives x 5 stages + 84 initial briefs: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
