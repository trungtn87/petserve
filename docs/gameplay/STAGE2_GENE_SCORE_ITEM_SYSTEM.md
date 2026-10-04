# Stage 2 — Gene Score Item System

Status: **AUTHORITATIVE IMPLEMENTATION SPEC**

This document supersedes the old per-stage Gene-slot design. The implementation target is the `pethome` integration line after Stage 2 closeout.

## 1. Final item model

The live Gene catalog contains **64 base Gene definitions**.

- **50 shared physical Genes**: usable by every element.
- **14 element effect Genes**: `mark` + `aura` for 7 elements.
- Rarity is an **item-instance property**. It does not create another Gene definition.
- Therefore the code owns 64 Gene definitions, while the player can encounter many item variants through rarity and repeated drops.

### Shared physical loci — 50 Genes

| Locus | Five directions |
| --- | --- |
| eyes | luminous, moon, sharp, gentle, ringed |
| ears | long, tufted, sharp, rounded, softfan |
| fur | fluffy, sleek, plush, layered, silky |
| coat | shadow, nebula, striped, spotted, marbled |
| tail | long, fluffy, curved, tipped, streamlined |
| body | sturdy, agile, slender, compact, regal |
| whiskers | starlight, long, fine, fanned, curved |
| paws | luminous, sturdy, swift, fluffy, runic |
| mane | astral, full, layered, silken, regal |
| structure | spirit, guardian, elegant, feral, ancient |

### Element effect loci — 14 Genes

Each of the seven elements has exactly two element-locked definitions:

```text
mark_wood    aura_wood
mark_earth   aura_earth
mark_fire    aura_fire
mark_water   aura_water
mark_metal   aura_metal
mark_light   aura_light
mark_dark    aura_dark
```

Effect items may drop randomly even when their element does not match the current pet. A mismatched effect item is **not consumed and is not junk**; it remains in inventory for a compatible pet / inheritance path.

## 2. Rarity → score and Growth

Rarity changes strength, not the Gene direction.

| Rarity | Gene score | Growth |
| --- | ---: | ---: |
| Common | +25 | +2% |
| Uncommon | +60 | +5% |
| Rare | +120 | +7% |
| Epic | +200 | +10% |
| Legendary | +320 | +15% |

Example: Common `tail_long` and Legendary `tail_long` are the same Gene direction. The Legendary instance contributes more score and reaches stronger visual expression faster.

A single newly generated Gene Item must be visibly readable on the next evolution. Common starts at DEVELOPING instead of TRACE. Rarity controls intensity, not whether the Gene appears.

Hidden `influence_tags` scale with the same rarity multiplier so old weighted/Mythic-support data remains proportional to item strength. Legacy Gene items are migrated to this score table when inventory data is loaded.

## 3. Unlimited use in growth stages

The old Gene-slot rules are removed.

```text
Stage 1: unlimited Gene Items
Stage 2: unlimited Gene Items
Stage 3: unlimited Gene Items
Stage 4: final form; no new Gene Item consumption
```

All 12 loci are accepted in Stages 1–3. There is no `0/2`, `1/2`, or `2/2` usage state anymore.

The player may stack the same direction repeatedly or distribute items across many loci/directions.

## 4. Lifetime Gene score ledger

Canonical score key:

```text
<locus>.<direction>
```

Example:

```text
tail.long     = 135
tail.fluffy   = 82
tail.curved   = 38
fur.sleek     = 65
fur.fluffy    = 55
aura.fire     = 145
```

Scores persist across live stages.

Two different concepts are intentionally separated:

1. **Current-stage Gene inputs** — items consumed since the previous evolution. These drive the structural `EvolutionDelta` for the next transition.
2. **Lifetime Gene scores** — all score accumulated during the pet life. These survive stage reset and drive the visual strength/blending prompt.

When the pet advances a stage, current-stage input items are cleared, but lifetime scores, used Gene IDs, lifetime tag influence, and used-item history remain.

This prevents a Stage 1 Gene from being reapplied as a new structural mutation every later stage while still allowing its visual influence to persist and intensify.

## 5. Score → visual expression tier

Global thresholds:

| Score | Internal tier | UI meaning |
| ---: | --- | --- |
| 0 | NONE | Chưa biểu hiện |
| 1–24 | TRACE | Mầm |
| 25–59 | DEVELOPING | Đang phát triển |
| 60–119 | EXPRESSED | Biểu hiện rõ |
| 120–199 | DOMINANT | Đặc trưng |
| 200+ | ASCENDED | Cực đại |

Thresholds are centralized in `GeneExpressionScale`.

A Gene definition supplies its own `prompt_stem` and `preserve_hint`. The tier supplies the intensity language.

Therefore the threshold system is shared, while anatomy/surface meaning remains specific to each Gene.

## 6. Multiple directions in one locus

Scores do not force one permanent winner.

For each locus at render time:

