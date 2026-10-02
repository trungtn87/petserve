extends Node
class FailingFacade extends InfantGameFacade:
	var fail := false
	func save() -> bool:
		return false if fail else super.save()
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var had_meta := SaveManager.has_meta_save()
	var original := SaveManager.load_meta()
	_test_maps()
	_test_simulation()
	_test_rewards()
	await _test_network_ui()
	if had_meta:
		SaveManager.save_meta(original)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.META_PATH))
	print("TANK checks=",checks," failures=",failures)
	get_tree().quit(1 if failures else 0)

func _test_maps() -> void:
	var maps := TankMaps.all_maps()
	check(maps.size() == 20,"20 authored maps")
	var unique: Dictionary = {}
	for i in 20:
		var cells := TankMaps.cells(i)
		check(cells.size()==169 and cells.count(5)==1,"valid 13x13 map and one base")
		unique[str(maps[i].rows)] = true
		# Steel/water are impassable; brick may be destroyed to approach the base.
		for start in [0,6,12,160,164]:
			var seen: Dictionary = {start:true}
			var queue: Array = [start]
			while not queue.is_empty():
				var cell: int = queue.pop_front()
				for d in TankSession.DIRS:
					var x := cell%13+int(d.x)
					var y := cell/13+int(d.y)
					var next := y*13+x
					if x>=0 and x<13 and y>=0 and y<13 and not seen.has(next) and int(cells[next]) not in [2,3]:
						seen[next]=true
						queue.append(next)
			check(seen.has(162),"spawn can reach base in every map")
	check(unique.size()==20,"all maps distinct")
	var game := TankSession.new()
	game.start(false,123)
	var used: Array = []
	for i in 20:
		used.append(game.map_index)
		game._next_wave()
	used.sort()
	check(used == range(20),"shuffle bag uses all maps without repeats")

func _test_simulation() -> void:
	var g := TankSession.new()
	g.start(true,42)
	check(g.players.size()==2 and g.players[0].lives==3,"duo separate lives")
	g.tiles.fill(0)
	g.players[0].x=4.5
	g.players[0].y=4.5
	g.players[1].x=4.5
	g.players[1].y=4.5
	check(g._move(g.players[0],0.05),"players never block each other")
	g.players[0].x=4.5
	g.players[0].y=4.5
	g.tiles[3*13+4]=1
	g.bullets=[{"x":4.5,"y":4.05,"dir":0,"owner":0,"source":0,"gun":0}]
	g._update_bullets(0.05)
	check(g.tiles[3*13+4]==0 and g.bullets.is_empty(),"bullet breaks brick and stops")
	g.tiles[3*13+4]=2
	g.bullets=[{"x":4.5,"y":4.05,"dir":0,"owner":0,"source":0,"gun":0}]
	g._update_bullets(0.05)
	check(g.tiles[3*13+4]==2,"normal bullet cannot destroy steel")
	g.bullets=[{"x":4.5,"y":4.05,"dir":0,"owner":0,"source":0,"gun":3}]
	g._update_bullets(0.05)
	check(g.tiles[3*13+4]==0,"fully upgraded bullet destroys steel")
	g.players[1].shield=0
	g.bullets=[{"x":4.5,"y":4.8,"dir":0,"owner":0,"source":0,"gun":0}]
	g._update_bullets(0.05)
	check(g.players[1].lives==3,"friendly fire causes no damage")
	g.bullets=[{"x":4.5,"y":4.8,"dir":0,"owner":-1,"source":1,"gun":0}]
	g.players[0].shield=0
	g._update_bullets(0.05)
	check(g.players[0].lives==2 and g.players[0].shield>0,"enemy hit respawns with shield")
	g.tiles[162]=5
	g.bullets=[{"x":6.5,"y":11.99,"dir":2,"owner":-1,"source":1,"gun":0}]
	g._update_bullets(0.05)
	check(g.status=="lost","base destruction ends match")
	g.start(true,8)
	g.players[0].gun=0
	g._power(g.players[0],0,0)
	check(g.players[0].gun==1 and g.players[1].gun==0,"gun pickup belongs to collector")
	g._power(g.players[0],1,0)
	check(g.players[0].shield==8.0,"shield power duration")
	g._power(g.players[0],2,0)
	check(g.frozen==6.0,"freeze benefits team")
	g._spawn()
	var before_score: int=g.players[1].score
	g._power(g.players[1],3,1)
	check(g.enemies.is_empty() and g.players[1].score>before_score,"bomb grants collector kill points")
	g.tiles[148]=0
	g._power(g.players[0],4,0)
	check(g.fort==10.0 and g.tiles[148]==1,"fort repairs base walls")
	g.bullets=[{"x":5.5,"y":10.99,"dir":2,"owner":-1,"source":1,"gun":0}]
	g._update_bullets(0.05)
	check(g.tiles[148]==1,"fort prevents brick destruction")
	g.start(false,10)
	g.remaining=0
	g.enemies.clear()
	g.tick(0.02)
	check(g.wave==2,"clearing enemies advances wave")
	g.players[0].lives=0
	g.tick(0.02)
	check(g.status=="lost","all players dead ends match")
	g.start(true,55)
	for i in 1800:
		g.set_input(0,i/120%4,true)
		g.tick(1.0/60)
	check(JSON.stringify(g.snapshot()).to_utf8_buffer().size()<14000,"snapshot fits shared transport limit")

