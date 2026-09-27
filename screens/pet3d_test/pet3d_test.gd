extends Node3D

@onready var pet: DarkPet3D = $DarkPet3D
@onready var camera: Camera3D = $Camera3D

func _process(_delta: float) -> void:
	var mouse := get_viewport().get_mouse_position()
	var origin := camera.project_ray_origin(mouse)
	var direction := camera.project_ray_normal(mouse)
	var plane := Plane(Vector3.FORWARD, 0.0)
	var target = plane.intersects_ray(origin, direction)
	if target != null:
		pet.set_look_target(target)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pet.react_to_touch()
	elif event is InputEventScreenTouch and event.pressed:
		pet.react_to_touch()
