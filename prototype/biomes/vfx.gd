extends RefCounted
const C=preload("res://biomes/content.gd")
const DATA=preload("res://combat/enemy_catalog.gd")

static func theme(kind: String) -> String:
	if kind in ["melee","beetle","ranged","thorn_matriarch"]: return "root"
	if kind in ["crystal_crab","glow_jelly","shaman","mirror_weaver"]: return "eclipse"
	if kind in ["gale_sentinel","raven","storm_manta","bell_colossus"]: return "thunder"
	return "maw"

static func paint(v: Node2D) -> void:
	var h: Node=v.host
	for p in h.projectiles:
		if not p.get("biome_projectile",false): continue
		var key:=theme(str(p.style))
		var color: Color=DATA.DATA.get(p.style,{}).get("color",Color("b8e5a0"))
		var heading: Vector2=p.velocity.normalized()
		for j in 4: v.draw_circle(p.pos-heading*(j+1)*9,4-j*.7,Color(color,.4-j*.08))
		if p.get("ground_wave",false): v.art(v,key,3,p.pos+Vector2(0,23),Vector2(75,60),.9)
		elif p.get("biome_bomb",false):
			v.draw_circle(p.pos,10,Color("55443a"))
			v.draw_arc(p.pos,8,0,TAU,20,Color("ffd492"),3,true)
		else: v.art(v,key,0,p.pos+Vector2(0,20),Vector2(38,45),.95)
	for f in h.boss_fields.fields:
		if not str(f.style).begins_with("biome_"): continue
		var kind: String=str(f.style).trim_prefix("biome_")
		var key:=theme(kind)
		var color: Color=DATA.DATA.get(kind,{}).get("color",Color("d7bbff"))
		var age: float=f.age-f.warning
		if f.has("rect"):
			var r: Rect2=f.rect
			if age<0:
				v.draw_rect(r,Color(color,.10))
				v.draw_line(r.position,Vector2(r.end.x,r.position.y),Color(color,.8),2,true)
				v.draw_line(Vector2(r.position.x,r.end.y),r.end,Color(color,.8),2,true)
				v.draw_string(h.font,r.get_center()+Vector2(-60,-r.size.y*.6),"低束 · 跃起" if kind.ends_with("low") else "高束 · 落地",HORIZONTAL_ALIGNMENT_LEFT,-1,16,color)
			else:
				var alpha: float=1-smoothstep(.18,.7,age)
				for layer in 3:
					var center: Vector2=r.get_center()
					var width: float=[r.size.y*.85,r.size.y*.43,6.0][layer]
					v.draw_line(Vector2(r.position.x,center.y),Vector2(r.end.x,center.y),Color(color if layer<2 else Color.WHITE,alpha*(.3 if layer==0 else .85)),width,true)
				v.art(v,"eclipse",clampi(2+int(age*10),2,7),r.get_center(),Vector2(r.size.x,r.size.y*1.8),alpha*.65)
		elif age<0: v.warning(f,color)
		else: v.art(v,key,clampi(2+int(age*12),2,7),f.pos+Vector2(0,-65) if key=="eclipse" else f.pos,Vector2(f.radius*2.4,165),1-smoothstep(.45,.8,age))
	for e in h.enemies:
		if not is_instance_valid(e) or e.dead: continue
		var color: Color=DATA.DATA.get(e.kind,{}).get("color",Color("b8e5a0"))
		if not e.boss and C.SKILLS.has(e.kind):
			if e.state=="tell":
				var t: float=clampf(e.timer/e.windup_duration(),0,1)
				v.draw_arc(e.position+Vector2(0,-80),28,PI,PI+PI*t,24,Color(color,.8),3,true)
				v.draw_string_outline(h.font,e.position+Vector2(-65,-195),str(e.attack_data.get("name","")),HORIZONTAL_ALIGNMENT_LEFT,-1,14,4,Color("181524"))
				v.draw_string(h.font,e.position+Vector2(-65,-195),str(e.attack_data.get("name","")),HORIZONTAL_ALIGNMENT_LEFT,-1,14,color)
			elif e.state=="active" and not C.caster(e.kind):
				var t: float=fmod(e.timer,.38)
				if t<.20:
					var center: Vector2=e.position+Vector2(e.facing*76,-76)
					var start: float=-1.8 if e.facing>0 else 1.3
					v.draw_arc(center,62,start,start+2.1,24,Color(color,(1-t/.20)*.5),15,true)
					v.draw_arc(center,62,start,start+2.1,24,Color("fff4d4",(1-t/.20)*.85),3,true)
		elif e.kind=="molten_wheel" and e.state in ["ult_tell","ult_active"]:
			var facing: int=int(e.ult_data.get("facing",e.facing))
			if e.state=="ult_tell" or e.timer>1.0 and e.timer<1.70:
				if e.state=="ult_active": facing=-facing
				var end:=Vector2(float(e.ult_data.get("destination",e.target.x)) if e.state=="ult_tell" else float(e.ult_data.origin.x),636)
				v.draw_line(e.position+Vector2(0,-4),end,Color(color,.6),5,true)
				for j in 4:
					var point: Vector2=e.position.lerp(end,(j+1)/5.0)
					v.draw_polyline(PackedVector2Array([point+Vector2(-facing*12,-20),point+Vector2(0,-5),point+Vector2(-facing*12,10)]),color,3,true)
			else: v.art(v,"maw",3,e.position,Vector2(250,270),.6)