func _test_rewards() -> void:
	SaveManager.save_meta({})
	var api := FailingFacade.new()
	check(api.setup(999001,1,&"dark"),"facade setup")
	var g := TankSession.new()
	g.start(true)
	g.players[0].score=6000
	g.players[1].score=3000
	check(not api.settle_tank(g.snapshot(),0).ok,"live match cannot claim")
	g.status="lost"
	api.fail=true
	check(not api.settle_tank(g.snapshot(),0).ok,"failed save rejected")
	check(api.tank_records(true).is_empty(),"failed save rolls records back")
	api.fail=false
	var result := api.settle_tank(g.snapshot(),1)
	check(result.ok and result.fragments==3 and result.bonus_chests==1,"personal score fragments and team record bonus")
	check(not api.settle_tank(g.snapshot(),1).ok,"duplicate reward blocked")
	var api2 := InfantGameFacade.new()
	api2.setup(999001,1,&"dark")
	check(not api2.settle_tank(g.snapshot(),1).ok,"duplicate blocked after reload")
	check(api2.tank_records(true).best_score==9000 and api2.tank_records(false).is_empty(),"separate solo and duo records")
	g.start(true)
	g.players[0].score=10000
	g.status="lost"
	check(api.settle_tank(g.snapshot(),0).bonus_chests==0,"daily record chest cap")

func wait_for(predicate: Callable, seconds: float = 3.0) -> bool:
	var deadline := Time.get_ticks_msec()+int(seconds*1000)
	while not predicate.call() and Time.get_ticks_msec()<deadline:
		await get_tree().process_frame
	return bool(predicate.call())

func _test_network_ui() -> void:
	var host := LocalConnectionService.new()
	var guest := LocalConnectionService.new()
	add_child(host)
	add_child(guest)
	check(host.host_wifi()==OK and guest.join_wifi("127.0.0.1")==OK,"real Wi-Fi peers created")
	check(await wait_for(func(): return host.connected() and guest.connected()),"real peers connected")
	var ui1 := TankActivityUI.new()
	var ui2 := TankActivityUI.new()
	ui1.connection=host
	ui2.connection=guest
	add_child(ui1)
	add_child(ui2)
	ui1.size=Vector2(300,460)
	ui2.size=Vector2(300,460)
	ui1.open_activity()
	ui2.open_activity()
	ui1._duo_start()
	check(not ui1._running,"host waits for guest readiness")
	ui2._duo_start()
	check(await wait_for(func(): return ui1._peer_in_tank),"Tank readiness over network")
	ui1._duo_start()
	check(await wait_for(func(): return ui2._running),"guest receives authoritative start")
	check(ui1._accepted==ui2._accepted and ui1._state.map_index==ui2._state.map_index,"same match and random map on both devices")
	ui2._press("up")
	var y: float=ui1.session.players[1].y
	check(await wait_for(func(): return float(ui1.session.players[1].y)<y-0.1),"guest controls second tank on host")
	ui2._release("up")
	ui1._toggle_pause()
	check(await wait_for(func(): return ui2._paused),"host pause mirrored")
	ui1._toggle_pause()
	ui1.session.status="lost"
	check(await wait_for(func(): return not ui2._running),"finished match delivered to guest")
	check(ui2._state.status=="lost","guest has final result")
	ui1.close_activity()
	ui2.close_activity()
	ui1.open_activity()
	ui2.open_activity()
	ui2._claim.visible=false
	ui2._duo_start()
	await wait_for(func(): return ui1._peer_in_tank)
	ui1._duo_start()
	await wait_for(func(): return ui2._running)
	guest.disconnect_session()
	check(await wait_for(func(): return not ui1._running),"disconnect aborts host match")
	check(not ui1._claim.visible and not ui2._claim.visible,"disconnect gives no reward")
	ui1.queue_free()
	ui2.queue_free()
	host.queue_free()
	guest.queue_free()
	var hub := EntertainmentHubUI.new()
	add_child(hub)
	await get_tree().process_frame
	check(hub._tank_activity!=null,"Tank integrated into entertainment hub")
	hub.queue_free()
