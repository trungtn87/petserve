class_name PetAppearanceProfile
extends Resource
## Palette for the Moonwhisker v4 topology. No simulation or save state.
@export var id: StringName = &"moon_shadow"
@export var fur_color: Color = Color("515366")
@export var accent_color: Color = Color("665080")
@export var chest_color: Color = Color("8a8199")
@export var inner_ear_color: Color = Color("965b89")
@export var iris_color: Color = Color("874be1")
@export var iris_lower_color: Color = Color("65dfec")
@export var rune_color: Color = Color("bda4ff")
@export_range(0.0, 2.0) var rune_energy: float = 0.8
