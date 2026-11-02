extends CharacterBody2D
var host: Node
var kind: String = "melee"
var eid: int = 0
var hp: int = 90
var maximum: int = 90
var dead: bool = false
var state: String = "approach"
var timer: float = 0
var cooldown: float = 0.8
var facing: int = -1
var flash: float = 0
var stagger: float = 0
var move_id: int = 0
var action_count: int = 0
var dealt: bool = false
var target: Vector2
var boss: bool:
	get: return kind=="boss"

func _ready() -> void:
	maximum = 510 if boss else 92 if kind=="melee" else 78
	hp = maximum
	cooldown = 0.8+eid*0.17
	collision_layer = 4
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(74 if boss else 48,205 if boss else 150)
	shape.shape = rect
	shape.position.y = -rect.size.y/2
	add_child(shape)

func hurtbox() -> Rect2:
	return Rect2(position+Vector2(-40 if boss else -29,-215 if boss else -163),Vector2(80 if boss else 58,215 if boss else 163))

func windup_duration() -> float:
	return 0.86 if kind=="ranged" else (0.85 if move_id==0 else 0.64) if boss else 0.55

func visual_state() -> String:
	if state=="stunned": return "hurt"
	if state=="tell": return "attack2" if boss and move_id==0 else "attack0"
	if state=="active": return "attack2" if boss and move_id==0 else "attack1"
	if not is_on_floor() and position.y<638: return "air"
	return "run" if absf(velocity.x)>18 else "idle"

func visual_progress() -> float:
	if state=="tell": return 0.08+0.16*timer/windup_duration()
	if state=="active": return 0.30+minf(0.65,timer*3)
	return 0

func _physics_process(dt: float) -> void:
	if not host.playing() or host.hitstop>0 or dead: return
	timer += dt
	cooldown -= dt
	flash = maxf(0,flash-dt*6)
	stagger = maxf(0,stagger-dt*15)
	velocity.y += 1700*dt
	var dx: float = host.player.position.x-position.x
	if state=="stunned":
		velocity.x = move_toward(velocity.x,0,1100*dt)
		if timer>0.32: transition("approach")
	elif state=="tell":
		velocity.x = move_toward(velocity.x,0,2400*dt)
		if timer>=windup_duration():
			transition("active")
			dealt = false
			if kind=="ranged": host.shoot(position+Vector2(facing*32,-125),target,facing)
			host.play_sound("attack",-24,0.65 if boss else 0.85)
	elif state=="active":
		velocity.x = facing*(420 if boss and move_id==1 else 95 if not boss else 40) if timer<0.22 else 0
		if kind!="ranged" and not dealt:
			var reach: float = 196 if boss and move_id==0 else 141 if boss else 109
			var rect := Rect2(position+Vector2(0 if facing>0 else -reach,-155),Vector2(reach,155))
			if rect.intersects(host.player.hurtbox()):
				host.player.take_hit(32 if boss else 18,facing)
				dealt = true
		if timer>0.26:
			transition("recover")
			cooldown = 1.25 if boss else 1.05
	elif state=="recover":
		velocity.x = move_toward(velocity.x,0,1800*dt)
		if timer>(0.65 if boss else 0.42): transition("approach")
	else:
		facing = 1 if dx>0 else -1
		if kind=="ranged":
			velocity.x = -facing*95 if absf(dx)<270 else facing*80 if absf(dx)>480 else 0
			if cooldown<=0 and absf(dx)>200 and host.attack_budget(self): begin_attack()
		else:
			var desired: float = 106 if boss else 76
			var speed: float = 115 if boss else 133
			velocity.x = facing*speed if absf(dx)>desired else -facing*45 if absf(dx)<desired-20 else 0
			if absf(dx)<desired+35 and cooldown<=0 and host.attack_budget(self): begin_attack()
	move_and_slide()
	position.x = clampf(position.x,65,1215)

func transition(next: String) -> void:
	state = next
	timer = 0

func begin_attack() -> void:
	action_count += 1
	move_id = action_count%2
	target = host.player.position+Vector2(0,-95)
	transition("tell")

func take_hit(damage: int, direction: int, heavy: bool) -> void:
	if dead: return
	hp = maxi(0,hp-damage)
	flash = 1
	stagger += 45 if heavy else 15
	var armored: bool = boss and state in ["tell","active"] and not heavy and stagger<70
	if not armored:
		transition("stunned")
		velocity = Vector2(direction*(150 if boss else 255),-90 if boss else -115)
		cooldown = maxf(cooldown,0.55)
	if heavy and boss:
		host.float_number(position+Vector2(0,-230),"破势",Color("8bd9cd"))
	if hp<=0:
		dead = true
		host.enemy_down(self)
		host.stage.remove_actor(self)
		queue_free()
