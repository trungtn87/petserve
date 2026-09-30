# Stage 2 — Species Mythic Mutation Foundation

## Goal

Mythic Mutation is a species-exclusive rare branch. It is separate from normal Gene Item expression.

The code decides the branch first. AI rendering is only allowed to visualize the selected branch.

## Locked rules

- Each species may define one or two Mythic Mutation branches.
- Mythic Mutation does not consume the Stage Gene Item cap.
- A pet may carry at most one Mythic Mutation branch.
- The branch is keyed by PetIdentity.species.
- A branch that awakens at Stage 3 is persisted in PetGenome.mutations and continues to Stage 4 without rerolling.
- Normal Gene traits remain unchanged when the Mythic branch id is attached.
- Mythic definitions may read existing phenotype requirements and Gene influence tags as data-driven eligibility/weight inputs.
- A species cannot activate another species' mutation.
- AI must not invent an undefined combined mythical form.

## Current cat data

The current implemented species is cat.

Two branches are reserved:

1. cat_nekomata
2. cat_bakeneko

Both have Stage 3 and Stage 4 visual instructions.

Their activation_basis_points are intentionally 0 in the default data. Rarity/balance has not been approved yet, so the live game must not silently start rolling Mythic Mutation.

## Activation model

When balance is configured later:

1. Filter definitions by PetIdentity.species.
2. Filter by target stage and required phenotype traits.
3. Calculate each candidate's basis points from its data value plus optional Gene tag affinity.
4. Use a lineage-stable deterministic roll.
5. Select at most one branch.
6. Persist that branch id in PetGenome.mutations.
7. Future stages continue the same branch without rerolling.

Reloading the same evolution attempt therefore cannot reroll a better mythical result.

## Integration boundary

SpeciesMythicMutationResolver is intentionally separate from StageEvolutionResolver.

Before activation rates are enabled, StageEvolutionService still needs the dedicated render-plan integration that can safely combine:

- normal Stage 2 Gene result(s),
- one optional species Mythic Mutation branch,
- identity/anatomy preservation,
- one persisted retry-safe evolution plan.

This prevents a mutation id from being committed before the image renderer has been given the same code-selected mutation plan.
