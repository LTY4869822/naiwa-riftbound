extends RefCounted
## Original anime combat animation. Silhouette → coloured body → ivory highlight.
## Timing/positions come from the real attacks; this renderer never creates damage.
const Art = preload("res://third_party/combat_vfx/vfx/magic/magic_art.gd")
const PROFILES = preload("res://foe_vfx/profiles.gd")
const INK:=Color("142439")

static func tint(c: Color, a: float) -> Color:
	return Color(c.r,c.g,c.b,clampf(a,0,1))

static func hash01(k: float) -> float:
	return fposmod(sin(k*12.9898)*43758.5453,1.0)

static func glow(cv: Node, p: Vector2, size: Vector2, c: Color) -> void:
	cv.light.append([Art.glow(),p,size,0.0,c])

static func arc(p: Vector2, radius: Vector2, first: float, last: float, count: int=32) -> PackedVector2Array:
	var points:=PackedVector2Array()
	for i in count:
		var a: float=lerpf(first,last,float(i)/(count-1))
		points.append(p+Vector2(cos(a),sin(a))*radius)
	return points

static func crescent(cv: Node, p: Vector2, r: Vector2, first: float, last: float, width: float, colors: Array, alpha: float) -> void:
	# Two tapered bezels make a solid blade, with a negative-space inner edge.
	for layer in 3:
		var outer:=PackedVector2Array()
		var inner:=PackedVector2Array()
		for i in 38:
			var u: float=float(i)/37
			var a: float=lerpf(first,last,u)
			var w: float=pow(sin(u*PI),0.7)*width
			var edge: Vector2=Vector2(cos(a),sin(a))
			var outside: float=w*0.08 if layer==0 else 0.0 if layer==1 else -w*0.10
			var inside: float=w*(1.05 if layer==0 else 0.90 if layer==1 else 0.40)
			outer.append(p+edge*(r+Vector2.ONE*outside))
			if i>0 and i<37: inner.append(p+edge*(r-Vector2.ONE*inside))
		inner.reverse()
		outer.append_array(inner)
		cv.polygon(outer,tint(colors[3] if layer==0 else colors[1] if layer==1 else colors[0],alpha))

static func speed(cv: Node, p: Vector2, side: int, length: float, colors: Array, alpha: float, seed_id: int) -> void:
	for i in 5:
		var y: float=-50-i*18
		var x: float=9+hash01(seed_id+i)*35
		var l: float=length*(0.40+hash01(seed_id+i+17)*0.6)
		var q:=PackedVector2Array([p+Vector2(-side*x,y),p+Vector2(-side*(l+x),y-5),p+Vector2(-side*(l+x+15),y-7),p+Vector2(-side*x,y-3)])
		cv.polygon(q,tint(colors[3],alpha*0.65))
		cv.stroke(PackedVector2Array([p+Vector2(-side*x,y-2),p+Vector2(-side*(x+l*0.8),y-5)]),tint(colors[0],alpha*0.85),1.5)

static func cloud(cv: Node, p: Vector2, size: Vector2, palette: Array, alpha: float, seed_id: int, spin: float=0.0) -> void:
	var points:=PackedVector2Array()
	for i in 60:
		var a: float=float(i)/60*TAU
		var r: float=0.84+0.10*cos(a*6+seed_id)+0.05*sin(a*9+seed_id*0.3)
		points.append(p+(Vector2(cos(a),sin(a))*size*r).rotated(spin))
	cv.polygon(points,tint(palette[3],alpha))
	for i in points.size(): points[i]=p+(points[i]-p)*0.90+Vector2(0,-2)
	cv.polygon(points,tint(palette[2],alpha))
	# Interior comma strokes suggest rolling ink/smoke, not circles of confetti.
	for i in 2:
		var at: Vector2=p+Vector2((i-0.5)*size.x*0.7,-size.y*0.12)
		cv.stroke(arc(at,Vector2(size.x*0.25,size.y*0.40),-2.8,-0.2,16),tint(palette[1],alpha*0.7),2.8)

