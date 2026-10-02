extends RefCounted

const Morphology = preload("res://features/evolution/visual/lineage_morphology.gd")
const SpeciesExpression = preload("res://features/evolution/visual/species_gene_expression.gd")

func compose(base_prompt: String, identity: PetIdentity, stage: int, scores: Dictionary) -> String:
	if identity == null or not identity.is_valid() or base_prompt.is_empty():
		return ""
	# 47d8688 preserves the coordinator's full stage/reference/element brief.
	# Never replace it with ResolvedFormPrompt, which is a later experiment.
	var style := MythicStyleProfile.load_default()
	if style == null:
		return ""
	var opening := "Premium fantasy game character art, polished stylized 3D appearance, evolved chibi proportions, glossy expressive eyes, soft sculpted rounded forms and a clean collectible fantasy-pet silhouette. "
	var prompt := opening + style.base_style() + "\n\n" + base_prompt
	var gene_prompt := GenePromptResolver.new().build_from_scores(scores, identity.element(), stage, identity.species())
	if not gene_prompt.is_empty():
		var scope := ""
		if stage >= 3:
			scope = "Use the reference for individual identity. Natural maturation and the morphology plan may change proportions and pose. Only listed Gene directions may add specialized traits. Total lifetime score controls expression strength; the highest-scored direction is dominant and other scored directions may blend. Do not invent unlisted Gene directions or unauthorized appendages.\n"
		prompt += "\n\n[ACCUMULATED GENE SCORE PHENOTYPE]\n" + scope + gene_prompt
	prompt += Morphology.new().build(identity, stage, scores)
	var family := SpeciesExpression.new().family_for(identity.species())
	if family == SpeciesExpression.FAMILY_AVIAN:
		prompt = prompt.replace("ear tips", "wing tips").replace("ear fur", "crown plumage").replace("fur", "plumage").replace("coat", "plumage")
	elif family == SpeciesExpression.FAMILY_REPTILE:
		prompt = prompt.replace("ear tips", "dorsal contours").replace("ear fur", "brow scales").replace("fur", "scale surface").replace("coat", "scale pattern")
	return prompt
