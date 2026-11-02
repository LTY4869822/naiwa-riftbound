extends Node2D
## Painted source art owns the silhouette; code only choreographs and telegraphs.
const CATALOG=preload("res://combat/enemy_catalog.gd")
const THEMES={"thorn_matriarch":"root","mirror_weaver":"eclipse","bell_colossus":"thunder","molten_wheel":"maw","boss":"root","mycelium_boss":"root","tempest_boss":"thunder","cinder_boss":"maw","zheng":"claw","zhuyin":"eclipse","yinglong":"thunder","paoxiao":"maw"}
const COLORS={"root":Color("b5e786"),"thunder":Color("96eaff"),"maw":Color("ffc77c"),"claw":Color("d3a0ff"),"eclipse":Color("ff8e9f")}
var host: Node
var director: Node
var atlas: Dictionary={}
var data: Dictionary={}
var backdrop: Node2D
var overlay: Control
var clock:=0.0
var reveal: ShaderMaterial

func _ready() -> void:
	z_index=16
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/rift-v4/manifest.json"))
	for key in data:
		atlas[key]=[]
		var source: Texture2D=load(data[key].file)
		for f in data[key].frames:
			var a:=AtlasTexture.new()
			a.atlas=source
			a.region=Rect2(f.region[0],f.region[1],f.region[2],f.region[3])
			a.filter_clip=true
			atlas[key].append(a)
	backdrop=Node2D.new()
	backdrop.z_index=2
	backdrop.texture_filter=texture_filter
	backdrop.draw.connect(paint_backdrop)
	host.stage.add_child(backdrop)
	var layer:=CanvasLayer.new()
	layer.layer=5
	add_child(layer)
	overlay=Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
	overlay.draw.connect(paint_caption)
	layer.add_child(overlay)
	reveal=ShaderMaterial.new()
	reveal.shader=preload("res://rift/reveal.gdshader")

func reveal_actor(e: Node, progress: float) -> void:
	var rig: Node=host.stage.actors.get(e.get_instance_id())
	if not is_instance_valid(rig): return
	rig.sprite.material=reveal
	reveal.set_shader_parameter("progress",progress)
	reveal.set_shader_parameter("center_x",e.position.x)
	reveal.set_shader_parameter("half_width",e.hurtbox().size.x*.6+85)
	reveal.set_shader_parameter("side",float(director.entrance.get("side",1)))

func _process(dt: float) -> void:
	visible=host.mode=="battle" and not host.over
	backdrop.visible=visible
	overlay.visible=visible and not host.paused and not host.route_open and not director.entrance.is_empty()
	if host.mode!="battle" or host.paused or host.route_open: return
	if host.hitstop<=0: clock+=dt
	queue_redraw()
	backdrop.queue_redraw()
	overlay.queue_redraw()

func art(canvas: CanvasItem, key: String, frame: int, at: Vector2, size: Vector2, alpha: float=1.0, rotation_angle: float=0.0) -> void:
	if not atlas.has(key) or alpha<.005: return
	frame=clampi(frame,0,7)
	var f: Dictionary=data[key].frames[frame]
	var factor: Vector2=size/Vector2(data[key].reference[0],data[key].reference[1])
	var extent:=Vector2(f.region[2],f.region[3])*factor
	var pivot:=Vector2(f.pivot[0],f.pivot[1])*factor
	canvas.draw_set_transform(at,rotation_angle)
	canvas.draw_texture_rect(atlas[key][frame],Rect2(-pivot,extent),false,Color(1,1,1,alpha))
	canvas.draw_set_transform(Vector2.ZERO)

func paint_backdrop() -> void:
	if not visible: return
	if not director.entrance.is_empty():
		var t: float=director.entrance.age
		var f:=clampi(int(t/.7*4),0,3) if t<.7 else 4+int(t*7)%2 if t<1.95 else 6+clampi(int((t-1.95)*3),0,1)
		backdrop.draw_rect(Rect2(-20,-20,1320,840),Color(.02,.008,.04,.28*sin(clampf(t/2.5,0,1)*PI)))
		art(backdrop,"portal",f,director.entrance.portal,Vector2(355,440),1-smoothstep(2.3,2.5,t))
	for e in host.enemies:
		if not is_instance_valid(e) or e.dead or not e.boss: continue
		if e.state=="tell" and e.move_id==5:
			var fade: float=smoothstep(0,.4,e.timer)
			for x in [e.position.x,float(e.attack_data.get("destination",e.position.x))]: art(backdrop,"portal",2,Vector2(x,490),Vector2(160,260),fade*.7)
		if e.state=="phase_shift": art(backdrop,"portal",3,e.position+Vector2(0,-155),Vector2(340,365),sin(clampf(e.timer/.8,0,1)*PI)*.8)

func warning(f: Dictionary, color: Color) -> void:
	var t:=clampf(f.age/maxf(.001,f.warning),0,1)
	var p: Vector2=f.pos
	draw_set_transform(p,0,Vector2(1,.17))
	draw_circle(Vector2.ZERO,f.radius,Color(.03,.01,.045,.45))
	draw_circle(Vector2.ZERO,f.radius*t,Color(color,.15))
	draw_arc(Vector2.ZERO,f.radius,0,TAU,64,Color(color,.8),2,true)
	draw_arc(Vector2.ZERO,maxf(1,f.radius*t),0,TAU,64,Color("fff3cf"),1.2,true)
	draw_set_transform(Vector2.ZERO)