static func burst(cv: Node, p: Vector2, size: float, colors: Array, age: float, alpha: float, seed_id: int) -> void:
	var flash: float=clampf(1-age/0.20,0,1)
	if flash<=0: return
	for layer in 3:
		var points:=PackedVector2Array()
		for i in 24:
			var a: float=i*TAU/24+0.25
			var r: float=size*(0.23 if i%2 else (0.68+hash01(seed_id+i)*0.6))*(0.82+age*1.7)
			r*=1.10 if layer==0 else 1.0 if layer==1 else 0.58
			points.append(p+Vector2(cos(a),sin(a))*r)
		cv.polygon(points,tint(colors[3] if layer==0 else colors[1] if layer==1 else colors[0],alpha*flash))
	# Crisp diagonal crossing holds the contact centre for a few frames.
	for sign_id in [-1,1]:
		cv.stroke(PackedVector2Array([p+Vector2(-size*0.65,-size*0.6*sign_id),p+Vector2(size*0.65,size*0.6*sign_id)]),tint(colors[0],flash*alpha),2.0)

static func debris(cv: Node, p: Vector2, age: float, life: float, colors: Array, seed_id: int, count: int=8) -> void:
	var fade: float=pow(clampf(1-age/life,0,1),0.7)
	for i in count:
		var key: float=seed_id+i*37
		var velocity:=Vector2((hash01(key)-0.5)*300,-65-hash01(key+7)*180)
		var at: Vector2=p+velocity*age+Vector2(0,age*age*220)
		var size: float=(3+hash01(key+3)*6)*fade
		var points:=PackedVector2Array()
		for j in 4:
			points.append(at+Vector2.from_angle(j*TAU/4+age*3+key)*Vector2(size*1.5,size*0.7))
		cv.polygon(points,tint(colors[3],fade))
		for j in points.size(): points[j]=at+(points[j]-at)*0.66
		cv.polygon(points,tint(colors[1 if i%3 else 0],fade))

static func ring(cv: Node, p: Vector2, radius: Vector2, palette: Array, alpha: float, spin: float=0) -> void:
	for i in 3:
		var a: float=i*TAU/3+spin
		crescent(cv,p,radius,a,a+1.6,6,palette,alpha)

static func bolt(cv: Node, from: Vector2, to: Vector2, width: float, colors: Array, alpha: float, seed_id: int) -> void:
	var path:=PackedVector2Array([from])
	var delta: Vector2=to-from
	var normal: Vector2=delta.normalized().orthogonal()
	for i in range(1,9):
		var u: float=float(i)/9
		path.append(from+delta*u+normal*(hash01(seed_id+i*7)*2-1)*minf(delta.length()*0.11,28))
	path.append(to)
	cv.stroke(path,tint(colors[3],alpha*0.95),width+7)
	cv.stroke(path,tint(colors[2],alpha),width+3)
	cv.stroke(path,tint(colors[1],alpha),width)
	cv.stroke(path,tint(colors[0],alpha),maxf(1.2,width*0.36))
	for branch_id in 3:
		var start: Vector2=path[3+branch_id*2]
		var end: Vector2=start+delta.normalized()*40+normal*(1 if branch_id%2 else -1)*(25+branch_id*12)
		var arm:=PackedVector2Array([start,start.lerp(end,0.4)+normal*12,end])
		cv.stroke(arm,tint(colors[2],alpha),maxf(1.5,width*0.5))
		cv.stroke(arm,tint(colors[0],alpha),maxf(0.8,width*0.18))

static func root(cv: Node, p: Vector2, side: int, growth: float, palette: Array, alpha: float, seed_id: int) -> void:
	if growth<0.03: return
	for i in 3:
		var base: Vector2=p+Vector2(side*(14+i*40),0)
		var points:=PackedVector2Array()
		var back:=PackedVector2Array()
		var spine:=PackedVector2Array()
		for j in 18:
			var u: float=float(j)/17
			var center: Vector2=base+Vector2(side*(u*(24+i*10)+sin(u*PI)*13)*growth,-(42+i*24)*growth*u)
			var width: float=18*pow(1-u,0.6)
			points.append(center-Vector2(width,0))
			if j<17: back.append(center+Vector2(width,0))
			spine.append(center)
		back.reverse()
		points.append_array(back)
		cv.polygon(points,tint(palette[3],alpha))
		var center: Vector2=base+Vector2(0,-(42+i*24)*growth*0.5)
		for j in points.size(): points[j]=center+(points[j]-center)*0.84
		cv.polygon(points,tint(palette[2],alpha))
		cv.stroke(spine,tint(palette[1],alpha),3)
		debris(cv,base,(1-growth)*0.3,0.6,palette,seed_id+i,3)

