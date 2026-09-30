extends Node


var failures: int = 0


func _ready() -> void:
	call_deferred("run")


func check(
	ok: bool,
	label: String
) -> void:
	if ok:
		return

	failures += 1
	push_error(label)


func run() -> void:
	var generator := ItemGenerator.new()
	var catalog := GeneCatalog.new()
	var definitions := catalog.load_default()
	var policy := StageGenePolicy.load_default()

	check(
		not definitions.is_empty(),
		"gene catalog must load"
	)
	check(
		policy != null,
		"gene policy must load"
	)

	var meta: Dictionary = {}
	var service := ElementCrystallizationService.new()
	service.setup(
		meta,
		generator,
		definitions,
		policy,
		7281,
		1,
		&"dark"
	)

	var start_time := 100000
	var start_result := service.start(
		start_time
	)
	check(
		bool(start_result.get("ok", false)),
		"crystallization must start"
	)

	var first := service.snapshot(
		start_time
	)
	check(
		bool(first.get("running", false)),
		"stage one must be running"
	)
	check(
		int(first.get("stage", 0)) == 1,
		"must start at stage one"
	)
	check(
		int(first.get("remaining_seconds", 0)) == 3600,
		"stage one must last one hour"
	)
	check(
		String(first.get("element_id", "")) == "dark",
		"must keep pet element"
	)

	var early := service.process(
		start_time + 3599
	)
	check(
		not bool(early.get("changed", false)),
		"must not finish before one hour"
	)
	check(
		(early.get("rewards", []) as Array).is_empty(),
		"must not reward before deadline"
	)

	var frozen_meta := meta.duplicate(true)
	var final_time := start_time + 12 * 60 * 60
	var first_finish := service.process(
		final_time
	)
	var rewards_a := first_finish.get(
		"rewards",
		[]
	) as Array
	check(
		rewards_a.size() == 1,
		"offline catch-up must resolve to one reward"
	)
	check(
		not bool(
			service.snapshot(final_time).get(
				"running",
				true
			)
		),
		"service must return to idle after reward"
	)

	var replay_meta := frozen_meta.duplicate(true)
	var replay := ElementCrystallizationService.new()
	replay.setup(
		replay_meta,
		generator,
		definitions,
		policy,
		7281,
		1,
		&"dark"
	)
	var replay_finish := replay.process(
		final_time
	)
	var rewards_b := replay_finish.get(
		"rewards",
		[]
	) as Array

	check(
		rewards_b.size() == 1,
		"replay must resolve one reward"
	)

	if (
		rewards_a.size() == 1
		and rewards_b.size() == 1
	):
		var item_a := rewards_a[0] as Dictionary
		var item_b := rewards_b[0] as Dictionary
		check(
			String(item_a.get("uid", ""))
			== String(item_b.get("uid", "")),
			"fixed seed must prevent restart reroll"
		)
		check(
			String(item_a.get("source", ""))
			== "element_crystallization",
			"reward source must be crystallization"
		)
		check(
			String(
				item_a.get(
					"crystallization_element",
					""
				)
			) == "dark",
			"reward must carry element metadata"
		)

		if StringName(
			item_a.get(
				"item_type",
				""
			)
		) == ItemGenerator.TYPE_GENE:
			var tags := item_a.get(
				"influence_tags",
				{}
			) as Dictionary
			check(
				tags.has("element_dark"),
				"gene crystallization must carry element tag"
			)

	var second_start := service.start(
		final_time + 1
	)
	check(
		bool(second_start.get("ok", false)),
		"new cycle must start after completion"
	)
	var cancel_result := service.cancel(
		final_time + 2
	)
	check(
		bool(cancel_result.get("ok", false)),
		"running cycle must cancel"
	)
	check(
		not bool(
			service.snapshot(
				final_time + 2
			).get(
				"running",
				true
			)
		),
		"cancel must clear running state"
	)

	print(
		"ELEMENT CRYSTALLIZATION failures=",
		failures
	)
	get_tree().quit(
		1 if failures else 0
	)
