extends RefCounted
const ULTS=preload("res://remediation/boss_ultimates.gd")
var results: Array[String]=[]
func check(ok: bool, label: String) -> void:
	results.append(("PASS " if ok else "FAIL ")+label)
	if not ok: print("REACTION_FAIL ",label)

func freeze(h: Node) -> void:
	h.set_process(false)
	h.player.set_physics_process(false)
	h.boss_fields.set_physics_process(false)
	h.spore_field.set_physics_process(false)
	h.arena.set_physics_process(false)
	h.enemy_fx.set_physics_process(false)
	h.sprint_wind.set_physics_process(false)
	h.hitstop=0
	h.wait_wave=999
	h.wave=h.CAMPAIGN.wave_count(h.level_index)

func reset(h: Node, index: int=0) -> void:
	h.choose_level(index)
	freeze(h)
	h.player.position=Vector2(600,640)
	h.player.velocity=Vector2.ZERO

func run(h: Node) -> void:
	if not h.test_mode or Profile.save_enabled: h.get_tree().quit(1); return
	h.audio_enabled=false
	Profile.level=3
	for index in 4:
		for side in [1,-1]:
			reset(h,index)
			h.player.position.x=940 if side==1 else 300
			var e: Node=h.spawn(h.current_level().boss,300 if side==1 else 940)
			e.set_physics_process(false)
			e.facing=-side
			check(ULTS.begin(e) and e.facing==side,"boss %d turns toward player before ultimate (%d)" % [index,side])
			check(not e.ult_data.has("safe_x"),"boss %d has no fixed safe-zone mechanic (%d)" % [index,side])
			check(not h.boss_fields.fields.is_empty() and h.boss_fields.fields.all(func(f): return not h.boss_fields.area(f).intersects(e.hurtbox())),"boss %d every damaging field excludes its own body (%d)" % [index,side])
			check(h.boss_fields.fields.all(func(f): return (f.pos.x-e.position.x)*side>0),"boss %d attacks in its actual facing direction (%d)" % [index,side])
			var positions: Array=h.boss_fields.fields.map(func(f): return f.pos)
			h.player.position.x=600
			e._physics_process(0.25)
			check(h.boss_fields.fields.map(func(f): return f.pos)==positions,"boss %d does not drag shown ground warnings behind a dodging player (%d)" % [index,side])
		for side in [1,-1]:
			reset(h,index)
			h.player.position.x=1210 if side==1 else 70
			var e: Node=h.spawn(h.current_level().boss,1160 if side==1 else 120)
			e.set_physics_process(false)
			e.hp=roundi(e.maximum*0.8)
			e.combat_age=8
			e.ult_cooldown=0
			var start: float=e.position.x
			check(not ULTS.begin(e) and h.boss_fields.fields.is_empty(),"boss %d refuses a self-overlapping wall cast (%d)" % [index,side])
			e._physics_process(1.0/60)
			check((e.position.x-start)*side<0 and h.boss_fields.fields.is_empty(),"boss %d physically makes room at an arena edge (%d)" % [index,side])
	for kind in ["melee","ranged","beetle","shaman","raven","boss","mycelium_boss","tempest_boss","cinder_boss"]:
		reset(h)
		h.enemy_sequence=49
		var e: Node=h.spawn(kind,500)
		e.set_physics_process(false)
		check(e.cooldown<0.5,"%s initial reaction is bounded independently of spawn sequence" % kind)
		e.cooldown=0
		e._physics_process(1.0/60)
		check(e.state=="tell" and e.facing==1,"%s acquires and begins an available attack in one AI tick" % kind)
		h.player.position.x=350
		e._physics_process(0.05)
		check(e.facing==-1,"%s corrects facing during early anticipation" % kind)
		var locked: Vector2=e.target
		e.timer=0.20
		h.player.position.x=700
		e._physics_process(0.01)
		check(e.target==locked and e.facing==-1,"%s commits direction after its short aim window" % kind)
	reset(h)
	h.player.position.x=560
	var moth: Node=h.spawn("ranged",500)
	moth.set_physics_process(false)
	moth.cooldown=0
	moth._physics_process(1.0/60)
	check(moth.state=="tell","a close-range moth still retaliates instead of fleeing forever")
	reset(h)
	var a: Node=h.spawn("melee",500)
	var b: Node=h.spawn("melee",720)
	var caster: Node=h.spawn("shaman",900)
	for e in [a,b,caster]: e.set_physics_process(false)
	a.transition("tell")
	b.transition("tell")
	check(h.attack_budget(caster),"two melee tells cannot starve the ranged attack slot")
	caster.transition("tell")
	var second: Node=h.spawn("ranged",1100)
	second.set_physics_process(false)
	check(not h.attack_budget(second),"group aggression remains capped at one caster and three attackers")
	reset(h)
	var small: Node=h.spawn("melee",780)
	small.set_physics_process(false)
	small.hp=1000
	small.take_hit(1,1,false)
	small.timer=0.1
	small.take_hit(1,1,false)
	check(is_equal_approx(small.timer,0.1),"light hits cannot repeatedly reset an ordinary enemy's reaction")
	small._physics_process(0.08)
	check(small.state=="approach","ordinary enemies exit light-hit stun promptly")
	reset(h)
	var p: Node=h.player
	var rig: Node=h.stage.actors[p.get_instance_id()]
	var bounds: Vector2=p.hurtbox().size
	for side in [1,-1]:
		p.state="idle"
		p.facing=side
		p.stamina=100
		p.dash_cd=0
		p.dash()
		for frame in 4:
			h.stage.sync(p,0.01)
			rig.drive(0.01,"dash",(frame+0.1)/4,side,570,640)
			check(rig.current_frame_id==100+frame and is_equal_approx(absf(rig.sprite.scale.x),rig.sprite.scale.y),"sprint uses complete forward-lean frame %d with uniform proportions (%d)" % [frame,side])
		check(p.hurtbox().size==bounds and p.stamina==68,"sprint art keeps the real collision and stamina rules (%d)" % side)
	h.sprint_wind.clear()
	h.sprint_wind.advance(0.01)
	p.position.x+=20
	h.stage.sync(p,0.01)
	h.sprint_wind.advance(0.03)
	check(not h.sprint_wind.ghosts.is_empty() and not h.sprint_wind.trails.is_empty(),"actual sprint displacement produces pose snapshots and wind")
	for i in 25:
		p.position.x+=10
		h.sprint_wind.advance(0.03)
	check(h.sprint_wind.ghosts.size()<=8 and h.sprint_wind.trails.size()<=12,"sprint trails have bounded lifetimes and counts")
	var age: float=h.sprint_wind.ghosts[0].age
	h.paused=true
	h.sprint_wind._physics_process(0.2)
	check(h.sprint_wind.ghosts[0].age==age,"pause freezes sprint animation trails")
	h.paused=false
	h.hitstop=0.1
	h.sprint_wind._physics_process(0.2)
	check(h.sprint_wind.ghosts[0].age==age,"hitstop freezes sprint trails")
	h.hitstop=0
	h.camp()
	check(h.sprint_wind.ghosts.is_empty() and h.sprint_wind.trails.is_empty(),"camp clears sprint ghosts and wind")
	var failures: Array=results.filter(func(s): return s.begins_with("FAIL"))
	var file:=FileAccess.open("res://artifacts/reaction-review.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":results.size(),"failures":failures.size(),"results":results},"\t"))
	print("REACTION_CHECKS ",results.size()," failures=",failures.size())
	h.get_tree().quit(failures.size())
