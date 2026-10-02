extends RefCounted

# Species-aware translation layer for visual Genes.
# Gameplay Gene meanings stay shared, but render instructions are adapted to
# anatomy so the same direction never forces every species into one body plan.

const FAMILY_FURRED := "furred_quadruped"
const FAMILY_HOOFED := "hoofed"
const FAMILY_AVIAN := "avian"
const FAMILY_REPTILE := "reptile"

const STRUCTURAL_LOCI := [
	"body",
	"structure",
	"ears",
	"tail",
	"mane",
	"paws",
	"fur",
]


func family_for(
	species: StringName
) -> String:
	match species:
		&"bird", &"phoenix":
			return FAMILY_AVIAN
		&"lizard", &"dragon":
			return FAMILY_REPTILE
		&"horse", &"qilin", &"deer":
			return FAMILY_HOOFED
		_:
			return FAMILY_FURRED


func anatomy(
	species: StringName
) -> String:
	match species:
		&"cat":
			return "recognizable feline anatomy: one cat head, four natural legs, two feline ears and exactly one tail"
		&"dog":
			return "recognizable canine anatomy: one dog head and muzzle, four natural legs, two canine ears and exactly one tail"
		&"fox":
			return "recognizable fox anatomy: one narrow fox head, four light legs, two large fox ears and exactly one tail"
		&"bear":
			return "recognizable bear anatomy: one broad bear head, four sturdy legs, two rounded ears and one short tail"
		&"rabbit":
			return "recognizable rabbit anatomy: one rabbit head, four limbs, two long rabbit ears and one small tail"
		&"lizard":
			return "recognizable lizard anatomy: one reptilian head, four legs, scale-covered body and exactly one long tail; no mammalian ears or fur"
		&"dragon":
			return "recognizable dragon anatomy: one dragon head, four legs and exactly one tail; wings or major horns only when separately authorized by code"
		&"bird":
			return "recognizable bird anatomy: one bird head and beak, two legs, exactly one pair of wings and one tail-feather assembly; no mammalian ears"
		&"phoenix":
			return "recognizable phoenix anatomy: one divine-bird head and beak, two legs, exactly one pair of wings and one decorative tail-feather assembly"
		&"horse":
			return "recognizable horse anatomy: one equine head, two ears, four hoofed legs, natural mane and exactly one tail"
		&"qilin":
			return "recognizable qilin anatomy: one divine-beast head, two ears, four hoofed legs, one tail and only the sacred horn plan authorized for this individual"
		&"deer":
			return "recognizable deer anatomy: one small cervid head, two ears, four fine legs and one short tail; antlers only when separately authorized"
		_:
			return "one recognizable species-appropriate body using only its natural or code-authorized anatomy"


func is_structural_locus(
	locus: String
) -> bool:
	return STRUCTURAL_LOCI.has(
		locus
	)


func birth_expression(
	species: StringName,
	profile: Dictionary
) -> String:
	var family := family_for(
		species
	)
	var frame_key := String(
		profile.get(
			"frame_key",
			"balanced_athletic"
		)
	)
	var frame := _frame_for_family(
		family,
		frame_key
	)
	var head := String(
		profile.get(
			"head_character",
			"balanced youthful head"
		)
	)
	var surface := _surface_expression(
		family,
		String(
			profile.get(
				"surface_flow",
				"smooth directional surface flow"
			)
		)
	)
	var appendage := _appendage_expression(
		family,
		String(
			profile.get(
				"appendage_character",
				"balanced"
			)
		)
	)
	var temperament := String(
		profile.get(
			"temperament",
			"calm"
		)
	)

	return (
		"%s. Head impression: %s. %s. %s. "
		+ "Temperament reads as %s. All of these are variations inside normal %s anatomy, not permission to hybridize the species."
	) % [
		frame,
		head,
		surface,
		appendage,
		temperament,
		String(
			species
		),
	]


