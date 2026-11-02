extends RefCounted
## Diagnostic play: ordinary damage, ordinary inputs, no invulnerability override.
func press(h: Node, action: String) -> void:
	var event:=InputEventAction.new()
	event.action=action
	event.pressed=true
	h.player._unhandled_input(event)

func run(h: Node) -> void:
	if not h.test_mode or Profile.save_enabled: h.get_tree().quit(1); return
	h.audio_enabled=false
	h.arena.enabled=false
	h.enemy_fx.tracing=true
	Engine.time_scale=4
	Engine.physics_ticks_per_second=240
	var results: Array[Dictionary]=[]
	for index in 4:
		for strategy in ["attack","heavy"]:
			Profile.reset_profile()
			h.choose_level(index)
			h.wait_wave=999
			h.wave=h.CAMPAIGN.wave_count(index)
			h.enemy_fx.trace.clear()
			var foe: Node=h.spawn(h.current_level().boss,390)
			var decision:=0.0
			var start_trace: int=h.enemy_fx.trace.size()
			while not h.over and h.elapsed<50 and is_instance_valid(foe) and not foe.dead:
				await h.get_tree().physics_frame
				Input.action_release("move_left")
				Input.action_release("move_right")
				if h.hitstop>0 or not is_instance_valid(foe): continue
				var p: Node=h.player
				var dx: float=foe.position.x-p.position.x
				if absf(dx)>88: Input.action_press("move_right" if dx>0 else "move_left")
				else: p.facing=1 if dx>0 else -1
				decision-=1.0/60
				if decision<=0 and absf(dx)<123:
					press(h,strategy)
					decision=0.11
			Input.action_release("move_left")
			Input.action_release("move_right")
			var charges:=0
			var releases:=0
			for event in h.enemy_fx.trace.slice(start_trace):
				if event.phase=="charge": charges+=1
				if event.phase=="release": releases+=1
			var dead: bool=not is_instance_valid(foe) or foe.dead
			var result: Dictionary={"map":h.current_level().id,"boss":h.current_level().boss,"starting_level":1,"strategy":"hold pursuit + repeat J" if strategy=="attack" else "hold pursuit + repeat K","boss_defeated":dead,"hero_hp":h.player.hp,"seconds":snappedf(h.elapsed,0.01),"boss_charge_events":charges,"boss_release_events":releases,"no_dash_no_jump_no_ultimate":true,"invulnerability_override":false}
			results.append(result)
			print("DESIGN_PROBE ",JSON.stringify(result))
	Engine.time_scale=1
	Engine.physics_ticks_per_second=60
	var filename: String="design-combat-probe-after-remediation.json" if "--remediation-probe" in OS.get_cmdline_user_args() else "design-combat-probe.json"
	var file:=FileAccess.open("res://artifacts/"+filename,FileAccess.WRITE)
	file.store_string(JSON.stringify({"kind":"narrow diagnostic; not a human playtest or difficulty rating","normal_damage":true,"results":results},"\t"))
	h.get_tree().quit()
