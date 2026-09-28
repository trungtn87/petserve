class_name InfantGameFacade
extends RefCounted


const META_SCHEMA: int = 1


var _meta: Dictionary = {}
var _generator: ItemGenerator = ItemGenerator.new()
var _inventory: InventoryService = InventoryService.new()
var _chests: ChestService = ChestService.new()
var _lifecycle: InfantLifecycle = InfantLifecycle.new()
var _entertainment: MiniGameRewardService = MiniGameRewardService.new()
var _run_id: int = 0


func setup(run_id: int) -> bool:
	_run_id = run_id
	_meta = SaveManager.load_meta()

	if _meta.is_empty():
		_meta = {
			"schema": META_SCHEMA,
			"inventory": [],
			"chest_queue": [],
		}

	_inventory.setup(_meta)
	_chests.setup(_meta, _generator)
	_chests.ensure_hatch_chest(run_id)
	_lifecycle.setup(_meta, run_id)
	_entertainment.setup(_meta, _chests, run_id)

	return save()


func tick(delta: float) -> void:
	var should_save := _lifecycle.tick(delta)

	if should_save:
		save()


func save() -> bool:
	return SaveManager.save_meta(_meta)


func snapshot() -> Dictionary:
	var state := _lifecycle.snapshot()

	state["pending_chests"] = _chests.pending_count()
	state["inventory_count"] = _inventory.count()

	var entertainment_state := _entertainment.snapshot(_run_id)

	for key in entertainment_state.keys():
		state[key] = entertainment_state[key]

	return state


func claim_caro_win_reward() -> Dictionary:
	var lifecycle_state := _lifecycle.snapshot()

	if bool(lifecycle_state.get("ready_to_evolve", false)):
		return {
			"ok": false,
			"rewarded": false,
			"message": "Ấu thể đã sẵn sàng tiến hóa • không nhận thêm rương.",
		}

	var result := _entertainment.claim_caro_win(_run_id)

	if bool(result.get("rewarded", false)):
		save()

	return result


func inventory(
	filter_type: StringName = &""
) -> Array[Dictionary]:
	return _inventory.list_items(filter_type)


func open_next_chest() -> Array[Dictionary]:
	var rewards := _chests.open_next()

	if rewards.is_empty():
		return []

	_inventory.add_items(rewards)
	save()

	return rewards


func use_item(uid: String) -> Dictionary:
	var item := _inventory.get_item(uid)

	if item.is_empty():
		return {
			"ok": false,
			"message": "Không tìm thấy vật phẩm.",
		}

	if not _inventory.can_use_in_infant(item):
		return {
			"ok": false,
			"message": "Vật phẩm này được giữ lại cho giai đoạn sau.",
		}

	var result := _lifecycle.apply_item(item)

	if not bool(result.get("ok", false)):
		return result

	if not _inventory.remove_item(uid):
		return {
			"ok": false,
			"message": "Đã áp dụng hiệu ứng nhưng không thể cập nhật kho đồ.",
		}

	save()

	return result


func describe_item(item: Dictionary) -> String:
	return _generator.describe(item)


func rarity_label(rarity: String) -> String:
	return _generator.rarity_label(rarity)


func quality_label(quality: String) -> String:
	return _generator.quality_label(quality)


func property_label(value: StringName) -> String:
	return _generator.property_label(value)


func defect_label(value: StringName) -> String:
	return _generator.defect_label(value)
