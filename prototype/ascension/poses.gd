extends Node2D
## Crisp complete poses share a measured pivot; disjoint reveal masks avoid ghosts.
const MANIFEST:="res://assets/ascension/manifest.json"
static var data: Dictionary={}
static var cache: Dictionary={}
var rig: Node2D
var first: Sprite2D
var second: Sprite2D
var join: Sprite2D
var outgoing: Sprite2D
var last_phase:="dormant"
var reveal_in: ShaderMaterial
var reveal_out: ShaderMaterial
var max_ground_error:=0.0

func _ready() -> void:
	if data.is_empty(): data=JSON.parse_string(FileAccess.get_file_as_string(MANIFEST)).assets
	var fresh: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/loop-v2/manifest.json"))
	for key in fresh: data["hero/"+key+"-v2.png"]=fresh[key]
	first=make_sprite()
	second=make_sprite()
	join=make_sprite()
	outgoing=make_sprite()
	reveal_in=ShaderMaterial.new()
	reveal_in.shader=preload("res://loop/armor_reveal.gdshader")
	reveal_out=ShaderMaterial.new()
	reveal_out.shader=reveal_in.shader
	reveal_out.set_shader_parameter("outgoing",true)

func make_sprite() -> Sprite2D:
	var s:=Sprite2D.new()
	s.centered=false
	s.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(s)
	return s

static func entry(file: String, index: int) -> Dictionary:
	var key:=file+":"+str(index)
	if not cache.has(key):
		var d: Dictionary=data[file].frames[index]
		var a:=AtlasTexture.new()
		a.atlas=load(data[file].file)
		a.region=Rect2(d.region[0],d.region[1],d.region[2],d.region[3])
		a.filter_clip=true
		cache[key]={"texture":a,"meta":d}
	return cache[key]

func pose(s: Sprite2D, file: String, index: int, factor: float, alpha: float) -> Dictionary:
	var item:=entry(file,index)
	var d: Dictionary=item.meta
	s.texture=item.texture
	s.scale=Vector2(rig.direction*factor,factor)
	s.position=Vector2(-rig.direction*float(d.pivot[0])*factor,-float(d.pivot[1])*factor)
	s.modulate.a=alpha
	s.visible=alpha>0.001
	max_ground_error=maxf(max_ground_error,absf(s.position.y+float(d.pivot[1])*factor))
	return d

func clear() -> void:
	first.visible=false
	second.visible=false
	join.visible=false
	outgoing.visible=false
	rig.sprite.modulate.a=1
	rig.sprite.visible=true
	rig.sprite.material=null
	first.material=null
	join.material=null

func drive(power: Node, dt: float, state: String, progress: float, speed: float) -> void:
	clear()
	var phase: String=power.phase
	last_phase=phase
	if phase in ["ignite","dissolve"]:
		var t: float=clampf(power.age/power.INTRO,0,1) if phase=="ignite" else 1-smoothstep(0,1,power.age/power.OUTRO)
		rig.show_frame(0)
		rig.sprite.visible=t<0.18
		var frame:=clampi(floori(t*8),0,7)
		var height:=lerpf(211,260,smoothstep(0,1,t))
		var a: Dictionary=data["hero/morph-v2.png"].frames[frame]
		pose(first,"hero/morph-v2.png",frame,height/float(a.height),1)
		if t<0.18:
			var reveal:=smoothstep(0,0.18,t)
			reveal_in.set_shader_parameter("progress",reveal)
			reveal_out.set_shader_parameter("progress",reveal)
			rig.sprite.material=reveal_out
			first.material=reveal_in
		if t>0.86:
			var reveal:=smoothstep(0.86,1,t)
			reveal_in.set_shader_parameter("progress",reveal)
			reveal_out.set_shader_parameter("progress",reveal)
			first.material=reveal_out
			pose(join,"hero/combat-v2.png",0,260.0/float(data["hero/combat-v2.png"].frames[0].height),1)
			join.material=reveal_in
		metadata(height)
		return
	rig.sprite.visible=false
	var file:="hero/combat-v2.png"
	var frame:=0
	if phase=="finisher": frame=6 if power.age<0.52 else 2 if power.age<1.10 else 7 if power.age<1.60 else 3 if power.age<1.85 else 0
	elif state=="dash" or state=="run":
		file="hero/run-v2.png"
		frame=clampi(floori(progress*8),0,7) if state=="dash" else int(rig.cycle*14)%8
	elif state.begins_with("attack"):
		var id:=int(state.right(1))
		var clips: Array=[[0,1,2,3,0],[3,4,5,3,0],[0,6,7,3,0]]
		var contact: float=[0.237,0.273,0.304][id]
		var end_contact: float=[0.474,0.523,0.518][id]
		frame=clips[id][0 if progress<0.04 else 1 if progress<contact else 2 if progress<end_contact else 3 if progress<0.82 else 4]
	elif state=="hurt": frame=0
	rig.cycle+=dt*(clampf(absf(speed)/175,0.2,1.4) if state=="run" else 1.0)
	var scale_factor:=260.0/float(data["hero/combat-v2.png"].frames[0].height)
	if file=="hero/run-v2.png": scale_factor=245.0/float(data[file].frames[0].height)
	var d:=pose(first,file,frame,scale_factor,1)
	rig.current_frame_id=200+frame
	metadata(float(d.height)*scale_factor)

func metadata(height: float) -> void:
	var u: float=1.0/rig.factor
	rig.current={"anchor":[0.0,height*u],"hand":[170.0*u,(height-140)*u],"sole_y":height*u,"support_depth":0,"grounded":true,"feet":[{"point":[0.0,height*u],"depth":0,"width":40.0}]}
	rig.ground_error=0
