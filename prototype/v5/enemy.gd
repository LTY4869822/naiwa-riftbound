extends CharacterBody2D
const BIOME=preload("res://biomes/tactics.gd")
const BIOME_CONTENT=preload("res://biomes/content.gd")
const CATALOG = preload("res://combat/enemy_catalog.gd")
const TACTICS = preload("res://combat/enemy_tactics.gd")
const BOSS_TACTICS = preload("res://campaign/boss_tactics.gd")
const ULT = preload("res://remediation/boss_ultimates.gd")
const POISE = preload("res://remediation/boss_poise.gd")
const MYTHIC = preload("res://ascension/mythic_ai.gd")
const REPERTOIRE=preload("res://loop/boss_brain.gd")
var attack_data: Dictionary={}
var move_history: Array=[]
var move_hits: Dictionary={}
var combat_phase:=1
var sense_clock:=0.0
var senses: Dictionary={}
var move_cooldowns: Dictionary={}
var last_scores: Array[float]=[]
signal changed
var host: Node
var kind: String = "melee"
var eid: int = 0
var hp: int = 90
var maximum: int = 90
var dead: bool = false
var state: String = "approach"
var timer: float = 0
var cooldown: float = 0.8
var facing: int = -1
var flash: float = 0
var stagger: float = 0
var move_id: int = 0
var action_count: int = 0
var dealt: bool = false
var target: Vector2
var launch: Vector2
var enraged: bool=false
var locked_windup: float=0.0
var break_guard:=0.0
var combat_age:=0.0
var ult_cooldown:=8.0
var ult_count:=0
var ult_data: Dictionary={}
var stun_time:=0.16
const TRACK_WINDOW:=0.18
var boss: bool:
	get: return kind=="boss" or bool(CATALOG.DATA.get(kind,{}).get("boss",false))

func _ready() -> void:
	maximum = 510 if boss else 92 if kind=="melee" else 78
	if CATALOG.expanded(kind): maximum=int(CATALOG.DATA[kind].hp)
	if host.has_method("scaled_enemy_health"): maximum=host.scaled_enemy_health(maximum,kind)
	hp = maximum
	cooldown = 0.24+(eid%3)*0.07
	collision_layer = 4
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(74 if boss else 48,205 if boss else 150)
	if CATALOG.expanded(kind): rect.size=CATALOG.DATA[kind].body
	shape.shape = rect
	shape.position.y = -rect.size.y/2
	add_child(shape)

func hurtbox() -> Rect2:
	if CATALOG.expanded(kind):
		var bounds: Rect2=CATALOG.DATA[kind].hurt
		return Rect2(position+bounds.position,bounds.size)
	if kind=="ranged": return Rect2(position+Vector2(-42,-205),Vector2(84,138))
	return Rect2(position+Vector2(-52 if boss else -55,-240 if boss else -139),Vector2(104 if boss else 110,240 if boss else 139))

func windup_duration() -> float:
	if attack_data.has("windup"): return float(attack_data.windup)
	if bool(CATALOG.DATA.get(kind,{}).get("mythic",false)): return locked_windup if locked_windup>0 else MYTHIC.windup(self)
	if boss and kind!="boss": return locked_windup if locked_windup>0 else BOSS_TACTICS.windup(self)
	if CATALOG.expanded(kind): return float(CATALOG.DATA[kind].windup)
	return 0.48 if kind=="ranged" else (0.64 if move_id==0 else 0.46) if boss else 0.34

func visual_state() -> String:
	if state=="stunned": return "hurt"
	if state=="ult_tell": return "attack2"
	if state=="ult_active": return "attack1"
	if state=="tell": return "attack2" if boss and move_id==0 else "attack0"
	if state=="active": return "attack2" if boss and move_id==0 else "attack1"
	if not is_on_floor() and position.y<638: return "air"
	return "run" if absf(velocity.x)>18 else "idle"

func visual_progress() -> float:
	if state=="tell": return 0.08+0.16*timer/windup_duration()
	if state=="active": return 0.30+minf(0.65,timer*3)
	return 0

