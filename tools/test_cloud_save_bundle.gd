extends SceneTree


const CloudSaveBundleScript = preload(
	"res://core/cloud/cloud_save_bundle.gd"
)


var _failures: int = 0


func _initialize() -> void:
	var fixture := {
		"schema": CloudSaveBundleScript.CURRENT_SCHEMA,
		"captured_at_unix": 123,
		"run": {
			"schema": 1,
			"cloud_test": "run",
		},
		"meta": {
			"schema": 4,
			"cloud_test": "meta",
		},
		"egg": {
			"cloud_test": "egg",
		},
		"hatch": {
			"cloud_test": "hatch",
		},
		"evolution": {
			"schema": 2,
			"cloud_test": "evolution",
		},
		"legacy": {
			"schema": 1,
			"inheritance_id": "cloud_test",
			"status": "pending",
			"cloud_test": "legacy",
		},
		"visual": {},
	}

	_expect(
		CloudSaveBundleScript.is_valid(
			fixture
		),
		"fixture snapshot must be valid"
	)

	_expect(
		CloudSaveBundleScript.restore(
			fixture
		),
		"fixture snapshot must restore to local persistence"
	)

	var captured := (
		CloudSaveBundleScript.capture()
	)

	_expect(
		String(
			captured["run"].get(
				"cloud_test",
				""
			)
		) == "run",
		"run save must round-trip"
	)
	_expect(
		String(
			captured["meta"].get(
				"cloud_test",
				""
			)
		) == "meta",
		"meta save must round-trip"
	)
	_expect(
		String(
			captured["egg"].get(
				"cloud_test",
				""
			)
		) == "egg",
		"egg save must round-trip"
	)
	_expect(
		String(
			captured["hatch"].get(
				"cloud_test",
				""
			)
		) == "hatch",
		"hatch save must round-trip"
	)
	_expect(
		String(
			captured["evolution"].get(
				"cloud_test",
				""
			)
		) == "evolution",
		"evolution save must round-trip"
	)
	_expect(
		String(
			captured["legacy"].get(
				"cloud_test",
				""
			)
		) == "legacy",
		"legacy save must round-trip"
	)

	_expect(
		CloudSaveBundleScript.has_game_data(
			captured
		),
		"captured fixture must contain game data"
	)

	_expect(
		CloudSaveBundleScript.restore(
			CloudSaveBundleScript.empty_snapshot()
		),
		"empty snapshot must clear local persistence"
	)

	var cleared := (
		CloudSaveBundleScript.capture()
	)

	_expect(
		not CloudSaveBundleScript.has_game_data(
			cleared
		),
		"all local save domains must be empty after clear"
	)

	_finish()


func _expect(
	condition: bool,
	message: String
) -> void:
	if condition:
		print(
			"PASS: ",
			message
		)
		return

	_failures += 1
	push_error(
		"FAIL: " + message
	)


func _finish() -> void:
	if _failures > 0:
		quit(1)
		return

	print(
		"Cloud save bundle test passed."
	)
	quit(0)
