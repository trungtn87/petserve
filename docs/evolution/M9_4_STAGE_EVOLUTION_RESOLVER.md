# M9.4 — Stage 1 Natural Growth vs Gene Expression Resolver

Status: Stage 1 core resolver implemented. Runtime image-edit integration is deferred to M9.5.

## Locked Stage 1 behavior

StageEvolutionResolver is the decision point between Natural Growth and Gene Expression for Stage 1.

- No Gene Item used in Stage 1 -> natural.
- One valid Stage 1 Gene Item used -> gene.
- Natural Growth preserves all 12 visual loci and does not invent a mutation.
- Gene Expression converts the consumed Gene direction into exactly one EvolutionDelta.
- The delta is applied to a new PetGenome snapshot; the source Genome is never mutated.
- Hidden influence tags remain attached to the resolution for later weighting logic.
- Stage 1 therefore behaves clearly: thả rông = chỉ lớn tự nhiên; dùng 1 Gene Item = có một hướng hình thái khác.

## Stage-by-stage boundary

M9.4 intentionally does not decide Stage 2/3 Gene expression.

Stage 2 may eventually express up to two Gene-driven changes and Stage 3 up to three, so the Stage 1 resolver must not silently force later Stages into a one-trait rule.

If Gene input exists outside Stage 1, the resolver returns requires_stage_expression_policy = true. Reinforcement of an already expressed direction also waits for an explicit advanced expression chain rather than fabricating a new allele.

## Deferred to M9.5

- use the Stage 1 resolver inside StageEvolutionService;
- Natural Growth image-edit prompt;
- Gene visual instruction lookup;
- full phenotype prompt sent to AI;
- pending evolution metadata for natural/gene mode;
- Android end-to-end Stage 1 -> Stage 2 test.
