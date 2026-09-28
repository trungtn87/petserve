# Pet Content Pipeline

## Rule

New content of an existing kind should be added through definitions/assets, not identity checks in Core.

## Pet runtime contract

A pet may provide any subset of presentation capabilities. The host only requires a `PetDefinition` and a `PetActor` scene. Optional visual parts (ears, tail, FX, mouth, eyelids, etc.) belong to the concrete presentation scene.

Interaction is generic: `PetActor.tapped` is emitted by the actor and interpreted by behavior/state systems. Home screens do not need to know whether the actor is Dark, Fire, Water, or another pet.

## Reference pet milestone

Dark Pet is the first reference implementation. It validates:

1. definition-driven spawning
2. reusable home hosting
3. state-driven presentation
4. autonomous idle behavior
5. lightweight motion
6. touch/click reaction

Future pets should reuse this contract and replace presentation assets/configuration rather than adding element-specific branches to Core.

## Cat 2.5D production path

The shared rig, profiles, sample art pack, validation commands and future
element/stage workflow are documented in
[Cat 2.5D Framework](design/CAT_2_5D_FRAMEWORK.md).
