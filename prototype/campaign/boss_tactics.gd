extends RefCounted
const DURATIONS := {"mycelium_boss":[0.78,0.55],"tempest_boss":[0.72,0.48],"cinder_boss":[0.86,0.78]}

static func windup(e: Node) -> float:
	return float(DURATIONS[e.kind][e.move_id])-(0.10 if e.enraged else 0.0)

static func release(e: Node) -> void:
	var h: Node=e.host
	var point := Vector2(e.target.x,640)
	if e.kind=="mycelium_boss" and e.move_id==0:
		for offset in [-210,0,210]: h.boss_fields.cast(e.eid,point+Vector2(offset,0),"spore",0.88,25,48)
		if e.enraged: h.boss_fields.cast(e.eid,point,"spore",1.38,25,55)
		h.fx("crown_cast",e.position+Vector2(0,-185),e.facing,0.65)
	elif e.kind=="tempest_boss" and e.move_id==0:
		for i in 3: h.boss_fields.cast(e.eid,point+Vector2((i-1)*205,0),"lightning",0.84+i*0.17,25,38)
		if e.enraged: h.boss_fields.cast(e.eid,point+Vector2(e.facing*100,0),"lightning",1.40,25,38)
		h.fx("storm_cast",e.position+Vector2(0,-165),e.facing,0.6)
	elif e.kind=="cinder_boss":
		if e.move_id==0:
			h.boss_fields.cast(e.eid,point,"eruption",0.76,28,70)
			if e.enraged: h.boss_fields.cast(e.eid,point+Vector2(e.facing*195,0),"eruption",1.02,28,65)
		else:
			for offset in [-215,0,215]: h.boss_fields.cast(e.eid,point+Vector2(offset,0),"eruption",0.90,26,55)
		h.fx("forge_slam",e.position+Vector2(e.facing*100,-8),e.facing,0.7)
	else:
		h.fx("wing_cut" if e.kind=="tempest_boss" else "crown_sweep",e.position+Vector2(e.facing*88,-95),e.facing,0.55)
	h.play_sound("heavy",-20,0.55 if e.kind=="cinder_boss" else 0.82)

static func step(e: CharacterBody2D, dt: float) -> void:
	e.velocity.y+=1700*dt
	var dx: float=e.host.player.position.x-e.position.x
	if e.state=="stunned":
		e.velocity.x=move_toward(e.velocity.x,0,1200*dt)
		if e.timer>0.44: e.transition("approach")
	elif e.state=="tell":
		e.velocity.x=0
		if e.timer>=e.windup_duration():
			e.transition("active")
			e.dealt=false
			release(e)
	elif e.state=="active":
		var lunging: bool=e.kind=="tempest_boss" and e.move_id==1
		e.velocity.x=e.facing*(450 if e.enraged else 380) if lunging else 0
		var melee: bool=(e.kind=="mycelium_boss" and e.move_id==1) or lunging or (e.kind=="cinder_boss" and e.move_id==0)
		if melee and not e.dealt:
			var reach: float=130 if lunging else 195
			var box := Rect2(e.position+Vector2(0 if e.facing>0 else -reach,-175),Vector2(reach,175))
			if box.intersects(e.host.player.hurtbox()):
				e.dealt=true
				var accepted: bool=e.host.player.take_hit(e.host.scaled_enemy_damage(29 if e.kind=="cinder_boss" else 26) if e.host.has_method("scaled_enemy_damage") else 29 if e.kind=="cinder_boss" else 26,e.facing)
				if accepted and e.host.playing(): e.host.enemy_fx.contact(e,e.host.player.position+Vector2(0,-110))
		if lunging and int(e.timer/0.06)>int((e.timer-dt)/0.06): e.host.fx("raven_trail",e.position+Vector2(0,-125),e.facing,0.36)
		if e.timer>(0.46 if lunging else 0.30):
			e.transition("recover")
			e.cooldown=1.0 if e.enraged else 1.3
	elif e.state=="recover":
		e.velocity.x=move_toward(e.velocity.x,0,1200*dt)
		if e.timer>(0.65 if e.kind=="cinder_boss" else 0.50): e.transition("approach")
	else:
		e.facing=1 if dx>0 else -1
		var speed: float=185 if e.kind=="tempest_boss" else 118 if e.kind=="cinder_boss" else 145
		e.velocity.x=e.facing*speed if absf(dx)>175 else -e.facing*32 if absf(dx)<135 else 0
		var next_move: int=(e.action_count+1)%2
		var range_limit: float=650 if next_move==0 or (e.kind=="cinder_boss" and next_move==1) else 225
		if e.cooldown<=0 and absf(dx)<range_limit and e.host.attack_budget(e): e.begin_attack()
	e.move_and_slide()
	e.position.x=clampf(e.position.x,100,1180)
	e.host.stage.sync(e,dt)
