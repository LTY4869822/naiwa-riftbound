extends RefCounted
## Record the real physics/render path, at native timing, with no mocked VFX.
const FPS := 60
const DIR := "res://artifacts/ultimate-demo-frames/"
var frame := 0
var audio_events: Array[Dictionary]=[]
var prior_launches := 0
var prior_hits := 0
var last_hit_launch := -1

func record(h: Node, seconds: float) -> void:
	for i in roundi(seconds*FPS):
		await RenderingServer.frame_post_draw
		if h.ultimate.launch_count>prior_launches:
			audio_events.append({"frame":frame,"sound":"ultimate_launch"})
			prior_launches=h.ultimate.launch_count
		if h.ultimate.hit_count>prior_hits:
			# Runtime plays the heavy impact sound only on a wave's first target.
			if last_hit_launch!=prior_launches:
				audio_events.append({"frame":frame,"sound":"ultimate_hit"})
				last_hit_launch=prior_launches
			prior_hits=h.ultimate.hit_count
		h.get_viewport().get_texture().get_image().save_jpg(DIR+"frame_%05d.jpg" % frame,0.95)
		frame+=1

func scene(h: Node, facing: int) -> void:
	h.ultimate.clear()
	preload("res://combat/enemy_review.gd").remove_enemies(h)
	h.player.position=Vector2(300 if facing==1 else 1000,640)
	h.player.velocity=Vector2.ZERO
	h.player.facing=facing
	h.player.state="idle"
	h.player.elapsed=0
	h.player.focus=100
	h.player.invuln=100
	h.stage.sync(h.player,0.001)
	var beetle: Node=h.spawn("beetle",h.player.position.x+facing*315)
	var mage: Node=h.spawn("shaman",h.player.position.x+facing*630)
	for e in h.enemies: e.cooldown=100
	h.wait_wave=10000
	h.refresh_hud()

func cast(h: Node) -> void:
	audio_events.append({"frame":frame,"sound":"ultimate_charge"})
	h.player.skill()

func run(h: Node) -> void:
	if not h.test_mode or Profile.save_enabled:
		push_error("Ultimate film requires an isolated profile")
		h.get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	Profile.level=3
	h.audio_enabled=false
	h.start_battle()
	h.toast_text=""
	h.toast_time=0
	scene(h,1)
	await record(h,0.7)
	cast(h)
	await record(h,2.0)
	scene(h,-1)
	await record(h,0.7)
	cast(h)
	await record(h,2.0)
	h.reduce_motion=true
	scene(h,1)
	await record(h,0.7)
	cast(h)
	await record(h,1.9)
	var file:=FileAccess.open("res://artifacts/ultimate-demo-metadata.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"frames":frame,"fps":FPS,"duration_seconds":float(frame)/FPS,
		"audio_events":audio_events,"shots":["right cast","left cast","reduced motion cast"],
		"capture":"Actual Godot physics, combat collision, rendering and HUD; isolated profile"},"\t"))
	print("ULTIMATE_FILM ",frame," frames; ",audio_events.size()," sound cues")
	h.get_tree().quit()
