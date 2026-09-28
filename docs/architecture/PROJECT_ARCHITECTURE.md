# PetVerse — Project Architecture

Status: M0 clean baseline

## Principle

The application layer coordinates modules. Gameplay logic belongs to the feature/domain that owns it.

## M0 baseline

The retired pet presentation stack has been removed. The active runtime contains:

```text
res://
├── app/                 # startup and cross-feature routing
├── core/                # reusable infrastructure/services
├── data/                # egg/task configuration
├── egg/                 # egg view
├── features/
│   ├── egg/             # incubation domain + engines
│   └── hatch/           # hatch + naming
├── UI/                  # main screen/components/theme
├── scenes/
│   ├── main.tscn
│   └── evolution_placeholder.tscn
└── tools/               # generic project tooling only
```

## Removed legacy areas

M0 intentionally removes the old 3D, 2D/2.5D, Pet Home, pet expression, pet motion and direct pet-interaction implementations.

These implementations remain recoverable from Git history and the existing side branches. They are not dependencies of the new Evolution Core.

## Next architecture boundary

M1 may introduce a new evolution domain, but it must not depend on the retired presentation framework.

The intended dependency direction is:

```text
App / Screen
    ↓
Evolution service/facade
    ↓
Identity + genome + evolution rules
    ↓
Visual specification / renderer adapter
```

Presentation/rendering must not decide evolution rules.

## Main-file rule

Main/root scripts coordinate lifecycle and routing only. Domain rules must not be appended to MainScreen or GameApp.

## Stable baseline rule

Egg v1.1 and Hatch remain working baseline modules while Evolution Core is developed in isolated milestones.
