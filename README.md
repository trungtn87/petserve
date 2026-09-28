# Pet Vô Hạn — Evolution Core

Godot Android portrait project.

## Current milestone

M2 adds `PetGenome`, the mutable-by-evolution state that is kept separate from the stable `PetIdentity`.

Current Evolution Core:

```text
PetIdentity  = which individual this is
PetGenome    = what this individual has developed into
```

M2 genome intentionally stays small:

- stage;
- body_growth;
- extensible visual traits;
- mutation IDs.

No AI rendering, mutation probability or evolution rules are implemented yet.

## Preserved baseline

- Core infrastructure and local save/load.
- Egg incubation v1.1.
- Hatch and naming flow.
- Main UI and Android project configuration.
- Independent feature branches remain untouched.

## Test status

M1/M2 include headless test scripts, but local Godot execution is deferred and will be run later on the user's machine.

See:
- `docs/evolution/M1_PET_IDENTITY.md`
- `docs/evolution/M2_PET_GENOME.md`
