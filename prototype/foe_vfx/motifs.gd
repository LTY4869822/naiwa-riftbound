extends RefCounted
## New material choreography on the MIT demo's batched canvas, wind and arc geometry.
const Art = preload("res://third_party/combat_vfx/vfx/magic/magic_art.gd")
const Arcs = preload("res://third_party/combat_vfx/vfx/magic/thunder/arcs.gd")
const Gusts = preload("res://third_party/combat_vfx/vfx/magic/wind/gusts.gd")
const Canvas = preload("res://third_party/combat_vfx/vfx/magic/canvas.gd")
const PROFILES = preload("res://foe_vfx/profiles.gd")

static func tint(color: Color, opacity: float) -> Color:
	return Color(color.r,color.g,color.b,clampf(opacity,0,1))

static func mist(cv: Node, p: Vector2, size: Vector2, color: Color, spin: float=0.0) -> void:
	cv.mist.append([Art.smoke(),p,size,spin,color])

static func glow(cv: Node, p: Vector2, size: Vector2, color: Color) -> void:
	cv.light.append(Arcs.light(p,size,color))

static func wind_data(cv: Node) -> Dictionary:
	return cv.strip("foe_wind",func(): return Gusts.node(7.0,false),func(nodes: Array,out: Dictionary,time: float): Gusts.show(nodes,out,time))

static func arc_data(cv: Node, warm: bool=false) -> Dictionary:
	return cv.strip("foe_heat" if warm else "foe_lightning",func():
		var node := Arcs.node()
		if warm:
			node.material.set_shader_parameter("glow_colour",Color("ffae53"))
			node.material.set_shader_parameter("edge_colour",Color("d25334"))
		return [null,node],func(nodes: Array,out: Dictionary,time: float): Canvas.show_plain(nodes,out,time))

static func ring(cv: Node, p: Vector2, radius: Vector2, power: float, twist: float=0.0) -> void:
	var out: Dictionary=wind_data(cv)
	for sector in 3:
		var points:=PackedVector2Array()
		for i in 16:
			var angle: float=sector*TAU/3+twist+float(i)/15*1.65
			points.append(p+Vector2(cos(angle),sin(angle))*radius)
		Gusts.band(out,points,5.0,power,0.85)

static func fragments(cv: Node, p: Vector2, age: float, life: float, palette: Array, seed: int, count: int, leaves: bool=false, feather: bool=false) -> void:
	var fade: float=clampf(1-age/life,0,1)
	for i in count:
		var key: int=seed+i*37
		var direction:=Vector2(Arcs.hash11(key),-0.3-Arcs.hash01(key+7))
		var at: Vector2=p+direction*age*(80+Arcs.hash01(key+3)*130)+Vector2(0,age*age*160)
		var color: Color=palette[1 if i%3 else 0]
		if leaves or feather:
			cv.mist.append(Gusts.leaf_item(at,(20 if feather else 13)*fade,age*5+key,age*9+key,tint(color,fade*0.8)))
		else:
			var length: float=(8 if i%3 else 14)*fade
			cv.light.append([Art.glow(),at,Vector2(length*1.9,2.5*fade),direction.angle(),tint(color,fade)])
			cv.mist.append([null,at,Vector2(3,3)*fade,age*4+key,tint(palette[2],fade)])

static func charge(cv: Node, event: Dictionary, p: Vector2, palette: Array, material: String) -> void:
	var t: float=clampf(event.age/event.life,0,1)
	var size: float=1.35 if event.kind.ends_with("boss") or event.kind=="boss" else 1.0
	var hub: Vector2=p+Vector2(event.facing*(12 if size>1 else 35),-175 if size>1 else -115 if material in ["spore","lantern"] else -70)
	if material=="earth": hub=p+Vector2(event.facing*68,-47)
	if material=="wind": hub=p+Vector2(event.facing*12,-91)
	glow(cv,hub,Vector2.ONE*(24+44*t)*size,tint(palette[1],0.15+t*0.28))
	for i in (9 if size>1 else 6):
		var angle: float=i*2.399+event.age*2
		var radius: float=(46-31*t)*size
		var at: Vector2=hub+Vector2.from_angle(angle)*radius
		if material in ["leaf","root","wind","storm"]:
			cv.mist.append(Gusts.leaf_item(at,12*size*t,angle+event.age*3,angle,tint(palette[1],t*0.7)))
		else: glow(cv,at,Vector2.ONE*(4+3*t),tint(palette[0],t*0.75))
	if material in ["spore","mycelium"]:
		ring(cv,hub,Vector2.ONE*(18+t*21)*size,t*0.55,event.age*1.7)
		for i in 3:
			var at:=hub+Vector2(sin(event.age*3+i*2)*17,-i*8)
			mist(cv,at,Vector2.ONE*(20+22*t)*size,tint(palette[2],t*0.12),i+event.age)
	elif material=="storm":
		var out: Dictionary=arc_data(cv)
		for i in 3:
			var end:=hub+Vector2.from_angle(i*TAU/3+event.age*0.9)*(24+t*28)
			Arcs.strip(out,Arcs.bolt(hub,end,event.seed+i,0.2,7),1.5,t*0.6,0.35)
	elif material in ["earth","fire"]:
		mist(cv,p+Vector2(-event.facing*28,-7),Vector2(60,20)*(0.7+t),tint(palette[2],t*0.15),event.age)

