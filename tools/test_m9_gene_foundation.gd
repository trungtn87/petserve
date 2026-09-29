extends SceneTree


var _failures: int = 0


func _initialize() -> void:
	var policy := StageGenePolicy.load_default()

	_expect(
		policy != null,
		"M9.2 StageGenePolicy must load"
	)

	if policy != null:
		_test_stage_policy(
			policy
		)
		_test_stage_one_state(
			policy
		)
		_test_stage_two_state(
			policy
		)
		_test_stage_three_state(
			policy
		)
		_test_invalid_stage_guards(
			policy
		)
		_test_final_stage(
			policy
		)

	if _failures == 0:
		print(
			"M9.2 Gene Foundation: PASS"
		)
		quit(0)
		return

	push_error(
		"M9.2 Gene Foundation: FAIL (%d)"
		% _failures
	)
	quit(1)


func _test_stage_policy(
	policy: StageGenePolicy
) -> void:
	var expected_stage_one: Array[StringName] = [
		&"eyes",
		&"ears",
		&"fur",
		&"coat",
		&"tail",
	]

	for locus in expected_stage_one:
		_expect(
			policy.can_accept_gene(
				1,
				locus
			),
			"Stage 1 must allow %s"
			% String(locus)
		)

	_expect(
		policy.allowed_loci(
			1
		).size() == 5
		and policy.max_gene_items(
			1
		) == 1,
		"Stage 1 must expose 5 loci and 1 Gene Item slot"
	)

	for locus in [
		&"body",
		&"whiskers",
		&"paws",
		&"mane",
		&"mark",
	]:
		_expect(
			policy.can_accept_gene(
				2,
				locus
			),
			"Stage 2 must open %s"
			% String(locus)
		)

	_expect(
		policy.allowed_loci(
			2
		).size() == 10
		and policy.max_gene_items(
			2
		) == 2,
		"Stage 2 must expose 10 loci and 2 Gene Item slots"
	)

	for locus in PetGenomeSchema.VISUAL_LOCI:
		_expect(
			policy.can_accept_gene(
				3,
				locus
			),
			"Stage 3 must allow every Genome V1 locus: %s"
			% String(locus)
		)

	_expect(
		policy.allowed_loci(
			3
		).size() == 12
		and policy.max_gene_items(
			3
		) == 3,
		"Stage 3 must expose all 12 loci and 3 Gene Item slots"
	)

	_expect(
		policy.allowed_loci(
			4
		).is_empty()
		and policy.max_gene_items(
			4
		) == 0,
		"Stage 4 must lock Gene Items"
	)

	_expect(
		not policy.can_accept_gene(
			1,
			&"body"
		),
		"Stage 1 must reject body"
	)

	for stage_index in range(
		StageGenePolicy.FIRST_STAGE,
		StageGenePolicy.FINAL_STAGE + 1
	):
		_expect(
			policy.has_stage(stage_index),
			"StageGenePolicy must define every lifecycle stage"
		)


func _test_stage_one_state(
	policy: StageGenePolicy
) -> void:
	var state := GeneDevelopmentState.new(
		1
	)

	var first := state.record_gene_item(
		policy,
		"gene_item_001",
		&"long_tail",
		&"tail",
		&"long",
		20.0
	)

	_expect(
		bool(
			first.get(
				"ok",
				false
			)
		),
		"Stage 1 must accept one allowed Gene Item"
	)

	_expect(
		is_equal_approx(
			state.influence_for(
				&"tail",
				&"long"
			),
			20.0
		),
		"Gene influence must be recorded"
	)

	var blocked_by_cap := state.record_gene_item(
		policy,
		"gene_item_002",
		&"moon_eyes",
		&"eyes",
		&"moon",
		20.0
	)

	_expect(
		not bool(
			blocked_by_cap.get(
				"ok",
				false
			)
		),
		"Stage 1 must enforce the one-item cap"
	)

	var round_trip := GeneDevelopmentState.from_dict(
		state.to_dict(),
		policy
	)

	_expect(
		round_trip != null
		and round_trip.item_count() == 1
		and is_equal_approx(
			round_trip.influence_for(
				&"tail",
				&"long"
			),
			20.0
		),
		"GeneDevelopmentState must round-trip"
	)

	var disallowed := GeneDevelopmentState.new(
		1
	).record_gene_item(
		policy,
		"gene_item_body",
		&"large_body",
		&"body",
		&"large",
		15.0
	)

	_expect(
		not bool(
			disallowed.get(
				"ok",
				false
			)
		),
		"Stage 1 must reject a locked locus"
	)


