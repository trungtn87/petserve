class_name PetNameValidator
extends RefCounted


const MIN_LENGTH: int = 1
const MAX_LENGTH: int = 16


func validate(
	raw_name: String
) -> Dictionary:
	var normalized: String = (
		_normalize(
			raw_name
		)
	)


	if normalized.is_empty():
		return {
			"ok": false,
			"name": "",
			"error": "Hãy nhập tên cho pet."
		}


	if normalized.length() < MIN_LENGTH:
		return {
			"ok": false,
			"name": "",
			"error": "Tên quá ngắn."
		}


	if normalized.length() > MAX_LENGTH:
		return {
			"ok": false,
			"name": "",
			"error": (
				"Tên tối đa %d ký tự."
				% MAX_LENGTH
			)
		}


	for index in range(
		normalized.length()
	):
		var code: int = normalized.unicode_at(
			index
		)

		if code < 32:
			return {
				"ok": false,
				"name": "",
				"error": "Tên chứa ký tự không hợp lệ."
			}


	return {
		"ok": true,
		"name": normalized,
		"error": ""
	}


func _normalize(
	raw_name: String
) -> String:
	var source: String = raw_name.strip_edges()

	var result: String = ""

	var previous_space: bool = false


	for index in range(
		source.length()
	):
		var character: String = source.substr(
			index,
			1
		)


		if character == " ":
			if previous_space:
				continue

			previous_space = true

		else:
			previous_space = false


		result += character


	return result.strip_edges()
