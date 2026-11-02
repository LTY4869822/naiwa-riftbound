extends Node2D
const CANVAS=preload("res://foe_vfx/toon_canvas.gd")
const M=preload("res://foe_vfx/toon_motifs.gd")
const PROFILES=preload("res://foe_vfx/profiles.gd")
const MYTH_PALETTES=preload("res://ascension/vfx.gd").PALETTES
var host: Node
var canvas: Node2D
var clock:=0.0
func _ready() -> void:
	canvas=CANVAS.new()
	add_child(canvas)
func colors(kind: String) -> Array:
	if preload("res://biomes/boss_skills.gd").TITLES.has(kind):
		var color: Color=preload("res://combat/enemy_catalog.gd").DATA[kind].color
		return [Color("fff2d6"),color,color.darkened(.38),Color("342844")]
	return MYTH_PALETTES[kind] if MYTH_PALETTES.has(kind) else PROFILES.profile(kind).palette
func _process(dt: float) -> void:
	visible=host.mode=="battle" and not host.over
	if not host.playing() or host.hitstop>0: return
	clock+=dt
	canvas.begin(clock)
	for e in host.enemies:
		if not is_instance_valid(e) or e.dead or not e.boss: continue
		var pal:=colors(e.kind)
		if e.state=="tell" and not e.attack_data.is_empty():
			var t: float=clampf(e.timer/e.windup_duration(),0,1)
			if e.move_id==1:
				var finish:=clampf(e.target.x-e.facing*110,70,1210)
				canvas.stroke(PackedVector2Array([e.position+Vector2(0,-5),Vector2(finish,635)]),M.tint(pal[1],0.55+t*0.4),4)
				for i in 4:
					var x: float=lerpf(e.position.x,finish,(i+1)/5.0)
					canvas.stroke(PackedVector2Array([Vector2(x-e.facing*10,624),Vector2(x,635),Vector2(x-e.facing*10,646)]),M.tint(pal[0],t),2)
			elif e.move_id in [2,3]:
				canvas.cel_quad("orb",e.position+Vector2(e.facing*65,-180),Vector2.ONE*(30+t*65),clock,t,pal)
			else:
				M.crescent(canvas,e.position+Vector2(e.facing*100,-115),Vector2(90,110),-2.2,-0.2,8,pal,t*0.5)
		elif e.state=="active":
			if e.move_id==0:
				for j in (3 if e.enraged else 2):
					var age: float=e.timer-[0.06,0.34,0.72][j]
					if age<0 or age>0.26: continue
					var turn: float=PI if e.facing<0 else 0
					M.crescent(canvas,e.position+Vector2(e.facing*145,-120),Vector2(160,125),-2.8+turn+j*.3,0.5+turn+j*.3,23,pal,1-age/0.26)
			elif e.move_id==1:
				M.speed(canvas,e.position,e.facing,260,pal,0.8,e.eid)
				canvas.flipbook("wind",e.position+Vector2(-e.facing*50,-125),Vector2(310,220),2+fmod(clock*14,3),0.65,0,e.facing,pal)
	for f in host.boss_fields.fields:
		if not str(f.style).begins_with("repertoire_"): continue
		if f.has("rect"): continue # Painted dragon effect and exact lane warning are owned by rift/visual.
		var kind: String=str(f.style).trim_prefix("repertoire_").trim_prefix("beam_")
		var pal:=colors(kind)
		var area: Rect2=host.boss_fields.area(f)
		var age: float=f.age-f.warning
		if f.has("rect"):
			var y: float=area.get_center().y
			if age<0:
				canvas.stroke(PackedVector2Array([Vector2(area.position.x,y),Vector2(area.end.x,y)]),M.tint(pal[1],0.6),2)
				for side in [-1,1]: canvas.stroke(PackedVector2Array([Vector2(area.position.x,y+side*area.size.y*.5),Vector2(area.end.x,y+side*area.size.y*.5)]),M.tint(pal[0],0.4),1)
			else:
				var fade:=1-smoothstep(0.22,0.75,age)
				for layer in 3:
					var points:=PackedVector2Array()
					var radius: float=area.size.y*[0.55,0.35,0.11][layer]
					for direction in [-1,1]:
						for i in 33:
							var u: float=(i if direction<0 else 32-i)/32.0
							var edge: float=pow(maxf(0,sin(u*PI)),0.32)*radius*(0.86+0.14*sin(clock*22+u*40))
							points.append(Vector2(lerpf(area.position.x,area.end.x,u),y+direction*edge))
					canvas.polygon(points,M.tint(pal[2-layer],fade))
				M.bolt(canvas,Vector2(area.position.x,y),Vector2(area.end.x,y),4,pal,fade,int(clock*7))
				var origin:=Vector2(area.position.x if f.facing>0 else area.end.x,y)
				canvas.flipbook("lightning",origin,Vector2(90,area.size.x),2+fmod(clock*13,3),fade*.58,PI/2 if f.facing>0 else -PI/2,1,pal)
				for j in 3:
					var at:=Vector2(lerpf(area.position.x,area.end.x,(j+1)/4.0),y)
					M.crescent(canvas,at,Vector2(22,40),clock*5+j,clock*5+j+4.0,4,pal,fade*.7)
		elif age<0:
			canvas.stroke(M.arc(f.pos+Vector2(0,-6),Vector2(f.radius,12),0,TAU,48),M.tint(pal[1],0.8),2)
			canvas.ellipse(f.pos+Vector2(0,-5),Vector2(4,4),M.tint(pal[0],0.8))
		else:
			var key: String="lightning" if kind in ["tempest_boss","yinglong"] else "fire" if kind in ["cinder_boss","paoxiao"] else "roots" if kind in ["boss","zheng"] else "spore"
			canvas.flipbook(key,f.pos,Vector2(f.radius*2.6,250),age*11,1-smoothstep(0.3,0.8,age),0,1,pal)
	canvas.finish()
	queue_redraw()

func _draw() -> void:
	if not visible: return
	for e in host.enemies:
		if not is_instance_valid(e) or e.dead or e.state!="ult_active": continue
		if e.ult_data.get("apex",false): continue
		var rig: Node=host.stage.actors.get(e.get_instance_id())
		if rig==null or rig.frames.size()<7: continue
		var texture: Texture2D=rig.frames[6].texture
		var height:=450.0
		var size:=texture.get_size()*height/texture.get_height()
		var root: Vector2=e.ult_data.get("target",e.host.player.position)
		root.y=600
		var tint:=colors(e.kind)[1] as Color
		tint.a=0.20*(1-smoothstep(1.0,1.8,e.timer))
		draw_texture_rect(texture,Rect2(root-Vector2(size.x*.5,size.y),size),false,tint)
