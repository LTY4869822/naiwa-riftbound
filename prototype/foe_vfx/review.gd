extends RefCounted
const CASES = preload("res://foe_vfx/cases.gd")
const PROFILES = preload("res://foe_vfx/profiles.gd")

static func note(results: Array[String], ok: bool, text: String) -> void:
	results.append(("PASS " if ok else "FAIL ")+text)

static func freeze(h: Node) -> void:
	h.set_process(false)
	h.player.set_physics_process(false)
	h.spore_field.set_physics_process(false)
	h.boss_fields.set_physics_process(false)
	h.enemy_fx.set_physics_process(false)
	h.player.position=Vector2(450,640)
	h.player.invuln=0
	h.view.visible=true
	h.view.position=Vector2.ZERO
	h.fx_node.position=Vector2.ZERO
	h.hitstop=0
	h.trauma=0
	h.stage.sync(h.player,1.0/60)

static func tick(h: Node, enemy: Node, frames: int) -> void:
	for i in frames:
		await h.get_tree().physics_frame
		h.hitstop=0
		enemy._physics_process(1.0/60)
		h.spore_field.advance(1.0/60)
		h.boss_fields.advance(1.0/60)
		h.enemy_fx.advance(1.0/60)

static func run(h: Node) -> void:
	if not h.test_mode or Profile.save_enabled:
		h.get_tree().quit(1)
		return
	var results: Array[String]=[]
	h.audio_enabled=false
	Profile.level=3
	h.enemy_fx.tracing=true
	var kinds: Dictionary={}
	for spec in CASES.ITEMS:
		h.choose_level(spec.map)
		await h.get_tree().physics_frame
		freeze(h)
		h.wave=h.CAMPAIGN.wave_count(h.level_index)
		var e: Node=h.spawn(spec.kind,spec.x)
		e.set_physics_process(false)
		e.facing=-1
		e.action_count=1 if spec.move==0 else 0
		var hp: int=h.player.hp
		e.begin_attack()
		kinds[e.kind]=true
		note(results,h.enemy_fx.events.any(func(item): return item.owner==e.eid and item.mode=="charge"),spec.name+" emits a species-specific anticipation")
		h.enemy_fx.advance(0.1)
		note(results,not h.enemy_fx.canvas.light.is_empty(),spec.name+" has real rendered charge geometry")
		note(results,not h.enemy_fx.canvas.shapes.is_empty(),spec.name+" has an opaque anime silhouette over the map")
		await tick(h,e,6)
		note(results,h.player.hp==hp and h.projectiles.is_empty(),spec.name+" VFX does not create early gameplay damage")
		h.player.invuln=100
		e.timer=e.windup_duration()-0.005
		await tick(h,e,1)
		note(results,e.state=="active" and h.enemy_fx.events.any(func(item): return item.owner==e.eid and item.mode=="release"),spec.name+" fires from the real attack transition")
		if spec.kind in ["melee","raven","boss"] or (spec.kind in ["mycelium_boss","tempest_boss"] and spec.move==1) or (spec.kind=="cinder_boss" and spec.move==0) or spec.kind=="beetle":
			note(results,not h.enemy_fx.meshes.is_empty(),spec.name+" uses imported claw/ribbon mesh geometry")
			var mesh: Dictionary=h.enemy_fx.meshes[0]
			var before: Vector2=mesh.node.position
			e.position.x+=13
			h.enemy_fx.advance(0.001)
			note(results,is_equal_approx(mesh.node.position.x-before.x,13),spec.name+" follows the moving enemy without shifting its collider")
		var ages: Array=h.enemy_fx.events.map(func(item): return item.age)
		h.paused=true
		h.enemy_fx._physics_process(0.2)
		note(results,ages==h.enemy_fx.events.map(func(item): return item.age),spec.name+" freezes its animation on pause")
		h.paused=false
		h.hitstop=0.1
		h.enemy_fx._physics_process(0.2)
		note(results,ages==h.enemy_fx.events.map(func(item): return item.age),spec.name+" freezes on hitstop")
		h.hitstop=0
		await tick(h,e,4)
		await h.capture("foe-vfx-"+e.kind+"-%d" % spec.move)
		# A committed normal attack now requires a full poise break. This case
		# checks cleanup after an actual interruption, not unconditional heavy stun.
		if e.boss:
			e.stagger=100
			e.break_guard=0
		e.take_hit(1,1,true)
		note(results,e.state=="stunned" and not h.enemy_fx.events.any(func(item): return item.owner==e.eid and item.bound) and not h.enemy_fx.meshes.any(func(item): return item.owner==e.eid and item.bound),spec.name+" interruption removes attached attack effects")
		e.take_hit(99999,1,true)
		note(results,not h.enemy_fx.events.any(func(item): return item.owner==e.eid) and not h.enemy_fx.meshes.any(func(item): return item.owner==e.eid),spec.name+" death cancels all owned VFX")
		await h.get_tree().physics_frame
	note(results,kinds.size()==9 and PROFILES.DATA.size()==9,"all nine enemy identities including all four bosses are covered")
	h.choose_level(0)
	await h.get_tree().physics_frame
	freeze(h)
	var beetle: Node=h.spawn("beetle",600)
	var bird: Node=h.spawn("raven",534)
	beetle.set_physics_process(false)
	bird.set_physics_process(false)
	bird.position.y=665
	beetle.facing=-1
	beetle.take_hit(20,1,false)
	note(results,h.enemy_fx.events.any(func(item): return item.mode=="armor" and item.kind=="beetle" and item.owner==beetle.eid),"overlapping enemies cannot steal the beetle's armor material identity")
	var king: Node=h.spawn("mycelium_boss",940)
	king.set_physics_process(false)
	bird.position=Vector2(940,600)
	king.take_hit(king.maximum/2+1,1,true)
	note(results,h.enemy_fx.events.any(func(item): return item.mode=="enrage" and item.kind=="mycelium_boss" and item.owner==king.eid),"phase-two VFX keeps its boss identity even with an overlapping raven")
	h.choose_level(2)
	await h.get_tree().physics_frame
	freeze(h)
	for style in ["spore","lightning","eruption"]:
		h.enemy_fx.clear()
		h.boss_fields.clear()
		h.boss_fields.cast(999,Vector2(450,640),style,0.5,20,50)
		h.boss_fields.advance(0.49)
		note(results,not h.enemy_fx.events.any(func(item): return item.mode=="field"),style+" impact VFX waits for the real hazard boundary")
		h.boss_fields.advance(0.02)
		note(results,h.enemy_fx.events.any(func(item): return item.mode=="field" and item.style==style),style+" material burst starts on actual hazard activation")
		h.enemy_fx.advance(0.1)
		var animation_key: String="sprite_lightning" if style=="lightning" else "sprite_fire" if style=="eruption" else "sprite_spore"
		note(results,h.enemy_fx.canvas.pools.has(animation_key) and h.enemy_fx.canvas.pools[animation_key].used>0,style+" uses the new painted eight-frame animation")
		await h.capture("foe-vfx-field-"+style)
	h.enemy_fx.clear()
	h.spore_field.clear()
	h.boss_fields.clear()
	h.shoot(Vector2(900,510),Vector2(450,510),-1)
	var bullet: Dictionary=h.projectiles[0]
	var at: Vector2=bullet.pos
	h.enemy_fx.advance(0.1)
	note(results,bullet.pos==at and bullet.enemy_vfx and not h.enemy_fx.canvas.light.is_empty(),"lantern particles follow the real projectile and never move it")
	h.reduce_motion=true
	h.enemy_fx.paint()
	note(results,h.enemy_fx.canvas.time==0,"reduced motion freezes shader noise without changing projectile physics")
	h.reduce_motion=false
	for i in 100: h.enemy_fx.emit("shaman","contact",Vector2(450,520),0.4)
	note(results,h.enemy_fx.events.size()<=h.enemy_fx.LIMIT,"transient effect count stays bounded under burst load")
	h.enemy_fx.advance(1.0)
	note(results,h.enemy_fx.events.is_empty() and h.enemy_fx.meshes.is_empty(),"all transient effects expire and release their mesh nodes")
	note(results,h.enemy_fx.canvas.invalid_polygons==0,"all cel silhouettes triangulate without invalid geometry")
	h.projectiles.clear()
	h.enemy_fx.paint()
	var animation_hidden:=true
	for pool in h.enemy_fx.canvas.pools.values():
		for node in pool.nodes:
			if node.visible: animation_hidden=false
	note(results,animation_hidden,"pooled painted animations hide after the attack expires")
	note(results,h.enemy_fx.find_children("*","SubViewport",true,false).is_empty(),"runtime adapter draws full-resolution meshes without per-effect viewports")
	h.enemy_fx.emit("raven","contact",Vector2(450,520),0.4)
	h.camp()
	h.enemy_fx._process(0)
	note(results,not h.enemy_fx.visible,"camp hides every enemy effect subtree")
	h.choose_level(3)
	freeze(h)
	note(results,h.enemy_fx.events.is_empty() and h.enemy_fx.meshes.is_empty(),"changing maps clears all old attack visuals")
	h.enemy_fx.emit("raven","contact",Vector2(450,520),0.4)
	h.finish(false)
	note(results,h.enemy_fx.events.is_empty(),"ending a run clears every enemy visual")
	var lab:=preload("res://foe_vfx/lab.gd").new()
	lab.host=h
	h.add_child(lab)
	note(results,lab.opponent.kind=="melee" and h.mode=="battle","interactive lab begins with a playable hunter encounter")
	var key:=InputEventKey.new()
	key.pressed=true
	key.keycode=KEY_9
	lab._unhandled_input(key)
	note(results,lab.selected==8 and lab.opponent.kind=="cinder_boss" and h.level_index==3,"lab number keys select the corresponding enemy and scene")
	key.keycode=KEY_T
	lab._unhandled_input(key)
	note(results,lab.opponent.state=="tell","lab can preview a boss's next real attack")
	key.keycode=KEY_R
	lab._unhandled_input(key)
	note(results,lab.opponent.kind=="cinder_boss" and lab.opponent.hp==lab.opponent.maximum and h.enemy_fx.events.is_empty(),"lab retry restores the selected opponent and clears its previous VFX")
	note(results,not Profile.save_enabled,"VFX review never writes the real player profile")
	var failures:=0
	for result in results:
		print(result)
		if result.begins_with("FAIL"): failures+=1
	var file:=FileAccess.open("res://artifacts/foe-vfx-checks.txt",FileAccess.WRITE)
	file.store_string("\n".join(results)+"\nFailures=%d\n" % failures)
	var trace:=FileAccess.open("res://artifacts/foe-vfx-trace.json",FileAccess.WRITE)
	trace.store_string(JSON.stringify({"events":h.enemy_fx.trace,"peak_events":h.enemy_fx.peak_events,"peak_meshes":h.enemy_fx.peak_meshes},"\t"))
	print("FOE_VFX_CHECKS ",results.size()," failures=",failures)
	h.get_tree().quit(failures)
