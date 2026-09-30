extends SceneTree

var _failures: int = 0

func _initialize() -> void:
	var policy := StageGenePolicy.load_default()
	_expect(policy != null, "StageGenePolicy must load")
	if policy != null:
		_test_stage_policy(policy)
		_test_stage_states(policy)
		_test_final_stage(policy)

	if _failures == 0:
		print("M9.2 Gene Foundation: PASS")
		quit(0)
		return
	push_error("M9.2 Gene Foundation: FAIL (%d)" % _failures)
	quit(1)


func _test_stage_policy(policy: StageGenePolicy) -> void:
	var stage_one: Array[StringName] = [&"eyes", &"whiskers", &"fur", &"mark", &"paws"]
	var stage_two: Array[StringName] = [&"body", &"ears", &"coat", &"tail", &"mane"]
	var stage_three: Array[StringName] = [&"structure", &"aura"]

	_expect(policy.allowed_loci(1) == stage_one and policy.max_gene_items(1) == 2,
		"Stage 1 must expose five small-detail loci and two Gene slots")
	_expect(policy.allowed_loci(2) == stage_two and policy.max_gene_items(2) == 2,
		"Stage 2 must expose five form loci and two Gene slots")
	_expect(policy.allowed_loci(3) == stage_three and policy.max_gene_items(3) == 2,
		"Stage 3 must expose structure+aura and two Gene slots")
	_expect(policy.allowed_loci(4).is_empty() and policy.max_gene_items(4) == 0,
		"Stage 4 must lock Gene Items")

	for locus in stage_one:
		_expect(policy.can_accept_gene(1, locus), "Stage 1 missing %s" % String(locus))
	for locus in stage_two:
		_expect(policy.can_accept_gene(2, locus), "Stage 2 missing %s" % String(locus))
	for locus in stage_three:
		_expect(policy.can_accept_gene(3, locus), "Stage 3 missing %s" % String(locus))

	_expect(not policy.can_accept_gene(1, &"tail"), "Stage 1 must reject Stage 2 tail locus")
	_expect(not policy.can_accept_gene(2, &"mark"), "Stage 2 must reject Stage 1 mark locus")
	_expect(not policy.can_accept_gene(3, &"body"), "Stage 3 must reject Stage 2 body locus")


func _test_stage_states(policy: StageGenePolicy) -> void:
	var s1 := GeneDevelopmentState.new(1)
	_expect(bool(s1.record_gene_item(policy, "s1_a", &"whiskers_starlight", &"whiskers", &"starlight", 20.0).get("ok", false)),
		"Stage 1 accepts whiskers")
	_expect(bool(s1.record_gene_item(policy, "s1_b", &"mark_moon", &"mark", &"moon", 20.0).get("ok", false)),
		"Stage 1 accepts mark")
	_expect(not bool(s1.record_gene_item(policy, "s1_c", &"eyes_moon", &"eyes", &"moon", 20.0).get("ok", false)),
		"Stage 1 enforces two-item cap")

	var s2 := GeneDevelopmentState.new(2)
	_expect(bool(s2.record_gene_item(policy, "s2_a", &"body_sturdy", &"body", &"sturdy", 20.0).get("ok", false)),
		"Stage 2 accepts body")
	_expect(bool(s2.record_gene_item(policy, "s2_b", &"mane_astral", &"mane", &"astral", 20.0).get("ok", false)),
		"Stage 2 accepts mane")
	_expect(not bool(s2.record_gene_item(policy, "s2_c", &"tail_long", &"tail", &"long", 20.0).get("ok", false)),
		"Stage 2 enforces two-item cap")

	var s3 := GeneDevelopmentState.new(3)
	_expect(bool(s3.record_gene_item(policy, "s3_a", &"structure_spirit", &"structure", &"spirit", 20.0).get("ok", false)),
		"Stage 3 accepts structure")
	_expect(bool(s3.record_gene_item(policy, "s3_b", &"aura_elemental", &"aura", &"elemental", 20.0).get("ok", false)),
		"Stage 3 accepts aura")
	_expect(not bool(s3.record_gene_item(policy, "s3_c", &"body_sturdy", &"body", &"sturdy", 20.0).get("ok", false)),
		"Stage 3 rejects non-advanced loci")


func _test_final_stage(policy: StageGenePolicy) -> void:
	var state := GeneDevelopmentState.new(4)
	_expect(not state.can_record(policy, &"aura"), "Stage 4 rejects Gene Items")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
