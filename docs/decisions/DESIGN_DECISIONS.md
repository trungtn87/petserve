# PetVerse — Design Decisions

This file records decisions that should not be casually reopened during implementation. A changed decision should be explicitly documented rather than silently overwritten in code.

## PET-001 — Pet is a subject
Pet is modeled and presented as a living subject, not a collection of player-facing statistics.

## PET-002 — No permanent numeric progression HUD
Do not permanently expose Level, EXP, age/day, hunger or mood as numeric HUD on Pet Home. Internal numeric simulation is allowed.

## PET-003 — State communicates simulation
Internal values are resolved into states; states are communicated through behavior, expression, motion, FX and sound.

## PET-004 — Pet Home remains visually minimal
The main composition prioritizes pet + environment. Necessary secondary functions live behind an expandable/hidden menu.

## PET-005 — Direct interaction belongs on the pet
Basic interaction should be direct (initially tap; later gestures as needed), not a permanent generic interaction button.

## PET-006 — Dark Pet is Reference Pet 001
Dark Pet validates the generic Pet Framework. Core/domain/brain code must not depend on Dark Pet identity.

## PET-007 — New pets inherit the framework
Adding a new pet should primarily mean adding/configuring assets and pet-specific presentation data. Shared state/behavior/interaction logic is inherited.

## PET-008 — Main coordinates only
Main/root screen code must remain orchestration-focused. Pet logic belongs to the pet module; feature logic belongs to its feature module.

## PET-009 — Preserve Egg v1.1 during Pet foundation work
The existing egg/hatch implementation remains the baseline. Pet work is additive until transition integration is explicitly implemented and tested.

## PET-010 — First pet milestone
The first milestone is not full pet gameplay. It is: Pet Home composition + one expressive Dark Pet + idle micro-behaviors + lightweight tap interaction.