func response_hint(
	profile: Dictionary
) -> String:
	match String(
		profile.get(
			"expression_bias",
			"balanced_response"
		)
	):
		"length_before_bulk":
			return "When a Gene has several valid expressions, this individual tends to express length and flowing continuity before extra bulk."
		"bulk_before_length":
			return "When a Gene has several valid expressions, this individual tends to express stable mass and support before extra length."
		"flow_before_width":
			return "When a Gene has several valid expressions, this individual tends to express directional flow and taper before broad width."
		"surface_before_volume":
			return "When a Gene has several valid expressions, this individual tends to express organized surface structure before large volume."
		_:
			return "When a Gene has several valid expressions, keep the response balanced and faithful to this individual's inherited frame."


func pose_hint(
	species: StringName,
	focus: String,
	temperament: String
) -> String:
	var family := family_for(
		species
	)

	match family:
		FAMILY_AVIAN:
			if focus == "tail":
				return "natural side-three-quarter perch or standing pose with the single tail-feather assembly readable"
			if focus in ["mane", "structure", "body"]:
				return "natural three-quarter standing or perched pose with breast, neck and one wing pair easy to read"
			if focus == "paws":
				return "natural small step or perch with both legs and feet readable"
			return "natural three-quarter juvenile bird pose, wings relaxed and anatomy unobscured"

		FAMILY_REPTILE:
			if focus == "tail":
				return "natural side-three-quarter reptilian stance with the single tail separated from the torso outline"
			if focus in ["body", "structure"]:
				return "natural three-quarter reptilian stance showing head, torso, four legs and tail clearly"
			if focus == "paws":
				return "natural walking or planted reptilian stance with all four feet readable"
			return "natural three-quarter reptilian pose, low or upright as appropriate to the species"

		FAMILY_HOOFED:
			if focus == "tail":
				return "natural three-quarter hoofed stance with the single tail visible outside the hindquarter outline"
			if focus in ["mane", "body", "structure"]:
				return "natural three-quarter hoofed stance showing neck, chest, four legs and species-native mane or ruff"
			if focus == "paws":
				return "natural light step with four hoofed legs anatomically clear"
			return "natural three-quarter hoofed pose with a readable neck and leg silhouette"

		_:
			if focus == "tail":
				return "natural side-three-quarter quadruped pose with the single tail separated from the body outline"
			if focus in ["mane", "body", "structure"]:
				return "natural three-quarter quadruped stance with chest, flank and four legs readable"
			if focus == "paws":
				return "natural walking step with the near forepaw visible and no crossed limbs"
			if focus == "ears":
				return "natural three-quarter pose with the existing ear silhouettes unobscured"

	var mood := temperament
	if mood.is_empty():
		mood = "calm"
	return "natural %s three-quarter pose that keeps the whole species silhouette readable" % mood


func translate(
	species: StringName,
	locus: StringName,
	direction: StringName
) -> String:
	var family := family_for(
		species
	)
	var locus_key := String(
		locus
	)
	var direction_key := String(
		direction
	)

	match locus_key:
		"body":
			return _body_instruction(
				family,
				direction_key
			)
		"structure":
			return _structure_instruction(
				family,
				direction_key
			)
		"ears":
			return _ears_instruction(
				family,
				direction_key
			)
		"tail":
			return _tail_instruction(
				family,
				direction_key
			)
		"fur":
			return _surface_instruction(
				family,
				direction_key
			)
		"paws":
			return _feet_instruction(
				family,
				direction_key
			)
		"mane":
			return _mane_instruction(
				family,
				direction_key
			)
		"whiskers":
			return _whisker_instruction(
				family,
				direction_key
			)
		"coat":
			return _coat_instruction(
				family,
				direction_key
			)
		"eyes":
			return _eye_instruction(
				direction_key
			)
		"mark":
			return "Develop a restrained %s lineage marking using the current elemental palette and the species' natural surface layout." % direction_key
		"aura":
			return "Express a restrained %s elemental aura close to the body without hiding anatomy or replacing physical development." % direction_key
		_:
			return ""


