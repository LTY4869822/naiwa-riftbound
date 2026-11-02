extends RefCounted
const C=preload("res://biomes/content.gd")

static func begin(e: Node) -> void:
	var tier:=C.skill_tier(e.host)
	e.move_id=e.action_count%(tier+1)
	e.action_count+=1
	e.move_history.append(e.move_id)
	if e.move_history.size()>24: e.move_history.pop_front()
	e.attack_data={"name":C.SKILLS[e.kind][e.move_id],"windup":maxf(.36,.58-tier*.05)+(.17 if e.move_id==2 else 0),"variant":e.move_id}
	e.move_hits.clear()
	e.aim_at_player()
	e.velocity.x=0
	e.transition("tell")

static func bolt(e: Node, spread: float=0, speed: float=390, bomb: bool=false) -> void:
	var origin: Vector2=e.position+Vector2(e.facing*44,-100)
	var direction: Vector2=(e.target-origin).normalized().rotated(spread)
	if direction.x*e.facing<.25: direction=Vector2(e.facing,.05).normalized().rotated(spread)
	e.host.projectiles.append({"pos":origin,"velocity":direction*speed+Vector2(0,-260 if bomb else 0),"life":3.8,"owner":e.eid,"style":e.kind,"biome_projectile":true,"biome_bomb":bomb,"enemy_vfx":false,"radius":10.0,"gravity":650.0 if bomb else 0.0,"damage":e.host.scaled_enemy_damage(16 if not bomb else 21)})

static func field(e: Node, x: float, warning: float=.75, radius: float=56) -> void:
	e.host.boss_fields.cast(e.eid,Vector2(x,640),"biome_"+e.kind,warning,18,radius)

static func release(e: Node) -> void:
	var v: int=e.move_id
	if e.kind in ["ranged","glow_jelly","gear_gunner"]:
		if e.kind=="gear_gunner" and v==1: bolt(e,0,330,true)
		elif v==2 and e.kind!="gear_gunner": field(e,e.target.x,.85,64)
		else:
			for i in (3 if v>0 else 1): bolt(e,(i-1)*.20 if v>0 else 0)
	elif e.kind=="shaman":
		if v==2:
			for i in 3: bolt(e,(i-1)*.25,340)
		else:
			field(e,e.target.x,.85,58)
			if v==1: field(e,clampf(e.target.x+e.facing*145,90,1190),1.18,58)
	elif e.kind=="gale_sentinel" and v==1: bolt(e,0,470)
	elif e.kind=="storm_manta" and v>0:
		if v==1:
			for i in 3: bolt(e,(i-1)*.23,410)
		else:
			field(e,e.target.x,.85,54)
			field(e,e.target.x-e.facing*140,1.12,54)
	elif e.kind=="raven" and v==2:
		for i in 3: bolt(e,(i-1)*.23,375)
	elif e.kind in ["crystal_crab","beetle","cinder_skitter"] and v==2:
		for side in [-1,1]:
			e.host.projectiles.append({"pos":e.position+Vector2(side*75,-24),"velocity":Vector2(side*350,0),"life":3.0,"owner":e.eid,"style":e.kind,"biome_projectile":true,"ground_wave":true,"damage":e.host.scaled_enemy_damage(19),"radius":12.0})
	elif e.kind=="cinder_skitter" and v==1:
		for i in 3: bolt(e,(i-1)*.27,350)
	elif e.kind=="slag_hound" and v==2: field(e,e.target.x,.65,65)
	e.launch=e.position
	e.host.play_sound("attack",-25,.8+v*.2)

static func contact(e: Node, id: int, reach: float, damage: int) -> void:
	if e.move_hits.has(id): return
	var r:=Rect2(e.position+Vector2(0 if e.facing>0 else -reach,-140),Vector2(reach,140))
	if r.intersects(e.host.player.hurtbox()):
		e.move_hits[id]=true
		e.host.player.take_hit(e.host.scaled_enemy_damage(damage),e.facing)

static func step(e: CharacterBody2D, dt: float) -> void:
	var tier:=C.skill_tier(e.host)
	var flying:=C.flyer(e.kind)
	var caster:=C.caster(e.kind)
	var dx: float=e.host.player.position.x-e.position.x
	if flying: e.velocity.y=(600-e.position.y)*6
	else: e.velocity.y+=1700*dt
	if e.state=="stunned":
		e.velocity.x=move_toward(e.velocity.x,0,1300*dt)
		if e.timer>e.stun_time: e.transition("approach")
	elif e.state=="tell":
		e.velocity.x=0
		if e.timer>=e.windup_duration():
			e.transition("active")
			release(e)
	elif e.state=="active":
		var v: int=e.move_id
		e.velocity.x=0
		var rush: bool=(e.kind in ["beetle","slag_hound","cinder_skitter"] and not (e.kind=="cinder_skitter" and v==1)) or e.kind=="crystal_crab" and v==1 or e.kind in ["raven","storm_manta"] and v==0 or e.kind=="raven" and v==1
		if rush:
			e.velocity.x=e.facing*(390+tier*25) if e.timer<.44 else 0
			if e.kind=="slag_hound" and e.timer<.42: e.velocity.y=-cos(e.timer/.42*PI)*210
			if flying: e.velocity.y=(630-e.position.y)*6 if e.timer<.24 else (585-e.position.y)*5
			contact(e,0,115,21)
			if v==1 and e.kind in ["beetle","slag_hound"] and e.timer>.50:
				if not e.attack_data.has("return"):
					e.attack_data["return"]=true
					e.facing=1 if dx>0 else -1
				e.velocity.x=e.facing*370 if e.timer<.80 else 0
				contact(e,1,115,18)
		elif not caster or e.kind=="storm_manta" and v==0:
			var timings: Array=[.05,.40] if v==2 and e.kind in ["melee","gale_sentinel"] else [.07]
			if e.kind=="melee" and v==1 and e.timer<.28: e.velocity.x=e.facing*280
			for i in timings.size():
				if e.timer>=float(timings[i]) and e.timer<float(timings[i])+.17: contact(e,i,176 if e.kind=="gale_sentinel" else 132,18)
		if e.timer>(.90 if v==1 and e.kind in ["beetle","slag_hound"] else .68 if v==2 else .52):
			if e.kind=="raven" and v==1: bolt(e,0,370)
			e.cooldown=1.10-tier*.15
			e.transition("recover")
	elif e.state=="recover":
		e.velocity.x=move_toward(e.velocity.x,0,1800*dt)
		if e.timer>.27: e.transition("approach")
	else:
		e.facing=1 if dx>0 else -1
		var distance: float=350 if caster else 190 if e.kind in ["beetle","slag_hound","raven"] else 143
		var speed: float=(130 if caster else 175)+tier*14
		e.velocity.x=e.facing*speed if absf(dx)>distance else -e.facing*65 if absf(dx)<distance-55 else 0
		# Separate same-side teammates so later waves remain readable.
		for other in e.host.enemies:
			if not is_instance_valid(other) or other==e or other.dead: continue
			var od: float=other.position.x-e.host.player.position.x
			if signf(od)==signf(e.position.x-e.host.player.position.x) and absf(od)<absf(dx) and absf(other.position.x-e.position.x)<95:
				e.velocity.x=-e.facing*45
				break
		if e.cooldown<=0 and absf(dx)<(780 if caster else distance+120) and e.host.attack_budget(e): begin(e)
	e.move_and_slide()
	e.position.x=clampf(e.position.x,80,1200)
	e.host.stage.sync(e,dt)
