extends Resource
## Species-specific limits and semantic bone mapping. Radians are internal only.
@export var neck: StringName = &"Neck"
@export var head: StringName = &"Head"
@export var ears: Array[StringName] = [&"Ear_L", &"Ear_R"]
@export var tail: Array[StringName] = [&"Tail_01", &"Tail_02", &"Tail_03", &"Tail_04"]
@export_range(0.0, 30.0) var yaw_degrees: float = 16.0
@export_range(0.0, 20.0) var pitch_degrees: float = 10.0
@export_range(0.0, 10.0) var tilt_degrees: float = 4.0
@export_range(0.0, 10.0) var ear_degrees: float = 4.0
@export_range(0.0, 10.0) var tail_degrees: float = 5.0
@export_range(0.0, 3.0) var breath_degrees: float = 1.2
@export_range(0.1, 10.0) var follow_response: float = 4.5
## Imported reference head uses local +Z forward, +Y up.