func _frame_for_family(
	family: String,
	frame_key: String
) -> String:
	match family:
		FAMILY_AVIAN:
			match frame_key:
				"compact_grounded":
					return "A compact juvenile bird frame with a stable breast and tidy body mass"
				"long_flexible":
					return "A slightly elongated juvenile bird frame with flowing neck-to-body continuity"
				"tall_light":
					return "A light upright juvenile bird frame with an airy carriage"
				_:
					return "A balanced athletic juvenile bird frame with clean body carriage"
		FAMILY_REPTILE:
			match frame_key:
				"compact_grounded":
					return "A compact grounded reptilian frame with a firm torso and stable four-leg support"
				"long_flexible":
					return "A naturally elongated flexible reptilian frame with a continuous body-to-tail line"
				"tall_light":
					return "A lighter reptilian frame with slightly elevated carriage and agile support"
				_:
					return "A balanced athletic reptilian frame with clear torso, four legs and tail"
		FAMILY_HOOFED:
			match frame_key:
				"compact_grounded":
					return "A compact grounded hoofed frame with a stable chest while preserving natural neck and leg proportions"
				"long_flexible":
					return "A flowing hoofed frame with a longer visual line through neck, torso and movement"
				"tall_light":
					return "A tall light hoofed frame with graceful species-appropriate leg carriage"
				_:
					return "A balanced athletic hoofed frame with natural neck, chest and leg rhythm"
		_:
			match frame_key:
				"compact_grounded":
					return "A compact grounded quadruped frame with stable mass distribution"
				"long_flexible":
					return "A long flexible quadruped frame with a light middle and flowing body line"
				"tall_light":
					return "A taller lighter quadruped frame with an agile limb rhythm"
				_:
					return "A balanced athletic quadruped frame with even mass distribution"


func _surface_expression(
	family: String,
	surface_flow: String
) -> String:
	match family:
		FAMILY_AVIAN:
			return "Plumage follows %s." % surface_flow
		FAMILY_REPTILE:
			return "Scales and skin contours follow %s." % surface_flow
		_:
			return "Coat and surface contours follow %s." % surface_flow


func _appendage_expression(
	family: String,
	character: String
) -> String:
	match family:
		FAMILY_AVIAN:
			return "The existing wing and tail-feather shapes have a %s character without changing appendage count" % character
		FAMILY_REPTILE:
			return "The existing tail and head-side contours have a %s character without adding mammalian anatomy" % character
		FAMILY_HOOFED:
			return "The existing ears, mane or ruff and single tail share a %s character" % character
		_:
			return "The existing ears and single tail share a %s character" % character


func _body_instruction(
	family: String,
	direction: String
) -> String:
	match direction:
		"sturdy":
			match family:
				FAMILY_AVIAN:
					return "Develop a fuller stable breast and stronger body carriage while keeping neck, wings and legs naturally avian."
				FAMILY_REPTILE:
					return "Develop a firmer torso and shoulder base with stable weight-bearing limbs while keeping the reptilian body line."
				FAMILY_HOOFED:
					return "Develop a stronger chest and shoulder base while keeping the neck and legs recognizably hoofed and graceful."
				_:
					return "Develop a stronger chest-and-shoulder impression with stable limbs, without broadening every body part."
		"agile":
			match family:
				FAMILY_AVIAN:
					return "Develop a lighter athletic body carriage with clean wing roots and quick balanced footing."
				FAMILY_REPTILE:
					return "Develop a lighter flexible torso with agile limb placement and a continuous tail line."
				FAMILY_HOOFED:
					return "Develop a light athletic hoofed frame with a clean waist, responsive neck and easy leg movement."
				_:
					return "Develop a lighter athletic frame with a clean waist and responsive limb placement."
		"slender":
			match family:
				FAMILY_AVIAN:
					return "Refine the juvenile body into a lighter elegant bird silhouette without thinning wings or legs unnaturally."
				FAMILY_REPTILE:
					return "Refine the body into a lean elongated reptilian silhouette while preserving stable four-leg anatomy."
				FAMILY_HOOFED:
					return "Refine the body into a lean graceful hoofed silhouette while preserving a healthy chest and species-appropriate legs."
				_:
					return "Refine the body into a leaner silhouette with a clear waist while keeping healthy chest and limb support."
		"compact":
			match family:
				FAMILY_AVIAN:
					return "Keep the bird body compact and cohesive with a tidy breast-to-tail transition."
				FAMILY_REPTILE:
					return "Keep the reptilian body compact and cohesive without shortening the natural tail into a stump."
				FAMILY_HOOFED:
					return "Keep the hoofed body compact through chest and torso, not by shortening the legs into an unnatural shape."
				_:
					return "Keep the body compact and cohesive through torso mass, not by shrinking limbs or head unnaturally."
		"regal":
			match family:
				FAMILY_AVIAN:
					return "Develop a poised elevated bird carriage with elegant breast, neck and head alignment."
				FAMILY_REPTILE:
					return "Develop a poised reptilian carriage with a confident neck and clean body-to-tail line."
				FAMILY_HOOFED:
					return "Develop a noble hoofed carriage with a confident neck, balanced chest and composed stride."
				_:
					return "Develop a poised confident carriage with an elevated chest and clean balanced silhouette."
		_:
			return ""


