class_name PhenotypePromptBuilder
extends RefCounted


func describe(
	genome: PetGenome
) -> String:
	if (
		genome == null
		or not genome.is_valid()
	):
		return ""

	var traits := genome.visual_traits_snapshot()
	var parts: Array[String] = []

	for locus in PetGenomeSchema.VISUAL_LOCI:
		parts.append(
			"%s=%s"
			% [
				String(locus),
				String(
					traits.get(
						locus,
						PetGenomeSchema.BASE_TRAIT
					)
				),
			]
		)

	return "; ".join(
		parts
	)


func describe_except(
	genome: PetGenome,
	excluded_locus: StringName
) -> String:
	if (
		genome == null
		or not genome.is_valid()
	):
		return ""

	var excluded := StringName(
		String(excluded_locus)
			.strip_edges()
			.to_lower()
	)
	var traits := genome.visual_traits_snapshot()
	var parts: Array[String] = []

	for locus in PetGenomeSchema.VISUAL_LOCI:
		if locus == excluded:
			continue

		parts.append(
			"%s=%s"
			% [
				String(locus),
				String(
					traits.get(
						locus,
						PetGenomeSchema.BASE_TRAIT
					)
				),
			]
		)

	return "; ".join(
		parts
	)


func changed_loci(
	before: PetGenome,
	after: PetGenome
) -> Array[StringName]:
	var result: Array[StringName] = []

	if (
		before == null
		or after == null
		or not before.is_valid()
		or not after.is_valid()
	):
		return result

	for locus in PetGenomeSchema.VISUAL_LOCI:
		if before.get_trait(
			locus,
			PetGenomeSchema.BASE_TRAIT
		) != after.get_trait(
			locus,
			PetGenomeSchema.BASE_TRAIT
		):
			result.append(
				locus
			)

	return result