- highest score = **DOMINANT direction**;
- other positive-score directions = **SECONDARY BLEND**;
- each direction keeps its own expression tier.

Example:

```text
tail.long    135  -> dominant / DOMINANT
tail.fluffy   82  -> secondary / EXPRESSED
tail.curved   38  -> secondary / DEVELOPING
```

The prompt may describe one tail as long + clearly fluffy + mildly curved. It must not invent a direction absent from the score ledger.

The structural Genome resolver still chooses a deterministic/weighted canonical trait for transition bookkeeping. The score prompt carries the richer visual blend.

## 7. Physical vs effect Gene behavior

### Physical Genes

The 50 physical Genes are shared. Their prompt is combined with the pet's existing element language.

A Fire pet and Water pet can both use `tail_long`; the anatomical direction is the same while elemental styling remains Fire/Water.

### Mark and Aura

`mark` and `aura` are explicit element effects.

- Drop: may be any element.
- Inventory/inheritance: always allowed to keep.
- Consume: only when `GeneDefinition.element_lock == PetIdentity.element`.
- Render: only definitions compatible with the current pet element are read from the score ledger.

## 8. Prompt pipeline

The render contract is:

```text
Gene Item instance
    ↓ rarity maps to Gene score
GeneDevelopmentState lifetime ledger
    ↓
GeneExpressionScale selects tier
    ↓
GenePromptResolver
    ↓ dominant + secondary directions per locus
EvolutionEditCoordinator base stage/element/Mythic prompt
    ↓
EvolutionEditCoordinator adds [GENE VISIBILITY LOCK], then StageEvolutionService appends [ACCUMULATED GENE SCORE PHENOTYPE]
    ↓
serialized pending render request
```

`StageEvolutionPlanValidator` rebuilds the Gene score prompt from persisted `gene_scores`. A changed score prompt, tier, render request, Gene delta, Mythic branch or seed fails validation.

Pending evolution schema is **11**. Older pending plans are rebuilt instead of silently reused.

## 9. Save migration

`GeneDevelopmentState` schema is **2**.

New persisted fields:

- `gene_items` — current-stage consumed Gene inputs;
- `gene_scores` — lifetime `locus.direction -> score`;
- `lifetime_tag_influences`;
- `used_gene_ids`;
- `used_item_uids`.

When loading an older state that only contains `gene_items`, schema-2 restore reconstructs the score ledger and lifetime identifiers from the available old records.

A stage mismatch no longer discards the lifetime Gene state. It performs `reset_for_stage()`, which clears only current-stage inputs.

## 10. PetHome item detail

The old line:

```text
Lượt Gene Thiếu niên: 0/2
```

is removed.

Gene detail now exposes:

- locus and direction;
- usable growth stages;
- current accumulated score;
- score added by this item;
- projected score after use;
- current → projected expression tier;
- next score threshold;
- element requirement for Mark/Aura;
- pending evolution lock status.

## 11. Mythic integration

Mythic recipes use accumulated Gene **loci**.

Current cat branches:

- Giác Linh Miêu: `whiskers + mark + ears`;
- Dực Linh Miêu: `fur + body + mane`.

Lifetime `used_gene_ids` persists across stage reset so a recipe can be completed over multiple stages.

The retired generic `mark_moon` fixture is replaced by element-specific Mark definitions such as `mark_dark`.

See `docs/evolution/STAGE2_MYTHIC_MUTATIONS.md`.

## 12. Main implementation files

- `data/evolution/gene/base_genes.json`
- `data/evolution/gene/stage_gene_policy.json`
- `features/evolution/domain/gene_definition.gd`
- `features/evolution/domain/gene_development_state.gd`
- `features/evolution/rules/gene_expression_scale.gd`
- `features/evolution/visual/gene_prompt_resolver.gd`
- `features/evolution/rules/stage_gene_policy.gd`
- `gameplay/item/item_generator.gd`
- `gameplay/infant/infant_game_facade.gd`
- `features/evolution/service/stage_evolution_service.gd`
- `features/evolution/service/stage_evolution_plan_validator.gd`
- `features/evolution/service/evolution_edit_coordinator.gd`
- `screens/pet_home/pet_home_gameplay_ui.gd`

## 13. Stage 2 acceptance contract

Stage 2 may be closed only when CI verifies:

- project imports with no script/class parse failures;
- exactly 64 valid Gene definitions;
- 50 shared + 14 element-effect split;
- rarity maps to the locked score/Growth table;
- unlimited Gene use works in Stages 1–3;
- final Stage 4 blocks new Gene use;
- wrong-element effect Gene remains stored and cannot be consumed;
- score survives stage reset;
- same direction stacks;
- multiple loci still resolve in one evolution;
- score prompt is serialized and retry-safe;
- Mythic locus recipe still works across history/current stage;
- Stage 2→3 acceptance passes;
- Android debug APK smoke-build succeeds.
