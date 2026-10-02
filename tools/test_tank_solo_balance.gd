extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _initialize() -> void:
	var g := TankSession.new()
	g.start(false,123)
	check(g.players[0].lives==5 and g.players[0].gun==1,"solo starts with five lives and faster gun")
	check(g.remaining==8 and g.enemy_limit()==2 and g.spawn_clock==4.0,"gentle first wave")
	check(g.base_hp==3 and g.fort==15.0,"base protected at start")
	for i in 20:
		for y in [12,13]:
			for x in 16:
				check(g.tiles[y*16+x]==0,"solo defensive cross-lane clear")
		for x in [0,8,15]:
			check(g.tiles[11*16+x]==1,"cover stops direct spawn-to-base fire")
		g._next_wave()
	g.start(false,10)
	g.tiles.fill(0)
	g.tiles[248]=5
	shoot_base(g,-1)
	check(g.base_hp==3,"opening protection blocks enemy hit")
	g.fort=0
	shoot_base(g,0)
	check(g.base_hp==3,"own bullet cannot damage solo base")
	shoot_base(g,-1)
	check(g.base_hp==2 and g.status=="playing","first enemy hit is survivable")
	shoot_base(g,-1)
	check(g.base_hp==2,"same volley cannot drain all base HP")
	g.base_grace=0
	shoot_base(g,-1)
	check(g.base_hp==1 and g.status=="playing","second hit survivable")
	g.base_grace=0
	shoot_base(g,-1)
	check(g.base_hp==0 and g.status=="lost","third hit ends match")
	g.start(false,12)
	g.players[0].gun=2
	g.players[0].shield=0
	g.players[0].x=4.5
	g.players[0].y=4.5
	g.tiles.fill(0)
	g.bullets=[{"x":4.5,"y":4.7,"dir":0,"owner":-1,"source":1,"gun":0}]
	g._update_bullets(0.05)
	check(g.players[0].lives==4 and g.players[0].gun==1,"solo death retains usable gun")
	g.wave=10
	var cap := g.spawn_interval()
	g._next_wave()
	g.wave=50
	check(g.spawn_interval()==cap and g.remaining==14,"solo difficulty capped")
	g.start(true,20)
	check(g.remaining==18 and g.enemy_limit()==6 and g.players[0].lives==3 and g.fort==0,"duo balance preserved")
	g.tiles.fill(0)
	g.tiles[248]=5
	shoot_base(g,-1)
	check(g.status=="lost","duo base remains one hit")
	# A simple defender moves along the clear cross-lane, lines up and aims up/down, returning to its defensive row after respawn.
	var wins := 0
	for map_index in 20:
		g.start(false,map_index+1)
		g.deck=[map_index]
		g.wave=0
		g._next_wave()
		var staged := false
		var last_lives := int(g.players[0].lives)
		for frame in 60*120:
			if g.status != "playing" or g.wave>1:
				break
			var p: Dictionary=g.players[0]
			if int(p.lives)<last_lives:
				staged=false
			last_lives=int(p.lives)
			var direction := -1
			var fire := false
			if not staged and float(p.y)>13.55:
				direction=0
			elif not g.enemies.is_empty():
				var target: Dictionary=g.enemies[0]
				for e in g.enemies:
					if float(e.y)>float(target.y):
						target=e
				var dx := float(target.x)-float(p.x)
				staged=true
				var aim := 0 if float(target.y)<float(p.y) else 2
				direction=1 if dx>0.12 else 3 if dx< -0.12 else (aim if int(p.dir)!=aim else -1)
				fire=absf(dx)<=0.12
			g.set_input(0,direction,fire)
			g.tick(1.0/60)
		if g.wave>1:
			wins+=1

	print("SOLO defender first-wave wins=",wins,"/20")
	check(wins>=15,"simple defender can clear most random solo maps")
	print("SOLO BALANCE checks=",checks," failures=",failures)
	quit(1 if failures else 0)

func shoot_base(g: TankSession, owner: int) -> void:
	g.bullets=[{"x":8.5,"y":14.99,"dir":2,"owner":owner,"source":1,"gun":0}]
	g._update_bullets(0.05)
