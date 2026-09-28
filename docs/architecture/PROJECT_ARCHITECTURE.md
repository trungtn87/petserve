# PetVerse — Project Architecture

Status: M0 clean baseline

## Principle

The application layer coordinates modules. Gameplay logic belongs to the feature/domain that owns it.

## M0 baseline

The retired pet presentation stack has been removed. The active runtime contains:

```text
res://
├── app/                 # startup and cross-feature routing
├── core/                # reusable infrastructure/services
├── data/                # egg/task configuration
├── egg/                 # egg view
├── features/
│   ├── egg/             # incubation domain + engines
│   └── hatch/           # hatch + naming
├── UI/                  # main screen/components/theme
├── scenes/
│   ├── main.tscn
│   └── evolution_initial.tscn
└── tools/               # generic project tooling only
```

## Removed legacy areas

M0 intentionally removes the old 3D, 2D/2.5D, Pet Home, pet expression, pet motion and direct pet-interaction implementations.

These implementations remain recoverable from Git history and the existing side branches. They are not dependencies of the new Evolution Core.

## Next architecture boundary

M1 may introduce a new evolution domain, but it must not depend on the retired presentation framework.

The intended dependency direction is:

```text
App / Screen
    ↓
Evolution service/facade
    ↓
Identity + genome + evolution rules
    ↓
Visual specification / renderer adapter
```

Presentation/rendering must not decide evolution rules.

## Main-file rule

Main/root scripts coordinate lifecycle and routing only. Domain rules must not be appended to MainScreen or GameApp.

## Stable baseline rule

Egg v1.1 and Hatch remain working baseline modules while Evolution Core is developed in isolated milestones.


## M1 domain

```text
features/evolution/
└── domain/
    ├── pet_identity.gd
    └── pet_identity_factory.gd
```

PetIdentity is the root of future Evolution Core data. Future Genome, EvolutionRule and VisualSpec layers may depend on identity, but identity must not depend on them.


## M2 genome domain

```text
features/evolution/
└── domain/
    ├── pet_identity.gd
    ├── pet_identity_factory.gd
    ├── pet_genome.gd
    └── pet_genome_factory.gd
```

Dependency boundary:

```text
PetIdentity   PetGenome
     \         /
      future Evolution Rules
             ↓
      future Visual Spec
```

PetGenome does not depend on renderer, UI, Pet Home, AI models, item systems or mutation probability logic.


## M3 evolution-rule layer

```text
features/evolution/
├── domain/
│   └── evolution_delta.gd
└── rules/
    ├── mutation_definition.gd
    ├── mutation_catalog.gd
    ├── evolution_rule_engine.gd
    └── genome_delta_applier.gd
```

Dependency direction:

```text
PetIdentity + PetGenome
          ↓
MutationDefinition data
          ↓
EvolutionRuleEngine
          ↓
EvolutionDelta
          ↓
GenomeDeltaApplier
          ↓
new PetGenome
```

The rule layer has no dependency on AI/image rendering, UI, Pet Home, chest/inventory or entertainment modules.


## M4 visual-spec layer

```text
features/evolution/visual/
├── pet_visual_spec.gd
├── mythic_style_profile.gd
├── mutation_visual_definition.gd
├── mutation_visual_catalog.gd
├── pet_visual_spec_builder.gd
└── pet_prompt_builder.gd
```

Dependency direction:

```text
Identity + Genome + EvolutionDelta
              ↓
      Visual definition data
              ↓
      PetVisualSpecBuilder
              ↓
        PetVisualSpec
              ↓
        PetPromptBuilder
              ↓
future renderer adapter
```

The visual layer may read evolution results but must never choose mutation probability, eligibility or gameplay outcomes. The active base style profile is Mythic Elemental Chibi; element lineage cues remain visual data.


## M5/M6 render boundary

```text
features/evolution/
├── render/
│   ├── pet_render_request.gd
│   ├── pet_render_result.gd
│   ├── pet_renderer.gd
│   ├── pet_render_config.gd
│   ├── pet_render_service.gd
│   ├── mock_pet_renderer.gd
│   └── openai_image_renderer.gd
├── persistence/
│   └── evolution_save_service.gd
├── service/
│   ├── evolution_bootstrap_service.gd
│   └── initial_pet_render_coordinator.gd
└── visual/
    ├── initial_pet_visual_spec.gd
    ├── initial_species_profile.gd
    ├── initial_species_catalog.gd
    ├── initial_pet_visual_spec_builder.gd
    └── initial_pet_prompt_builder.gd
```

Runtime flow:

```text
Egg/Hatch save
      ↓
EvolutionBootstrapService
      ↓
PetIdentity + initial PetGenome
      ↓
InitialPetVisualSpec
      ↓
INITIAL_TEXT_TO_IMAGE PetRenderRequest
      ↓
PetRenderer adapter
      ↓
PNG saved under user://pet_renders
      ↓
PetVisualRecord + evolution_pet_v1.json
      ↓
EvolutionInitialScreen
```

The initial request intentionally has no source image. Future evolution editing will reuse the same renderer contract with EVOLUTION_IMAGE_EDIT and the previous PetVisualRecord as source.
