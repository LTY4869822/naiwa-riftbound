extends RefCounted
const BRAIN=preload("res://loop/boss_brain.gd")
var h: Node
var number:=0
var shots: Array=[]
func frame(shot: String="") -> void:
	await RenderingServer.frame_post_draw
	var im: Image=h.get_viewport().get_texture().get_image()
	im.save_jpg("res://artifacts/loop-frames/frame_%05d.jpg" % number,.90)
	number+=1
	if not shot.is_empty():
		im.save_png("res://artifacts/loop-"+shot+".png")
		shots.append(shot)
	await h.get_tree().process_frame
func blank(realm: int, chapter: int=0) -> void:
	h.choose_level(realm,chapter)
	h.wait_wave=999
	h.wave=1
func run(host: Node) -> void:
	h=host
	h.audio_enabled=false
	h.get_window().size=Vector2i(1280,800)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/loop-frames"))
	Profile.level=3
	h.open_route()
	for i in 30: await frame("connected-route" if i==25 else "")
	blank(0)
	h.player.position=Vector2(260,640)
	var enemy: Node=h.spawn("melee",370)
	for i in 70:
		if i==8: h.player.attack(0)
		if i==25: h.player.attack(1)
		if i==44: h.player.attack(2)
		if i>=30: Input.action_press("move_right")
		await frame("coin-drop" if i==40 else "coin-pickup" if i==62 else "")
	Input.action_release("move_right")
	h.player.hp=48
	h.wave=h.CAMPAIGN.wave_count(0,0)
	h.training.beat()
	h.finish(true)
	var saved_hp: int=h.player.hp
	var healed_shot:=false
	var passage_shot:=false
	var next_shot:=false
	for i in 160:
		if not h.journey.travelling: Input.action_press("move_right")
		var shot: String="heal-drop" if i==0 else ""
		if h.player.hp>saved_hp and not healed_shot:
			healed_shot=true
			shot="heal-collected"
		if h.player.position.x>1100 and not passage_shot:
			passage_shot=true
			shot="passage"
		if h.stage_index==1 and not h.journey.travelling and not next_shot:
			next_shot=true
			shot="next-room"
		await frame(shot)
		if h.stage_index==1 and not h.journey.travelling and i>110: break
	Input.action_release("move_right")
	blank(2,2)
	h.player.position=Vector2(300,640)
	for i in 3: await frame()
	Ascension.energy=100
	h.ascension.awaken()
	for i in 38: await frame("morph-eight" if i==20 else "")
	for i in 50:
		Input.action_release("move_right")
		Input.action_release("move_left")
		Input.action_press("move_right" if i<25 else "move_left")
		await frame("eight-frame-run" if i==13 else "fast-turn" if i==29 else "")
	Input.action_release("move_left")
	h.player.facing=1
	for attack in 3:
		h.player.attack(attack)
		for i in 22: await frame("combo-%d" % attack if i==9 else "")
	var boss: Node=h.spawn("yinglong",930)
	boss.set_physics_process(false)
	h.player.facing=1
	h.player.skill()
	for i in 82: await frame("balanced-finisher" if i==38 else "boss-survives" if i==72 else "")
	for kind in ["zheng","zhuyin","yinglong","paoxiao"]:
		blank(["zheng","zhuyin","yinglong","paoxiao"].find(kind),2)
		h.player.position=Vector2(300,640)
		var e: Node=h.spawn(kind,1000)
		e.cooldown=999
		e.ult_cooldown=999
		BRAIN.begin(e,2 if kind in ["zhuyin","yinglong"] else 1)
		for i in 75:
			if i==35 and kind in ["zhuyin","yinglong"]: h.player.jump_buffer=.14
			await frame(kind+"-regular" if i==49 else "")
		h.projectiles.clear()
		h.boss_fields.clear()
		e.position=Vector2(1000,640)
		h.player.position=Vector2(260,640)
		h.player.velocity=Vector2.ZERO
		e.transition("approach")
		preload("res://ascension/mythic_ai.gd").begin_ultimate(e)
		for i in 105:
			Input.action_release("move_right")
			if i>=35 and i<66:
				Input.action_press("move_right")
				if i==40: h.player.facing=1; h.player.dash()
			await frame(kind+"-ultimate" if i==59 else "")
		Input.action_release("move_right")
	h.open_gear()
	for i in 30: await frame("equipment" if i==23 else "")
	var f:=FileAccess.open("res://artifacts/loop-film.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"frames":number,"fps":30,"seconds":number/30.0,"shots":shots,"real_gpu":true,"scenario":"Seeded visual demonstration. A normal tutorial enemy drops pickup gold; a staged room clear and injured hero demonstrate partial healing and the actual passage. Animation segment preloads 100 energy; its healthy boss survives the real finisher. Boss moves/ultimates use their real AI and hitboxes. Not a complete playthrough."},"\t"))
	f.close()
	print("LOOP_FILM ",number," frames")
	h.get_tree().quit()
