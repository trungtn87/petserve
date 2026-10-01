# Species Mythic Mutation + Mythic Destiny

## Goal

Mythic evolution is a species-exclusive branch layered on top of the scored Gene system.

Code decides the Mythic branch before rendering. AI only visualizes the locked Gene-score phenotype and Mythic plan.

## Locked rules

- Each species may define one or more Mythic branches.
- A pet may carry at most one Mythic branch.
- Mythic identity is keyed by `PetIdentity.species`.
- Gene Items are unlimited during growth Stages 1-3; Mythic does not consume a Gene slot because Gene slots no longer exist.
- Mythic recipes use required Gene **loci**, not one exact item ID. Different Gene directions can therefore satisfy the same anatomical recipe.
- Element-locked `mark` and `aura` Genes still must match the current pet element when consumed.
- Normal Gene scores remain canonical and continue to accumulate independently by `locus.direction`.
- AI must not invent another Mythic creature, mix branches, or reroll a locked destiny.
- An active Mythic branch continues through later stages without another selection.

## Two Mythic entry paths

### A. Rare Egg Stage 4

Egg Stage 4 can lock one species-compatible Mythic Destiny deterministically from lineage seed. The destiny is persisted and reused on retry.

Visible Mythic expression follows the branch data. Current cat branches first awaken at live Stage 3 and complete at Stage 4.

### B. Locus recipe from accumulated Genes

The lifetime Gene ledger keeps every distinct consumed Gene ID even when current-stage Gene inputs are reset after evolution. `SpeciesMythicDestinyService` maps those IDs back to their Gene definitions and checks the required loci.

Current cat recipes:

- **Giác Linh Miêu**: `whiskers + mark + ears`
- **Dực Linh Miêu**: `fur + body + mane`

The three contributing Genes do not need to be consumed in the same stage and their rarity does not change whether the recipe is complete. Rarity changes score strength; recipe completion is locus-based.

Example for a Dark cat:

```text
whiskers_starlight + mark_dark + ears_tufted
=> loci whiskers + mark + ears
=> lock cat_horned_spirit
```

The old `mark_moon` fixture is retired. Element effects now use `mark_<element>` / `aura_<element>`.

## Current cat branches

### Giác Linh Miêu — `cat_horned_spirit`

- Required loci: `whiskers, mark, ears`
- First visible Mythic expression: Stage 3
- Final expression: Stage 4
- Stage 3: small symmetrical spirit horns integrated with the established whiskers/mark/ear development.
- Stage 4: mature horns + controlled elemental aura.

### Dực Linh Miêu — `cat_winged_spirit`

- Required loci: `fur, body, mane`
- First visible Mythic expression: Stage 3
- Final expression: Stage 4
- Stage 3: compact fantasy wings integrated with the established fur/body/mane development.
- Stage 4: mature wings + controlled elemental aura.

Default `activation_basis_points = 0`, so there is no extra arbitrary random Mythic roll in the current live definitions.

## Retry-safe evolution contract

The pending evolution plan persists:

- current-stage Gene deltas,
- accumulated Gene IDs,
- lifetime Gene scores,
- lifetime hidden tag influence,
- generated Gene-score prompt,
- Mythic Destiny and resolution,
- target Genome,
- source/target phenotype,
- serialized render request and stable seed.

A renderer failure does not reroll Gene direction, Mythic branch or seed.

## Relation to the scored Gene system

Current-stage Gene Items still determine the structural `EvolutionDelta` used for that transition. Lifetime scores are separate and survive stage reset.

This separation prevents a Gene consumed in Stage 1 from being applied again automatically as a new delta in Stage 2, while still allowing its accumulated score to keep influencing later visual prompts.

The authoritative scored-item design is documented in `docs/gameplay/STAGE2_GENE_SCORE_ITEM_SYSTEM.md`.
