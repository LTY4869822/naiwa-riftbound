extends Node2D
## Original directed VFX. Geometry follows authoritative phases/attack fields.
const CANVAS=preload("res://foe_vfx/toon_canvas.gd")
const M=preload("res://foe_vfx/toon_motifs.gd")
const PURPLE:=[Color("fff3ff"),Color("cf80ff"),Color("622bc2"),Color("1b1235")]
const PALETTES:={"zheng":[Color("fff2cd"),Color("ffae64"),Color("a0473c"),Color("261921")],"zhuyin":[Color("fff1e6"),Color("fa6e97"),Color("842c73"),Color("1e102f")],"yinglong":[Color("edffff"),Color("6be7ff"),Color("376ae6"),Color("0e203e")],"paoxiao":[Color("fff7c6"),Color("ffb54a"),Color("d54b36"),Color("2a1420")]}
var host: Node
var power: Node
var cv: Node2D
var back: Node2D
var dim: ColorRect
var title: Label
var sub: Label
var clock:=0.0
var last_attack:=-1
var last_state:=""
var attack_age:=1.0
var attack_origin:=Vector2.ZERO
var attack_side:=1

func _ready() -> void:
	dim=ColorRect.new()
	dim.size=Vector2(1280,800)
	dim.mouse_filter=Control.MOUSE_FILTER_IGNORE
	dim.z_index=-11
	add_child(dim)
	back=CANVAS.new()
	back.z_index=-8
	add_child(back)
	cv=CANVAS.new()
	add_child(cv)
	var layer:=CanvasLayer.new()
	layer.layer=3
	add_child(layer)
	title=Label.new()
	title.position=Vector2(350,291)
	title.size=Vector2(580,70)
	title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size",44)
	title.add_theme_color_override("font_color",Color("f6e0ff"))
	title.add_theme_color_override("font_outline_color",Color("251339"))
	title.add_theme_constant_override("outline_size",10)
	title.mouse_filter=Control.MOUSE_FILTER_IGNORE
	layer.add_child(title)
	sub=Label.new()
	sub.position=Vector2(350,355)
	sub.size=Vector2(580,30)
	sub.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size",15)
	sub.add_theme_color_override("font_color",Color("d4b3f5"))
	sub.add_theme_constant_override("outline_size",5)
	sub.mouse_filter=Control.MOUSE_FILTER_IGNORE
	layer.add_child(sub)
	clear()

func clear() -> void:
	if not is_instance_valid(cv): return
	cv.begin(0)
	cv.finish()
	back.begin(0)
	back.finish()
	dim.color=Color.TRANSPARENT
	title.visible=false
	sub.visible=false
	attack_age=1
	last_state=""

