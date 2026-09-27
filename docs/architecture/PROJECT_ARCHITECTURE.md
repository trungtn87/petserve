# PetVerse — Project Architecture

Status: Foundation

## Principle
PetVerse is organized by responsibility. The main application layer coordinates modules; it must not absorb gameplay logic.

The project has three architecture goals: **extensible, reusable, diverse**.

### Core rule: adding content must not require editing Core
Content of an existing kind should be added through definitions/configuration/assets rather than conditionals in shared systems.

```text
FRAMEWORK / CORE
       ↓
CAPABILITY + REGISTRY
       ↓
DEFINITION / CONFIG
       ↓
ASSET / CONTENT
       ↓
INSTANCE
```

Examples:
- new pet -> new PetDefinition + assets; no Pet Core edit
- new element/attribute -> new definition/data; no pet-specific `if element == ...` chain
- new home -> new HomeDefinition/environment assets; no new home controller
- new expression/state content -> definition/capability data where the existing framework supports it

A genuinely new gameplay capability may extend the framework/API. Existing content types must not require Core edits merely to add another entry.

## Existing baseline
The v1.1 repository already separates application, core services, data, egg/hatch features, scenes, UI and tools. The pet system extends this structure instead of replacing the working egg system.

## Target module boundaries

```text
res://
├── app/                 # app startup and cross-module routing
├── core/                # reusable infrastructure/services
├── data/                # definitions/configuration/content data
├── egg/                 # existing egg module
├── pet/                 # generic pet framework
│   ├── domain/          # pet state/profile/capabilities
│   ├── brain/           # state/behavior decisions
│   ├── interaction/     # player -> pet interaction resolution
│   └── presentation/    # state -> visual/audio representation
├── home/                # reusable home/environment framework
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
Facade / Framework API
    ↓
Domain + capabilities + behavior
    ↓
Presentation
    ↓
Definitions + assets
```

Screens must not calculate pet needs, personality or expression rules. Pet visuals must not decide gameplay state.

## Reference Pet rule
The Dark Pet is the first reference implementation. Pet Core must never depend on Dark Pet specifically. A future pet should be addable primarily through assets/configuration and optional capabilities/presentation overrides.

## Reusable Home Framework
PetHome is a host, not a specific room.

```text
PetHome
├── EnvironmentSlot
├── DecorationLayer
├── ActorLayer
│   └── PetAnchor
├── EffectLayer
└── UILayer
```

A HomeDefinition describes replaceable content such as environment, background/foreground, pet anchor, decorations, ambient FX/audio and lighting. Environment, actor and UI remain independent.

## Diversity rule
Reuse must not reduce every pet/home to a reskin. Shared capabilities provide common behavior; definitions and optional components/overrides provide diversity. Avoid identity condition chains such as `if dark`, `elif fire`, `elif water` in generic Core code.

## Main-file rule
Main/root scripts coordinate lifecycle and routing only. New pet behavior, state logic, animation logic or feature logic must live in its owning module rather than being appended to the main screen.

## Migration rule
The working v1.1 egg/hatch flow is baseline behavior. Pet development is additive until an explicit Egg -> PetHome transition is introduced and tested.
