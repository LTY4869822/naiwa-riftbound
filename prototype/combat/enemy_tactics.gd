extends RefCounted
## Species-specific movement. The shared actor owns health, signals and collision.
static func contact(e: Node, area: Rect2, damage: int) -> void:
	if not e.dealt and area.intersects(e.host.player.hurtbox()):
		e.dealt=true
		var accepted: bool=e.host.player.take_hit(e.host.scaled_enemy_damage(damage) if e.host.has_method("scaled_enemy_damage") else damage,e.facing)
		if accepted and e.host.playing(): e.host.enemy_fx.contact(e,e.host.player.position+Vector2(0,-85))

static func step(e: CharacterBody2D, dt: float) -> void:
	if e.kind=="raven":
		fly(e,dt)
		return
	e.velocity.y+=1700*dt
	var dx: float=e.host.player.position.x-e.position.x
	if e.state=="stunned":
		e.velocity.x=move_toward(e.velocity.x,0,1100*dt)
		if e.timer>e.stun_time: e.transition("approach")
	elif e.state=="tell":
		e.velocity.x=move_toward(e.velocity.x,0,2400*dt)
		if e.timer>=e.windup_duration():
			e.transition("active")
			e.dealt=false
			if e.kind=="shaman":
				e.host.spore_field.cast(e.eid,e.target,e.facing)
				e.host.fx("spore_cast",e.position+Vector2(e.facing*52,-120),e.facing,0.5)
			else: e.host.fx("thorn_launch",e.position+Vector2(e.facing*64,-42),e.facing,0.38)
			e.host.play_sound("attack",-23,0.6 if e.kind=="beetle" else 1.3)
	elif e.state=="active":
		if e.kind=="beetle":
			e.velocity.x=e.facing*440
			contact(e,Rect2(e.position+Vector2(-82,-108),Vector2(164,108)),23)
			if int(e.timer/0.065)>int((e.timer-dt)/0.065): e.host.fx("thorn_dust",e.position+Vector2(-e.facing*38,-8),e.facing,0.38)
			if e.timer>=0.43 or e.is_on_wall():
				e.transition("recover")
				e.cooldown=1.2
		else:
			e.velocity.x=0
			if e.timer>=0.26:
				e.transition("recover")
				e.cooldown=1.7
	elif e.state=="recover":
		e.velocity.x=move_toward(e.velocity.x,0,1300*dt)
		if e.timer>(0.48 if e.kind=="beetle" else 0.40): e.transition("approach")
	else:
		e.facing=1 if dx>0 else -1
		if e.kind=="beetle":
			e.velocity.x=e.facing*150 if absf(dx)>225 else -e.facing*58 if absf(dx)<155 else 0
			if absf(dx)<410 and e.cooldown<=0 and e.host.attack_budget(e): e.begin_attack()
		else:
			e.velocity.x=e.facing*128 if absf(dx)>380 else -e.facing*85 if absf(dx)<195 else 0
			if e.cooldown<=0 and e.host.attack_budget(e): e.begin_attack()
	e.move_and_slide()
	e.position.x=clampf(e.position.x,85,1195)
	e.host.stage.sync(e,dt)

static func fly(e: CharacterBody2D, dt: float) -> void:
	var dx: float=e.host.player.position.x-e.position.x
	if e.state=="stunned":
		e.velocity.y+=900*dt
		e.velocity.x=move_toward(e.velocity.x,0,600*dt)
		if e.timer>e.stun_time: e.transition("approach")
	elif e.state=="tell":
		e.velocity.x=move_toward(e.velocity.x,0,1100*dt)
		e.velocity.y=(535-e.position.y)*7
		if e.timer>=e.windup_duration():
			e.launch=e.position
			e.transition("active")
			e.dealt=false
			e.host.fx("raven_launch",e.position+Vector2(0,-86),e.facing,0.48)
			e.host.play_sound("dash",-23,1.5)
	elif e.state=="active":
		var t: float=clampf(e.timer/0.56,0,1)
		var strike := Vector2(e.target.x,640)
		var end := Vector2(clampf(e.target.x+e.facing*130,85,1195),580)
		var next: Vector2=e.launch.lerp(strike,smoothstep(0,0.58,t)) if t<0.58 else strike.lerp(end,smoothstep(0.58,1,t))
		e.velocity=(next-e.position)/maxf(dt,0.001)
		if t>0.24 and t<0.83: contact(e,Rect2(e.position+Vector2(-50,-130),Vector2(100,120)),19)
		if int(e.timer/0.055)>int((e.timer-dt)/0.055): e.host.fx("raven_trail",e.position+Vector2(0,-90),e.facing,0.34)
		if t>=1:
			e.transition("recover")
			e.cooldown=1.65
	elif e.state=="recover":
		e.velocity.x=move_toward(e.velocity.x,0,850*dt)
		e.velocity.y=(600-e.position.y)*6
		if e.timer>0.42: e.transition("approach")
	else:
		e.facing=1 if dx>0 else -1
		e.velocity.x=e.facing*165 if absf(dx)>215 else -e.facing*72 if absf(dx)<130 else 0
		e.velocity.y=(600-e.position.y)*7
		if e.cooldown<=0 and absf(dx)<480 and e.host.attack_budget(e): e.begin_attack()
	e.move_and_slide()
	e.position.x=clampf(e.position.x,85,1195)
	e.host.stage.sync(e,dt)
