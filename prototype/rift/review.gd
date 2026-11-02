extends RefCounted
const BRAIN=preload("res://loop/boss_brain.gd")
const TACTICS=preload("res://rift/tactics.gd")
var h: Node
var checks:=0
var failures: Array[String]=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); push_error(label)
func wait(t: float) -> void: await h.get_tree().create_timer(t).timeout
func quiet() -> void:
	h.rift.finish_arrival()
	h.wait_wave=9999
	h.projectiles.clear()
	h.boss_fields.clear()
	for e in h.enemies:
		if is_instance_valid(e): h.stage.remove_actor(e); e.queue_free()
	h.enemies.clear()
func run(host: Node) -> void:
	h=host
	h.audio_enabled=false
	Profile.level=7
	h.choose_level(0)
	h.wait_wave=9999
	h.wave=1
	var e: Node=h.spawn("boss",940)
	check(e.maximum>=980,"level-seven guardian has thicker real health")
	check(e.state=="rift_arrive" and not h.playing(),"real boss spawn starts gated arrival")
	var hp: int=e.hp
	e.take_hit(100,1,true)
	check(e.hp==hp,"arrival cannot be damaged before combat starts")
	await wait(1.15)
	await h.capture("rift-arrival")
	check(e.combat_age==0 and h.player.hp==Profile.max_health(),"arrival freezes combat, not only the image")
	var age: float=h.rift.entrance.age
	h.paused=true
	await wait(.15)
	check(is_equal_approx(h.rift.entrance.age,age),"pause freezes cinematic progression")
	h.paused=false
	check(h.rift.skip() and h.playing(),"skip path restores combat")
	var rig: Node=h.stage.actors[e.get_instance_id()]
	check(rig.sprite.material==null and e.position==Vector2(940,640),"arrival leaves no material or position offset")
	e.set_physics_process(false)
	e.hp=roundi(e.maximum*.64)
	e.transition("approach")
	BRAIN.step(e,.016)
	check(e.combat_phase==2 and e.state=="phase_shift","65 percent health unlocks phase two")
	hp=e.hp
	e.take_hit(100,1,true)
	check(e.hp==hp,"phase transition cannot be burst-skipped")
	e.timer=.81
	BRAIN.step(e,0)
	e.hp=roundi(e.maximum*.29)
	e.transition("approach")
	BRAIN.step(e,.016)
	check(e.combat_phase==3 and e.state=="phase_shift","30 percent health unlocks phase three without healing")
	e.timer=.81
	BRAIN.step(e,0)
	check(e.state=="approach" and e.cooldown<=.25,"phase transition returns to live combat")
	e.move_cooldowns.clear()
	e.move_history.clear()
	e.senses={"air":false,"attacking":false,"vx":0}
	e.position=Vector2(900,640)
	h.player.position=Vector2(200,640)
	var far:=TACTICS.choose(e)
	h.player.position.x=790
	var near:=TACTICS.choose(e)
	check(far in [1,2,4] and near==0 and far!=near,"spacing switches close melee to a distant rush, projectile or wave")
	e.sense_clock=0
	h.player.velocity.x=220
	TACTICS.observe(e,.01)
	h.player.velocity.x=-220
	TACTICS.observe(e,.01)
	check(e.senses.vx==220,"motion observations have a deliberate sample interval")
	for move in 6:
		h.player.position=Vector2(300,640)
		e.position=Vector2(960,640)
		BRAIN.begin(e,move)
		check(e.windup_duration()>=.55 and not e.attack_data.name.is_empty(),"readable six-move warning "+str(move))
		e.transition("active")
		BRAIN.release(e)
		if move==4:
			check(h.projectiles.filter(func(p): return p.get("ground_wave",false)).size()==2,"ground wave launches two real projectiles")
			var wave: Dictionary=h.projectiles[-1]
			h.player.position=wave.pos+Vector2(0,28)
			check(h.projectile_hits(wave,wave.pos-Vector2(10,0)),"wave threatens grounded player")
			h.player.position.y-=140
			check(not h.projectile_hits(wave,wave.pos-Vector2(10,0)),"jump clears actual wave hitbox")
		if move==5: check(e.position.x<500 and h.boss_fields.fields.size()>0,"rift hunt changes flank and warns attack")
		h.projectiles.clear()
		h.boss_fields.clear()
	quiet()
	h.choose_level(0)
	h.wait_wave=9999
	h.wave=1
	h.player.hp=54
	h.finish(true)
	check(h.rift.offer_active and not h.playing(),"victory opens a three-choice relic pause")
	await wait(.10)
	await h.capture("rift-relics")
	check(h.rift.modal.buttons.size()==3,"three focusable relic actions are visible")
	var actor: int=h.player.get_instance_id()
	h.camp()
	h.enter_battle()
	await wait(.10)
	check(h.rift.offer_active and h.rift.modal.is_inside_tree(),"camp and return restore pending relic choice")
	h.rift.modal.buttons[0].pressed.emit()
	check(h.rift.rank("edge")==1 and not h.rift.offer_active and h.playing(),"real button equips one relic and resumes")
	check(not h.rift.pick("wind") and h.rift.rank("wind")==0,"second callback cannot claim another relic")
	check(is_equal_approx(h.rift.attack_boost(),1.12),"attack relic changes real damage multiplier")
	h.continue_room()
	check(h.player.get_instance_id()==actor and h.rift.rank("edge")==1,"relic follows same actor into next room")
	h.rift.offers.assign(["spring","wind","echo"])
	h.rift.offer_active=true
	h.rift.pick("spring")
	check(is_equal_approx(h.rift.heal_fraction(),.65),"healing relic changes missing-health recovery")
	h.player.hp=54
	h.journey.collect({"type":"heal","id":99,"pos":h.player.position})
	check(h.player.hp==54+roundi((Profile.max_health()-54)*.65),"pickup actually applies relic healing")
	h.rift.ranks["wind"]=1
	check(is_equal_approx(h.player.dash_cost(),28) and is_equal_approx(h.player.dash_limit(),.47),"wind relic changes real dash cost and cooldown")
	h.player.stamina=28
	h.player.dash_cd=0
	h.player.state="idle"
	h.refresh_hud()
	check(h.battle_hud.dash_ready,"HUD uses the relic-adjusted stamina threshold")
	h.rift.ranks.clear()
	h.player.state="dash"
	h.player.elapsed=.06
	h.player.invuln=.16
	h.player.focus=0
	Ascension.energy=0
	hp=h.player.hp
	h.player.take_hit(25,1)
	check(h.player.hp==hp and h.rift.perfect_count==1 and h.player.focus==12 and Ascension.energy==2,"contact-confirmed precision dodge grants real counter reward")
	h.player.take_hit(25,1)
	check(h.rift.perfect_count==1 and Ascension.energy==2,"one dodge cannot farm repeat contact rewards")
	check(h.rift.attack_boost()>1.3,"precision dodge enables brief real damage boost")
	await wait(1.30)
	check(h.rift.riposte==0,"counter reward expires")
	h.choose_level(1)
	check(h.rift.ranks.is_empty() and not h.rift.offer_active,"new map resets run relics and pending UI")
	check(not Profile.save_enabled and not Wardrobe.save_enabled and not Ascension.save_enabled,"review cannot touch formal records")
	var f:=FileAccess.open("res://artifacts/rift-checks.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	f.close()
	print("RIFT_CHECKS ",checks," failures=",failures.size())
	h.get_tree().quit(0 if failures.is_empty() else 1)
