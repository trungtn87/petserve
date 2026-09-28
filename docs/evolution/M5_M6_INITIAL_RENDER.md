# M5 + M6 — Godot Initial Pet Render

Status: implemented on `feat/evolution-m5-m6-initial-render`

## Goal

Create the first complete infant-pet visual flow inside Godot without using any sample/reference pet image.

This milestone proves the special first-image path:

```text
NO SOURCE IMAGE
      ↓
Identity + initial Genome
      ↓
Galaxy infant prompt
      ↓
text-to-image renderer
      ↓
PNG
      ↓
Godot TextureRect
```

Later evolution images will use the generated PNG as the source image.

## Why infant is the correct first render

The infant carries the least developed genome state:

```text
stage = 1
body_growth = 0.0

fur   = base
eyes  = base
ears  = base
tail  = base
mark  = base

mutations = []
```

M6 rejects the initial render spec if stage/growth/mutation data already represents an evolved form.

This makes the first image a clean visual origin rather than an already over-designed final form.

## Godot runtime integration

`GameApp` now routes Hatch to:

```text
res://scenes/evolution_initial.tscn
```

The screen:

1. reloads the current Egg save;
2. reloads the confirmed Hatch/name save;
3. verifies both saves use the same run_seed;
4. creates deterministic PetIdentity;
5. creates the initial PetGenome;
6. builds a species-specific infant visual spec;
7. builds a text-only render request;
8. reuses a cached image if this exact pet already has one;
9. otherwise sends the render request when a dev API key exists;
10. saves and displays the returned PNG.

## M5 render contract

```text
PetRenderRequest
├── mode
├── pet_id
├── positive_prompt
├── negative_prompt
├── source_image_path
├── target_region
├── edit_strength
└── output_key

PetRenderer
        ↓
PetRenderResult
```

Two modes are reserved:

```text
INITIAL_TEXT_TO_IMAGE
EVOLUTION_IMAGE_EDIT
```

M5/M6 implement the first mode end-to-end. The second mode remains reserved for the next evolution-image milestone.

## M6 initial cat profile

The initial cat is deliberately simple:

- baby/infant body proportions;
- slightly oversized rounded head;
- large expressive eyes;
- short legs;
- small triangular ears;
- one simple fluffy tail;
- soft plush fur;
- no mutation marks;
- no split tail;
- no eye galaxy ring mutation;
- no glowing-paw mutation;
- no astral mane;
- no forehead mutation.

The element still contributes its Galaxy palette. A Dark infant therefore receives indigo/violet/blue-black/cold-cyan accents without being given later Dark mutations.

## Provider adapter

The local development adapter targets the Images generation endpoint configured in:

```text
data/evolution/render/openai_dev.json
```

Default initial-generation settings:

```text
model      = gpt-image-2.5-flare
size       = 1024x1024
quality    = high
background = transparent
format     = png
```

The API response is decoded from base64, validated as PNG, written to `user://pet_renders`, loaded into an ImageTexture, and shown directly by Godot.

## API-key rule

No secret is committed.

The development adapter reads:

```text
OPENAI_API_KEY
```

from the process environment.

If absent:

```text
Godot screen still opens
→ prompt is visible
→ Generate button remains available
→ request returns a clear missing-key error
```

Production Android must use a backend/proxy. Do not place a permanent provider API key in the APK.

## Persistence

Successful generation writes:

```text
user://evolution_pet_v1.json
```

with:

- PetIdentity;
- PetGenome;
- pet name;
- current PetVisualRecord.

The PNG itself is stored under:

```text
user://pet_renders/
```

This prevents re-render cost every time the scene opens.

## Test note

Local test is deferred.

Contract test:

```bash
godot --headless --path . --script res://tools/test_initial_render_contract.gd
```

Full live test requires `OPENAI_API_KEY` and running the normal Hatch flow.

Expected first live result:

```text
Egg/Hatch
   ↓
CAT + current element
   ↓
Galaxy infant prompt
   ↓
one transparent PNG
   ↓
image visible inside Godot
```