static func release(cv: Node, event: Dictionary, p: Vector2, palette: Array, material: String) -> void:
	var t: float=event.age
	var fade: float=clampf(1-t/event.life,0,1)
	var side: int=event.facing
	var origin: Vector2=event.origin
	if material in ["leaf","root"]:
		fragments(cv,p+Vector2(side*55,-72 if material=="leaf" else -95),t,0.65,palette,event.seed,10 if material=="root" else 6,true)
		if material=="root":
			ring(cv,Vector2(p.x+side*85,638),Vector2(30+t*200,7+t*29),fade*0.5,t*0.7)
			mist(cv,p+Vector2(side*60,-10),Vector2(74,34)*(0.6+t),tint(palette[2],fade*0.22),t)
	elif material=="earth":
		var nose: Vector2=p+Vector2(side*74,-44)
		glow(cv,nose,Vector2(56,28),tint(palette[1],0.35))
		var out: Dictionary=wind_data(cv)
		Gusts.crescent(out,nose,Vector2(side,0),34,7,0.75)
		for line in 3:
			var points:=PackedVector2Array()
			for i in 14:
				var u: float=float(i)/13
				points.append(p+Vector2(-side*(u*105+16),-35-line*14+sin(u*PI)*8))
			Gusts.band(out,points,4+line*1.2,fade*0.32,0.6)
		for i in 5:
			var age: float=fmod(t+i*0.065,0.38)
			var at: Vector2=p+Vector2(-side*(25+age*110),-age*30-4)
			mist(cv,at,Vector2(30+age*60,16+age*30),tint(palette[2],(1-age/0.38)*0.25),i)
		fragments(cv,p+Vector2(-side*35,-8),t,0.7,palette,event.seed,9)
	elif material in ["spore","lantern"]:
		var from: Vector2=origin+Vector2(side*123,-85) if material=="spore" else origin+Vector2(side*32,-125)
		if material=="lantern":
			glow(cv,from,Vector2.ONE*(40+t*45),tint(palette[1],fade*0.45))
			return
		var end: Vector2=event.target
		var u: float=clampf(t/0.34,0,1)
		var at: Vector2=from.lerp(end,u)+Vector2(0,-sin(u*PI)*44)
		glow(cv,at,Vector2.ONE*(21+sin(u*PI)*11),tint(palette[1],fade*0.8))
		glow(cv,at,Vector2.ONE*7,tint(palette[0],fade))
		for i in 7:
			var back: float=clampf(u-float(i)*0.035,0,1)
			var trail: Vector2=from.lerp(end,back)+Vector2(0,-sin(back*PI)*44)
			glow(cv,trail,Vector2.ONE*(7-i*0.65),tint(palette[1],fade*(0.6-i*0.06)))
	elif material in ["wind","storm"]:
		var out: Dictionary=wind_data(cv)
		var length: float=95 if material=="wind" else 150
		for sector in 3:
			var points:=PackedVector2Array()
			for i in 18:
				var u: float=float(i)/17
				points.append(p+Vector2(-side*(u*length+10),-85-sector*16+sin(u*PI)*(15+sector*4)))
			Gusts.band(out,points,9+sector*3,fade*0.6,0.95)
		fragments(cv,p+Vector2(0,-95),t,0.8,palette,event.seed,9,false,true)
		if material=="storm" and int(event.move)==0:
			ring(cv,p+Vector2(0,-165),Vector2(65,35)*(0.6+t),fade*0.6,t*2)
	elif material=="mycelium":
		ring(cv,p+Vector2(0,-190),Vector2(85,33)*(0.8+t),fade*0.5,t)
		for i in 8:
			var at:=p+Vector2(sin(i*2.399+t)*70,-165-cos(i*2.399+t)*40)
			mist(cv,at,Vector2.ONE*(26+t*30),tint(palette[1],fade*0.17),i+t)
			glow(cv,at,Vector2.ONE*13,tint(palette[2],fade*0.55))
	elif material=="fire":
		var at:=p+Vector2(side*40,-132)
		glow(cv,at,Vector2(115,94),tint(palette[1],fade*0.24))
		fragments(cv,p+Vector2(side*120,-10),t,0.7,palette,event.seed,18)
		ring(cv,p+Vector2(side*110,-1),Vector2(25+t*200,7+t*24),fade*0.65,t*0.4)

