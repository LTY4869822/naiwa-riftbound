extends Node2D
## Effects consume real combat events. This node never applies damage or moves bodies.
const PROFILES = preload("res://foe_vfx/profiles.gd")
const MOTIFS = preload("res://foe_vfx/toon_motifs.gd")
const Canvas = preload("res://foe_vfx/toon_canvas.gd")
const Art = preload("res://third_party/combat_vfx/vfx/magic/magic_art.gd")
const Ribbon = preload("res://third_party/combat_vfx/vfx/trajectory_ribbon.gd")
const Claw = preload("res://third_party/combat_vfx/vfx/claw_rake.gd")
const LIMIT := 48
var host: Node
var canvas: Node2D
var events: Array[Dictionary]=[]
var meshes: Array[Dictionary]=[]
var clock:=0.0
var sequence:=0
var peak_events:=0
var peak_meshes:=0
var trace: Array[Dictionary]=[]
var tracing:=false
var dirty:=false

func _ready() -> void:
	name="EnemyAttackVFX"
	Art.quality="balanced"
	canvas=Canvas.new()
	add_child(canvas)
	# Warm procedural textures once, away from an enemy's contact frame.
	Art.glow()
	Art.smoke()

func record(kind: String, phase: String, owner_id: int) -> void:
	if tracing:
		trace.append({"kind":kind,"phase":phase,"owner":owner_id,"clock":clock})
		if trace.size()>512: trace.pop_front()

func actor(owner_id: int) -> Node:
	for e in host.enemies:
		if is_instance_valid(e) and not e.dead and e.eid==owner_id: return e
	return null

func emit(kind: String, mode: String, point: Vector2, life: float, owner_id: int=0, facing: int=1, extras: Dictionary={}) -> Dictionary:
	if events.size()>=LIMIT: events.pop_front()
	sequence+=1
	var event: Dictionary={"kind":kind,"mode":mode,"origin":point,"age":0.0,"life":life,"owner":owner_id,"facing":facing,"seed":sequence*31,"follow":false,"bound":false,"move":0}
	event.merge(extras,true)
	events.append(event)
	dirty=true
	peak_events=maxi(peak_events,events.size())
	record(kind,mode,owner_id)
	return event

func remove_mesh(index: int) -> void:
	var node: Node=meshes[index].node
	if is_instance_valid(node):
		remove_child(node)
		node.queue_free()
	meshes.remove_at(index)

func cancel(owner_id: int, interrupt_only: bool=false) -> void:
	dirty=true
	for i in range(events.size()-1,-1,-1):
		if events[i].owner==owner_id and (not interrupt_only or events[i].bound): events.remove_at(i)
	for i in range(meshes.size()-1,-1,-1):
		if meshes[i].owner==owner_id and (not interrupt_only or meshes[i].bound): remove_mesh(i)

func clear() -> void:
	events.clear()
	for i in range(meshes.size()-1,-1,-1): remove_mesh(i)
	clock=0
	if is_instance_valid(canvas):
		canvas.begin(clock)
		canvas.finish()
	dirty=false

func actor_transition(e: Node, next: String) -> void:
	if e.boss and not e.attack_data.is_empty():
		if next in ["stunned","recover"]: cancel(e.eid,true)
		return
	if not PROFILES.DATA.has(e.kind): return
	if next=="stunned":
		cancel(e.eid,true)
		if not e.dead and not is_instance_valid(host.get("punch")): emit(e.kind,"interrupt",e.position+Vector2(0,-95),0.28,e.eid,e.facing)
		return
	if next=="recover":
		for item in meshes:
			if item.owner==e.eid:
				item.follow=false
				item.bound=false
		for item in events:
			if item.owner==e.eid and item.bound:
				item.origin=e.position
				item.follow=false
				item.bound=false
		return
	if next=="tell":
		cancel(e.eid,true)
		emit(e.kind,"charge",e.position,e.windup_duration(),e.eid,e.facing,{"follow":true,"bound":true,"move":e.move_id})
	elif next=="active":
		cancel(e.eid,true)
		var lifetime: float=0.68 if e.kind=="raven" else 0.43 if e.kind=="beetle" else 0.46 if e.kind=="tempest_boss" and e.move_id==1 else 0.55
		emit(e.kind,"release",e.position,lifetime,e.eid,e.facing,{"follow":e.kind not in ["shaman","ranged"],"bound":true,"move":e.move_id,"target":Vector2(e.target.x,628)})
		if e.kind in ["melee","raven"]: claw(e,108 if e.kind=="melee" else 86,3)
		elif e.kind=="beetle": ribbon(e,64,21,-0.95,0.95,Vector2(e.facing*37,-51))
		elif e.kind=="boss":
			ribbon(e,183 if e.move_id==0 else 130,34,-1.15,1.10,Vector2(0,-104))
			if e.move_id==0: claw(e,175,2)
		elif e.kind=="mycelium_boss" and e.move_id==1: claw(e,180,3)
		elif e.kind=="tempest_boss" and e.move_id==1:
			ribbon(e,125,24,-1.0,0.95,Vector2(0,-105))
			claw(e,119,3)
		elif e.kind=="cinder_boss" and e.move_id==0: ribbon(e,185,43,-1.45,1.08,Vector2(0,-108))

