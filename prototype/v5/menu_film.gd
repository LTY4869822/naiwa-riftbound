extends RefCounted
## Captures actual GPU-rendered viewport frames, including the complete laugh.
## Run only through --slice-test --menu-film, together with --fixed-fps 30.
const FPS := 30
const FRAME_DIR := "res://artifacts/menu-v2-demo-frames/"

static func button(h: Node, key: String) -> Button:
	return h.hud.find_child(key,true,false) as Button

static func mark(state: Dictionary, name: String) -> void:
	state.events.append({"name":name,"frame":state.frame,"seconds":float(state.frame)/FPS})

static func record(h: Node, state: Dictionary, seconds: float) -> void:
	for index in range(int(round(seconds*FPS))):
		await RenderingServer.frame_post_draw
		var bitmap: Image=h.get_viewport().get_texture().get_image()
		bitmap.save_jpg(FRAME_DIR+"frame_%05d.jpg" % state.frame,0.90)
		state.last_image=bitmap
		state.frame+=1

static func snapshot(state: Dictionary, suffix: String) -> void:
	if state.last_image!=null:
		state.last_image.save_png("res://artifacts/menu-v2-demo-"+suffix+".png")

static func key(h: Node, action: String) -> void:
	for down in [true,false]:
		var event:=InputEventAction.new()
		event.action=action
		event.pressed=down
		h.get_viewport().push_input(event,true)

static func finish_transition(h: Node, state: Dictionary) -> void:
	var deadline: int=state.frame+FPS*3
	while h.menu_transition.busy and state.frame<deadline:
		await record(h,state,1.0/FPS)
	assert(not h.menu_transition.busy,"Menu transition did not finish")

static func run(h: Node) -> void:
	if not h.test_mode or Profile.save_enabled:
		push_error("Menu film requires isolated --slice-test")
		h.get_tree().quit(1)
		return
	h.audio_enabled=true
	h.reduce_motion=false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FRAME_DIR))
	var state: Dictionary={"frame":0,"events":[],"last_image":null}
	mark(state,"title_and_staggered_button_entrance")
	await record(h,state,1.2)
	snapshot(state,"front")
	mark(state,"keyboard_focus_down_to_supply")
	key(h,"ui_down")
	await record(h,state,0.4)
	key(h,"ui_down")
	await record(h,state,0.4)
	key(h,"ui_up")
	await record(h,state,0.4)
	mark(state,"confirm_supply_ink_transition")
	button(h,"OpenFeed").pressed.emit()
	await record(h,state,0.3)
	snapshot(state,"ink-cover")
	await finish_transition(h,state)
	await record(h,state,0.35)
	assert(h.menu_section=="feed")
	mark(state,"direct_desktop_feed_hint")
	button(h,"OpenRecycleFeed").pressed.emit()
	await record(h,state,0.4)
	snapshot(state,"supply")
	mark(state,"escape_back_ink_transition")
	key(h,"pause")
	await finish_transition(h,state)
	await record(h,state,0.35)
	assert(h.menu_section=="home")
	mark(state,"frontal_idle_before_laugh")
	await record(h,state,0.35)
	var laugh_frame: int=state.frame
	mark(state,"laugh_button_click")
	button(h,"LaughCompanion").pressed.emit()
	var pet: Control=h.hud.find_child("MenuCompanion",true,false)
	assert(pet!=null and pet.display_mode=="laugh")
	await record(h,state,0.18)
	snapshot(state,"front-laugh")
	await record(h,state,0.42)
	await record(h,state,4.0)
	snapshot(state,"laugh")
	await record(h,state,8.3)
	snapshot(state,"falling")
	await record(h,state,0.9)
	snapshot(state,"fall")
	await record(h,state,1.2)
	snapshot(state,"rest")
	await record(h,state,1.8)
	assert(pet.display_mode=="idle" and pet.current_frame==-1)
	snapshot(state,"recover")
	mark(state,"complete_recovery_to_frontal_idle")
	var metadata: Dictionary={
		"capture":"Every frame is an actual Godot viewport GPU readback; no composed still-image video.",
		"fps":FPS,"frames":state.frame,"duration_seconds":float(state.frame)/FPS,
		"width":state.last_image.get_width(),"height":state.last_image.get_height(),
		"laugh_trigger_frame":laugh_frame,
		"audio_offset_seconds":float(laugh_frame)/FPS+pet.INTRO_DURATION,
		"original_laugh_frames":422,"original_laugh_fps":30,
		"original_laugh_duration_seconds":pet.laugh_duration,
		"profile_save_enabled":Profile.save_enabled,
		"events":state.events,
	}
	var file:=FileAccess.open("res://artifacts/menu-v2-demo-metadata.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(metadata,"\t"))
	file.close()
	print("MENU_FILM frames=",state.frame," fps=",FPS," duration=",float(state.frame)/FPS," audio_offset=",metadata.audio_offset_seconds)
	h.get_tree().quit()
