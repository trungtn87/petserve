# M4 — Visual Spec + Galaxy Prompt

Status: implemented on `feat/evolution-m4-visual-spec`

## Purpose

M4 translates one validated M3 evolution change into a renderer-neutral visual instruction.

M4 does **not** call an AI model.

Its job is to make sure a future image editor receives a strict contract:

```text
same pet
+
same established appearance
+
Galaxy Fantasy Chibi style
+
ONE requested visual change
```

## Flow

```text
PetIdentity
+
previous PetGenome
+
next PetGenome
+
EvolutionDelta
+
GalaxyStyleProfile
+
MutationVisualDefinition
        ↓
PetVisualSpecBuilder
        ↓
PetVisualSpec
        ↓
PetPromptBuilder
        ↓
positive prompt
negative prompt
target region
edit strength
```

The future renderer will consume the spec together with the previous pet image.

## Galaxy style contract

M4 locks one initial art family:

```text
galaxy_fantasy_chibi_v1
```

Core characteristics:

- same individual character identity;
- cute compact chibi proportions;
- large expressive eyes;
- soft fluffy fur;
- clean readable silhouette;
- premium mobile-game character quality;
- soft nebula gradients;
- restrained star details;
- elegant celestial glow;
- element-specific galaxy accents.

Galaxy is intentionally restrained. The style profile explicitly rejects noisy star texture covering the whole body.

## Seven element accents

The shared Galaxy family has seven accent directions:

- metal: silver / cool violet / cyan;
- wood: emerald / teal / violet;
- water: sapphire / cyan / violet;
- fire: crimson / magenta / amber / gold;
- earth: umber / amber / violet / crystal;
- dark: indigo / violet / blue-black / cold cyan;
- light: pearl white / pale gold / cyan / violet.

This creates seven recognizable base families without turning them into unrelated art styles.

## Visual mutation data is separate from gameplay mutation data

M3 owns gameplay semantics:

```text
tail_long_fluffy
target_trait = tail
base -> long_fluffy
weight = 10
```

M4 separately owns how that change should be drawn:

```text
mutation_id = tail_long_fluffy
target_region = tail
instruction = make the same tail moderately longer and fuller...
edit_strength = 0.24
```

This separation is intentional.

Changing art wording later must not change gameplay probability or evolution logic.

## One-change validation

Before a visual spec is produced, M4 verifies:

1. previous and next genome have the same stage;
2. body growth did not silently change;
3. delta source/target traits match both genomes;
4. no non-target trait changed;
5. mutation history is previous history + exactly one new mutation;
6. visual definition matches the same mutation ID;
7. visual target region matches the M3 target trait.

If any of these fail, no visual spec is produced.

This is the main guard against AI prompt drift being caused by bad game data.

## Prompt structure

The positive prompt has stable sections:

```text
[IDENTITY LOCK]
...

[GALAXY STYLE]
...

[CURRENT FORM]
...

[CHANGE ONLY]
...

[PRESERVE]
...
```

The negative prompt is separate.

No model/vendor syntax is embedded in this layer.

## Edit strength

Every initial mutation has a restrained normalized edit-strength hint.

Current values are approximately:

```text
0.13 .. 0.24
```

A future renderer adapter may map that abstract value to the selected model's actual denoise/edit parameter.

M4 itself does not assume how a specific model represents image-edit strength.

## Files

```text
features/evolution/visual/
├── pet_visual_spec.gd
├── galaxy_style_profile.gd
├── mutation_visual_definition.gd
├── mutation_visual_catalog.gd
├── pet_visual_spec_builder.gd
└── pet_prompt_builder.gd

data/evolution/visual/
├── galaxy_style.json
└── mutation_visuals.json

tools/test_visual_spec.gd
```

## Example

Input:

```text
pet_id = cat_dark_7281_g0

previous:
eyes = base

delta:
galaxy_eye_ring
eyes: base -> galaxy_ring

next:
eyes = galaxy_ring
```

M4 produces a spec conceptually like:

```text
STYLE
Galaxy Fantasy Chibi
Dark accent: indigo + violet + cold cyan

IDENTITY
same individual cat

CHANGE ONLY
eyes:
add thin luminous galaxy rings inside the existing irises

PRESERVE
face, eye placement, ears, tail, fur, mark and all unrelated anatomy

TARGET REGION
eyes

EDIT STRENGTH
0.18
```

The future AI renderer will edit the **previous pet image**, not generate a replacement pet from text alone.

## Test note

Local Godot execution remains deferred as requested.

Later:

```bash
godot --headless --path . --script res://tools/test_visual_spec.gd
```

Expected:

```text
M4 Visual Spec: PASS
```

Potential parser/runtime issues found later should be fixed without weakening the M4 contracts.
