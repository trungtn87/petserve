class_name GeneExpressionScale
extends RefCounted

const NONE: StringName = &"none"
const TRACE: StringName = &"trace"
const DEVELOPING: StringName = &"developing"
const EXPRESSED: StringName = &"expressed"
const DOMINANT: StringName = &"dominant"
const ASCENDED: StringName = &"ascended"

const TRACE_MIN: float = 1.0
const DEVELOPING_MIN: float = 25.0
const EXPRESSED_MIN: float = 60.0
const DOMINANT_MIN: float = 120.0
const ASCENDED_MIN: float = 200.0

static func tier_for_score(score: float) -> StringName:
	if score >= ASCENDED_MIN:
		return ASCENDED
	if score >= DOMINANT_MIN:
		return DOMINANT
	if score >= EXPRESSED_MIN:
		return EXPRESSED
	if score >= DEVELOPING_MIN:
		return DEVELOPING
	if score >= TRACE_MIN:
		return TRACE
	return NONE

static func next_threshold(score: float) -> float:
	var tier := tier_for_score(score)
	match tier:
		NONE:
			return TRACE_MIN
		TRACE:
			return DEVELOPING_MIN
		DEVELOPING:
			return EXPRESSED_MIN
		EXPRESSED:
			return DOMINANT_MIN
		DOMINANT:
			return ASCENDED_MIN
		_:
			return 0.0

static func tier_label_vi(tier: StringName) -> String:
	match tier:
		TRACE:
			return "Mầm"
		DEVELOPING:
			return "Đang phát triển"
		EXPRESSED:
			return "Biểu hiện rõ"
		DOMINANT:
			return "Đặc trưng"
		ASCENDED:
			return "Cực đại"
		_:
			return "Chưa biểu hiện"
