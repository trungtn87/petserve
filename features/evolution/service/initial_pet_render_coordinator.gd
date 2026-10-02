class_name InitialPetRenderCoordinator
extends Node


const ProxyPetRendererScript = preload(
	"res://features/evolution/render/proxy_pet_renderer.gd"
)
const PetSceneProfileFactoryScript = preload(
	"res://features/evolution/domain/pet_scene_profile_factory.gd"
)


var _render_service: PetRenderService


func _ready() -> void:
	_render_service = PetRenderService.new()
	add_child(_render_service)


func build_request(
	identity: PetIdentity,
	genome: PetGenome,
	scene_profile = null,
	mythic_destiny: Dictionary = {}
) -> Dictionary:
	var style := MythicStyleProfile.load_default()

	if style == null:
		return {
			"ok": false,
			"error": "Không load được MythicStyleProfile.",
		}

	if scene_profile == null:
		scene_profile = (
			PetSceneProfileFactoryScript.new()
			.create_initial(identity)
		)

	if scene_profile == null:
		return {
			"ok": false,
			"error": "Không tạo được PetHome Scene Profile.",
		}

	var species_catalog := InitialSpeciesCatalog.new()
	var species_profile := species_catalog.find_by_species(
		species_catalog.load_default(),
		identity.species()
	)

	if species_profile == null:
		return {
			"ok": false,
			"error": "Chưa có initial species profile cho %s."
			% String(identity.species()),
		}

	var spec := InitialPetVisualSpecBuilder.new().build(
		identity,
		genome,
		style,
		species_profile,
		scene_profile
	)

	if spec == null:
		return {
			"ok": false,
			"error": "Không tạo được InitialPetVisualSpec.",
		}

	var prompt_builder := InitialPetPromptBuilder.new()
	var positive_prompt := (
		prompt_builder.build_positive(
			spec
		)
	)

	if not mythic_destiny.is_empty():
		var destiny_service := SpeciesMythicDestinyService.new()
		var definition := destiny_service.definition_for(
			mythic_destiny,
			identity
		)

		if definition == null:
			return {
				"ok": false,
				"error": "Mythic Destiny ban đầu không hợp lệ.",
			}

		var mutation_hint := _stage_one_fantasy_hint(
			definition.id()
		)

		if not mutation_hint.is_empty():
			positive_prompt += (
				" Fantasy mutation: "
				+ mutation_hint
			)

	var request := PetRenderRequest.new()
	request.mode = (
		PetRenderRequest.RenderMode.INITIAL_TEXT_TO_IMAGE
	)
	request.pet_id = identity.pet_id()
	request.positive_prompt = positive_prompt
	request.negative_prompt = (
		prompt_builder.build_negative(spec)
	)
	request.seed = max(
		1,
		posmod(
			identity.lineage_seed(),
			2147483647
		)
	)
	request.output_key = (
		identity.pet_id()
		+ "_pethome_infant_v15_species_morphology"
	)

	if not request.is_valid():
		return {
			"ok": false,
			"error": "Initial PetHome render request không hợp lệ.",
		}

	return {
		"ok": true,
		"scene_profile": scene_profile,
		"spec": spec,
		"request": request,
	}


func render(
	request: PetRenderRequest
) -> PetRenderResult:
	var config := PetRenderConfig.load_default()

	if config == null:
		return PetRenderResult.fail(
			&"invalid_config",
			"Không load được proxy render config."
		)

	var renderer = ProxyPetRendererScript.new(
		config
	)

	_render_service.set_renderer(
		renderer
	)

	return await _render_service.render(
		request
	)


# Compatibility alias for the M5/M6 call site.
func render_initial(
	request: PetRenderRequest
) -> PetRenderResult:
	return await render(
		request
	)


func has_render_endpoint() -> bool:
	var config := PetRenderConfig.load_default()

	return (
		config != null
		and config.is_configured()
	)



func _stage_one_fantasy_hint(
	mutation_id: StringName
) -> String:
	var hints: Dictionary = {
		&"cat_horned_spirit": "tiny subtle spirit horn buds on the forehead.",
		&"cat_winged_spirit": "one small symmetrical pair of soft wing buds on the upper back.",
		&"dog_cerberus_guardian": "a barely visible guardian-shadow echo close to the shoulders; keep exactly one physical head.",
		&"dog_black_hound": "a faint shadow wake around the tail and slightly brighter supernatural eyes.",
		&"fox_kitsune": "a faint fox-fire wisp near the single tail and a tiny spirit-mask hint.",
		&"fox_spirit_oracle": "slightly elongated spirit ear tips and a subtle dreamlike eye glow.",
		&"bear_mountain_guardian": "slightly heavier shoulder fluff and subtly reinforced young paws.",
		&"bear_runic_ancestor": "one or two tiny ancestral rune flecks hidden in the coat.",
		&"rabbit_moon_hare": "a tiny moon-shaped ear accent and subtle lunar forehead hint.",
		&"rabbit_jade_horn": "a tiny central jade-colored horn bud, barely emerging.",
		&"lizard_dragonkin": "tiny paired horn ridges and a very small dorsal crest hint.",
		&"lizard_basilisk": "a subtle crown-crest hint and slightly more intense eyes.",
		&"bird_phoenix": "slightly brighter sacred wing edges and a tiny golden feather accent; remain an ordinary Bird lineage.",
		&"bird_thunder_roc": "slightly stronger crown feathers and a faint storm-like wing marking.",
		&"dragon_celestial": "a tiny elegant horn-crown hint and one faint cloudlike mane wisp.",
		&"dragon_abyss": "slightly denser shoulder scales and a restrained dark horn-ridge hint.",
		&"phoenix_sun": "a few warm luminous feather edges and one tiny rebirth-light wisp.",
		&"phoenix_void": "one faint eclipse-like feather mark and a cool subtle eye glow.",
		&"horse_celestial_steed": "a barely longer airy mane and a tiny luminous edge on the hooves.",
		&"horse_nightmare": "a faint shadow tint in the mane and slightly brighter supernatural eyes.",
		&"qilin_celestial": "a tiny sacred horn glow and one small cloudlike mane curl.",
		&"qilin_dread": "a slightly darker sacred scale patch and a firmer horn silhouette.",
		&"deer_worldtree_stag": "tiny symmetrical antler buds and one subtle woodland coat mark.",
		&"deer_moonveil": "tiny pale antler buds and a very soft moonlit eye sheen.",
	}

	return String(
		hints.get(
			mutation_id,
			""
		)
	)
