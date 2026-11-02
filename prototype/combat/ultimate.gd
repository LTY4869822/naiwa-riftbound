extends Node2D
## A traveling, piercing punch wave. Uses unmodified Effekseer/tktk CC0 parts.
## All actor images remain on their original, uniformly scaled Sprite2D.
const SPEED := 1250.0
const RANGE := 740.0
const HALF_HEIGHT := 67.0
const GOLD := Color("ffc969")
const CORE := Color("fff4d5")
const TEAL := Color("78e9d7")
const INK := Color("153b42")
const BURST = preload("res://assets/ultimate/Burst01.png")
const ENERGY = preload("res://assets/ultimate/ElectricBall.png")
const RING = preload("res://assets/ultimate/Shockwave.png")
const BEAM = preload("res://assets/ultimate/LaserMain01.png")
const STREAK = preload("res://assets/ultimate/Shock_wave_ring001.png")
const LINES = preload("res://assets/ultimate/actionlines.png")
var host: Node
var waves: Array[Dictionary] = []
var bursts: Array[Dictionary] = []
var launch_count := 0
var hit_count := 0
var clock := 0.0
var glow: Node2D
var background: ColorRect
var background_copy: BackBufferCopy
var background_material: ShaderMaterial
var ripple_time := 1.0
var ripple_at := Vector2.ZERO

func _ready() -> void:
	glow=Node2D.new()
	var additive:=ShaderMaterial.new()
	additive.shader=preload("res://combat/ultimate_particle.gdshader")
	glow.material=additive
	glow.draw.connect(draw_glow)
	add_child(glow)
	# These siblings draw after the scenery, before enemies (z=3) and Naiwa (z=5).
	background_copy=BackBufferCopy.new()
	background_copy.copy_mode=BackBufferCopy.COPY_MODE_VIEWPORT
	background_copy.z_index=1
	host.stage.add_child(background_copy)
	background=ColorRect.new()
	background.position=Vector2(-24,-24)
	background.size=Vector2(1328,848)
	background.mouse_filter=Control.MOUSE_FILTER_IGNORE
	background.z_index=2
	background_material=ShaderMaterial.new()
	background_material.shader=preload("res://combat/ultimate_background.gdshader")
	background.material=background_material
	host.stage.add_child(background)
	background.hide()
	background_copy.hide()

func _process(dt: float) -> void:
	advance(dt)

func charging() -> bool:
	return host.mode=="battle" and not host.over and is_instance_valid(host.player) and host.player.state=="skill" and not host.player.skill_fired

func clear() -> void:
	waves.clear()
	bursts.clear()
	ripple_time=1.0
	if is_instance_valid(background): background.hide()
	if is_instance_valid(background_copy): background_copy.hide()
	queue_redraw()
	if is_instance_valid(glow): glow.queue_redraw()

func launch(origin: Vector2, facing: int, rear_limit: float=INF) -> void:
	launch_count+=1
	waves.append({"origin":origin,"pos":origin,"facing":facing,"travel":0.0,
		"age":0.0,"hit_ids":[],"damage":roundi(Profile.damage()*5.2*host.rift.attack_boost()),
		"rear_limit":origin.x-facing*85 if is_inf(rear_limit) else rear_limit})
	bursts.append({"pos":origin,"age":0.0,"duration":0.32,"facing":facing,"launch":true})
	ripple_at=origin
	ripple_time=0.0
	host.trauma=maxf(host.trauma,0.35)
	host.play_sound("ultimate_launch",-13,1.0)

