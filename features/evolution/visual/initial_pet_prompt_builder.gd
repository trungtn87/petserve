class_name InitialPetPromptBuilder
extends RefCounted


func build_positive(
	spec: InitialPetVisualSpec
) -> String:
	if spec == null or not spec.is_valid():
		return ""

	return " ".join([
		spec.identity_section,
		spec.style_section,
		spec.form_section,
		spec.scene_section,
		spec.composition_section,
		spec.ui_safe_section,
		spec.future_space_section,
	]).strip_edges()


func build_negative(
	spec: InitialPetVisualSpec
) -> String:
	if spec == null or not spec.is_valid():
		return ""

	return spec.negative_prompt
