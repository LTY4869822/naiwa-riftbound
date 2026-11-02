extends Node2D
## Kenney CC0 masks plus authored timing, trajectories and warning geometry.
const CATALOG = preload("res://combat/enemy_catalog.gd")
const DIRT = preload("res://assets/enemies-expansion/vfx/dirt_02.png")
const SMOKE = preload("res://assets/enemies-expansion/vfx/smoke_05.png")
const MAGIC = preload("res://assets/enemies-expansion/vfx/magic_03.png")
const CIRCLE = preload("res://assets/enemies-expansion/vfx/circle_05.png")
const SLASH = preload("res://assets/enemies-expansion/vfx/slash_02.png")
const SPARK = preload("res://assets/enemies-expansion/vfx/spark_04.png")
const STAR = preload("res://assets/enemies-expansion/vfx/star_07.png")
const ORANGE := Color("ff9c70")
const GOLD := Color("ffd89a")
const PURPLE := Color("cd93d9")
const CYAN := Color("9ce1e9")
var host: Node
var masks: Dictionary={}
const MASK_BOUNDS := {
	"dirt_02.png":Rect2(43,81,387,372),"smoke_05.png":Rect2(72,66,369,344),
	"magic_03.png":Rect2(26,27,460,458),"circle_05.png":Rect2(142,142,228,228),
	"slash_02.png":Rect2(98,249,316,190),"spark_04.png":Rect2(77,100,327,293),
	"star_07.png":Rect2(102,103,308,307),
}

func _process(_dt: float) -> void:
	visible=host.mode=="battle"
	if visible: queue_redraw()

func fade(color: Color, alpha: float) -> Color:
	return Color(color.r,color.g,color.b,clampf(alpha,0,1))

func stamp(texture: Texture2D, at: Vector2, size: Vector2, color: Color, angle: float=0.0) -> void:
	if is_instance_valid(host.get("enemy_fx")): return
	if color.a<0.01: return
	var key: String=texture.resource_path.get_file()
	if not masks.has(key):
		var atlas := AtlasTexture.new()
		atlas.atlas=texture
		atlas.region=MASK_BOUNDS[key]
		atlas.filter_clip=true
		masks[key]=atlas
	draw_set_transform(at,angle)
	draw_texture_rect(masks[key],Rect2(-size/2,size),false,color)
	draw_set_transform(Vector2.ZERO)

func diamond(at: Vector2, direction: Vector2, size: float, color: Color) -> void:
	if size<0.25 or color.a<0.01: return
	var side := Vector2(-direction.y,direction.x)
	draw_set_transform(at)
	draw_colored_polygon(PackedVector2Array([direction*size,side*size*0.25,-direction*size*0.6,-side*size*0.25]),color)
	draw_set_transform(Vector2.ZERO)

func ground_ring(at: Vector2, radius: float, progress: float) -> void:
	draw_set_transform(at,0,Vector2(1,0.20))
	draw_circle(Vector2.ZERO,radius,fade(ORANGE,0.07+0.09*progress))
	draw_arc(Vector2.ZERO,radius,0,TAU,64,fade(ORANGE,0.8),2.0,true)
	draw_arc(Vector2.ZERO,radius*progress,-PI/2,TAU-PI/2,64,fade(GOLD,0.9),1.5,true)
	draw_set_transform(Vector2.ZERO)
	for side in [-1,1]:
		draw_line(at+Vector2(side*radius,-7),at+Vector2(side*radius,7),ORANGE,1.5,true)

