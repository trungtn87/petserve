class_name InitialSpeciesProfile
extends RefCounted


var species: StringName = &""
var infant_form: String = ""
var composition: String = ""
var forbidden_advanced_features: String = ""


func is_valid() -> bool:
	return (
		not String(species).is_empty()
		and not infant_form.is_empty()
		and not composition.is_empty()
		and not forbidden_advanced_features.is_empty()
	)


static func from_dict(
	data: Dictionary
) -> InitialSpeciesProfile:
	var profile := InitialSpeciesProfile.new()

	profile.species = StringName(
		str(data.get("species", ""))
			.strip_edges()
			.to_lower()
	)
	profile.infant_form = str(
		data.get("infant_form", "")
	).strip_edges()
	profile.composition = str(
		data.get("composition", "")
	).strip_edges()
	profile.forbidden_advanced_features = str(
		data.get(
			"forbidden_advanced_features",
			""
		)
	).strip_edges()

	if not profile.is_valid():
		return null

	return profile