func _structure_instruction(
	family: String,
	direction: String
) -> String:
	match direction:
		"guardian":
			return _guardian_instruction(
				family
			)
		"elegant":
			return _elegant_instruction(
				family
			)
		"feral":
			return _feral_instruction(
				family
			)
		"ancient":
			return _ancient_instruction(
				family
			)
		"spirit":
			return _spirit_instruction(
				family
			)
		_:
			return ""


func _guardian_instruction(
	family: String
) -> String:
	match family:
		FAMILY_AVIAN:
			return "Coordinate the existing bird anatomy into a steady guardian carriage: stable breast, grounded feet and protective wing posture, with no extra mass or armor."
		FAMILY_REPTILE:
			return "Coordinate the existing reptilian anatomy into a grounded guardian stance with a firm torso and stable limbs, without adding armor."
		FAMILY_HOOFED:
			return "Coordinate the existing hoofed anatomy into a stable guardian carriage with a stronger chest and planted stance while keeping graceful legs."
		_:
			return "Coordinate the existing body into a grounded guardian silhouette: stable shoulders, chest and stance, without turning the pet into a bulky template."


func _elegant_instruction(
	family: String
) -> String:
	match family:
		FAMILY_AVIAN:
			return "Coordinate the bird into longer flowing visual lines through neck, plumage and carriage while preserving natural avian balance."
		FAMILY_REPTILE:
			return "Coordinate the reptilian body into smooth continuous curves from head through torso to tail without weakening limb support."
		FAMILY_HOOFED:
			return "Coordinate the hoofed body into long soft transitions through neck, torso and stride without exaggerating leg length."
		_:
			return "Coordinate the body into longer soft transitions and cleaner curves while preserving the inherited frame."


func _feral_instruction(
	family: String
) -> String:
	match family:
		FAMILY_AVIAN:
			return "Coordinate a more alert forward bird carriage with sharper feather grouping and ready footing, not a predatory species swap."
		FAMILY_REPTILE:
			return "Coordinate a forward-ready reptilian stance with taut body line and sharper native contours."
		FAMILY_HOOFED:
			return "Coordinate an alert forward hoofed stance with taut movement and sharper native contours, not a carnivore body."
		_:
			return "Coordinate a forward-ready athletic stance with taut body lines and sharper native contours."


func _ancient_instruction(
	family: String
) -> String:
	match family:
		FAMILY_AVIAN:
			return "Coordinate a calm ceremonial bird carriage with layered mature plumage organization, without oversized sacred accessories."
		FAMILY_REPTILE:
			return "Coordinate a calm ancient reptilian carriage with measured long lines and organized native scale structure."
		FAMILY_HOOFED:
			return "Coordinate a calm ceremonial hoofed carriage with measured neck and body lines and restrained mature surface detail."
		_:
			return "Coordinate a calm dignified silhouette with measured long lines and organized mature surface structure."


func _spirit_instruction(
	family: String
) -> String:
	match family:
		FAMILY_AVIAN:
			return "Keep the avian body light and coherent; express spirit character mainly through graceful carriage and restrained feather flow, not extra anatomy."
		FAMILY_REPTILE:
			return "Keep the reptilian body light and coherent; express spirit character through flowing contours and restrained energy, not extra anatomy."
		FAMILY_HOOFED:
			return "Keep the hoofed body light and coherent; express spirit character through graceful carriage and restrained mane or surface flow."
		_:
			return "Keep the body light and coherent; express spirit character through graceful contours and restrained surface flow, not extra anatomy."


