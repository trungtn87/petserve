extends SceneTree

const PetIdentityFactoryScript = preload(
    "res://features/evolution/domain/pet_identity_factory.gd"
)
const PetGenomeFactoryScript = preload(
    "res://features/evolution/domain/pet_genome_factory.gd"
)
const PetSceneProfileFactoryScript = preload(
    "res://features/evolution/domain/pet_scene_profile_factory.gd"
)
const MythicStyleProfileScript = preload(
    "res://features/evolution/visual/mythic_style_profile.gd"
)
const InitialSpeciesCatalogScript = preload(
    "res://features/evolution/visual/initial_species_catalog.gd"
)
const InitialPetVisualSpecBuilderScript = preload(
    "res://features/evolution/visual/initial_pet_visual_spec_builder.gd"
)
const InitialPetPromptBuilderScript = preload(
    "res://features/evolution/visual/initial_pet_prompt_builder.gd"
)

func _initialize() -> void:
    var identity = PetIdentityFactoryScript.new().create_initial(
        7281,
        &"dark"
    )
    var genome = PetGenomeFactoryScript.new().create_initial()
    var scene_profile = PetSceneProfileFactoryScript.new().create_initial(identity)
    var style = MythicStyleProfileScript.load_default()
    var catalog = InitialSpeciesCatalogScript.new()
    var species = catalog.find_by_species(
        catalog.load_default(),
        &"cat"
    )
    var spec = InitialPetVisualSpecBuilderScript.new().build(
        identity,
        genome,
        style,
        species,
        scene_profile
    )
    if spec == null or not spec.is_valid():
        push_error("Could not build initial pet visual spec")
        quit(1)
        return

    var prompts = InitialPetPromptBuilderScript.new()
    var prompt: String = prompts.build_positive(spec)
    var payload := {
        "prompt": prompt,
        "width": 576,
        "height": 1024,
        "seed": 7281
    }

    var request_file := FileAccess.open(
        "/tmp/petverse_render_request.json",
        FileAccess.WRITE
    )
    if request_file == null:
        push_error("Could not open request output")
        quit(1)
        return
    request_file.store_string(JSON.stringify(payload))
    request_file.close()

    var prompt_file := FileAccess.open(
        "/tmp/petverse_prompt.txt",
        FileAccess.WRITE
    )
    if prompt_file != null:
        prompt_file.store_string(prompt)
        prompt_file.close()

    print("Prompt chars: ", prompt.length())
    quit(0)
