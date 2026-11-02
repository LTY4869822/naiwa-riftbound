extends Node2D
## Distinct, player-scale arenas. Platforms are player-only; monsters keep floor navigation.
var host: Node
var index:=0
var enabled:=true
var clock:=0.0
var cooldown:=7.0
var cycle:=0
var lamp_x:=-1000.0
var cleanse:=0.0
var lamp_cooldown:=0.0
var platforms: Array[Dictionary]=[]

func reset(level: int, chapter: int=0) -> void:
	index=level
	clock=0
	cooldown=7
	cycle=0
	cleanse=0
	lamp_cooldown=0
	platforms.clear()
	for child in get_children():
		remove_child(child)
		child.queue_free()
	if chapter>0:
		if level==0:
			if chapter==1: platform(360,580,150,"wood"); platform(910,590,160,"wood")
			else: platform(640,568,200,"wood")
		elif level==1:
			platform(430 if chapter==1 else 340,585,140,"stone")
			platform(930 if chapter==1 else 940,590,150,"stone")
		elif level==2:
			for x in ([260,640,1020] if chapter==1 else [420,860]): platform(x,590 if chapter==1 else 555,140,"stone")
		else:
			for x in ([820] if chapter==1 else [360,920]): platform(x,585,150,"stone")
	elif level==0: platform(570,606,178,"wood")
	elif level==2:
		platform(380,570,150,"stone")
		platform(900,570,150,"stone")
	queue_redraw()

func platform(x: float, top: float, width: float, material: String) -> void:
	var body:=StaticBody2D.new()
	body.collision_layer=8
	body.collision_mask=0
	body.position=Vector2(x,top+8)
	var shape:=CollisionShape2D.new()
	var box:=RectangleShape2D.new()
	box.size=Vector2(width,16)
	shape.shape=box
	shape.one_way_collision=true
	body.add_child(shape)
	add_child(body)
	platforms.append({"rect":Rect2(x-width/2,top,width,16),"material":material})

func _physics_process(dt: float) -> void:
	visible=host.mode=="battle"
	if not enabled or not host.playing() or host.hitstop>0: return
	clock+=dt
	cleanse=maxf(0,cleanse-dt)
	lamp_cooldown=maxf(0,lamp_cooldown-dt)
	if cleanse>0:
		for bank in [host.spore_field.fields,host.boss_fields.fields]:
			for i in range(bank.size()-1,-1,-1):
				if bank[i].get("style","spore") in ["spore","ultimate_spore"] and absf(bank[i].pos.x-lamp_x)<190 and not bank[i].get("fired",false): bank.remove_at(i)
	# Teaching beats stay calm; arena hazards begin once combat fundamentals are introduced.
	if host.wave<2 or host.over: queue_redraw(); return
	for e in host.enemies:
		if is_instance_valid(e) and not e.dead and e.state in ["ult_tell","ult_active"]: queue_redraw(); return
	cooldown-=dt
	if cooldown<=0:
		cycle+=1
		var owner: int=-100-index
		if index==1:
			var x: float=clampf(host.player.position.x+(135 if cycle%2 else -135),100,1180)
			host.boss_fields.cast(owner,Vector2(x,640),"spore",1.35,10,65)
			cooldown=9
		elif index==2:
			for x in [240,640,1040]: host.boss_fields.cast(owner,Vector2(x,640),"surge",1.6,14,175)
			host.toast("地面雷潮 · 跳上高台，或跃起避开电流")
			cooldown=10
		elif index==3:
			host.boss_fields.cast(owner,Vector2(320 if cycle%2 else 960,640),"heat",2.2,16,245)
			host.toast(("左侧" if cycle%2 else "右侧")+"过热 · 换到冷却区，或跃起避开热浪")
			cooldown=10
		else: cooldown=12
	queue_redraw()

func interact() -> void:
	if not enabled or not host.playing() or host.player.dead: return
	if index==1:
		var nearest: float=300 if absf(host.player.position.x-300)<absf(host.player.position.x-980) else 980
		if absf(host.player.position.x-nearest)>105:
			host.toast("靠近荧光净化灯，再按交互键")
			return
		if lamp_cooldown>0: host.toast("净化灯正在恢复 · %.0f 秒" % ceilf(lamp_cooldown)); return
		lamp_x=nearest
		cleanse=6
		lamp_cooldown=11
		host.toast("净化灯点亮 · 六秒内驱散附近尚未爆发的孢圈")
		host.play_sound("feed",-20,1.2)
	elif index==3 and absf(host.player.position.x-640)<110 and lamp_cooldown<=0:
		host.player.focus=minf(100,host.player.focus+20)
		lamp_cooldown=14
		host.toast("炉心散热 · +20 专注")
		host.refresh_hud()
	else: host.toast("此处没有可交互装置")

func _draw() -> void:
	for p in platforms:
		preload("res://biomes/props.gd").paint(self,index,p.rect)
	if index==1:
		for x in [300,980]:
			draw_line(Vector2(x,637),Vector2(x,583),Color("477f78"),7,true)
			draw_circle(Vector2(x,579),12,Color("adffe0"))
			draw_arc(Vector2(x,579),19,0,TAU,32,Color(0.5,1,0.8,0.45),2,true)
		if cleanse>0:
			draw_circle(Vector2(lamp_x,579),32,Color(0.34,1,0.73,0.10))
			draw_arc(Vector2(lamp_x,579),25,clock,clock+PI*1.4,40,Color("a3f9c8"),2,true)
	elif index==3:
		draw_rect(Rect2(617,613,46,27),Color("375862"))
		draw_line(Vector2(620,618),Vector2(660,618),Color("9cebcf") if lamp_cooldown<=0 else Color("7d9694"),5,true)
