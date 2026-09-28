# Pet Vô Hạn — Evolution Core

Godot Android portrait project.

## Current milestone

M4 adds a renderer-neutral Galaxy visual specification and prompt builder.

```text
M1 PetIdentity
        +
M2 PetGenome
        +
M3 EvolutionDelta
        ↓
M4 PetVisualSpec
        ↓
fixed Galaxy prompt contract
```

M4 still does not call an AI image model.

It guarantees that the future renderer is instructed to:
- keep the same individual pet;
- keep the Galaxy Fantasy Chibi art family;
- apply only one M3 mutation;
- preserve unrelated traits;
- use restrained edit strength.

Gameplay mutation rules and visual prompt wording remain separate data layers.

## Test status

M1–M4 include headless tests. Local execution is deferred until later as requested.

See:
- `docs/evolution/M1_PET_IDENTITY.md`
- `docs/evolution/M2_PET_GENOME.md`
- `docs/evolution/M3_EVOLUTION_RULES.md`
- `docs/evolution/M4_VISUAL_SPEC.md`