func advance(dt: float) -> void:
	visible=host.mode=="battle"
	if not host.playing():
		background.visible=visible and background.visible
		background_copy.visible=background.visible
		return
	if host.hitstop>0:
		update_background()
		return
	clock+=dt
	ripple_time+=dt
	for i in range(bursts.size()-1,-1,-1):
		bursts[i].age+=dt
		if bursts[i].age>=bursts[i].duration: bursts.remove_at(i)
	for i in range(waves.size()-1,-1,-1):
		var w: Dictionary=waves[i]
		var from: Vector2=w.pos
		var distance: float=minf(SPEED*dt,RANGE-float(w.travel))
		w.travel+=distance
		w.age+=dt
		w.pos=w.origin+Vector2(w.facing*w.travel,0)
		# Swept hitbox avoids tunneling at low frame rates, including the launch point.
		var rect:=Rect2(Vector2(minf(from.x,w.pos.x)-12,w.pos.y-HALF_HEIGHT),Vector2(absf(w.pos.x-from.x)+24,HALF_HEIGHT*2))
		for e in host.enemies:
			if not is_instance_valid(e) or e.dead or e.eid in w.hit_ids: continue
			if (e.position.x-w.rear_limit)*w.facing < -8: continue
			if not rect.intersects(e.hurtbox()): continue
			w.hit_ids.append(e.eid)
			var bounds: Rect2=e.hurtbox()
			var point:=Vector2(clampf(w.pos.x,bounds.position.x+8,bounds.end.x-8),clampf(w.pos.y,bounds.position.y+8,bounds.end.y-8))
			var previous_hp: int=e.hp
			e.take_hit(w.damage,w.facing,true)
			if previous_hp-e.hp<=0: continue
			hit_count+=1
			host.impact(point,w.facing,true,false,"ultimate",not w.get("impact_pulse",false))
			w.impact_pulse=true
			bursts.append({"pos":point,"age":0.0,"duration":0.42,"facing":w.facing,"launch":false})
			host.float_number(point+Vector2(0,-35),str(previous_hp-e.hp),CORE)
			if not e.dead: host.stage.sync(e,0.001)
			host.refresh_hud()
		if w.travel>=RANGE or w.pos.x < -100 or w.pos.x > 1380: waves.remove_at(i)
	update_background()
	queue_redraw()
	glow.queue_redraw()

func update_background() -> void:
	var charge:=charging()
	var ripple: bool=ripple_time<0.34 and not host.reduce_motion
	background.visible=(charge or ripple) and host.mode=="battle"
	background_copy.visible=background.visible
	if not background.visible: return
	var canvas_size: Vector2=host.get_viewport_rect().size
	background.size=canvas_size+Vector2(48,48)
	var progress: float=clampf(host.player.elapsed/host.player.SKILL_RELEASE,0,1) if charge else 0.0
	background_material.set_shader_parameter("dimming",0.10+progress*0.12 if charge else 0.11*(1-ripple_time/0.34))
	background_material.set_shader_parameter("center",(ripple_at+host.stage.position)/canvas_size)
	background_material.set_shader_parameter("canvas_size",canvas_size)
	background_material.set_shader_parameter("radius_px",35+ripple_time*1030)
	background_material.set_shader_parameter("strength",0.0 if host.reduce_motion else (1-ripple_time/0.34 if ripple else 0.0))

func alpha(c: Color, value: float) -> Color:
	return Color(c,clampf(value,0,1))

func line(c: CanvasItem, a: Vector2, b: Vector2, color: Color, width: float) -> void:
	if color.a>0.01 and width>0.1: c.draw_line(a,b,color,width,true)

func shard(c: CanvasItem, p: Vector2, angle: float, length_px: float, width: float, color: Color) -> void:
	if color.a<0.01 or length_px<0.3 or width<0.15: return
	var d:=Vector2.from_angle(angle)
	var n:=d.orthogonal()
	c.draw_colored_polygon(PackedVector2Array([p+d*length_px,p+n*width,p-d*length_px*0.5,p-n*width]),color)

func crescent(p: Vector2, facing: int, radius: Vector2, thickness: float, color: Color) -> void:
	var outer:=PackedVector2Array()
	var inner:=PackedVector2Array()
	for i in 33:
		var t: float=i/32.0
		var a:=lerpf(-1.42,1.42,t)
		var n:=Vector2(cos(a)*facing,sin(a))
		var width:=sin(t*PI)*thickness
		outer.append(p+n*radius)
		inner.append(p+n*(radius-Vector2(width,width)))
	inner.reverse()
	outer.append_array(inner)
	draw_colored_polygon(outer,color)

