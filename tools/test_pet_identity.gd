extends SceneTree


const PetIdentityScript = preload(
	"res://features/evolution/domain/pet_identity.gd"
)

const PetIdentityFactoryScript = preload(
	"res://features/evolution/domain/pet_identity_factory.gd"
)


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
	_test_all_base_elements()
	_test_deterministic_id()
	_test_different_seed_changes_id()
	_test_different_element_changes_id()
	_test_round_trip()
	_test_invalid_input()

	if _failures == 0:
		print("M1 PetIdentity: PASS")
		quit(0)
		return

	push_error(
		"M1 PetIdentity: FAIL (%d)" % _failures
	)
	quit(1)


func _test_all_base_elements() -> void:
	var factory = PetIdentityFactoryScript.new()

	for element in ELEMENTS:
		var identity = factory.create_initial(
			7281,
			element
		)

		_expect(
			identity != null and identity.is_valid(),
			"base element must create valid identity: %s"
			% String(element)
		)


func _test_deterministic_id() -> void:
	var factory = PetIdentityFactoryScript.new()

	var a = factory.create_initial(7281, &"dark")
	var b = factory.create_initial(7281, &"dark")

	_expect(
		a != null
		and b != null
		and a.pet_id() == b.pet_id(),
		"same inputs must create same pet_id"
	)


func _test_different_seed_changes_id() -> void:
	var factory = PetIdentityFactoryScript.new()

	var a = factory.create_initial(7281, &"dark")
	var b = factory.create_initial(7282, &"dark")

	_expect(
		a != null
		and b != null
		and a.pet_id() != b.pet_id(),
		"different lineage seed must create different pet_id"
	)


func _test_different_element_changes_id() -> void:
	var factory = PetIdentityFactoryScript.new()

	var a = factory.create_initial(7281, &"dark")
	var b = factory.create_initial(7281, &"fire")

	_expect(
		a != null
		and b != null
		and a.pet_id() != b.pet_id(),
		"different element must create different pet_id"
	)


func _test_round_trip() -> void:
	var factory = PetIdentityFactoryScript.new()
	var original = factory.create_initial(7281, &"dark")

	var restored = PetIdentityScript.from_dict(
		original.to_dict()
	)

	_expect(
		restored != null
		and original.same_identity(restored),
		"serialize/deserialize must preserve identity exactly"
	)


func _test_invalid_input() -> void:
	var factory = PetIdentityFactoryScript.new()

	_expect(
		factory.create_initial(0, &"dark") == null,
		"zero lineage seed must be rejected"
	)

	_expect(
		factory.create_initial(7281, &"") == null,
		"empty element must be rejected"
	)

	_expect(
		factory.create(
			7281,
			&"dark",
			&"cat",
			-1
		) == null,
		"negative generation must be rejected"
	)


func _expect(
	condition: bool,
	message: String
) -> void:
	if condition:
		return

	_failures += 1
	push_error(message)
