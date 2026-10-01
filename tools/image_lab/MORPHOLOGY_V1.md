# Morphology V1
Implemented on test/ai-image-gene-stages.

- 64 Gene descriptions now specify visible anatomy, fur contours, markings or localized energy. Dynamic Gene visuals use this catalog before legacy overrides.
- Birth frame, face language, fur contour, pose family, side and response vary deterministically with lineage seed and generation. Same seed reproduces the same design brief; new life button picks a different seed.
- Stage 1 establishes individuality; stages 2–5 progressively mature torso, legs and chest even without Gene input.
- Body and structure scores resolve bounded numerical proportions from the inherited frame. Tail-long and ear-long also affect ratios. Other traits use the detailed catalog instructions and accumulated score tiers.
- Structure Genes coordinate existing regions. They never authorize horns, wings or extra tails; existing Mythic resolution remains authoritative.
- Existing Gene IDs and saved scores remain valid. Expression chains gain a fourth terminal entry so the same direction can develop at all four feeding stages through Final.
- Stage 2 remains text-to-image. Stage 3+ uses the previous image for identity while allowing target morphology and pose changes.
- Pending plan schema is 13. Old pending plans are rebuilt by the existing migration path. Output keys are versioned to avoid old cached artwork.
- The canonical plan validator reconstructs the same morphology prompt; its checks are not bypassed.
- Existing full-body PetHome composition remains; no provider/model change or new paid service.
- Image quality still requires actual AI comparisons: deterministic descriptions do not guarantee unique pixels or exact numerical proportions from a generative model.

Tests: image-lab.yml imports in Godot 4.6.1, tests 64 seeds, Gene visuals, all seven elements through Final, UI preparation and startup. No AI calls.
