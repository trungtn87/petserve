# Dark Pet Runtime Asset

`dark_pet_base.png` is the first runtime visual prepared from the Flow concept image.

The project intentionally keeps runtime art separate from reference sheets:

- `runtime/` = files loaded by Godot.
- `reference/` = visual direction only.

## Current reference implementation

Dark Pet already supports reusable runtime behavior through `PetActor`:

- ambient idle motion
- ear movement
- tail movement
- state presentation
- tap interaction -> happy reaction

The temporary Polygon2D visual remains as fallback until `dark_pet_base.png` is copied into this folder and the Sprite2D rig is enabled. This separation prevents reference/composite artwork from accidentally becoming production runtime art.
