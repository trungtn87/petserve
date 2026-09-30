# M9.3 — Gene Definition + Real Gene Item + Inventory

Status: implementation milestone.

## Contract

M9.3 turns the M9.2 Gene foundation into a real inventory item flow without resolving phenotype yet.

- Gene definitions are data-driven.
- A Gene Item has one primary visual direction and optional hidden influence tags.
- Stage 1 starts with ten reference Gene definitions across the five unlocked loci.
- Inventory can expose Gene Items only when the current Stage policy allows their locus.
- Consuming a Gene Item records influence in GeneDevelopmentState, adds 5% Growth for the current Stage, and removes that item from Inventory.
- Gene Item Growth is stage-relative (5% of the current Stage requirement), so the effect remains meaningful in Stage 1–3.
- A hibernating pet cannot consume a Gene Item; feeding must wake the pet first.
- Consuming a Gene Item does not mutate PetGenome/phenotype immediately.
- Stage caps remain 1 / 2 / 3 / 0 Gene Items.
- GeneDevelopmentState resets on the next Stage; expressed phenotype will remain in PetGenome after the future resolver is implemented.

## Diversity rule

The lifetime cap is six Gene Items total across Stage 1–3. That does not mean only six possible forms. A Gene can be reinforced or redirected in later stages, and each item also carries influence tags that can affect future weighted resolution.

## Deferred

- Chest loot tables for Gene Items.
- Natural Growth vs Gene expression resolver.
- Applying expressed traits to PetGenome.
- AI prompt/render changes.
