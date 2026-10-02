class_name InitialPetPromptBuilder
extends RefCounted


func build_positive(
	spec: InitialPetVisualSpec
) -> String:
	if spec == null or not spec.is_valid():
		return ""

	return " ".join([
		# Klein 4B follows the beginning of the prompt most strongly.
		# PetHome framing/background are gameplay constraints, so they go first.
		spec.ui_safe_section,
		spec.scene_section,
		spec.composition_section,
		spec.identity_section,
		spec.form_section,
		spec.style_section,
		spec.future_space_section,
	]).strip_edges()


func build_negative(
	spec: InitialPetVisualSpec
) -> String:
	if spec == null or not spec.is_valid():
		return ""

	return spec.negative_prompt
