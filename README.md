# Pet Vô Hạn — Evolution Core

Godot Android portrait project.

## Current milestone

M3 introduces deterministic Evolution Rules.

```text
PetIdentity
    +
PetGenome
    +
Mutation data
    ↓
EvolutionDelta
    ↓
new PetGenome
```

Each M3 step changes exactly one trait and records exactly one new mutation.

Current separation:

- M1 PetIdentity = which individual this is;
- M2 PetGenome = what this individual currently looks/develops like;
- M3 Evolution Rules = which single controlled mutation happens next.

AI image generation is still deliberately outside the gameplay domain.

## Preserved baseline

- Egg incubation v1.1.
- Hatch and naming flow.
- Core save/random infrastructure.
- Side gameplay branches remain untouched.

## Test status

M1/M2/M3 include test scripts. Local Godot execution is deferred until later as requested.

See:
- `docs/evolution/M1_PET_IDENTITY.md`
- `docs/evolution/M2_PET_GENOME.md`
- `docs/evolution/M3_EVOLUTION_RULES.md`
