extends Node2D
## Separate anticipation, fast core, broken trail and debris; no screen-wide flashes.
var host: Node

func _ready() -> void:
	var expansion := preload("res://combat/enemy_vfx.gd").new()
	expansion.host=host
	add_child(expansion)
	var guardians := preload("res://campaign/vfx.gd").new()
	guardians.host=host
	add_child(guardians)
const CREAM := Color("fff4cf")
const GOLD := Color("ffbe50")
const TEAL := Color("75e1d2")
const INK := Color("163b40")

func tint(c: Color, a: float) -> Color:
	return Color(c.r,c.g,c.b,clampf(a,0,1))

func shard(p: Vector2, axis: Vector2, length: float, width: float, c: Color) -> void:
	if c.a<0.015 or width<0.18 or length<0.3: return
	var side := Vector2(-axis.y,axis.x)
	# Local coordinates retain precision when a fading shard becomes sub-pixel.
	draw_set_transform(p)
	draw_colored_polygon(PackedVector2Array([axis*length,side*width,-axis*length*0.42,-side*width]),c)
	draw_set_transform(Vector2.ZERO)

func ribbon(p: Vector2, radius: Vector2, begin: float, sweep: float, width: float, facing: int, c: Color) -> void:
	if c.a<0.015 or width<0.18: return
	var points := PackedVector2Array()
	for inner in [false,true]:
		for j in range(1 if inner else 0,32 if inner else 33):
			var u: float = float(32-j if inner else j)/32
			var angle: float = begin+sweep*u
			var thickness: float = pow(maxf(0,sin(u*PI)),0.7)*width
			var rr := radius - Vector2.ONE*thickness if inner else radius
			points.append(Vector2(cos(angle)*rr.x*facing,sin(angle)*rr.y))
	draw_set_transform(p)
	draw_colored_polygon(points,c)
	draw_set_transform(Vector2.ZERO)

func wake(from: Vector2, to: Vector2, bend: float, width: float, color: Color) -> void:
	if color.a<0.015 or width<0.18: return
	var points := PackedVector2Array()
	var end := to-from
	var center := end*0.5+Vector2(0,bend)
	for side in [1,-1]:
		for i in range(19):
			var u: float=float(i if side==1 else 18-i)/18
			var q: Vector2=center*2*(1-u)*u+end*u*u
			var axis: Vector2=(center*(1-u)+(end-center)*u).normalized()
			var normal := Vector2(-axis.y,axis.x)
			points.append(q+normal*side*width*maxf(0.025,sin(u*PI)))
	draw_set_transform(from)
	draw_colored_polygon(points,color)
	draw_set_transform(Vector2.ZERO)

