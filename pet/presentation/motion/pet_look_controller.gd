extends RefCounted
## Solves a world target in the head's REST frame, never its already-rotated pose.
var angles := Vector2.ZERO # pitch, yaw
var remaining: float = 0.0
var target_world := Vector3.ZERO

func focus(point: Vector3, seconds: float = 3.0) -> void:
	target_world = point
	remaining = maxf(seconds, 0.0)

func clear() -> void:
	remaining = 0.0
	angles = Vector2.ZERO

func step(delta: float, head_frame: Transform3D, profile: Resource) -> void:
	var desired := Vector2.ZERO
	if remaining > 0.0:
		remaining = maxf(0.0, remaining - delta)
		var local := head_frame.affine_inverse() * target_world
		# Behind the head: release attention rather than twisting to a clamp edge.
		if local.length_squared() > 0.0001 and local.z > 0.0:
			desired.y = clampf(atan2(local.x, local.z), -deg_to_rad(profile.yaw_degrees), deg_to_rad(profile.yaw_degrees))
			desired.x = clampf(-atan2(local.y, Vector2(local.x, local.z).length()), -deg_to_rad(profile.pitch_degrees), deg_to_rad(profile.pitch_degrees))
	angles = angles.lerp(desired, 1.0 - exp(-profile.follow_response * delta))
