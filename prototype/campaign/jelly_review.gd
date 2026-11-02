extends RefCounted
var results: Array[String]=[]
var shots := false

func check(ok: bool, title: String) -> void:
	results.append(("PASS " if ok else "FAIL ")+title)

func event(h: Node, action: String, down: bool) -> void:
	var key:=InputEventAction.new()
	key.action=action
	key.pressed=down
	h.get_viewport().push_input(key,true)

func press(h: Node, action: String) -> void:
	event(h,action,true)
	await h.get_tree().process_frame
	event(h,action,false)
	await h.get_tree().process_frame

func capture(h: Node, name: String) -> void:
	if shots: await h.capture("route-jelly-"+name)

func route(h: Node) -> Node:
	return h.hud.find_child("LevelRoute",true,false)

func run(h: Node, with_shots: bool=false) -> void:
	shots=with_shots
	if not h.test_mode or Profile.save_enabled:
		h.get_tree().quit(1)
		return
	h.set_process(false)
	h.audio_enabled=false
	Profile.level=3
	h.open_route()
	await h.get_tree().create_timer(0.7).timeout
	var map: Node=route(h)
	map.cards[0].grab_focus()
	await h.get_tree().create_timer(0.3).timeout
	check(map.cards.size()==4 and map.cards[0].has_focus(),"four map cards open with an accessible native initial focus")
	check(map.cards.all(func(c): return c.get_script().resource_path=="res://campaign/jelly_card.gd"),"all four real maps use the jelly card component")
	await capture(h,"idle")
	await press(h,"ui_right")
	check(map.cards[1].has_focus() and map.cards.filter(func(c): return c.highlighted).size()==1,"right moves one focus and one highlight to the next column")
	await h.get_tree().create_timer(0.45).timeout
	check(map.focus_box.position.distance_to(map.cards[1].position)<25,"shared focus outline settles onto the newly focused card")
	await capture(h,"focus")
	await press(h,"ui_down")
	check(map.cards[3].has_focus(),"down follows the same column")
	await press(h,"ui_left")
	check(map.cards[2].has_focus(),"left follows the same row")
	await press(h,"ui_up")
	check(map.cards[0].has_focus(),"up returns to the first row")
	await h.get_tree().create_timer(0.15).timeout
	# A held native confirmation produces compression but cannot enter a level yet.
	event(h,"ui_accept",true)
	await h.get_tree().create_timer(0.12).timeout
	check(map.cards[0].held and map.cards[0].face.scale.y<0.97,"holding confirm compresses the glossy surface")
	check(is_equal_approx(map.cards[0].scale.x,map.cards[0].scale.y),"copy is outside the squash layer and keeps a uniform scale")
	check(h.mode=="camp" and h.route_open,"a held press does not enter a map before release")
	await capture(h,"press")
	event(h,"ui_accept",false)
	await h.get_tree().process_frame
	var first: Node=map.cards[0]
	check(map.committing and map.pending_level==0,"releasing confirm commits the selected map")
	map.cards[3].pressed.emit()
	check(map.activation_count==1 and map.pending_level==0,"rapid duplicate activation cannot select another map")
	await h.get_tree().create_timer(0.08).timeout
	check(first.face.scale.y>0.99,"the pressed surface rebounds before the transition")
	await capture(h,"rebound")
	await h.get_tree().create_timer(0.28).timeout
	check(h.menu_transition.busy,"level activation uses the persistent ink transition")
	await capture(h,"transition")
	await h.get_tree().create_timer(0.7).timeout
	check(h.mode=="battle" and h.level_index==0 and not h.route_open and not h.menu_transition.busy,"transition enters the correct live environment exactly once")
	h.player.set_physics_process(false)
	var player: Node=h.player
	var at: Vector2=player.position
	h.open_route()
	await h.get_tree().create_timer(0.65).timeout
	map=route(h)
	await press(h,"pause")
	await h.get_tree().create_timer(0.9).timeout
	check(not h.route_open and h.paused and h.player==player and player.position==at,"Escape returns to the same paused battle without moving the hero")
	h.open_route()
	await h.get_tree().create_timer(0.65).timeout
	map=route(h)
	map.cards[3].pressed.emit()
	await press(h,"pause")
	await h.get_tree().create_timer(0.9).timeout
	check(h.level_index==0 and not h.route_open and not h.menu_transition.busy,"Escape before coverage cancels the queued map activation")
	h.open_route()
	await h.get_tree().create_timer(0.65).timeout
	map=route(h)
	for dimensions in [Vector2i(1120,630),Vector2i(960,600)]:
		h.get_window().size=dimensions
		await h.get_tree().create_timer(0.18).timeout
		var bounds:=Rect2(map.canvas.position,Vector2(1280,800)*map.canvas.scale)
		check(Rect2(Vector2(-1,-1),map.size+Vector2(2,2)).encloses(bounds),"reference canvas fits %dx%d" % [dimensions.x,dimensions.y])
		check(map.cards.all(func(c): return c.size.x*map.canvas.scale.x>400 and c.size.y*map.canvas.scale.y>170),"map hit targets remain large at %dx%d" % [dimensions.x,dimensions.y])
		await capture(h,"%dx%d" % [dimensions.x,dimensions.y])
	h.reduce_motion=true
	h.close_route()
	h.open_route()
	await h.get_tree().process_frame
	map=route(h)
	map.cards[2].grab_focus()
	await h.get_tree().process_frame
	map.cards[2].button_down.emit()
	await h.get_tree().create_timer(0.12).timeout
	check(map.cards[2].entrance==1 and map.cards[2].face.scale==Vector2.ONE and map.cards[2].hover_velocity==0,"reduced motion removes entry bounce, spring and surface deformation")
	await capture(h,"reduced")
	map.cards[2].button_up.emit()
	map.cards[2].pressed.emit()
	check(h.level_index==2 and not h.route_open and not h.menu_transition.busy,"reduced motion immediately enters the chosen map")
	check(not Profile.save_enabled,"map UI review cannot write the real profile")
	var failed: int=results.filter(func(s): return s.begins_with("FAIL")).size()
	var file:=FileAccess.open("res://artifacts/route-jelly-checks.txt",FileAccess.WRITE)
	file.store_string("\n".join(results)+"\nFailures=%d\n" % failed)
	for line in results: print(line)
	print("ROUTE_JELLY_CHECKS ",results.size()," failures=",failed)
	h.get_tree().quit(failed)
