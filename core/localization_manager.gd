extends Node

signal language_changed(language: String)

const SUPPORTED_LANGUAGES: Array[String] = ["vi", "en"]
const TRANSLATION_FILES: Array[String] = [
	"res://localization/common.csv",
	"res://localization/egg.csv",
	"res://localization/pet.csv",
	"res://localization/item.csv",
]

var _language: String = "en"
var _translations: Dictionary = {}


func _ready() -> void:
	_build_translations()

	var initial_language := SettingsManager.get_language()

	if not _apply_language(initial_language, false):
		_apply_language("en", false)


func get_language() -> String:
	return _language


func is_language(language: String) -> bool:
	return _language == _normalize_language(language)


func set_language(language: String) -> bool:
	var normalized := _normalize_language(language)

	if not SUPPORTED_LANGUAGES.has(normalized):
		return false

	if _language == normalized:
		return true

	if not SettingsManager.set_language(normalized):
		return false

	return _apply_language(normalized, true)


func text(key: String, fallback: String = "") -> String:
	var translated := TranslationServer.translate(key)

	if translated == key and not fallback.is_empty():
		return fallback

	return translated


func _apply_language(language: String, emit_signal: bool) -> bool:
	var normalized := _normalize_language(language)

	if not SUPPORTED_LANGUAGES.has(normalized):
		return false

	_language = normalized
	TranslationServer.set_locale(normalized)

	if emit_signal:
		language_changed.emit(_language)

	return true


func _build_translations() -> void:
	for language in SUPPORTED_LANGUAGES:
		var translation := Translation.new()
		translation.locale = language
		_translations[language] = translation

	for path in TRANSLATION_FILES:
		_append_csv(path)

	for translation in _translations.values():
		TranslationServer.add_translation(translation)


func _append_csv(path: String) -> void:
	if not FileAccess.file_exists(path):
		push_error("LocalizationManager: missing " + path)
		return

	var file := FileAccess.open(path, FileAccess.READ)

	if file == null:
		push_error("LocalizationManager: could not open " + path)
		return

	if file.get_length() <= 0:
		file.close()
		return

	var header := file.get_csv_line(",")

	if header.is_empty():
		file.close()
		return

	var key_index := header.find("keys")

	if key_index < 0:
		file.close()
		push_error("LocalizationManager: CSV has no keys column: " + path)
		return

	var language_columns: Dictionary = {}

	for language in SUPPORTED_LANGUAGES:
		var index := header.find(language)

		if index >= 0:
			language_columns[language] = index

	while file.get_position() < file.get_length():
		var row := file.get_csv_line(",")

		if row.is_empty() or key_index >= row.size():
			continue

		var key := String(row[key_index]).strip_edges()

		if key.is_empty():
			continue

		for language in language_columns.keys():
			var column := int(language_columns[language])

			if column >= row.size():
				continue

			var value := String(row[column])

			if value.is_empty():
				continue

			var translation: Translation = _translations[language]
			translation.add_message(StringName(key), value)

	file.close()


func _normalize_language(language: String) -> String:
	return language.strip_edges().to_lower().get_slice("_", 0).get_slice("-", 0)
