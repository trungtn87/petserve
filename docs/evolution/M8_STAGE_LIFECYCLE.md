# M8 — General Stage Lifecycle + Evolution II / III

## Source scope

The gameplay design defines one pet life as:

```text
Egg
→ Stage 1 / Ấu thể
→ Evolution I
→ Stage 2 / Thiếu niên
→ Evolution II
→ Stage 3 / Trưởng thành
→ Evolution III
→ Stage 4 / Hình thái cuối
→ aging / death / legacy later
```

The same source gives Stage 2 ≈ 2 days and Stage 3 ≈ 3 days as an initial framework, while explicitly saying later-stage timing is not yet hard-locked.

M8 therefore stores these values in data, not gameplay code. They can be tuned without changing lifecycle logic.

Stage 1 remains the existing 2-hour tutorial/prototype target from the current PetHome integration.

## Goal

M8 removes the Stage-1-only wall without introducing death, Legacy Chest, fragment crafting or new item-influence balance.

Playable evolution chain becomes:

```text
Stage 1
  ↓ growth/offline/items
Evolution I
  ↓
Stage 2
  ↓ growth/offline/items
Evolution II
  ↓
Stage 3
  ↓ growth/offline/items
Evolution III
  ↓
Stage 4 FINAL FORM
```

## Stage timing data

`data/gameplay/lifecycle/stages.json`

Current M8 values:

- Stage 1: 2 hours — preserved existing tutorial milestone.
- Stage 2: 2 days — provisional design baseline.
- Stage 3: 3 days — provisional design baseline.
- Stage 4: no M8 growth timer. Aging/death belongs to a later milestone.

Hungry growth remains 75% because M8 does not invent a new nutrition/death balance.

## Runtime architecture

`StageLifecyclePolicy`
loads stage timing from data.

`StageLifecycle`
owns:
- current stage;
- growth elapsed;
- food reserve;
- online progression;
- offline progression;
- ready-to-evolve state;
- transition into final form.

The old `InfantLifecycle` remains as a compatibility wrapper.

`InfantGameFacade` now accepts the current genome stage and uses the generic lifecycle internally. Its name is retained temporarily so existing UI/tests do not require a large rename in the same milestone.

## Evolution transaction

`StageEvolutionService` generalizes the M7 transaction.

For stages 1, 2 and 3 it:

1. validates lifecycle stage == genome stage;
2. requires ready-to-evolve;
3. deterministically selects one M3 mutation;
4. applies one genome delta;
5. uses M7 `EvolutionEditCoordinator`;
6. persists the exact image-edit request;
7. targets exactly current stage + 1;
8. commits only after a valid rendered image;
9. increments visual index and evolution history.

Stage 4 rejects another evolution.

`InfantEvolutionService` is retained as a compatibility wrapper around `StageEvolutionService`.

## Items

Food and Growth items remain growth resources in Stage 1–3.

Existing saved items whose old `usable_stage` value is `infant` remain usable so M8 does not invalidate player inventory.

M8 does not yet add:
- element influence;
- gene influence;
- rare unlock weighting;
- fragments/crafting.

Those systems are present in the gameplay design but are separate from the stage-loop milestone.

## PetHome

PetHome now reads the genome stage when setting up gameplay.

The Evolution panel:
- shows growth and remaining time in Stage 1–3;
- enables Evolution when ready;
- shows “Đã đạt hình thái cuối” at Stage 4.

Caro remains playable after Stage 1 but its infant reward cap is not extended.

## Compatibility

M7 `infant_state` is migrated into the new `life_state`.

During Stage 1 the legacy field is synchronized so the existing infant regression suite remains meaningful.

## Validation

New suite:

`tools/test_m8_stage_cycle.tscn`

It covers:
- Stage 2 timing;
- Stage 3 timing;
- offline Stage 2 growth;
- Food use after infancy;
- Stage 2 → ready;
- Stage 3 → ready;
- Stage 4 final-form stop;
- Evolution II prepare/request/commit;
- Evolution III prepare/request/commit;
- visual index/history continuity;
- rejection of a fourth evolution.

Run together with:

```bash
godot --headless --path . tools/test_infant_home.tscn
godot --headless --path . tools/test_m7_evolution_edit.tscn
godot --headless --path . tools/test_m8_stage_cycle.tscn
```

## M8 boundary

M8 ends at a stable Stage 4 final form.

Natural aging, neglect death, account vault vs pet inventory, Legacy Chest and inheritance remain outside M8.
