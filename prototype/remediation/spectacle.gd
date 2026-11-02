extends Node2D
## Original ultimate choreography; this renderer never applies damage.
const Canvas=preload("res://foe_vfx/toon_canvas.gd")
const Motif=preload("res://foe_vfx/toon_motifs.gd")
const Ult=preload("res://remediation/boss_ultimates.gd")
const PALETTES:={
	"hero":[Color("fff5ce"),Color("f9c157"),Color("64d8bc"),Color("173e40")],
	"boss":[Color("efffcf"),Color("a4dc79"),Color("88724c"),Color("173c37")],
	"mycelium_boss":[Color("f3e4ff"),Color("c084f6"),Color("5d99d7"),Color("312047")],
	"tempest_boss":[Color("e5faff"),Color("77dcff"),Color("698af5"),Color("1e304d")],
	"cinder_boss":[Color("fff2b1"),Color("ffb140"),Color("ef6946"),Color("472b38")]}
var host: Node
var canvas: Node2D
var cutin: Control
var cutin_age:=10.0
var cutin_kind:="hero"
var cutin_owner:=0
var clock:=0.0
var portrait: Texture2D
var bold: SystemFont

func _ready() -> void:
	canvas=Canvas.new()
	add_child(canvas)
	var layer:=CanvasLayer.new()
	layer.layer=6
	add_child(layer)
	cutin=Control.new()
	cutin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cutin.mouse_filter=Control.MOUSE_FILTER_IGNORE
	cutin.draw.connect(paint_cutin)
	layer.add_child(cutin)
	bold=SystemFont.new()
	bold.font_names=PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei"])
	bold.font_weight=900

func announce(kind: String, owner_id: int=0) -> void:
	cutin_kind=kind
	cutin_owner=owner_id
	cutin_age=0
	portrait=load("res://assets/menu-v2/pet/front-idle.png") if kind=="hero" else null
	if kind!="hero":
		for e in host.enemies:
			if is_instance_valid(e) and e.eid==owner_id:
				var rig: Node=host.stage.actors.get(e.get_instance_id())
				if rig!=null and rig.frames.size()>5: portrait=rig.frames[5].texture
	cutin.queue_redraw()

func clear() -> void:
	cutin_age=10
	if is_instance_valid(canvas): canvas.begin(0); canvas.finish()
	if is_instance_valid(cutin): cutin.hide()

func cancel(owner_id: int) -> void:
	if cutin_owner==owner_id: cutin_age=10

func _process(dt: float) -> void:
	visible=host.mode=="battle" and not host.over
	cutin.visible=visible and cutin_age<0.72
	if not host.playing(): return
	if host.hitstop>0: return
	clock+=dt
	cutin_age+=dt
	cutin.queue_redraw()
	canvas.begin(clock)
	for e in host.enemies:
		if is_instance_valid(e) and not e.dead and PALETTES.has(e.kind) and not e.ult_data.is_empty() and not e.ult_data.get("apex",false) and e.state in ["ult_tell","ult_active"]: paint_boss(e)
	for field in host.boss_fields.fields:
		if str(field.style).begins_with("ultimate_"): paint_field(field)
	paint_hero()
	canvas.finish()

func paint_boss(e: Node) -> void:
	var colors: Array=PALETTES[e.kind]
	if e.state=="ult_tell":
		var power: float=clampf(e.timer/Ult.TELL,0,1)
		var p: Vector2=e.position+Vector2(0,-120)
		Motif.crescent(canvas,p,Vector2(94,108),-clock*2,-clock*2+PI*1.6,15,colors,power*0.8)
		for i in 9:
			var angle: float=i*TAU/9+clock*0.7
			var point: Vector2=p+Vector2.from_angle(angle)*(135-power*55)
			canvas.ellipse(point,Vector2(3,8),colors[0],angle)
		if e.kind=="mycelium_boss":
			for i in 3: canvas.cel_quad("orb",p+Vector2(sin(clock+i*2.1)*100,cos(clock+i*2.1)*44),Vector2(42,42),clock,0.85,colors,0,i)
		elif e.kind=="tempest_boss":
			canvas.flipbook("wind",p,Vector2(285,185),2+fmod(clock*10,3),0.65)
		elif e.kind=="cinder_boss":
			canvas.cel_quad("orb",p+Vector2(0,-100),Vector2.ONE*(75+power*80),clock,0.9,colors)

