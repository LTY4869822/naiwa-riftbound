extends Node2D
var host: Node

func _ready() -> void:
	var expansion := preload("res://combat/enemy_vfx.gd").new()
	expansion.host=host
	add_child(expansion)
	var guardians := preload("res://campaign/vfx.gd").new()
	guardians.host=host
	add_child(guardians)

func _draw() -> void:
	if host==null or host.mode!="battle": return
	var h: Node = host
	if is_instance_valid(h.player):
		if h.player.state=="attack":
			var progress: float = h.player.visual_progress()
			if progress>0.26 and progress<0.58:
				var facing: int = h.player.facing
				var center: Vector2 = h.stage.hand_position(h.player)+Vector2(-18*facing,0)
				var points := PackedVector2Array()
				var alpha: float = sin((progress-0.26)/0.32*PI)
				for i in range(18):
					var u: float = float(i)/17
					var a: float = lerpf(-1.25,0.85,u)+(progress-0.4)*2
					points.append(center+Vector2(cos(a)*facing,sin(a))*(35 if h.player.combo<2 else 72))
				draw_polyline(points,Color(1,0.76,0.32,alpha*0.15),18,true)
				draw_polyline(points,Color(1,0.83,0.47,alpha*0.7),5,true)
				draw_polyline(points,Color(1,0.96,0.80,alpha),1.5,true)
	for e in h.enemies:
		if not is_instance_valid(e) or e.dead: continue
		if preload("res://combat/enemy_catalog.gd").expanded(e.kind): continue
		if e.hp<e.maximum and not e.boss:
			var bar_at: Vector2=e.position+Vector2(-33,-187)
			var ratio: float=clampf(float(e.hp)/e.maximum,0,1)
			draw_line(bar_at-Vector2(1,0),bar_at+Vector2(67,0),Color(0.025,0.06,0.075,0.9),8,true)
			draw_line(bar_at,bar_at+Vector2(66,0),Color("65776b"),6,true)
			draw_line(bar_at,bar_at+Vector2(66,0),Color("172d30"),4,true)
			if ratio>0:
				draw_line(bar_at,bar_at+Vector2(66*ratio,0),Color("d3b983"),4,true)
				draw_line(bar_at+Vector2(0,-1),bar_at+Vector2(66*ratio,-1),Color("f2dfb1"),1,true)
		if e.state=="tell":
			var progress: float = minf(1,e.timer/e.windup_duration())
			var p: Vector2 = e.position+Vector2(0,-284 if e.boss else -199)
			draw_arc(p,10,-PI/2,-PI/2+TAU*progress,28,Color("f0a17d"),2,true)
			draw_line(p+Vector2(0,-4),p+Vector2(0,2),Color("ffe1b7"),2,true)
			draw_circle(p+Vector2(0,6),1,Color("ffe1b7"))
			if e.kind=="ranged":
				var from: Vector2 = e.position+Vector2(e.facing*32,-125)
				draw_dashed_line(from,e.target,Color(1,0.56,0.34,0.2+progress*0.35),1,7,true)
			else:
				var reach: float = 196 if e.boss and e.move_id==0 else 141 if e.boss else 109
				var x: float = e.position.x if e.facing>0 else e.position.x-reach
				draw_rect(Rect2(x,637,reach,7),Color(0.98,0.49,0.30,0.16+progress*0.5))
	for p in h.projectiles:
		if p.get("enemy_vfx",false): continue
		var v: Vector2 = p.velocity.normalized()
		draw_line(p.pos-v*31,p.pos,Color(1,0.65,0.32,0.28),8,true)
		draw_line(p.pos-v*22,p.pos,Color("ffc58c"),2,true)
		draw_circle(p.pos,7,Color("da8057"))
		draw_circle(p.pos,3.5,Color("ffefc0"))
	for effect in h.effects:
		var alpha: float = clampf(effect.life/effect.max,0,1)
		var age: float = 1-alpha
		var p: Vector2 = effect.pos
		match effect.type:
			"dust":
				for side in [-1,1]:
					draw_arc(p+Vector2(side*age*22,2),5+age*18,PI,TAU,16,Color(0.75,0.76,0.63,alpha*0.23),3*alpha,true)
			"hit":
				var color: Color = Color("ef9c79") if effect.hurt else Color("ffe0a2")
				for i in range(10):
					var a: float = i*2.399
					var d := Vector2(cos(a),sin(a)*0.7)
					var distance: float = age*(95 if effect.heavy else 58)
					draw_line(p+d*(distance+2),p+d*(distance+alpha*22),Color(color.r,color.g,color.b,alpha),maxf(0.6,2*alpha),true)
				if age<0.5:
					var star := PackedVector2Array()
					for i in range(8):
						var a: float = i*PI/4
						star.append(p+Vector2(cos(a),sin(a))*((32 if effect.heavy else 22)*alpha if i%2==0 else 5*alpha))
					draw_colored_polygon(star,Color(1,0.98,0.87,alpha))
			"ring":
				draw_arc(p,35+age*290,0,TAU,80,Color(0.56,0.88,0.77,alpha*0.7),4*alpha,true)
				draw_arc(p,40+age*305,0,TAU,80,Color(1,0.93,0.71,alpha),1.5,true)
				for i in 12:
					var angle: float=i*TAU/12+0.25
					var axis := Vector2.from_angle(angle)
					var side := Vector2(-axis.y,axis.x)
					var tip := p+axis*(48+age*285)
					var shard := PackedVector2Array([tip+axis*21*alpha,tip+side*5*alpha,tip-axis*13*alpha,tip-side*5*alpha])
					draw_colored_polygon(shard,Color(0.95,0.88,0.59,alpha*0.85))
			"dash":
				for i in range(4):
					var q: Vector2 = p+Vector2(-effect.facing*(20+age*100),i*13-20)
					draw_line(q,q+Vector2(-effect.facing*40*alpha,0),Color(0.67,0.87,0.80,alpha*0.6),1,true)
			"death", "muzzle":
				for i in range(8):
					var a: float = i*TAU/8
					var q := p+Vector2(cos(a),sin(a))*(12+age*64)
					draw_rect(Rect2(q,Vector2(4,4)*alpha),Color(0.85,0.84,0.59,alpha))
			"text":
				var c: Color = effect.color
				c.a = minf(1,alpha*3)
				draw_string_outline(h.font,p,effect.text,HORIZONTAL_ALIGNMENT_CENTER,-1,22,3,Color(0.05,0.1,0.1,c.a))
				draw_string(h.font,p,effect.text,HORIZONTAL_ALIGNMENT_CENTER,-1,22,c)

func shadow(p: Vector2, width: float) -> void:
	draw_set_transform(p+Vector2(0,3),0,Vector2(1,0.16))
	draw_circle(Vector2.ZERO,width,Color(0.015,0.04,0.04,0.25))
	draw_set_transform(Vector2.ZERO)
