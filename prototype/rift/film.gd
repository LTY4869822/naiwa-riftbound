extends RefCounted
const BRAIN=preload("res://loop/boss_brain.gd")
const MYTH=preload("res://ascension/mythic_ai.gd")
var h: Node
var shots: Array[String]=[]
func frames(n: int, shot: String="") -> void:
	for i in n:
		if i==n/2 and not shot.is_empty():
			await h.capture(shot)
			shots.append(shot)
		await h.get_tree().process_frame
func scene(realm: int, kind: String, intro: bool=false, chapter: int=2) -> Node:
	h.rift.presentations_enabled=intro
	h.choose_level(realm,chapter)
	h.wave=h.CAMPAIGN.wave_count(realm,chapter)
	h.wait_wave=9999
	h.arena.enabled=false
	h.player.position=Vector2(240,640)
	var e: Node=h.spawn(kind,960)
	e.cooldown=999
	e.ult_cooldown=999
	return e
func ultimate(e: Node, shot: String) -> void:
	h.projectiles.clear()
	h.boss_fields.clear()
	h.player.position=Vector2(260,640)
	h.player.hp=Profile.max_health()
	h.player.state="idle"
	h.player.velocity=Vector2.ZERO
	e.position=Vector2(960,640)
	e.transition("approach")
	MYTH.begin_ultimate(e)
	for i in 116:
		if i==25: Input.action_press("move_right")
		if i==46: Input.action_release("move_right")
		if i==65:
			await h.capture(shot)
			shots.append(shot)
		await h.get_tree().process_frame
	Input.action_release("move_right")
func run(host: Node) -> void:
	h=host
	Profile.level=7
	h.audio_enabled=true
	h.get_window().size=Vector2i(1280,800)
	var e: Node=scene(2,"yinglong",true)
	await frames(78,"rift-v4-arrival")
	e.hp=roundi(e.maximum*.64)
	e.transition("approach")
	await frames(28,"rift-v4-phase-two")
	BRAIN.begin(e,4)
	for i in 78:
		if i>40 and h.player.is_on_floor(): h.player.jump_buffer=.14
		if i==49: await h.capture("rift-v4-shockwave"); shots.append("rift-v4-shockwave")
		await h.get_tree().process_frame
	e.hp=roundi(e.maximum*.29)
	e.transition("approach")
	await frames(28)
	BRAIN.begin(e,5)
	await frames(88,"rift-v4-hunt")
	await ultimate(e,"rift-v4-dragon")
	for kind in ["zheng","zhuyin","paoxiao"]:
		e=scene(["zheng","zhuyin","yinglong","paoxiao"].find(kind),kind)
		await ultimate(e,"rift-v4-"+kind)
	e=scene(0,"boss",false,0)
	preload("res://remediation/boss_ultimates.gd").begin(e)
	await frames(105,"rift-v4-roots")
	h.choose_level(2,2)
	h.wait_wave=9999
	h.wave=1
	h.player.position=Vector2(240,640)
	await frames(4)
	Ascension.energy=100
	h.ascension.awaken()
	await frames(35)
	h.ascension.finisher()
	await frames(70,"rift-v4-hero")
	h.choose_level(0)
	h.wait_wave=9999
	h.wave=5
	h.player.hp=54
	h.finish(true)
	await frames(65,"rift-v4-relics")
	h.rift.modal.buttons[1].pressed.emit()
	await frames(12)
	var file:=FileAccess.open("res://artifacts/rift-film.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"frames":Engine.get_process_frames(),"fps":30,"shots":shots,"scenario":"Seeded showcase: real boss arrival, phase thresholds set to 64/29 percent to demonstrate unlocks, forced named moves and ultimates, normal damage, no invulnerability override. Fresh player HP per scene, background hazards disabled for clarity. Hero segment seeds 100 energy. Relic segment stages a cleared room and selects a real button. Not a full playthrough."},"\t"))
	file.close()
	print("RIFT_FILM ",Engine.get_process_frames()," frames")
	h.get_tree().quit()
