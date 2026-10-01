class_name MockPetRenderer
extends PetRenderer


func renderer_id() -> StringName:
	return &"mock_pet_renderer"


func render(
	request: PetRenderRequest
) -> PetRenderResult:
	if request == null or not request.is_valid():
		return PetRenderResult.fail(
			&"invalid_request",
			"MockPetRenderer nhận request không hợp lệ.",
			renderer_id()
		)

	return PetRenderResult.ok(
		"user://mock/%s.png" % request.output_key,
		renderer_id(),
		&"mock",
		{
			"request": request.to_debug_dict(),
		}
	)
