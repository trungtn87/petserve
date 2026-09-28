# M3 — Evolution Rules

Status: implemented on `feat/evolution-m3-rules`

## Purpose

M3 is the first milestone that can decide one concrete evolution mutation and turn an old genome snapshot into a new genome snapshot.

The rule is intentionally strict:

> One evolution step changes one trait and records one mutation ID.

M3 does not generate images. It produces the exact structured change that a later prompt/renderer layer will visualize.

## Flow

```text
PetIdentity
+
PetGenome
+
MutationCatalog
      ↓
EvolutionRuleEngine
      ↓
EvolutionDelta
      ↓
GenomeDeltaApplier
      ↓
NEW PetGenome
```

The original PetIdentity and original PetGenome remain unchanged.

## MutationDefinition

A mutation definition is data, not an element-specific branch in Core.

Current fields:

```text
id
target_trait
required_trait
result_trait
min_stage
max_stage
weight
allowed_species[]
allowed_elements[]
conflicts[]
```

Example:

```json
{
  "id": "tail_long_fluffy",
  "target_trait": "tail",
  "required_trait": "base",
  "result_trait": "long_fluffy",
  "min_stage": 1,
  "weight": 10
}
```

A later mutation can build on it:

```json
{
  "id": "tail_twin_tip",
  "target_trait": "tail",
  "required_trait": "long_fluffy",
  "result_trait": "twin_tip",
  "min_stage": 2,
  "weight": 4
}
```

This creates a real development chain instead of independently replacing the pet.

## Deterministic choice

The selection RNG is seeded only from stable game data:

- lineage seed;
- generation;
- current stage;
- mutation count;
- mutation history.

The candidate list is sorted before weighted selection.

Therefore the same identity + same genome + same mutation catalog produces the same next mutation.

AI is not involved in the decision.

## Initial mutation catalog

M3 includes a small semantic mutation catalog. Some internal IDs retain early Galaxy-era names such as `galaxy_eye_ring`, `nebula_fur_speckles` and `starlight_whiskers`.

Those IDs are gameplay identifiers only. They do not dictate final art direction.

M4 currently interprets them under the Mythic Elemental Chibi style while keeping the IDs stable so the completed rule layer does not change for a visual-only revision.

## Anti-repeat behavior

A mutation ID already present in the current genome is not eligible again.

This guarantees:

> The same pet cannot receive the exact same mutation twice.

It does **not** yet guarantee global uniqueness between every pet in the game. A future evolution-signature registry will be needed if absolute cross-player/cross-run uniqueness is required.

## One-small-change rule

M3 delta contains only:

```text
mutation_id
target_trait
from_trait
to_trait
step_index
```

Applying it:

- does not change PetIdentity;
- does not change stage;
- does not change body_growth;
- changes one trait;
- appends one mutation ID.

Stage advancement and growth progression remain separate systems.

## Files

```text
features/evolution/
├── domain/
│   ├── pet_identity.gd
│   ├── pet_genome.gd
│   └── evolution_delta.gd
└── rules/
    ├── mutation_definition.gd
    ├── mutation_catalog.gd
    ├── evolution_rule_engine.gd
    └── genome_delta_applier.gd

data/evolution/mutations/base_mutations.json
tools/test_evolution_rules.gd
```

## Pass criteria

1. Mutation data loads without duplicate IDs.
2. Same identity + same genome chooses the same mutation.
3. Incompatible stage/species/element/conflict rules are rejected.
4. One step changes exactly one trait.
5. One step appends exactly one mutation ID.
6. Existing mutation IDs cannot repeat.
7. Trait chains can require a previous form.
8. Old genome snapshot remains unchanged.
9. M0/M1/M2 modules are not rewritten.
10. No AI/render/PetHome dependency is introduced.

## Test note

Local Godot execution is deferred as requested.

Later command:

```bash
godot --headless --path . --script res://tools/test_evolution_rules.gd
```

Expected:

```text
M3 Evolution Rules: PASS
```

Any parser/runtime issue found later should be fixed on top of M3 without changing the locked domain meaning.
