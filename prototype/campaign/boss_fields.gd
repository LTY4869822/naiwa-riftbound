extends Node
const AIM=preload("res://combat/cast_target.gd")
## Boss area attacks: locked targets, fixed warning, one hit, owner cancellation.
var host: Node
var fields: Array[Dictionary]=[]
const ACTIVE := 0.18

func cast(owner_id: int, point: Vector2, style: String, warning: float, damage: int, radius: float) -> void:
	if fields.size()>=16: return
	var facing:=0
	for e in host.enemies:
		if not is_instance_valid(e) or e.dead or e.eid!=owner_id or not e.boss: continue
		var x: float=AIM.project(e,point.x,radius)
		if is_nan(x): return
		point.x=x
		facing=e.facing
		break
	for f in fields:
		if f.owner==owner_id and f.style==style and absf(f.warning-warning)<0.01 and absf(f.pos.x-point.x)<radius*0.7: return
	var adjusted: int=host.scaled_enemy_damage(damage) if host.has_method("scaled_enemy_damage") else damage
	fields.append({"owner":owner_id,"pos":Vector2(clampf(point.x,75,1205),640),"style":style,"warning":warning,"damage":adjusted,"radius":radius,"age":0.0,"fired":false,"dealt":false,"facing":facing})

func clear() -> void:
	fields.clear()

func cast_rect(owner: int, rect: Rect2, style: String, warning: float, damage: int, facing: int) -> void:
	if fields.size()>=16 or rect.size.x<=0: return
	fields.append({"owner":owner,"pos":Vector2(rect.get_center().x,640),"style":style,"warning":warning,"damage":host.scaled_enemy_damage(damage),"radius":rect.size.x*0.5,"age":0.0,"fired":false,"dealt":false,"facing":facing,"rect":rect})

func cancel(owner_id: int) -> void:
	for i in range(fields.size()-1,-1,-1):
		if fields[i].owner==owner_id: fields.remove_at(i)

func area(field: Dictionary) -> Rect2:
	if field.has("rect"): return field.rect
	var height: float=410 if field.style in ["lightning","ultimate_thunder"] else 245 if field.style=="ultimate_roots" else 220 if field.style=="ultimate_meteor" else 180 if field.style=="ultimate_spore" else 48 if field.style=="surge" else 70 if field.style=="roots" else 84
	if str(field.style).begins_with("mythic_"): height=410 if field.style=="mythic_yinglong" else 300
	if str(field.style).begins_with("repertoire_"): height=215
	if str(field.style).begins_with("apex_"): height=410 if str(field.style).ends_with("yinglong") or str(field.style).ends_with("tempest_boss") else 300
	return Rect2(field.pos+Vector2(-field.radius,-height),Vector2(field.radius*2,height))

func _physics_process(dt: float) -> void:
	if not host.playing() or host.hitstop>0: return
	advance(dt)

func advance(dt: float) -> void:
	for i in range(fields.size()-1,-1,-1):
		var field: Dictionary=fields[i]
		var previous: float=field.age
		field.age+=dt
		if field.age>=field.warning and not field.fired:
			field.fired=true
			if is_instance_valid(host.get("punch")): host.punch.terrain(field)
			host.enemy_fx.field_burst(field,field.style)
			if not str(field.style).begins_with("apex_") and not str(field.style).begins_with("biome_"): host.fx("boss_"+field.style,field.pos,1,0.65)
			host.play_sound("heavy",-22,1.6 if field.style=="lightning" else 0.65)
		# Crossing the active interval also resolves a single contact after a long tick.
		if field.age>=field.warning and previous<field.warning+ACTIVE and not field.dealt:
			if is_instance_valid(host.player) and area(field).intersects(host.player.hurtbox()):
				field.dealt=true
				var direction: int=1 if host.player.position.x>=field.pos.x else -1
				host.player.take_hit(int(field.damage),direction)
				if not host.playing(): return
		if field.age>field.warning+0.8: fields.remove_at(i)
