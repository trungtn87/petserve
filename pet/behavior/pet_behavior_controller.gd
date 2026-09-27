class_name PetBehaviorController
extends RefCounted


var _random: RandomNumberGenerator = RandomNumberGenerator.new()
var _idle_elapsed: float = 0.0
var _next_idle_delay: float = 0.0


func _init() -> void:
	_random.randomize()
	_schedule_next_idle()


func reset() -> void:
	_idle_elapsed = 0.0
	_schedule_next_idle()


func tick(delta: float) -> StringName:
	_idle_elapsed += maxf(delta, 0.0)
	if _idle_elapsed < _next_idle_delay:
		return &""

	_idle_elapsed = 0.0
	_schedule_next_idle()
	return _pick_idle_state()


func react_to_tap() -> StringName:
	return PetState.STATE_HAPPY


func _schedule_next_idle() -> void:
	_next_idle_delay = _random.randf_range(2.5, 5.5)


func _pick_idle_state() -> StringName:
	var roll: float = _random.randf()
	if roll < 0.45:
		return PetState.STATE_CURIOUS
	if roll < 0.70:
		return PetState.STATE_SLEEPY
	return PetState.STATE_NEUTRAL
