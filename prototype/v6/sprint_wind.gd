extends Node2D
## World-space snapshots and wind follow actual displacement, never the collider.
var host: Node
var ghosts: Array[Dictionary]=[]
var trails: Array[Dictionary]=[]
var previous:=Vector2.ZERO
var last_actor:=0
var sample_clock:=0.0
var wind_clock:=0.0
var clock:=0.0
const LIMIT:=8

func clear() -> void:
	ghosts.clear()
	trails.clear()
	last_actor=0
	sample_clock=0
	wind_clock=0
	queue_redraw()

func _physics_process(dt: float) -> void:
	visible=host.mode=="battle" and not host.over
	if not host.playing() or host.hitstop>0: return
	advance(dt)

func advance(dt: float) -> void:
	clock+=dt
	for bank in [ghosts,trails]:
		for i in range(bank.size()-1,-1,-1):
			bank[i].age+=dt
			if bank[i].age>=bank[i].life: bank.remove_at(i)
	if not is_instance_valid(host.player): return
	var p: Node=host.player
	if p.get_instance_id()!=last_actor:
		previous=p.position
		last_actor=p.get_instance_id()
	var distance: float=absf(p.position.x-previous.x)
	var moving: bool=distance>0.5 and distance<80
	previous=p.position
	var dash: bool=p.state=="dash" and moving
	var run: bool=p.state=="idle" and moving and absf(p.velocity.x)>130
	sample_clock-=dt
	wind_clock-=dt
	if dash and sample_clock<=0:
		var rig: Node=host.stage.actors.get(p.get_instance_id())
		if rig!=null and rig.state=="dash":
			if ghosts.size()>=LIMIT: ghosts.pop_front()
			var drawn: Sprite2D=rig.ascended.first if host.ascension.empowered() else rig.sprite
			ghosts.append({"pos":p.position,"offset":drawn.position,"scale":drawn.scale,"texture":drawn.texture,"age":0.0,"life":0.19 if host.reduce_motion else 0.24})
			sample_clock=0.045 if host.reduce_motion else 0.028
	if (dash or run) and wind_clock<=0:
		if trails.size()>=12: trails.pop_front()
		trails.append({"pos":p.position,"facing":p.facing,"dash":dash,"age":0.0,"life":0.27 if dash else 0.15})
		wind_clock=0.045 if dash else 0.12
	queue_redraw()

func _draw() -> void:
	for g in ghosts:
		var fade: float=pow(1.0-g.age/g.life,1.5)
		draw_set_transform(g.pos+g.offset,0,g.scale)
		draw_texture(g.texture,Vector2.ZERO,Color(0.55,1.0,0.86,fade*(0.10 if host.reduce_motion else 0.24)))
		draw_set_transform(Vector2.ZERO)
	for trail in trails:
		var t: float=trail.age/trail.life
		var fade: float=pow(1-t,1.2)
		var side: int=trail.facing
		var length: float=(185 if trail.dash else 55)*(0.70+t*0.45)
		var root: Vector2=trail.pos+Vector2(-side*8,-94)
		for i in (4 if trail.dash else 2):
			var points:=PackedVector2Array()
			for j in 17:
				var u: float=j/16.0
				var curl: float=sin(u*PI)*(9+i*3)*(1 if i%2 else -1)
				points.append(root+Vector2(side*(35-u*length),-42+i*27+curl+t*(i-1.5)*12))
			draw_polyline(points,Color(0.06,0.22,0.25,fade*0.38),4.5 if trail.dash else 2,true)
			draw_polyline(points,Color(0.57,0.96,0.88,fade*(0.65 if trail.dash else 0.25)),2.2 if trail.dash else 1,true)
			if trail.dash: draw_polyline(points,Color(0.93,1.0,0.91,fade*0.75),0.8,true)
		if trail.dash:
			# A short compressed air arc travels behind the shoulder; it never flashes the screen.
			var arc:=PackedVector2Array()
			for i in 20:
				var a: float=lerpf(-1.20,1.20,i/19.0)
				arc.append(root+Vector2(side*(cos(a)*23-52-t*45),sin(a)*73))
			draw_polyline(arc,Color(0.72,1.0,0.91,fade*0.5),2.1,true)