func attack_effect(p: Node) -> void:
	var facing: int=p.facing
	var hand: Vector2=host.stage.hand_position(p)
	var strike: Vector2=host.stage.strike_position(p)
	var heavy: bool=p.combo==2
	var start: float=p.STARTUP[p.combo]
	var active: float=p.ACTIVE[p.combo]
	var primary: Color=TEAL if p.combo==1 else GOLD
	if p.elapsed<start:
		if heavy and p.elapsed>0.07:
			var charge: float=(p.elapsed-0.07)/(start-0.07)
			for i in 4:
				var axis := Vector2.from_angle(i*TAU/4+0.4)
				shard(hand+axis*lerpf(36,8,charge),axis,6,1.8,tint(CREAM,charge*0.8))
		return
	var t: float=(p.elapsed-start)/(active+0.13)
	if t>=1: return
	var strength: float=pow(1-t,0.75)
	var root: Vector2=p.position+Vector2(10*facing,-111)
	if heavy:
		# Fist-driven pressure trail: a compact leading edge instead of a giant sword arc.
		var end:=strike+Vector2(facing*(16+t*24),2)
		wake(hand-Vector2(facing*83,12),end,-17,15*strength,tint(INK,strength*.75))
		wake(hand-Vector2(facing*80,12),end,-17,10*strength,tint(GOLD,strength*.9))
		wake(hand-Vector2(facing*65,9),end,-13,3.2*strength,tint(CREAM,strength))
		ribbon(end,Vector2(23+t*14,39),-1.25,2.50,10*strength,facing,tint(TEAL,strength*.85))
		for i in 4:
			var q:=hand+Vector2(facing*(-65-i*15-t*25),-19+i*12)
			shard(q,Vector2(facing,-.08),26*strength,1.8*strength,tint(GOLD,strength*.65))
	else:
		var flip: float=-1 if p.combo==1 else 1
		var offset := Vector2(-16*facing,11*flip)
		wake(hand-Vector2(facing*25,0),strike,-5*flip,5*strength,tint(primary,strength*0.72))
		wake(hand-Vector2(facing*25,0),strike,-5*flip,1.8*strength,tint(CREAM,strength))
		ribbon(strike+offset,Vector2(39+t*13,43),-1.45*flip,2.5*flip,13*strength,facing,tint(INK,strength*0.8))
		ribbon(strike+offset,Vector2(36+t*13,40),-1.45*flip,2.5*flip,9*strength,facing,tint(primary,strength))
		ribbon(strike+offset,Vector2(34+t*13,38),-1.40*flip,2.35*flip,3.5*strength,facing,tint(CREAM,strength))
		for i in 3:
			var q: Vector2=strike+Vector2(facing*(-25-t*18),-14+i*14)
			shard(q,Vector2(facing,-0.12*flip),30*strength,2.5*strength,tint(primary,strength*(0.75-i*0.15)))

func impact_effect(e: Dictionary, age: float, alpha: float) -> void:
	var p: Vector2=e.pos
	var size: float=1.35 if e.heavy else 0.85
	var color: Color=Color("f69d79") if e.hurt else GOLD
	if age<0.35:
		var core: float=1-age*1.5
		shard(p,Vector2(0.93,-0.36),43*size*core,11*size*core,INK)
		shard(p,Vector2(0.36,0.93),31*size*core,7*size*core,color)
		shard(p,Vector2(0.93,-0.36),36*size*core,7*size*core,CREAM)
		shard(p,Vector2(-0.5,0.86),24*size*core,4*size*core,CREAM)
	for i in (11 if e.heavy else 7):
		var axis := Vector2.from_angle(i*2.399+0.21)
		var distance: float=(10+pow(age,0.65)*(82 if e.heavy else 51))*size
		shard(p+axis*distance,axis,lerpf(15,3,age)*size,2.5*alpha*size,tint(CREAM if i%3==0 else color,alpha))
	if age>0.12:
		for i in 3:
			ribbon(p,Vector2.ONE*(18+age*68*size),i*TAU/3+age*0.3,0.85,2.8*alpha,1,tint(TEAL,alpha*0.65))

