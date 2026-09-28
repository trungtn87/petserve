# Pet Vô Hạn — Evolution Core

Godot Android portrait project.

## Current milestone

M5 + M6 are wired into the Godot runtime.

After Hatch, the app now opens the Evolution Initial screen and builds a real infant render request from:

```text
Egg element + run seed
        ↓
PetIdentity
        +
initial PetGenome
        ↓
Galaxy infant visual spec
        ↓
text-to-image request
```

The first render intentionally uses **no reference image**. It establishes the first visual identity for that pet.

Current infant constraints:
- species: cat;
- stage: 1;
- body_growth: 0;
- all traits: base;
- mutations: empty;
- Galaxy Fantasy Chibi style;
- advanced mutation features explicitly forbidden.

## Development renderer

The branch includes a direct OpenAI Images API adapter for local development only.

It reads:

```text
OPENAI_API_KEY
```

from the environment. No API key is stored in the repo.

If the key is missing, the Godot screen still runs, shows the complete generated prompt, and reports that rendering is waiting for the key instead of crashing.

A successful render is cached in:

```text
user://pet_renders/
```

and linked to the pet in:

```text
user://evolution_pet_v1.json
```

## Android

Internet permission is enabled for later network rendering. A production APK must not contain a provider API key; the direct adapter is a development bridge until a server/proxy render path is added.

## Test status

M1–M6 include headless/runtime test hooks. Local execution remains deferred until convenient.

See:
- `docs/evolution/M1_PET_IDENTITY.md`
- `docs/evolution/M2_PET_GENOME.md`
- `docs/evolution/M3_EVOLUTION_RULES.md`
- `docs/evolution/M4_VISUAL_SPEC.md`
- `docs/evolution/M5_M6_INITIAL_RENDER.md`
