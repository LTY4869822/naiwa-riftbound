extends CharacterBody2D
signal changed
var host: Node
var hp: int
var dead: bool = false
var facing: int = 1
var state: String = "idle"
var elapsed: float = 0
var combo: int = 0
var buffered: float = 0
var jump_buffer: float = 0
var coyote: float = 0
var jumps_used: int = 0
const JUMP_SPEED := 520.0
const AIR_JUMP_SPEED := 500.0
var stamina: float = 100
var focus: float = 0
var invuln: float = 0
var dash_cd: float = 0
var flash: float = 0
var hit_ids: Array[int] = []
const DURATIONS := [0.38,0.44,0.56]
const STARTUP := [0.09,0.12,0.17]
const ACTIVE := [0.09,0.11,0.12]
const SKILL_RELEASE := 0.48
const SKILL_DURATION := 0.88
const SKILL_DASH_CANCEL := 0.56
var combo_queued := false
var swing_sent := false
var skill_fired := false

func _ready() -> void:
	hp = Profile.max_health()
	collision_layer = 2
	collision_mask = 1|8
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(66,202)
	shape.shape = rectangle
	shape.position.y = -101
	add_child(shape)

func visual_state() -> String:
	if state=="skill": return "skill"
	if state=="attack": return "attack%d" % combo
	if state in ["hurt","dash"]: return "hurt" if state=="hurt" else "run"
	if not is_on_floor() and position.y<638: return "air"
	return "run" if absf(velocity.x)>25 else "idle"

func visual_progress() -> float:
	if state=="skill": return elapsed/SKILL_DURATION
	if state=="hurt": return elapsed/0.22
	if state=="dash": return elapsed/0.18
	if not is_on_floor() and state=="idle": return clampf((velocity.y+520)/1040,.09 if jumps_used==2 else 0,1)
	return elapsed/DURATIONS[combo] if state=="attack" else 0.0

func hurtbox() -> Rect2:
	return Rect2(position+Vector2(-43,-211),Vector2(86,211))

func attackbox() -> Rect2:
	if host.ascension.empowered(): return Rect2(position+Vector2(-20 if facing>0 else -265,-235),Vector2(285,235))
	var hand: Vector2=host.stage.strike_position(self)
	if combo==2: return Rect2(position+Vector2(10 if facing>0 else -128,-161),Vector2(118,142))
	return Rect2(hand-Vector2(38,35),Vector2(76,92))

func attack(step: int) -> void:
	if dead: return
	state = "attack"
	combo = step
	elapsed = 0
	buffered = 0
	combo_queued=false
	swing_sent=false
	hit_ids.clear()
	changed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not host.playing(): return
	if event.is_action_pressed("awaken") and not event.is_echo(): host.ascension.awaken()
	if host.ascension.cinematic(): return
	if event.is_action_pressed("attack") and not event.is_echo():
		buffered=0.16
		if state=="attack" and elapsed>STARTUP[combo] and combo<2: combo_queued=true
	if event.is_action_pressed("jump") and not event.is_echo(): jump_buffer = 0.14
	if event.is_action_pressed("heavy") and not state in ["hurt","dash","skill"] and stamina>=28 and (state!="attack" or elapsed>DURATIONS[combo]-0.12):
		stamina -= 28
		attack(2)
	if event.is_action_pressed("dash"): dash()
	if event.is_action_pressed("skill") and not event.is_echo(): skill()
	if event.is_action_pressed("interact") and not event.is_echo(): host.arena.interact()

func _physics_process(dt: float) -> void:
	if not host.playing() or host.hitstop>0 or dead: return
	step(dt)

