extends RefCounted
const BIOME=preload("res://biomes/boss_skills.gd")
const OLD=preload("res://remediation/boss_ultimates.gd")
const MYTH=preload("res://ascension/mythic_ai.gd")
const STRATEGY=preload("res://rift/tactics.gd")
const NAMES:={
 "thorn_matriarch":["鹿角连挑","森冠奔袭","翡翠飞叶","双翼荆牢"],
 "mirror_weaver":["镜足双刺","丝影突袭","棱镜碎光","织网锁点"],
 "bell_colossus":["铜拳二叩","钟灵横撞","鸣音三击","天钟落印"],
 "molten_wheel":["锁钩双斩","熔轮碾压","炉芯火铳","链轨封锁"],
	"boss":["双枝横扫","古木冲撞","飞叶三连","根牢追击"],
	"mycelium_boss":["菌冠二连掌","孢雾突进","散射孢弹","菌群召来"],
	"tempest_boss":["双翼回旋斩","掠空突袭","三重风羽","雷印追猎"],
	"cinder_boss":["熔锤二连","炉心撞击","陨火投掷","余烬封路"],
	"zheng":["五尾连鞭","裂岳跃扑","碎岩飞刃","崩山追柱"],
	"zhuyin":["双生蛇噬","盘蛇横掠","烛目贯夜","夜蚀召来"],
	"yinglong":["龙翼连斩","破云飞掠","天息贯雷","雷狱追猎"],
	"paoxiao":["裂牙连噬","撼地扑杀","吞焰陨火","踏炉震波"],
}
const EXTRA_NAMES:={"thorn_matriarch":["古根震浪","森隙追猎"],"mirror_weaver":["镜光震环","蛛隙折跃"],"bell_colossus":["钟鸣地潮","云隙降临"],"molten_wheel":["齿轮震浪","熔轨折返"],"boss":["森罗震地","根隙追猎"],"mycelium_boss":["菌海震荡","幽孢折跃"],"tempest_boss":["风压震环","掠影换位"],"cinder_boss":["熔芯震波","炉隙追猎"],"zheng":["五尾撼岳","裂界猎杀"],"zhuyin":["昼夜震荡","烛影换位"],"yinglong":["苍雷震环","龙隙飞掠"],"paoxiao":["焚炉震波","吞隙追猎"]}
const WINDUPS:=[0.70,0.76,0.88,1.02,0.90,1.10]
const LENGTHS:=[0.86,0.84,0.80,0.82,0.75,0.95]

static func begin(e: Node, force: int=-1) -> void:
	var dx: float=absf(e.host.player.position.x-e.position.x)
	var id: int=force
	if id<0:
		id=STRATEGY.choose(e)
	e.action_count+=1
	e.move_id=id
	e.move_history.append(id)
	if e.move_history.size()>32: e.move_history.pop_front()
	var title: String=NAMES.get(e.kind,NAMES.boss)[id] if id<4 else EXTRA_NAMES.get(e.kind,EXTRA_NAMES.boss)[id-4]
	e.attack_data={"name":title,"windup":float(WINDUPS[id])-(0.07*(e.combat_phase-1)),"active":float(LENGTHS[id])+(0.15 if id==0 and e.enraged else 0)}
	e.move_cooldowns[id]=7.0 if id==5 else 5.0 if id==4 else 1.6
	e.locked_windup=e.attack_data.windup
	e.move_hits.clear()
	e.aim_at_player()
	if id==5: e.attack_data["destination"]=clampf(e.target.x+e.facing*245,130,1150)
	e.transition("tell")

static func projectiles(e: Node, ultimate: bool=false) -> void:
	var h: Node=e.host
	for i in (5 if ultimate else 3):
		var spread: float=(i-(2 if ultimate else 1))*0.16
		var origin: Vector2=e.position+Vector2(e.facing*80,-170)
		var aim: Vector2=e.ult_data.get("target",e.target)+Vector2(0,-95) if ultimate else e.target
		var direction: Vector2=(aim-origin).normalized().rotated(spread)
		if direction.x*e.facing<0.35: direction=Vector2(e.facing,clampf(direction.y,-0.6,0.6)).normalized()
		var v: Vector2=direction*430
		var gravity:=0.0
		if e.kind in ["cinder_boss","paoxiao","zheng","mycelium_boss","molten_wheel"]:
			v.y-=140
			gravity=350.0
		h.projectiles.append({"pos":origin,"velocity":v,"life":4.0,"owner":e.eid,"enemy_vfx":false,"style":e.kind,"damage":h.scaled_enemy_damage(18 if not ultimate else 22),"radius":13.0,"gravity":gravity})

