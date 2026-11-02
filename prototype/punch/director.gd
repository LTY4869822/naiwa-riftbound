extends Node
## PixelFX color + additive light, attached to accepted contacts. Never applies damage.
const FLASH=preload("res://punch/flash.gdshader")
const MAX_BURSTS:=24
const MAX_FLOORS:=3
var host: Node
var data: Dictionary={}
var atlas: Dictionary={}
var bursts: Array[Dictionary]=[]
var floors: Array[Dictionary]=[]
var front: Node2D
var glow: Node2D
var ground: Node2D
var ground_glow: Node2D
var sound: Node
var cooldown:=0.0
var ground_cooldown:=0.0
var confirmed:=0
var pulses:=0
var clock:=0.0
var kick:=Vector2.ZERO
var kick_age:=1.0
func _ready() -> void:
	data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/pixelfx/manifest.json"))
	for key in data:
		var d: Dictionary=data[key]
		var color: Texture2D=load(d.file)
		var light: Texture2D=load(d.light)
		atlas[key]={"color":[],"light":[]}
		for rect in d.frames:
			for layer in ["color","light"]:
				var a:=AtlasTexture.new()
				a.atlas=color if layer=="color" else light
				a.region=Rect2(rect[0],rect[1],rect[2],rect[3]); a.filter_clip=true
				atlas[key][layer].append(a)
	front=Node2D.new(); front.z_index=22
	glow=Node2D.new(); glow.z_index=21
	ground=Node2D.new(); ground.z_index=2
	ground_glow=Node2D.new(); ground_glow.z_index=2
	var add:=CanvasItemMaterial.new(); add.blend_mode=CanvasItemMaterial.BLEND_MODE_ADD
	glow.material=add
	ground_glow.material=add
	for n in [front,glow,ground,ground_glow]: n.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	host.fx_node.add_child(front); host.fx_node.add_child(glow); host.stage.add_child(ground); host.stage.add_child(ground_glow)
	front.draw.connect(paint.bind(front,"color",false))
	glow.draw.connect(paint.bind(glow,"light",false))
	ground.draw.connect(paint.bind(ground,"color",true))
	ground_glow.draw.connect(paint.bind(ground_glow,"light",true))
	sound=preload("res://punch/audio.gd").new(); sound.host=host; add_child(sound)
func clear() -> void:
	bursts.clear(); floors.clear(); cooldown=0; ground_cooldown=0; kick=Vector2.ZERO; kick_age=1
	if is_instance_valid(sound): sound.clear()
	redraw()
func redraw() -> void:
	for n in [front,glow,ground,ground_glow]:
		if is_instance_valid(n): n.queue_redraw()
func spawn(key: String,point: Vector2,facing: int=1,scale_multiplier: float=1.0,on_floor: bool=false) -> void:
	var list: Array[Dictionary]=floors if on_floor else bursts
	var limit: int=MAX_FLOORS if on_floor else MAX_BURSTS
	if list.size()>=limit: list.pop_front()
	list.append({"key":key,"pos":point,"facing":facing,"age":0.0,"scale":scale_multiplier})
	redraw()
func contact(point: Vector2,facing: int,heavy: bool,hurt: bool=false,style: String="",pulse: bool=true) -> void:
	confirmed+=1
	var key: String=style if data.has(style) else "hurt" if hurt else "heavy" if heavy else "hit-gold"
	spawn(key,point,facing,.80 if host.reduce_motion else 1.0)
	if pulse: accent(facing,"hurt" if hurt else "break" if key=="break" else "heavy" if heavy else "light")
func accent(facing: int,role: String) -> void:
	# A crowd hit shares one audiovisual pulse. No accumulated 200 ms global freezes.
	if cooldown>0: return
	cooldown=.045; pulses+=1
	var stop: float=.058 if role=="heavy" else .048 if role=="break" else .042 if role=="hurt" else .026
	host.hitstop=maxf(host.hitstop,stop)
	host.trauma=maxf(host.trauma,.57 if role=="heavy" else .43 if role=="break" else .40 if role=="hurt" else .24)
	kick=Vector2(facing*(5.2 if role=="heavy" else 3.7 if role=="break" else 1.8),-1.5 if role=="heavy" else -.6)
	kick_age=0
	sound.trigger(role)
