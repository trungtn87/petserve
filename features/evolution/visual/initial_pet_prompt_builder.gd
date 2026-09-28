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

		"[MYTHIC ELEMENTAL STYLE]\n"
		+ spec.style_section,

		"[INFANT FORM]\n"
		+ spec.form_section,

		"[PETHOME WORLD]\n"
		+ spec.scene_section,

		"[COMPOSITION]\n"
		+ spec.composition_section,

		"[UI SAFE LAYOUT]\n"
		+ spec.ui_safe_section,

		"[EVOLUTION SPACE]\n"
		+ spec.future_space_section,
	])


func build_negative(
	spec: InitialPetVisualSpec
) -> String:
	if spec == null or not spec.is_valid():
		return ""

	return spec.negative_prompt
