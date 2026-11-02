extends Node2D
## Authoritative phases and three real damage contacts, independent of particles.
const INTRO:=1.05
const DURATION:=14.0
const FINISH:=2.0
const OUTRO:=0.4
var host: Node
var phase:="dormant"
var age:=0.0
var remaining:=0.0
var side:=1
var origin:=Vector2.ZERO
var pulses:=0
var hits: Array=[]
var vfx: Node2D

func _ready() -> void:
	vfx=preload("res://ascension/vfx.gd").new()
	vfx.host=host
	vfx.power=self
	vfx.z_index=12
	host.add_child.call_deferred(vfx)

func empowered() -> bool: return phase=="empowered"
func cinematic() -> bool: return phase in ["ignite","finisher","dissolve"]
func visible_form() -> bool: return phase!="dormant"

func awaken() -> bool:
	var p: Node=host.player
	if not host.playing() or not is_instance_valid(p) or p.dead or phase!="dormant": return false
	if p.state not in ["idle","attack"] or p.state=="attack" and p.elapsed<p.STARTUP[p.combo]+p.ACTIVE[p.combo]: return false
	if not p.is_on_floor():
		host.toast("落地站稳后释放魔神觉醒")
		return false
	if Ascension.energy<100:
		host.toast("击杀敌人积攒魔能 · %d / 100" % Ascension.energy)
		return false
	if not Ascension.consume():
		host.toast("魔能暂未保存，请稍后重试")
		return false
	phase="ignite"
	age=0
	remaining=DURATION
	side=p.facing
	origin=p.position
	p.state="awakening"
	p.elapsed=0
	p.buffered=0
	p.velocity=Vector2.ZERO
	p.invuln=maxf(p.invuln,INTRO+0.15)
	host.play_sound("ultimate_charge",-16,0.66)
	host.toast("魔神觉醒 · 玄甲铸身，紫霆归一")
	host.refresh_hud()
	return true

func finisher() -> bool:
	var p: Node=host.player
	if not empowered() or p.dead or p.state in ["hurt","dash"]: return false
	if p.state=="attack" and p.elapsed<p.STARTUP[p.combo]+p.ACTIVE[p.combo]: return false
	phase="finisher"
	age=0
	remaining=0
	pulses=0
	hits=[]
	side=p.facing
	origin=p.position
	p.state="ascended_finish"
	p.elapsed=0
	p.buffered=0
	p.velocity=Vector2.ZERO
	p.invuln=maxf(p.invuln,FINISH+0.10)
	host.play_sound("ultimate_charge",-13,0.55)
	host.toast("紫霆 · 灭界")
	host.refresh_hud()
	return true

func clear(keep_power: bool=false) -> void:
	if keep_power and phase=="empowered":
		age=0
		return
	phase="dormant"
	age=0
	remaining=0
	pulses=0
	hits=[]
	if is_instance_valid(vfx): vfx.clear()
	if is_instance_valid(host.player) and host.player.state in ["awakening","ascended_finish","reverting"]:
		host.player.state="idle"
		host.player.elapsed=0

func _physics_process(dt: float) -> void:
	if not host.playing() or host.hitstop>0 or not is_instance_valid(host.player) or host.player.dead: return
	advance(dt)

func advance(dt: float) -> void:
	if phase=="dormant": return
	age+=dt
	var p: Node=host.player
	if cinematic():
		p.velocity.x=0
		p.buffered=0
		p.invuln=maxf(p.invuln,0.10)
	if phase=="ignite" and age>=INTRO:
		phase="empowered"
		age=0
		p.state="idle"
		p.elapsed=0
		p.stamina=minf(100,p.stamina+20)
		host.trauma=maxf(host.trauma,0.65)
		host.play_sound("ultimate_launch",-14,0.72)
	elif phase=="empowered":
		remaining=maxf(0,remaining-dt)
		if remaining<=0 and p.state=="idle": dissolve()
	elif phase=="finisher":
		var times:=[0.52,0.84,1.18]
		while pulses<3 and age>=times[pulses]:
			strike(pulses)
			pulses+=1
			if not host.playing(): return
		if age>=FINISH: dissolve()
	elif phase=="dissolve" and age>=OUTRO:
		phase="dormant"
		age=0
		p.state="idle"
		p.elapsed=0
	host.refresh_hud()

func dissolve() -> void:
	phase="dissolve"
	age=0
	host.player.state="reverting"
	host.player.elapsed=0
	host.player.invuln=maxf(host.player.invuln,OUTRO+0.05)

func strike(index: int) -> void:
	var box:=Rect2(origin+Vector2(-35 if side>0 else -975,-465),Vector2(1010,500))
	var accepted:=0
	for e in host.enemies:
		if not is_instance_valid(e) or e.dead or not box.intersects(e.hurtbox()): continue
		var id:=str(index)+":"+str(e.eid)
		if id in hits: continue
		hits.append(id)
		var before: int=e.hp
		e.take_hit(roundi(Profile.damage()*[1.6,2.4,4.0][index]*host.rift.attack_boost()),side,true)
		if before-e.hp<=0: continue
		host.impact(e.hurtbox().get_center(),side,true,false,"ultimate",accepted==0)
		if index==2 and accepted==0 and e.is_on_floor(): host.punch.floor_hit(e.position,side)
		accepted+=1
		host.float_number(e.position+Vector2(0,-235),str(before-e.hp),Color("e7beff"))
	if accepted>0 and index==2:
		host.hitstop=maxf(host.hitstop,.075)
		host.trauma=maxf(host.trauma,.70)