static func ground(cv: Node, event: Dictionary, palette: Array) -> void:
	var t: float=event.age
	var p: Vector2=event.origin
	var radius: float=float(event.radius)
	var fade: float=clampf(1-t/event.life,0,1)
	var style: String=event.style
	if style=="lightning":
		var out: Dictionary=arc_data(cv)
		var key: int=event.seed+(0 if event.get("calm",false) else floori(t*24)*13)
		var main: PackedVector2Array=Arcs.bolt(p+Vector2(-17,-410),p,key,0.17,8)
		Arcs.strip(out,main,10*pow(fade,1.4),fade*0.95,0.24)
		for branch in Arcs.branches(main,event.seed,4,50,0.25): Arcs.strip(out,branch[0],3*fade,fade*0.7,0.35)
		for i in 6:
			var end:=p+Vector2.from_angle(i*TAU/6+0.2)*Vector2(radius*1.3,radius*0.23)
			Arcs.strip(out,Arcs.bolt(p,end,event.seed+i,0.3,7),2*fade,fade*0.8,0.25)
		glow(cv,p+Vector2(0,-8),Vector2(85,35)*fade,tint(palette[0],fade*0.5))
		fragments(cv,p,t,0.65,palette,event.seed,15)
	elif style=="eruption":
		var hot: float=clampf(1-t/0.42,0,1)
		var height: float=84*smoothstep(0,0.07,t)*hot
		for i in 4:
			var quad: MeshInstance2D=cv.quad("flame_tongue")
			var width: float=radius*(0.72+0.12*sin(i*1.7))
			Art.place(quad,Rect2(p+Vector2((i-1.5)*radius*0.38-width/2,-height),Vector2(width,maxf(1,height))))
			quad.material.set_shader_parameter("time",t)
			quad.material.set_shader_parameter("seed",float(event.seed+i))
			quad.material.set_shader_parameter("intensity",hot*0.8)
		var cracks: Dictionary=arc_data(cv,true)
		for i in 7:
			var end:=p+Vector2.from_angle(i*TAU/7)*Vector2(radius*1.05,radius*0.22)
			Arcs.strip(cracks,Arcs.bolt(p,end,event.seed+i,0.4,6),2.4*fade,fade*0.8,0.35)
		mist(cv,p+Vector2(0,-25-t*75),Vector2(60+t*70,42+t*55),Color(0.16,0.19,0.22,fade*0.30),t)
		fragments(cv,p,t,0.75,palette,event.seed,16)
	else:
		var king: bool=event.kind=="mycelium_boss"
		var height: float=84 if king else 132
		mist(cv,p+Vector2(0,-height/2),Vector2(radius*1.8,height),tint(palette[2],fade*0.18),0.2)
		for i in (10 if king else 7):
			var angle: float=i*2.399+event.seed
			var at:=p+Vector2(sin(angle)*radius*(0.4+t),-13-t*(46+float(i%3)*24))
			mist(cv,at,Vector2.ONE*(22+t*40),tint(palette[2],fade*0.24),angle+t)
			glow(cv,at,Vector2.ONE*(9+fade*6),tint(palette[1],fade*0.7))
			ring(cv,at,Vector2.ONE*(5+fade*5),fade*0.2,angle)
		ring(cv,p,Vector2(radius*(0.8+t),9+t*14),fade*0.6,t)
		fragments(cv,p+Vector2(0,-16),t,0.75,palette,event.seed,10,true)

static func paint(cv: Node, event: Dictionary, at: Vector2) -> void:
	var data: Dictionary=PROFILES.profile(event.kind)
	var palette: Array=data.palette
	match event.mode:
		"charge": charge(cv,event,at,palette,data.material)
		"release": release(cv,event,at,palette,data.material)
		"field": ground(cv,event,palette)
		"contact", "armor", "interrupt":
			fragments(cv,at,event.age,event.life,palette,event.seed,10 if event.mode=="contact" else 6,data.material in ["leaf","root","spore","mycelium"],data.material in ["wind","storm"])
			glow(cv,at,Vector2.ONE*(35+event.age*45),tint(palette[0],clampf(1-event.age/0.15,0,1)*0.35))
		"enrage":
			ring(cv,at,Vector2.ONE*(35+event.age*110),1-event.age/event.life,event.age*1.4)
			fragments(cv,at,event.age,event.life,palette,event.seed,16)

static func projectile(cv: Node, bullet: Dictionary, clock: float) -> void:
	var p: Vector2=bullet.pos
	var direction: Vector2=bullet.velocity.normalized()
	var color:=Color("ffcf85")
	glow(cv,p,Vector2.ONE*39,Color(color,0.42))
	glow(cv,p,Vector2.ONE*13,Color("fff2c5"))
	for i in 8:
		var q: Vector2=p-direction*(9+i*5)+Vector2(0,sin(clock*13+i*0.7)*3)
		glow(cv,q,Vector2(10-i*0.6,4),Color(color,(1-float(i)/8)*0.55))
	for side in [-1,1]:
		var wing: Vector2=p+Vector2(0,side*(6+absf(sin(clock*18))*5))
		cv.mist.append(Gusts.leaf_item(wing,13,side*0.5,clock*13,Color(color,0.75)))
