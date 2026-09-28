# PetVerse — Design Decisions

This file records decisions that should not be casually reopened during implementation.

## EVO-000 — M0 removes the retired pet presentation stack
The previous 3D, 2D/2.5D, Pet Home, expression, motion and direct pet-interaction implementations are not part of the new baseline.

## EVO-001 — Evolution is the core direction
The next gameplay foundation is pet evolution, not a simulation-heavy pet-care runtime.

## EVO-002 — A pet must preserve lineage
Future visual forms must develop from the same individual pet rather than being independently regenerated as unrelated characters.

## EVO-003 — Code decides evolution
Evolution identity, genome and mutation changes are decided by deterministic/domain code. A renderer may visualize those decisions but must not invent the evolution rules.

## EVO-004 — Small controlled deltas
Evolution should be developed as a sequence of small controlled changes. New mutation types should primarily be data additions once the rule system is stable.

## EVO-005 — Visual direction belongs to the visual-spec layer
The art family is controlled by visual-spec data rather than gameplay rules. The original Galaxy direction was later superseded by EVO-028.

## ARCH-001 — Main coordinates only
Main/root code remains orchestration-focused.

## ARCH-002 — Stable milestone development
Each layer is completed and tested before the next layer is added.

## ARCH-003 — Preserve Egg v1.1 during Evolution Core work
Egg incubation, hatch and naming remain baseline behavior until an evolution replacement explicitly changes that flow.

## ARCH-004 — Side branches are historical/experimental references
M0 cleanup must not rewrite or delete existing side branches.


## EVO-006 — PetIdentity is immutable across evolution
A single pet life keeps the same pet_id, species, element, lineage_seed and generation through every later growth/evolution visual change. Stage, genome mutations and rendered images must not be stored as identity fields.

## EVO-007 — Identity is deterministic
The same species + element + lineage_seed + generation must produce the same pet_id. Identity generation must not depend on AI output or image content.


## EVO-008 — Genome is separate from identity
Stage, body growth, visual traits and mutation IDs belong to PetGenome, never PetIdentity.

## EVO-009 — Genome starts small and extensible
The V1 genome exposes only stage, body_growth, an open trait map and mutation IDs. New visual channels should be added as trait data rather than new core fields unless a future capability genuinely requires a typed field.

## EVO-010 — Genome is a snapshot
PetGenome does not expose mutable internal collections. A later evolution service creates a new validated genome snapshot instead of letting arbitrary UI/render code mutate the current genome in place.

## EVO-011 — M2 contains no evolution probability
Mutation rarity, compatibility, item influence and next-evolution selection are explicitly deferred to the Evolution Rules milestone.


## EVO-012 — One M3 step changes one trait
An EvolutionDelta changes exactly one genome trait and appends exactly one mutation ID. Stage and body-growth progression are not silently bundled into the same mutation step.

## EVO-013 — Mutation selection is deterministic
The same stable identity, genome state and mutation catalog must select the same next mutation. Mutation selection cannot depend on AI output.

## EVO-014 — Mutation definitions are data-driven
Mutation identity, target trait, prerequisites, stage constraints, weights, allowed species/elements and conflicts belong in mutation data rather than hard-coded identity condition chains.

## EVO-015 — Existing mutation IDs cannot repeat within one genome
A mutation already recorded on a pet is not eligible again. Absolute uniqueness between different pets is a separate future signature/registry capability.

## EVO-016 — Evolution applies by snapshot replacement
Applying an EvolutionDelta creates a new PetGenome snapshot. The old genome remains unchanged.


## EVO-017 — M4 is renderer-neutral
Visual Spec and Prompt Builder describe the desired edit but contain no vendor/model API assumptions.

## EVO-018 — Shared visual family with element-specific accents
All base pets use one shared quality/style contract with element-specific accent palettes. The original Galaxy family was later superseded by Mythic Elemental Chibi in EVO-028.

## EVO-019 — Visual wording is separate from mutation probability
Gameplay MutationDefinition remains independent from MutationVisualDefinition. Art prompt changes must not alter evolution weights or eligibility.

## EVO-020 — Every rendered evolution starts from the previous pet image
The future renderer must treat the previous individual pet image as the source of truth. M4 prompts explicitly request the same individual, not a new text-only character.

## EVO-021 — M4 rejects multi-trait drift
A visual spec is produced only when the M3 transition changes one target trait and appends one mutation. Any unrelated genome change invalidates the visual request.

## EVO-022 — Magical detail stays restrained
Elemental magic is localized and readable. Full-body noisy textures, excessive particles and effects that obscure the pet silhouette are explicitly rejected.


## EVO-023 — Initial infant render is text-to-image
The first infant visual is created without a source image. It establishes the visual identity that every later edit must preserve.

## EVO-024 — Initial infant is intentionally mutation-free
The M6 base pet requires stage 1, body_growth 0, base traits and an empty mutation history. Advanced visual mutations are explicitly excluded from the initial prompt.

## EVO-025 — Renderer is behind an adapter
Gameplay and visual-spec layers do not call a provider API directly. PetRenderRequest / PetRenderer / PetRenderResult form the provider boundary.

## EVO-026 — Direct OpenAI renderer is development-only
The direct Images API adapter reads its API key only from an environment variable and no key is committed to the repository. A production Android build must later use a controlled backend/proxy rather than shipping a provider secret in the client.

## EVO-027 — Rendered initial art is cached
A successful initial render is saved under user:// and linked to PetIdentity + PetGenome through EvolutionSaveService. Re-entering the screen reuses the saved image for the same pet unless the user explicitly regenerates it.


## EVO-028 — Base visual family changed to Mythic Elemental Chibi
The Galaxy-heavy direction is retired for base pets. Base infants use soft Mythic Elemental Chibi art with restrained magical effects.

## EVO-029 — Element lineage anchors exist before mutation
Base infants may carry element palette, eye color, one small forehead lineage sigil and one restrained tail-centered effect while the genome remains mutation-free. These cues identify lineage rather than mutation state.

## EVO-030 — Stable M3 mutation IDs are not renamed for visual-only changes
M3 rule IDs remain stable even when M4 reinterpretation changes their art wording. Visual meaning belongs to M4 data.

## EVO-031 — Initial identity render uses Sunburst
The first text-to-image render uses gpt-image-2.5-sunburst in the development adapter because this image becomes the visual origin for the pet's later evolution lineage.
