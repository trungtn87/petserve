class_name GenomeDeltaApplier
extends RefCounted


var _factory: PetGenomeFactory = PetGenomeFactory.new()


func apply(
	genome: PetGenome,
	delta: EvolutionDelta
) -> PetGenome:
	if (
		genome == null
		or delta == null
		or not genome.is_valid()
		or not delta.is_valid()
	):
		return null

	if genome.has_mutation(
		delta.mutation_id()
	):
		return null

	var current_trait := genome.trait(
		delta.target_trait(),
		&"base"
	)

	if current_trait != delta.from_trait():
		return null

	var traits := genome.traits_snapshot()
	traits[delta.target_trait()] = (
		delta.to_trait()
	)

	var mutations: Array = []

	for mutation_id in genome.mutation_ids():
		mutations.append(mutation_id)

	mutations.append(
		delta.mutation_id()
	)

	return _factory.create_snapshot(
		genome.stage(),
		genome.body_growth(),
		traits,
		mutations
	)
