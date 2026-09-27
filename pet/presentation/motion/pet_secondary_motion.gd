extends RefCounted
## Analytic damped response: stable with different frame rates; no accumulating pose.
var clock: float = 0.0
var reaction_age: float = 10.0
var cooldown: float = 0.0
var twitch_age: float = 10.0
var next_twitch: float = 2.0
var twitch_side: int = 0
var rng := RandomNumberGenerator.new()

func _init(seed_value: int = 731) -> void:
	rng.seed = seed_value # Presentation-only RNG, independent of life/game RNG.

func react() -> bool:
	if cooldown > 0.0:
		return false
	reaction_age = 0.0
	cooldown = 0.6
	return true

func step(delta: float, attentive: bool) -> void:
	clock += delta
	reaction_age += delta
	cooldown = maxf(0.0, cooldown - delta)
	twitch_age += delta
	next_twitch -= delta
	if next_twitch <= 0.0:
		twitch_age = 0.0
		twitch_side = rng.randi_range(0, 1)
		next_twitch = rng.randf_range(3.0, 7.0) if attentive else rng.randf_range(2.0, 5.0)

func envelope() -> float:
	# Smooth anticipation -> peak -> recovery. Zero slope at both endpoints.
	if reaction_age >= 1.8:
		return 0.0
	if reaction_age < 0.25:
		return smoothstep(0.0, 0.25, reaction_age)
	return 1.0 - smoothstep(0.25, 1.8, reaction_age)

func ear_offset(side: int, amount: float) -> float:
	var offset := sin(clock * 0.7 + float(side) * 1.7) * amount * 0.12
	var age := twitch_age - float(side) * 0.09
	if side == twitch_side and age > 0.0 and age < 0.6:
		offset += sin(age / 0.6 * PI) * amount * 0.5
	var response_age := reaction_age - float(side) * 0.12
	if response_age > 0.0 and response_age < 2.0:
		offset += sin(response_age * 5.0) * exp(-response_age * 2.5) * amount
	return clampf(offset, -amount, amount) * (1.0 if side == 0 else -1.0)

func tail_offset(index: int, amount: float) -> float:
	var phase := clock * 1.3 - float(index) * 0.4
	var idle := sin(phase) * amount * 0.3
	var age := reaction_age - float(index) * 0.10
	var response := 0.0
	if age > 0.0 and age < 3.0:
		response = sin(age * 6.0) * exp(-age * 1.5) * amount * 0.65
	return clampf(idle + response, -amount, amount)
