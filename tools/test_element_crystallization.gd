extends Node

var failures: int = 0

func _ready() -> void:
    call_deferred("run")

func check(ok: bool, label: String) -> void:
    if ok:
        return
    failures += 1
    push_error(label)

func run() -> void:
    var generator := ItemGenerator.new()
    var catalog := GeneCatalog.new()
    var definitions := catalog.load_default()
    var policy := StageGenePolicy.load_default()
    check(not definitions.is_empty(), "gene catalog must load")
    check(policy != null, "gene policy must load")

    var meta: Dictionary = {}
    var service := ElementCrystallizationService.new()
    service.setup(meta, generator, definitions, policy, 7281, 1, &"dark")
    var start_time := 100000
    var started := service.start(start_time)
    check(bool(started.get("ok", false)), "stage 1 crystallization must start")
    var first := service.snapshot(start_time)
    check(int(first.get("unlocked_slots", 0)) == 1, "stage 1 must unlock one slot")
    check(int(first.get("running_count", 0)) == 1, "stage 1 must run one slot")
    check(int(first.get("remaining_seconds", 0)) == 3600, "stage one must last one hour")

    # Tiến hóa khi đang kết tinh chỉ mở thêm slot cho lượt mới; slot đang chạy không đổi.
    service.update_context(2, &"fire")
    var after_evolution := service.snapshot(start_time)
    check(int(after_evolution.get("unlocked_slots", 0)) == 2, "stage 2 must unlock two slots")
    var slots := after_evolution.get("slots", []) as Array
    check(slots.size() == 4, "snapshot must expose four physical slots")
    check(String((slots[0] as Dictionary).get("element_id", "")) == "dark", "running slot must preserve start element after evolution")
    check(int((slots[0] as Dictionary).get("pet_stage_at_start", 0)) == 1, "running slot must preserve start pet stage")
    check(int((slots[0] as Dictionary).get("finish_at_unix", 0)) == start_time + 3600, "evolution must not reset running timer")

    var final_time := start_time + 12 * 60 * 60
    var finish := service.process(final_time)
    check((finish.get("rewards", []) as Array).size() == 1, "stage 1 running slot must resolve exactly one reward")
    check(int(service.snapshot(final_time).get("running_count", -1)) == 0, "finished slot must return idle")

    # Sau khi đã ở pet stage 2, một lần bắt đầu lấp hai slot đã mở.
    var stage2_start := service.start(final_time + 1)
    check(bool(stage2_start.get("ok", false)), "stage 2 crystallization must start")
    var stage2 := service.snapshot(final_time + 1)
    check(int(stage2.get("unlocked_slots", 0)) == 2, "stage 2 capacity must remain two")
    check(int(stage2.get("running_count", 0)) == 2, "stage 2 must run two crystallization slots")
    slots = stage2.get("slots", []) as Array
    check(String((slots[0] as Dictionary).get("element_id", "")) == "fire", "new slot must use current element")
    check(String((slots[1] as Dictionary).get("element_id", "")) == "fire", "second new slot must use current element")

    # Tiến hóa tiếp không đụng hai slot đang chạy.
    var finish0 := int((slots[0] as Dictionary).get("finish_at_unix", 0))
    var finish1 := int((slots[1] as Dictionary).get("finish_at_unix", 0))
    service.update_context(4, &"water")
    var stage4 := service.snapshot(final_time + 2)
    check(int(stage4.get("unlocked_slots", 0)) == 4, "stage 4 must unlock maximum four slots")
    slots = stage4.get("slots", []) as Array
    check(int((slots[0] as Dictionary).get("finish_at_unix", 0)) == finish0, "evolution must not alter slot 1 timing")
    check(int((slots[1] as Dictionary).get("finish_at_unix", 0)) == finish1, "evolution must not alter slot 2 timing")
    check(String((slots[0] as Dictionary).get("element_id", "")) == "fire", "evolution must not alter slot 1 element")

    # Bắt đầu lại chỉ lấp hai slot mới, không restart hai slot cũ.
    var fill_more := service.start(final_time + 2)
    check(bool(fill_more.get("ok", false)), "newly unlocked slots must be startable")
    var full := service.snapshot(final_time + 2)
    check(int(full.get("running_count", 0)) == 4, "stage 4 must support four simultaneous slots")
    check(int(full.get("available_slots", -1)) == 0, "all four slots must be occupied")

    print("ELEMENT CRYSTALLIZATION failures=", failures)
    get_tree().quit(1 if failures else 0)
