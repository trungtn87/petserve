# M2 — PetGenome

Status: implemented on `feat/evolution-m2-pet-genome`

## Purpose

M2 stores the current inheritable/visual evolution state of a pet without mixing that state into `PetIdentity`.

Identity answers:

> Which individual is this?

Genome answers:

> What has this individual currently developed into?

## Small V1 genome

M2 intentionally starts with very few fields:

```text
PetGenome
├── stage
├── body_growth
├── traits{}
└── mutations[]
```

### stage

Evolution form index. M2 only requires `stage >= 1`; it does not hard-code a maximum stage count.

### body_growth

A normalized visual-development value from `0.0 .. 1.0`.

This is not the Infant gameplay countdown/progress timer. It is a genome/visual value that future prompt/render layers may use to describe physical growth.

### traits

Open key/value visual channels.

Initial factory channels:

```text
fur  = base
eyes = base
ears = base
tail = base
mark = base
```

The dictionary is intentionally extensible. A later feature can add:

```text
horn = tiny_crescent
paw  = luminous
wing = none
```

without editing `PetGenome` core.

### mutations

Ordered unique mutation IDs accumulated by the current genome snapshot.

Example:

```text
[
    eye_glow,
    tail_starlight
]
```

M2 stores mutation IDs only. Mutation probability, compatibility, rarity and evolution selection belong to M3 rules.

## Separation from identity

`PetGenome` must not contain:

- pet_id
- species
- element
- lineage_seed
- generation

Those remain in `PetIdentity`.

This allows one individual to keep the same identity while its genome changes across many evolution steps.

## Snapshot rule

M2 treats a genome as a snapshot.

Public APIs return copied trait/mutation data so callers cannot silently mutate internal genome state.

M3 will be responsible for creating the next valid genome snapshot from a controlled evolution delta.

## Files

```text
features/evolution/domain/
├── pet_identity.gd
├── pet_identity_factory.gd
├── pet_genome.gd
└── pet_genome_factory.gd

tools/test_pet_genome.gd
```

## Pass criteria

1. Initial genome starts at stage 1 and body_growth 0.
2. Default visual channels are `base`.
3. Arbitrary future trait channels can be added without editing PetGenome.
4. Serialization round-trip preserves the genome exactly.
5. Returned trait/mutation collections cannot mutate internal state.
6. Invalid stage/growth/trait/mutation data is rejected.
7. Duplicate mutation IDs are rejected.
8. Identity fields are not embedded into genome data.
9. M0/M1 behavior is untouched.

## Deferred deliberately

M2 does not implement:

- mutation probability;
- evolution candidate selection;
- element compatibility;
- item influence;
- AI prompt generation;
- image rendering;
- Hatch integration.

Those belong to later milestones.

## Test note

Local Godot execution is intentionally deferred until the user is available to run the project.

When testing later:

```bash
godot --headless --path . --script res://tools/test_pet_genome.gd
```

Expected:

```text
M2 PetGenome: PASS
```
