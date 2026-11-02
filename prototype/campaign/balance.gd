extends RefCounted
const LEVELS = preload("res://campaign/levels.gd")

static func press(h: Node, key: String) -> void:
	var event:=InputEventAction.new()
	event.action=key
	event.pressed=true
	h.player._unhandled_input(event)

static func run(h: Node) -> void:
	if not h.test_mode or Profile.save_enabled:
		h.get_tree().quit(1)
		return
	h.audio_enabled=false
	Engine.time_scale=4
	var results: Array[Dictionary]=[]
	var new_player: bool="--remediation-new-player" in OS.get_cmdline_user_args()
	var forge_check: bool="--reaction-forge-check" in OS.get_cmdline_user_args()
	var maps: Array=[3] if forge_check else range(1 if new_player else 4)
	if new_player: Profile.reset_profile()
	for level in maps:
		Profile.level=1 if new_player else 5 if forge_check else 3
		Profile.xp=0
		h.choose_level(level)
		var decision:=0.0
		while not h.over and h.elapsed<240:
			await h.get_tree().physics_frame
			if h.hitstop>0: continue
			var p: Node=h.player
			Input.action_release("move_left")
			Input.action_release("move_right")
			var target: Node=null
			var score:=99999.0
			for e in h.enemies:
				if not is_instance_valid(e) or e.dead: continue
				var distance: float=absf(e.position.x-p.position.x)-(160 if e.kind in ["shaman","ranged"] else 0)
				if distance<score:
					score=distance
					target=e
			if target==null: continue
			var dx: float=target.position.x-p.position.x
			var escape: int=0
			for field in h.boss_fields.fields:
				if field.age<field.warning+0.15 and absf(field.pos.x-p.position.x)<field.radius+58:
					escape=1 if p.position.x>=field.pos.x else -1
					if p.position.x>1120: escape=-1
					if p.position.x<160: escape=1
			for field in h.spore_field.fields:
				if absf(field.pos.x-p.position.x)<100: escape=1 if p.position.x>=field.pos.x else -1
			if escape!=0:
				p.facing=escape
				Input.action_press("move_right" if escape>0 else "move_left")
				if p.state=="idle": press(h,"dash")
			elif absf(dx)>90: Input.action_press("move_right" if dx>0 else "move_left")
			else: p.facing=1 if dx>0 else -1
			decision-=Engine.time_scale/Engine.physics_ticks_per_second
			if escape==0 and decision<=0:
				# Commit the intended attack direction after an evasive dash.
				p.facing=1 if dx>0 else -1
				if Profile.level>=2 and p.focus>=60 and absf(dx)<290: press(h,"skill")
				elif (target.kind=="beetle" or target.boss and target.state=="tell") and absf(dx)<185 and p.stamina>=28: press(h,"heavy")
				elif target.kind!="beetle" and absf(dx)<116: press(h,"attack")
				decision=0.10
			if h.level_index==3 and absf(p.position.x-640)<105 and p.focus<80: press(h,"interact")
			if target.state=="tell" and target.timer>target.windup_duration()*0.72 and absf(dx)<230: press(h,"dash")
			for bullet in h.projectiles:
				var approaching: bool=(p.position.x-bullet.pos.x)*bullet.velocity.x>0
				if approaching and absf(bullet.pos.x-p.position.x)<165 and p.hurtbox().grow(12).has_point(Vector2(p.position.x,bullet.pos.y)):
					if p.is_on_floor(): press(h,"jump")
					p.facing=-int(signf(bullet.velocity.x))
					press(h,"dash")
		Input.action_release("move_left")
		Input.action_release("move_right")
		var remaining: Array=[]
		for e in h.enemies:
			if is_instance_valid(e) and not e.dead: remaining.append({"kind":e.kind,"hp":e.hp,"position":str(e.position),"state":e.state})
		results.append({"level":level+1,"title":LEVELS.get_level(level).title,"won":h.over and h.won,"seconds":h.elapsed,"hp":h.player.hp,"waves":h.wave,"kills":h.kills,"remaining":remaining})
		print("CAMPAIGN_PLAY ",JSON.stringify(results[-1]))
	var success: bool=results.all(func(result): return result.won)
	var filename: String="reaction-forge-play.json" if forge_check else "campaign-new-player.json" if new_player else "campaign-balance.json"
	var file:=FileAccess.open("res://artifacts/"+filename,FileAccess.WRITE)
	file.store_string(JSON.stringify({"all_won":success,"starting_level_each_map":1 if new_player else 5 if forge_check else 3,"final_level":Profile.level,"training_ledger":Profile.consumed.filter(func(id): return id.begins_with("lesson-")),"invulnerability_override":false,"runs":results},"\t"))
	h.get_tree().quit(0 if success else 1)
