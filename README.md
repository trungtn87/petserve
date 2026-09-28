# Pet Vô Hạn — Evolution Core

Godot Android portrait project.

## Current visual direction

The base art direction is now:

```text
MYTHIC ELEMENTAL CHIBI
```

not full-body Galaxy.

Target infant look:
- very cute kitten proportions;
- slightly oversized rounded head;
- compact body and short legs;
- large glossy expressive eyes;
- plush layered fur;
- polished soft semi-3D illustration;
- clean readable silhouette;
- restrained mythic effects;
- element identity concentrated in palette, eyes, one small forehead lineage sigil and a tail-centered effect.

The seven base element families are:
- metal;
- wood;
- water;
- fire;
- earth;
- dark;
- light.

Internal M3 mutation IDs are intentionally unchanged so the stable rule layer does not move just because visual wording changes.

## Current runtime

M5 + M6 are wired into Godot:

```text
Egg element + run seed
        ↓
PetIdentity + initial PetGenome
        ↓
Mythic infant visual spec
        ↓
text-to-image request
        ↓
PNG cached in user://pet_renders
```

The first pet image still uses **no reference image**. That image becomes the visual origin for every later evolution edit.

The development renderer now uses `gpt-image-2.5-sunburst` for the initial base image because the first image is the most important identity anchor.

No API key is stored in the repository. The development adapter reads `OPENAI_API_KEY` from the environment.

## Test status

M1–M6 include headless/runtime test hooks. Local execution remains deferred until convenient.
