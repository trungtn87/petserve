class_name PetSceneProfileFactory
extends RefCounted


const ENVIRONMENTS := {
	"metal": [
		"a silver crystal valley with faceted mineral cliffs and reflective crystal clusters",
		"a cool metallic canyon with pale cyan crystals and polished stone terraces",
		"a luminous silver mineral garden with crystalline arches and distant glassy peaks",
	],
	"wood": [
		"a lush ancient forest clearing beneath one giant tree with broad roots and mossy stones",
		"a green spirit grove with layered roots, soft ferns and a small woodland stream",
		"a warm enchanted forest terrace around an old tree trunk with glowing plants",
	],
	"water": [
		"a serene blue lake beside a small waterfall, smooth wet stones and soft mist",
		"a clear moonlit lagoon with a gentle cascade and luminous aquatic plants",
		"a crystalline stream garden with shallow pools, rounded stones and drifting water vapor",
	],
	"fire": [
		"a volcanic stone terrace with distant lava glow, warm embers and dark basalt formations",
		"a sheltered ember canyon with glowing rock seams and soft orange firelight",
		"a warm lava garden with black volcanic stones, red-gold fissures and floating sparks",
	],
	"earth": [
		"a broad earthy valley with sandstone shelves, natural rock formations and mineral veins",
		"a calm stone cavern opening toward a warm valley with crystals embedded in the walls",
		"a grounded rocky plateau with layered soil, weathered boulders and muted mineral glow",
	],
	"light": [
		"a peaceful garden above the clouds with floating terraces, soft flowers and open sky",
		"a sunlit cloud sanctuary with pale stone paths, airy arches and gentle radiant plants",
		"a floating meadow temple with warm clouds, subtle golden flowers and distant sky islands",
	],
	"dark": [
		"a moonlit night forest with ancient ruins, soft mist, violet glowing flowers and a distant waterfall",
		"a quiet midnight grove around a dark reflective lake, broken stone arches and purple-blue fog",
		"an ancient night forest terrace with twisted roots, old ruins, a small cascade and restrained violet bioluminescence",
	],
}

const PALETTES := {
	"metal": [
		["silver_cyan", "cool silver, pale cyan, pearl gray and faint ice-blue"],
		["steel_blue", "soft steel blue, brushed silver, white crystal and muted navy"],
		["moon_silver", "moonlit silver, cool lavender-gray, pale blue and clean white"],
	],
	"wood": [
		["moss_cream", "moss green, warm cream, fresh leaf green and light tan"],
		["forest_gold", "deep leaf green, soft olive, warm gold and natural brown"],
		["spring_green", "fresh green, pale mint, warm bark brown and soft sunlight yellow"],
	],
	"water": [
		["aqua_pearl", "pale aqua, pearl white, clear cyan and deep lake blue"],
		["lagoon_blue", "lagoon turquoise, cool blue, white mist and faint teal"],
		["moon_water", "moonlit blue, pale cyan, silver-white and soft indigo"],
	],
	"fire": [
		["ember_cream", "warm cream, amber, orange-red and dark basalt"],
		["lava_gold", "golden orange, deep red, warm brown and charcoal"],
		["sunset_flame", "soft coral red, orange, pale gold and smoky gray"],
	],
	"earth": [
		["sand_amber", "warm sand, amber, soft umber and muted olive"],
		["stone_gold", "stone gray, warm ochre, pale gold and earthy brown"],
		["mineral_clay", "clay brown, sandstone beige, muted green and subtle crystal gold"],
	],
	"light": [
		["ivory_gold", "warm ivory, pearl white, champagne gold and faint lilac"],
		["cloud_pearl", "cloud white, pale sky blue, soft gold and gentle lavender"],
		["dawn_light", "cream white, sunrise gold, peach-pink and pale blue"],
	],
	"dark": [
		["violet_moon", "smoky blue-black, charcoal indigo, muted violet and silver moonlight"],
		["midnight_cyan", "deep midnight blue, cool cyan, dark violet and pale silver"],
		["shadow_orchid", "soft black, indigo, orchid purple and faint blue-white glow"],
	],
}

