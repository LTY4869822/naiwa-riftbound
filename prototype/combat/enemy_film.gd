extends RefCounted
## Choreographed real-runtime capture, isolated profile, stationary protected player.
const FPS := 30
const DIR := "res://artifacts/enemy-demo-frames/"

static func record(h: Node, data: Dictionary, seconds: float) -> void:
	for i in roundi(seconds*FPS):
		if data.get("pose_roster",false):
			for e in h.enemies: h.stage.sync(e,1.0/FPS)
		h.player.invuln=10
		await RenderingServer.frame_post_draw
		var bitmap: Image=h.get_viewport().get_texture().get_image()
		bitmap.save_jpg(DIR+"frame_%05d.jpg" % data.frame,0.92)
		data.image=bitmap
		data.frame+=1

static func shot(data: Dictionary, name: String) -> void:
	data.image.save_png("res://artifacts/enemy-demo-"+name+".png")

static func scene(h: Node, kind: String, at: float, player_x: float) -> Node:
	preload("res://combat/enemy_review.gd").remove_enemies(h)
	h.player.position=Vector2(player_x,640)
	h.player.velocity=Vector2.ZERO
	h.player.state="idle"
	h.player.invuln=10
	h.stage.sync(h.player,1.0/FPS)
	var e: Node=h.spawn(kind,at)
	e.facing=-1
	e.cooldown=10
	e.begin_attack()
	return e

static func mark(data: Dictionary, name: String) -> void:
	data.events.append({"name":name,"frame":data.frame,"seconds":float(data.frame)/FPS})

static func run(h: Node) -> void:
	if not h.test_mode or Profile.save_enabled:
		push_error("Enemy capture requires --slice-test isolation")
		h.get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	Profile.level=3
	h.audio_enabled=false
	h.reduce_motion=true
	h.start_battle()
	await h.get_tree().physics_frame
	h.player.set_physics_process(false)
	h.player.position=Vector2(330,640)
	h.stage.sync(h.player,1.0/FPS)
	h.wave=2
	h.refresh_hud()
	h.view.visible=true
	var data: Dictionary={"frame":0,"events":[],"image":null,"pose_roster":true}
	for spec in [["beetle",600.0],["shaman",870.0],["raven",1100.0]]:
		var e: Node=h.spawn(spec[0],spec[1])
		e.set_physics_process(false)
	h.toast("森林新敌人 · 荆背甲虫 / 孢灯术士 / 夜羽鸦")
	mark(data,"three-species-roster")
	await record(h,data,1.4)
	shot(data,"roster")
	data.pose_roster=false
	h.toast("荆背甲虫 · 压角蓄力 → 冲撞 → 硬直；重击可以破甲")
	mark(data,"beetle-charge")
	var beetle: Node=scene(h,"beetle",780,470)
	await record(h,data,0.6)
	shot(data,"beetle-warning")
	await record(h,data,0.47)
	shot(data,"beetle-charge")
	await record(h,data,1.13)
	beetle.take_hit(20,1,true)
	await record(h,data,0.27)
	shot(data,"beetle-break")
	h.toast("孢灯术士 · 锁定圆环 → 延迟孢爆；离开圆环即可避开")
	mark(data,"shaman-spore")
	scene(h,"shaman",850,450)
	await record(h,data,0.73)
	shot(data,"shaman-warning")
	await record(h,data,0.94)
	shot(data,"shaman-burst")
	await record(h,data,0.73)
	h.wave=3
	h.refresh_hud()
	h.toast("夜羽鸦 · 升空蓄势 → 俯冲羽刃 → 返回低空，可抓住间隙反击")
	mark(data,"raven-dive")
	scene(h,"raven",820,450)
	await record(h,data,0.6)
	shot(data,"raven-warning")
	await record(h,data,0.4)
	shot(data,"raven-dive")
	await record(h,data,1.4)
	h.toast("四节巡游已接入 · J 连击 / K 重击 / L 闪避 / U 碎片冲击")
	mark(data,"return-to-roster")
	preload("res://combat/enemy_review.gd").remove_enemies(h)
	h.player.position.x=330
	h.stage.sync(h.player,1.0/FPS)
	for spec in [["beetle",600.0],["shaman",870.0],["raven",1100.0]]:
		var e: Node=h.spawn(spec[0],spec[1])
		e.set_physics_process(false)
	data.pose_roster=true
	await record(h,data,1.2)
	var file:=FileAccess.open("res://artifacts/enemy-demo-metadata.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"fps":FPS,"frames":data.frame,"duration_seconds":float(data.frame)/FPS,"events":data.events,"capture":"Real Godot GPU frames; choreographed enemy attacks, stationary invulnerable player, isolated profile."},"\t"))
	h.get_tree().quit()
