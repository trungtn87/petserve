# M5 + M6 — Godot Initial Mythic Pet Render

## Goal

Generate one complete infant pet directly inside the Godot pipeline without any sample/reference image.

```text
NO SOURCE IMAGE
      ↓
Identity + initial Genome
      ↓
Mythic Elemental infant prompt
      ↓
text-to-image renderer
      ↓
PNG
      ↓
Godot TextureRect
```

## Infant data contract

The infant is still the least-developed pet state:

```text
stage = 1
body_growth = 0.0
traits = base
mutations = []
```

Element identity is visual lineage metadata, not a mutation. The initial image may therefore contain:
- element-specific base palette;
- element-specific eye color;
- exactly one small lineage sigil;
- one restrained tail-centered elemental effect.

It must not contain advanced mutation features.

## Target cat form

The first cat image should resemble a premium soft mythical game mascot:
- compact kitten body;
- rounded slightly oversized head;
- short legs;
- huge glossy expressive eyes;
- small triangular ears;
- plush soft fur;
- one fluffy tail;
- front three-quarter standing pose;
- transparent background;
- no props or scenery.

## Seven base looks

- Metal: silver-gray + cool blue, tiny crystal cues.
- Wood: cream/tan + leaf green, small leaf cues.
- Water: pearl white + aqua/cyan, water wisps/droplets.
- Fire: cream + orange/red, restrained flame tail.
- Earth: tan/umber + olive, mineral dust/tiny pebbles.
- Dark: smoky charcoal-indigo + violet, purple shadow mist and crescent lineage sigil.
- Light: ivory/pearl + pale gold, soft radiant tail and luminous sigil.

## Renderer

Development config:

```text
initial_model = gpt-image-2.5-sunburst
edit_model    = gpt-image-2.5-sunburst
size          = 1024x1024
quality       = high
background    = transparent
output_format = png
```

No API key is committed. Godot reads `OPENAI_API_KEY` from the environment.

## Expected live result

```text
Egg/Hatch
   ↓
CAT + current element
   ↓
Mythic Elemental infant prompt
   ↓
one transparent PNG
   ↓
image visible in Godot
   ↓
that image becomes the visual origin for later image edits
```
