extends RefCounted
var results: Array[String]=[]

func check(ok: bool, title: String) -> void:
	results.append(("PASS " if ok else "FAIL ")+title)

func run(h: Node) -> void:
	h.start_battle()
	await h.get_tree().physics_frame
	await h.get_tree().physics_frame
	h.paused=true
	h.player.set_physics_process(false)
	var p: Node=h.player
	var enemy: Node=h.spawn("melee",p.position.x+110)
	enemy.set_physics_process(false)
	var rig: Node=h.stage.actors[p.get_instance_id()]
	var used_strikes: Array[int]=[]
	for side in [1,-1]:
		p.facing=side
		for combo in [0,1]:
			enemy.position=p.position+Vector2(side*110,0)
			enemy.hp=500
			p.velocity=Vector2.ZERO
			p.attack(combo)
			p.elapsed=p.STARTUP[combo]-0.025
			p.step(0.01)
			check(enemy.hp==500,"facing %d punch %d startup cannot hit" % [side,combo+1])
			p.elapsed=p.STARTUP[combo]+0.03
			p.step(0.01)
			var hp_after: int=enemy.hp
			used_strikes.append(rig.current_frame_id)
			check(hp_after<500,"facing %d punch %d hits the forward target" % [side,combo+1])
			p.step(0.01)
			check(enemy.hp==hp_after,"facing %d punch %d cannot repeat damage during its active frames" % [side,combo+1])
	check(used_strikes==[2,6,2,6],"contact frames alternate between independent forward-facing fists")
	p.facing=1
	enemy.position=p.position+Vector2(-130,0)
	enemy.hp=500
	p.attack(1)
	p.elapsed=p.STARTUP[1]+0.03
	p.step(0.01)
	check(enemy.hp==500,"second punch does not accidentally damage the rear target")
	p.state="idle"
	p.buffered=0
	Input.action_press("attack")
	p.step(0.01)
	Input.action_release("attack")
	check(p.state=="idle","held input cannot auto-repeat a combo")
	p.attack(0)
	p.combo_queued=true
	p.elapsed=p.DURATIONS[0]-0.005
	p.step(0.01)
	check(p.state=="attack" and p.combo==1 and p.hit_ids.is_empty(),"buffered second input advances to the other fist with fresh hit tracking")
	p.state="idle"
	p.stamina=100
	p.dash_cd=0
	p.dash()
	var health: int=p.hp
	p.take_hit(18,1)
	check(p.hp==health and p.stamina==68,"dash consumes stamina and grants its invulnerability window")
	p.invuln=0
	p.take_hit(18,1)
	check(p.state=="hurt" and p.hp==health-18,"taking damage interrupts the move")
	var worst_ground:=0.0
	var uniform:=true
	var textures_ok:=true
	rig.position=Vector2(245,640)
	for i in rig.manifest.frames.size():
		rig.show_frame(i)
		if rig.current.grounded:
			var expected_y: float=640+float(rig.current.support_depth)*rig.factor
			worst_ground=maxf(worst_ground,absf(rig.sole_world().y-expected_y))
		uniform=uniform and is_equal_approx(absf(rig.sprite.scale.x),rig.sprite.scale.y)
		var image: Image=rig.sprite.texture.get_image()
		textures_ok=textures_ok and image.get_pixel(0,0).a==0 and image.get_pixel(535,700).a>0.99
	check(worst_ground<=0.4,"support feet meet their projected ground plane (error %.3f px)" % worst_ground)
	check(uniform,"frame transitions keep the same width/height scale ratio")
	check(textures_ok,"alpha extraction removes background while preserving the cream belly")
	check(rig.manifest.clips.run.frames.size()==8,"walk cycle contains eight complete side-facing poses")
	check(rig.manifest.frames.all(func(f): return str(f.texture).begins_with("res://assets/v6/side/")),"no rejected frontal pose is mixed into any animation")
	rig.drive(0.01,"run",0,1,175,640)
	rig.drive(0.01,"idle",0,1,0,640)
	check(not rig.settle_clip.is_empty(),"stopping walks through a settle pose instead of instantly snapping to guard")
	rig.drive(0.01,"attack1",0.4,1,0,640)
	check(rig.settle_clip.is_empty() and rig.current_frame_id==6,"attacking interrupts the visual settle without delaying input")
	rig.drive(0.01,"hurt",0.1,1,0,640)
	check(rig.current_frame_id==16,"damage uses its authored side-facing reaction")
	rig.position=Vector2(245,540)
	rig.drive(0.01,"attack0",0.4,1,0,640)
	check(rig.sole_world().y<541,"airborne punch follows the body's height rather than pinning to ground")
	var boss: Node=h.spawn("boss",900)
	boss.set_physics_process(false)
	boss.begin_attack()
	boss.take_hit(1,1,false)
	check(boss.state=="tell","boss armor resists light stun")
	boss.take_hit(1,1,true)
	check(boss.state=="stunned","charged punch breaks boss stance")
	var bullets: int=h.projectiles.size()
	h.shoot(Vector2(1000,520),Vector2(250,520),-1)
	check(h.projectiles.size()==bullets+1,"ranged attack creates a projectile")
	h.camp()
	h.menu_section="feed"
	h.build_ui()
	await h.get_tree().process_frame
	var virtual_ids: Array[String]=[str(Profile.files[0].id),str(Profile.files[1].id)]
	check(h.hud.get_child(0).get_script().resource_path=="res://v6/menu.gd","combat camp uses the virtual-card menu")
	for id in virtual_ids:
		var menu: Node=h.hud.get_child(0)
		var cards: Array=menu.buttons.filter(func(b): return str(b.name)==id)
		if not cards.is_empty(): cards[0].pressed.emit()
		await h.get_tree().process_frame
		check(id in h.selected,"virtual card selection survives its menu rebuild")
	check(is_instance_valid(h.feed_button) and not h.feed_button.disabled,"selected cards enable the feed button")
	h.feed_button.pressed.emit()
	await h.get_tree().process_frame
	await h.get_tree().process_frame
	check(Profile.level==2 and Profile.xp==20,"virtual-file feeding unlocks level two")
	p.position=Vector2(245,640)
	p.velocity=Vector2.ZERO
	p.state="idle"
	p.focus=100
	p.skill()
	p.step(0.10)
	check(p.state=="skill" and not p.skill_fired and p.focus==40,"ultimate waits for the casting pose and consumes focus")
	var casts: int=h.ultimate.launch_count
	p.step(0.39)
	p.step(0.03)
	check(p.skill_fired and h.ultimate.launch_count==casts+1,"ultimate releases only once after the side-facing contact drawing")
	check(not Profile.save_enabled,"isolated checks cannot write the player's save")
	var failed: int=results.filter(func(line): return line.begins_with("FAIL")).size()
	var file:=FileAccess.open("res://artifacts/v6-checks.txt",FileAccess.WRITE)
	file.store_string("\n".join(results)+"\nFailures=%d\n" % failed)
	print("V6_CHECKS ",results.size()," failures=",failed)
	h.get_tree().quit(failed)
