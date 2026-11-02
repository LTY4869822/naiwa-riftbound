extends RefCounted
const ULTS=preload("res://remediation/boss_ultimates.gd")
var results: Array[String]=[]
func check(ok: bool, title: String) -> void:
	results.append(("PASS " if ok else "FAIL ")+title)
	if not ok: print("REMEDIATION_FAIL ",title)

func freeze(h: Node) -> void:
	h.set_process(false)
	h.player.set_physics_process(false)
	h.boss_fields.set_physics_process(false)
	h.spore_field.set_physics_process(false)
	h.arena.set_physics_process(false)
	h.enemy_fx.set_physics_process(false)
	h.hitstop=0
	h.wait_wave=999

func run(h: Node) -> void:
	if not h.test_mode or Profile.save_enabled or Preferences.enabled_saving: h.get_tree().quit(1); return
	h.audio_enabled=false
	Profile.level=3
	h.start_battle()
	freeze(h)
	var e: Node=h.spawn("boss",600)
	e.set_physics_process(false)
	e.hp=5000
	e.take_hit(1,1,true)
	check(e.state!="stunned","neutral heavy builds poise instead of guaranteeing a break")
	e.transition("tell")
	e.break_guard=0
	e.take_hit(1,1,true)
	check(e.state=="stunned" and e.break_guard>2,"heavy counters a normal windup and installs break protection")
	e.timer=0.21
	for i in 6: e.take_hit(1,1,false)
	check(is_equal_approx(e.timer,0.21),"repeated light hits cannot restart the stun timer")
	e._physics_process(0.15)
	check(e.state=="approach","fixed stun actually ends while pressure continues")
	e.stagger=99
	e.take_hit(1,1,true)
	check(e.state!="stunned","protected recovery cannot immediately be stun locked again")
	e.break_guard=0
	e.take_hit(1,1,false)
	check(e.state=="stunned","light hits still reward filling the poise meter")
	for index in 4:
		h.choose_level(index)
		await h.get_tree().physics_frame
		freeze(h)
		h.wave=h.CAMPAIGN.wave_count(index)
		e=h.spawn(h.current_level().boss,940)
		e.set_physics_process(false)
		h.player.position=Vector2(245,640)
		ULTS.begin(e)
		check(e.state=="ult_tell" and not h.boss_fields.fields.is_empty(),"boss %d has a complete aimed ultimate with real fields" % index)
		check(not e.ult_data.has("safe_x"),"boss %d has no designated safe zone" % index)
		check(h.boss_fields.fields.all(func(f): return not h.boss_fields.area(f).intersects(e.hurtbox())),"boss %d never puts its attack over its own body" % index)
		var locked: Array=[]
		for f in h.boss_fields.fields: locked.append(f.pos)
		var target_at: Vector2=e.ult_data.target
		h.player.position.x=1050
		check(e.ult_data.target==target_at and h.boss_fields.fields.map(func(f): return f.pos)==locked,"boss %d locks its aim after showing the attack warning" % index)
		var hp: int=h.player.hp
		h.boss_fields.advance(3.7)
		check(h.player.hp==hp,"boss %d can be dodged by leaving the actual attack area" % index)
		h.boss_fields.clear()
		e.break_guard=0
		h.player.position=Vector2(245,640)
		ULTS.begin(e)
		e.timer=0.2
		e.take_hit(1,1,true)
		check(e.state=="stunned" and h.boss_fields.fields.is_empty(),"boss %d early heavy counter cancels every pending ultimate hit" % index)
		e.break_guard=0
		h.player.position=Vector2(245,640)
		ULTS.begin(e)
		e.timer=0.8
		e.take_hit(1,1,true)
		check(e.state=="ult_tell","boss %d committed ultimate resists stun but takes damage" % index)
		var field: Dictionary=h.boss_fields.fields[0]
		h.player.position=field.pos
		h.player.invuln=0
		h.player.state="idle"
		hp=h.player.hp
		h.boss_fields.advance(ULTS.TELL-0.01)
		check(h.player.hp==hp,"boss %d anticipation cannot hurt before the advertised release" % index)
		h.boss_fields.advance(0.15)
		check(h.player.hp<hp,"boss %d ultimate contact deals actual damage" % index)
		hp=h.player.hp
		h.boss_fields.advance(0.01)
		check(h.player.hp==hp,"boss %d cannot hit every frame of one impact" % index)
		h.paused=true
		var age: float=h.boss_fields.fields[0].age
		h.boss_fields._physics_process(0.4)
		check(h.boss_fields.fields[0].age==age,"boss %d warnings freeze under pause" % index)
		h.paused=false
		h.hitstop=0.2
		h.boss_fields._physics_process(0.4)
		check(h.boss_fields.fields[0].age==age,"boss %d warnings freeze under hitstop" % index)
		h.hitstop=0
		e.take_hit(99999,1,true)
		check(h.boss_fields.fields.is_empty(),"boss %d death cancels all remaining strikes" % index)
	# Arena and progression contracts.
	for index in 4:
		h.choose_level(index)
		await h.get_tree().physics_frame
		freeze(h)
		check(h.arena.platforms.size()==(1 if index==0 else 2 if index==2 else 0),"map %d has its intended collision layout" % index)
		for p in h.arena.platforms: check(640-p.rect.position.y<104,"map %d ledge is within the authored jump height" % index)
		h.wave=2
		h.arena.enabled=true
		h.arena.cooldown=0
		h.arena._physics_process(0.01)
		check((not h.boss_fields.fields.is_empty())==(index>0),"map %d has the intended arena hazard" % index)
		if index==1:
			h.player.position.x=300
			h.boss_fields.clear()
			h.boss_fields.cast(3,Vector2(300,640),"ultimate_spore",2,23,90)
			h.arena.interact()
			h.arena._physics_process(0.01)
			check(h.boss_fields.fields.is_empty() and h.arena.cleanse>0,"cave lamp actually cleanses ordinary and ultimate spores")
		if index==3:
			h.player.focus=10
			h.player.position.x=640
			h.arena.interact()
			check(h.player.focus==30 and h.arena.lamp_cooldown>0,"forge console grants focus with a real cooldown")
	Profile.reset_profile()
	h.choose_level(0)
	freeze(h)
	var lessons: Array=["combo","heavy","dash"]
	for i in 3:
		h.wave=i+1
		h.training.beat()
		h.training.complete(lessons[i])
		Profile.add_xp(8)
	check(Profile.level>=2,"first three lessons and kills unlock the ultimate before its tutorial")
	var xp: int=Profile.xp
	h.training.complete("dash")
	check(Profile.xp==xp,"lesson reward ledger prevents replay XP duplication")
	check(h.scaled_enemy_health(132,"beetle")==34 and h.scaled_enemy_damage(23)<23,"first journey has an explicit low-damage one-heavy armor lesson")
	h.wave=5
	check(h.scaled_enemy_health(510,"boss")==510 and h.scaled_enemy_damage(32)==32,"tutorial assistance never weakens the guardian climax")
	Profile.level=20
	h.trial_mode=false
	check(h.scaled_enemy_health(510)==510 and h.scaled_enemy_damage(30)==30,"normal adventure preserves growth benefits")
	h.trial_mode=true
	check(h.scaled_enemy_health(510)>510 and h.scaled_enemy_damage(30)>30,"optional trials scale enemy health and damage to growth")
	h.trial_mode=false
	var old_attack: int=Preferences.keys.attack
	var old_heavy: int=Preferences.keys.heavy
	check(Preferences.rebind("attack",old_heavy) and Preferences.keys.heavy==old_attack,"conflicting primary bindings swap without losing an action")
	var reserved:=Preferences.rebind("attack",KEY_ESCAPE)
	check(not reserved and Preferences.keys.attack==old_heavy,"reserved menu keys remain usable")
	var shift:=InputEventKey.new()
	shift.physical_keycode=KEY_SHIFT
	check(InputMap.event_is_action(shift,"dash"),"Shift dash survives a rebind")
	var pad:=InputEventJoypadButton.new()
	pad.button_index=JOY_BUTTON_RIGHT_SHOULDER
	check(InputMap.event_is_action(pad,"skill"),"controller right shoulder is mapped to the actual ultimate action")
	Preferences.reset_bindings()
	Preferences.large_text=true
	check(Preferences.font_size(18)>18,"large text preference reaches actual text sizing")
	Preferences.large_text=false
	h.camp()
	check(h.spectacle.cutin_age>=0.72 and h.ultimate.waves.is_empty(),"return to camp clears all ultimate presentation")
	var failures: Array=results.filter(func(s): return s.begins_with("FAIL"))
	var report: Dictionary={"checks":results.size(),"failures":failures.size(),"results":results}
	var f:=FileAccess.open("res://artifacts/remediation-review.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(report,"\t"))
	print("REMEDIATION_REVIEW ",results.size()," failures=",failures.size())
	h.get_tree().quit(0 if failures.is_empty() else 1)
