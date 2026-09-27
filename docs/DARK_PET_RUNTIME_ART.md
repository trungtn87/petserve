# Runtime art integration milestone

Dark Pet now supports a production-art slot without coupling gameplay to artwork.

- `DarkPetActor` checks for `assets/pets/dark/runtime/dark_pet_base.png` at runtime.
- When present, it becomes the visible pet artwork automatically.
- When absent, the technical placeholder is retained so development can continue without broken resources.
- Tap interaction and state reactions continue to run through the reusable PetActor/Behavior framework.
- The next visual milestone is a modular native-Godot rig with separate layers for eyes, ears, tail and expression overlays.
