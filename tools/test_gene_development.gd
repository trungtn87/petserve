extends SceneTree


const StageGenePolicyScript = preload(
	"res://features/evolution/gene/stage_gene_policy.gd"
)

const GeneDevelopmentStateScript = preload(
	"res://features/evolution/gene/gene_development_state.gd"
)


var _failures: int = 0


func _initialize() -> void:
	var policy = StageGenePolicyScript.load_default()

	_expect(
		policy != null,
		"default StageGenePolicy must load"
	)

	if policy != null:
		_test_policy(policy)
		_test_stage_one(policy)
		_test_stage_two_reinforcement(policy)
		_test_stage_three(policy)
		_test_stage_four(policy)
		_test_round_trip(policy)
		_test_copy_safety(policy)

	if _failures == 0:
		print("M9.2 Stage Gene State: PASS")
		quit(0)
		return

	push_error(
		"M9.2 Stage Gene State: FAIL (%d)"
		% _failures
	)
	quit(1)


func _test_policy(
	policy
) -> void:
	_expect(
		policy.allowed_loci(1) == [
			&"eyes",
			&"ears",
			&"fur",
			&"coat",
			&"tail",
		],
		"Stage 1 loci must match the locked policy"
	)

	_expect(
		policy.max_gene_items(1) == 1,
		"Stage 1 must allow exactly 1 Gene Item"
	)

	_expect(
		policy.allowed_loci(2) == [
			&"body",
			&"eyes",
			&"ears",
			&"whiskers",
			&"fur",
			&"coat",
			&"tail",
			&"paws",
			&"mane",
			&"mark",
		],
		"Stage 2 loci must match the locked policy"
	)

	_expect(
		policy.max_gene_items(2) == 2,
		"Stage 2 must allow exactly 2 Gene Items"
	)

	_expect(
		policy.allowed_loci(3)
		== PetGenomeSchema.visual_loci(),
		"Stage 3 must unlock all 12 visual loci"
	)

	_expect(
		policy.max_gene_items(3) == 3,
		"Stage 3 must allow exactly 3 Gene Items"
	)

	_expect(
		policy.allowed_loci(4).is_empty()
		and policy.max_gene_items(4) == 0,
		"Stage 4 must be phenotype-locked"
	)


func _test_stage_one(
	policy
) -> void:
	var disallowed = GeneDevelopmentStateScript.new(1)

	_expect(
		not bool(
			disallowed.try_apply(
				policy,
				&"gene_large_body",
				&"body",
				&"large",
				20.0
			).get("ok", false)
		),
		"Stage 1 must reject body Gene Items"
	)

	var state = GeneDevelopmentStateScript.new(1)
	var first := state.try_apply(
		policy,
		&"gene_moon_eyes",
		&"eyes",
		&"moon",
		20.0
	)

	_expect(
		bool(first.get("ok", false)),
		"Stage 1 must accept an allowed Gene Item"
	)

	_expect(
		state.application_count() == 1
		and state.remaining_slots(policy) == 0
		and is_equal_approx(
			state.influence(
				&"eyes",
				&"moon"
			),
			20.0
		),
		"Stage 1 Gene Item must create influence and consume its only slot"
	)

	_expect(
		not bool(
			state.try_apply(
				policy,
				&"gene_long_tail",
				&"tail",
				&"long",
				10.0
			).get("ok", false)
		),
		"Stage 1 must reject a second Gene Item"
	)


func _test_stage_two_reinforcement(
	policy
) -> void:
	var state = GeneDevelopmentStateScript.new(2)

	_expect(
		bool(
			state.try_apply(
				policy,
				&"gene_long_tail",
				&"tail",
				&"long",
				12.0
			).get("ok", false)
		),
		"Stage 2 first Gene Item must apply"
	)

	_expect(
		bool(
			state.try_apply(
				policy,
				&"gene_long_tail",
				&"tail",
				&"long",
				8.0
			).get("ok", false)
		),
		"Stage 2 must allow reinforcement with a second Gene Item"
	)

	_expect(
		is_equal_approx(
			state.influence(
				&"tail",
				&"long"
			),
			20.0
		),
		"same-direction Gene Items must accumulate influence"
	)

	_expect(
		state.application_count() == 2
		and state.is_full(policy),
		"Stage 2 must stop after 2 Gene Items"
	)


func _test_stage_three(
	policy
) -> void:
	var state = GeneDevelopmentStateScript.new(3)

	for gene_data in [
		[
			&"gene_horn",
			&"structure",
			&"horn",
			15.0,
		],
		[
			&"gene_dark_aura",
			&"aura",
			&"mist",
			18.0,
		],
		[
			&"gene_large_body",
			&"body",
			&"large",
			10.0,
		],
	]:
		_expect(
			bool(
				state.try_apply(
					policy,
					gene_data[0],
					gene_data[1],
					gene_data[2],
					gene_data[3]
				).get("ok", false)
			),
			"Stage 3 must accept all unlocked loci up to 3 items"
		)

	_expect(
		state.application_count() == 3
		and state.is_full(policy),
		"Stage 3 must stop after 3 Gene Items"
	)


func _test_stage_four(
	policy
) -> void:
	var state = GeneDevelopmentStateScript.new(4)

	_expect(
		state.is_full(policy),
		"Stage 4 must have no Gene Item slots"
	)

	_expect(
		not bool(
			state.try_apply(
				policy,
				&"gene_dark_aura",
				&"aura",
				&"mist",
				20.0
			).get("ok", false)
		),
		"Stage 4 must reject new Gene Items"
	)


func _test_round_trip(
	policy
) -> void:
	var original = GeneDevelopmentStateScript.new(2)

	original.try_apply(
		policy,
		&"gene_moon_mark",
		&"mark",
		&"moon",
		14.0
	)
	original.try_apply(
		policy,
		&"gene_moon_mark",
		&"mark",
		&"moon",
		6.0
	)

	var restored = GeneDevelopmentStateScript.from_dict(
		original.to_dict(),
		policy
	)

	_expect(
		restored != null
		and original.same_state(restored),
		"GeneDevelopmentState must survive save/load exactly"
	)


func _test_copy_safety(
	policy
) -> void:
	var state = GeneDevelopmentStateScript.new(1)

	state.try_apply(
		policy,
		&"gene_shadow_fur",
		&"fur",
		&"shadow",
		10.0
	)

	var influences := state.influences_snapshot()
	var fur := influences.get(
		"fur",
		{}
	) as Dictionary

	fur["shadow"] = 999.0
	influences["fur"] = fur

	_expect(
		is_equal_approx(
			state.influence(
				&"fur",
				&"shadow"
			),
			10.0
		),
		"influence snapshots must not expose internal state"
	)

	var applications := state.applications_snapshot()
	applications[0]["influence"] = 999.0

	_expect(
		is_equal_approx(
			float(
				state.applications_snapshot()[0].get(
					"influence",
					0.0
				)
			),
			10.0
		),
		"application snapshots must not expose internal state"
	)


func _expect(
	condition: bool,
	message: String
) -> void:
	if condition:
		return

	_failures += 1
	push_error(message)
