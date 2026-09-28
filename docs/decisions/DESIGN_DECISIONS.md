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

## ARCH-001 — Extensible, reusable, diverse
All major systems are designed for three properties: extension without duplication, reuse of stable frameworks, and content diversity through data/capabilities rather than copied logic.

## ARCH-002 — Adding content is not editing Core
Adding another entry of an existing content type (pet, element/attribute, home, expression, item, event, etc.) must not require modifying shared Core merely to recognize its identity. Prefer definitions, registries, capabilities and assets.

## ARCH-003 — New capability may extend the framework
"No Core edits for new content" does not prohibit architecture evolution. A genuinely new gameplay capability may add a generic API/component. Once added, additional content using that capability should be data-driven.

## ARCH-004 — Avoid identity condition chains
Generic systems must not grow chains such as `if dark / elif fire / elif water`. Identity-specific differences belong in definitions, capabilities, assets or explicit presentation overrides.

## HOME-001 — Pet Home is a reusable host
Pet Home is not a specific room. It hosts replaceable environment, decoration, actor, effect and UI layers. New homes should primarily be HomeDefinition + assets.

## HOME-002 — Pet and home are independent
A pet is not bound to a specific home scene. The same pet can inhabit different HomeDefinitions and the same home can host different pets without duplicating controller logic.

## PET-011 — Fixed-camera Cat 2.5D production presentation
The primary Pet Home uses the reusable native-Godot Cat 2.5D Framework.
Sprite parts, pivot motion, texture swaps and lightweight FX preserve the
concept appearance for limited interactions. No free/360-degree camera.
Dark is Reference Pack 01; element/stage variations are profiles and assets,
not identity checks in Core. Existing 3D scenes remain R&D.
See `docs/design/CAT_2_5D_FRAMEWORK.md` for implementation and limits.