func _process(dt: float) -> void:
	if not host.playing():
		clear()
		return
	if host.hitstop<=0:
		clock+=dt
		attack_age+=dt
	cv.begin(clock)
	back.begin(clock)
	title.visible=false
	sub.visible=false
	var dark:=0.0
	var p: Node=host.player
	if power.phase=="ignite":
		var t: float=clampf(power.age/power.INTRO,0,1)
		dark=sin(t*PI)*0.52
		ignite(p.position,t)
		caption("魔 神 觉 醒","玄甲铸身  /  紫霆归一",sin(t*PI))
	elif power.phase=="empowered":
		aura(p.position,p.facing)
		if p.state=="attack" and (last_state!="attack" or last_attack!=p.combo):
			last_attack=p.combo
			attack_age=0
			attack_origin=p.position
			attack_side=p.facing
		if attack_age<0.46:
			var t:=attack_age/0.46
			M.crescent(cv,attack_origin+Vector2(attack_side*110,-140),Vector2(155,115),-PI*0.8 if attack_side>0 else PI*0.2,PI*0.7 if attack_side>0 else PI*1.7,25,PURPLE,sin(t*PI))
			M.speed(cv,attack_origin,attack_side,180,PURPLE,1-t,4)
	elif power.phase=="finisher":
		dark=0.44*smoothstep(0,0.28,power.age)*(1-smoothstep(1.55,power.FINISH,power.age))
		finish_attack()
		caption("紫 霆 · 灭 界","以魔神之爪  /  断诸界之隙",1-smoothstep(0.6,1.1,power.age))
	elif power.phase=="dissolve":
		var t: float=power.age/power.OUTRO
		M.debris(cv,p.position+Vector2(0,-170),t,1.1,PURPLE,44,12)
		M.ring(back,p.position+Vector2(0,-120),Vector2(90,110)*(1+t),PURPLE,(1-t)*0.5,-clock)
	last_state=p.state
	for e in host.enemies:
		if not is_instance_valid(e) or e.dead or not PALETTES.has(e.kind): continue
		var pal: Array=PALETTES[e.kind]
		if e.ult_data.get("apex",false): continue
		if e.state in ["ult_tell","ult_active"]:
			var t: float=e.timer/1.5 if e.state=="ult_tell" else 1.0
			dark=maxf(dark,0.24*minf(t,1))
			M.ring(back,e.position+Vector2(0,-175),Vector2(135,190),pal,0.8,clock*0.4)
			# A sparse charging halo leaves the creature's face and silhouette readable.
			# The explosive eclipse sheet belongs only at the locked attack footprint.
			back.cel_quad("orb",e.position+Vector2(-e.facing*55,-205),Vector2(95,125),clock,0.25+0.2*minf(t,1),pal,0,e.eid)
			if e.state=="ult_tell":
				for i in 5:
					var a: float=i*TAU/5+clock*0.6
					M.bolt(back,e.position+Vector2(cos(a)*190,-175+sin(a)*190),e.position+Vector2(0,-180),2,pal,t*0.65,i)
				if power.phase=="dormant": caption(str(e.ult_data.get("title","荒神降临")),"山海异兽  /  离开锁定的落点",sin(minf(t,1)*PI)*0.85,pal[1])
		elif e.state=="active" and e.attack_data.is_empty():
			var at: Vector2=e.position+Vector2(e.facing*160,-135)
			var turn: float=PI if e.facing<0 else 0
			M.crescent(cv,at,Vector2(165,120),-2.6+turn,0.5+turn,28,pal,1-clampf(e.timer/0.5,0,1))
	for f in host.boss_fields.fields:
		if not str(f.style).begins_with("mythic_"): continue
		field(f)
	dim.color=Color(0.025,0.008,0.065,dark)
	cv.finish()
	back.finish()

func caption(value: String, detail: String, alpha: float, tint: Color=Color("e5b5ff")) -> void:
	title.visible=alpha>0.01
	sub.visible=title.visible
	title.text=value
	sub.text=detail
	title.modulate=Color(tint,alpha)
	sub.modulate.a=alpha

func ignite(p: Vector2, t: float) -> void:
	var force:=smoothstep(0,0.7,t)
	M.ring(back,p+Vector2(0,-135),Vector2(100+50*t,145+55*t),PURPLE,force,clock*1.3)
	for i in 9:
		var a: float=i*TAU/9+clock*0.8
		var r:=lerpf(230,40,smoothstep(0.25,0.88,t))
		var at:=p+Vector2(cos(a)*r,sin(a)*r*0.6-155)
		var stone:=PackedVector2Array([at+Vector2(-9,-10),at+Vector2(5,-14),at+Vector2(14,0),at+Vector2(2,11),at+Vector2(-10,5)])
		cv.polygon(stone,M.tint(PURPLE[3],force*(1-smoothstep(0.8,1,t))))
		cv.stroke(PackedVector2Array([at+Vector2(-6,-5),at,at+Vector2(4,7)]),M.tint(PURPLE[1],force),2)
		if not host.reduce_motion: M.bolt(back,at,p+Vector2(0,-150),2,PURPLE,force*0.7,i)
	for i in 5:
		var x: float=p.x+(i-2)*48
		var y: float=640-(60+260*force)*(0.65+0.35*sin(i+clock*2))
		back.stroke(PackedVector2Array([Vector2(x,640),Vector2(x,y)]),M.tint(PURPLE[1],force*0.45),2+i%2)
	if t>0.76:
		var u: float=(t-0.76)/0.24
		M.ring(cv,p+Vector2(0,-120),Vector2(120+u*240,170+u*140),PURPLE,(1-u)*0.85,-clock)
		burst_at(p+Vector2(0,-150),u)

func burst_at(p: Vector2, t: float) -> void:
	M.burst(cv,p,130,PURPLE,t*0.25,0.65,17)

func aura(p: Vector2, side: int) -> void:
	M.ring(back,p+Vector2(0,-145),Vector2(100,150),PURPLE,0.28,-clock*0.5)
	if not host.reduce_motion:
		for i in 3:
			var a: float=clock*1.2+i*TAU/3
			var point:=p+Vector2(cos(a)*95,-140+sin(a)*95)
			M.bolt(back,point,point+Vector2(side*15,-70),1.6,PURPLE,0.56,i+int(clock*4))

