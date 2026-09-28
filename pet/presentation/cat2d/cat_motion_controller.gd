class_name CatMotionController
extends RefCounted
## Sole owner of pivot transforms: no competing per-frame tweens.
var time: float = 0.0
var rest_amount: float = 0.0
var sleep_amount: float = 0.0
var reaction: float = 0.0

func react() -> void:
	reaction = 1.0

func tick(delta: float, action: StringName, expression: StringName, profile: CatPresentationProfile, pivots: Dictionary, bases: Dictionary) -> void:
	time += delta
	var blend: float = 1.0 - exp(-delta * 7.0)
	rest_amount = lerpf(rest_amount, 1.0 if action in [&"lie", &"sleep"] else 0.0, blend)
	sleep_amount = lerpf(sleep_amount, 1.0 if action == &"sleep" else 0.0, blend)
	reaction = maxf(0.0, reaction - delta * 2.5)
	for key: StringName in pivots:
		var pivot: Node2D = pivots[key]
		pivot.position = bases[key]
		pivot.rotation = 0.0
		pivot.scale = Vector2.ONE
	var breath: float = sin(time * lerpf(2.0, 1.2, sleep_amount)) * profile.breath_amount
	var body: Node2D = pivots.get(&"body")
	if body != null:
		body.scale.y = 1.0 + breath
	var head: Node2D = pivots.get(&"head")
	if head != null:
		head.position += profile.lie_head_offset * rest_amount
		head.position.y += -breath * 65.0 - sin(reaction * PI) * 9.0
		var tilt: float = -3.0 if expression == PetState.STATE_CURIOUS else 0.0
		head.rotation = deg_to_rad(tilt * (1.0 - sleep_amount) + profile.sleep_head_degrees * sleep_amount)
		if action == &"eat":
			head.position.y += 17.0 + sin(time * 9.0) * 3.0
			head.rotation += deg_to_rad(6.0 + sin(time * 9.0) * 2.0)
	var tail: Node2D = pivots.get(&"tail")
	if tail != null:
		tail.rotation = deg_to_rad(sin(time * 1.45) * profile.tail_degrees * (1.0 - sleep_amount * 0.8) - rest_amount * 12.0)
	for key: StringName in [&"ear_left", &"ear_right"]:
		var ear: Node2D = pivots.get(key)
		if ear != null:
			var twitch: float = pow(maxf(0.0, sin(time * 0.85)), 16.0) * sin(time * 22.0)
			ear.rotation = deg_to_rad(twitch * profile.ear_degrees * (1.0 - sleep_amount))
	var fx: Node2D = pivots.get(&"fx")
	if fx != null:
		fx.position.y += sin(time * 0.8) * 4.0
		fx.modulate.a = profile.fx_opacity * (0.85 + sin(time * 1.1) * 0.15)
