extends SceneTree


const ELEMENTS: Array[StringName] = [
	&"metal",
	&"wood",
	&"water",
	&"fire",
	&"earth",
	&"dark",
	&"light",
]


var _failures: int = 0


func _initialize() -> void:
	_test_all_elements()
	_test_deterministic_profile()
	_test_different_seed_changes_scene_seed()
	_test_round_trip()

	if _failures == 0:
		print("M1 PetSceneProfile: PASS")
		quit(0)
		return

	push_error(
		"M1 PetSceneProfile: FAIL (%d)" % _failures
	)
	quit(1)


func _test_all_elements() -> void:
	var identity_factory := PetIdentityFactory.new()
	var scene_factory := PetSceneProfileFactory.new()

	for element in ELEMENTS:
		var identity := identity_factory.create_initial(
			7281,
			element
		)
		var profile := scene_factory.create_initial(
			identity
		)

		_expect(
			profile != null
			and profile.is_valid()
			and profile.element == element,
			"scene profile must be valid for %s"
			% String(element)
		)


func _test_deterministic_profile() -> void:
	var identity := (
		PetIdentityFactory.new()
		.create_initial(7281, &"dark")
	)
	var factory := PetSceneProfileFactory.new()

	var a := factory.create_initial(identity)
	var b := factory.create_initial(identity)

	_expect(
		a != null
		and b != null
		and a.same_profile(b),
		"same pet life must create the same scene profile"
	)


func _test_different_seed_changes_scene_seed() -> void:
	var identity_factory := PetIdentityFactory.new()
	var scene_factory := PetSceneProfileFactory.new()

	var a := scene_factory.create_initial(
		identity_factory.create_initial(
			7281,
			&"dark"
		)
	)
	var b := scene_factory.create_initial(
		identity_factory.create_initial(
			7282,
			&"dark"
		)
	)

	_expect(
		a != null
		and b != null
		and a.scene_seed != b.scene_seed,
		"different pet lives must have different scene seeds"
	)


func _test_round_trip() -> void:
	var identity := (
		PetIdentityFactory.new()
		.create_initial(7281, &"dark")
	)
	var original := (
		PetSceneProfileFactory.new()
		.create_initial(identity)
	)
	var restored := PetSceneProfile.from_dict(
		original.to_dict()
	)

	_expect(
		restored != null
		and original.same_profile(restored),
		"scene profile serialization must round-trip exactly"
	)


func _expect(
	condition: bool,
	message: String
) -> void:
	if condition:
		return

	_failures += 1
	push_error(message)
