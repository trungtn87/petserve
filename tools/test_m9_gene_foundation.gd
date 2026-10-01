extends SceneTree

var _failures: int = 0

func _initialize() -> void:
	var policy := StageGenePolicy.load_default()
	_expect(policy != null, "StageGenePolicy must load")
	if policy != null:
		_test_stage_policy(policy)
		_test_score_state(policy)
		_test_final_stage(policy)

	if _failures == 0:
		print("M9.2 Gene Foundation: PASS")
		quit(0)
		return
	push_error("M9.2 Gene Foundation: FAIL (%d)" % _failures)
	quit(1)


func _test_stage_policy(policy: StageGenePolicy) -> void:
	for stage_index in [1, 2, 3]:
		_expect(
			policy.allowed_loci(stage_index) == PetGenomeSchema.VISUAL_LOCI
			and policy.is_unlimited(stage_index)
			and policy.max_gene_items(stage_index) == StageGenePolicy.UNLIMITED_ITEMS,
			"Stage %d must allow all 12 Gene loci with unlimited item use" % stage_index
		)
		for locus in PetGenomeSchema.VISUAL_LOCI:
			_expect(
				policy.can_accept_gene(stage_index, locus),
				"Stage %d missing locus %s" % [stage_index, String(locus)]
			)

	_expect(
		policy.allowed_loci(4).is_empty()
		and policy.max_gene_items(4) == 0,
		"Stage 4 final form must lock new Gene Item use"
	)


func _test_score_state(policy: StageGenePolicy) -> void:
	var state := GeneDevelopmentState.new(1)

	_expect(
		bool(state.record_gene_item(
			policy, "tail_a", &"tail_long", &"tail", &"long", 20.0
		).get("ok", false)),
		"first tail Gene records"
	)
	_expect(
		bool(state.record_gene_item(
			policy, "tail_b", &"tail_long", &"tail", &"long", 35.0
		).get("ok", false)),
		"same Gene may stack again in one Stage"
	)
	_expect(
		bool(state.record_gene_item(
			policy, "eyes_a", &"eyes_moon", &"eyes", &"moon", 10.0
		).get("ok", false)),
		"third Gene is not blocked by a slot cap"
	)
	_expect(
		state.item_count() == 3
		and is_equal_approx(state.score_for(&"tail", &"long"), 55.0)
		and GeneExpressionScale.tier_for_score(55.0) == GeneExpressionScale.DEVELOPING,
		"Gene score must accumulate by locus.direction"
	)

	_expect(state.reset_for_stage(2), "Stage reset succeeds")
	_expect(
		state.item_count() == 0
		and state.lifetime_gene_count() == 3
		and is_equal_approx(state.score_for(&"tail", &"long"), 55.0)
		and state.used_gene_ids_snapshot().has("tail_long"),
		"Stage reset clears transition inputs but preserves lifetime score ledger"
	)

	_expect(
		bool(state.record_gene_item(
			policy, "tail_c", &"tail_fluffy", &"tail", &"fluffy", 80.0
		).get("ok", false)),
		"different direction in same locus can accumulate later"
	)
	_expect(
		is_equal_approx(state.score_for(&"tail", &"fluffy"), 80.0),
		"secondary direction has independent score"
	)


func _test_final_stage(policy: StageGenePolicy) -> void:
	var state := GeneDevelopmentState.new(4)
	_expect(not state.can_record(policy, &"aura"), "Stage 4 rejects new Gene Items")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