static func beam(e: Node, warning: float=0.72) -> void:
	var body: Rect2=e.hurtbox()
	var first: float=body.end.x+24 if e.facing>0 else body.position.x-24
	var end: float=1210 if e.facing>0 else 70
	var width: float=absf(end-first)
	if width<100: return
	var rect:=Rect2(minf(first,end),548,width,68)
	e.host.boss_fields.cast_rect(e.eid,rect,"repertoire_beam_"+e.kind,warning,27,e.facing)

static func release(e: Node) -> void:
	var h: Node=e.host
	e.move_hits.clear()
	e.attack_data["sounds"]=[]
	if e.move_id==2:
		if e.kind in ["zhuyin","yinglong","mirror_weaver"]: beam(e)
		else: projectiles(e)
	elif e.move_id==3:
		for i in 3:
			h.boss_fields.cast(e.eid,Vector2(e.target.x+e.facing*(i-1)*115,640),"repertoire_"+e.kind,0.48+i*0.27,21,63)
		if e.kind in ["mycelium_boss","zhuyin"]:
			var count:=0
			for other in h.enemies:
				if is_instance_valid(other) and not other.dead and not other.boss: count+=1
			if count<1: h.spawn("glow_jelly" if e.kind=="zhuyin" else "shaman",clampf(e.position.x-e.facing*150,150,1130))
	elif e.move_id==4: STRATEGY.shockwave(e)
	elif e.move_id==5: STRATEGY.rift_step(e)
	h.play_sound("heavy",-21,0.75+e.move_id*0.12)

static func step(e: CharacterBody2D, dt: float) -> void:
	var h: Node=e.host
	STRATEGY.observe(e,dt)
	if STRATEGY.phase_step(e,dt): return
	if BIOME.step(e,dt): return
	var mythic: bool=MYTH.TITLES.has(e.kind)
	if e.state in ["ult_tell","ult_active","ult_recover"]:
		if e.state=="ult_active" and not e.ult_data.get("special_done",false):
			e.ult_data.special_done=true
			if e.kind in ["zhuyin","yinglong"]: beam(e,0.85)
			else: projectiles(e,true)
		if mythic: MYTH.step(e,dt)
		else: OLD.step(e,dt)
		return
	if not mythic and OLD.TITLES.has(e.kind) and OLD.step(e,dt): return
	if mythic and e.state=="approach" and e.combat_age>5 and e.hp<e.maximum*0.90 and e.ult_cooldown<=0 and h.attack_budget(e):
		if MYTH.begin_ultimate(e): return
		e.ult_cooldown=1.25
		e.velocity=Vector2(-e.facing*170,e.velocity.y+1700*dt)
		e.move_and_slide()
		e.position.x=clampf(e.position.x,100,1180)
		h.stage.sync(e,dt)
		return
	e.velocity.y+=1700*dt
	var dx: float=h.player.position.x-e.position.x
	if e.state=="stunned":
		e.velocity.x=move_toward(e.velocity.x,0,1500*dt)
		if e.timer>0.34: e.transition("approach")
	elif e.state=="tell":
		e.velocity.x=0
		if e.timer>=e.windup_duration():
			e.transition("active")
			release(e)
	elif e.state=="active":
		e.velocity.x=e.facing*820 if e.move_id==1 and e.timer<0.65 and (e.target.x-e.position.x)*e.facing>110 else 0
		if e.move_id in [0,1]:
			var timings: Array=[0.06,0.34,0.72] if e.move_id==0 and e.enraged else [0.06,0.34] if e.move_id==0 else [0.04]
			for i in timings.size():
				if e.timer>=float(timings[i]) and not i in e.attack_data.get("sounds",[]):
					e.attack_data.sounds.append(i)
					h.play_sound("dash" if e.move_id==1 else "attack",-22,0.70+i*.13)
				if e.timer<float(timings[i]) or e.timer>float(timings[i])+(0.65 if e.move_id==1 else 0.17) or e.move_hits.has(i): continue
				var reach: float=265 if mythic else 210
				var hit:=Rect2(e.position+Vector2(0 if e.facing>0 else -reach,-195),Vector2(reach,195))
				if hit.intersects(h.player.hurtbox()):
					e.move_hits[i]=true
					h.player.take_hit(h.scaled_enemy_damage(22 if e.move_id==0 else 27),e.facing)
		if e.timer>=float(e.attack_data.get("active",0.8)):
			e.cooldown=[.90,.74,.62][e.combat_phase-1]
			e.transition("recover")
	elif e.state=="recover":
		e.velocity.x=move_toward(e.velocity.x,0,2400*dt)
		if e.timer>0.38: e.transition("approach")
	else:
		e.facing=1 if dx>0 else -1
		e.velocity.x=e.facing*(190+e.combat_phase*12) if absf(dx)>300 else -e.facing*90 if absf(dx)<170 else 0
		if e.cooldown<=0 and h.attack_budget(e): begin(e)
	e.move_and_slide()
	e.position.x=clampf(e.position.x,100,1180)
	h.stage.sync(e,dt)
