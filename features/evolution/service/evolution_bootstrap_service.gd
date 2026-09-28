class_name EvolutionBootstrapService
extends RefCounted


const PetSceneProfileFactoryScript = preload(
	"res://features/evolution/domain/pet_scene_profile_factory.gd"
)


func build_from_hatch() -> Dictionary:
	var egg_data := SaveService.new().load_game()
	var hatch_data := HatchSaveService.new().load_data()

	if egg_data.is_empty() or hatch_data.is_empty():
		return {
			"ok": false,
			"error": "Không tìm thấy dữ liệu Egg/Hatch.",
		}

	var egg_state := EggState.from_save_dict(
		egg_data
	)
	var hatch_state := HatchState.from_save_dict(
		hatch_data
	)

	if (
		egg_state == null
		or hatch_state == null
		or not egg_state.has_active_run()
		or not hatch_state.is_valid()
	):
		return {
			"ok": false,
			"error": "Dữ liệu Egg/Hatch không hợp lệ.",
		}

	if egg_state.run_seed != hatch_state.run_seed:
		return {
			"ok": false,
			"error": "Egg và Hatch không cùng run.",
		}

	if not hatch_state.name_confirmed:
		return {
			"ok": false,
			"error": "Pet chưa xác nhận tên.",
		}

	var identity := PetIdentityFactory.new().create_initial(
		egg_state.run_seed,
		StringName(egg_state.egg_type),
		&"cat"
	)

	var genome := PetGenomeFactory.new().create_initial()

	if identity == null or genome == null:
		return {
			"ok": false,
			"error": "Không tạo được Identity/Genome ban đầu.",
		}

	var scene_profile = (
		PetSceneProfileFactoryScript.new()
		.create_initial(identity)
	)

	if scene_profile == null:
		return {
			"ok": false,
			"error": "Không tạo được PetHome Scene Profile từ M1.",
		}

	return {
		"ok": true,
		"identity": identity,
		"genome": genome,
		"scene_profile": scene_profile,
		"pet_name": hatch_state.pet_name,
	}
