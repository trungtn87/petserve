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
    check((finish.get("rewards", []) as Array).is_empty(), "completion must not auto-harvest reward")
    var waiting := service.snapshot(final_time)
    check(int(waiting.get("running_count", -1)) == 0, "finished slot must stop running")
    check(int(waiting.get("ready_count", 0)) == 1, "finished slot must wait for manual claim")
    var waiting_slots := waiting.get("slots", []) as Array
    check(bool((waiting_slots[0] as Dictionary).get("ready_to_claim", false)), "slot must expose ready-to-claim state")
    var blocked_start := service.start(final_time + 1, 0)
    check(not bool(blocked_start.get("ok", true)), "ready slot must not restart before claim")
    var claim := service.claim(0, final_time + 1)
    check(bool(claim.get("ok", false)), "player must manually claim finished crystallization")
    var claimed_reward: Variant = claim.get("reward", {})
    check(typeof(claimed_reward) == TYPE_DICTIONARY and not (claimed_reward as Dictionary).is_empty(), "manual claim must return persisted reward")
    check(int(service.snapshot(final_time + 1).get("ready_count", -1)) == 0, "claim must clear ready state")

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

    # Mỗi ô phải có thể bắt đầu/hủy độc lập từ UI.
    var targeted_meta: Dictionary = {}
    var targeted := ElementCrystallizationService.new()
    targeted.setup(targeted_meta, generator, definitions, policy, 9917, 2, &"earth")
    var targeted_time := 200000

    var start_slot_two := targeted.start(targeted_time, 1)
    check(bool(start_slot_two.get("ok", false)), "slot 2 must start independently")
    var targeted_state := targeted.snapshot(targeted_time)
    var targeted_slots := targeted_state.get("slots", []) as Array
    check(int(targeted_state.get("running_count", 0)) == 1, "targeted start must run exactly one slot")
    check(not bool((targeted_slots[0] as Dictionary).get("running", false)), "slot 1 must remain idle")
    check(bool((targeted_slots[1] as Dictionary).get("running", false)), "slot 2 must be running")

    var locked_slot := targeted.start(targeted_time, 2)
    check(not bool(locked_slot.get("ok", true)), "stage 2 must reject locked slot 3")

    var start_slot_one := targeted.start(targeted_time + 1, 0)
    check(bool(start_slot_one.get("ok", false)), "slot 1 must start independently")
    check(int(targeted.snapshot(targeted_time + 1).get("running_count", 0)) == 2, "both unlocked slots can run together")

    var cancel_slot_two := targeted.cancel(targeted_time + 2, 1)
    check(bool(cancel_slot_two.get("ok", false)), "slot 2 must cancel independently")
    targeted_state = targeted.snapshot(targeted_time + 2)
    targeted_slots = targeted_state.get("slots", []) as Array
    check(bool((targeted_slots[0] as Dictionary).get("running", false)), "cancelling slot 2 must not stop slot 1")
    check(not bool((targeted_slots[1] as Dictionary).get("running", false)), "cancelled slot 2 must become idle")

    print("ELEMENT CRYSTALLIZATION failures=", failures)
    get_tree().quit(1 if failures else 0)
