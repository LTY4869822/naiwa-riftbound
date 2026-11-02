extends RefCounted
var frames:=0
var shots: Array=[]
var h: Node
func frame(shot: String="") -> void:
	await RenderingServer.frame_post_draw
	var im: Image=h.get_viewport().get_texture().get_image()
	im.save_jpg("res://artifacts/ascension-frames/frame_%05d.jpg" % frames,0.91)
	frames+=1
	if not shot.is_empty():
		im.save_png("res://artifacts/ascension-"+shot+".png")
		shots.append(shot)
	await h.get_tree().process_frame

func run(host: Node) -> void:
	h=host
	if not h.test_mode or Profile.save_enabled: h.get_tree().quit(1); return
	h.audio_enabled=false
	h.get_window().size=Vector2i(1280,800)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/ascension-frames"))
	Profile.level=5
	h.open_route()
	for i in 45: await frame("route" if i==40 else "")
	h.choose_level(0,2)
	h.wait_wave=999
	h.wave=3
	h.player.position=Vector2(300,640)
	Ascension.energy=82
	var minion: Node=h.spawn("melee",410)
	minion.hp=1
	var guardian: Node=h.spawn("zheng",1000)
	guardian.ult_cooldown=20
	var begun:=false
	var released:=false
	var peak_shot:=false
	for i in 255:
		Input.action_release("move_right")
		if i==8: h.player.attack(0)
		if Ascension.energy>=100 and not begun and h.player.state=="idle": begun=h.ascension.awaken()
		if h.ascension.empowered() and h.ascension.age<0.9:
			Input.action_press("move_right")
			if h.ascension.age>0.25 and h.ascension.age<0.32: h.player.dash()
		if h.ascension.empowered() and h.ascension.age>1.1 and not released:
			h.player.facing=1
			released=h.ascension.finisher()
		var shot: String="transformation" if i==40 else "form" if i==80 else "ultimate" if i==125 else "reversion" if i==205 else ""
		if h.ascension.phase=="finisher" and h.ascension.age>=1.44 and not peak_shot:
			peak_shot=true
			shot="ultimate-impact"
		await frame(shot)
	Input.action_release("move_right")
	for map in 4:
		h.choose_level(map,2)
		h.wait_wave=999
		h.wave=3
		h.arena.cooldown=999
		h.player.position=Vector2(275,640)
		var e: Node=h.spawn(h.current_level().boss,1000)
		e.hp=roundi(e.maximum*0.85)
		e.combat_age=8
		e.ult_cooldown=0
		e.cooldown=999
		for i in 160:
			Input.action_release("move_right")
			if i>=43 and i<84:
				Input.action_press("move_right")
				if i==46:
					h.player.facing=1
					h.player.dash()
			await frame("mythic-%d-charge" % map if i==27 else "mythic-%d-impact" % map if i==59 else "mythic-%d-follow" % map if i==75 else "")
		Input.action_release("move_right")
	h.ascension.clear()
	var f:=FileAccess.open("res://artifacts/ascension-film.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"frames":frames,"fps":30,"seconds":frames/30.0,"shots":shots,"real_gpu_renderer":true,"invulnerability_override":false,"scenario":"Seeded demonstration: one low-HP minion fills the final 18 energy; actual transformation, input movement, hero finisher and four real boss AI ultimates."},"\t"))
	f.close()
	print("ASCENSION_FILM ",frames," frames")
	h.get_tree().quit()
