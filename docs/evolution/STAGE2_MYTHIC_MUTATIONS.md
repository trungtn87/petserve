# Species Mythic Mutation + Mythic Destiny

## Goal

Mythic evolution is a species-exclusive branch layered on top of the normal Gene system.

Code always decides the mythical branch first. AI rendering only visualizes the already locked Gene + Mythic evolution plan.

## Locked rules

- Each species may define one or two Mythic branches.
- A pet may carry at most one Mythic branch.
- Mythic identity is keyed by `PetIdentity.species`.
- Mythic development does not consume the normal per-stage Gene Item cap.
- Normal Gene traits remain canonical and are resolved independently by locus.
- AI must not invent another mythical creature, mix two Mythic branches, or reroll the branch.
- A Mythic branch that is already active continues through later stages without another selection.
- The mythical beast name is stored as Mythic Destiny and shown in PetHome info when known.

## Two Mythic entry paths

### A. Rare Stage 4 egg

The existing egg system already owns the low rate of opening Egg Stage 4. Reaching Egg Stage 4 itself is the Mythic trigger; Mythic Destiny does not require a second mutation flag or a second rarity roll.

At hatch:

```text
Rare Egg Stage 4
        ↓
filter Mythic branches by species
        ↓
select one branch deterministically from lineage seed
        ↓
persist Mythic Destiny
        ↓
show "Thú thần thoại: <name>" in PetHome
        ↓
Stage 1 -> 2 starts developing toward that branch
```

The infant remains the same individual. Its Stage 1 birth render may show only a very subtle code-locked foreshadowing cue; Stage 2 begins the visible Mythic development, Stage 3 awakens the branch clearly, and Stage 4 completes it rather than spawning a fully transformed adult at hatch.

### B. Fixed three-Gene recipe

A normal pet can unlock Mythic Destiny by accumulating the exact three Gene IDs defined by a branch.

Gene IDs are accumulated from committed evolution history plus the Gene Items used in the current stage. They do not need to be used in the same stage.

This matches the current Gene caps:

```text
Stage 1: max 1 Gene
Stage 2: max 2 Genes

1 previous Gene + 2 current Genes = 3-Gene recipe
```

When a recipe is complete, the branch is locked into the pending evolution plan before rendering. Render failure/retry reuses exactly the same destiny, Gene changes and render seed.

## Current cat branches

### Nekomata

Fixed recipe:

```text
tail_long
eyes_moon
mark_moon
```

Development:

- Stage 2: early spirit-cat/lunar cues; do not fully split the tail.
- Stage 3: awaken the Nekomata branch; one shared tail root develops a fork/twin-tip direction.
- Stage 4: complete the established Nekomata form.

### Bakeneko

Fixed recipe:

```text
coat_shadow
eyes_luminous
whiskers_starlight
```

Development:

- Stage 2: early spectral coat/whisker/gaze cues; keep the normal single-tail body plan.
- Stage 3: awaken the Bakeneko spirit-cat form.
- Stage 4: complete the established Bakeneko form.

These recipes are data, not hard-coded resolver logic. They can be changed without rewriting the evolution engine.

## Random Mythic activation

The generic weighted resolver remains available for future content, but the default cat definitions currently use:

```text
activation_basis_points = 0
```

Therefore the current live Mythic routes are the rare Stage 4 egg destiny and the exact three-Gene recipes. No extra arbitrary Mythic chance has been added.

## Composite evolution plan

Stage evolution now resolves Gene changes per locus.

- Two Genes in different loci can both express in one evolution.
- Two conflicting Genes in the same locus still resolve to one weighted result.
- Reinforcement remains limited to the predefined expression chain.
- No undefined combined Gene trait is invented.

Then Mythic resolution runs against that code-selected Gene result.

The resulting pending plan stores:

- every Gene delta,
- accumulated Gene IDs,
- Mythic Destiny,
- Mythic resolution and trigger source,
- target Genome,
- source/target phenotype,
- serialized render request and stable seed.

The validator rebuilds the plan before commit. If the renderer result does not match the locked plan contract, the stage transition is not committed.

## PetHome info

When Mythic Destiny is known, the Info panel adds:

```text
Thú thần thoại    Nekomata
```

or the corresponding species-specific branch name.

For a rare Stage 4 egg this name is available immediately after hatch. For a normal pet it becomes available once the three-Gene recipe has been locked.

## Adding another species

To add a new species later:

1. add the species identity/visual content;
2. add one or two entries to `species_mythic_mutations.json`;
3. define whether each branch is Stage-4-egg eligible;
4. define the exact three-Gene recipe;
5. define stage-by-stage Mythic prompts.

No species-specific conditional should be added to the core resolver.