func step(dt: float) -> void:
	invuln = maxf(0,invuln-dt)
	flash = maxf(0,flash-dt*7)
	dash_cd = maxf(0,dash_cd-dt)
	buffered = maxf(0,buffered-dt)
	jump_buffer = maxf(0,jump_buffer-dt)
	stamina = minf(100,stamina+dt*((22 if state=="idle" else 12)+Wardrobe.gear_rank("anklet")*3))
	if is_on_floor() and velocity.y>=0:
		jumps_used=0
		coyote=.10
	else:
		coyote=maxf(0,coyote-dt)
		# Walking off a ledge spends the ground jump after its coyote window.
		if coyote<=0 and jumps_used==0: jumps_used=1
	elapsed += dt*(1.18 if host.ascension.empowered() and state=="attack" else 1.0)
	var move: float = Input.get_axis("move_left","move_right")
	if host.ascension.cinematic() or state=="travel":
		velocity.x=0
	elif state=="idle":
		if move!=0: facing=int(signf(move))
		var acceleration: float=8400 if move!=0 and signf(move)!=signf(velocity.x) else 5600
		velocity.x = move_toward(velocity.x,move*(310 if host.ascension.empowered() else 285),dt*acceleration)
		if buffered>0: attack(0)
	elif state=="attack":
		velocity.x=move_toward(velocity.x,0,2200*dt)
		if move!=0 and elapsed>=STARTUP[combo]+ACTIVE[combo]+0.025 and (not combo_queued or signf(move)!=facing):
			state="idle"
			facing=int(signf(move))
			velocity.x=move*140
			buffered=0
			combo_queued=false
		if elapsed>=STARTUP[combo] and elapsed<STARTUP[combo]+ACTIVE[combo]:
			if not swing_sent:
				swing_sent=true
				host.play_sound("attack",-22,0.9+combo*0.08)
		if elapsed>=DURATIONS[combo]:
			if (buffered>0 or combo_queued) and combo<2: attack(combo+1)
			else: state = "idle"
	elif state=="skill":
		velocity.x=move_toward(velocity.x,0,1800*dt)
		if elapsed>=SKILL_DURATION: state="idle"
	elif state=="hurt":
		velocity.x = move_toward(velocity.x,0,750*dt)
		if elapsed>0.22: state = "idle"
	elif state=="dash":
		velocity.x = facing*(680 if host.ascension.empowered() else 570)
		velocity.y = minf(velocity.y,0)
		if elapsed>0.18: state = "idle"
	if jump_buffer>0: try_jump()
	if state!="dash": velocity.y += 1300*dt
	var was_grounded: bool = is_on_floor()
	move_and_slide()
	position.x = clampf(position.x,60,1220)
	# Visual pose and its hand collider advance on this same physics tick.
	host.stage.sync(self,dt)
	# Release after the contact drawing and its hand anchor update on this tick.
	if state=="skill" and elapsed>=SKILL_RELEASE and not skill_fired:
		skill_fired=true
		host.skill_burst()
	if state=="attack" and elapsed>=STARTUP[combo] and elapsed<STARTUP[combo]+ACTIVE[combo]: host.resolve_attack(self)
	if is_on_floor():
		jumps_used=0
		coyote=.10
		if not was_grounded: host.dust(position)
	changed.emit()

func try_jump() -> bool:
	if dead or host.ascension.cinematic() or state in ["hurt","skill","travel"]: return false
	if state=="attack" and elapsed<STARTUP[combo]+ACTIVE[combo]+.025: return false
	if state=="dash" and elapsed<.08: return false
	var ground_jump: bool=jumps_used==0 and (is_on_floor() and velocity.y>=0 or coyote>0)
	if not ground_jump and jumps_used>=2: return false
	if not ground_jump and jumps_used==0: jumps_used=1
	jumps_used=1 if ground_jump else 2
	velocity.y=-JUMP_SPEED if ground_jump else -AIR_JUMP_SPEED
	jump_buffer=0
	coyote=0
	state="idle"
	elapsed=0
	buffered=0
	combo_queued=false
	if ground_jump:
		host.dust(position)
		host.play_sound("dash",-27,.95)
	else:
		host.fx("air_jump",position,facing,.38)
		host.play_sound("dash",-22,1.45)
	changed.emit()
	return true

func dash_cost() -> float: return 32.0-4*host.rift.rank("wind")
func dash_limit() -> float: return maxf(.35,.55-.08*host.rift.rank("wind"))

func dash() -> void:
	if host.ascension.cinematic(): return
	if dead or state=="hurt" or dash_cd>0 or stamina<dash_cost(): return
	if state=="skill" and elapsed<SKILL_DASH_CANCEL: return
	if state=="attack" and elapsed<STARTUP[combo]+ACTIVE[combo]: return
	var intent: float=Input.get_axis("move_left","move_right")
	if intent!=0: facing=int(signf(intent))
	stamina -= dash_cost()
	state = "dash"
	elapsed = 0
	dash_cd = dash_limit()
	invuln = 0.18
	host.play_sound("dash",-22,1.05)
	host.fx("dash",position+Vector2(0,-85),facing)
	if is_instance_valid(host.get("training")): host.training.complete("dash")
	changed.emit()

func skill() -> void:
	if host.ascension.cinematic(): return
	if host.ascension.empowered():
		host.ascension.finisher()
		return
	if dead or state in ["hurt","skill","dash"]: return
	if Profile.level<2:
		host.toast("完成训练或喂食升到 Lv.2 后解锁星核巨拳")
		return
	if focus<60:
		host.toast("命中积累专注，60 点可释放星核巨拳")
		return
	focus -= 60
	invuln = maxf(invuln,0.62)
	state="skill"
	elapsed=0
	skill_fired=false
	buffered=0
	combo_queued=false
	host.play_sound("ultimate_charge",-16,1.0)
	if is_instance_valid(host.get("training")): host.training.complete("ultimate")
	if is_instance_valid(host.get("spectacle")): host.spectacle.announce("hero")
	changed.emit()

func take_hit(damage: int, direction: int) -> bool:
	if invuln>0 or dead:
		if not dead and state=="dash" and elapsed<=.10: host.rift.perfect_evade()
		return false
	hp = maxi(0,hp-damage)
	state = "hurt"
	elapsed = 0
	flash = 1
	buffered = 0
	invuln = 0.68
	velocity = Vector2(direction*280,-140)
	host.impact(position+Vector2(0,-107),direction,true,true)
	host.play_sound("hurt",-16,0.9)
	changed.emit()
	if hp<=0:
		dead = true
		host.finish(false)
	return true
