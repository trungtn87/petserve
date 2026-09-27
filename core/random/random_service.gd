class_name RandomService
extends RefCounted


const MIN_RUN_SEED: int = 100000
const MAX_RUN_SEED: int = 999999999


func create_run_seed() -> int:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()

	return rng.randi_range(
		MIN_RUN_SEED,
		MAX_RUN_SEED
	)


func create_stream(
	run_seed: int,
	scope: String,
	salt: int = 0
) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()

	var scope_hash: int = _stable_hash(
		scope
	)

	var combined_seed: int = (
		run_seed * 1103515245
		+ scope_hash * 12345
		+ salt
	)

	combined_seed = abs(
		combined_seed
	)

	if combined_seed == 0:
		combined_seed = 1

	rng.seed = combined_seed

	return rng


func _stable_hash(
	text: String
) -> int:
	var hash_value: int = 2166136261

	for index in range(
		text.length()
	):
		var character: int = text.unicode_at(
			index
		)

		hash_value = (
			hash_value ^ character
		)

		hash_value = int(
			(
				hash_value * 16777619
			)
			& 0x7FFFFFFF
		)

	if hash_value == 0:
		hash_value = 1

	return hash_value
