# M1 — PetIdentity + PetSceneProfile

Status: implemented on the evolution main line.

## Purpose

M1 now creates the stable identity of one pet life together with a stable PetHome scene identity.

The pet identity remains:

- `pet_id`
- `species`
- `element`
- `lineage_seed`
- `generation`

The scene companion profile is derived deterministically from that identity:

- `environment_theme`
- `environment_variant`
- `palette_id`
- `palette_description`
- `lighting_theme`
- `motif_id`
- `motif_description`
- `scene_seed`

## Stability rule

For one pet life:

```text
PetIdentity
+ PetSceneProfile
      stay stable
          ↓
Genome / Evolution / Visual layers may change
```

The scene profile is not a second AI render. It is prompt data that makes the pet and its PetHome environment belong to the same visual world.

## Initial creation

The current first species is `cat`.

```text
run_seed + species + element + generation
        ↓
PetIdentity
        ↓
PetSceneProfileFactory
        ↓
stable world palette / environment / lighting / motif
```

The seven current elements are supported:

- metal
- wood
- water
- fire
- earth
- dark
- light

Each element has multiple deterministic environment, palette, lighting and motif variants. Different pet lives therefore receive different scene combinations while the same life always reconstructs the same profile.

## Files

```text
features/evolution/domain/pet_identity.gd
features/evolution/domain/pet_identity_factory.gd
features/evolution/domain/pet_scene_profile.gd
features/evolution/domain/pet_scene_profile_factory.gd
tools/test_pet_identity.gd
tools/test_pet_scene_profile.gd
```

## Pass criteria

M1 passes when:

1. All seven elements create a valid identity and scene profile.
2. Same pet life always creates the same `pet_id` and same scene profile.
3. Different lineage seeds create different pet IDs and different scene seeds.
4. Identity and scene profile both serialize/deserialize exactly.
5. Invalid identity input is rejected.
6. No renderer/provider dependency exists inside M1.

## Headless tests

```bash
godot --headless --path . --script res://tools/test_pet_identity.gd
godot --headless --path . --script res://tools/test_pet_scene_profile.gd
```

Expected:

```text
M1 PetIdentity: PASS
M1 PetSceneProfile: PASS
```
