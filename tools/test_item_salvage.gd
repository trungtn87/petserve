extends Node

var failures := 0

func _ready() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)

func run() -> void:
	var meta := {"inventory": [], "chest_queue": []}
	var generator := ItemGenerator.new()
	var inventory := InventoryService.new()
	var chests := ChestService.new()
	inventory.setup(meta)
	chests.setup(meta, generator)

	var items: Array[Dictionary] = []
	for index in range(10):
		items.append(generator.generate(ItemGenerator.TYPE_FOOD, 1000 + index))
	inventory.add_items(items)

	for index in range(9):
		var item := inventory.list_items()[0]
		check(inventory.remove_item(String(item.get("uid", ""))), "remove salvage item " + str(index))
		check(chests.add_salvage_fragments(1, 77, 1) == 0, "no chest before ten fragments")

	check(chests.fragment_count() == 9, "nine fragments stored")
	check(chests.pending_count() == 0, "no recycled chest at nine fragments")

	var final_item := inventory.list_items()[0]
	check(inventory.remove_item(String(final_item.get("uid", ""))), "remove tenth salvage item")
	check(chests.add_salvage_fragments(1, 77, 1) == 1, "ten fragments craft one chest")
	check(chests.fragment_count() == 0, "fragments consumed by craft")
	check(chests.pending_count() == 1, "recycled chest queued")

	var rewards := chests.open_next()
	check(rewards.size() == 1, "recycled chest opens through normal queue")
	check(chests.pending_count() == 0, "recycled chest marked opened")

	print("ITEM SALVAGE failures=", failures)
	get_tree().quit(1 if failures else 0)
