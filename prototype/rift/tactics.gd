extends RefCounted
## Utility scoring reads sampled visible motion, never player inputs.
const PERSONALITY={"thorn_matriarch":[1.2,1.3,1.1,1.5,1.0,.9],"mirror_weaver":[.9,1.0,1.4,1.3,.9,1.4],"bell_colossus":[1.3,.8,1.0,1.1,1.5,1.0],"molten_wheel":[1.2,1.5,1.0,1.0,1.3,.9],"boss":[1.0,.85,1.10,1.25,.95,.9],"mycelium_boss":[.8,.8,1.25,1.5,1.0,1.1],"tempest_boss":[1.0,1.35,1.0,.9,1.2,1.1],"cinder_boss":[1.2,.9,1.0,1.1,1.35,.85],"zheng":[1.25,1.4,.9,.9,1.2,1.0],"zhuyin":[.8,.8,1.35,1.3,1.0,1.5],"yinglong":[1.0,1.0,1.3,.9,1.1,1.4],"paoxiao":[1.45,1.1,1.0,.9,1.2,.95]}
static func observe(e: Node, dt: float) -> void:
	e.sense_clock-=dt
	for key in e.move_cooldowns: e.move_cooldowns[key]=maxf(0,e.move_cooldowns[key]-dt)
	if e.sense_clock>0: return
	e.sense_clock=.20
	var p: Node=e.host.player
	e.senses={"x":p.position.x,"vx":p.velocity.x,"air":not p.is_on_floor(),"attacking":p.state in ["attack","skill"],"stamina":p.stamina}

static func choose(e: Node) -> int:
	var p: Node=e.host.player
	var distance: float=absf(p.position.x-e.position.x)
	var near:=1-clampf((distance-140)/380,0,1)
	var far:=clampf((distance-220)/520,0,1)
	var floor_target: bool=not bool(e.senses.get("air",false))
	var scores: Array[float]=[.30+near*.9,.25+far*1.0,.35+far*.55,.35+float(absf(float(e.senses.get("vx",0)))>100)*.5,.30+float(floor_target)*.75,.30+float(e.senses.get("attacking",false))*.7]
	var unlocked:=4 if e.combat_phase==1 else 5 if e.combat_phase==2 else 6
	var best:=-1
	var value:=-1.0
	for i in unlocked:
		if float(e.move_cooldowns.get(i,0))>0: continue
		var recent:=0
		for j in range(maxi(0,e.move_history.size()-6),e.move_history.size()):
			if int(e.move_history[j])==i: recent+=1
		var score: float=scores[i]*float(PERSONALITY.get(e.kind,PERSONALITY.boss)[i])/(1+recent*.75)
		if not e.move_history.is_empty() and e.move_history[-1]==i: score*=.08
		if not i in e.move_history: score+=.35
		if i==0 and distance>430: score*=.12
		if i==1 and distance<180: score*=.12
		if i==4 and not floor_target: score*=.12
		if score>value: value=score; best=i
	e.last_scores=scores
	return maxi(0,best)

static func phase_step(e: Node, dt: float) -> bool:
	if e.state=="phase_shift":
		e.velocity.x=0
		if e.timer>=.80:
			e.cooldown=.22
			e.ult_cooldown=minf(e.ult_cooldown,2.0)
			e.transition("approach")
		e.host.stage.sync(e,dt)
		return true
	var next:=3 if e.hp<=e.maximum*.30 else 2 if e.hp<=e.maximum*.65 else 1
	if next<=e.combat_phase or not e.state in ["approach","recover","ult_recover","stunned"]: return false
	e.combat_phase=next
	e.enraged=true
	e.host.boss_fields.cancel(e.eid)
	for i in range(e.host.projectiles.size()-1,-1,-1):
		if int(e.host.projectiles[i].get("owner",0))==e.eid: e.host.projectiles.remove_at(i)
	e.ult_data.clear()
	e.transition("phase_shift")
	e.host.toast(("封印崩解 · 震地波解锁" if next==2 else "裂界暴走 · 跨隙追猎解锁")+" · 注意新前摇")
	e.host.play_sound("ultimate_charge",-19,.65+next*.09)
	e.host.refresh_hud()
	return true

static func shockwave(e: Node) -> void:
	for direction in [-1,1]:
		e.host.projectiles.append({"pos":e.position+Vector2(direction*95,-28),"velocity":Vector2(direction*470,0),"life":2.6,"owner":e.eid,"style":e.kind,"enemy_vfx":false,"damage":e.host.scaled_enemy_damage(24),"radius":13.0,"gravity":0.0,"ground_wave":true})

static func rift_step(e: Node) -> void:
	e.attack_data["departure"]=e.position
	e.position.x=float(e.attack_data.destination)
	e.facing=1 if e.target.x>e.position.x else -1
	e.host.stage.sync(e,.001)
	e.host.boss_fields.cast(e.eid,Vector2(e.target.x,640),"repertoire_"+e.kind,.65,25,76)
	e.host.play_sound("dash",-17,.65)
