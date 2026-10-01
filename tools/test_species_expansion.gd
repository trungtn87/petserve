extends SceneTree


const EXPECTED_SPECIES: Array[StringName] = [
	&"cat",
	&"dog",
	&"fox",
	&"bear",
	&"rabbit",
	&"lizard",
	&"bird",
	&"dragon",
	&"phoenix",
	&"horse",
	&"qilin",
	&"deer",
]

const EXPECTED_SPECIES_MUTATIONS := {
	"cat": ["cat_folded_spirit_ears", "cat_double_tail", "cat_hunter_mane"],
	"dog": ["dog_drop_ears", "dog_curl_tail", "dog_guardian_shoulders"],
	"fox": ["fox_fan_tail", "fox_double_tail", "fox_spirit_mask"],
	"bear": ["bear_massive_paws", "bear_shoulder_mane", "bear_ancient_bulk"],
	"rabbit": ["rabbit_lop_ears", "rabbit_giant_tail", "rabbit_moon_hindlegs"],
	"lizard": ["lizard_dorsal_crest", "lizard_crystal_scales", "lizard_spiked_tail"],
	"bird": ["bird_crown_crest", "bird_long_tail_plume", "bird_wing_eye_pattern"],
	"dragon": ["dragon_horn_crown", "dragon_scale_plates", "dragon_tail_blade", "dragon_wing_buds", "dragon_full_wings"],
	"phoenix": ["phoenix_crown_crest", "phoenix_tail_streamers", "phoenix_layered_wings", "phoenix_rebirth_plumage", "phoenix_rebirth_aura"],
	"horse": ["horse_flowing_mane", "horse_swift_hooves", "horse_ribbon_tail", "horse_noble_frame", "horse_wind_mark"],
	"qilin": ["qilin_cloud_mane", "qilin_scale_patch", "qilin_sacred_hooves", "qilin_horn_growth", "qilin_ribbon_tail"],
	"deer": ["deer_antler_buds", "deer_long_legs", "deer_leaf_marks", "deer_forest_mane", "deer_moon_eyes"],
}


var _failures: int = 0


func _initialize() -> void:
	_test_species_catalog()
	_test_initial_profiles()
	_test_species_mutations()
	_test_mutation_visual_contracts()
	_test_anatomy_loci()
	_test_mythic_branches()

	if _failures == 0:
		print("Species Expansion: PASS")
		quit(0)
		return

	push_error("Species Expansion: FAIL (%d)" % _failures)
	quit(1)


func _test_species_catalog() -> void:
	var all_species := PetSpeciesCatalog.all()
	_expect(all_species.size() == EXPECTED_SPECIES.size(), "species catalog must contain exactly twelve species")

	for species in EXPECTED_SPECIES:
		_expect(all_species.has(species), "missing species: %s" % String(species))
		_expect(PetSpeciesCatalog.is_supported(species), "species must be supported: %s" % String(species))

	for seed in range(1, 100):
		var a := PetSpeciesCatalog.pick_for_seed(seed)
		var b := PetSpeciesCatalog.pick_for_seed(seed)
		_expect(a == b, "species selection must be deterministic for seed %d" % seed)
		_expect(EXPECTED_SPECIES.has(a), "seed selected unsupported species: %s" % String(a))


func _test_initial_profiles() -> void:
	var catalog := InitialSpeciesCatalog.new()
	var profiles := catalog.load_default()
	_expect(profiles.size() == EXPECTED_SPECIES.size(), "initial species profile count must be twelve")

	for species in EXPECTED_SPECIES:
		var profile := catalog.find_by_species(profiles, species)
		_expect(profile != null and profile.is_valid(), "missing/invalid initial profile: %s" % String(species))


func _test_species_mutations() -> void:
	var catalog := MutationCatalog.new()
	var definitions := catalog.load_default()
	_expect(not definitions.is_empty(), "mutation catalog must load")

	for species_key in EXPECTED_SPECIES_MUTATIONS.keys():
		var expected_ids: Array = EXPECTED_SPECIES_MUTATIONS[species_key]

		for mutation_id in expected_ids:
			var definition := catalog.find_by_id(definitions, StringName(mutation_id))
			_expect(definition != null, "missing species mutation: %s" % mutation_id)
			if definition == null:
				continue

			var data := definition.to_dict()
			var allowed: Array = data.get("allowed_species", [])
			_expect(
				allowed.size() == 1 and String(allowed[0]) == String(species_key),
				"species mutation must be exclusive to %s: %s" % [species_key, mutation_id]
			)


func _test_mutation_visual_contracts() -> void:
	var catalog := MutationVisualCatalog.new()
	var visuals := catalog.load_default()

	for species_key in EXPECTED_SPECIES_MUTATIONS.keys():
		var expected_ids: Array = EXPECTED_SPECIES_MUTATIONS[species_key]
		for mutation_id in expected_ids:
			var visual := catalog.find_by_id(
				visuals,
				StringName(mutation_id)
			)
			_expect(
				visual != null and visual.is_valid(),
				"missing/invalid visual mutation contract: %s" % mutation_id
			)


func _test_anatomy_loci() -> void:
	for locus in [
		&"horns",
		&"wings",
		&"hooves",
		&"antlers",
	]:
		_expect(
			PetGenomeSchema.is_visual_locus(locus),
			"missing anatomy locus: %s" % String(locus)
		)


func _test_mythic_branches() -> void:
	var catalog := SpeciesMythicMutationCatalog.new()
	var definitions := catalog.load_default()
	_expect(definitions.size() == EXPECTED_SPECIES.size() * 2, "must have exactly two Mythic branches per species")

	for species in EXPECTED_SPECIES:
		var branches := catalog.for_species(definitions, species)
		_expect(branches.size() == 2, "species must have exactly two Mythic branches: %s" % String(species))

		for branch in branches:
			_expect(branch != null and branch.is_valid(), "invalid Mythic branch for %s" % String(species))
			if branch == null:
				continue
			_expect(branch.supports_stage(3), "Mythic must support stage 3: %s" % String(branch.id()))
			_expect(branch.supports_stage(4), "Mythic must support stage 4: %s" % String(branch.id()))
			_expect(branch.supports_stage(5), "Mythic must support stage 5: %s" % String(branch.id()))


func _expect(condition: bool, message: String) -> void:
	if condition:
		return

	_failures += 1
	push_error(message)
