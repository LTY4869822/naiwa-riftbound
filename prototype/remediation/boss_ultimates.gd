extends RefCounted
## Aimed attacks lock a player position. There are no designated safe lanes.
const AIM=preload("res://combat/cast_target.gd")
const TITLES:={"boss":"万根森罗","mycelium_boss":"幽光幻海","tempest_boss":"天穹裁决","cinder_boss":"赤焰天陨"}
const HINTS:={"boss":"根浪朝你推进 · 横移或闪避","mycelium_boss":"孢潮锁定你的位置 · 移动避开爆发","tempest_boss":"连锁落雷 · 离开雷印后继续移动","cinder_boss":"陨火瞄准你 · 躲开落点与后续热浪"}
const TELL:=1.5
const ACTIVE:=1.8
const COUNTER_WINDOW:=0.45

static func begin(e: Node) -> bool:
	var h: Node=e.host
	e.facing=AIM.direction(e)
	var largest: float=115 if e.kind=="cinder_boss" else 90 if e.kind in ["boss","mycelium_boss"] else 44
	var projected: float=AIM.project(e,h.player.position.x,largest)
	if is_nan(projected): return false
	h.boss_fields.cancel(e.eid)
	for owner_id in [-100,-101,-102,-103]: h.boss_fields.cancel(owner_id)
	e.ult_count+=1
	e.ult_cooldown=15.0 if not e.enraged else 12.0
	e.target=h.player.position
	e.ult_data={"target":e.target,"origin":e.position,"facing":e.facing,"title":TITLES[e.kind],"hint":HINTS[e.kind]}
	e.ult_data["apex"]=true
	var apex: String="apex_"+e.kind
	e.velocity.x=0
	e.transition("ult_tell")
	var x: float=e.target.x
	if e.kind=="boss":
		var first: float=x-e.facing*170
		for j in 4:
			h.boss_fields.cast(e.eid,Vector2(first+e.facing*j*135,640),apex,TELL+j*0.22,27,90)
	elif e.kind=="mycelium_boss":
		for j in 3:
			for offset in [0,155]: h.boss_fields.cast(e.eid,Vector2(x+e.facing*offset,640),apex,TELL+j*0.48,23,90)
	elif e.kind=="tempest_boss":
		for j in 4:
			var offset: float=[0.0,145.0,-125.0,275.0][j]
			h.boss_fields.cast(e.eid,Vector2(x+e.facing*offset,640),apex,TELL+j*0.23,25,65)
	else:
		h.boss_fields.cast(e.eid,Vector2(x,640),apex,TELL+0.08,32,100)
		for j in 2: h.boss_fields.cast(e.eid,Vector2(x+e.facing*j*165,640),apex,TELL+0.72+j*0.18,20,105)
	if is_instance_valid(h.get("spectacle")): h.spectacle.announce(e.kind,e.eid)
	h.toast(TITLES[e.kind]+" · "+HINTS[e.kind])
	h.play_sound("ultimate_charge",-21,0.72 if e.kind=="cinder_boss" else 1.02)
	h.refresh_hud()
	return true

static func step(e: CharacterBody2D, dt: float) -> bool:
	if e.state not in ["ult_tell","ult_active","ult_recover"]:
		if e.state=="approach" and e.combat_age>=6 and e.hp<=e.maximum*0.82 and e.ult_cooldown<=0 and e.host.attack_budget(e):
			if not begin(e):
				e.ult_cooldown=1.25
				# At an edge, make room first rather than clamping an attack onto self.
				e.velocity=Vector2(-e.facing*165,e.velocity.y+1700*dt)
				e.move_and_slide()
				e.position.x=clampf(e.position.x,65,1215)
				e.host.stage.sync(e,dt)
				return true
		else: return false
	e.velocity.y+=1700*dt
	e.velocity.x=move_toward(e.velocity.x,0,1800*dt)
	if e.state=="ult_tell" and e.timer>=TELL:
		e.transition("ult_active")
		e.host.trauma=maxf(e.host.trauma,0.5)
		e.host.play_sound("ultimate_launch",-18,0.75 if e.kind=="cinder_boss" else 1.0)
	elif e.state=="ult_active" and e.timer>=ACTIVE: e.transition("ult_recover")
	elif e.state=="ult_recover" and e.timer>=0.72:
		e.ult_data.clear()
		e.cooldown=0.55
		e.transition("approach")
	e.move_and_slide()
	e.position.x=clampf(e.position.x,65,1215)
	e.host.stage.sync(e,dt)
	return true