func _test_stage_two_state(
	policy: StageGenePolicy
) -> void:
	var state := GeneDevelopmentState.new(
		1
	)

	_expect(
		state.reset_for_stage(
			2
		)
		and state.is_empty(),
		"new Stage must start with a clean GeneDevelopmentState"
	)

	var first := state.record_gene_item(
		policy,
		"gene_item_s2_001",
		&"agile_body",
		&"body",
		&"agile",
		12.0
	)
	var second := state.record_gene_item(
		policy,
		"gene_item_s2_002",
		&"moon_mark",
		&"mark",
		&"moon",
		18.0
	)

	_expect(
		bool(
			first.get(
				"ok",
				false
			)
		)
		and bool(
			second.get(
				"ok",
				false
			)
		)
		and state.item_count() == 2,
		"Stage 2 must accept two Gene Items"
	)

	var third := state.record_gene_item(
		policy,
		"gene_item_s2_003",
		&"long_tail",
		&"tail",
		&"long",
		10.0
	)

	_expect(
		not bool(
			third.get(
				"ok",
				false
			)
		),
		"Stage 2 must enforce the two-item cap"
	)

	var duplicate_state := GeneDevelopmentState.new(
		2
	)
	_expect(
		bool(
			duplicate_state.record_gene_item(
				policy,
				"same_uid",
				&"agile_body",
				&"body",
				&"agile",
				5.0
			).get(
				"ok",
				false
			)
		)
		and not bool(
			duplicate_state.record_gene_item(
				policy,
				"same_uid",
				&"moon_mark",
				&"mark",
				&"moon",
				5.0
			).get(
				"ok",
				false
			)
		),
		"the same Gene Item UID cannot be consumed twice"
	)


func _test_stage_three_state(
	policy: StageGenePolicy
) -> void:
	var state := GeneDevelopmentState.new(3)

	for gene_data in [
		[
			"gene_item_s3_structure",
			&"horn_gene",
			&"structure",
			&"horn",
			15.0,
		],
		[
			"gene_item_s3_aura",
			&"dark_aura",
			&"aura",
			&"mist",
			18.0,
		],
		[
			"gene_item_s3_body",
			&"large_body",
			&"body",
			&"large",
			10.0,
		],
	]:
		_expect(
			bool(
				state.record_gene_item(
					policy,
					gene_data[0],
					gene_data[1],
					gene_data[2],
					gene_data[3],
					gene_data[4]
				).get(
					"ok",
					false
				)
			),
			"Stage 3 must accept all three unlocked Gene Item slots"
		)

	_expect(
		state.item_count() == 3
		and is_equal_approx(
			state.influence_for(
				&"structure",
				&"horn"
			),
			15.0
		)
		and is_equal_approx(
			state.influence_for(
				&"aura",
				&"mist"
			),
			18.0
		),
		"Stage 3 must record advanced structure/aura influence"
	)


func _test_invalid_stage_guards(
	policy: StageGenePolicy
) -> void:
	var state := GeneDevelopmentState.new(1)

	_expect(
		not state.reset_for_stage(5),
		"GeneDevelopmentState must reject stages outside the 1..4 lifecycle"
	)

	_expect(
		GeneDevelopmentState.from_dict(
			{
				"stage_index": 5,
				"gene_items": [],
			},
			policy
		) == null,
		"save data outside the 1..4 lifecycle must be rejected"
	)

	var base_direction := GeneDevelopmentState.new(
		1
	).record_gene_item(
		policy,
		"gene_item_base_direction",
		&"invalid_base_gene",
		&"tail",
		&"base",
		10.0
	)

	_expect(
		not bool(
			base_direction.get(
				"ok",
				false
			)
		),
		"Gene Item direction cannot be the base allele"
	)


func _test_final_stage(
	policy: StageGenePolicy
) -> void:
	var state := GeneDevelopmentState.new(
		4
	)

	_expect(
		not state.can_record(
			policy,
			&"aura"
		),
		"Stage 4 must reject Gene Items"
	)

	_expect(
		not bool(
			state.record_gene_item(
				policy,
				"gene_item_final",
				&"dark_aura",
				&"aura",
				&"dark",
				50.0
			).get(
				"ok",
				false
			)
		),
		"Stage 4 cannot record visual Gene influence"
	)


func _expect(
	condition: bool,
	message: String
) -> void:
	if condition:
		return

	_failures += 1
	push_error(
		message
	)
