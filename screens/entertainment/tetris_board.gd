class_name TetrisBoard
extends Control

const COLORS := [Color("68ddec"), Color("ffd777"), Color("bd8bfa"), Color("84dd99"), Color("f58699"), Color("80a7ff"), Color("ffb36a")]
var state: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resized.connect(queue_redraw)

func show_state(value: Dictionary) -> void:
	state = value
	queue_redraw()

func board_rect() -> Rect2:
	var unit := floorf(minf(size.x / 10.0, size.y / 20.0))
	var extent := Vector2(unit * 10, unit * 20)
	return Rect2((size - extent) * 0.5, extent)

func _draw() -> void:
	if state.is_empty():
		return
	var rect := board_rect()
	var unit := rect.size.x / 10.0
	draw_rect(rect, Color("100c1c"))
	for x in range(11):
		draw_line(rect.position + Vector2(x * unit, 0), rect.position + Vector2(x * unit, rect.size.y), Color("2d2540"))
	for y in range(21):
		draw_line(rect.position + Vector2(0, y * unit), rect.position + Vector2(rect.size.x, y * unit), Color("2d2540"))
	var board: Array = state.get("board", [])
	for index in board.size():
		if int(board[index]) > 0:
			_cell(rect, Vector2i(index % 10, int(index / 10)), COLORS[int(board[index]) - 1], false)
	if state.get("status", "") == "playing":
		var session := TetrisSession.new()
		var kind := int(state.piece)
		for cell in session.cells(kind, int(state.rotation)):
			_cell(rect, state.ghost + cell, Color(COLORS[kind], 0.35), true)
		for cell in session.cells(kind, int(state.rotation)):
			_cell(rect, state.position + cell, COLORS[kind], false)
	draw_rect(rect, Color("ac8fe8"), false, 1.0)
	var side := rect.position.x
	if side >= 42:
		var preview_unit := minf(12.0, (side - 8) / 4.0)
		var left := Vector2((side - 4 * preview_unit) * 0.5, rect.position.y + 36)
		var right := Vector2(rect.end.x + (side - 4 * preview_unit) * 0.5, left.y)
		draw_string(ThemeDB.fallback_font, left + Vector2(0,-10), "GIỮ", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("c9bcdf"))
		draw_string(ThemeDB.fallback_font, right + Vector2(0,-10), "TIẾP", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("c9bcdf"))
		_preview_piece(int(state.held), left, preview_unit)
		var next: Array = state.next
		_preview_piece(int(next[0]), right, preview_unit)
		_preview_piece(int(next[1]), right + Vector2(0,60), preview_unit)

func _cell(rect: Rect2, point: Vector2i, color: Color, ghost: bool) -> void:
	if point.y < 0 or point.y >= 20:
		return
	var unit := rect.size.x / 10.0
	var tile := Rect2(rect.position + Vector2(point) * unit + Vector2.ONE, Vector2.ONE * (unit - 2))
	if ghost:
		draw_rect(tile, color, false, 1.5)
	else:
		draw_rect(tile, color)
	if not ghost:
		draw_line(tile.position + Vector2(1,1), tile.position + Vector2(tile.size.x-1,1), color.lightened(0.3), 1.0)

func _preview_piece(kind: int, origin: Vector2, unit: float) -> void:
	if kind < 0:
		return
	for cell in TetrisSession.SHAPES[kind]:
		draw_rect(Rect2(origin + Vector2(cell) * unit, Vector2.ONE * (unit - 1)), COLORS[kind])
