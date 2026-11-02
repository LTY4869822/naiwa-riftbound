extends RefCounted
const QUIET=preload("res://echo/demo.gd")
var h: Node
var checks:=0
var failures: Array[String]=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); push_error(label)
func frames(n: int) -> void:
	for i in n: await h.get_tree().physics_frame
func wait(t: float) -> void: await h.get_tree().create_timer(t).timeout
func action(name: String,pressed: bool=true) -> void:
	var e:=InputEventAction.new(); e.action=name; e.pressed=pressed; Input.parse_input_event(e)
func target(kind: String,x: float) -> Node:
	var e: Node=h.spawn(kind,x)
	h.rift.finish_arrival()
	e.hp=50000; e.maximum=50000; e.velocity=Vector2(0,20); e.move_and_slide()
	e.set_physics_process(false); e.state="approach"; e.facing=-1
	return e
func ready_player(x: float=430,facing: int=1) -> void:
	h.punch.clear(); h.hitstop=0; h.trauma=0
	h.player.position=Vector2(x,640); h.player.velocity=Vector2.ZERO
	h.player.state="idle"; h.player.elapsed=0; h.player.buffered=0; h.player.stamina=100
	h.player.facing=facing; h.player.hit_ids.clear()
func until_contact(before: int) -> bool:
	for i in 45:
		await frames(1)
		if h.punch.confirmed>before: return true
	return false
