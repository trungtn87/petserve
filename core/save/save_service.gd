class_name SaveService
extends RefCounted


const SAVE_PATH: String = (
	"user://save_v11.json"
)


func save_game(data: Dictionary) -> bool:
	return AtomicJson.write(SAVE_PATH, data)


func load_game() -> Dictionary:
	return AtomicJson.read(SAVE_PATH)


func has_save() -> bool:
	return AtomicJson.exists(SAVE_PATH)


func delete_save() -> bool:
	return AtomicJson.erase(SAVE_PATH)