func _ears_instruction(
	family: String,
	direction: String
) -> String:
	if family == FAMILY_AVIAN:
		return _avian_head_side_instruction(
			direction
		)
	if family == FAMILY_REPTILE:
		return _reptile_head_side_instruction(
			direction
	)

	match direction:
		"long":
			return "Lengthen the two existing species-native ears moderately while keeping their bases and head proportions natural."
		"tufted":
			return "Develop restrained terminal tufts on the two existing ears, integrated with the native coat."
		"sharp":
			return "Refine the two existing ears toward cleaner tapered tips without making them oversized."
		"rounded":
			return "Refine the two existing ears toward softer rounded tips while preserving their species-native size."
		"softfan":
			return "Broaden the two existing ear silhouettes gently through soft species-native hair or edge shape, not by adding extra ears."
		_:
			return ""


func _avian_head_side_instruction(
	direction: String
) -> String:
	match direction:
		"long":
			return "Translate this ear-direction into slightly taller paired head-feather or ear-covert contours; do not add mammalian ears."
		"tufted":
			return "Translate this ear-direction into small paired feather tufts at the natural sides or crown of the head; do not add mammalian ears."
		"sharp":
			return "Translate this ear-direction into cleaner tapered paired head-feather contours; do not add mammalian ears."
		"rounded":
			return "Translate this ear-direction into softer rounded paired head-feather contours; do not add mammalian ears."
		"softfan":
			return "Translate this ear-direction into a restrained paired fan of head feathers integrated with the skull silhouette; do not add ears."
		_:
			return ""


func _reptile_head_side_instruction(
	direction: String
) -> String:
	match direction:
		"long":
			return "Translate this ear-direction into a slightly elongated paired brow or head-side scale contour native to the reptile; do not add mammalian ears."
		"tufted":
			return "Translate this ear-direction into small paired scale or frill accents at the natural head edge; no fur tufts or mammalian ears."
		"sharp":
			return "Refine paired native brow or head-side contours toward cleaner tapered scale points without adding new appendages."
		"rounded":
			return "Refine paired native brow or head-side contours toward softer rounded scale forms without adding ears."
		"softfan":
			return "Translate this ear-direction into a restrained paired head-side frill only if natural to the species silhouette; never add mammalian ears."
		_:
			return ""


func _tail_instruction(
	family: String,
	direction: String
) -> String:
	var noun := "single tail"
	if family == FAMILY_AVIAN:
		noun = "single tail-feather assembly"

	match direction:
		"long":
			return "Lengthen the existing %s moderately while preserving one coherent appendage and natural attachment." % noun
		"fluffy":
			if family == FAMILY_AVIAN:
				return "Increase layered feather fullness within the existing tail-feather assembly without creating multiple tails."
			if family == FAMILY_REPTILE:
				return "Translate fullness into broader layered scale, fin or ridge volume on the existing tail; do not add fur."
			return "Increase soft volume around the existing single tail while keeping its core shape and attachment readable."
		"curved":
			return "Give the existing %s a clear natural flowing curve without kinks, duplication or impossible joints." % noun
		"tipped":
			return "Give the existing %s a distinct restrained terminal shape or color block, without adding a second appendage." % noun
		"streamlined":
			return "Refine the existing %s into a cleaner tapered flowing line with less bulky visual noise." % noun
		_:
			return ""


func _surface_instruction(
	family: String,
	direction: String
) -> String:
	var noun := "coat"
	if family == FAMILY_AVIAN:
		noun = "plumage"
	elif family == FAMILY_REPTILE:
		noun = "scale and skin surface"

	match direction:
		"fluffy":
			if family == FAMILY_REPTILE:
				return "Translate fluffy into slightly fuller layered scale or soft-frill surface organization; do not grow mammalian fur."
			return "Increase soft separated volume in the %s while preserving the underlying body silhouette." % noun
		"sleek":
			return "Refine the %s into a smoother directional surface that follows the body naturally." % noun
		"plush":
			if family == FAMILY_REPTILE:
				return "Translate plush into dense smooth juvenile scale coverage with soft visual transitions; no fur."
			return "Develop a denser soft %s surface with compact rounded volume, not oversized body mass." % noun
		"layered":
			return "Organize the %s into readable overlapping layers that follow the species' natural growth direction." % noun
		"silky":
			return "Give the %s a fine flowing directional finish without changing anatomy or adding length everywhere." % noun
		_:
			return ""


