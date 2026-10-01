# M7 — Evolution Image Edit + Lineage Continuity

## Goal

M7 turns the first rendered PetHome image into the visual source of truth for every later evolution.

The renderer must edit the previous complete PetHome portrait instead of generating a new unrelated pet from text.

```text
PetIdentity
+ previous PetGenome
+ deterministic EvolutionDelta
+ previous PetHome PNG
+ stable PetSceneProfile
        ↓
EvolutionEditCoordinator
        ↓
persisted EVOLUTION_IMAGE_EDIT request
        ↓
ProxyPetRenderer
        ↓
Cloudflare Worker /v1/render/evolution
        ↓
same pet + same world + one controlled mutation + next stage
```

## Locked rules

1. Code chooses the mutation before rendering.
2. One evolution advances exactly one stage.
3. The mutation snapshot itself does not change stage.
4. The previous PetHome image must belong to the same `pet_id`.
5. The previous image is mandatory and is sent as the image-edit source.
6. Only the mutation target region may introduce a new biological feature.
7. The PetHome world, camera, palette, lighting and UI-safe framing must be preserved.
8. The complete render request is persisted before the network request.
9. Retry restores the persisted request; it does not reroll mutation or rebuild a different prompt.
10. A successful decoded image is required before genome/stage/history commit.

## Architecture

New reusable boundary:

`features/evolution/service/evolution_edit_coordinator.gd`

It owns only the construction and persistence contract of an evolution image-edit request.

It does not choose mutation probability and does not write gameplay save state.

`InfantEvolutionService` remains responsible for the Stage 1 → 2 gameplay transaction and now delegates the visual request to this coordinator.

Future Stage 2 → 3 and Stage 3 → 4 flows must reuse the same coordinator rather than duplicate prompt/render logic.

## Stage semantics

M3 mutation remains a single-trait genome delta at the current stage.

M7 separately supplies the visual target stage to `PetVisualSpecBuilder`.

This removes the previous string replacement hack:

```text
"evolution stage 1" → replace → "evolution stage 2"
```

and makes stage intent explicit data.

## Retry/save contract

`pending_evolution.render_request` stores:

- mode;
- pet_id;
- positive prompt;
- negative prompt;
- source image path;
- target region;
- edit strength;
- output key.

Once persisted, retry restores these exact values.

Legacy pending plans created before M7 are still readable by `InfantEvolutionService.build_request()`.

## Provider contract

The existing proxy route is used:

`POST /v1/render/evolution`

The Godot client downsizes the previous PNG below 512 px before sending it as base64. The Worker forwards it to FLUX.2 Klein 4B as `input_image_0`.

No provider credential enters the gameplay/domain layers.

## Validation

Contract test:

`tools/test_m7_evolution_edit.tscn`

It verifies:

- EVOLUTION_IMAGE_EDIT mode;
- previous image is preserved as source;
- target region is preserved;
- target stage is explicit in the prompt;
- PetHome continuity instruction exists;
- serialize → restore produces the same request;
- stage skipping is rejected;
- an image from another pet is rejected.

Run:

```bash
godot --headless --path . tools/test_m7_evolution_edit.tscn
```

The existing infant integration suite must also remain green:

```bash
godot --headless --path . tools/test_infant_home.tscn
```

## M7 pass criteria

M7 code is complete when both contract suites pass.

End-to-end M7 is complete only after the deployed Worker route `/v1/render/evolution` is verified with a real Stage 1 → 2 render and the result is verified on Android.

The repository can implement and test the client/contract, but deployment/device verification is a separate runtime step.
