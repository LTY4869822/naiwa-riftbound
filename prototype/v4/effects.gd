extends Node2D
const A = preload("res://v4/art.gd")
var host: Node

func diamond(p: Vector2, length: float, width: float, angle: float, color: Color) -> void:
	if length<0.3 or width<0.15: return
	var points := PackedVector2Array()
	for v in [Vector2(-length,0),Vector2(0,-width),Vector2(length,0),Vector2(0,width)]: points.append(p+v.rotated(angle))
	draw_colored_polygon(points,color)

func crescent(center: Vector2, radius: float, width: float, facing: int, rotation: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(25):
		var u: float = float(i)/24
		var angle := lerpf(-1.32,1.05,u)+rotation
		points.append(center+Vector2(cos(angle)*facing,sin(angle))*radius)
	for i in range(24,-1,-1):
		var u: float = float(i)/24
		var angle := lerpf(-1.32,1.05,u)+rotation
		points.append(center+Vector2(cos(angle)*facing,sin(angle))*(radius-sin(u*PI)*width))
	draw_colored_polygon(points,color)

func _draw() -> void:
	if host==null or host.mode!="battle": return
	var h: Node = host
	if is_instance_valid(h.player):
		shadow(Vector2(h.player.position.x,640),40)
		if h.player.state=="attack":
			var elapsed: float = h.player.elapsed-h.player.STARTUP[h.player.combo]
			if elapsed>=-0.015 and elapsed<0.22:
				var age: float = clampf(elapsed/0.22,0,1)
				var center: Vector2 = h.player.position+Vector2(22*h.player.facing,-125 if h.player.combo<2 else -105)
				var radius: float = 104 if h.player.combo<2 else 131
				var color: Color = A.CYAN if h.player.combo<2 else A.GOLD
				crescent(center,radius,24*(1-age),h.player.facing,age*0.5,A.INK)
				crescent(center,radius-3,17*(1-age),h.player.facing,age*0.5,color)
				crescent(center,radius-4,5*(1-age),h.player.facing,age*0.5,A.PAPER)
	for e in h.enemies:
		if not is_instance_valid(e) or e.dead: continue
		shadow(Vector2(e.position.x,640),48 if e.boss else 32)
		if e.hp<e.maximum and not e.boss:
			draw_rect(Rect2(e.position+Vector2(-24,-187),Vector2(48,4)),A.INK)
			draw_rect(Rect2(e.position+Vector2(-24,-187),Vector2(48*float(e.hp)/e.maximum,4)),A.DANGER)
		if e.state=="tell":
			var progress: float = minf(1,e.timer/e.windup_duration())
			var p: Vector2 = e.position+Vector2(0,-245 if e.boss else -196)
			diamond(p,14,14,0,A.INK)
			draw_arc(p,18,-PI/2,-PI/2+TAU*progress,32,A.DANGER,3,true)
			draw_line(p+Vector2(0,-6),p+Vector2(0,2),A.PAPER,3,true)
			draw_circle(p+Vector2(0,7),1.5,A.PAPER)
			if e.kind=="ranged":
				draw_dashed_line(e.position+Vector2(e.facing*32,-125),e.target,A.DANGER,1.5,9,true)
			else:
				var reach: float = 196 if e.boss and e.move_id==0 else 141 if e.boss else 109
				var start: Vector2 = Vector2(e.position.x,636)
				draw_line(start,start+Vector2(e.facing*reach,0),A.INK,8)
				draw_line(start,start+Vector2(e.facing*reach*progress,0),A.DANGER,4)
				for i in range(3):
					var arrow := start+Vector2(e.facing*(reach-8-i*15),0)
					draw_polyline(PackedVector2Array([arrow+Vector2(-e.facing*5,-5),arrow,arrow+Vector2(-e.facing*5,5)]),A.PAPER,2,true)
	for p in h.projectiles:
		var angle: float = p.velocity.angle()
		diamond(p.pos-p.velocity.normalized()*13,27,6,angle,A.INK)
		diamond(p.pos,12,6,angle,A.DANGER)
		diamond(p.pos+Vector2(2,0).rotated(angle),7,2,angle,A.CREAM)
	for effect in h.effects:
		var alpha: float = clampf(effect.life/effect.max,0,1)
		var age: float = 1-alpha
		var p: Vector2 = effect.pos
		match effect.type:
			"dust":
				for i in range(5):
					var direction := Vector2(cos(i*0.72+0.15),-absf(sin(i*0.72+0.15)))
					diamond(p+direction*(10+age*24),6*alpha,3*alpha,age,A.DISTANT)
			"hit":
				var color: Color = A.DANGER if effect.hurt else A.GOLD if effect.heavy else A.CYAN
				if age<0.38:
					diamond(p,52*alpha if effect.heavy else 35*alpha,9*alpha,-0.55,A.INK)
					diamond(p,46*alpha if effect.heavy else 30*alpha,5*alpha,-0.55,A.PAPER)
					diamond(p,34*alpha,4*alpha,1.0,color)
				for i in range(6):
					var angle: float = i*2.399
					var d := Vector2(cos(angle),sin(angle)*0.75)
					diamond(p+d*(18+age*(82 if effect.heavy else 48)),12*alpha,2*alpha,angle,color)
			"ring":
				var radius: float = 38+smoothstep(0,0.75,age)*272
				draw_arc(p,radius,0,TAU,96,A.CYAN,7*alpha,true)
				draw_arc(p,radius+9,0,TAU,96,A.PAPER,2*alpha,true)
				for i in range(8):
					var angle: float = i*TAU/8+age*0.25
					diamond(p+Vector2(cos(angle),sin(angle))*radius,24*alpha,7*alpha,angle,A.PAPER)
			"dash":
				for i in range(4): diamond(p+Vector2(-effect.facing*(28+age*95),i*18-30),42*alpha,2*alpha,0,A.CYAN if i%2==0 else A.PAPER)
			"death", "muzzle":
				for i in range(7):
					var angle: float = i*TAU/7
					diamond(p+Vector2(cos(angle),sin(angle))*(10+age*64),9*alpha,4*alpha,angle+age,A.CREAM)
			"text":
				var c: Color = effect.color
				c.a = minf(1,alpha*3)
				draw_string_outline(h.font,p,effect.text,HORIZONTAL_ALIGNMENT_CENTER,-1,24,4,A.INK)
				draw_string(h.font,p,effect.text,HORIZONTAL_ALIGNMENT_CENTER,-1,24,c)

func shadow(p: Vector2, width: float) -> void:
	draw_set_transform(p+Vector2(0,2),0,Vector2(1,0.12))
	draw_circle(Vector2.ZERO,width,Color(0.067,0.106,0.169,0.24))
	draw_set_transform(Vector2.ZERO)