func _draw() -> void:
	if not visible: return
	for f in host.boss_fields.fields:
		if str(f.style).begins_with("apex_"):
			var key: String=THEMES.get(str(f.style).trim_prefix("apex_"),"claw")
			var age: float=f.age-f.warning
			var at: Vector2=f.pos+Vector2(0,-140) if key=="eclipse" else f.pos
			var size:=Vector2(f.radius*2.6,410 if key=="thunder" else 310)
			if age<0:
				warning(f,COLORS[key])
				if age>-.28: art(self,key,0 if age<-.14 else 1,at,size,smoothstep(-.28,0,age)*.65)
			else:
				# The strike/contact frames coincide with the authoritative 0.18s damage interval.
				art(self,key,clampi(2+floori(age*12),2,7),at,size,1-smoothstep(.55,.8,age))
		elif f.has("rect") and str(f.style).begins_with("repertoire_beam_"):
			var area: Rect2=f.rect
			var beam_kind: String=str(f.style).trim_prefix("repertoire_beam_")
			var beam_color: Color=COLORS[THEMES.get(beam_kind,"thunder")]
			var age: float=f.age-f.warning
			if age<0:
				draw_rect(area,Color(.30,.80,1,.10))
				draw_line(area.position,Vector2(area.end.x,area.position.y),beam_color,1.5,true)
				draw_line(Vector2(area.position.x,area.end.y),area.end,beam_color,1.5,true)
			else:
				var at:=Vector2(area.end.x if f.facing<0 else area.position.x,area.get_center().y)
				if beam_kind in ["zhuyin","mirror_weaver"]: art(self,"eclipse",clampi(int(age*10),2,7),area.get_center(),Vector2(area.size.x,area.size.y*1.8),1-smoothstep(.4,.75,age))
				else: art(self,"thunder",clampi(int(age*10),2,7),at,Vector2(area.size.y*2.1,area.size.x),1-smoothstep(.4,.75,age),PI/2 if f.facing>0 else -PI/2)
	for p in host.projectiles:
		if not p.has("style") or p.get("biome_projectile",false): continue
		var key: String=THEMES.get(p.style,"claw")
		if p.get("ground_wave",false): art(self,key,3,p.pos+Vector2(0,28),Vector2(98,65),.9)
		else:
			var color: Color=COLORS[key]
			for j in 3: draw_circle(p.pos-p.velocity.normalized()*(j+1)*12,3-j*.6,Color(color,.4-j*.10))
			art(self,key,0,p.pos+(Vector2.ZERO if key=="eclipse" else Vector2(0,23)),Vector2(57,65),1.0)
	preload("res://biomes/vfx.gd").paint(self)
	var power: Node=host.ascension
	if power.phase=="finisher":
		var t: float=power.age
		var space: float=(1220-power.origin.x if power.side>0 else power.origin.x-60)
		var x: float=power.origin.x+power.side*clampf(space*.50,150,460)
		var at:=Vector2(x,640)
		if t<.52: art(self,"portal",clampi(int(t*7),0,3),at+Vector2(0,-165),Vector2(170,270),smoothstep(0,.35,t))
		else:
			art(self,"claw",clampi(int((t-.52)*5.4),0,7),at,Vector2(clampf(space,300,780),450),1-smoothstep(1.65,2,t))
			if t>1.18: art(self,"portal",6,at+Vector2(0,-170),Vector2(420,310),(1-smoothstep(1.18,1.80,t))*.5)

func paint_caption() -> void:
	if director.entrance.is_empty(): return
	var e: Node=director.entrance.actor.get_ref()
	if not is_instance_valid(e): return
	var t: float=director.entrance.age
	var alpha: float=smoothstep(.15,.6,t)*(1-smoothstep(2.1,2.5,t))
	overlay.draw_rect(Rect2(0,0,1280,23),Color(0,0,0,alpha*.9))
	overlay.draw_rect(Rect2(0,742,1280,58),Color(0,0,0,alpha*.9))
	var color:=Color("f3d8a0")
	overlay.draw_line(Vector2(88,305),Vector2(331,305),Color(color,alpha),3,true)
	overlay.draw_string(host.font,Vector2(88,285),"裂 界 降 临",HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color(color,alpha))
	overlay.draw_string_outline(host.font,Vector2(83,375),CATALOG.title(e.kind),HORIZONTAL_ALIGNMENT_LEFT,-1,54,9,Color(.04,.015,.06,alpha))
	overlay.draw_string(host.font,Vector2(83,375),CATALOG.title(e.kind),HORIZONTAL_ALIGNMENT_LEFT,-1,54,Color("fff4de",alpha))
	overlay.draw_string(host.font,Vector2(88,418),"三重封印  /  破势反击，踏碎荒神",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color(.83,.77,.9,alpha))
	overlay.draw_string(host.font,Vector2(1036,778),"Space  跳过登场",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color(.9,.85,.96,alpha))
