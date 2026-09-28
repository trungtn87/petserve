class_name CatPresentationProfile
extends Resource
## Shared, data-only cutout rig. Parts use atlas regions or independent textures.
## Known slots: body, head, tail, ear_left/right, eye_left/right, mouth, mark, fx.
@export var id: StringName = &""
@export var atlas: Texture2D
@export var parts: Dictionary = {}
@export var variants: Dictionary = {}
@export var display_scale: float = 0.65
@export var hit_rect: Rect2 = Rect2(-145, -360, 310, 365)
@export var breath_amount: float = 0.012
@export var tail_degrees: float = 5.0
@export var ear_degrees: float = 3.0
@export var blink_range: Vector2 = Vector2(2.8, 5.5)
@export var look_radius: float = 3.0
@export var eat_seconds: float = 3.5
@export var lie_head_offset: Vector2 = Vector2(16, 65)
@export var sleep_head_degrees: float = 7.0
@export var fx_opacity: float = 0.35

func is_valid() -> bool:
	if id.is_empty() or atlas == null or not parts.has(&"body") or not parts.has(&"head"):
		return false
	if display_scale <= 0.0 or blink_range.x <= 0.0 or blink_range.y < blink_range.x or eat_seconds <= 0.0:
		return false
	var bounds := Rect2(Vector2.ZERO, atlas.get_size())
	for key: StringName in parts:
		if not parts[key] is Dictionary:
			return false
		var part: Dictionary = parts[key]
		if not part.get("region") is Rect2 or float(part.get("width", 100.0)) <= 0.0:
			return false
		var region: Rect2 = part["region"]
		if not region.has_area() or not bounds.encloses(region):
			return false
		if not part.get("group", "Body") in ["BackFX", "Tail", "Body", "Head", "Face", "FrontFX"]:
			return false
		var seen: Array[StringName] = [key]
		var parent: StringName = part.get("parent", &"")
		while not parent.is_empty():
			if parent in seen or not parts.has(parent) or not parts[parent] is Dictionary:
				return false
			seen.append(parent)
			parent = parts[parent].get("parent", &"")
	for region: Rect2 in variants.values():
		if not region.has_area() or not bounds.encloses(region):
			return false
	return true

func texture_for(region: Rect2) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = atlas
	texture.region = region
	texture.filter_clip = true
	return texture