static func charge(cv: Node, event: Dictionary, p: Vector2, palette: Array, material: String) -> void:
	var t: float=clampf(event.age/event.life,0,1)
	var boss: bool=event.kind=="boss" or event.kind.ends_with("boss")
	var side: int=event.facing
	var hub: Vector2=p+Vector2(side*(30 if boss else 42),-150 if boss else -105 if material in ["lantern","spore"] else -70)
	var energy: float=(17+25*t)*(1.3 if boss else 1.0)
	glow(cv,hub,Vector2.ONE*energy*3,tint(palette[1],0.12+t*0.20))
	# A converging halo accelerates toward the locked release frame.
	ring(cv,hub,Vector2.ONE*(energy+27*(1-t)),palette,0.3+t*0.55,event.age*3)
	for i in 5:
		var angle: float=i*2.399+event.age
		var from: Vector2=hub+Vector2.from_angle(angle)*(38+46*(1-t))
		var end: Vector2=hub+Vector2.from_angle(angle)*(15+18*(1-t))
		cv.stroke(PackedVector2Array([from,end]),tint(palette[0],t*0.9),1.5+t)
	if material in ["storm","lantern","spore","mycelium"]:
		cv.cel_quad("orb",hub,Vector2.ONE*energy*1.8,0.0 if event.calm else event.age,0.85,palette,0,event.seed)
		if material=="storm":
			for i in 3:
				var end: Vector2=hub+Vector2.from_angle(i*TAU/3+event.age)*(energy+20)
				bolt(cv,hub,end,2.5,palette,t,event.seed+i)
	elif material=="fire":
		for arm in [-1,1]: cv.cel_quad("flame",p+Vector2(arm*80,-115),Vector2(68,95)*(0.5+t*0.5),0.0 if event.calm else event.age,t*0.9,palette,arm*0.3,event.seed+arm)
	elif material=="earth":
		for i in 3: cloud(cv,p+Vector2(-side*(18+i*26),-7),Vector2(17+i*5,8),palette,t*0.5,event.seed+i)
	else:
		crescent(cv,hub,Vector2(energy*0.8,energy*1.2),-2.4+event.age,1.0+event.age,7,palette,t*0.7)

