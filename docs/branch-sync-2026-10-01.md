# Branch sync — 2026-10-01

Baseline: `pethome`.

## Already absorbed by pethome

These branches are ancestors of the current baseline (ahead_by = 0 when compared with pethome), so they are not merged again:

- feat/evolution-m0-cleanup
- feat/evolution-m1-pet-identity
- feat/evolution-m2-pet-genome
- feat/evolution-m3-rules
- feat/evolution-m4-visual-spec
- feat/evolution-m5-m6-initial-render
- feat/hatch-to-pethome
- integrate/stage2-hunger-into-pethome
- feat/stage3-closeout-reference-evolution
- feat/stage3-food-growth-expansion
- feat/stage3-tier3-chests
- feat/stage4-growth-final-evolution
- feat/legacy-item-inheritance
- feat/pet-skills-26

## Superseded implementation branches

The following branches diverged from an old common base. Their functional contracts are already represented in current pethome code and acceptance tests. They are kept as history instead of being merged wholesale:

- feat/stage2-step1-lifecycle
- feat/stage2-step2-reward-gene-source
- feat/stage2-step3-mythic-mutations
- feat/stage2-step3b-mythic-destiny
- feat/stage2-step4-pethome-feedback
- feat/stage2-step5-acceptance-android-ci
- feat/hunger-growth-thresholds
- feat/infant-caro-entertainment
- feat/infant-item-chest-inventory
- feat/dev-instant-evolution-talent
- feat/stage2-gene-score-final
- feat/m9-genome-v1-foundation
- feat/m9-stage-gene-state
- feat/m9-2-gene-foundation-hardening
- feat/m9-2-gene-policy-state
- feat/m9-2-stage-gene-policy
- feat/m9-3-gene-items-inventory
- feat/m9-4-stage1-evolution-resolver
- feat/m9-5-stage1-evolution-image-edit
- old ci/*, fix/* and work/* branches based on the same stale baseline

Merging these branches directly would reintroduce older versions of files that pethome has since evolved.

## Intentionally not merged

- feat/cat-2-5d-framework — experimental presentation track; current pethome uses the AI-rendered visual/evolution pipeline.
- feat/localization-vi-en — separate product scope, not required by Final Record.
- feat/v1.3-cloud-save-foundation — future persistence scope, intentionally isolated from the current local-save release.

## Current implementation order

1. Keep pethome as canonical baseline.
2. Add Final Record archive without duplicating stage image files.
3. Reconstruct stage snapshots from evolution_history + current_visual.
4. Render exactly four portrait milestones into a 16:9 landscape card.
5. Add account-level final-form collection and completion counter.
6. Integrate Final Record before legacy/reset so the old life cannot be lost.
7. Run the full Godot acceptance suite.
8. Build the Android debug APK through the existing GitHub Actions pipeline.