func species(e: Node) -> void:
	var color: Color=CATALOG.DATA[e.kind].color
	var top: float=e.hurtbox().position.y-18
	var label_at := Vector2(e.position.x,top)
	var name: String=CATALOG.title(e.kind)
	var width: float=host.font.get_string_size(name,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x
	draw_string_outline(host.font,label_at-Vector2(width/2,0),name,HORIZONTAL_ALIGNMENT_LEFT,-1,12,3,Color("102b32"))
	draw_string(host.font,label_at-Vector2(width/2,0),name,HORIZONTAL_ALIGNMENT_LEFT,-1,12,fade(color,0.95))
	if e.hp<e.maximum:
		var p := label_at+Vector2(-30,7)
		draw_line(p,p+Vector2(60,0),Color("112e34"),5,true)
		draw_line(p,p+Vector2(60*float(e.hp)/e.maximum,0),color,3,true)
	if e.state=="tell":
		var t: float=clampf(e.timer/e.windup_duration(),0,1)
		var icon := label_at+Vector2(0,-22)
		draw_arc(icon,9,-PI/2,-PI/2+TAU*t,28,ORANGE,2,true)
		draw_line(icon+Vector2(0,-4),icon+Vector2(0,2),GOLD,2,true)
		draw_circle(icon+Vector2(0,5),1,GOLD)
		match e.kind:
			"beetle":
				var left: float=e.position.x-82 if e.facing>0 else e.position.x-272
				draw_rect(Rect2(left,635,354,7),fade(ORANGE,0.18+t*0.3))
				draw_line(Vector2(left,640),Vector2(left+354,640),fade(ORANGE,0.8),1.5,true)
				for i in 3:
					var x: float=e.position.x+e.facing*(100+i*52)
					draw_polyline(PackedVector2Array([Vector2(x-e.facing*7,626),Vector2(x,631),Vector2(x-e.facing*7,636)]),fade(GOLD,0.35+0.6*t),2,true)
				stamp(SPARK,e.position+Vector2(e.facing*77,-49),Vector2.ONE*(20+t*24),fade(GOLD,t*0.7),t*0.6)
			"shaman":
				ground_ring(Vector2(e.target.x,640),66,t*0.75)
				var hand: Vector2=e.position+Vector2(e.facing*55,-126)
				stamp(MAGIC,hand,Vector2.ONE*(24+t*43),fade(PURPLE,t*0.7),e.timer*1.2)
				for i in 5:
					var axis := Vector2.from_angle(i*TAU/5+e.timer*2)
					stamp(STAR,hand+axis*(36-24*t),Vector2.ONE*11,fade(GOLD,t))
			"raven":
				ground_ring(Vector2(e.target.x,640),53,t)
				draw_dashed_line(e.position+Vector2(0,-90),Vector2(e.target.x,590),fade(ORANGE,0.25+t*0.35),1.0,9,true)
				stamp(SLASH,e.position+Vector2(e.facing*30,-85),Vector2(52+t*25,28),fade(CYAN,t*0.8),e.facing*0.65)
	elif e.state=="active" and e.kind=="beetle":
		stamp(SLASH,e.position+Vector2(e.facing*77,-56),Vector2(80,105),fade(GOLD,0.75),0 if e.facing>0 else PI)
	elif e.state=="active" and e.kind=="raven":
		stamp(SLASH,e.position+Vector2(e.facing*18,-65),Vector2(125,60),fade(CYAN,0.85),e.facing*0.7)

func effect(e: Dictionary) -> void:
	var a: float=clampf(e.life/e.max,0,1)
	var t: float=1-a
	var p: Vector2=e.pos
	var facing: int=e.facing
	match e.type:
		"thorn_launch":
			stamp(SPARK,p,Vector2(120,80)*(0.5+t),fade(GOLD,a),0 if facing>0 else PI)
			for i in 6:
				var axis := Vector2.from_angle(i*0.39-PI*0.35)
				axis.x*=facing
				diamond(p+axis*t*92,axis,14*a,fade(GOLD,a))
		"thorn_dust":
			stamp(SMOKE,p+Vector2(-facing*t*37,-t*15),Vector2(46,25)*(0.5+t),fade(Color("c6ba89"),a*0.4),t*0.3)
			stamp(DIRT,p+Vector2(-facing*t*45,-t*14),Vector2(42,24)*(0.6+t),fade(GOLD,a*0.5))
		"armor_spark":
			stamp(SPARK,p,Vector2.ONE*(45+t*40),fade(GOLD,a),t)
			for i in 5:
				var axis := Vector2.from_angle(i*1.4+0.5)
				diamond(p+axis*t*62,axis,12*a,fade(GOLD,a))
		"spore_cast":
			stamp(MAGIC,p,Vector2.ONE*(50+t*64),fade(PURPLE,a*0.7),t*1.2)
			stamp(STAR,p,Vector2.ONE*45*a,fade(GOLD,a))
		"spore_burst":
			stamp(CIRCLE,p,Vector2(150,35)*(0.6+t),fade(GOLD,a),0)
			stamp(MAGIC,p+Vector2(0,-55),Vector2(118,143)*(0.65+t),fade(PURPLE,a*0.55),t*0.4)
			for i in 9:
				var axis := Vector2(sin(i*2.39),-0.6-absf(cos(i*1.7)))
				var at := p+axis*(12+t*79)
				stamp(SMOKE,at,Vector2.ONE*(24+t*45),fade(PURPLE,a*0.55),i+t)
				stamp(STAR,at,Vector2.ONE*(8+a*11),fade(GOLD,a),i)
			for i in 4:
				var at := p+Vector2((i-1.5)*23,-32-t*105)
				diamond(at,Vector2.UP,24*a,fade(PURPLE,a*0.9))
		"raven_launch", "raven_trail":
			var launch: bool=e.type=="raven_launch"
			stamp(SLASH,p+Vector2(-facing*t*22,0),Vector2(110 if launch else 65,55 if launch else 28)*(0.7+t*0.4),fade(CYAN,a*(0.7 if launch else 0.35)),facing*0.65)
			for i in (7 if launch else 2):
				var axis := Vector2(-facing*(0.3+i*0.13),-0.6+sin(i*2.3))
				var at := p+axis*(8+t*82)
				diamond(at,Vector2.from_angle(facing*0.5+i*0.25),12*a,fade(CYAN,a*0.75))

func _draw() -> void:
	if host==null or host.mode!="battle": return
	for e in host.enemies:
		if is_instance_valid(e) and not e.dead and not e.boss and CATALOG.expanded(e.kind): species(e)
	if is_instance_valid(host.spore_field):
		for field in host.spore_field.fields:
			if field.age<host.spore_field.WARNING:
				ground_ring(field.pos,66,0.75+0.25*field.age/host.spore_field.WARNING)
	for e in host.effects:
		if e.type in ["thorn_launch","thorn_dust","armor_spark","spore_cast","spore_burst","raven_launch","raven_trail"]: effect(e)
