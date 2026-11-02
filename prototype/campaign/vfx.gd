extends Node2D
const CATALOG = preload("res://combat/enemy_catalog.gd")
const COLORS := {"spore":Color("ce9df3"),"lightning":Color("b1e6ff"),"eruption":Color("ffb26f")}
var host: Node

func _process(_dt: float) -> void:
	visible=host.mode=="battle"
	if visible: queue_redraw()

func alpha(color: Color, amount: float) -> Color:
	return Color(color.r,color.g,color.b,clampf(amount,0,1))

func ellipse(at: Vector2, radius: Vector2, color: Color, width: float=2.0) -> void:
	draw_set_transform(at,0,Vector2(1,radius.y/radius.x))
	draw_arc(Vector2.ZERO,radius.x,0,TAU,64,color,width,true)
	draw_set_transform(Vector2.ZERO)

func warning(field: Dictionary) -> void:
	var t: float=clampf(field.age/field.warning,0,1)
	var p: Vector2=field.pos
	var radius: float=field.radius
	var color: Color=COLORS.get(field.style,Color("d8bca0"))
	draw_set_transform(p,0,Vector2(1,0.19))
	draw_circle(Vector2.ZERO,radius,alpha(Color("071221"),0.7))
	draw_circle(Vector2.ZERO,radius*t,alpha(color,0.15))
	draw_arc(Vector2.ZERO,radius,0,TAU,64,Color("17212a"),5,true)
	draw_arc(Vector2.ZERO,radius,0,TAU,64,Color("ffb078"),2,true)
	draw_arc(Vector2.ZERO,radius*t,0,TAU,64,alpha(color,0.95),2,true)
	draw_set_transform(Vector2.ZERO)
	for side in [-1,1]: draw_line(p+Vector2(side*radius,-7),p+Vector2(side*radius,7),Color("ffe3b7"),1.5,true)
	if field.style=="lightning":
		draw_rect(Rect2(p+Vector2(-radius,-410),Vector2(radius*2,410)),alpha(color,0.025+0.04*t))
		draw_dashed_line(p+Vector2(0,-410),p,alpha(color,0.28+t*0.4),1,11,true)
		var bolt := PackedVector2Array([p+Vector2(3,-67),p+Vector2(-8,-48),p+Vector2(3,-48),p+Vector2(-3,-30)])
		draw_polyline(bolt,alpha(color,0.45+0.5*t),2,true)

func tell(e: Node) -> void:
	var t: float=clampf(e.timer/e.windup_duration(),0,1)
	var color: Color=CATALOG.DATA[e.kind].color
	var at: Vector2=e.position+Vector2(0,-310)
	draw_arc(at,12,-PI/2,-PI/2+TAU*t,40,Color("ffb078"),2.5,true)
	draw_line(at+Vector2(0,-5),at+Vector2(0,2),Color("fff0c8"),2,true)
	draw_circle(at+Vector2(0,7),1.5,Color("fff0c8"))
	var melee: bool=(e.kind=="mycelium_boss" and e.move_id==1) or (e.kind=="tempest_boss" and e.move_id==1) or (e.kind=="cinder_boss" and e.move_id==0)
	if melee:
		var reach: float=335 if e.kind=="tempest_boss" else 195
		var left: float=e.position.x if e.facing>0 else e.position.x-reach
		draw_rect(Rect2(left,634,reach,8),Color(1,0.55,0.32,0.18+t*0.33))
		draw_line(Vector2(left,640),Vector2(left+reach,640),Color("ffb078"),2,true)
	else:
		ellipse(Vector2(e.target.x,640),Vector2(32,7),alpha(color,0.4+t*0.4))
		for i in 5:
			var axis := Vector2.from_angle(i*TAU/5+e.timer*1.5)
			draw_circle(e.position+Vector2(0,-180)+axis*(60-t*35),2+t*2,alpha(color,t))

