extends Node

## Central RNG service.
## All future randomness (egg, hatch task, pet, traits...) must derive from a run seed.

var _rng := RandomNumberGenerator.new()
var current_seed: int = 0

func create_new_seed() -> int:
    # Time-based seed is only used once when a new life starts.
    # The generated seed is then persisted so the run can be reproduced.
    var seed_value := int(Time.get_unix_time_from_system() * 1000.0) ^ Time.get_ticks_usec()
    seed_value = abs(seed_value)
    if seed_value == 0:
        seed_value = 1
    return seed_value

func set_run_seed(seed_value: int) -> void:
    current_seed = seed_value
    _rng.seed = seed_value

func range_i(min_value: int, max_value: int) -> int:
    return _rng.randi_range(min_value, max_value)

func range_f(min_value: float, max_value: float) -> float:
    return _rng.randf_range(min_value, max_value)

func pick(items: Array) -> Variant:
    if items.is_empty():
        return null
    return items[range_i(0, items.size() - 1)]

func derive_seed(channel: StringName) -> int:
    # Stable channel-specific seed derived from run seed.
    # Avoids unrelated random systems consuming each other's sequence later.
    return abs(hash(str(current_seed) + ":" + String(channel)))
