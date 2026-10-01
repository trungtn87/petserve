extends EvolutionSaveService

# Test plans never touch the player's EvolutionSaveService.SAVE_PATH.
var data: Dictionary = {}

func save_data(value: Dictionary) -> bool:
	data = value.duplicate(true)
	return true

func load_data() -> Dictionary:
	return data.duplicate(true)

func delete_data() -> bool:
	data.clear()
	return true
