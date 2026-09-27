# PetVerse — Project Architecture

Status: Foundation

## Principle
PetVerse is organized by responsibility. The main application layer coordinates modules; it must not absorb gameplay logic.

## Existing baseline
The v1.1 repository already separates application, core services, data, egg/hatch features, scenes, UI and tools. The pet system extends this structure instead of replacing the working egg system.

## Target module boundaries

```text
res://
├── app/                 # app startup and cross-module routing
├── core/                # reusable infrastructure/services
├── data/                # configuration and content data
├── egg/                 # existing egg module
├── pet/                 # pet domain/framework (new)
│   ├── domain/          # pet state/profile/traits
│   ├── brain/           # state/behavior decisions
│   ├── interaction/     # player -> pet interaction resolution
│   └── presentation/    # state -> visual/audio representation
├── features/            # independent gameplay features
├── scenes/              # Godot scene composition
├── screens/             # screen-level presentation/controller code
├── UI/                  # reusable UI components
└── docs/                # architecture/design/decisions
```

## Dependency direction

```text
App / Screen
    ↓
PetFacade
    ↓
Pet domain + brain + interaction
    ↓
Presentation
    ↓
Pet scene/assets
```

Screens must not calculate pet needs, personality or expression rules. Pet visuals must not decide gameplay state.

## Reference Pet rule
The Dark Pet is the first reference implementation. Pet Core must never depend on Dark Pet specifically. A future pet should be addable primarily through assets/configuration and optional presentation overrides.

## Pet Home composition

```text
PetHome
├── EnvironmentLayer
├── ActorLayer
│   └── PetAnchor
└── UILayer
```

Environment, actor and UI remain independent so rooms/environments, pet species and interface can evolve separately.

## Main-file rule
Main/root scripts coordinate lifecycle and routing only. New pet behavior, state logic, animation logic or feature logic must live in its owning module rather than being appended to the main screen.

## Migration rule
The working v1.1 egg/hatch flow is baseline behavior. Pet development is additive until an explicit Egg -> PetHome transition is introduced and tested.
