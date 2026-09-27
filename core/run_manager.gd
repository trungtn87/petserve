extends Node

const GAME_VERSION := "1.0.0-dev"
const SAVE_SCHEMA := 1

var run: Dictionary = {}

func _ready() -> void:
    restore_or_prepare()

func restore_or_prepare() -> void:
    var saved := SaveManager.load_run()
    if saved.is_empty():
        run = {
            "schema": SAVE_SCHEMA,
            "game_version": GAME_VERSION,
            "status": "no_life_started",
            "run_id": 0,
            "run_seed": 0
        }
        return

    run = saved
    var seed_value := int(run.get("run_seed", 0))
    if seed_value > 0:
        RandomManager.set_run_seed(seed_value)

func start_new_life() -> Dictionary:
    var new_seed := RandomManager.create_new_seed()
    RandomManager.set_run_seed(new_seed)

    run = {
        "schema": SAVE_SCHEMA,
        "game_version": GAME_VERSION,
        "status": "life_started",
        "run_id": int(Time.get_unix_time_from_system()),
        "run_seed": new_seed,
        "created_at_unix": int(Time.get_unix_time_from_system()),
        "stage": "bootstrap"
    }
    SaveManager.save_run(run)
    return run.duplicate(true)

func get_snapshot() -> Dictionary:
    return run.duplicate(true)