func paint_field(field: Dictionary) -> void:
	var p: Vector2=field.pos
	var style: String=field.style
	var kind: String="boss" if style=="ultimate_roots" else "mycelium_boss" if style=="ultimate_spore" else "tempest_boss" if style=="ultimate_thunder" else "cinder_boss"
	var colors: Array=PALETTES[kind]
	var t: float=field.age-field.warning
	var radius: float=field.radius
	if t<0:
		var progress: float=clampf(field.age/field.warning,0,1)
		Motif.ring(canvas,p,Vector2(radius,22),[Color("ffe4ca"),Color("ffac8c"),Color("e77968"),Color("3c2735")],0.92)
		Motif.ring(canvas,p,Vector2(maxf(2,radius*progress),18),colors,0.75,2)
		canvas.stroke(PackedVector2Array([p+Vector2(-radius,-4),p+Vector2(radius,-4)]),Color(1,0.36,0.29,0.7),3)
		if style=="ultimate_thunder":
			canvas.stroke(PackedVector2Array([p+Vector2(0,-450),p]),Color(0.7,0.85,1,0.18+progress*0.3),2)
			canvas.cel_quad("orb",p+Vector2(0,-385),Vector2.ONE*(24+progress*33),clock,0.7,colors)
		elif style=="ultimate_meteor":
			var meteor: Vector2=p+Vector2(-90*(1-progress),-500+progress*260)
			canvas.flipbook("fire",meteor+Vector2(0,50),Vector2(140,210),2+fmod(clock*14,3),0.85,0.36)
			canvas.cel_quad("orb",meteor,Vector2.ONE*(70+progress*35),clock,0.95,colors)
		return
	var fade: float=clampf((0.8-t)/0.3,0,1)
	var frame: float=clampf(t/0.72*8,0,7)
	if style=="ultimate_roots":
		canvas.flipbook("roots",p,Vector2(radius*2.35,290),frame,fade)
		Motif.debris(canvas,p,t,0.8,colors,19,12)
	elif style=="ultimate_spore":
		canvas.flipbook("spore",p,Vector2(radius*2.15,260),frame,fade)
		for i in 4:
			var point: Vector2=p+Vector2(sin(i*2.3+t*2)*(50+t*85),-85-cos(i*1.9)*50-t*65)
			canvas.cel_quad("orb",point,Vector2.ONE*(30-18*t),clock,fade*0.7,colors,0,i)
	elif style=="ultimate_thunder":
		canvas.flipbook("lightning",p,Vector2(180,670),frame,fade)
		Motif.ring(canvas,p,Vector2(30+t*110,12+t*18),colors,fade,3)
	else:
		canvas.flipbook("fire",p,Vector2(radius*2.5,340),frame,fade)
		Motif.burst(canvas,p+Vector2(0,-40),160,colors,t/0.8,fade,23)
		Motif.debris(canvas,p,t,0.8,colors,23,14)

func paint_hero() -> void:
	if not is_instance_valid(host.player): return
	var colors: Array=PALETTES.hero
	if host.ultimate.charging():
		var progress: float=clampf(host.player.elapsed/host.player.SKILL_RELEASE,0,1)
		var p: Vector2=host.stage.strike_position(host.player)
		canvas.flipbook("fist",p,Vector2(140,138)*(0.7+progress*0.3),minf(2,progress*3),progress*0.8,0,host.player.facing)
	for w in host.ultimate.waves:
		var fade: float=clampf((host.ultimate.RANGE-float(w.travel))/110,0,1)
		var p: Vector2=w.pos+Vector2(-w.facing*40,0)
		canvas.flipbook("fist",p,Vector2(310,248),3+minf(1,w.age*2),fade,0,w.facing)
		Motif.ring(canvas,p,Vector2(50,110),colors,fade*0.8,4)
		for i in 3:
			Motif.crescent(canvas,p-Vector2(w.facing*(80+i*55),0),Vector2(34,95-i*10),-1.4 if w.facing==1 else PI-1.4,1.4 if w.facing==1 else PI+1.4,9,colors,fade*(0.55-i*0.12))
	for b in host.ultimate.bursts:
		if b.launch: continue
		var frame: float=5+minf(2,b.age/b.duration*3)
		canvas.flipbook("fist",b.pos,Vector2(330,290),frame,1-b.age/b.duration,0,b.facing)

func paint_cutin() -> void:
	if cutin_age>=0.72 or portrait==null: return
	var colors: Array=PALETTES[cutin_kind]
	var u: float=clampf(cutin_age/0.72,0,1)
	var fade: float=clampf(minf(u/0.10,(1-u)/0.18),0,1)
	var origin: Vector2=Vector2(0,270)
	var shift: float=0 if host.reduce_motion else (1-pow(minf(1,u*7),3))*-170
	cutin.draw_set_transform(origin+Vector2(shift,0))
	cutin.draw_colored_polygon(PackedVector2Array([Vector2(0,0),Vector2(815,0),Vector2(760,128),Vector2(0,128)]),Color(colors[3],fade*0.96))
	cutin.draw_colored_polygon(PackedVector2Array([Vector2(0,0),Vector2(825,0),Vector2(812,7),Vector2(0,7)]),Color(colors[1],fade))
	cutin.draw_line(Vector2(0,126),Vector2(760,126),Color(colors[2],fade),4,true)
	for i in 12: cutin.draw_line(Vector2(330+i*31,10),Vector2(260+i*31,118),Color(colors[1],fade*0.10),4,true)
	var art_size:=Vector2(136,166)
	var art_at:=Vector2(34,-25)
	cutin.draw_texture_rect(portrait,Rect2(art_at,art_size),false,Color(1,1,1,fade))
	var title: String="星核·碎界拳" if cutin_kind=="hero" else Ult.TITLES[cutin_kind]
	var subtitle: String="NAIWA  /  STARFALL OVERDRIVE" if cutin_kind=="hero" else "GUARDIAN  /  ULTIMATE ARTS"
	cutin.draw_string(bold,Vector2(206,31),subtitle,HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color(colors[1],fade))
	cutin.draw_string_outline(bold,Vector2(200,88),title,HORIZONTAL_ALIGNMENT_LEFT,-1,44,6,Color(colors[3],fade))
	cutin.draw_string(bold,Vector2(200,88),title,HORIZONTAL_ALIGNMENT_LEFT,-1,44,Color(colors[0],fade))
	cutin.draw_set_transform(Vector2.ZERO)
