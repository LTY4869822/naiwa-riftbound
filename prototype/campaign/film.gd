extends RefCounted
const LEVELS = preload("res://campaign/levels.gd")
const FPS:=30
const DIR:="res://artifacts/campaign-demo-frames/"

static func record(h: Node, data: Dictionary, seconds: float) -> void:
	for i in roundi(seconds*FPS):
		if is_instance_valid(h.player):
			h.player.invuln=10
			h.stage.sync(h.player,1.0/FPS)
		for e in h.enemies:
			if is_instance_valid(e) and not e.is_physics_processing(): h.stage.sync(e,1.0/FPS)
		await RenderingServer.frame_post_draw
		var bitmap: Image=h.get_viewport().get_texture().get_image()
		bitmap.save_jpg(DIR+"frame_%05d.jpg" % data.frame,0.91)
		data.image=bitmap
		data.frame+=1

static func shot(data: Dictionary, name: String) -> void:
	data.image.save_png("res://artifacts/campaign-demo-"+name+".png")

static func run(h: Node) -> void:
	if not h.test_mode or Profile.save_enabled:
		h.get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	h.audio_enabled=false
	h.reduce_motion=true
	Profile.level=3
	var data: Dictionary={"frame":0,"image":null,"events":[]}
	h.open_route()
	await record(h,data,1.0)
	shot(data,"route")
	for i in 4:
		h.choose_level(i)
		h.player.set_physics_process(false)
		h.player.position=Vector2(450,640)
		h.player.invuln=10
		h.wave=LEVELS.wave_count(i)
		var guardian: Node=h.spawn(LEVELS.get_level(i).boss,900)
		guardian.set_physics_process(false)
		guardian.facing=-1
		h.refresh_hud()
		h.toast("第 %d 关 · %s    守关Boss：%s" % [i+1,h.current_level().title,h.current_level().boss_name])
		data.events.append({"level":i+1,"frame":data.frame,"seconds":float(data.frame)/FPS})
		await record(h,data,0.5)
		shot(data,"level-%d" % (i+1))
		guardian.action_count=1
		guardian.begin_attack()
		guardian.set_physics_process(true)
		await record(h,data,1.3)
		shot(data,"warning-%d" % (i+1))
		await record(h,data,0.85)
		shot(data,"attack-%d" % (i+1))
		await record(h,data,0.9)
		guardian.take_hit(guardian.maximum/2+1 if i>0 else 1,1,true)
		await record(h,data,0.35)
		shot(data,"phase-%d" % (i+1))
	var file:=FileAccess.open("res://artifacts/campaign-demo-metadata.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"fps":FPS,"frames":data.frame,"duration_seconds":float(data.frame)/FPS,"events":data.events,"capture":"Real Godot GPU; choreographed boss casts and phase changes, stationary protected hero; isolated profile. Not an autoplay victory recording."},"\t"))
	h.get_tree().quit()
