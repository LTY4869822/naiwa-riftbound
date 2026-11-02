extends RefCounted
const FPS:=60
const DIR:="res://artifacts/route-jelly-demo-frames/"
var frame:=0
var events: Array[Dictionary]=[]

func record(h: Node, seconds: float) -> void:
	for i in roundi(seconds*FPS):
		await RenderingServer.frame_post_draw
		h.get_viewport().get_texture().get_image().save_jpg(DIR+"frame_%05d.jpg" % frame,0.94)
		frame+=1

func mark(name: String) -> void:
	events.append({"frame":frame,"name":name,"seconds":float(frame)/FPS})

func input(h: Node, down: bool) -> void:
	var event:=InputEventAction.new()
	event.action="ui_accept"
	event.pressed=down
	h.get_viewport().push_input(event,true)

func run(h: Node) -> void:
	if not h.test_mode or Profile.save_enabled:
		h.get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	h.audio_enabled=false
	Profile.level=3
	h.open_route()
	mark("spring entry")
	await record(h,0.9)
	var map: Node=h.hud.find_child("LevelRoute",true,false)
	for index in [1,3,2,0]:
		mark("focus card %d" % (index+1))
		map.cards[index].grab_focus()
		await record(h,0.7)
	mark("hold native confirm")
	input(h,true)
	await record(h,0.20)
	mark("release and rebound")
	input(h,false)
	await record(h,0.16)
	mark("ink transition")
	await record(h,1.04)
	if is_instance_valid(h.player): h.player.invuln=100
	h.open_route()
	mark("reopen from battle")
	await record(h,0.9)
	h.reduce_motion=true
	h.close_route()
	h.open_route()
	map=h.hud.find_child("LevelRoute",true,false)
	await h.get_tree().process_frame
	mark("reduced motion")
	map.cards[2].grab_focus()
	await record(h,1.0)
	var file:=FileAccess.open("res://artifacts/route-jelly-demo-metadata.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"frames":frame,"fps":FPS,"duration_seconds":float(frame)/FPS,
		"events":events,"capture":"Real Godot map UI, native focus and confirm input; isolated profile; silent motion preview."},"\t"))
	print("ROUTE_JELLY_FILM ",frame," frames")
	h.get_tree().quit()