const LIGHTING := {
	"metal": [
		"clean cool crystal light with controlled silver reflections",
		"soft overcast moonlight with pale cyan crystal bounce",
		"gentle directional silver-blue light with subtle mineral sparkle",
	],
	"wood": [
		"soft sunlight filtered through leaves with warm green bounce",
		"gentle forest shade with scattered golden rays",
		"fresh morning woodland light with soft green ambient glow",
	],
	"water": [
		"cool diffused lake light with soft cyan reflections",
		"moonlit blue ambience with faint reflected water glow",
		"fresh misty daylight with clean aqua bounce light",
	],
	"fire": [
		"warm ember lighting with restrained orange rim light",
		"soft volcanic glow balanced by dark ambient stone tones",
		"golden-red firelight with subtle floating ember highlights",
	],
	"earth": [
		"warm grounded daylight with soft amber mineral bounce",
		"calm cave-edge lighting with gentle golden crystal accents",
		"muted natural sunlight with warm stone reflections",
	],
	"light": [
		"gentle heavenly daylight with soft golden bloom",
		"diffused cloud light with warm ivory highlights",
		"soft dawn sunlight with restrained radiant glow",
	],
	"dark": [
		"cool moonlight with soft violet-blue ambient glow",
		"deep night lighting with restrained cyan rim light and purple mist bounce",
		"silver moonlight filtered through trees with subtle indigo ambient light",
	],
}

const MOTIFS := {
	"metal": [
		["crystal_shard", "small clean crystal-shard shapes repeated subtly in the world"],
		["silver_arc", "thin silver arc motifs integrated into crystal formations"],
		["geometric_rune", "restrained geometric rune shapes carved into distant mineral surfaces"],
	],
	"wood": [
		["leaf_spirit", "small leaf motifs and gentle spirit-like plant lights"],
		["root_ring", "curved root-ring forms repeated naturally in the environment"],
		["sprout_rune", "subtle sprout-shaped natural markings on stones and bark"],
	],
	"water": [
		["water_drop", "clean droplet shapes echoed in water highlights and small plants"],
		["wave_arc", "gentle wave arcs repeated subtly in shoreline forms"],
		["ripple_rune", "soft circular ripple motifs integrated into pools and stones"],
	],
	"fire": [
		["ember_flame", "small flame and ember shapes repeated subtly in rock glow"],
		["sun_spark", "tiny sun-like spark motifs inside distant lava fissures"],
		["warm_rune", "restrained angular fire runes carved into dark stones"],
	],
	"earth": [
		["diamond_stone", "small diamond-like mineral shapes repeated naturally in rock surfaces"],
		["layered_ring", "layered geological ring motifs visible in stone formations"],
		["pebble_rune", "subtle earthy rune shapes formed by small stones"],
	],
	"light": [
		["sun_halo", "soft halo motifs echoed in clouds and distant architecture"],
		["star_bloom", "small star-like flower shapes used sparingly in the garden"],
		["radiant_arc", "gentle radiant arcs integrated into floating structures"],
	],
	"dark": [
		["crescent_moon", "crescent-moon motifs echoed subtly in ruins and distant light shapes"],
		["night_star", "small restrained star motifs scattered through flowers and stone carvings"],
		["shadow_orchid", "orchid-like violet luminous forms repeated subtly in the night vegetation"],
	],
}


func create_initial(
	identity: PetIdentity
) -> PetSceneProfile:
	if identity == null or not identity.is_valid():
		return null

	var key := String(identity.element()).to_lower()

	if (
		not ENVIRONMENTS.has(key)
		or not PALETTES.has(key)
		or not LIGHTING.has(key)
		or not MOTIFS.has(key)
	):
		return null

	var environments: Array = ENVIRONMENTS[key]
	var palettes: Array = PALETTES[key]
	var lighting: Array = LIGHTING[key]
	var motifs: Array = MOTIFS[key]

	var rng := RandomNumberGenerator.new()
	rng.seed = _scene_seed(identity)

	var environment_index := rng.randi_range(
		0,
		environments.size() - 1
	)
	var palette_index := rng.randi_range(
		0,
		palettes.size() - 1
	)
	var lighting_index := rng.randi_range(
		0,
		lighting.size() - 1
	)
	var motif_index := rng.randi_range(
		0,
		motifs.size() - 1
	)

	var palette: Array = palettes[palette_index]
	var motif: Array = motifs[motif_index]

	var profile := PetSceneProfile.new()
	profile.element = identity.element()
	profile.environment_theme = str(
		environments[environment_index]
	)
	profile.environment_variant = environment_index
	profile.palette_id = StringName(
		str(palette[0])
	)
	profile.palette_description = str(
		palette[1]
	)
	profile.lighting_theme = str(
		lighting[lighting_index]
	)
	profile.motif_id = StringName(
		str(motif[0])
	)
	profile.motif_description = str(
		motif[1]
	)
	profile.scene_seed = _scene_seed(
		identity
	)

	return profile if profile.is_valid() else null


func _scene_seed(
	identity: PetIdentity
) -> int:
	var value := (
		identity.lineage_seed() * 214013
		+ int(identity.generation() + 1) * 2531011
	)

	if value < 0:
		value = -value

	return maxi(1, value)
