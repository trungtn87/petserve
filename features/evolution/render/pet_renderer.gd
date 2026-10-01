class_name PetRenderer
extends Node


func renderer_id() -> StringName:
	return &"base"


func render(
	request: PetRenderRequest
) -> PetRenderResult:
	return PetRenderResult.fail(
		&"not_implemented",
		"PetRenderer.render() chưa được triển khai.",
		renderer_id()
	)
