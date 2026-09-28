# Cat 2.5D Framework — Reference Pack 01

Implemented against `main` at `65fb388`. The primary Pet Home uses a fixed-camera,
Godot-native layered cat. The 3D scenes remain available for R&D.

## Runtime

`GameApp → pet_home_2_5d.tscn → PetDefinition → PetActorHost → CatPet2D`

Shared scene: `scenes/pet/actors/cat_pet_2_5d.tscn`. Logical draw groups:
BackFX, Tail, Body, Head, Face, FrontFX. Face/ear pivots are children of the
head pivot; profile z values control overlap. Shared components in
`pet/presentation/cat2d/`:

- `CatPresentationProfile`: atlas, regions, widths, pivots, hierarchy, variants,
  motion/FX parameters and hit area.
- `CatPet2D`: PetActor contract, visual-pack swapping, bounded touch/click input
  and temporary presentation actions.
- `CatMotionController`: sole owner of pivot transforms, breathing, head tilt,
  eating bob, ear twitch, tail sway, resting transition, tap bounce and smoke.
- `CatFaceController`: blinking, gaze, sleepy/surprised eyes, mouth variants
  and closed sleeping eyes.

Core/domain/egg/save code has no element-specific changes. `GameApp` only
changes its destination scene. Existing `PetState` and `PetBehaviorController`
provide idle expressions. Rest/eating temporarily suspend idle selection.
Menu actions are presentation commands, **not inventory, hunger simulation,
or persisted sleep state**.

## Try it

- F6 on `scenes/pet/pet_home_2_5d.tscn`: direct visual test.
- F5: existing egg screen and transition into the new Pet Home.
- Tap pet: wake + happy bounce. Background taps do nothing.
- Menu → Thức ăn: short eating animation, then idle.
- Menu → Nằm nghỉ / Ngủ: persistent pose until pet tap or Đánh thức.
- Other existing menu entries remain gameplay placeholders.

An idle sleepy expression is distinct from the explicit persistent sleep action.

## Add an element or evolved stage

1. Put a transparent parts atlas in `assets/pets/cat/<element>/stage_N/`.
2. Duplicate `data/pet/cat/dark/stage_1.tres` and set id/atlas/part regions.
3. Configure `region`, `width`, `pivot`, `offset`, `parent`, `group`, optional
   `z`. Body pivot is at the feet and texture is bottom-aligned. Face and ears
   follow the head pivot. Use overlapping fur around joints.
4. Optional variants: `eye_left_closed`, `eye_right_closed`, `mouth_eat`,
   `mouth_happy`, `body_lie`.
5. Point a PetDefinition at the shared actor scene and new profile. Set
   capabilities: `tap_reaction`, `look_target`, `eat`, `lie`, `sleep`.
6. Assign it to `CatHomeScreen.pet_definition`, or apply a new visual stage
   with `actor.set_profile(new_profile)`.

These are pet appearance stages, not the four egg incubation stages. New
content using the same rig needs no Core edits or controller clones. Different
anatomy may require another shared rig.

Validation rejects out-of-atlas regions, missing body/head, bad parent links,
cycles, unknown groups and invalid basic timing/scale. Optional parts can be
omitted. Textures are allocated only on profile application and reused during
frame updates. Swaps free the old hierarchy. The atlas uses measured regions,
not assumed grid cells.

## Art and limits

Dark Pack 01 was generated using the user's `1000002323.jpg` concept and the
built-in image generator, then calibrated in Godot. Asset:
`assets/pets/cat/dark/stage_1/parts_atlas.png`, 1254×1254 RGBA.
Prompt brief: `assets/pets/cat/dark/stage_1/ART_NOTES.md`.

This first working pack uses painted parts for the soft rendered appearance;
it is not an exact reconstruction. Lying uses a low body variant and lowered
head; major turns or evolved silhouettes need additional art. No runtime 3D,
Live2D, Spine, Rive, or free camera. Android hardware performance is unmeasured.

## Verification

Godot 4.6.1 Compatibility:

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tools/test_cat_2_5d.gd
godot --headless --path . --quit-after 60
godot --path . --script res://tools/capture_cat_2_5d.gd
```

Checks: mounting, hierarchy, atlas bounds, invalid hierarchy, eat completion,
persistent rest/sleep, waking, optional parts, repeated profile swaps,
background/pet hit tests, duplicate mouse/touch suppression, home routing.
Rendered idle/eat/lie/sleep/wake/menu with Mesa software OpenGL.
Previews: `docs/previews/cat2d/`, including `pet_2_5d.mp4`.

Baseline editor import reports an invalid old reference PNG and incomplete
Android export preset; neither blocks the new scene or main-game smoke test.
No APK build is claimed by this change.