func floor_hit(point: Vector2,facing: int) -> void:
	if ground_cooldown>0: return
	ground_cooldown=.28
	spawn("ground",point,facing,.70,true)
func terrain(field: Dictionary) -> void:
	# Spell/ground contact is visual only; it is not a confirmed hit against the player.
	if field.has("rect") or str(field.style) in ["surge","heat"]: return
	spawn("ground",field.pos,1,clampf(float(field.radius)/120,.35,.85),true)
func evade() -> void:
	spawn("break",host.player.position+Vector2(host.player.facing*22,-118),host.player.facing,.75)
	sound.trigger("break")
func flash_actor(rig: Node,actor: Node) -> void:
	if not is_instance_valid(rig) or not is_instance_valid(rig.get("sprite")): return
	var sprite: Sprite2D=rig.sprite
	if sprite.material!=null and not sprite.material.get_meta("contact_flash",false): return
	if actor.flash<=0:
		if sprite.material!=null: sprite.material=null
		return
	if sprite.material==null:
		var material:=ShaderMaterial.new(); material.shader=FLASH; material.set_meta("contact_flash",true)
		sprite.material=material
	var amount: float=.20*actor.flash if host.reduce_motion else smoothstep(.25,1,actor.flash)*.56
	sprite.material.set_shader_parameter("amount",amount)
	sprite.material.set_shader_parameter("hit_color",Color("ffd7bd") if actor==host.player else Color("fff7dc"))
	rig.modulate=Color.WHITE
func camera_offset() -> Vector2:
	if host.reduce_motion: return Vector2.ZERO
	var shake: float=host.trauma*host.trauma
	var noise:=Vector2(sin(clock*42)*.65+sin(clock*71)*.35,cos(clock*37)*.65+cos(clock*59)*.35)
	var recoil:=kick*(exp(-kick_age*22)*cos(kick_age*30)) if kick_age<.32 else Vector2.ZERO
	return noise*Vector2(7,4)*shake+recoil
func _process(dt: float) -> void:
	var shown: bool=host.mode=="battle" and not host.over
	for n in [front,glow,ground,ground_glow]: n.visible=shown
	if not shown or not host.playing(): return
	cooldown=maxf(0,cooldown-dt); ground_cooldown=maxf(0,ground_cooldown-dt)
	clock+=dt; kick_age+=dt
	# Keep the key impact frame visible through hit-stop; particles then follow through.
	if host.hitstop<=0:
		for list in [bursts,floors]:
			for i in range(list.size()-1,-1,-1):
				list[i].age+=dt*(1.45 if list[i].key=="ground" else 1.18)
				if list[i].age>=float(data[list[i].key].duration): list.remove_at(i)
	redraw()
func paint(c: Node2D,layer: String,on_floor: bool) -> void:
	var list: Array[Dictionary]=floors if on_floor else bursts
	for b in list:
		var d: Dictionary=data[b.key]
		var i:=clampi(floori(b.age*float(d.fps)),0,d.frames.size()-1)
		var factor: float=float(d.scale)*float(b.scale)
		var pivot:=Vector2(d.pivot[0],d.pivot[1])
		var rect: Array=d.frames[i]
		var alpha: float=1-smoothstep(.68,float(d.duration),float(b.age)) if on_floor else 1.0
		if host.reduce_motion and layer=="light": continue
		c.draw_set_transform(b.pos,0,Vector2(int(b.facing)*factor,factor))
		c.draw_texture_rect(atlas[b.key][layer][i],Rect2(-pivot,Vector2(rect[2],rect[3])),false,Color(1,1,1,alpha*(.70 if layer=="light" else 1.0)))
	c.draw_set_transform(Vector2.ZERO)
