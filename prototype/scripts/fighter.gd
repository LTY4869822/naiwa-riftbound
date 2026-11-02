extends CharacterBody2D

var host: Node
var hp: int = 100
var facing: int = 1
var attack_timer: float = 0.0
var attack_elapsed: float = 0.0
var attack_hit: bool = false
var combo: int = 0
var last_attack: float = -10.0
var invuln: float = 0.0
var dash_timer: float = 0.0
var dash_cd: float = 0.0
var skill_cd: float = 0.0
var input_buffer: float = 0.0
var jumps: int = 0
var clock: float = 0.0
var hurt_timer: float = 0.0
var landed_timer: float = 0.0
var afterimage_clock: float = 0.0
var sprite: AnimatedSprite2D
var flash_material: ShaderMaterial
const FLASH_SHADER = preload("res://shaders/flash.gdshader")

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(40, 112)
	shape.shape = rect
	shape.position.y = -56
	add_child(shape)
	hp = Profile.max_health()
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = SpriteFrames.new()
	sprite.sprite_frames.remove_animation("default")
	for animation in ["idle","run","attack0","attack1","attack2","hurt","air"]:
		sprite.sprite_frames.add_animation(animation)
		sprite.sprite_frames.set_animation_loop(animation,animation=="run" or animation=="idle")
		sprite.sprite_frames.set_animation_speed(animation,12 if animation=="run" else 11)
		if animation=="idle":
			sprite.sprite_frames.add_frame(animation,load("res://assets/v2/hero/idle.png"))
		elif animation=="air":
			sprite.sprite_frames.add_frame(animation,load("res://assets/v2/hero/run_3.png"))
		else:
			var prefix: String = "attack" if animation.begins_with("attack") else animation
			for i in range(4):
				sprite.sprite_frames.add_frame(animation,load("res://assets/v2/hero/%s_%d.png" % [prefix,i]),[1.2,0.65,0.9,1.3][i] if prefix=="attack" else 1.0)
	flash_material = ShaderMaterial.new()
	flash_material.shader = FLASH_SHADER
	sprite.material = flash_material
	sprite.position = Vector2(0,-112)
	sprite.scale = Vector2.ONE*0.5
	add_child(sprite)
	sprite.play("idle")

func _process(_delta: float) -> void:
	if sprite==null or host==null:
		return
	if host.mode!="battle" or host.paused or host.hitstop>0 or host.battle_over:
		sprite.speed_scale = 0
		return
	var pose: String = "hurt" if hurt_timer>0 else "attack%d" % combo if attack_timer>0 else "air" if not is_on_floor() else "run" if absf(velocity.x)>55 else "idle"
	if sprite.animation!=pose:
		sprite.play(pose)
	sprite.speed_scale = 1
	if pose.begins_with("attack"):
		sprite.speed_scale = 0.37/[0.34,0.39,0.55][combo]
	sprite.flip_h = facing<0
	var squash: float = sin(landed_timer*25)*landed_timer*0.15
	sprite.scale = Vector2(0.5+squash,0.5-squash)
	sprite.position.y = -112+sin(clock*3)*1.4 if pose=="idle" else -112
	sprite.rotation = facing*0.12 if dash_timer>0 else -facing*0.07 if hurt_timer>0 else 0
	flash_material.set_shader_parameter("flash",0.8 if hurt_timer>0.26 else 0.0)
	sprite.modulate.a = 0.6 if invuln>0 and hurt_timer<=0 and int(clock*20)%2==0 else 1.0

