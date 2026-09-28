# Dark cat stage 1 — cutout atlas

Reference: user's `1000002323.jpg`, slate/violet fluffy moon kitten.
Tool: built-in image generation; transparent background; two passes.
Final original RGBA retained unmodified as `parts_atlas.png`.
Placement/regions are configured in the profile, not baked into runtime code.

## Prompt brief, pass 1

Production 2.5D cutout puppet parts atlas closely matching reference. Square,
preferably 2048x2048, true transparent background, 4×4 equal cells, no lines/text,
centered parts, wide transparent margins, no overlap. Silky slate blue-purple
fur, cyan-violet eyes, pink ears, upper-left soft rendered lighting, fixed
three-quarter view facing right. Row-major parts: torso with four paws and neck
extension, no head/tail; round head with continuous fur where eyes/mouth were,
retain nose/muzzle, no ears/crescent; curved upright fluffy tail; left ear;
right ear; left open jewel eye; narrower right eye; left closed lid; right
closed lid; neutral mouth line; eating mouth/tongue; glowing crescent; wispy
violet smoke; low lying body with tucked paws, no head/tail; happy mouth;
sparkles. One isolated part per cell, clean alpha edges, opaque fur interiors.

## Prompt brief, pass 2

Edit layout only; preserve same 16 parts, fur, shading and details. Repack strict
4×4 grid with 15% transparent padding per side; shrink parts to central 70% of
each cell; no touching or boundary crossing. Same ordering; no labels, grid,
frames, checkerboard, opaque background or assembled character.

The generator returned 1254×1254 with nonuniform positions. The final profile
uses measured regions so rendering does not depend on a perfect grid.
