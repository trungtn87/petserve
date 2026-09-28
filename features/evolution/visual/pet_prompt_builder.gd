class_name PetPromptBuilder
extends RefCounted


func build_positive(
	spec: PetVisualSpec
) -> String:
	if (
		spec == null
		or not spec.is_valid()
	):
		return ""

	var sections: Array[String] = []

	sections.append(
		"[IDENTITY LOCK]\n"
		+ spec.identity_prompt()
	)

	sections.append(
		"[GALAXY STYLE]\n"
		+ spec.style_prompt()
	)

	if not spec.state_prompt().is_empty():
		sections.append(
			"[CURRENT FORM]\n"
			+ spec.state_prompt()
		)

	sections.append(
		"[CHANGE ONLY]\n"
		+ spec.change_prompt()
	)

	sections.append(
		"[PRESERVE]\n"
		+ spec.preserve_prompt()
	)

	return "\n\n".join(sections)


func build_negative(
	spec: PetVisualSpec
) -> String:
	if (
		spec == null
		or not spec.is_valid()
	):
		return ""

	return spec.negative_prompt()


func build_debug_bundle(
	spec: PetVisualSpec
) -> Dictionary:
	if (
		spec == null
		or not spec.is_valid()
	):
		return {}

	return {
		"pet_id": spec.pet_id(),
		"style_id": String(spec.style_id()),
		"mutation_id": String(
			spec.mutation_id()
		),
		"target_region": String(
			spec.target_region()
		),
		"edit_strength": spec.edit_strength(),
		"positive_prompt": build_positive(
			spec
		),
		"negative_prompt": build_negative(
			spec
		),
	}
