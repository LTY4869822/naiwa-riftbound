extends RefCounted
## Isolated keyboard navigation, asynchronous transition and full original-laugh review.
## Run with --slice-test --menu-review: neither profile nor menu preferences can be saved.
static func find_button(h: Node, key: String) -> Button:
	return h.hud.find_child(key,true,false) as Button

static func press(h: Node, action: String) -> void:
	for down in [true,false]:
		var event:=InputEventAction.new()
		event.action=action
		event.pressed=down
		h.get_viewport().push_input(event,true)
		await h.get_tree().process_frame

static func settle(h: Node, seconds: float = 1.2) -> void:
	await h.get_tree().create_timer(seconds).timeout

static func navigate_button(h: Node, key: String) -> bool:
	var button:=find_button(h,key)
	if button==null:
		print("FAIL missing menu button ",key)
		return false
	button.pressed.emit()
	await settle(h)
	return true

static func report(h: Node, checks: Array[String]) -> void:
	var failed:=0
	for line in checks:
		print(line)
		if line.begins_with("FAIL"): failed+=1
	var file:=FileAccess.open("res://artifacts/menu-v2-checks.txt",FileAccess.WRITE)
	file.store_string("\n".join(checks)+"\nFailures=%d\n" % failed)
	print("MENU_V2_CHECKS ",checks.size()," failures=",failed)
	h.get_tree().quit(failed)

