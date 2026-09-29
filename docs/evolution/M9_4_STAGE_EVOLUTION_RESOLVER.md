# M9.4 — Natural Growth vs Gene Expression Resolver

Status: core resolver implemented. Runtime image-edit integration is deferred to M9.5.

## Locked behavior

StageEvolutionResolver is the single decision point between Natural Growth and Gene Expression.

- No Gene Item used in the current Stage -> natural.
- Gene input exists -> gene.
- Natural Growth preserves all 12 visual loci and does not invent a mutation.
- Gene Expression selects one Gene input deterministically from the current Stage state and converts it into exactly one EvolutionDelta.
- The delta is applied to a new PetGenome snapshot; the source Genome is never mutated.
- Hidden influence tags remain attached to the resolution for later weighting logic.
- Multiple Gene inputs are weighted by their primary influence and resolved deterministically from lineage + current Genome + Gene inputs.

## Stage-by-stage boundary

M9.4 intentionally does not invent advanced allele chains.

If a later Stage consumes a Gene whose direction is already expressed, the resolver returns requires_expression_chain = true rather than silently doing nothing or fabricating an advanced form.

Stage 2/3 reinforcement chains will be defined when those Stages are optimized.

## Deferred to M9.5

- use this resolver inside StageEvolutionService;
- Natural Growth image-edit prompt;
- Gene visual instruction lookup;
- full phenotype prompt sent to AI;
- pending evolution metadata for natural/gene mode;
- Android end-to-end Stage 1 -> Stage 2 test.
