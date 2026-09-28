class_name PetVisualSpecBuilder
extends RefCounted


func build(
	identity: PetIdentity,
	previous_genome: PetGenome,
	next_genome: PetGenome,
	delta: EvolutionDelta,
	style: MythicStyleProfile,
	visual: MutationVisualDefinition,
	visual_stage: int = -1
) -> PetVisualSpec:
	if not _validate_inputs(
		identity,
		previous_genome,
		next_genome,
		delta,
		style,
		visual
	):
		return null

	var identity_prompt := (
		style.identity_lock()
		+ " Species: "
		+ String(identity.species())
		+ ". Element family: "
		+ String(identity.element())
		+ "."
	)

	var style_prompt := (
		style.base_style()
		+ " Element lineage appearance: "
		+ style.accent_for(
			identity.element()
		)
		+ "."
	)

	var stage_for_prompt := (
		visual_stage
		if visual_stage > 0
		else next_genome.stage()
	)

	var state_prompt := (
		"Current form: evolution stage %d, body development %.0f%%. "
		+ "Use the provided previous pet image as the visual source of truth."
	) % [
		stage_for_prompt,
		next_genome.body_growth() * 100.0,
	]

	var change_prompt := (
		"Modify only the %s region. %s"
	) % [
		String(visual.target_region()),
		visual.instruction(),
	]

	var preserve_prompt := (
		style.preserve_rule()
		+ " "
		+ visual.preserve_hint()
		+ " Preserve all non-target genome channels: "
		+ _non_target_trait_list(
			next_genome,
			delta.target_trait()
		)
		+ "."
	)

	var spec := PetVisualSpec.new(
		identity.pet_id(),
		style.style_id(),
		delta.mutation_id(),
		visual.target_region(),
		visual.edit_strength(),
		identity_prompt,
		style_prompt,
		state_prompt,
		change_prompt,
		preserve_prompt,
		style.negative_prompt()
	)

	if not spec.is_valid():
		return null

	return spec


func _validate_inputs(
	identity: PetIdentity,
	previous_genome: PetGenome,
	next_genome: PetGenome,
	delta: EvolutionDelta,
	style: MythicStyleProfile,
	visual: MutationVisualDefinition
) -> bool:
	if (
		identity == null
		or previous_genome == null
		or next_genome == null
		or delta == null
		or style == null
		or visual == null
	):
		return false

	if (
		not identity.is_valid()
		or not previous_genome.is_valid()
		or not next_genome.is_valid()
		or not delta.is_valid()
		or not style.is_valid()
		or not visual.is_valid()
	):
		return false

	if (
		visual.mutation_id()
		!= delta.mutation_id()
	):
		return false

	if (
		visual.target_region()
		!= delta.target_trait()
	):
		return false

	if (
		previous_genome.stage()
		!= next_genome.stage()
	):
		return false

	if not is_equal_approx(
		previous_genome.body_growth(),
		next_genome.body_growth()
	):
		return false

	if (
		previous_genome.get_trait(
			delta.target_trait(),
			&"base"
		)
		!= delta.from_trait()
	):
		return false

	if (
		next_genome.get_trait(
			delta.target_trait(),
			&"base"
		)
		!= delta.to_trait()
	):
		return false

	if not _only_target_trait_changed(
		previous_genome,
		next_genome,
		delta.target_trait()
	):
		return false

	if not _mutation_history_is_valid(
		previous_genome,
		next_genome,
		delta.mutation_id()
	):
		return false

	return true


func _only_target_trait_changed(
	previous_genome: PetGenome,
	next_genome: PetGenome,
	target_trait: StringName
) -> bool:
	var keys: Dictionary = {}

	for key_value in (
		previous_genome
		.traits_snapshot()
		.keys()
	):
		keys[StringName(str(key_value))] = true

	for key_value in (
		next_genome
		.traits_snapshot()
		.keys()
	):
		keys[StringName(str(key_value))] = true

	for key_value in keys.keys():
		var key := StringName(
			str(key_value)
		)

		if key == target_trait:
			continue

		if (
			previous_genome.get_trait(
				key,
				&"base"
			)
			!= next_genome.get_trait(
				key,
				&"base"
			)
		):
			return false

	return true


func _mutation_history_is_valid(
	previous_genome: PetGenome,
	next_genome: PetGenome,
	new_mutation: StringName
) -> bool:
	var previous := (
		previous_genome.mutation_ids()
	)
	var next := next_genome.mutation_ids()

	if next.size() != previous.size() + 1:
		return false

	for index in range(previous.size()):
		if next[index] != previous[index]:
			return false

	return next.back() == new_mutation


func _non_target_trait_list(
	genome: PetGenome,
	target_trait: StringName
) -> String:
	var names: Array[String] = []

	for key_value in (
		genome.traits_snapshot().keys()
	):
		var key := StringName(
			str(key_value)
		)

		if key == target_trait:
			continue

		names.append(String(key))

	names.sort()

	if names.is_empty():
		return "all established features"

	return ", ".join(names)
