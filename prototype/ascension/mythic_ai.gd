extends RefCounted
const AIM=preload("res://combat/cast_target.gd")
const TITLES:={"zheng":"五尾 · 裂岳天狱","zhuyin":"烛目 · 昼夜寂灭","yinglong":"应龙 · 九霄雷葬","paoxiao":"吞天 · 焚界饕宴"}
const TELL:=1.65
const ACTIVE:=2.0

static func windup(e: Node) -> float:
	return (0.78 if e.move_id==0 else 0.88)-(0.14 if e.enraged else 0.0)

static func begin_ultimate(e: Node) -> bool:
	var h: Node=e.host
	e.facing=AIM.direction(e)
	var radius: float=68 if e.kind=="yinglong" else 88
	var x: float=AIM.project(e,h.player.position.x,radius)
	if is_nan(x): return false
	h.boss_fields.cancel(e.eid)
	for owner in [-100,-101,-102,-103]: h.boss_fields.cancel(owner)
	e.ult_count+=1
	e.ult_cooldown=11.0 if e.enraged else 14.0
	e.target=h.player.position
	e.ult_data={"title":TITLES[e.kind],"origin":e.position,"target":e.target,"facing":e.facing}
	e.ult_data["apex"]=true
	e.transition("ult_tell")
	var offsets: Array=[-100.0,15.0,130.0,245.0,360.0] if e.kind=="zheng" else [0.0,180.0,-150.0,310.0] if e.kind=="zhuyin" else [0.0,130.0,270.0,-130.0,400.0] if e.kind=="yinglong" else [0.0,185.0,350.0,-150.0]
	for j in offsets.size():
		h.boss_fields.cast(e.eid,Vector2(x+e.facing*float(offsets[j]),640),"apex_"+e.kind,TELL+j*0.30,30 if e.kind!="paoxiao" else 35,radius)
	h.toast(TITLES[e.kind]+" · 预警锁定落点，保持移动")
	h.play_sound("ultimate_charge",-17,0.55 if e.kind in ["zhuyin","paoxiao"] else 0.8)
	return true

static func step(e: CharacterBody2D, dt: float) -> void:
	var h: Node=e.host
	var dx: float=h.player.position.x-e.position.x
	e.velocity.y+=1700*dt
	if e.state=="stunned":
		e.velocity.x=move_toward(e.velocity.x,0,1300*dt)
		if e.timer>0.38: e.transition("approach")
	elif e.state=="ult_tell":
		e.velocity.x=0
		if e.timer>=TELL:
			e.transition("ult_active")
			h.trauma=maxf(h.trauma,0.55)
			h.play_sound("ultimate_launch",-16,0.7)
	elif e.state=="ult_active":
		e.velocity.x=0
		if e.timer>=ACTIVE: e.transition("ult_recover")
	elif e.state=="ult_recover":
		e.velocity.x=0
		if e.timer>=0.85:
			e.ult_data.clear()
			e.cooldown=0.4
			e.transition("approach")
	elif e.state=="tell":
		e.velocity.x=0
		if e.timer>=e.windup_duration():
			e.transition("active")
			e.dealt=false
			if e.move_id==1:
				h.boss_fields.cast(e.eid,e.target,"mythic_"+e.kind,0.35,23,65)
				if e.enraged: h.boss_fields.cast(e.eid,e.target+Vector2(e.facing*150,0),"mythic_"+e.kind,0.65,23,65)
			h.play_sound("heavy",-21,0.72)
	elif e.state=="active":
		e.velocity.x=e.facing*(330 if e.kind=="zheng" else 210) if e.move_id==0 and e.timer<0.23 else 0
		if e.move_id==0 and not e.dealt:
			var box:=Rect2(e.position+Vector2(0 if e.facing>0 else -315,-220),Vector2(315,220))
			if box.intersects(h.player.hurtbox()):
				e.dealt=true
				h.player.take_hit(h.scaled_enemy_damage(30),e.facing)
		if e.timer>0.48:
			e.cooldown=0.78 if e.enraged else 1.1
			e.transition("recover")
	elif e.state=="recover":
		e.velocity.x=move_toward(e.velocity.x,0,2000*dt)
		if e.timer>0.50: e.transition("approach")
	else:
		e.facing=1 if dx>0 else -1
		if e.combat_age>=4 and e.hp<=e.maximum*0.92 and e.ult_cooldown<=0 and h.attack_budget(e):
			if not begin_ultimate(e): e.velocity.x=-e.facing*145
		else:
			e.velocity.x=e.facing*(165 if e.enraged else 140) if absf(dx)>290 else -e.facing*55 if absf(dx)<235 else 0
			if e.cooldown<=0 and absf(dx)<560 and h.attack_budget(e):
				e.begin_attack()
				if e.move_id==1 and absf(dx)<315:
					e.move_id=0
					e.locked_windup=windup(e)
	e.move_and_slide()
	e.position.x=clampf(e.position.x,100,1180)
	h.stage.sync(e,dt)