static func run(h: Node) -> void:
	var checks: Array[String]=[]
	await settle(h)
	await h.capture("menu-v2-home")
	checks.append("PASS home primary and native-pet return exist" if find_button(h,"StartJourney")!=null and find_button(h,"ReturnPet")!=null else "FAIL home actions")
	var menu: Node=h.hud.get_child(0)
	var pet: Node=menu.pet
	checks.append("PASS frontal companion asset is present and loaded" if pet.has_front_asset and pet.front_texture!=null and pet.front_texture.get_width()>0 else "FAIL frontal companion asset")
	var saved_audio: bool=h.audio_enabled
	h.audio_enabled=false
	pet.set_process(false)
	var first: bool=pet.play_laugh()
	var duplicate: bool=pet.play_laugh()
	checks.append("PASS laugh starts once and rejects duplicate" if first and not duplicate and pet.archive_open else "FAIL laugh admission")
	var seen: Dictionary={}
	for i in range(27):
		pet._process(1.0/30.0)
		seen[pet.current_frame]=true
		await h.get_tree().process_frame
	checks.append("PASS laugh advances original frames after 0.8 seconds" if pet.current_frame>0 and pet.display_mode=="laugh" else "FAIL laugh advance")
	for i in range(27,505):
		pet._process(1.0/30.0)
		if pet.current_frame>=0: seen[pet.current_frame]=true
		if i==120: await h.capture("menu-v2-laugh")
		await h.get_tree().process_frame
		if pet.display_mode=="idle": break
	checks.append("PASS full 422-frame source is decoded in order" if seen.size()==422 and seen.has(0) and seen.has(421) else "FAIL complete source frames decoded: %d" % seen.size())
	checks.append("PASS original laugh source duration is 14.07 seconds" if absf(pet.laugh_duration-422.0/30.0)<0.001 else "FAIL source laugh duration")
	checks.append("PASS laugh completes rest and recovery then restores front idle" if pet.display_mode=="idle" and pet.current_frame==-1 and not pet.audio.playing else "FAIL laugh recovery")
	checks.append("PASS laugh texture cache remains bounded" if pet.frame_cache.size()<=pet.CACHE_LIMIT else "FAIL laugh cache")
	pet.set_process(true)
	h.audio_enabled=saved_audio
	await press(h,"ui_down")
	checks.append("PASS keyboard down selects supply" if find_button(h,"OpenFeed").has_focus() else "FAIL keyboard focus")
	var swaps_before: int=h.menu_transition.action_count
	await press(h,"ui_accept")
	# A second request during coverage must be ignored rather than enqueue an unwanted page.
	h.menu_navigate("growth")
	await settle(h,0.10)
	checks.append("PASS ink cover starts before the page changes" if h.menu_transition.busy and h.menu_transition.phase=="cover" and h.menu_section=="home" else "FAIL pre-midpoint ink state")
	await h.capture("menu-v2-cover")
	await settle(h,0.34)
	await h.capture("menu-v2-reveal")
	await settle(h)
	checks.append("PASS keyboard confirm opens supply page" if h.menu_section=="feed" else "FAIL supply navigation")
	checks.append("PASS busy transition executes only one page callback" if h.menu_transition.action_count==swaps_before+1 and h.menu_section=="feed" and not h.menu_transition.busy else "FAIL duplicate transition guard")
	if h.menu_section!="feed":
		report(h,checks)
		return
	var direct:=find_button(h,"OpenRecycleFeed")
	checks.append("PASS one direct desktop feed action is available" if direct!=null and not direct.disabled else "FAIL direct feeding action")
	checks.append("PASS feeding has no categories or selectable file list" if find_button(h,"fragment-1")==null and h.hud.find_child("FragmentScroll",true,false)==null else "FAIL obsolete file selection UI")
	var state_before: Dictionary=Profile.to_dict().duplicate(true)
	if direct!=null: direct.pressed.emit()
	await settle(h,0.15)
	checks.append("PASS isolated feed action shows a hint without changing progress" if Profile.to_dict()==state_before and h.toast_text.contains("隔离试玩") else "FAIL isolated feeding action")
	var bytes_remaining: int=h.hud.get_child(0).bytes_to_next_level()
	checks.append("PASS file-growth threshold uses bytes and existing level progress" if bytes_remaining==480*1024*1024 else "FAIL byte growth threshold")
	await h.capture("menu-v2-feed")

	await navigate_button(h,"BackHome")
	await navigate_button(h,"OpenGrowth")
	await h.capture("menu-v2-growth")
	await navigate_button(h,"BackHome")
	await navigate_button(h,"OpenSettings")
	find_button(h,"SoundToggle").pressed.emit()
	await settle(h,0.15)
	checks.append("PASS sound toggle changes runtime setting" if not h.audio_enabled else "FAIL sound toggle")
	find_button(h,"MotionToggle").pressed.emit()
	await settle(h,0.15)
	checks.append("PASS reduced motion changes runtime setting" if h.reduce_motion else "FAIL motion toggle")
	await h.capture("menu-v2-settings")
	var reduced_count: int=h.menu_transition.action_count
	h.menu_navigate("growth")
	checks.append("PASS reduced motion switches page immediately without a wipe" if h.menu_section=="growth" and not h.menu_transition.busy and h.menu_transition.action_count==reduced_count else "FAIL reduced-motion transition")
	h.menu_navigate("settings")
	await h.get_tree().process_frame
	await press(h,"pause")
	await settle(h)
	checks.append("PASS escape returns to home" if h.menu_section=="home" else "FAIL back navigation")
	await press(h,"ui_accept")
	await settle(h)
	checks.append("PASS keyboard confirm begins journey" if h.mode=="battle" else "FAIL keyboard confirm")
	if not is_instance_valid(h.player):
		report(h,checks)
		return
	var hero: Node=h.player
	h.toggle_pause()
	await settle(h,0.2)
	await h.capture("menu-v2-pause")
	h.camp()
	await settle(h)
	checks.append("PASS home offers continue for existing battle" if find_button(h,"StartJourney").title=="继续巡游" else "FAIL continue label")
	await navigate_button(h,"StartJourney")
	checks.append("PASS continue keeps same player and session" if h.player==hero and h.mode=="battle" and not h.paused else "FAIL continue session")
	h.camp()
	await settle(h)
	for dimensions in [Vector2i(1120,630),Vector2i(960,600)]:
		h.get_window().size=dimensions
		await settle(h,0.4)
		await h.capture("menu-v2-home-%dx%d" % [dimensions.x,dimensions.y])
		menu=h.hud.get_child(0)
		var box:=Rect2(menu.canvas.position,Vector2(1280,800)*menu.canvas.scale)
		var actual: Vector2i=h.get_window().size
		checks.append("PASS layout fits %dx%d" % [actual.x,actual.y] if actual==dimensions and Rect2(Vector2(-1,-1),menu.size+Vector2(2,2)).encloses(box) else "FAIL layout bounds or window resize: requested %s got %s" % [dimensions,actual])
	checks.append("PASS review cannot save profile or preferences" if h.test_mode and not Profile.save_enabled else "FAIL save isolation")
	report(h,checks)
