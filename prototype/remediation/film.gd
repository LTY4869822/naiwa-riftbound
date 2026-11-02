extends RefCounted
var frames:=0
var chapter:=""
var shots: Array[String]=[]

func frame(h: Node, save: String="") -> void:
	await RenderingServer.frame_post_draw
	var image: Image=h.get_viewport().get_texture().get_image()
	image.save_jpg("res://artifacts/ultimate-v2-frames/frame_%05d.jpg" % frames,0.9)
	frames+=1
	if not save.is_empty():
		image.save_png("res://artifacts/ultimate-v2-"+save+".png")
		shots.append(save)
	await h.get_tree().process_frame

func run(h: Node) -> void:
	if not h.test_mode or Profile.save_enabled: h.get_tree().quit(1); return
	h.audio_enabled=false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/ultimate-v2-frames"))
	h.get_window().size=Vector2i(1280,800)
	Profile.level=3
	h.choose_level(0)
	h.wait_wave=999
	h.wave=5
	h.player.position=Vector2(310,640)
	h.player.focus=100
	var target: Node=h.spawn("boss",1000)
	target.cooldown=999
	target.ult_cooldown=999
	# Seed the showcase; actor movement, skill release, swept contacts and VFX run normally.
	for i in 110:
		if i==18: h.player.skill()
		await frame(h,"hero-charge" if i==28 else "hero-punch" if i==42 else "hero-impact" if i==49 else "")
	for index in 4:
		h.choose_level(index)
		h.wait_wave=999
		h.wave=h.CAMPAIGN.wave_count(index)
		h.arena.cooldown=999
		var e: Node=h.spawn(h.current_level().boss,940)
		e.hp=roundi(e.maximum*0.75)
		e.combat_age=8
		e.ult_cooldown=0
		e.cooldown=999
		h.player.position=Vector2(245,640)
		h.refresh_hud()
		for i in 162:
			Input.action_release("move_left")
			Input.action_release("move_right")
			if not e.ult_data.is_empty() and e.state in ["ult_tell","ult_active"]:
				var dx: float=620.0-h.player.position.x
				if absf(dx)>28:
					Input.action_press("move_right" if dx>0 else "move_left")
					if i==12: h.player.facing=1 if dx>0 else -1; h.player.dash()
			await frame(h,"boss-%d-cutin" % index if i==9 else "boss-%d-warning" % index if i==35 else "boss-%d-peak" % index if i==80 else "boss-%d-recovery" % index if i==148 else "")
		Input.action_release("move_left")
		Input.action_release("move_right")
	# Capture the actual remapping screen and larger battle text at the minimum window size.
	h.camp()
	h.menu_section="controls"
	h.build_ui()
	for i in 12: await frame(h,"controls" if i==11 else "")
	Preferences.large_text=true
	h.get_window().size=Vector2i(960,600)
	h.choose_level(2)
	h.wait_wave=999
	h.wave=3
	var boss: Node=h.spawn("tempest_boss",940)
	boss.cooldown=999
	boss.ult_cooldown=999
	for i in 12: await frame(h,"large-text-960" if i==11 else "")
	Preferences.large_text=false
	var f:=FileAccess.open("res://artifacts/ultimate-v2-film.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"frames":frames,"fps":30,"duration":frames/30.0,"shots":shots,"real_renderer":true,"damage_logic":"real release and collision; scenarios seeded for demonstration","invulnerability_override":false},"\t"))
	print("ULTIMATE_V2_FILM ",frames," frames")
	h.get_tree().quit()