static func release(cv: Node, event: Dictionary, p: Vector2, palette: Array, material: String) -> void:
	var age: float=event.age
	var u: float=clampf(age/event.life,0,1)
	var fade: float=pow(1-u,0.65)
	var side: int=event.facing
	var forward: float=0 if side>0 else PI
	var hub: Vector2=p+Vector2(side*35,-95)
	var punch: float=1-pow(1-clampf(age/0.13,0,1),3)
	match material:
		"leaf":
			cv.flipbook("wind",hub+Vector2(side*10,0),Vector2(155,180),1+u*7,fade,0,side,palette)
			debris(cv,hub+Vector2(side*60,0),age,0.55,palette,event.seed,7)
		"root":
			cv.flipbook("wind",p+Vector2(side*40,-105),Vector2(305,248),1+u*7,fade*0.85,0,side,palette)
			root(cv,p+Vector2(side*20,-1),side,punch,palette,fade,event.seed)
			ring(cv,p+Vector2(side*65,-3),Vector2(70+u*80,13+u*11),palette,fade*0.75)
		"earth":
			speed(cv,p,side,165,palette,fade,event.seed)
			crescent(cv,p+Vector2(side*49,-45),Vector2(58,43),forward-1.25,forward+1.25,13,palette,fade)
			for i in 3: cloud(cv,p+Vector2(-side*(28+i*26+u*14),-8-u*13),Vector2(23+i*4,12+i*3)*(0.6+u),palette,fade*0.75,event.seed+i)
			debris(cv,p+Vector2(-side*35,-7),age,0.65,palette,event.seed,9)
		"lantern":
			burst(cv,p+Vector2(side*32,-125),35,palette,age,0.7,event.seed)
		"spore":
			var origin: Vector2=event.origin+Vector2(side*123,-85)
			var end: Vector2=event.target
			var travel: float=clampf(age/0.34,0,1)
			var at: Vector2=origin.lerp(end,travel)+Vector2(0,-sin(travel*PI)*44)
			cv.cel_quad("orb",at,Vector2.ONE*38,0.0 if event.calm else age,fade,palette,0,event.seed)
			ring(cv,at,Vector2(25,12),palette,fade,age*7)
		"wind":
			speed(cv,p,side,165,palette,fade,event.seed)
			cv.flipbook("wind",hub+Vector2(side*10,-5),Vector2(220,195),1+u*7,fade,0,side)
			debris(cv,hub,age,0.65,palette,event.seed,8)
		"storm":
			if int(event.move)==0:
				var at: Vector2=p+Vector2(0,-185-u*40)
				cv.cel_quad("orb",at,Vector2.ONE*(70+u*25),0.0 if event.calm else age,fade,palette,0,event.seed)
				ring(cv,at,Vector2(70+u*38,27+u*12),palette,fade,age*3)
			else:
				speed(cv,p,side,215,palette,fade,event.seed)
				cv.flipbook("wind",hub,Vector2(280,255),1+u*7,fade,0,side)
				bolt(cv,hub+Vector2(-side*90,-15),hub+Vector2(side*80,0),6,palette,fade,event.seed)
		"mycelium":
			if int(event.move)==1:
				cv.flipbook("wind",p+Vector2(side*45,-102),Vector2(260,230),1+u*7,fade,0,side,palette)
			else:
				for i in 3:
					var at: Vector2=p+Vector2((i-1)*62,-184-u*28)
					cloud(cv,at,Vector2(38,28)*(0.7+u),palette,fade*0.85,event.seed+i)
					ring(cv,at,Vector2(43,20),palette,fade,age*4+i)
		"fire":
			var at: Vector2=p+Vector2(side*(80 if int(event.move)==0 else 12),-100)
			if int(event.move)==0:
				crescent(cv,at,Vector2(130,100),forward-1.6,forward+1.15,29,palette,fade)
				burst(cv,p+Vector2(side*125,-18),65,palette,age,fade,event.seed)
				cv.cel_quad("flame",p+Vector2(side*115,-50),Vector2(125,116),0.0 if event.calm else age,fade,palette,0,event.seed)
			else:
				for arm in [-1,1]: cv.cel_quad("flame",p+Vector2(arm*85,-100),Vector2(85,155),0.0 if event.calm else age,fade,palette,arm*0.4,event.seed+arm)
			debris(cv,p+Vector2(side*70,-10),age,0.68,palette,event.seed,12)

