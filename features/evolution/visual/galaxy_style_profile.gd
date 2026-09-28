class_name GalaxyStyleProfile
extends RefCounted


const DEFAULT_PATH: String = (
	"res://data/evolution/visual/galaxy_style.json"
)


var _style_id: StringName = &""
var _identity_lock: String = ""
var _base_style: String = ""
var _preserve_rule: String = ""
var _negative_prompt: String = ""
var _element_accents: Dictionary = {}


func style_id() -> StringName:
	return _style_id


func identity_lock() -> String:
	return _identity_lock


func base_style() -> String:
	return _base_style


func preserve_rule() -> String:
	return _preserve_rule


func negative_prompt() -> String:
	return _negative_prompt


func accent_for(
	element: StringName
) -> String:
	var key := String(element)

	if _element_accents.has(key):
		return str(_element_accents[key])

	return str(
		_element_accents.get(
			"default",
			"subtle cosmic glow with restrained galaxy accents"
		)
	)


func is_valid() -> bool:
	return (
		not String(_style_id).is_empty()
		and not _identity_lock.is_empty()
		and not _base_style.is_empty()
		and not _preserve_rule.is_empty()
		and not _negative_prompt.is_empty()
	)


static func load_default() -> GalaxyStyleProfile:
	return load_from_path(DEFAULT_PATH)


static func load_from_path(
	path: String
) -> GalaxyStyleProfile:
	if not FileAccess.file_exists(path):
		push_error(
			"GalaxyStyleProfile: Không tìm thấy file: "
			+ path
		)
		return null

	var file := FileAccess.open(
		path,
		FileAccess.READ
	)

	if file == null:
		push_error(
			"GalaxyStyleProfile: Không mở được file: "
			+ path
		)
		return null

	var parsed: Variant = JSON.parse_string(
		file.get_as_text()
	)
	file.close()

	if typeof(parsed) != TYPE_DICTIONARY:
		push_error(
			"GalaxyStyleProfile: Root JSON phải là Dictionary."
		)
		return null

	var data := parsed as Dictionary
	var accents_value: Variant = data.get(
		"element_accents",
		{}
	)

	if typeof(accents_value) != TYPE_DICTIONARY:
		return null

	var profile := GalaxyStyleProfile.new()

	profile._style_id = StringName(
		str(data.get("style_id", ""))
	)
	profile._identity_lock = str(
		data.get("identity_lock", "")
	)
	profile._base_style = str(
		data.get("base_style", "")
	)
	profile._preserve_rule = str(
		data.get("preserve_rule", "")
	)
	profile._negative_prompt = str(
		data.get("negative_prompt", "")
	)
	profile._element_accents = (
		accents_value as Dictionary
	).duplicate(true)

	if not profile.is_valid():
		return null

	return profile
