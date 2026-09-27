# PetVerse — Pet Design

Status: Foundation design

## Core experience
The pet is treated as a living subject, not as a dashboard of statistics. The primary screen prioritizes the pet and its environment.

## No-numbers presentation
Internal simulation may use numeric values, but the player-facing experience communicates them through state, expression, motion, behavior, sound and environmental response.

The primary pet screen does not expose Level, EXP, age/day counters, hunger bars, mood bars or elemental labels as permanent HUD elements.

## State-first communication

```text
Internal simulation
        ↓
State resolver
        ↓
Pet state(s)
        ↓
Visual / behavior expression
        ↓
Player observes and responds
```

A pet may hold multiple internal states simultaneously. Presentation chooses readable signals instead of exposing raw values.

## Pet Home
The default home view is intentionally minimal: pet + environment. Secondary functions are summoned through a hidden/expandable menu instead of occupying the permanent HUD.

Direct pet interaction should happen on the pet whenever practical (tap, later hold/swipe/drag), rather than through a generic "Interact" button.

## Reference Pet 001 — Dark Pet
The existing Dark Pet design is the first reference pet used to validate the framework. Its large eyes, ears, tail, forehead mark and dark FX provide expression channels.

Initial expression vocabulary:
- neutral
- blink
- happy
- curious
- surprised
- sleepy

Initial lightweight interaction target:
- idle micro-actions
- occasional blink/look/ear/tail/head motion
- tap reaction
- return to idle

## Reuse goal
Expression is compositional where possible. A state can be represented by combinations of eyes, eyelids, mouth, ears, tail, body motion, mark/FX and sound instead of requiring a unique full-frame animation for every state.

The framework is successful when Pet 002 can inherit the same behavior/expression system without rewriting Pet 001 logic.