func finish_attack() -> void:
	if is_instance_valid(host.get("rift")): return
	var t: float=power.age
	var p: Vector2=power.origin
	var side: int=power.side
	# Compress the spectral claw to the available forward screen space. The
	# travelling rifts retain their full reach; the impact never jumps behind us.
	var available: float=(1220-p.x if side>0 else p.x-60)+60
	var width:=clampf(available,320,940)
	var at:=p+Vector2(side*width*0.5,-210)
	if t<0.52:
		var u: float=t/0.52
		cv.cel_quad("orb",p+Vector2(side*105,-170),Vector2.ONE*(25+u*110),clock,u,PURPLE)
		M.ring(back,p+Vector2(side*110,-170),Vector2(130,130)*(1-u*0.6),PURPLE,u,clock*2)
	else:
		var u: float=clampf((t-0.52)/(power.FINISH-0.52),0,1)
		cv.flipbook("claw",at,Vector2(width,minf(480,width*0.72)),u*8,1-smoothstep(0.8,1,u),0,side)
		for j in 3:
			var delay: float=[0.52,0.84,1.18][j]
			var elapsed: float=t-delay
			if elapsed<0 or elapsed>0.52: continue
			var fade: float=1-elapsed/0.52
			var start:=p+Vector2(side*50,-280+j*54)
			var end:=p+Vector2(side*920,-100-j*74)
			M.bolt(cv,start,end,12 if j==2 else 7,PURPLE,fade,17+j)
			M.crescent(cv,at,Vector2(width*0.34+elapsed*100,160+elapsed*120),-2.8+j*.3,0.6+j*.3,36,PURPLE,fade)
			M.debris(cv,at+Vector2(0,170),elapsed,0.6,PURPLE,37+j*9,12)
		if t>1.18:
			var elapsed: float=t-1.18
			M.burst(cv,at,width*0.22,PURPLE,elapsed,0.85,90)
			M.ring(back,at,Vector2(width*0.24+elapsed*160,200+elapsed*120),PURPLE,1-smoothstep(0,0.7,elapsed),0)

func field(f: Dictionary) -> void:
	var key: String=str(f.style).trim_prefix("mythic_")
	var pal: Array=PALETTES.get(key,PURPLE)
	var p: Vector2=f.pos
	var remaining: float=f.warning-f.age
	if remaining>1.65: return
	if remaining>0:
		var alpha:=0.55+0.3*(1-clampf(remaining/1.65,0,1))
		cv.stroke(M.arc(p+Vector2(0,-6),Vector2(f.radius,12),0,TAU,64),M.tint(pal[1],alpha),2)
		cv.stroke(M.arc(p+Vector2(0,-6),Vector2(f.radius*0.72,8),0,TAU,48),M.tint(pal[0],alpha*0.5),1)
		for dir in [-1,1]:
			var x: float=p.x+dir*f.radius
			cv.stroke(PackedVector2Array([Vector2(x-dir*18,625),Vector2(x,625),Vector2(x,601)]),M.tint(pal[1],alpha),2.5)
		warning_eye(p,pal,remaining)
	else:
		var t: float=f.age-f.warning
		var fade:=1-smoothstep(0.35,0.8,t)
		var size:=Vector2(f.radius*3.0,410 if key=="yinglong" else 325)
		if key=="zheng":
			cv.flipbook("claw",p+Vector2(0,-125),size,t*10,fade,PI/2,-f.facing,pal)
			M.debris(cv,p,t,0.8,pal,int(p.x),12)
		elif key=="yinglong":
			cv.flipbook("lightning",p,size,t*11,fade,0,1,pal)
			M.bolt(cv,p+Vector2(0,-480),p,8,pal,fade,int(p.x))
		else:
			cv.flipbook("eclipse",p+Vector2(0,-145),Vector2(f.radius*3,360),2+t*7,fade,0,-f.facing,pal)
		M.ring(cv,p+Vector2(0,-10),Vector2(f.radius*(1+t),20+t*25),pal,fade,0)

func warning_eye(p: Vector2, pal: Array, remaining: float) -> void:
	back.ellipse(p+Vector2(0,-6),Vector2(6,6),M.tint(pal[0],0.6+sin(remaining*12)*0.2))