func add_mesh(e: Node, node: Node2D, offset: Vector2, duration: float) -> void:
	if meshes.size()>=12: remove_mesh(0)
	node.position=e.position+offset
	node.scale.x=e.facing
	node.modulate.a=0.40
	add_child(node)
	# The attack pose enters directly on contact: pre-sample its opening half.
	node.advance(duration*0.48)
	meshes.append({"node":node,"owner":e.eid,"offset":offset,"follow":true,"bound":true,"kind":e.kind})
	peak_meshes=maxi(peak_meshes,meshes.size())
	record(e.kind,"mesh",e.eid)

func ribbon(e: Node, radius: float, width: float, first: float, last: float, offset: Vector2) -> void:
	var node:=Ribbon.new()
	node.configure({"radius":radius,"width":width,"pixel":1.0,"duration":0.20,"tail":0.15,"start_angle":first,"end_angle":last,"hilt_travel":4.0,"swell":3.0,"squash":0.72,"palette":PROFILES.profile(e.kind).palette})
	add_mesh(e,node,offset,0.20)

func claw(e: Node, reach: float, fingers: int) -> void:
	var node:=Claw.new()
	var points:=PackedVector2Array()
	for i in 18:
		var u: float=float(i)/17
		points.append(Vector2(lerpf(12,reach,u),-46+83*u+sin(u*PI)*18))
	node.configure({"path":points,"duration":0.14,"tail":0.17,"fingers":fingers,"spread":13.0 if not e.boss else 18.0,"width":8.0 if not e.boss else 12.0,"jag":0.08,"pixel":1.0,"debris":12.0,"palette":PROFILES.profile(e.kind).palette,"seed_id":e.eid})
	add_mesh(e,node,Vector2(0,-75 if not e.boss else -112),0.14)

func field_burst(field: Dictionary, style: String) -> void:
	if style.begins_with("biome_"): return
	if style.begins_with("ultimate_") or style.begins_with("mythic_") or style.begins_with("repertoire_") or style.begins_with("apex_"): return
	var e: Node=actor(int(field.owner))
	var kind: String=e.kind if e!=null else "tempest_boss" if style in ["lightning","surge"] else "cinder_boss" if style in ["eruption","heat"] else "boss" if style=="roots" else "shaman"
	emit(kind,"field",field.pos,0.72,int(field.owner),1,{"style":style,"radius":float(field.get("radius",66))})

func contact(e: Node, at: Vector2) -> void:
	var box: Rect2=host.player.hurtbox()
	var point:=Vector2(box.end.x-8 if e.position.x>host.player.position.x else box.position.x+8,clampf(at.y,box.position.y+12,box.end.y-12))
	emit(e.kind,"contact",point,0.35,e.eid,e.facing)
	if e.boss and is_instance_valid(host.get("punch")) and host.player.is_on_floor() and (e.move_id in [0,2] or e.state=="ult_active"):
		host.punch.floor_hit(host.player.position,e.facing)

func projectile_contact(bullet: Dictionary) -> void:
	emit("ranged","contact",bullet.pos,0.32,int(bullet.get("owner",0)))

func nearest(point: Vector2) -> Node:
	var result: Node=null
	var distance:=INF
	for e in host.enemies:
		if not is_instance_valid(e) or e.dead: continue
		var score: float=(e.position+Vector2(0,-95)).distance_squared_to(point)
		if score<distance:
			distance=score
			result=e
	return result

func legacy(type: String, point: Vector2, facing: int) -> bool:
	if type not in PROFILES.LEGACY: return false
	if type in ["armor_spark","boss_enrage"]:
		var e: Node=nearest(point)
		if e!=null: emit(e.kind,"armor" if type=="armor_spark" else "enrage",point,0.28 if type=="armor_spark" else 0.75,e.eid,facing)
	return true

func _physics_process(dt: float) -> void:
	if not host.playing() or host.hitstop>0: return
	advance(dt)

func advance(dt: float) -> void:
	clock+=dt
	for i in range(events.size()-1,-1,-1):
		var item: Dictionary=events[i]
		item.age+=dt
		if item.age>=item.life: events.remove_at(i)
	for i in range(meshes.size()-1,-1,-1):
		var item: Dictionary=meshes[i]
		var e: Node=actor(int(item.owner))
		if e==null:
			remove_mesh(i)
			continue
		if item.follow: item.node.position=e.position+item.offset
		item.node.advance(dt)
		if item.node.is_done(): remove_mesh(i)
	paint()
	dirty=false

func paint() -> void:
	visible=host.mode=="battle"
	canvas.begin(0.0 if host.reduce_motion else clock)
	if not visible:
		canvas.finish()
		return
	for event in events:
		event.calm=host.reduce_motion
		var e: Node=actor(int(event.owner)) if event.owner!=0 else null
		var at: Vector2=e.position if event.follow and e!=null else event.origin
		if event.mode=="charge" and e!=null and e.state=="tell": event.facing=e.facing
		MOTIFS.paint(canvas,event,at)
	for bullet in host.projectiles:
		if bullet.get("enemy_vfx",false): MOTIFS.projectile(canvas,bullet,0.0 if host.reduce_motion else clock)
	canvas.finish()

func _process(_dt: float) -> void:
	# Pause keeps the last presented frame. Camp/desktop must hide the whole subtree.
	visible=host.mode=="battle"
	if dirty:
		paint()
		dirty=false
