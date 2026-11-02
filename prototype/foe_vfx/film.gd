extends RefCounted
## Real GPU capture of the actual attack transitions and actual damage to a fixed hero.
const CASES = preload("res://foe_vfx/cases.gd")
const FPS:=30
const DIR:="res://artifacts/foe-vfx-demo-frames/"

static func record(h: Node, data: Dictionary, seconds: float) -> void:
	for i in roundi(seconds*FPS):
		# Locomotion is held for clear framing; hit state and protection run normally.
		h.player.invuln=maxf(0,h.player.invuln-1.0/FPS)
		h.player.flash=maxf(0,h.player.flash-7.0/FPS)
		h.player.elapsed+=1.0/FPS
		if h.player.state=="hurt" and h.player.elapsed>0.32: h.player.state="idle"
		h.player.changed.emit()
		h.stage.sync(h.player,1.0/FPS)
		h.trauma=0
		await RenderingServer.frame_post_draw
		var bitmap: Image=h.get_viewport().get_texture().get_image()
		bitmap.save_jpg(data.directory+"frame_%05d.jpg" % data.frame,0.91)
		data.image=bitmap
		data.frame+=1
		if not data.get("peak_taken",false) and h.enemy_fx.events.any(func(event): return event.mode=="field" and event.age>=0.22 and event.age<0.30):
			shot(data,data.case_label+"-field-peak")
			data.peak_taken=true

static func shot(data: Dictionary, name: String) -> void:
	data.image.save_png("res://artifacts/"+data.tag+"-demo-"+name+".png")

static func run(h: Node) -> void:
	if not h.test_mode or Profile.save_enabled:
		h.get_tree().quit(1)
		return
	var tag: String="toon-vfx" if "--toon-film" in OS.get_cmdline_user_args() else "foe-vfx"
	var directory: String="res://artifacts/"+tag+"-demo-frames/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	h.audio_enabled=false
	h.reduce_motion=false
	var data: Dictionary={"frame":0,"image":null,"events":[],"tag":tag,"directory":directory}
	for spec in CASES.ITEMS:
		Profile.level=3
		Profile.xp=0
		h.choose_level(spec.map)
		h.player.set_physics_process(false)
		h.player.position=Vector2(450,640)
		h.player.invuln=0
		h.wave=h.CAMPAIGN.wave_count(h.level_index)
		var e: Node=h.spawn(spec.kind,spec.x)
		e.set_physics_process(false)
		e.facing=-1
		e.cooldown=30
		e.action_count=1 if spec.move==0 else 0
		h.stage.sync(e,1.0/FPS)
		h.refresh_hud()
		h.toast(spec.name+"    蓄力 → 出招 → 命中 / 消散")
		var label: String=spec.kind+"-%d" % spec.move
		data.case_label=label
		data.peak_taken=false
		data.events.append({"kind":spec.kind,"move":spec.move,"name":spec.name,"frame":data.frame,"seconds":float(data.frame)/FPS})
		await record(h,data,0.20)
		e.begin_attack()
		e.set_physics_process(true)
		await record(h,data,maxf(0.2,e.windup_duration()-0.1))
		shot(data,label+"-charge")
		await record(h,data,0.16)
		shot(data,label+"-strike")
		await record(h,data,0.10)
		shot(data,label+"-sweep")
		await record(h,data,0.20)
		if spec.kind=="beetle" or spec.kind=="raven" or (spec.kind in ["boss","tempest_boss"] and spec.move==1): shot(data,label+"-rush")
		await record(h,data,0.44)
		shot(data,label+"-burst")
		await record(h,data,0.22)
		shot(data,label+"-impact")
		await record(h,data,0.34)
	var file:=FileAccess.open("res://artifacts/"+tag+"-demo-metadata.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"fps":FPS,"frames":data.frame,"duration_seconds":float(data.frame)/FPS,"attacks":data.events,"capture":"Real Godot GPU frames; actual enemy AI attacks, real damage and protection windows. Hero locomotion and camera shake held for framing. Isolated profile; not an autoplay victory recording."},"\t"))
	h.get_tree().quit()
