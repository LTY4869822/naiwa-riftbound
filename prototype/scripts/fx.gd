extends Node2D

var host: Node

func _process(_delta: float) -> void:
	if host!=null:
		position = host.arena.position
	queue_redraw()

func crescent(center: Vector2, radius: float, thickness: float, facing: int, angle: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(25):
		var t: float = float(i)/24
		var a: float = lerpf(-1.35,1.15,t)+angle
		var r: float = radius+sin(t*PI)*thickness
		points.append(center+Vector2(cos(a)*facing,sin(a))*r)
	for i in range(24,-1,-1):
		var t: float = float(i)/24
		var a: float = lerpf(-1.35,1.15,t)+angle
		points.append(center+Vector2(cos(a)*facing,sin(a))*radius)
	draw_colored_polygon(points,color)

func _draw() -> void:
	if host==null or host.mode=="pet":
		return
	for effect in host.effects:
		var alpha: float = clampf(float(effect["life"])/float(effect["max"]),0,1)
		var age: float = 1-alpha
		var pos: Vector2 = effect["pos"]
		match effect["type"]:
			"particle":
				var color: Color = effect["color"]
				color.a = alpha
				var v: Vector2 = effect["velocity"]
				draw_line(pos-v.normalized()*float(effect["size"])*2,pos,color,maxf(0.7,alpha*2),true)
			"dust":
				draw_arc(pos+Vector2(0,3),(1-alpha)*48,-PI,0,20,Color(0.8,0.75,0.55,alpha*0.25),6*alpha,true)
			"ghost":
				if host.mode!="battle": continue
				var texture: Texture2D = effect.get("texture",host.idle)
				draw_set_transform(pos,0,Vector2(effect["facing"],1))
				draw_texture_rect(texture,Rect2(-96,-224,192,224),false,Color(0.75,0.9,0.83,alpha*0.28))
				draw_set_transform(Vector2.ZERO)
			"slash", "enemy_slash":
				if host.mode!="battle": continue
				var strong: bool = effect.get("strong",false)
				var enemy: bool = effect["type"]=="enemy_slash"
				var facing: int = effect["facing"]
				var c: Color = Color("f19c7b") if enemy else Color("ffcf77")
				var radius: float = (104 if strong else 76)*(0.78+age*0.42)
				var angle: float = effect.get("angle",0.0)+age*0.15
				crescent(pos,radius,30 if strong else 22,facing,angle,Color(c.r,c.g,c.b,alpha*0.13))
				crescent(pos,radius+4,15 if strong else 11,facing,angle,Color(c.r,c.g,c.b,alpha*0.65))
				crescent(pos,radius+12,3.5,facing,angle,Color(1,0.98,0.88,alpha))
				if strong:
					draw_line(pos+Vector2(-95*facing,48),pos+Vector2(185*facing,-36),Color(1,0.88,0.55,alpha*0.7),4*alpha,true)
			"impact":
				var color: Color = effect["color"]
				for i in range(9):
					var a: float = i*2.399+effect.get("seed",0.0)
					var d := Vector2(cos(a),sin(a)*0.65)
					var distance: float = age*(90 if effect["strong"] else 58)
					draw_line(pos+d*(distance+5),pos+d*(distance+13+alpha*15),Color(color.r,color.g,color.b,alpha),maxf(0.7,alpha*2),true)
				if age<0.4:
					draw_line(pos-Vector2(35,0)*alpha,pos+Vector2(35,0)*alpha,Color(1,0.97,0.84,alpha),4*alpha,true)
					draw_line(pos-Vector2(0,25)*alpha,pos+Vector2(0,25)*alpha,Color(1,0.97,0.84,alpha),3*alpha,true)
			"ring":
				if host.mode!="battle": continue
				var r: float = 45+age*330
				draw_arc(pos,r,0,TAU,96,Color(1,0.82,0.45,alpha*0.45),12*alpha,true)
				draw_arc(pos,r+12,0,TAU,96,Color(1,0.95,0.75,alpha),2*alpha,true)
				for side in [-1,1]:
					var tip := pos+Vector2(side*age*420,0)
					draw_colored_polygon(PackedVector2Array([tip+Vector2(-side*150,12*alpha),tip+Vector2(side*15,0),tip+Vector2(-side*150,-12*alpha)]),Color(1,0.91,0.65,alpha*0.8))
	for number in host.numbers:
		var alpha: float = clampf(number["life"]*2,0,1)
		var color: Color = number["color"]
		color.a = alpha
		var p: Vector2 = number["pos"]
		draw_string(host.font,p+Vector2(1,2),number["text"],HORIZONTAL_ALIGNMENT_CENTER,-1,22,Color(0.02,0.04,0.05,alpha))
		draw_string(host.font,p,number["text"],HORIZONTAL_ALIGNMENT_CENTER,-1,22,color)
	if host.mode=="battle":
		if host.impact_flash>0:
			draw_rect(Rect2(0,0,1280,800),Color(1,0.9,0.68,host.impact_flash*1.5))
		if host.damage_flash>0:
			draw_rect(Rect2(0,0,1280,800),Color(0.6,0.08,0.03,host.damage_flash*0.3))
		if host.combo_hits>1 and host.combo_life>0:
			draw_string(host.font,Vector2(55,153),"%02d" % host.combo_hits,HORIZONTAL_ALIGNMENT_LEFT,-1,46,Color("efcd89"))
			draw_string(host.font,Vector2(58,177),"连击  /  COMBO",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("c6c7ae"))
		if host.wave_banner>0:
			var a: float = minf(1,host.wave_banner*2)
			draw_string(host.font,Vector2(470,282),"第 %02d 波 · %s" % [host.wave,"档案守卫" if host.wave==3 else "损坏档案"],HORIZONTAL_ALIGNMENT_LEFT,-1,30,Color(1,0.92,0.75,a))
