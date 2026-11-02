extends Node2D
## Original RGBA atlas sprites, bounded pickup sparks and short collection arcs.
const DATA_PATH:="res://assets/loot-v3/manifest.json"
var host: Node
var journey: Node
var atlas: Dictionary={}
var manifest: Dictionary={}
var clock:=0.0
var bursts: Array[Dictionary]=[]
var feedback_count:=0
var label_box: StyleBoxFlat

func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	manifest=JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	for key in manifest:
		atlas[key]=[]
		var texture: Texture2D=load(manifest[key].file)
		for frame in manifest[key].frames:
			var sprite:=AtlasTexture.new()
			sprite.atlas=texture
			sprite.region=Rect2(frame.region[0],frame.region[1],frame.region[2],frame.region[3])
			sprite.filter_clip=true
			atlas[key].append(sprite)
	label_box=StyleBoxFlat.new()
	label_box.bg_color=Color("152820e8")
	label_box.border_color=Color("aadca77d")
	label_box.set_border_width_all(1)
	label_box.set_corner_radius_all(8)

func reset() -> void:
	bursts.clear()
	queue_redraw()

func collected(drop: Dictionary) -> void:
	feedback_count+=1
	if bursts.size()>=24: bursts.pop_front()
	bursts.append({"kind":drop.type,"pos":Vector2(drop.pos),"target":host.player.position+Vector2(0,-103),"age":0.0,"seed":int(drop.id)})

func _process(dt: float) -> void:
	visible=host.mode=="battle" and not host.over
	if not host.playing() or host.hitstop>0: return
	clock+=dt
	for i in range(bursts.size()-1,-1,-1):
		bursts[i].age+=dt
		if bursts[i].age>0.78: bursts.remove_at(i)
	queue_redraw()

func icon(kind: String, index: int, p: Vector2, height: float, alpha: float=1.0, rotation_angle: float=0.0) -> void:
	var tex: AtlasTexture=atlas[kind][index]
	var size: Vector2=tex.region.size*(height/float(manifest[kind].reference_height))
	draw_set_transform(p,rotation_angle)
	draw_texture_rect(tex,Rect2(-size*.5,size),false,Color(1,1,1,alpha))
	draw_set_transform(Vector2.ZERO)

func star(p: Vector2, size: float, color: Color) -> void:
	if size<.35 or color.a<.01: return
	draw_colored_polygon(PackedVector2Array([p+Vector2(0,-size),p+Vector2(size*.23,-size*.23),p+Vector2(size,0),p+Vector2(size*.23,size*.23),p+Vector2(0,size),p+Vector2(-size*.23,size*.23),p+Vector2(-size,0),p+Vector2(-size*.23,-size*.23)]),color)

func shadow(p: Vector2, width: float) -> void:
	draw_set_transform(Vector2(p.x,637),0,Vector2(1,.22))
	draw_circle(Vector2.ZERO,width,Color(0.025,0.018,0.045,.30))
	draw_circle(Vector2.ZERO,width*.7,Color(0.025,0.018,0.045,.20))
	draw_set_transform(Vector2.ZERO)

func _draw() -> void:
	if atlas.is_empty() or not visible: return
	for d in journey.drops:
		var p: Vector2=d.pos+Vector2(0,sin(clock*2.8+d.id)*3)
		var fade: float=smoothstep(0,.14,d.age)
		if d.type=="coin":
			var height: float=48 if d.amount>=40 else 40
			shadow(p,height*.44)
			draw_circle(p,29,Color(1,.63,.13,.045*fade))
			draw_circle(p,23,Color(1,.74,.23,.08*fade))
			icon("coin",int(clock*10+d.id*.7)%8,p,height,fade)
			var gleam: float=pow(maxf(0,sin(clock*2.6+d.id)),12)*fade
			star(p+Vector2(12,-14),5,Color(1,.97,.70,gleam))
		else:
			shadow(p,27)
			draw_colored_polygon(PackedVector2Array([Vector2(p.x-23,638),Vector2(p.x+23,638),Vector2(p.x+7,468),Vector2(p.x-7,468)]),Color(.22,1,.57,.055*fade))
			draw_circle(p,42,Color(.10,.95,.55,.04*fade))
			draw_circle(p,32,Color(.25,1,.65,.06*fade))
			icon("potion",0,p,62,fade,sin(clock*2+d.id)*.035)
			for j in 3:
				var u: float=fposmod(clock*.38+j/3.0,1)
				star(p+Vector2(sin(j*2.2+clock)*20,-20-u*37),2.4,Color(.76,1,.73,sin(u*PI)*.7*fade))
			var box:=Rect2(p+Vector2(-57,-65),Vector2(114,27))
			draw_style_box(label_box,box)
			draw_string(host.font,box.position+Vector2(17,20),"翡翠药露",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("e2f9c5"))
			if absf(host.player.position.x-p.x)<260:
				var text:="回复一半缺失生命" if host.rift.rank("spring")==0 else "回复%d%%缺失生命" % roundi(host.rift.heal_fraction()*100)
				var width: float=host.font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x
				draw_string_outline(host.font,p+Vector2(-width*.5,-75),text,HORIZONTAL_ALIGNMENT_LEFT,-1,14,4,Color("10291c"))
				draw_string(host.font,p+Vector2(-width*.5,-75),text,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("d0ffd1"))
	for b in bursts:
		var u: float=clampf(b.age/.60,0,1)
		var fade: float=1-smoothstep(.26,.78,b.age)
		var color:=Color("ffe393") if b.kind=="coin" else Color("a1ffcc")
		var radius: float=lerpf(6,43,ease(u,.6))
		draw_arc(b.pos,radius,0,TAU,48,Color(color,fade*.45),1.5,true)
		for j in 9:
			var a: float=j*TAU/9+b.seed*.31
			var r: float=radius*(.75+j%3*.21)
			var point: Vector2=b.pos+Vector2(cos(a)*r,sin(a)*r-u*30)
			star(point,(3.5 if j%3==0 else 2)*fade,Color(color,fade))
		if b.kind=="coin" and b.age<.44:
			var t: float=smoothstep(0,.44,b.age)
			var at: Vector2=b.pos.lerp(b.target,t)+Vector2(0,-sin(t*PI)*42)
			icon("coin",int(b.age*20)%8,at,lerpf(26,10,t),1-t*.65)
		elif b.kind=="heal":
			var target: Vector2=b.target+Vector2(0,-b.age*35)
			draw_arc(target,28+u*27,PI*.15,PI*.85,32,Color(color,fade*.75),2,true)
			star(target,8*fade,Color("e4ffce",fade))