func _draw() -> void:
	if not is_instance_valid(host.player): return
	if charging():
		var p: Vector2=host.stage.hand_position(host.player)
		var progress: float=clampf(host.player.elapsed/host.player.SKILL_RELEASE,0,1)
		var ground: Vector2=host.player.position
		draw_set_transform(ground,0,Vector2(1,0.20))
		draw_arc(Vector2.ZERO,43+progress*25,PI*0.05,PI*1.95,64,alpha(TEAL,progress*0.60),2,true)
		draw_arc(Vector2.ZERO,28+progress*18,-clock*4,-clock*4+PI*1.4,48,alpha(GOLD,0.7*progress),3,true)
		draw_set_transform(Vector2.ZERO)
		for i in 12:
			var a:=i*TAU/12.0+clock*1.1
			var phase:=fmod(progress*2.0+i*0.137,1.0)
			var r:=lerpf(87,14,phase)*(0.6+progress*0.4)
			line(self,p+Vector2.from_angle(a)*r,p+Vector2.from_angle(a)*(r+10+progress*13),alpha(TEAL if i%3==0 else GOLD,phase*progress),1.5)
		draw_arc(p,15+(1-progress)*19,clock*2,clock*2+PI*1.3,40,alpha(CORE,progress*0.8),1.5,true)
	for w in waves:
		var p: Vector2=w.pos
		var f: int=w.facing
		var fade:=clampf((RANGE-float(w.travel))/110,0,1)
		var rise:=clampf(float(w.age)/0.05,0,1)
		var power:=fade*rise
		var length_px:=minf(190,float(w.travel)+35)
		# Broken silhouette and contrasting edge retain direction against a bright scene.
		crescent(p,f,Vector2(52,79),16,alpha(INK,power*0.8))
		crescent(p+Vector2(f*3,0),f,Vector2(48,73),10,alpha(TEAL,power))
		crescent(p+Vector2(f*9,0),f,Vector2(38,58),12,alpha(GOLD,power))
		crescent(p+Vector2(f*14,0),f,Vector2(29,40),6,alpha(CORE,power))
		for i in 7:
			var y: float=(i-3)*18
			var tail: float=length_px*(0.55+0.45*sin(i*2.1+1))
			var head:=p+Vector2(-f*(18+absf(y)*0.6),y)
			line(self,head-Vector2(f*tail,0),head,alpha(TEAL if i%2==0 else GOLD,0.65*power),2 if i%2==0 else 3)
		shard(self,p+Vector2(f*34,0),0 if f==1 else PI,40,6,alpha(CORE,power))
	for b in bursts:
		var t: float=b.age/b.duration
		var p: Vector2=b.pos
		var power:=pow(1-t,1.4)
		for i in 11:
			var a:=i*TAU/11+0.17
			var distance:=15+t*(75+(i%3)*17)
			shard(self,p+Vector2.from_angle(a)*distance,a,lerpf(23,2,t),2.5*power,alpha(TEAL if i%3==0 else GOLD,power))
		if not b.launch and t<0.55:
			draw_arc(p,18+t*120,0,TAU,64,alpha(TEAL,0.6*(1-t/0.55)),2,true)
		if t<0.38:
			shard(self,p,0,75*(1-t/0.38),7*power,alpha(CORE,power))
			shard(self,p,PI/2,53*(1-t/0.38),5*power,alpha(CORE,power))

func texture_at(tex: Texture2D, p: Vector2, size: Vector2, color: Color, angle: float=0) -> void:
	glow.draw_set_transform(p,angle)
	glow.draw_texture_rect(tex,Rect2(-size*0.5,size),false,color)
	glow.draw_set_transform(Vector2.ZERO)

func draw_glow() -> void:
	if not is_instance_valid(host.player): return
	if charging():
		var progress: float=clampf(host.player.elapsed/host.player.SKILL_RELEASE,0,1)
		var p: Vector2=host.stage.hand_position(host.player)
		texture_at(ENERGY,p,Vector2.ONE*(18+progress*37),alpha(GOLD,0.72*progress),clock*1.7)
		texture_at(RING,host.player.position,Vector2(130,23)*(0.7+progress*0.3),alpha(TEAL,0.15*progress))
	for w in waves:
		var fade:=clampf((RANGE-float(w.travel))/110,0,1)
		var f: int=w.facing
		var p: Vector2=w.pos
		var rise:=clampf(float(w.age)/0.06,0,1)
		var power:=rise*fade
		texture_at(ENERGY,p+Vector2(f*16,0),Vector2(94,94),alpha(GOLD,0.5*power),clock*2)
		texture_at(BEAM,p-Vector2(f*72,0),Vector2(21,185),alpha(CORE,0.43*power),PI/2)
		texture_at(STREAK,p-Vector2(f*75,0),Vector2(112,175),alpha(TEAL,0.23*power),PI/2 if f==1 else -PI/2)
		texture_at(LINES,p-Vector2(f*110,0),Vector2(100,170),alpha(GOLD,0.16*power),PI/2)
	for b in bursts:
		var t: float=b.age/b.duration
		var size: float=lerpf(44,190,t)
		var p: Vector2=b.pos
		texture_at(BURST,p,Vector2(size,size),alpha(GOLD,pow(1-t,2.0)*0.62),PI/2 if b.facing==1 else -PI/2)
		texture_at(ENERGY,p,Vector2.ONE*lerpf(43,82,t),alpha(CORE,pow(1-t,3.0)*0.48))
		texture_at(RING,p,Vector2.ONE*(24+t*155),alpha(TEAL,pow(1-t,2)*0.16))