func run(host: Node) -> void:
	h=host; h.audio_enabled=false
	h.get_window().size=Vector2i(1280,800)
	Profile.level=7; h.rift.presentations_enabled=false
	QUIET.jump(h); h.arena.enabled=false; h.toast_time=0
	await frames(4)
	check(h.punch.atlas.size()==7,"seven palette-tuned color/light animation pairs loaded")
	for key in h.punch.data:
		check(h.punch.atlas[key].color.size()==h.punch.atlas[key].light.size(),key+" buffers share frame count")
	check(h.punch.glow.material.blend_mode==CanvasItemMaterial.BLEND_MODE_ADD,"light uses separate additive canvas")
	check(h.punch.ground.z_index<3,"floor dust draws behind character rigs")
	check(h.punch.front.mouse_filter if h.punch.front is Control else true,"VFX has no input-blocking control")
	var start: int=h.punch.confirmed
	action("attack"); await frames(1); action("attack",false); await wait(.5)
	check(h.punch.confirmed==start and h.punch.bursts.is_empty(),"real attack input into empty space has no false hit feedback")
	var e: Node=target("melee",570)
	ready_player(); await frames(3)
	var hp: int=e.hp
	action("attack"); await frames(1); action("attack",false)
	check(await until_contact(start),"real light attack input reaches the enemy")
	check(e.hp<hp and h.punch.confirmed==start+1,"accepted hit produces exactly one contact")
	check(h.punch.bursts[-1].key=="hit-gold","first punch uses gold directional spark")
	var duplicate:=false
	for event in h.enemy_fx.events: duplicate=duplicate or event.mode=="interrupt"
	check(not duplicate,"legacy body-center interrupt does not duplicate the real contact point")
	check(h.hitstop>0 and h.hitstop<=.026,"light contact uses bounded 26 ms stop")
	var light_stop: float=h.hitstop
	check(e.flash>0,"real target hit drives silhouette flash")
	var rig: Node=h.stage.actors[e.get_instance_id()]
	check(rig.sprite.material!=null and rig.sprite.material.get_meta("contact_flash",false),"target uses flash shader without stretching its sprite")
	await h.capture("punch-light-contact")
	action("attack"); await frames(1); action("attack",false)
	check(h.player.combo_queued or h.player.buffered>0,"attack input during impact still buffers the next action")
	await wait(.60)
	check(h.punch.confirmed>=start+2,"buffered combo resolves a second real contact")
	# Release the staged target to its real physics so its hit flash can decay naturally.
	e.cooldown=10; e.state="stunned"; e.timer=0; e.set_physics_process(true)
	await wait(.35)
	e.set_physics_process(false)
	check(h.hitstop==0 and h.trauma==0,"hit-stop and camera trauma return to rest")
	check(rig.sprite.material==null or float(rig.sprite.material.get_shader_parameter("amount"))<.01,"flash returns to normal")
	ready_player(); e.position=Vector2(565,640); e.state="approach"
	start=h.punch.confirmed; hp=e.hp
	action("heavy"); await frames(1); action("heavy",false)
	check(await until_contact(start),"real heavy input connects")
	check(h.punch.bursts[-1].key=="heavy","heavy contact has its own broken-ring effect")
	check(h.hitstop>light_stop and h.hitstop<=.058,"heavy contact is heavier but remains under 60 ms")
	check(e.hp<hp and h.punch.floors.size()==1,"grounded heavy contact emits one floor eruption")
	await h.capture("punch-heavy-contact")
	await wait(.15); await h.capture("punch-heavy-followthrough")
	await wait(.65)
	ready_player(790,-1); e.position=Vector2(655,640); e.state="approach"
	start=h.punch.confirmed
	action("heavy"); await frames(1); action("heavy",false)
	check(await until_contact(start),"left-facing heavy contact connects")
	check(h.punch.bursts[-1].facing==-1,"left-facing spark and ring mirror along the strike")
	check(h.punch.bursts[-1].pos.x<790,"left impact anchor remains on the target")
	await h.capture("punch-left-contact")
	await wait(.6)
	QUIET.quiet(h); ready_player()
	e=target("beetle",565); start=h.punch.confirmed
	action("heavy"); await frames(1); action("heavy",false)
	check(await until_contact(start),"armored enemy accepts the actual heavy hit")
	check(h.punch.bursts[-1].key=="break","armor break uses distinct mint clash")
	await h.capture("punch-break-contact")
	await wait(.6)
	QUIET.quiet(h); ready_player()
	h.boss_fields.cast(999,Vector2(1050,640),"roots",.40,10,60)
	h.boss_fields.advance(.39)
	check(h.punch.floors.is_empty(),"boss terrain burst waits for its complete warning")
	h.boss_fields.advance(.02)
	check(h.punch.floors.size()==1 and h.punch.bursts.is_empty(),"boss terrain contact makes floor debris without a fake player hit")
	check(h.hitstop==0,"boss terrain whiff does not freeze player movement")
	h.boss_fields.clear(); h.punch.clear()
	e=target("zheng",720); e.state="rift_arrive"
	h.ultimate.launch(Vector2(680,515),1,430)
	h.ultimate.advance(.03)
	check(h.punch.bursts.is_empty(),"invulnerable boss arrival does not emit a fake ultimate hit")
	h.ultimate.clear(); e.state="approach"; start=h.punch.confirmed
	h.ultimate.launch(Vector2(680,515),1,430); h.ultimate.advance(.03)
	check(h.punch.confirmed==start+1 and h.punch.bursts[-1].key=="ultimate","confirmed ultimate contact uses violet effect")
	await h.capture("punch-ultimate-contact")
	h.ultimate.clear(); await wait(.4)
	QUIET.quiet(h); ready_player()
	e=target("zheng",700)
	var rear: Node=target("beetle",100)
	var rear_hp: int=rear.hp
	hp=e.hp; start=h.punch.confirmed
	h.ascension.origin=h.player.position; h.ascension.side=1; h.ascension.hits.clear()
	h.ascension.strike(0); h.ascension.strike(0)
	check(h.punch.confirmed==start+1,"awakening finisher repeats cannot double-fire the first contact")
	h.ascension.strike(1); h.ascension.strike(2)
	check(h.punch.confirmed==start+3 and h.punch.bursts.size()==3,"three confirmed finisher contacts each emit one violet burst")
	check(hp-e.hp==roundi(Profile.damage()*1.6)+roundi(Profile.damage()*2.4)+roundi(Profile.damage()*4.0),"finisher damage retains current 1.6 / 2.4 / 4.0 balance")
	check(rear.hp==rear_hp,"finisher feedback does not invent rear damage")
	QUIET.quiet(h); ready_player()
	h.ascension.hits.clear(); start=h.punch.confirmed
	h.ascension.strike(2)
	check(h.punch.confirmed==start and h.hitstop==0 and h.punch.bursts.is_empty(),"empty finisher has no fake target hit or global freeze")
	ready_player(); h.player.invuln=0; hp=h.player.hp; start=h.punch.confirmed
	check(h.player.take_hit(10,1),"player accepts an actual enemy hit")
	check(h.player.hp==hp-10 and h.punch.confirmed==start+1 and h.punch.bursts[-1].key=="hurt","damage uses coral hurt feedback")
	check(not h.player.take_hit(10,1) and h.punch.confirmed==start+1,"invulnerable repeated hit cannot repeat feedback")
	await h.capture("punch-hurt-contact")
	await wait(.4)
	ready_player(); h.rift.evade_cd=0
	var perfect: int=h.rift.perfect_count
	h.rift.perfect_evade()
	check(h.rift.perfect_count==perfect+1 and h.punch.bursts[-1].key=="break","precision dodge has distinct mint timing reward")
	var pulse_count: int=h.punch.pulses
	h.punch.clear()
	for i in 12: h.impact(Vector2(600+i,500),1,true)
	check(h.punch.pulses==pulse_count+1 and h.hitstop<=.058 and h.trauma<=.57,"crowd contacts share one pulse without multiplying stop or shake")
	for i in 90: h.punch.spawn("heavy",Vector2(600,500))
	for i in 20: h.punch.ground_cooldown=0; h.punch.floor_hit(Vector2(600,640),1)
	check(h.punch.bursts.size()==24 and h.punch.floors.size()==3,"particle bursts and floor effects remain bounded under stress")
	h.punch.clear(); h.hitstop=0
	h.impact(Vector2(600,500),1,true)
	h.paused=true; var age: float=h.punch.bursts[0].age
	await wait(.15)
	check(h.punch.bursts[0].age==age,"pause freezes feedback lifetime")
	h.paused=false; h.reduce_motion=true
	check(h.punch.camera_offset()==Vector2.ZERO,"reduce-motion removes all camera recoil and shake")
	await h.capture("punch-reduced-motion")
	h.reduce_motion=false; await wait(2.5)
	check(h.punch.bursts.is_empty() and h.punch.floors.is_empty(),"one-shots expire without lingering sprites")
	h.audio_enabled=true
	check(h.punch.sound.trigger("heavy"),"dedicated impact voice plays")
	check(h.punch.sound.voices.size()==6 and h.punch.sound.clips.heavy.size()==3,"six bounded audio voices and three alternate takes")
	h.audio_enabled=false; await frames(2)
	var silent:=true
	for voice in h.punch.sound.voices: silent=silent and not voice.playing
	check(silent,"sound toggle immediately silences playing impact voices")
	h.punch.spawn("heavy",Vector2(500,500)); h.continue_room()
	check(h.punch.bursts.is_empty(),"connected room transition clears obsolete contact effects")
	check(not Profile.save_enabled and not Wardrobe.save_enabled and not Ascension.save_enabled,"all checks use isolated progression")
	FileAccess.open("res://artifacts/punch-checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"input":"Actual Input.parse_input_event for whiff, light combo, heavy, and left-facing heavy; staged targets. Other edge cases call combat hooks."},"\t"))
	print("PUNCH_CHECKS ",checks," failures=",failures.size())
	h.get_tree().quit(0 if failures.is_empty() else 1)
