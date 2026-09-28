# PetVerse — Design Decisions

This file records decisions that should not be casually reopened during implementation.

## EVO-000 — M0 removes the retired pet presentation stack
The previous 3D, 2D/2.5D, Pet Home, expression, motion and direct pet-interaction implementations are not part of the new baseline.

## EVO-001 — Evolution is the core direction
The next gameplay foundation is pet evolution, not a simulation-heavy pet-care runtime.

## EVO-002 — A pet must preserve lineage
Future visual forms must develop from the same individual pet rather than being independently regenerated as unrelated characters.

## EVO-003 — Code decides evolution
Evolution identity, genome and mutation changes are decided by deterministic/domain code. A renderer may visualize those decisions but must not invent the evolution rules.

## EVO-004 — Small controlled deltas
Evolution should be developed as a sequence of small controlled changes. New mutation types should primarily be data additions once the rule system is stable.

## EVO-005 — Galaxy visual direction
The target visual family is Galaxy Fantasy Chibi. Style constraints belong in the future visual-spec layer, not in gameplay rules.

## ARCH-001 — Main coordinates only
Main/root code remains orchestration-focused.

## ARCH-002 — Stable milestone development
Each layer is completed and tested before the next layer is added.

## ARCH-003 — Preserve Egg v1.1 during Evolution Core work
Egg incubation, hatch and naming remain baseline behavior until an evolution replacement explicitly changes that flow.

## ARCH-004 — Side branches are historical/experimental references
M0 cleanup must not rewrite or delete existing side branches.


## EVO-006 — PetIdentity is immutable across evolution
A single pet life keeps the same pet_id, species, element, lineage_seed and generation through every later growth/evolution visual change. Stage, genome mutations and rendered images must not be stored as identity fields.

## EVO-007 — Identity is deterministic
The same species + element + lineage_seed + generation must produce the same pet_id. Identity generation must not depend on AI output or image content.


## EVO-008 — Genome is separate from identity
Stage, body growth, visual traits and mutation IDs belong to PetGenome, never PetIdentity.

## EVO-009 — Genome starts small and extensible
The V1 genome exposes only stage, body_growth, an open trait map and mutation IDs. New visual channels should be added as trait data rather than new core fields unless a future capability genuinely requires a typed field.

## EVO-010 — Genome is a snapshot
PetGenome does not expose mutable internal collections. A later evolution service creates a new validated genome snapshot instead of letting arbitrary UI/render code mutate the current genome in place.

## EVO-011 — M2 contains no evolution probability
Mutation rarity, compatibility, item influence and next-evolution selection are explicitly deferred to the Evolution Rules milestone.
