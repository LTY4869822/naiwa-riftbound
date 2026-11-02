extends RefCounted
const BRAIN=preload("res://loop/boss_brain.gd")
var h: Node
var checks:=0
var failures: Array=[]
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures.append(label); push_error(label)
func frames(n: int) -> void:
	for i in n: await h.get_tree().process_frame
func wait(seconds: float) -> void: await h.get_tree().create_timer(seconds).timeout
func quiet() -> void:
	h.wait_wave=999
	h.wave=1
	h.boss_fields.clear()
	h.projectiles.clear()
	for e in h.enemies:
		if is_instance_valid(e): h.stage.remove_actor(e); e.queue_free()
	h.enemies.clear()
func run(host: Node) -> void:
	h=host
	Profile.level=3
	h.choose_level(0)
	await frames(4)
	quiet()
	Ascension.reset()
	Wardrobe.reset()
	for i in 6: Ascension.record_kill(h.run_reward_id,i+1,false)
	check(Ascension.energy==30,"six minions cannot awaken")
	Ascension.record_kill(h.run_reward_id,20,true)
	check(Ascension.energy==40,"boss energy is limited")
	check(not h.ascension.awaken(),"insufficient energy prevents transformation")
	var p: Node=h.player
	p.hp=40
	var cash:=Wardrobe.coins
	var e: Node=h.spawn("melee",850)
	e.take_hit(10000,1,true)
	check(Wardrobe.coins==cash,"kill does not directly credit pickup gold")
	check(h.journey.drops.size()==1,"enemy creates a physical drop")
	var drop: Dictionary=h.journey.drops[0]
	check(h.journey.collect(drop),"physical pickup credits wallet")
	var after:=Wardrobe.coins
	check(after==int(drop.amount),"pickup uses the actual dropped value")
	check(h.journey.collect(drop) and Wardrobe.coins==after,"duplicate pickup cannot mint coins")
	h.journey.drops.clear()
	var hp: int=p.hp
	h.wave=1
	h.next_wave()
	check(p.hp==hp,"next encounter cannot auto-heal")
	quiet()
	h.finish(true)
	if h.rift.offer_active: h.rift.pick("edge")
	check(not h.over and h.journey.cleared,"room clear stays playable with no victory menu")
	check(p.hp==hp,"room clear does not refill HP")
	var heals: Array=h.journey.drops.filter(func(d): return d.type=="heal")
	check(heals.size()==1,"room clear creates exactly one healing pickup")
	check(h.journey.collect(heals[0]) and p.hp==mini(Profile.max_health(),hp+roundi((Profile.max_health()-hp)*.5)),"healing pickup restores half missing health, not full HP")
	var actor_id: int=p.get_instance_id()
	var carried: int=p.hp
	h.continue_room()
	check(h.stage_index==1 and p.get_instance_id()==actor_id and p.hp==carried,"second room retains the same actor and health")
	h.journey.cleared=false
	h.continue_room()
	check(h.stage_index==2 and p.get_instance_id()==actor_id and p.hp==carried,"third room retains the same actor and health")
	h.choose_level(0)
	await frames(3)
	quiet()
	p=h.player
	p.hp=44
	actor_id=p.get_instance_id()
	h.finish(true)
	if h.rift.offer_active: h.rift.pick("edge")
	h.journey.clear_age=1.1
	p.position=Vector2(1150,640)
	Input.action_press("move_right")
	await wait(.85)
	Input.action_release("move_right")
	check(h.stage_index==1 and not h.journey.travelling and p.get_instance_id()==actor_id and p.hp==44,"actual exit gate advances without healing or rebuilding actor")
	quiet()
	h.journey.reset()
	p.position=Vector2(500,640)
	p.state="idle"
	p.velocity=Vector2.ZERO
	Input.action_press("move_left")
	p.step(1.0/60)
	check(p.facing==-1 and p.velocity.x<0,"left input turns on its first physics tick")
	for i in 5: p.step(1.0/60)
	check(absf(p.velocity.x)>=280,"full run speed in under 100ms")
	Input.action_release("move_left")
	Input.action_press("move_right")
	p.step(1.0/60)
	check(p.facing==1,"reversal facing changes immediately")
	for i in 5: p.step(1.0/60)
	check(p.velocity.x>250,"direction reverses in under 100ms")
	p.state="idle"
	p.stamina=100
	p.dash_cd=0
	p.facing=-1
	p.dash()
	check(p.facing==1,"same-frame right input directs dash immediately")
	p.state="idle"
	Input.action_release("move_right")
	p.attack(0)
	p.elapsed=p.STARTUP[0]+p.ACTIVE[0]+0.03
	Input.action_press("move_left")
	p.step(1.0/60)
	check(p.state=="idle" and p.velocity.x<0,"movement cancels completed contact recovery")
	Input.action_release("move_left")
	p.position=Vector2(300,640)
	p.state="idle"
	await frames(3)
	Ascension.energy=100
	hp=p.hp
	check(h.ascension.awaken(),"earned full meter still awakens")
	h.ascension.advance(h.ascension.INTRO+.01)
	check(p.hp==hp,"awakening grants no free healing")
	check(h.ascension.DURATION==14,"empowered duration limited to fourteen seconds")
	var rig: Node=h.stage.actors[p.get_instance_id()]
	rig.drive(.016,"run",0,1,310,640)
	check(rig.ascended.data["hero/run-v2.png"].frames.size()==8 and rig.ascended.data["hero/morph-v2.png"].frames.size()==8,"new run and transformation contain eight authored poses")
	check(rig.ascended.first.modulate.a==1 and not rig.ascended.second.visible,"run uses one opaque pose without body ghosting")
	check(rig.ascended.max_ground_error<.001,"new poses keep the measured ground pivot")
	var target: Node=h.spawn("zheng",850)
	target.set_physics_process(false)
	var before: int=target.hp
	h.ascension.finisher()
	for pulse in 3: h.ascension.strike(pulse)
	check(not target.dead and target.hp>before*.65,"finisher cannot delete a healthy late boss")
	h.ascension.clear()
	quiet()
	for kind in BRAIN.NAMES:
		var boss: Node=h.spawn(kind,960)
		boss.set_physics_process(false)
		h.player.position=Vector2(300,640)
		var names: Array=[]
		for move in 4:
			BRAIN.begin(boss,move)
			names.append(boss.attack_data.name)
			check(boss.move_id==move and boss.windup_duration()>0.4,kind+" move telegraph "+str(move))
			BRAIN.release(boss)
			if move==2 and kind not in ["zhuyin","yinglong"]:
				check(h.projectiles.all(func(b): return b.velocity.x*boss.facing>0),kind+" volleys respect facing")
			check(boss.attack_data.active>0.3,kind+" distinct active interval "+str(move))
			h.projectiles.clear()
			h.boss_fields.clear()
		check(names.size()==4 and names[0]!=names[1] and names[2]!=names[3],kind+" has four named attacks")
		quiet()
	# Contact regressions use real boss damage, without particles or invulnerability.
	p.hp=Profile.max_health()
	p.invuln=0
	p.position=Vector2(700,640)
	var attacker: Node=h.spawn("zheng",500)
	attacker.set_physics_process(false)
	BRAIN.begin(attacker,0)
	attacker.transition("active")
	BRAIN.release(attacker)
	attacker.timer=.07
	var contact_hp: int=p.hp
	BRAIN.step(attacker,0)
	check(p.hp<contact_hp,"combo contact deals real damage")
	contact_hp=p.hp
	p.invuln=0
	BRAIN.step(attacker,0)
	check(p.hp==contact_hp,"one combo contact cannot deal damage every frame")
	p.invuln=0
	p.position=Vector2(700,640)
	attacker.position=Vector2(500,640)
	BRAIN.begin(attacker,1)
	attacker.transition("active")
	BRAIN.release(attacker)
	attacker.timer=.50
	contact_hp=p.hp
	BRAIN.step(attacker,0)
	check(p.hp<contact_hp,"rush retains contact damage after its initial frames")
	quiet()
	p.hp=Profile.max_health()
	p.invuln=0
	p.position=Vector2(300,640)
	attacker=h.spawn("zhuyin",1000)
	attacker.set_physics_process(false)
	attacker.facing=-1
	BRAIN.beam(attacker)
	contact_hp=p.hp
	h.boss_fields.advance(.70)
	check(p.hp==contact_hp,"beam warning never hurts the player")
	h.boss_fields.advance(.03)
	check(p.hp<contact_hp,"released beam uses its visible ground lane")
	p.invuln=0
	p.position.y=510
	h.boss_fields.clear()
	BRAIN.beam(attacker)
	contact_hp=p.hp
	h.boss_fields.advance(.73)
	check(p.hp==contact_hp,"jumping above the beam avoids actual damage")
	h.boss_fields.clear()
	p.position=Vector2(300,640)
	BRAIN.begin(attacker,3)
	BRAIN.release(attacker)
	check(h.boss_fields.fields.all(func(f): return not h.boss_fields.area(f).intersects(attacker.hurtbox())),"targeted domain fields exclude the boss body")
	h.boss_fields.cancel(attacker.eid)
	check(h.boss_fields.fields.is_empty(),"defeating an owner cancels its remaining domain damage")
	quiet()
	h.hitstop=0
	Wardrobe.reset()
	Wardrobe.award_clear("moss",Crypto.new().generate_random_bytes(16).hex_encode())
	Wardrobe.award_clear("moss-2",Crypto.new().generate_random_bytes(16).hex_encode())
	var d0:=Profile.damage()
	var h0:=Profile.max_health()
	check(Wardrobe.buy_gear("bracer").ok and Profile.damage()==d0+3,"coins buy an equipped attack item")
	check(not Wardrobe.buy_gear("bracer").ok,"insufficient money cannot double-upgrade")
	Wardrobe.award_clear("moss-3",Crypto.new().generate_random_bytes(16).hex_encode())
	check(Wardrobe.buy_gear("charm").ok and Profile.max_health()==h0+16,"health equipment modifies real maximum")
	var legacy:=Wardrobe.to_dict()
	legacy.erase("gear_ranks")
	legacy.erase("loot_ledger")
	check(Wardrobe.valid(legacy),"old wallet files remain readable")
	check(Wardrobe.valid(Wardrobe.to_dict()),"new economy fields satisfy durable save validation")
	h.open_gear()
	await wait(.25)
	await h.capture("loop-gear")
	check(h.hud.find_child("Forge_bracer",true,false)!=null,"real equipment menu exposes purchases")
	h.open_route()
	await wait(.7)
	await h.capture("loop-route")
	var route: Node=h.hud.find_child("LevelRoute",true,false)
	check(route.cards[0].stage_buttons.is_empty(),"maps enter one connected run instead of disconnected stage buttons")
	var f:=FileAccess.open("res://artifacts/loop-checks.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"failures":failures,"formal_saves":Profile.save_enabled or Wardrobe.save_enabled or Ascension.save_enabled},"\t"))
	f.close()
	print("LOOP_CHECKS ",checks," failures=",failures.size())
	h.get_tree().quit(0 if failures.is_empty() else 1)
