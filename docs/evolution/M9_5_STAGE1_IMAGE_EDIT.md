# M9.5 — Stage 1 Evolution Image-Edit Integration

Status: implementation in progress.

## M9.5.1 — Prompt and visual contract

Locked requirements:

- Every evolution image-edit receives the complete 12-locus phenotype snapshot.
- Gene evolution receives both current and code-selected target phenotype.
- AI may mature age/proportions for the next life stage, but may not invent Gene changes.
- Natural Growth uses a separate image-edit contract with zero Gene delta.
- Natural Growth must preserve all 12 visual loci semantically.
- The body Gene locus is distinct from ordinary age/proportion maturation.
- Stage 1 Gene visual changes are curated per Gene direction; they are not generated from free-form AI interpretation.
- PetHome environment, camera, framing and UI-safe zones remain locked to the previous full PetHome image.

M9.5.1 does not yet switch StageEvolutionService to the new Stage 1 resolver. That wiring is the next substep so the prompt layer can be reviewed independently.

## M9.5.3 — Plan integrity hardening

Before a Stage 1 render request can be reused or committed, StageEvolutionPlanValidator verifies:

- current and next stage are exactly 1 -> 2;
- source visual belongs to the same PetIdentity;
- serialized render request still matches pet, source image and target stage;
- persisted source/target phenotype snapshots match their PetGenome snapshots;
- Natural Growth has no delta, no changed visual locus and no new mutation history;
- Gene mode changes exactly one visual locus;
- Gene delta, target region, mutation history and Gene provenance all agree.

Corrupted or tampered pending plans are rejected instead of being rendered or committed.
