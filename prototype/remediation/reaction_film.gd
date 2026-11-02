extends RefCounted
var frames:=0
var shots: Array[String]=[]

func frame(h: Node, shot: String="") -> void:
	await RenderingServer.frame_post_draw
	var image: Image=h.get_viewport().get_texture().get_image()
	image.save_jpg("res://artifacts/reaction-frames/frame_%05d.jpg" % frames,0.9)
	frames+=1
	if not shot.is_empty():
		image.save_png("res://artifacts/reaction-"+shot+".png")
		shots.append(shot)
	await h.get_tree().process_frame

func run(h: Node) -> void:
	if not h.test_mode or Profile.save_enabled: h.get_tree().quit(1); return
	h.audio_enabled=false
	h.get_window().size=Vector2i(1280,800)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/reaction-frames"))
	Profile.level=3
	h.choose_level(0)
	h.wait_wave=999
	h.wave=5
	h.player.position=Vector2(300,640)
	for i in 100:
		Input.action_release("move_right")
		Input.action_release("move_left")
		if i<40: Input.action_press("move_right")
		elif i>=50 and i<90: Input.action_press("move_left")
		if i in [10,62]: h.player.dash()
		await frame(h,"sprint-right" if i==13 else "sprint-left" if i==65 else "wind-tail" if i==17 else "")
	Input.action_release("move_left")
	for index in 4:
		h.choose_level(index)
		h.wait_wave=999
		h.wave=h.CAMPAIGN.wave_count(index)
		h.arena.cooldown=999
		var from_right: bool=index%2==0
		var e: Node=h.spawn(h.current_level().boss,940 if from_right else 300)
		e.hp=roundi(e.maximum*0.75)
		e.combat_age=8
		e.ult_cooldown=0
		e.cooldown=999
		h.player.position=Vector2(245 if from_right else 1035,640)
		h.refresh_hud()
		for i in 140:
			Input.action_release("move_left")
			Input.action_release("move_right")
			# Actual inputs leave the warned attack footprint; there is no reserved lane.
			if i<58:
				Input.action_press("move_right" if from_right else "move_left")
				if i==12:
					h.player.facing=1 if from_right else -1
					h.player.dash()
			await frame(h,"boss-%d-aim" % index if i==27 else "boss-%d-strike" % index if i==58 else "boss-%d-follow" % index if i==78 else "")
		Input.action_release("move_left")
		Input.action_release("move_right")
	var f:=FileAccess.open("res://artifacts/reaction-film.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"frames":frames,"fps":30,"duration":frames/30.0,"shots":shots,"real_renderer":true,"invulnerability_override":false,"scenario":"seeded actors; real AI, movement, damage and sprite animation; no safe-zone mechanism"},"\t"))
	print("REACTION_FILM ",frames," frames")
	h.get_tree().quit()