func _feet_instruction(
	family: String,
	direction: String
) -> String:
	var noun := "paws"
	if family == FAMILY_AVIAN:
		noun = "feet"
	elif family == FAMILY_REPTILE:
		noun = "feet and claws"
	elif family == FAMILY_HOOFED:
		noun = "hooves and lower legs"

	match direction:
		"luminous":
			return "Add restrained localized elemental light around the existing %s; keep their physical shape readable." % noun
		"sturdy":
			return "Make the existing %s look more stable and well-supported without enlarging the entire limb." % noun
		"swift":
			return "Refine the existing %s toward a lighter agile impression while preserving normal joint and digit structure." % noun
		"fluffy":
			if family in [FAMILY_AVIAN, FAMILY_REPTILE]:
				return "Translate fluffy into a small species-native feather, scale or soft-frill accent around the existing %s; do not add mammalian fur." % noun
			return "Develop a restrained soft coat fringe around the existing %s without hiding toes, hoof edges or joint anatomy." % noun
		"runic":
			return "Add a small readable rune-like marking to the existing %s without changing their anatomy." % noun
		_:
			return ""


func _mane_instruction(
	family: String,
	direction: String
) -> String:
	var noun := "neck and chest ruff"
	if family == FAMILY_AVIAN:
		noun = "neck ruff and crown plumage"
	elif family == FAMILY_REPTILE:
		noun = "species-native neck or dorsal crest"
	elif family == FAMILY_HOOFED:
		noun = "species-native mane or neck ruff"

	var quality: String = String({
		"astral": "a restrained flowing mystical organization",
		"full": "a fuller but still anatomically integrated volume",
		"layered": "clear overlapping layers",
		"silken": "a smooth flowing direction",
		"regal": "a composed ceremonial shape",
	}.get(
		direction,
		""
	))

	if quality.is_empty():
		return ""

	return (
		"Develop %s with %s. Keep it attached to the species-native neck or chest structure; do not paste a mammalian lion mane onto unrelated anatomy."
	) % [
		noun,
		quality,
	]


func _whisker_instruction(
	family: String,
	direction: String
) -> String:
	var noun := "facial whiskers"
	if family == FAMILY_AVIAN:
		noun = "paired fine facial feather filaments near the beak and cheeks"
	elif family == FAMILY_REPTILE:
		noun = "paired subtle jawline sensory filaments or scale accents"
	elif family == FAMILY_HOOFED:
		noun = "fine muzzle tactile hairs"

	match direction:
		"starlight":
			return "Give the %s a faint localized starlight edge without turning them into beams." % noun
		"long":
			return "Lengthen the %s moderately while keeping them fine and species-compatible." % noun
		"fine":
			return "Refine the %s into delicate clean lines that do not dominate the face." % noun
		"fanned":
			return "Arrange the %s in a gentle readable fan without adding extra facial appendages." % noun
		"curved":
			return "Give the %s a soft natural curve that follows the face." % noun
		_:
			return ""


func _coat_instruction(
	family: String,
	direction: String
) -> String:
	var noun := "coat"
	if family == FAMILY_AVIAN:
		noun = "plumage pattern"
	elif family == FAMILY_REPTILE:
		noun = "scale and skin pattern"

	match direction:
		"shadow":
			return "Develop restrained shadow gradients in the %s while keeping the base elemental palette readable." % noun
		"nebula":
			return "Develop sparse nebula-like color transitions in the %s, localized rather than covering the whole body." % noun
		"striped":
			return "Develop species-following directional stripes in the %s." % noun
		"spotted":
			return "Develop restrained species-following spots in the %s." % noun
		"marbled":
			return "Develop a controlled marbled flow in the %s that follows natural surface direction." % noun
		_:
			return ""


func _eye_instruction(
	direction: String
) -> String:
	match direction:
		"luminous":
			return "Brighten the iris internally while keeping a dark readable pupil and normal eye placement."
		"moon":
			return "Develop a restrained crescent-like iris pattern around a readable pupil."
		"sharp":
			return "Refine the eye contour toward a more alert tapered gaze without moving or enlarging the eyes."
		"gentle":
			return "Refine the eye contour toward a softer open gaze while preserving identity."
		"ringed":
			return "Develop clean concentric iris rings around a visible pupil."
		_:
			return ""
