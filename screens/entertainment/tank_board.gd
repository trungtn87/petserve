class_name TankBoard
extends Control
var state: Dictionary = {}

func _ready() -> void:
	custom_minimum_size = Vector2(200, 200)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func show_state(value: Dictionary) -> void:
	state = value
	queue_redraw()

func _draw() -> void:
	var unit := minf(size.x, size.y) / 13.0
	var offset := (size - Vector2.ONE * unit * 13) / 2
	draw_rect(Rect2(offset, Vector2.ONE * unit * 13), Color("131d28"))
	if state.is_empty():
		return
	for cell in state.tiles.size():
		var type := int(state.tiles[cell])
		var r := Rect2(offset + Vector2(cell % 13, cell / 13) * unit, Vector2.ONE * unit)
		match type:
			1:
				draw_rect(r.grow(-0.8), Color("cf7049"))
				for y in [0.33,0.66]:
					draw_line(r.position + Vector2(0,unit*y),r.position+Vector2(unit,unit*y),Color("713e30"),1)
				draw_line(r.position+Vector2(unit*0.5,0),r.position+Vector2(unit*0.5,unit),Color("713e30"),1)
				if float(state.fort) > 0 and cell in [148,149,150,161,163]:
					draw_rect(r.grow(-1),Color("81e9f0"),false,2)
			2:
				draw_rect(r.grow(-1),Color("a6b9c8"))
				draw_rect(r.grow(-unit*0.22),Color("dce6ed"),false,1.5)
			3:
				draw_rect(r,Color("246d9c"))
				for y in [0.3,0.7]:
					draw_line(r.position+Vector2(unit*0.15,unit*y),r.position+Vector2(unit*0.85,unit*y),Color("78c4e1"),1)
			5:
				draw_rect(r.grow(-1),Color("ecdcab"))
				_text("★",r.get_center(),unit*0.8,Color("332b26"))
	for i in state.players.size():
		var p: Dictionary = state.players[i]
		if int(p.lives) > 0:
			_tank(p,offset,unit,Color("ffd05c") if i == 0 else Color("65d4ff"),str(i+1))
	for e in state.enemies:
		_tank(e,offset,unit,Color("f06b79") if int(e.kind) != 3 else Color("df9ff5"),"" )
	for b in state.bullets:
		draw_circle(offset+Vector2(b.x,b.y)*unit,maxf(2,unit*0.09),Color("fff3b0") if int(b.owner)>=0 else Color("ff7785"))
	for item in state.pickups:
		var center: Vector2 = offset+Vector2(item.x,item.y)*unit
		draw_rect(Rect2(center-Vector2.ONE*unit*0.35,Vector2.ONE*unit*0.7),Color("54e3ab"))
		_text(["+","S","F","B","H"][int(item.kind)],center,unit*0.55,Color("102b24"))
	# Foliage stays translucent so small tanks remain readable.
	for cell in state.tiles.size():
		if int(state.tiles[cell]) == 4:
			var center := offset+Vector2(cell%13+0.5,float(cell/13)+0.5)*unit
			draw_circle(center,unit*0.45,Color(0.2,0.65,0.34,0.48))
	for effect in state.effects:
		draw_circle(offset+Vector2(effect.x,effect.y)*unit,unit*(0.5-float(effect.time)),Color("ffc27c"))
	draw_rect(Rect2(offset,Vector2.ONE*unit*13),Color("6c839a"),false,1)

func _tank(t: Dictionary, offset: Vector2, unit: float, color: Color, number: String) -> void:
	var center := offset+Vector2(t.x,t.y)*unit
	var d: Vector2 = TankSession.DIRS[int(t.dir)]
	var side := Vector2(-d.y,d.x)
	draw_set_transform(center,d.angle()+PI/2)
	draw_rect(Rect2(Vector2(-0.36,-0.35)*unit,Vector2(0.18,0.7)*unit),Color("687987"))
	draw_rect(Rect2(Vector2(0.18,-0.35)*unit,Vector2(0.18,0.7)*unit),Color("687987"))
	draw_rect(Rect2(Vector2(-0.23,-0.29)*unit,Vector2(0.46,0.58)*unit),color)
	draw_circle(Vector2.ZERO,unit*0.17,color.darkened(0.25))
	draw_line(Vector2.ZERO,Vector2(0,-unit*0.5),color, maxf(2,unit*0.12))
	draw_set_transform(Vector2.ZERO)
	if not number.is_empty():
		_text(number,center+side*unit*0.02,unit*0.4,Color("15222d"))
		if float(t.shield) > 0:
			draw_arc(center,unit*0.47,0,TAU,24,Color("f1ffff"),1.2,true)
	elif bool(t.get("carrier",false)):
		draw_circle(center,unit*0.08,Color.WHITE)

func _text(text: String, center: Vector2, font_size: float, color: Color) -> void:
	var font := get_theme_default_font()
	var s := maxi(8,int(font_size))
	var extent := font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,s)
	draw_string(font,center+Vector2(-extent.x/2,(font.get_ascent(s)-font.get_descent(s))/2),text,HORIZONTAL_ALIGNMENT_LEFT,-1,s,color)
