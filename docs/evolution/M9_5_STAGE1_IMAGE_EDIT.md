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

## M9.5.4 — Compatibility and matrix checks

- Legacy Stage 1 pending plans from the old random-mutation pipeline are discarded and rebuilt under M9.5 rules.
- Legacy Stage 2/3 plans remain accepted until those stages are deliberately migrated.
- Natural and Gene Stage 1 plans are tested through commit, not only prepare.
- The ten Stage 1 Gene definitions are checked as a matrix: every Gene must resolve to one delta and every delta must have a curated visual definition targeting the same locus.
- The full phenotype prompt contract is checked against all 12 Genome V1 loci.
