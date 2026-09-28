# Pet Vô Hạn — Evolution Core

Godot Android portrait project.

## Current visual direction

Base art direction:

```text
MYTHIC ELEMENTAL CHIBI
```

M1–M4 remain provider-independent:
- PetIdentity
- PetGenome
- deterministic evolution rules
- Mythic visual/prompt specification

## M5/M6 development renderer

The active development renderer is now:

```text
Cloudflare Workers AI
@cf/black-forest-labs/flux-2-klein-4b
```

Flow:

```text
Egg element + run seed
        ↓
PetIdentity + initial PetGenome
        ↓
Mythic infant prompt
        ↓
Cloudflare Workers AI
        ↓
PNG cached in user://pet_renders
```

The first image uses no reference image and becomes the visual origin for later evolution edits.

The provider boundary remains `PetRenderer`, so Cloudflare can later be replaced with a paid API without changing M1–M4.

## Local development credentials

No Cloudflare secret is stored in the repository.

Godot reads:

```text
CLOUDFLARE_ACCOUNT_ID
CLOUDFLARE_API_TOKEN
```

from the environment.

The token must have Workers AI permissions.

This direct client-to-provider path is for development only. A production game must later use a backend/proxy so players never receive the provider token.

## Current M6 output

- model: FLUX.2 Klein 4B
- width: 1024
- height: 1024
- result cached as PNG
- infant render uses text-to-image
- image-edit mode remains reserved for the next milestone

## Test status

Local testing is active. Fix parser/runtime issues from the lowest milestone upward before changing higher-level behavior.