func burst(effect: Dictionary) -> void:
	var a: float=clampf(effect.life/effect.max,0,1)
	var t: float=1-a
	var p: Vector2=effect.pos
	match effect.type:
		"boss_lightning":
			var points := PackedVector2Array()
			for i in 12:
				points.append(p+Vector2(0 if i in [0,11] else sin(i*12.3+t*6)*16,lerpf(-430,0,float(i)/11)))
			draw_polyline(points,Color(0.40,0.63,1,a*0.18),20,true)
			draw_polyline(points,Color(0.60,0.82,1,a*0.8),7*a+0.2,true)
			draw_polyline(points,Color(0.96,0.99,1,a),2*a+0.2,true)
			ellipse(p,Vector2(30+t*85,7+t*11),Color(0.65,0.88,1,a))
			for i in 9:
				var axis := Vector2.from_angle(i*2.399)
				draw_line(p+axis*(t*100),p+axis*(t*100+18*a),Color(0.7,0.9,1,a),1.5,true)
		"boss_spore":
			ellipse(p,Vector2(40+t*65,9+t*12),Color(0.8,0.6,1,a))
			for i in 12:
				var q: Vector2=p+Vector2(sin(i*2.399)*(15+t*62),-12-t*(50+float(i%4)*19))
				draw_circle(q,3+a*4,Color(0.74,0.60,1,a*0.65))
				draw_arc(q,6+a*6,0,TAU,16,Color(0.94,0.83,1,a*0.5),1,true)
		"boss_eruption":
			ellipse(p,Vector2(45+t*70,9+t*15),Color(1,0.68,0.32,a))
			for i in 7:
				var x: float=(i-3)*15
				var height: float=(55+absf(sin(i*2.3))*65)*a
				draw_set_transform(p+Vector2(x,-t*15))
				draw_colored_polygon(PackedVector2Array([Vector2(-10,0),Vector2(-5,-height*0.6),Vector2(3,-height),Vector2(9,0)]),Color(1,0.44+float(i%3)*0.1,0.15,a*0.8))
				draw_set_transform(Vector2.ZERO)
			for i in 12:
				var axis := Vector2(sin(i*3.1),-0.5-absf(cos(i*1.8)))
				draw_circle(p+axis*(15+t*90)+Vector2(0,t*t*55),2*a+0.4,Color(1,0.85,0.5,a))
		"forge_slam":
			ellipse(p,Vector2(25+t*190,8+t*27),Color(1,0.67,0.33,a*0.9),3*a+0.5)
			for i in 11:
				var axis := Vector2(sin(i*2.399),-absf(cos(i*2.399)))
				var q: Vector2=p+axis*(10+t*120)+Vector2(0,t*t*75)
				draw_line(q,q+axis*18*a,Color(1,0.78,0.48,a),3*a+0.2,true)
		"wing_cut", "crown_sweep":
			var color: Color=Color("a5d8f3") if effect.type=="wing_cut" else Color("c2a4ef")
			var begin: float=-1.35+t*0.2
			var points := PackedVector2Array()
			for i in 26:
				var angle: float=begin+float(i)/25*2.5
				points.append(p+Vector2(cos(angle)*effect.facing,sin(angle))*(45+t*84))
			draw_polyline(points,alpha(color,a*0.18),16*a+0.1,true)
			draw_polyline(points,alpha(color,a),4*a+0.1,true)
			draw_polyline(points,Color(0.96,0.96,1,a),1.3,true)
		"crown_cast", "storm_cast", "boss_enrage":
			var color := Color("c2a4ef") if effect.type=="crown_cast" else Color("a5d8f3") if effect.type=="storm_cast" else Color("ffc28c")
			ellipse(p,Vector2.ONE*(28+t*108),alpha(color,a*0.6),2*a+0.5)
			for i in 12:
				var axis := Vector2.from_angle(i*TAU/12)
				draw_line(p+axis*(20+t*85),p+axis*(20+t*85+18*a),alpha(color,a),2,true)

func _draw() -> void:
	if host==null or host.mode!="battle": return
	for e in host.enemies:
		if not is_instance_valid(e) or e.dead or not e.boss or e.kind=="boss": continue
		if e.state=="tell": tell(e)
		if e.enraged: ellipse(e.position+Vector2(0,-5),Vector2(82,13),Color(1,0.55,0.35,0.36))
	for field in host.boss_fields.fields:
		if field.age<field.warning and not str(field.style).begins_with("ultimate_") and not str(field.style).begins_with("mythic_") and not str(field.style).begins_with("repertoire_"): warning(field)
	for effect in host.effects:
		if effect.type in ["boss_lightning","boss_spore","boss_eruption","forge_slam","wing_cut","crown_sweep","crown_cast","storm_cast","boss_enrage"]: burst(effect)
