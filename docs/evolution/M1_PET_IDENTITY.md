# M1 — PetIdentity

Status: implemented on `feat/evolution-m1-pet-identity`

## Purpose

M1 defines the stable identity of one pet life. Evolution visuals, genome values, stage growth and mutation data are intentionally not part of identity.

A pet may change appearance many times while these values remain fixed:

- `pet_id`
- `species`
- `element`
- `lineage_seed`
- `generation`

## Identity rule

For one pet life:

```text
PetIdentity
    stays fixed
        ↓
future Genome / Evolution / Visual layers may change
```

The renderer must never be allowed to replace PetIdentity.

## Initial creation

The current first species is `cat`.

The initial pet identity can be deterministically created from:

```text
run_seed + species + element + generation
```

Example:

```text
species       = cat
element       = dark
lineage_seed  = 7281
generation    = 0

pet_id = cat_dark_7281_g0
```

The seven existing egg elements are accepted by the identity layer:

- metal
- wood
- water
- fire
- earth
- dark
- light

PetIdentity itself does not hard-code an element registry. Element validity/content rules belong to a later content/rule layer so adding a future element does not require editing identity core.

## Files

```text
features/evolution/domain/pet_identity.gd
features/evolution/domain/pet_identity_factory.gd
tools/test_pet_identity.gd
```

## Pass criteria

M1 passes when:

1. All seven current elements can create a valid cat identity.
2. Same inputs always produce the same `pet_id`.
3. Different lineage seed produces a different `pet_id`.
4. Different element produces a different `pet_id`.
5. Serialization round-trip preserves identity exactly.
6. Invalid seed/element/generation is rejected.
7. No 3D/2.5D/pet-interaction code is reintroduced.

## Manual/headless test

When a Godot executable is available:

```bash
godot --headless --path . --script res://tools/test_pet_identity.gd
```

Expected output:

```text
M1 PetIdentity: PASS
```

M1 does not yet connect identity into Hatch runtime. That integration is intentionally deferred until the identity domain is stable.
