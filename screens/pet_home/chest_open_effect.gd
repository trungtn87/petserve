extends Control

signal finished
var progress := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.tween_method(func(value: float) -> void: progress = value; queue_redraw(), 0.0, 1.0, 1.25)
	tween.tween_callback(func() -> void: finished.emit(); queue_free())

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.02, 0.07, .88))
	var center := size * .5
	var burst := clampf((progress - .4) / .6, 0.0, 1.0)
	var shake := sin(progress * 70.0) * 5.0 * (1.0-burst)
	center.x += shake
	for i in 16:
		var angle := TAU * float(i) / 16.0 + progress
		var direction := Vector2(cos(angle), sin(angle))
		draw_line(center + direction * 35.0, center + direction * (40.0 + burst * 120.0), Color(1, .8, .3, burst*(1.0-burst)*3.0), 3.0)
		draw_circle(center + direction * (60.0 + burst * 110.0), 3.0, Color(1, .92, .55, burst))
	draw_circle(center, 55 + burst * 25, Color(1, .7, .2, burst * .15))
	var body := Rect2(center + Vector2(-48, -12), Vector2(96, 60))
	draw_style_box(_box(Color("74418b")), body)
	var lid := Rect2(center + Vector2(-50, -36-burst*38), Vector2(100, 28))
	draw_style_box(_box(Color("a774b9")), lid)
	draw_rect(Rect2(center + Vector2(-6, -12), Vector2(12, 60)), Color("edbb53"))
	draw_circle(center + Vector2(0, 4), 10, Color("ffe5a0"))

func _box(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = Color("edbb53")
	box.set_border_width_all(3)
	box.set_corner_radius_all(7)
	return box