static func ground(cv: Node, event: Dictionary, palette: Array) -> void:
	var p: Vector2=event.origin
	var age: float=event.age
	var u: float=clampf(age/event.life,0,1)
	var fade: float=pow(1-u,0.8)
	var radius: float=event.radius
	if event.style=="roots":
		for side in [-1,1]: root(cv,p+Vector2(-side*25,0),side,1.0-pow(1-clampf(age/0.13,0,1),3),palette,fade,event.seed)
		debris(cv,p,age,0.7,palette,event.seed,12)
		return
	if event.style in ["surge","heat"]:
		ring(cv,p,Vector2(radius,13+u*12),palette,fade,age*2)
		for i in 6:
			var at: Vector2=p+Vector2((float(i)/5-0.5)*radius*1.8,-4)
			if event.style=="surge": bolt(cv,at,at+Vector2(25,-30),2.3,palette,fade,event.seed+i)
			else: cv.flipbook("fire",at,Vector2(65,70),u*8,fade)
		return
	if event.style=="lightning":
		# Painted plasma keeps the broken, irregular silhouette of an anime strike.
		cv.flipbook("lightning",p,Vector2(radius*4.0,430),u*8,fade)
		for i in 5:
			var end: Vector2=p+Vector2.from_angle(i*TAU/5+0.2)*Vector2(radius*1.10,radius*0.23)
			bolt(cv,p,end,2.5,palette,fade,event.seed+i)
		burst(cv,p+Vector2(0,-12),radius*0.8,palette,age,1.0,event.seed)
		ring(cv,p+Vector2(0,-2),Vector2(radius*(0.8+u),11+u*15),palette,fade)
		debris(cv,p,age,0.65,palette,event.seed,9)
	elif event.style=="eruption":
		var height: float=135+radius*0.55
		cv.flipbook("fire",p,Vector2(radius*2.8,height),u*8,clampf(1-(u-0.75)*4,0,1))
		burst(cv,p+Vector2(0,-12),radius*0.7,palette,age,0.85,event.seed)
		ring(cv,p,Vector2(radius*(0.85+u*0.4),11+u*10),palette,fade*0.8)
		for i in 3:
			var a: float=(i-1)*0.9-PI/2
			var end: Vector2=p+Vector2(cos(a),sin(a))*Vector2(radius,18)
			cv.stroke(PackedVector2Array([p,p.lerp(end,0.5)+Vector2(4,0),end]),tint(palette[3],fade),5)
			cv.stroke(PackedVector2Array([p,p.lerp(end,0.5)+Vector2(4,0),end]),tint(palette[1],fade),1.8)
		debris(cv,p,age,0.70,palette,event.seed,12)
	else:
		var king: bool=event.kind=="mycelium_boss"
		var height: float=82 if king else 115
		cv.flipbook("spore",p,Vector2(radius*2.75,height*1.45),u*8,clampf(1-(u-0.65)*2.85,0,1))
		ring(cv,p+Vector2(0,-2),Vector2(radius*(0.9+u*0.4),13+u*10),palette,fade,age*2)
		for i in 5:
			var at: Vector2=p+Vector2((hash01(event.seed+i)*2-1)*radius,-22-i*12-age*32)
			cv.ellipse(at,Vector2.ONE*(2+fade*2),tint(palette[0],fade))
		debris(cv,p+Vector2(0,-25),age,0.7,palette,event.seed,6)

static func paint(cv: Node, event: Dictionary, at: Vector2) -> void:
	var data: Dictionary=PROFILES.profile(event.kind)
	var palette: Array=data.palette
	match event.mode:
		"charge": charge(cv,event,at,palette,data.material)
		"release": release(cv,event,at,palette,data.material)
		"field": ground(cv,event,palette)
		"contact","armor","interrupt":
			burst(cv,at,43 if event.mode=="contact" else 27,palette,event.age,1.0,event.seed)
			debris(cv,at,event.age,event.life,palette,event.seed,8)
			glow(cv,at,Vector2.ONE*65,tint(palette[1],clampf(1-event.age/0.14,0,1)*0.3))
		"enrage":
			var fade: float=1-event.age/event.life
			ring(cv,at,Vector2.ONE*(35+event.age*125),palette,fade,event.age*3)
			debris(cv,at,event.age,event.life,palette,event.seed,15)

static func projectile(cv: Node, bullet: Dictionary, clock: float) -> void:
	var palette: Array=PROFILES.profile("ranged").palette
	var p: Vector2=bullet.pos
	var direction: Vector2=bullet.velocity.normalized()
	# Compact rotating fire seed and two tapered tails follow the actual collider.
	for i in 2:
		var path:=PackedVector2Array()
		for k in 20:
			var u: float=float(k)/19
			path.append(p-direction*(15+u*71)+Vector2(0,(i*2-1)*(4+u*7)+sin(u*6-clock*12)*3*u))
		cv.stroke(path,tint(palette[3],0.85),7-i*2)
		cv.stroke(path,tint(palette[1],0.9),4-i)
	cv.cel_quad("orb",p,Vector2.ONE*38,clock,1.0,palette,0,float(bullet.get("owner",0)))
	glow(cv,p,Vector2.ONE*68,tint(palette[1],0.25))
	crescent(cv,p,Vector2(25,15),clock*7,clock*7+2.8,3,palette,0.85)