func _physics_process(dt: float) -> void:
	if not host.playing() or host.hitstop>0 or dead: return
	timer += dt
	cooldown -= dt*(1.0+0.12*int(host.get("stage_index")))
	flash = maxf(0,flash-dt*6)
	combat_age+=dt
	break_guard=maxf(0,break_guard-dt)
	ult_cooldown=maxf(0,ult_cooldown-dt)
	stagger = maxf(0,stagger-dt*(6 if boss else 15))
	if state=="tell" and timer<=TRACK_WINDOW: aim_at_player()
	elif state in ["approach","recover","ult_recover"]:
		var dx_now: float=host.player.position.x-position.x
		if absf(dx_now)>3: facing=1 if dx_now>0 else -1
	if boss:
		REPERTOIRE.step(self,dt)
		return
	if boss and is_instance_valid(host.get("spectacle")) and ULT.step(self,dt): return
	if boss and kind!="boss":
		BOSS_TACTICS.step(self,dt)
		return
	if BIOME_CONTENT.SKILLS.has(kind):
		BIOME.step(self,dt)
		return
	if CATALOG.expanded(kind):
		TACTICS.step(self,dt)
		return
	velocity.y += 1700*dt
	var dx: float = host.player.position.x-position.x
	if state=="stunned":
		velocity.x = move_toward(velocity.x,0,1100*dt)
		if timer>(0.32 if boss else stun_time): transition("approach")
	elif state=="tell":
		velocity.x = move_toward(velocity.x,0,2400*dt)
		if timer>=windup_duration():
			transition("active")
			dealt = false
			if kind=="ranged": host.shoot(position+Vector2(facing*32,-125),target,facing,eid)
			host.play_sound("attack",-24,0.65 if boss else 0.85)
	elif state=="active":
		velocity.x = facing*(420 if boss and move_id==1 else 95 if not boss else 40) if timer<0.22 else 0
		if kind!="ranged" and not dealt:
			var reach: float = 196 if boss and move_id==0 else 141 if boss else 109
			var rect := Rect2(position+Vector2(0 if facing>0 else -reach,-155),Vector2(reach,155))
			if rect.intersects(host.player.hurtbox()):
				var damage: int=32 if boss else 18
				if host.has_method("scaled_enemy_damage"): damage=host.scaled_enemy_damage(damage)
				var accepted: bool=host.player.take_hit(damage,facing)
				if accepted and host.playing(): host.enemy_fx.contact(self,host.player.position+Vector2(0,-97))
				dealt = true
		if timer>0.26:
			transition("recover")
			cooldown = 1.0 if boss else 0.95 if kind=="ranged" else 0.72
	elif state=="recover":
		velocity.x = move_toward(velocity.x,0,1800*dt)
		if timer>(0.45 if boss else 0.25): transition("approach")
	else:
		facing = 1 if dx>0 else -1
		if kind=="ranged":
			velocity.x = -facing*115 if absf(dx)<220 else facing*130 if absf(dx)>440 else 0
			if cooldown<=0 and absf(dx)<820 and host.attack_budget(self): begin_attack()
		else:
			var desired: float = 150 if boss else 114
			var speed: float = 145 if boss else 168
			velocity.x = facing*speed if absf(dx)>desired else -facing*45 if absf(dx)<desired-20 else 0
			if absf(dx)<desired+35 and cooldown<=0 and host.attack_budget(self): begin_attack()
	# Keep the second hunter behind its partner instead of stacking both silhouettes.
	if kind=="melee" and state=="approach":
		for peer in host.enemies:
			if not is_instance_valid(peer) or peer==self or peer.dead or peer.kind!="melee": continue
			var peer_dx: float=peer.position.x-host.player.position.x
			if signf(peer_dx)==signf(position.x-host.player.position.x) and absf(peer_dx)<absf(dx) and absf(peer.position.x-position.x)<145:
				velocity.x=-facing*36
				break
	move_and_slide()
	position.x = clampf(position.x,65,1215)
	host.stage.sync(self,dt)

func transition(next: String) -> void:
	state = next
	timer = 0
	if is_instance_valid(host.get("enemy_fx")): host.enemy_fx.actor_transition(self,next)
	changed.emit()

func begin_attack() -> void:
	if boss:
		REPERTOIRE.begin(self)
		return
	if BIOME_CONTENT.SKILLS.has(kind):
		BIOME.begin(self)
		return
	action_count += 1
	if CATALOG.expanded(kind): velocity.x=0
	move_id = action_count%2
	if bool(CATALOG.DATA.get(kind,{}).get("mythic",false)): locked_windup=MYTHIC.windup(self)
	elif boss and kind!="boss": locked_windup=BOSS_TACTICS.windup(self)
	aim_at_player()
	transition("tell")

func aim_at_player() -> void:
	var dx: float=host.player.position.x-position.x
	if absf(dx)>3: facing=1 if dx>0 else -1
	var lead: float=clampf(host.player.velocity.x*0.10,-35,35) if kind in ["ranged","shaman"] else 0.0
	target=host.player.position+Vector2(lead,-95)

func take_hit(damage: int, direction: int, heavy: bool) -> void:
	if dead: return
	if boss and (state in ["rift_arrive","phase_shift"] or state=="active" and move_id==5 and timer<.24): return
	if kind=="cinder_boss" and state in ["recover","ult_recover"]: damage=roundi(damage*1.3)
	var guarded: bool=kind in ["beetle","crystal_crab"] and not heavy and direction==-facing and state in ["approach","tell","active"]
	if guarded:
		damage=maxi(1,roundi(damage*0.60))
		if not is_instance_valid(host.get("punch")):
			if is_instance_valid(host.get("enemy_fx")): host.enemy_fx.emit(kind,"armor",position+Vector2(facing*66,-64),0.28,eid,facing)
			else: host.fx("armor_spark",position+Vector2(facing*66,-64),facing,0.27)
	hp = maxi(0,hp-damage)
	if boss and kind!="boss" and hp>0 and hp<=maximum/2 and not enraged:
		enraged=true
		host.toast(CATALOG.title(kind)+" · 第二阶段，留意强化预警")
		if is_instance_valid(host.get("enemy_fx")): host.enemy_fx.emit(kind,"enrage",position+Vector2(0,-120),0.75,eid,facing)
		else: host.fx("boss_enrage",position+Vector2(0,-120),facing,0.8)
	flash = 1
	var should_stun: bool
	if boss: should_stun=POISE.hit(self,heavy)
	else:
		stagger+=45 if heavy else 15
		should_stun=(not guarded or stagger>=55) and state!="stunned"
		if should_stun: stun_time=0.30 if heavy else 0.16
	if should_stun:
		transition("stunned")
		velocity = Vector2(direction*(150 if boss else 255),-90 if boss else -115)
		cooldown = maxf(cooldown,0.55 if boss else 0.18)
	if heavy and kind in ["beetle","crystal_crab"]: host.float_number(position+Vector2(0,-130),"破甲",Color("a6e6dc"))
	if hp<=0:
		dead = true
		host.enemy_down(self)
		host.stage.remove_actor(self)
		queue_free()
	changed.emit()
