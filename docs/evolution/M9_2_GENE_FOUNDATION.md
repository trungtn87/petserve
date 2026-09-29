# M9.2 — Stage Gene Policy + Gene Development State

Status: merged to `pethome`; M9.2 foundation complete. Runtime Inventory/Stage 1 integration remains deferred to M9.3.

## Contract

M9.2 establishes the stage-scoped Gene foundation without changing Inventory or evolution rendering yet.

- Stage 1: eyes, ears, fur, coat, tail; max 1 Gene Item.
- Stage 2: Stage 1 loci + body, whiskers, paws, mane, mark; max 2 Gene Items.
- Stage 3: all 12 Genome V1 loci including structure and aura; max 3 Gene Items.
- Stage 4: no visual Gene Item intake.

`StageGenePolicy` is data-driven from `data/evolution/gene/stage_gene_policy.json` and validates the complete Stage 1–4 contract.

`GeneDevelopmentState` records only Gene Items consumed during the current Stage. It keeps item UID, gene id, locus, direction and influence, exposes aggregated keys such as `tail.long`, prevents duplicate item consumption, enforces the Stage cap through `StageGenePolicy`, and serializes independently from `PetGenome`.

The state resets when a new Stage begins. Expressed traits remain in `PetGenome`; a later Stage must consume new Gene Items to reinforce or redirect development. Invalid lifecycle stages and the `base` direction are rejected.

## Not included in M9.2

- generating real Gene Items;
- consuming Gene Items from Inventory;
- resolving Natural Growth vs Gene expression;
- changing `PetGenome`;
- AI prompt/render integration.

Those are later M9 steps.
