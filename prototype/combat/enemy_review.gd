extends RefCounted
const CATALOG = preload("res://combat/enemy_catalog.gd")

static func note(checks: Array[String], ok: bool, text: String) -> void:
	checks.append(("PASS " if ok else "FAIL ")+text)

static func remove_enemies(h: Node) -> void:
	for e in h.enemies:
		if is_instance_valid(e):
			h.stage.remove_actor(e)
			e.queue_free()
	h.enemies.clear()
	h.spore_field.clear()
	h.effects.clear()
	h.projectiles.clear()

static func tick(h: Node, e: Node, frames: int) -> void:
	for i in frames:
		await h.get_tree().physics_frame
		h.hitstop=0
		e._physics_process(1.0/60)

static func restore_player(h: Node, x: float=330) -> void:
	h.player.position=Vector2(x,640)
	h.player.hp=Profile.max_health()
	h.player.dead=false
	h.player.invuln=0
	h.player.state="idle"
	h.player.elapsed=0
	h.player.velocity=Vector2.ZERO
	h.hitstop=0

static func run(h: Node) -> void:
	var checks: Array[String]=[]
	if not h.test_mode or Profile.save_enabled:
		push_error("Enemy review requires --slice-test isolation")
		h.get_tree().quit(1)
		return
	Profile.level=3
	h.audio_enabled=false
	h.start_battle()
	await h.get_tree().physics_frame
	h.set_process(false)
	h.player.set_physics_process(false)
	h.spore_field.set_physics_process(false)
	h.view.visible=true
	h.wave=2
	h.toast_time=0
	restore_player(h)
	var actors: Dictionary={}
	for spec in [["beetle",590.0],["shaman",860.0],["raven",1100.0]]:
		var e: Node=h.spawn(spec[0],spec[1])
		e.set_physics_process(false)
		actors[e.kind]=e
		h.stage.sync(e,1.0/60)
		var rig: Node=h.stage.actors[e.get_instance_id()]
		note(checks,e.maximum==int(CATALOG.DATA[e.kind].hp) and e.hurtbox().size==CATALOG.DATA[e.kind].hurt.size,e.kind+" has distinct health and body bounds")
		note(checks,rig.frames.size()==8 and rig.source==rig.EXPANSION[e.kind],e.kind+" uses its own eight-pose sprite sheet")
		rig.set_frame(6,1)
		note(checks,rig.sprite.scale.x<0,e.kind+" flips authored left-facing art for rightward attacks")
		rig.set_frame(0,-1)
	h.stage.sync(h.player,1.0/60)
	h.refresh_hud()
	await h.get_tree().create_timer(0.15).timeout
	await h.capture("enemy-roster")
	var b: Node=actors.beetle
	b.position=Vector2(620,640)
	b.facing=-1
	b.begin_attack()
	var before: int=b.hp
	b.take_hit(20,1,false)
	note(checks,b.hp==before-12 and b.state=="tell","beetle front armor reduces light damage and resists first stagger")
	b.take_hit(20,1,true)
	note(checks,b.hp==before-32 and b.state=="stunned","heavy hit deals full damage and interrupts beetle charge")
	b.stagger=0
	b.transition("approach")
	before=b.hp
	b.take_hit(10,-1,false)
	note(checks,b.hp==before-10 and b.state=="stunned","beetle rear remains vulnerable to light hits")
	restore_player(h,390)
	b.position=Vector2(620,640)
	b.facing=-1
	b.begin_attack()
	var at: Vector2=b.position
	await tick(h,b,35)
	note(checks,b.state=="tell" and absf(b.position.x-at.x)<1 and h.player.hp==Profile.max_health(),"charge anticipation is stationary and harmless")
	h.stage.sync(b,1.0/60)
	await h.capture("enemy-beetle-windup")
	await tick(h,b,25)
	note(checks,b.state=="active" and b.position.x<at.x-40,"beetle releases a real forward-moving charge")
	await h.capture("enemy-beetle-charge")
	await tick(h,b,25)
	note(checks,b.state=="recover" and h.player.hp==Profile.max_health()-23,"charge connects once and leaves a punishable recovery")
	var hp: int=h.player.hp
	h.player.invuln=0
	await tick(h,b,12)
	note(checks,h.player.hp==hp,"charge cannot hit the same target twice")
	restore_player(h,500)
	b.position=Vector2(560,640)
	b.transition("active")
	b.dealt=false
	h.player.invuln=0.18
	await tick(h,b,1)
	note(checks,h.player.hp==Profile.max_health() and b.dealt,"dash protection consumes beetle contact without damage")
	var s: Node=actors.shaman
	restore_player(h,360)
	s.position=Vector2(900,640)
	s.facing=-1
	s.begin_attack()
	var locked: Vector2=s.target
	h.player.position.x=540
	await tick(h,s,40)
	note(checks,s.target==locked and h.spore_field.fields.is_empty(),"shaman locks target at anticipation and does not track a dodging player")
	await h.capture("enemy-shaman-windup")
	await tick(h,s,25)
	note(checks,h.spore_field.fields.size()==1 and h.spore_field.fields[0].pos.x==locked.x,"completed cast creates one field at the locked location")
	h.player.position.x=locked.x
	h.spore_field.advance(0.47)
	note(checks,h.player.hp==Profile.max_health(),"spore warning does not deal early damage")
	h.spore_field.advance(0.02)
	note(checks,h.player.hp==Profile.max_health()-21,"spore explosion deals damage only at warning completion")
	await h.capture("enemy-shaman-burst")
	h.player.invuln=0
	h.spore_field.advance(0.05)
	note(checks,h.player.hp==Profile.max_health()-21,"one spore cast cannot repeatedly damage")
	h.spore_field.clear()
	restore_player(h,360)
	h.spore_field.cast(s.eid,Vector2(360,640),-1)
	h.player.invuln=0.18
	h.spore_field.advance(0.49)
	h.player.invuln=0
	h.spore_field.advance(0.06)
	note(checks,h.player.hp==Profile.max_health(),"dash protection cannot expire into a second spore contact")
	h.spore_field.clear()
	h.spore_field.cast(s.eid,Vector2(360,640),-1)
	h.paused=true
	h.spore_field._physics_process(0.5)
	note(checks,h.spore_field.fields[0].age==0,"pause freezes hazard clocks")
	h.paused=false
	h.hitstop=0.1
	h.spore_field._physics_process(0.5)
	note(checks,h.spore_field.fields[0].age==0,"hitstop freezes hazard clocks")
	h.hitstop=0
	s.take_hit(999,1,true)
	note(checks,h.spore_field.fields.is_empty(),"killing a shaman cancels its outstanding field")
	await h.get_tree().physics_frame
	var r: Node=actors.raven
	restore_player(h,460)
	r.position=Vector2(780,600)
	r.facing=-1
	r.begin_attack()
	locked=r.target
	await tick(h,r,35)
	note(checks,r.position.y<560 and r.state=="tell","raven visibly ascends before the dive")
	await h.capture("enemy-raven-windup")
	await tick(h,r,28)
	note(checks,r.state=="active" and r.position.x<740 and r.target==locked,"raven follows a committed dive toward the locked target")
	await h.capture("enemy-raven-dive")
	await tick(h,r,33)
	note(checks,r.state=="recover" and h.player.hp==Profile.max_health()-19,"raven dive connects once then exits into recovery")
	await tick(h,r,44)
	note(checks,r.state=="approach" and absf(r.position.y-600)<5,"raven returns to a reachable hovering height")
	r.begin_attack()
	r.take_hit(1,1,true)
	note(checks,r.state=="stunned","heavy attacks interrupt aerial anticipation")
	remove_enemies(h)
	var kinds: Dictionary={}
	h.wave=0
	for i in 4:
		h.next_wave()
		for e in h.enemies:
			kinds[e.kind]=true
			e.set_physics_process(false)
		note(checks,h.enemies.size()>=2 and h.enemies.size()<=3,"wave %d has a bounded mixed encounter" % h.wave)
		remove_enemies(h)
	note(checks,kinds.size()==6 and h.wave==4,"four-wave route includes all three new enemies and the original boss")
	h.spore_field.cast(999,Vector2(330,640),-1)
	h.start_battle()
	h.player.set_physics_process(false)
	note(checks,h.spore_field.fields.is_empty(),"restarting a run clears outstanding hazards")
	h.spore_field.cast(999,Vector2(330,640),-1)
	h.finish(false)
	note(checks,h.spore_field.fields.is_empty(),"ending a run clears outstanding hazards")
	h.start_battle()
	h.player.set_physics_process(false)
	restore_player(h)
	h.player.hp=1
	for i in 2: h.spore_field.cast(999+i,h.player.position,-1)
	h.spore_field.advance(0.49)
	note(checks,h.over and not h.won and h.spore_field.fields.is_empty(),"fatal spore damage safely clears multiple pending fields")
	h.start_battle()
	h.player.set_physics_process(false)
	restore_player(h)
	h.player.hp=1
	h.projectiles.append({"pos":h.player.position+Vector2(0,-95),"velocity":Vector2.ZERO,"life":1.0})
	h._process(1.0/60)
	note(checks,h.over and not h.won and h.projectiles.is_empty(),"fatal projectile damage safely clears the active projectile loop")
	note(checks,not Profile.save_enabled,"all enemy checks keep the real save isolated")
	var failed:=0
	for line in checks:
		print(line)
		if line.begins_with("FAIL"): failed+=1
	var file:=FileAccess.open("res://artifacts/enemy-checks.txt",FileAccess.WRITE)
	file.store_string("\n".join(checks)+"\nFailures=%d\n" % failed)
	print("ENEMY_CHECKS ",checks.size()," failures=",failed)
	h.get_tree().quit(failed)