func _physics_process(delta: float) -> void:
	if host == null or host.mode != "battle" or host.battle_over or host.paused or host.hitstop > 0:
		return
	clock += delta
	hurt_timer = maxf(0,hurt_timer-delta)
	landed_timer = maxf(0,landed_timer-delta)
	invuln = maxf(0,invuln-delta)
	dash_cd = maxf(0,dash_cd-delta)
	skill_cd = maxf(0,skill_cd-delta)
	input_buffer = maxf(0,input_buffer-delta)
	var move: float = Input.get_axis("move_left","move_right")
	if Input.is_action_just_pressed("attack"):
		input_buffer = 0.18
	if Input.is_action_pressed("attack") and attack_timer<=0.17:
		input_buffer = 0.18
	if input_buffer > 0 and attack_timer <= 0 and dash_timer <= 0 and hurt_timer<=0:
		attack()
	if Input.is_action_just_pressed("jump") and jumps < 2 and hurt_timer<=0:
		velocity.y = -530 if jumps == 0 else -450
		jumps += 1
		host.burst(position, Color("a8c9bc"),8)
	if Input.is_action_just_pressed("dash"):
		dash()
	if Input.is_action_just_pressed("skill"):
		skill()
	attack_timer = maxf(0,attack_timer-delta)
	if attack_timer > 0:
		attack_elapsed += delta
		if not attack_hit and attack_elapsed >= [0.10,0.12,0.18][combo]:
			attack_hit = true
			host.slash_effect(position,facing,combo)
			host.melee_hit(self,combo)
	dash_timer = maxf(0,dash_timer-delta)
	if dash_timer > 0:
		velocity.x = facing * 820
		velocity.y = 0
		afterimage_clock -= delta
		if afterimage_clock<=0:
			host.ghost(position,facing,sprite.sprite_frames.get_frame_texture(sprite.animation,sprite.frame))
			afterimage_clock = 0.035
	else:
		velocity.y += 1450 * delta
		if absf(move) > 0.1 and attack_timer<=0 and hurt_timer<=0:
			facing = 1 if move > 0 else -1
		if hurt_timer>0:
			velocity.x = move_toward(velocity.x,0,550*delta)
		elif attack_timer>0:
			velocity.x = facing*([95,130,440][combo]) if attack_hit and attack_timer>0.11 else move_toward(velocity.x,0,900*delta)
		else:
			velocity.x = move_toward(velocity.x,move*330,2400*delta)
	var was_grounded: bool = is_on_floor()
	move_and_slide()
	position.x = clampf(position.x,55,1225)
	if is_on_floor():
		jumps = 0
		if not was_grounded:
			landed_timer = 0.2
			host.dust(position)
	queue_redraw()

func attack() -> void:
	if attack_timer > 0 or dash_timer > 0 or hp <= 0 or hurt_timer>0:
		return
	combo = (combo + 1) % 3 if clock-last_attack < 0.8 else 0
	last_attack = clock
	attack_timer = [0.34,0.39,0.55][combo]
	attack_elapsed = 0
	attack_hit = false
	input_buffer = 0
	velocity.x += facing * 125
	sprite.play("attack%d" % combo)
	sprite.frame = 0
	host.play_sfx("attack")

func dash() -> void:
	if dash_cd > 0 or hp <= 0:
		return
	dash_timer = 0.17
	dash_cd = 0.85
	invuln = maxf(invuln,0.25)
	host.play_sfx("dash")

func skill() -> void:
	if Profile.level < 2:
		host.toast("先喂食升到 Lv.2，解锁「碎片冲击」")
		return
	if skill_cd > 0:
		return
	skill_cd = 4.0
	invuln = maxf(invuln,0.3)
	host.shockwave(position + Vector2(0,-45))

func take_hit(amount: int, direction: float) -> void:
	if invuln > 0 or hp <= 0:
		return
	hp = maxi(0,hp-amount)
	invuln = 0.9
	hurt_timer = 0.32
	attack_timer = 0
	attack_hit = true
	input_buffer = 0
	dash_timer = 0
	velocity = Vector2(direction*320,-170)
	host.damage_flash = 0.2
	host.shake = 5
	host.impact(position+Vector2(0,-80),int(direction),false,Color("ed806f"))
	host.play_sfx("hurt")
	host.float_text(position+Vector2(0,-145),"-%d" % amount,Color("ef8f86"))
	if hp == 0:
		host.finish_battle(false)

func _draw() -> void:
	if host == null:
		return
	if is_on_floor():
		draw_set_transform(Vector2(0,0),0,Vector2(1,0.16))
		draw_circle(Vector2.ZERO,36,Color(0.01,0.02,0.03,0.38))
		draw_set_transform(Vector2.ZERO)
