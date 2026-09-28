class_name InitialPetPromptBuilder
extends RefCounted


func build_positive(
	spec: InitialPetVisualSpec
) -> String:
	if spec == null or not spec.is_valid():
		return ""

	return "\n\n".join([
		"[INITIAL IDENTITY]\n"
		+ spec.identity_section,

		"[GALAXY STYLE]\n"
		+ spec.style_section,

		"[INFANT FORM]\n"
		+ spec.form_section,

		"[COMPOSITION]\n"
		+ spec.composition_section,

		"[EVOLUTION SPACE]\n"
		+ spec.future_space_section,
	])


func build_negative(
	spec: InitialPetVisualSpec
) -> String:
	if spec == null or not spec.is_valid():
		return ""

	return spec.negative_prompt
