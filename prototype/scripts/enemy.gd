extends CharacterBody2D

var host: Node
var eid: int = 0
var boss: bool = false
var hp: int = 60
var maximum: int = 60
var clock: float = 0
var cooldown: float = 1.0
var windup: float = 0
var stun: float = 0
var flash: float = 0
var dead: bool = false
var facing: int = -1
var sprite: Sprite2D
var frames: Array[Texture2D] = []
var flash_material: ShaderMaterial
var death_timer: float = 0.0
var attack_pose: float = 0.0
var wall_cd: float = 0.0

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	maximum = 280 if boss else 58
	hp = maximum
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(82,155) if boss else Vector2(76,68)
	shape.shape = rect
	shape.position.y = -rect.size.y/2
	add_child(shape)
	for i in range(4):
		frames.append(load("res://assets/v2/enemies/%s_%d.png" % ["warden" if boss else "hound",i]))
	sprite = Sprite2D.new()
	sprite.texture = frames[0]
	var scale_value: float = 0.49 if boss else 0.34
	sprite.scale = Vector2.ONE*scale_value
	sprite.position.y = -256*scale_value
	flash_material = ShaderMaterial.new()
	flash_material.shader = preload("res://shaders/flash.gdshader")
	sprite.material = flash_material
	add_child(sprite)

func _process(delta: float) -> void:
	if sprite==null:
		return
	if dead:
		death_timer += delta
		flash_material.set_shader_parameter("dissolve",minf(1,death_timer/0.42))
		flash_material.set_shader_parameter("flash",maxf(0,1-death_timer*4))
		if death_timer>0.45:
			queue_free()
		return
	if host.mode!="battle" or host.paused or host.hitstop>0 or host.battle_over:
		return
	var frame_index: int = 3 if attack_pose>0 else 2 if windup>0 else int(clock*8)%2 if absf(velocity.x)>10 else 0
	sprite.texture = frames[frame_index]
	sprite.flip_h = facing>0
	var sx: float = 0.49 if boss else 0.34
	sprite.scale = Vector2(sx*(1+flash*0.5),sx*(1-flash*0.4))
	sprite.rotation = -facing*flash*0.8
	flash_material.set_shader_parameter("flash",minf(1,flash*9))
	sprite.position.y = -256*sx+sin(clock*5)*1.5

func _physics_process(delta: float) -> void:
	if dead or host == null or host.mode != "battle" or host.battle_over or host.paused or host.hitstop>0:
		return
	clock += delta
	flash = maxf(0,flash-delta)
	stun = maxf(0,stun-delta)
	wall_cd = maxf(0,wall_cd-delta)
	attack_pose = maxf(0,attack_pose-delta)
	cooldown -= delta
	velocity.y += 1450*delta
	if stun>0:
		velocity.x = move_toward(velocity.x,0,440*delta)
	elif windup>0:
		windup -= delta
		velocity.x = 0
		if windup<=0:
			attack_pose = 0.24
			if absf(host.player.position.x-position.x)<(145 if boss else 88) and absf(host.player.position.y-position.y)<115:
				host.player.take_hit(22 if boss else 11,facing)
			host.enemy_slash(position,facing,boss)
			cooldown = 1.65 if boss else 1.3
	else:
		var dx: float = host.player.position.x-position.x
		facing = 1 if dx>0 else -1
		var range_x: float = 105 if boss else 60
		velocity.x = facing*(78 if boss else 105) if absf(dx)>range_x else 0
		if absf(dx)<range_x+15 and cooldown<=0 and absf(host.player.position.y-position.y)<115:
			windup = 0.7 if boss else 0.52
	move_and_slide()
	if (position.x<45 or position.x>1235) and absf(velocity.x)>260 and wall_cd<=0:
		wall_cd = 0.5
		host.impact(position+Vector2(0,-45),-facing,true,Color("eeac77"))
		take_hit(16,-velocity.x*0.3)
		host.float_text(position+Vector2(0,-110),"撞击 +16",Color("ffe5ad"))
	position.x = clampf(position.x,35,1245)
	queue_redraw()

func take_hit(damage: int, push: float) -> void:
	if dead:
		return
	hp -= damage
	queue_redraw()
	flash = 0.12
	stun = 0.22 if boss else 0.38
	windup = 0
	velocity = Vector2(push/(2.0 if boss else 1.0),-180)
	if absf(push)>500:
		velocity.y = -300 if not boss else -130
	host.float_text(position+Vector2(0,-120 if boss else -85),str(damage),Color("ffe0a0"))
	host.burst(position+Vector2(0,-40),Color("e7b85e"),10)
	if hp<=0:
		dead = true
		for child in get_children():
			if child is CollisionShape2D:
				child.set_deferred("disabled",true)
		host.on_enemy_down(self)

func _draw() -> void:
	if dead:
		return
	draw_set_transform(Vector2(0,-1),0,Vector2(1,0.18))
	draw_circle(Vector2.ZERO,44 if boss else 33,Color(0.01,0.02,0.03,0.45))
	draw_set_transform(Vector2.ZERO)
	if not boss and hp<maximum:
		draw_rect(Rect2(-31,-112,62,3),Color("293b42"))
		draw_rect(Rect2(-31,-112,62*maxf(0,float(hp)/maximum),3),Color("dc8a75"))
	if windup>0:
		var y: float = -250 if boss else -125
		draw_circle(Vector2(0,y),11,Color("ed7967"))
		draw_line(Vector2(0,y-6),Vector2(0,y+1),Color("281d23"),2)
		draw_circle(Vector2(0,y+5),1.5,Color("281d23"))
		draw_line(Vector2(facing*40,0),Vector2(facing*(140 if boss else 90),0),Color(0.95,0.3,0.22,0.6),4)
