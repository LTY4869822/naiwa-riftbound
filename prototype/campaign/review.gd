extends RefCounted
const LEVELS = preload("res://campaign/levels.gd")
const OLD_REVIEW = preload("res://combat/enemy_review.gd")

static func note(results: Array[String], ok: bool, title: String) -> void:
	results.append(("PASS " if ok else "FAIL ")+title)

static func freeze(h: Node) -> void:
	h.set_process(false)
	h.player.set_physics_process(false)
	h.spore_field.set_physics_process(false)
	h.boss_fields.set_physics_process(false)
	h.player.invuln=0
	h.player.position=Vector2(350,640)
	h.player.velocity=Vector2.ZERO
	h.stage.sync(h.player,1.0/60)
	h.view.visible=true
	h.view.position=Vector2.ZERO
	h.fx_node.position=Vector2.ZERO
	h.hitstop=0
	h.trauma=0
	h.toast_time=0

static func run(h: Node) -> void:
	var results: Array[String]=[]
	if not h.test_mode or Profile.save_enabled:
		h.get_tree().quit(1)
		return
	h.audio_enabled=false
	Profile.level=3
	h.open_route()
	await h.get_tree().create_timer(0.2).timeout
	var route: Node=h.hud.find_child("LevelRoute",true,false)
	note(results,is_instance_valid(route) and route.cards.size()==4,"route map exposes four real selectable levels")
	await h.capture("campaign-route")
	route.cards[2].pressed.emit()
	await h.get_tree().create_timer(0.95).timeout
	await h.get_tree().physics_frame
	freeze(h)
	note(results,h.level_index==2 and h.stage.level_index==2 and h.mode=="battle" and not h.route_open,"choosing a map enters the corresponding environment")
	var distinct: Dictionary={}
	var bosses: Dictionary={}
	for i in 4:
		h.choose_level(i)
		await h.get_tree().physics_frame
		freeze(h)
		var data: Dictionary=h.current_level()
		distinct[data.background]=true
		bosses[data.boss]=true
		var texture: Texture2D=preload("res://campaign/scenery.gd").texture(i)
		note(results,texture!=null and texture.get_width()>1200,"level %d has an imported painted environment" % (i+1))
		var guardian: Node=null
		for j in data.waves.size():
			h.next_wave()
			var found:=false
			for e in h.enemies:
				e.set_physics_process(false)
				if e.boss:
					found=true
					guardian=e
					note(results,e.kind==data.boss,"level %d spawns its own named guardian" % (i+1))
			note(results,found==(j==data.waves.size()-1),"level %d encounter %d preserves the guardian climax" % [i+1,j+1])
			if j<data.waves.size()-1: OLD_REVIEW.remove_enemies(h)
			await h.get_tree().physics_frame
		h.refresh_hud()
		h.stage.sync(guardian,1.0/60)
		note(results,h.battle_hud.snapshot.level_title==data.title and h.battle_hud.snapshot.boss_name==data.boss_name,"level %d HUD binds the actual map and boss name" % (i+1))
		await h.get_tree().create_timer(0.16).timeout
		await h.capture("campaign-level-%d" % (i+1))
		if i>0:
			var rig: Node=h.stage.actors[guardian.get_instance_id()]
			note(results,rig.frames.size()==8 and guardian.maximum>=620,"guardian %d has eight authored poses and boss health" % i)
			guardian.facing=-1
			guardian.action_count=1
			guardian.begin_attack()
			await OLD_REVIEW.tick(h,guardian,13)
			var lock: Vector2=guardian.target
			var duration: float=guardian.windup_duration()
			h.player.position.x=440
			await OLD_REVIEW.tick(h,guardian,maxi(1,floori((duration-0.25)*60)))
			note(results,guardian.target==lock and h.boss_fields.fields.is_empty(),"guardian %d locks its cast target and preserves harmless anticipation" % i)
			await OLD_REVIEW.tick(h,guardian,40)
			note(results,not h.boss_fields.fields.is_empty(),"guardian %d releases its distinctive area attack" % i)
			h.player.position.x=lock.x
			var health: int=h.player.hp
			h.boss_fields.advance(0.4)
			note(results,h.player.hp==health,"guardian %d warning cannot deal early damage" % i)
			h.boss_fields.advance(0.9)
			note(results,h.player.hp<health,"guardian %d warning completion deals real damage" % i)
			for effect in h.effects:
				if str(effect.type).begins_with("boss_"): effect.life=effect.max*0.73
			h.stage.sync(guardian,1.0/60)
			h.stage.sync(h.player,1.0/60)
			await h.capture("campaign-attack-%d" % (i+1))
			h.boss_fields.clear()
			guardian.stagger=0
			guardian.action_count=1
			guardian.begin_attack()
			guardian.take_hit(1,1,false)
			note(results,guardian.state=="tell","guardian %d armor resists light interruption" % i)
			guardian.take_hit(1,1,true)
			note(results,guardian.state=="stunned","guardian %d heavy hit breaks its stance" % i)
			guardian.action_count=1
			guardian.begin_attack()
			duration=guardian.windup_duration()
			guardian.take_hit(guardian.maximum/2+1,1,true)
			note(results,guardian.enraged and is_equal_approx(duration,guardian.windup_duration()),"guardian %d enters phase two without shortening an already signalled cast" % i)
			guardian.action_count=1
			guardian.begin_attack()
			note(results,guardian.windup_duration()<duration,"guardian %d phase two changes subsequent attack pacing" % i)
			if i==3:
				guardian.transition("recover")
				var before: int=guardian.hp
				guardian.take_hit(10,1,true)
				note(results,before-guardian.hp==13,"overheated forge core takes increased damage during recovery")
			h.boss_fields.cast(guardian.eid,Vector2(350,640),"spore",0.8,20,45)
			guardian.take_hit(9999,1,true)
			note(results,h.boss_fields.fields.is_empty(),"guardian %d death cancels every outstanding area attack" % i)
		h.finish(true)
		var wins_before: int=Profile.wins
		h.finish(true)
		note(results,h.completed_levels.has(i) and Profile.wins==wins_before,"level %d clear reward is idempotent" % (i+1))
		if i<3:
			h.next_level()
			note(results,h.level_index==i and h.stage_index==1 and not h.over and h.wave==0,"level %d clear enters its harder second chapter with a fresh encounter" % (i+1))
		await h.get_tree().physics_frame
	note(results,distinct.size()==4 and bosses.size()==4,"campaign has four distinct environments and four distinct bosses")
	h.choose_level(1)
	await h.get_tree().physics_frame
	freeze(h)
	h.boss_fields.cast(1,Vector2(350,640),"eruption",0.8,20,45)
	var field: Dictionary=h.boss_fields.fields[0]
	h.paused=true
	h.boss_fields._physics_process(1.0)
	note(results,field.age==0,"pause freezes boss warnings")
	h.paused=false
	h.hitstop=1
	h.boss_fields._physics_process(1.0)
	note(results,field.age==0,"hitstop freezes boss warnings")
	h.hitstop=0
	h.player.invuln=0.2
	var hp: int=h.player.hp
	h.boss_fields.advance(0.81)
	h.player.invuln=0
	h.boss_fields.advance(0.05)
	note(results,h.player.hp==hp,"a protected boss-field contact cannot hit again when protection expires")
	h.boss_fields.clear()
	h.player.position.y=530
	h.boss_fields.cast(1,Vector2(350,640),"eruption",0.8,20,45)
	h.boss_fields.advance(0.81)
	note(results,h.player.hp==hp,"low ground eruptions can be cleared by the actual jump height")
	h.player.position.y=640
	h.boss_fields.clear()
	for i in 2: h.boss_fields.cast(i,Vector2(350,640),"lightning",0.8,20,45)
	h.player.hp=1
	h.boss_fields.advance(0.81)
	note(results,h.over and h.boss_fields.fields.is_empty(),"fatal boss damage safely clears multiple active fields")
	var current: int=h.level_index
	h.next_level()
	note(results,h.level_index==current,"defeat cannot advance to another level")
	h.start_battle()
	freeze(h)
	h.boss_fields.cast(1,Vector2(350,640),"spore",0.8,20,45)
	h.choose_level(2)
	freeze(h)
	note(results,h.boss_fields.fields.is_empty() and h.projectiles.is_empty() and h.spore_field.fields.is_empty(),"map changes clear every old attack collection")
	h.open_route()
	for dimensions in [Vector2i(1120,630),Vector2i(960,600)]:
		h.get_window().size=dimensions
		await h.get_tree().create_timer(0.2).timeout
		route=h.hud.find_child("LevelRoute",true,false)
		var bounds:=Rect2(route.canvas.position,Vector2(1280,800)*route.canvas.scale)
		note(results,Rect2(Vector2(-1,-1),route.size+Vector2(2,2)).encloses(bounds),"map cards fit the %dx%d window" % [dimensions.x,dimensions.y])
		await hit_route_capture(h,dimensions)
	h.close_route()
	note(results,h.paused and not h.route_open,"closing the map preserves the paused battle")
	note(results,not Profile.save_enabled,"campaign review cannot write the real growth profile")
	var failed:=0
	for line in results:
		print(line)
		if line.begins_with("FAIL"): failed+=1
	var file:=FileAccess.open("res://artifacts/campaign-checks.txt",FileAccess.WRITE)
	file.store_string("\n".join(results)+"\nFailures=%d\n" % failed)
	print("CAMPAIGN_CHECKS ",results.size()," failures=",failed)
	h.get_tree().quit(failed)

static func hit_route_capture(h: Node, dimensions: Vector2i) -> void:
	await h.capture("campaign-route-%dx%d" % [dimensions.x,dimensions.y])
