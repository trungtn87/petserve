# M4 — Visual Spec + Mythic Elemental Prompt

Status: visual direction revised after M6 reference review.

## Locked art family

```text
mythic_elemental_chibi_v1
```

The visual target is a soft mythic elemental pet, not a full-body galaxy creature.

Core traits:
- cute infant/chibi proportions;
- large glossy eyes;
- plush layered fur;
- polished semi-3D painterly game art;
- restrained magical atmosphere;
- one readable elemental lineage;
- clean silhouette;
- no full-body starfield/nebula texture.

## Seven elemental lineage anchors

Each base pet may use stable element identity cues even before any mutation:

```text
palette
+ eye color
+ one small forehead lineage sigil
+ one restrained tail-centered effect
```

These are lineage anchors, not mutations.

This allows the seven infant cats to be visually recognizable while their M2 genome still remains:

```text
stage = 1
body_growth = 0
traits = base
mutations = []
```

## Stable-rule decision

M3 mutation IDs such as `galaxy_eye_ring` are retained internally for now to avoid destabilizing the completed rule layer.

M4 visual wording no longer interprets those IDs literally as galaxy art. For example:

```text
galaxy_eye_ring
→ thin mystical elemental iris ring
→ explicitly no galaxy texture
```

This preserves gameplay data while allowing the art direction to evolve independently.

## Prompt contract

Evolution edits keep the same structure:

```text
[IDENTITY LOCK]
[MYTHIC ELEMENTAL STYLE]
[CURRENT FORM]
[CHANGE ONLY]
[PRESERVE]
```

The previous pet image remains the source of truth for every evolved visual.
