extends RefCounted
const LEVELS=preload("res://campaign/levels.gd")
const MYTHIC=preload("res://ascension/mythic_ai.gd")
var checks:=0
var failures: Array=[]
var h: Node

func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures.append(message)
		push_error("ASCENSION: "+message)

func frames(count: int) -> void:
	for i in count: await h.get_tree().process_frame

func settle(seconds: float) -> void:
	await h.get_tree().create_timer(seconds).timeout

func quiet() -> void:
	h.wait_wave=999
	h.wave=1
	h.projectiles.clear()
	h.boss_fields.clear()
	for e in h.enemies:
		if is_instance_valid(e):
			h.stage.remove_actor(e)
			e.queue_free()
	h.enemies.clear()

func run(host: Node) -> void:
	h=host
	var ids: Array=[]
	for map in 4:
		var prior_hp:=0.0
		var prior_damage:=0.0
		for chapter in 3:
			var d:=LEVELS.get_stage(map,chapter)
			check(not d.id in ids,"unique stage "+d.id)
			ids.append(d.id)
			check(d.waves[-1][0][0]==d.boss,"guardian in every stage "+d.id)
			check(d.health_scale>prior_hp and d.damage_scale>prior_damage,"progressive stats "+d.id)
			prior_hp=d.health_scale
			prior_damage=d.damage_scale
			check(preload("res://wardrobe/catalog.gd").REWARDS.has(d.id),"reward ledger "+d.id)
			if chapter==2:
				check(d.boss==LEVELS.MYTHICS[map],"mythic guardian "+d.id)
				check(d.waves[0].size()+d.waves[1].size()>=6,"enough kills to awaken "+d.id)
	check(ids.size()==12,"twelve stages")
	check(ids[0]=="moss" and ids[3]=="cavern" and ids[6]=="storm" and ids[9]=="forge","legacy clear ids preserved")
	check(Preferences.keys.has("awaken") and InputMap.has_action("awaken"),"awakening action installed")
	Profile.level=5
	h.choose_level(0,2)
	await frames(4)
	quiet()
	Ascension.reset()
	for i in 6:
		var e: Node=h.spawn("melee",850)
		e.take_hit(10000,1,true)
		check(not Ascension.record_kill(h.run_reward_id,e.eid,false),"duplicate kill rejected "+str(i))
	check(Ascension.energy==100 and Ascension.total_kills==6,"real enemy deaths fill meter, cap 100")
	h.player.hp=30
	check(h.ascension.awaken(),"ready grounded hero awakens")
	check(Ascension.energy==0,"energy consumed once")
	check(not h.ascension.awaken(),"cannot re-enter intro")
	var old_age: float=h.ascension.age
	h.paused=true
	await frames(4)
	check(h.ascension.age==old_age,"pause freezes transformation")
	h.paused=false
	await settle(0.30)
	await h.capture("ascension-morph-1.png")
	await settle(0.55)
	await h.capture("ascension-morph-2.png")
	await settle(0.55)
	await h.capture("ascension-morph-3.png")
	await settle(0.55)
	check(h.ascension.empowered(),"intro joins empowered state")
	check(h.player.hp>30 and h.player.stamina==100,"awakening restores health and stamina")
	var rig: Node=h.stage.actors[h.player.get_instance_id()]
	check(rig.ascended.max_ground_error<0.001,"measured foot pivot continuous")
	check(absf(absf(rig.ascended.first.scale.x)-rig.ascended.first.scale.y)<0.001,"uniform full-body scale")
	await h.capture("ascension-empowered.png")
	var front: Node=h.spawn("zheng",860)
	front.set_physics_process(false)
	front.hp=6000
	front.maximum=6000
	var behind: Node=h.spawn("beetle",90)
	behind.set_physics_process(false)
	var back_hp: int=behind.hp
	h.player.facing=1
	check(h.ascension.finisher(),"empowered U starts exclusive finisher")
	check(not h.ascension.finisher(),"finisher cannot double fire")
	await settle(0.85)
	await h.capture("ascension-rift.png")
	await settle(0.75)
	await h.capture("ascension-finisher.png")
	await settle(1.9)
	check(h.ascension.phase=="dormant","finisher naturally returns to base")
	check(front.hp==6000-roundi(Profile.damage()*4)-roundi(Profile.damage()*7)-roundi(Profile.damage()*21),"three real damage contacts")
	check(behind.hp==back_hp,"front-only finisher does not hit behind")
	check(h.ascension.pulses==3 and h.ascension.hits.size()==3,"once per target per pulse")
	check(h.player.state=="idle","input unlocked after reversion")
	quiet()
	Ascension.energy=100
	h.player.position=Vector2(300,440)
	h.player.velocity=Vector2.ZERO
	await frames(3)
	check(not h.ascension.awaken() and Ascension.energy==100,"airborne awakening cannot spend meter")
	h.player.position=Vector2(300,640)
	await frames(3)
	check(h.ascension.awaken(),"grounded hero can awaken again after refilling")
	h.ascension.advance(h.ascension.INTRO+0.01)
	h.ascension.remaining=10.0
	h.choose_level(1,2)
	check(h.ascension.empowered() and h.ascension.remaining==10.0,"remaining empowered time carries into next stage")
	quiet()
	h.camp()
	var saved_remaining: float=h.ascension.remaining
	await frames(3)
	check(h.ascension.remaining==saved_remaining,"camp freezes empowered duration")
	h.enter_battle()
	h.ascension.remaining=0.001
	h.player.state="idle"
	h.ascension.advance(0.02)
	check(h.ascension.phase=="dissolve","natural timeout starts a smooth exit")
	h.ascension.advance(h.ascension.OUTRO+0.01)
	check(h.ascension.phase=="dormant" and h.player.state=="idle","timeout returns control without needing U")
	for map in 4:
		h.choose_level(map,2)
		await frames(3)
		quiet()
		h.player.position=Vector2(300,640)
		h.player.invuln=100
		var e: Node=h.spawn(LEVELS.MYTHICS[map],1000)
		e.set_physics_process(false)
		e.facing=-1
		check(e.boss and e.maximum>1000,"mythic combat data "+e.kind)
		var boss_rig: Node=h.stage.actors[e.get_instance_id()]
		check(boss_rig.frames.size()==8,"animated mythic poses "+e.kind)
		check(MYTHIC.begin_ultimate(e),"mythic ultimate can aim at player "+e.kind)
		for f in h.boss_fields.fields:
			check(not h.boss_fields.area(f).intersects(e.hurtbox()),"no self-target "+e.kind)
		check(h.boss_fields.fields.size()>=3,"multi-beat ultimate "+e.kind)
		e.timer=1.0
		h.stage.sync(e,0.01)
		await frames(3)
		await h.capture("ascension-boss-%d-tell.png" % map)
		e.transition("ult_active")
		h.stage.sync(e,0.01)
		await settle(1.65)
		await h.capture("ascension-boss-%d-strike.png" % map)
		h.boss_fields.cancel(e.eid)
		check(h.boss_fields.fields.is_empty(),"owner cancellation "+e.kind)
	quiet()
	h.camp()
	h.open_route()
	await settle(0.7)
	var route: Node=h.hud.find_child("LevelRoute",true,false)
	check(is_instance_valid(route),"route visible")
	for card in route.cards: check(card.stage_buttons.size()==3,"three native stage buttons")
	await h.capture("ascension-twelve-stages.png")
	route.activate_level(2,1)
	await settle(0.9)
	check(h.level_index==2 and h.stage_index==1,"stage button launches selected chapter")
	h.finish(true)
	var wallet: int=Wardrobe.coins
	h.finish(true)
	check(Wardrobe.coins==wallet,"clear reward idempotent")
	h.next_level()
	check(h.level_index==2 and h.stage_index==2,"next stage within same map")
	h.finish(true)
	h.next_level()
	check(h.level_index==3 and h.stage_index==0,"next map after third stage")
	h.ascension.clear()
	var result:={"checks":checks,"failures":failures,"stages":ids,"profile_isolated":not Profile.save_enabled,"wallet_isolated":not Wardrobe.save_enabled,"energy_isolated":not Ascension.save_enabled}
	var f:=FileAccess.open("res://artifacts/ascension-checks.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(result,"\t"))
	f.close()
	print("ASCENSION_CHECKS ",checks," failures=",failures.size())
	h.get_tree().quit(0 if failures.is_empty() else 1)
