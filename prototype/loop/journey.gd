extends Node2D
## Three connected rooms share the SAME actor and vitals. Loot pays only on pickup.
var host: Node
var presentation: Node2D
var pickup_audio: Node
var drops: Array[Dictionary]=[]
var cleared:=false
var travelling:=false
var travel_age:=0.0
var clock:=0.0
var next_drop:=0
var stage_rewarded:=false
var clear_age:=0.0
var picked_coins:=0
var picked_heals:=0
var shade: ColorRect

func _ready() -> void:
	presentation=preload("res://loot/presentation.gd").new()
	presentation.host=host
	presentation.journey=self
	add_child(presentation)
	pickup_audio=preload("res://loot/pickup_audio.gd").new()
	pickup_audio.host=host
	add_child(pickup_audio)
	var layer:=CanvasLayer.new()
	layer.layer=40
	add_child(layer)
	shade=ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	shade.color=Color.TRANSPARENT
	layer.add_child(shade)

func reset() -> void:
	drops.clear()
	cleared=false
	travelling=false
	stage_rewarded=false
	clear_age=0
	picked_coins=0
	picked_heals=0
	travel_age=0
	next_drop=0
	if is_instance_valid(shade): shade.color=Color.TRANSPARENT
	if is_instance_valid(presentation): presentation.reset()
	queue_redraw()

func drop_enemy(e: Node) -> void:
	next_drop+=1
	drops.append({"id":next_drop,"run":host.run_reward_id,"type":"coin","amount":40 if e.boss else 8+e.eid%3*2,"pos":e.position+Vector2(0,-65),"velocity":Vector2(25 if e.eid%2 else -25,-165),"age":0.0,"retry":0.0})

func clear_room() -> void:
	if cleared: return
	cleared=true
	clear_age=0
	host.projectiles.clear()
	host.boss_fields.clear()
	host.spore_field.clear()
	host.enemy_fx.clear()
	if not stage_rewarded:
		stage_rewarded=true
		host.clear_reward=Wardrobe.award_clear(host.current_level().id,host.run_reward_id)
		Profile.wins+=1
		Profile.save_profile()
		if host.stage_index==2: host.completed_levels[host.level_index]=true
	next_drop+=1
	drops.append({"id":next_drop,"run":host.run_reward_id,"type":"heal","pos":Vector2(945,590),"velocity":Vector2.ZERO,"age":0.0,"retry":0.0})
	var recovery: String="回复一半缺失生命" if host.rift.rank("spring")==0 else "回复%d%%缺失生命" % roundi(host.rift.heal_fraction()*100)
	host.toast("区域肃清 · 药露"+recovery+"，走到右侧通路继续")
	host.refresh_hud()
	host.rift.offer()

func collect(drop: Dictionary) -> bool:
	if drop.type=="coin":
		var paid: Dictionary=Wardrobe.award_loot(drop.run,drop.id,drop.amount)
		if not paid.get("ok",false): return false
		if int(paid.get("amount",0))>0:
			picked_coins+=int(paid.amount)
			host.float_number(drop.pos,"+%d 金币" % drop.amount,Color("ffda75"))
		else: return true
	else:
		var before: int=host.player.hp
		if before>=Profile.max_health(): return false
		host.player.hp=mini(Profile.max_health(),before+maxi(1,roundi((Profile.max_health()-before)*host.rift.heal_fraction())))
		picked_heals+=1
		host.float_number(drop.pos,"+%d 生命" % (host.player.hp-before),Color("a9f2bf"))
	presentation.collected(drop)
	pickup_audio.trigger(drop.type)
	host.refresh_hud()
	return true

func _physics_process(dt: float) -> void:
	if host.mode!="battle" or host.paused or host.route_open or host.over or host.hitstop>0: return
	clock+=dt
	if travelling:
		travel_age+=dt
		shade.color=Color(0.025,0.015,0.05,sin(clampf(travel_age/0.55,0,1)*PI))
		if travel_age>=0.275 and cleared:
			cleared=false
			host.continue_room()
		if travel_age>=0.55:
			travelling=false
			shade.color=Color.TRANSPARENT
			host.player.state="idle"
		queue_redraw()
		return
	if not host.playing(): return
	if cleared: clear_age+=dt
	for i in range(drops.size()-1,-1,-1):
		var d: Dictionary=drops[i]
		d.age+=dt
		d.retry=maxf(0,d.retry-dt)
		if d.type=="coin":
			d.velocity.y+=650*dt
			d.pos+=d.velocity*dt
			if d.pos.y>617:
				d.pos.y=617
				d.velocity=Vector2.ZERO
		var target: Vector2=host.player.position+Vector2(0,-30)
		var distance: float=d.pos.distance_to(target)
		if d.age>0.25 and d.type=="coin" and distance<115: d.pos=d.pos.move_toward(target,600*dt)
		if d.age>0.20 and d.pos.distance_to(target)<42 and d.retry<=0:
			if collect(d): drops.remove_at(i)
			else: d.retry=0.5
	if cleared and clear_age>1.0 and host.player.position.x>=1165 and host.player.velocity.x>20 and not host.ascension.cinematic():
		if host.stage_index<2:
			travelling=true
			travel_age=0
			host.player.state="travel"
			host.player.velocity=Vector2.ZERO
		else: host.complete_map()
	queue_redraw()

func _draw() -> void:
	if host.mode!="battle" or host.over: return
	if cleared:
		var glow:=0.55+0.15*sin(clock*3)
		draw_rect(Rect2(1141,397,69,242),Color(0.55,0.85,0.35,0.12))
		draw_line(Vector2(1140,640),Vector2(1140,397),Color("d7ff77"),3,true)
		draw_line(Vector2(1210,640),Vector2(1210,397),Color("a784e4"),3,true)
		for i in 3:
			var x:=1157+i*17
			draw_polyline(PackedVector2Array([Vector2(x,506),Vector2(x+9,515),Vector2(x,524)]),Color(0.85,1,0.6,glow),3,true)
		draw_string(host.font,Vector2(1078,379),"通往下一段" if host.stage_index<2 else "完成本地图 →",HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color("e7ffc1"))

