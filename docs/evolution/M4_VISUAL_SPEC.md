# M4 — Visual Spec + Mythic PetHome Prompt

## Locked art family

```text
mythic_elemental_chibi_v1
```

The renderer now produces one coherent PetHome artwork per life stage:

```text
pet + matching environment = one AI image
```

It does not render a pet asset and a background asset separately.

## Inputs

M4 combines:

- `PetIdentity`
- `PetSceneProfile`
- `PetGenome`
- Mythic style profile
- species profile

The scene profile contributes stable world identity:

- environment
- palette
- lighting
- motif
- scene seed

The genome contributes the current biological/evolution state.

## Initial prompt contract

```text
[INITIAL IDENTITY]
[MYTHIC ELEMENTAL STYLE]
[INFANT FORM]
[PETHOME WORLD]
[COMPOSITION]
[UI SAFE LAYOUT]
[EVOLUTION SPACE]
```

The PetHome world must be visible in the same image as the pet.

The composition reserves low-detail areas for runtime UI:
- upper region: name / stage / growth / food;
- lower region: three PetHome menu buttons.

No text, UI, frame or interface artwork is generated into the image.

## Evolution continuity

Later evolution renders must use the previous PetHome image as the visual reference. The pet remains the same individual and the scene keeps the same world identity while stage, mutation and maturity may change.

This keeps the cost model:

```text
one hatch = one AI image
one evolution = one AI image
```
