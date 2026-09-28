# Pet Vô Hạn — Evolution Core

Godot Android portrait project.

## Current milestone

M1 introduces the first Evolution Core domain object: `PetIdentity`.

Stable identity contains only:
- pet id;
- species;
- element;
- lineage seed;
- generation.

It deliberately contains no visual, stage, mutation or AI-render data.

## Preserved baseline

- Core infrastructure and local save/load.
- Egg incubation v1.1.
- Hatch and naming flow.
- Main UI and Android project configuration.
- Independent feature branches remain untouched.

## Retired from the active baseline

- 3D pet runtime.
- 2D/2.5D pet presentation runtime.
- Pet idle/expression/motion/interaction systems.
- Old Pet Home runtime.

See `docs/evolution/M1_PET_IDENTITY.md` for the M1 contract and test.
