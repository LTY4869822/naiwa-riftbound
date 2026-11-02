extends RefCounted
var results: Array[String]=[]

func check(ok: bool, label: String) -> void:
	results.append(("PASS " if ok else "FAIL ")+label)

func target(h: Node, x: float) -> Node:
	var e: Node=h.spawn("melee",x)
	e.set_physics_process(false)
	e.hp=500
	e.maximum=500
	return e

func tick(h: Node, dt: float) -> void:
	h.hitstop=0
	h.ultimate.advance(dt)

func run(h: Node) -> void:
	Profile.level=3
	h.start_battle()
	h.set_process(false)
	h.ultimate.set_process(false)
	h.player.set_physics_process(false)
	await h.get_tree().physics_frame
	var p: Node=h.player
	var u: Node=h.ultimate
	var rig: Node=h.stage.actors[p.get_instance_id()]
	Profile.level=1
	p.focus=100
	p.skill()
	check(p.state=="idle" and p.focus==100,"level-one lock does not spend focus")
	Profile.level=3
	p.focus=59
	p.skill()
	check(p.state=="idle" and p.focus==59,"insufficient focus cannot begin a cast")
	for facing in [1,-1]:
		for old in h.enemies:
			if is_instance_valid(old):
				h.stage.remove_actor(old)
				old.queue_free()
		h.enemies.clear()
		u.clear()
		h.hitstop=0
		p.position=Vector2(245 if facing==1 else 1035,640)
		p.velocity=Vector2.ZERO
		p.facing=facing
		p.state="idle"
		p.focus=100
		p.stamina=100
		p.dash_cd=0
		var near: Node=target(h,p.position.x+facing*170)
		var far: Node=target(h,p.position.x+facing*560)
		var rear: Node=target(h,p.position.x-facing*100)
		var launches: int=u.launch_count
		p.skill()
		p.step(0.47)
		check(p.focus==40 and not p.skill_fired and u.waves.is_empty(),"%d: charge costs 60 focus and cannot damage early" % facing)
		check(near.hp==500 and far.hp==500,"%d: charge is harmless" % facing)
		p.dash()
		check(p.state=="skill" and p.stamina==100,"%d: dash cannot cancel before release" % facing)
		p.step(0.02)
		var fist: Vector2=h.stage.strike_position(p)
		check(rig.current_frame_id==6 and u.waves.size()==1 and u.waves[0].origin.distance_to(fist)<0.1,"%d: wave starts at the complete drawing's forward fist" % facing)
		p.skill()
		p.step(0.01)
		check(u.launch_count==launches+1 and p.focus==40,"%d: held/repeated skill cannot spend or launch twice" % facing)
		check(near.hp==500,"%d: release does not teleport damage to the target" % facing)
		tick(h,0.03)
		var near_hp: int=near.hp
		check(near_hp<500 and far.hp==500,"%d: forward wave hits the near enemy before the far enemy" % facing)
		var location: Vector2=u.waves[0].pos
		h.paused=true
		u.advance(0.5)
		check(u.waves[0].pos==location and near.hp==near_hp,"%d: pause freezes travel and damage" % facing)
		h.paused=false
		h.hitstop=0.1
		u.advance(0.2)
		check(u.waves[0].pos==location,"%d: hit-stop freezes the projectile and VFX clock together" % facing)
		for i in 18: tick(h,0.04)
		check(near.hp==near_hp and far.hp<500,"%d: one wave pierces both targets, once each" % facing)
		check(rear.hp==500,"%d: rear enemy is unharmed" % facing)
		check(u.waves.is_empty(),"%d: finite range retires the wave" % facing)
		p.step(0.25)
		p.dash()
		check(p.state=="dash","%d: recovery permits a late dash cancel" % facing)
		check(is_equal_approx(absf(rig.sprite.scale.x),rig.sprite.scale.y) and rig.factor==0.175,"%d: ultimate preserves character proportions and source scale" % facing)
	# A large frame interval still sweeps every enemy, but never beyond max range.
	u.clear()
	for e in h.enemies:
		if is_instance_valid(e):
			h.stage.remove_actor(e)
			e.queue_free()
	h.enemies.clear()
	var swept: Node=target(h,620)
	var beyond: Node=target(h,1150)
	u.launch(Vector2(250,510),1)
	tick(h,2.0)
	check(swept.hp<500 and beyond.hp==500 and u.waves.is_empty(),"swept hitbox catches low-FPS crossings and respects range")
	# A nearby enemy between body and fist is still in front of the caster.
	var close: Node=target(h,300)
	u.launch(Vector2(337,510),1,245)
	tick(h,0.005)
	check(close.hp<500,"close forward target remains hittable before the fist anchor")
	u.clear()
	p.state="skill"
	p.skill_fired=false
	p.elapsed=0.3
	u.update_background()
	check(u.background_material.get_shader_parameter("canvas_size")==h.get_viewport_rect().size,"background distortion uses the actual viewport dimensions")
	p.state="idle"
	h.reduce_motion=true
	u.launch(Vector2(250,510),1)
	tick(h,0.01)
	check(not u.background.visible,"reduced motion removes screen distortion after release")
	check(u.background.z_index<rig.z_index and u.background_copy.z_index<u.background.z_index,"background capture renders before the character, excluding it from distortion")
	u.clear()
	check(u.waves.is_empty() and u.bursts.is_empty() and not u.background.visible,"clear retires all effects and background passes")
	p.state="skill"
	p.skill_fired=false
	h.camp()
	check(p.state=="idle" and u.waves.is_empty(),"camp cancels a charge so it cannot launch on return")
	h.start_battle()
	check(u.waves.is_empty() and u.bursts.is_empty() and not u.background.visible,"restarting the encounter clears prior ultimate visuals and colliders")
	h.player.state="skill"
	h.player.skill_fired=false
	h.finish(false)
	check(not u.charging() and u.waves.is_empty() and not u.background.visible,"ending combat during a charge cannot redraw the charge on the results screen")
	check(not Profile.save_enabled,"ultimate checks use an isolated profile")
	var failed: int=results.filter(func(s): return s.begins_with("FAIL")).size()
	var file:=FileAccess.open("res://artifacts/ultimate-checks.txt",FileAccess.WRITE)
	file.store_string("\n".join(results)+"\nFailures=%d\n" % failed)
	print("ULTIMATE_CHECKS ",results.size()," failures=",failed)
	h.get_tree().quit(failed)
