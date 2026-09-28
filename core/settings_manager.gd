extends Node

signal settings_changed

const SETTINGS_PATH: String = "user://settings.cfg"
const SECTION_GENERAL: String = "general"
const KEY_LANGUAGE: String = "language"
const SUPPORTED_LANGUAGES: Array[String] = ["vi", "en"]

var _language: String = "en"


func _ready() -> void:
	_load_settings()


func get_language() -> String:
	return _language


func set_language(language: String) -> bool:
	var normalized := _normalize_language(language)

	if not SUPPORTED_LANGUAGES.has(normalized):
		return false

	if _language == normalized:
		return true

	_language = normalized

	if not _save_settings():
		return false

	settings_changed.emit()
	return true


func _load_settings() -> void:
	var config := ConfigFile.new()
	var error := config.load(SETTINGS_PATH)

	if error == OK:
		var saved := _normalize_language(
			String(config.get_value(SECTION_GENERAL, KEY_LANGUAGE, ""))
		)

		if SUPPORTED_LANGUAGES.has(saved):
			_language = saved
			return

	_language = _detect_device_language()
	_save_settings()


func _save_settings() -> bool:
	var config := ConfigFile.new()
	config.set_value(SECTION_GENERAL, KEY_LANGUAGE, _language)

	var error := config.save(SETTINGS_PATH)

	if error != OK:
		push_error("SettingsManager: could not save settings.cfg")
		return false

	return true


func _detect_device_language() -> String:
	var locale := OS.get_locale().to_lower()
	var language := locale.get_slice("_", 0).get_slice("-", 0)

	if language == "vi":
		return "vi"

	return "en"


func _normalize_language(language: String) -> String:
	return language.strip_edges().to_lower().get_slice("_", 0).get_slice("-", 0)
