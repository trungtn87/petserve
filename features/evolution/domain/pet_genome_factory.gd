class_name PetGenomeFactory
extends RefCounted


const DEFAULT_TRAITS: Dictionary = {
	"body": "base",
	"eyes": "base",
	"ears": "base",
	"whiskers": "base",
	"fur": "base",
	"coat": "base",
	"tail": "base",
	"paws": "base",
	"mane": "base",
	"mark": "base",
	"structure": "base",
	"aura": "base",
}


func create_initial(
	extra_traits: Dictionary = {}
) -> PetGenome:
	var traits := DEFAULT_TRAITS.duplicate(true)

	for key_value in extra_traits.keys():
		traits[key_value] = extra_traits[key_value]

	return create_snapshot(
		1,
		0.0,
		traits,
		[]
	)


func create_snapshot(
	stage: int,
	body_growth: float,
	traits: Dictionary,
	mutations: Array
) -> PetGenome:
	var genome := PetGenome.new(
		stage,
		body_growth,
		traits,
		mutations
	)

	if not genome.is_valid():
		return null

	return genome
