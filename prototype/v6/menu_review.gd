extends RefCounted
## Isolated functional navigation and real-render visual review; uses --slice-test.
static func find_button(h: Node, key: String) -> Button:
	return h.hud.find_child(key,true,false) as Button

static func press(h: Node, action: String) -> void:
	for down in [true,false]:
		var event := InputEventAction.new()
		event.action=action
		event.pressed=down
		h.get_viewport().push_input(event,true)
		await h.get_tree().process_frame

static func run(h: Node) -> void:
	var checks: Array[String] = []
	await h.get_tree().create_timer(0.9).timeout
	await h.capture("menu-home")
	checks.append("PASS home primary and native-pet return exist" if find_button(h,"StartJourney")!=null and find_button(h,"ReturnPet")!=null else "FAIL home actions")
	await press(h,"ui_down")
	checks.append("PASS keyboard down selects supply" if find_button(h,"OpenFeed").has_focus() else "FAIL keyboard focus")
	await press(h,"ui_accept")
	await h.get_tree().create_timer(1.2).timeout
	checks.append("PASS keyboard confirm opens supply page" if h.menu_section=="feed" else "FAIL supply navigation")
	if h.menu_section!="feed":
		print("FAIL supply navigation")
		h.get_tree().quit(1)
		return
	checks.append("PASS feed starts disabled without selection" if h.feed_button.disabled else "FAIL empty selection")
	find_button(h,"fragment-1").pressed.emit()
	await h.get_tree().process_frame
	find_button(h,"fragment-2").pressed.emit()
	await h.get_tree().process_frame
	await h.get_tree().create_timer(0.15).timeout
	await h.capture("menu-feed")
	checks.append("PASS fragment selection enables feed" if h.selected.size()==2 and not h.feed_button.disabled else "FAIL selection")
	h.feed_button.pressed.emit()
	await h.get_tree().create_timer(0.2).timeout
	checks.append("PASS real feeding consumes selected fragments and unlocks level two" if Profile.level==2 and Profile.xp==20 and Profile.files.size()==1 and str(Profile.files[0].id)=="fragment-3" and Profile.fed==2 else "FAIL feeding")
	await h.capture("menu-fed")
	find_button(h,"BackHome").pressed.emit()
	await h.get_tree().create_timer(1.2).timeout
	find_button(h,"OpenGrowth").pressed.emit()
	await h.get_tree().create_timer(1.2).timeout
	await h.capture("menu-growth")
	find_button(h,"BackHome").pressed.emit()
	await h.get_tree().create_timer(1.2).timeout
	find_button(h,"OpenSettings").pressed.emit()
	await h.get_tree().create_timer(1.2).timeout
	find_button(h,"SoundToggle").pressed.emit()
	checks.append("PASS sound toggle changes runtime setting" if not h.audio_enabled else "FAIL sound toggle")
	find_button(h,"MotionToggle").pressed.emit()
	checks.append("PASS reduced motion changes runtime setting" if h.reduce_motion else "FAIL motion toggle")
	await h.get_tree().create_timer(0.2).timeout
	await h.capture("menu-settings")
	await press(h,"pause")
	await h.get_tree().create_timer(1.2).timeout
	checks.append("PASS escape returns to home" if h.menu_section=="home" else "FAIL back navigation")
	await press(h,"ui_accept")
	await h.get_tree().create_timer(1.2).timeout
	checks.append("PASS keyboard confirm begins journey" if h.mode=="battle" else "FAIL keyboard confirm")
	await h.get_tree().physics_frame
	await h.get_tree().create_timer(0.3).timeout
	var hero: Node = h.player
	h.toggle_pause()
	await h.get_tree().create_timer(0.2).timeout
	await h.capture("menu-pause")
	h.camp()
	checks.append("PASS home offers continue for existing battle" if find_button(h,"StartJourney").title=="继续巡游" else "FAIL continue label")
	find_button(h,"StartJourney").pressed.emit()
	await h.get_tree().create_timer(1.2).timeout
	checks.append("PASS continue keeps same player and session" if h.player==hero and h.mode=="battle" and not h.paused else "FAIL continue session")
	h.camp()
	for dimensions in [Vector2i(1120,630),Vector2i(960,600)]:
		h.get_window().size=dimensions
		await h.get_tree().create_timer(0.35).timeout
		await h.capture("menu-home-%dx%d" % [dimensions.x,dimensions.y])
		var menu: Node=h.hud.get_child(0)
		var box := Rect2(menu.canvas.position,Vector2(1280,800)*menu.canvas.scale)
		var actual: Vector2i=h.get_window().size
		checks.append("PASS layout fits %dx%d" % [actual.x,actual.y] if actual==dimensions and Rect2(Vector2(-1,-1),menu.size+Vector2(2,2)).encloses(box) else "FAIL layout bounds or window resize: requested %s got %s" % [dimensions,actual])
	checks.append("PASS review cannot save profile or preferences" if h.test_mode and not Profile.save_enabled else "FAIL save isolation")
	var failed := 0
	for line in checks:
		print(line)
		if line.begins_with("FAIL"): failed+=1
	var file := FileAccess.open("res://artifacts/menu-checks.txt",FileAccess.WRITE)
	file.store_string("\n".join(checks)+"\nFailures=%d\n" % failed)
	h.get_tree().quit(failed)
