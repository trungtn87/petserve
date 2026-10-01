class_name PetRenderService
extends Node


var _renderer: PetRenderer


func set_renderer(
	renderer: PetRenderer
) -> void:
	if _renderer != null:
		remove_child(_renderer)
		_renderer.queue_free()

	_renderer = renderer

	if _renderer != null:
		add_child(_renderer)


func renderer() -> PetRenderer:
	return _renderer


func render(
	request: PetRenderRequest
) -> PetRenderResult:
	if _renderer == null:
		return PetRenderResult.fail(
			&"missing_renderer",
			"PetRenderService chưa có renderer."
		)

	return await _renderer.render(request)