func _draw() -> void:
	if host==null or host.mode!="battle": return
	var h: Node=host
	if is_instance_valid(h.player):
		if h.player.state=="attack": attack_effect(h.player)
		if h.player.state=="skill" and h.player.elapsed<0.26:
			var charge: float=h.player.elapsed/0.26
			var center: Vector2=h.player.position+Vector2(0,-105)
			for i in 8:
				var axis := Vector2.from_angle(i*TAU/8)
				shard(center+axis*lerpf(98,24,charge),-axis,6+charge*7,2,tint(TEAL,charge))
	for e in h.enemies:
		if not is_instance_valid(e) or e.dead: continue
		if preload("res://combat/enemy_catalog.gd").expanded(e.kind): continue
		if e.hp<e.maximum and not e.boss:
			var bar: Vector2=e.position+Vector2(-24,-155 if e.kind=="melee" else -218)
			draw_rect(Rect2(bar,Vector2(48,3)),INK)
			draw_rect(Rect2(bar,Vector2(48*float(e.hp)/e.maximum,3)),GOLD)
		if e.state=="tell":
			var progress: float=minf(1,e.timer/e.windup_duration())
			var p: Vector2=e.position+Vector2(0,-284 if e.boss else -199)
			draw_arc(p,10,-PI/2,-PI/2+TAU*progress,28,Color("f0a17d"),2,true)
			draw_line(p+Vector2(0,-4),p+Vector2(0,2),CREAM,2,true)
			draw_circle(p+Vector2(0,6),1,CREAM)
			if e.kind=="ranged":
				draw_dashed_line(e.position+Vector2(e.facing*32,-125),e.target,Color(1,0.56,0.34,0.2+progress*0.35),1,7,true)
			else:
				var reach: float=196 if e.boss and e.move_id==0 else 141 if e.boss else 109
				var x: float=e.position.x if e.facing>0 else e.position.x-reach
				draw_rect(Rect2(x,637,reach,5),Color(0.98,0.49,0.30,0.16+progress*0.5))
	for p in h.projectiles:
		if p.get("enemy_vfx",false): continue
		var axis: Vector2=p.velocity.normalized()
		shard(p.pos-axis*12,axis,28,5,Color("da8057"))
		shard(p.pos,axis,12,4,CREAM)
	for e in h.effects:
		var alpha: float=clampf(e.life/e.max,0,1)
		var age: float=1-alpha
		var p: Vector2=e.pos
		match e.type:
			"hit": impact_effect(e,age,alpha)
			"air_jump":
				var radius:=Vector2(25+age*58,7+age*16)
				for side in [-1,1]:
					ribbon(p+Vector2(0,age*25),radius,0 if side>0 else PI,PI*.9,7*alpha,1,tint(INK,alpha*.9))
					ribbon(p+Vector2(0,age*25),radius-Vector2(2,1),0 if side>0 else PI,PI*.9,4*alpha,1,tint(GOLD if side>0 else TEAL,alpha))
				for i in 6:
					var side: float=-1 if i%2==0 else 1
					var at:=p+Vector2(side*(15+age*(30+i*9)),8+age*(30+i*10))
					shard(at,Vector2(side*.65,-.7),14*alpha,3*alpha,tint(CREAM if i%3==0 else TEAL,alpha))
			"dust":
				for side in [-1,1]:
					ribbon(p+Vector2(side*age*15,1),Vector2(9+age*24,3+age*6),PI,PI,2*alpha,1,Color(0.75,0.76,0.63,alpha*0.35))
			"ring":
				var radius: float=36+minf(1,age*1.45)*274
				for i in 5:
					var a: float=i*TAU/5+age*0.3
					ribbon(p,Vector2(radius,radius*0.64),a,1.05,15*alpha,1,tint(INK,alpha*0.8))
					ribbon(p,Vector2(radius-3,radius*0.64-3),a,1.05,8*alpha,1,tint(TEAL,alpha))
					ribbon(p,Vector2(radius-4,radius*0.64-4),a,0.95,2.5*alpha,1,tint(CREAM,alpha))
				for i in 16:
					var axis := Vector2.from_angle(i*TAU/16+0.2)
					shard(p+axis*Vector2(radius,radius*0.64),axis,22*alpha,4*alpha,tint(GOLD,alpha))
				if age<0.2: shard(p,Vector2.UP,80*(1-age*4),9,CREAM)
			"dash":
				for i in 5:
					shard(p+Vector2(-e.facing*(12+age*90),i*18-36),Vector2(e.facing,0),35*alpha,2*alpha,tint(TEAL,alpha*0.7))
			"death", "muzzle":
				for i in 8:
					var axis := Vector2.from_angle(i*TAU/8)
					shard(p+axis*(12+age*64),axis,8*alpha,3*alpha,tint(GOLD,alpha))
			"text":
				var c: Color=tint(e.color,minf(1,alpha*3))
				var fs: int=roundi(22*(1+.36*maxf(0,1-age*7)))
				var width: float=h.font.get_string_size(e.text,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x
				var at:=p-Vector2(width*.5,0)
				draw_string_outline(h.font,at,e.text,HORIZONTAL_ALIGNMENT_LEFT,-1,fs,4,tint(INK,c.a))
				draw_string(h.font,at,e.text,HORIZONTAL_ALIGNMENT_LEFT,-1,fs,c)
