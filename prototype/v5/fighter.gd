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
var stamina: float = 100
var focus: float = 0
var invuln: float = 0
var dash_cd: float = 0
var flash: float = 0
var hit_ids: Array[int] = []
const DURATIONS := [0.48,0.54,0.72]
const STARTUP := [0.14,0.17,0.25]
const ACTIVE := [0.11,0.12,0.14]
var combo_queued := false
var swing_sent := false
var skill_fired := false

func _ready() -> void:
	hp = Profile.max_health()
	collision_layer = 2
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(54,165)
	shape.shape = rectangle
	shape.position.y = -82.5
	add_child(shape)

func visual_state() -> String:
	if state=="skill": return "attack2"
	if state=="attack": return "attack%d" % combo
	if state in ["hurt","dash"]: return "hurt" if state=="hurt" else "run"
	if not is_on_floor() and position.y<638: return "air"
	return "run" if absf(velocity.x)>25 else "idle"

func visual_progress() -> float:
	if state=="skill": return elapsed/0.68
	return elapsed/DURATIONS[combo] if state=="attack" else 0.0

func hurtbox() -> Rect2:
	return Rect2(position+Vector2(-28,-173),Vector2(56,173))

func attackbox() -> Rect2:
	var hand: Vector2=host.stage.hand_position(self)
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
	if event.is_action_pressed("attack") and not event.is_echo():
		buffered=0.16
		if state=="attack" and elapsed>STARTUP[combo] and combo<2: combo_queued=true
	if event.is_action_pressed("jump"): jump_buffer = 0.14
	if event.is_action_pressed("heavy") and not state in ["hurt","dash","skill"] and stamina>=28 and (state!="attack" or elapsed>DURATIONS[combo]-0.12):
		stamina -= 28
		attack(2)
	if event.is_action_pressed("dash"): dash()
	if event.is_action_pressed("skill"): skill()

func _physics_process(dt: float) -> void:
	if not host.playing() or host.hitstop>0 or dead: return
	step(dt)

func step(dt: float) -> void:
	invuln = maxf(0,invuln-dt)
	flash = maxf(0,flash-dt*7)
	dash_cd = maxf(0,dash_cd-dt)
	buffered = maxf(0,buffered-dt)
	jump_buffer = maxf(0,jump_buffer-dt)
	stamina = minf(100,stamina+dt*(22 if state=="idle" else 12))
	coyote = 0.10 if is_on_floor() else maxf(0,coyote-dt)
	elapsed += dt
	var move: float = Input.get_axis("move_left","move_right")
	if state=="idle":
		velocity.x = move_toward(velocity.x,move*175,dt*(1000 if move!=0 else 1400))
		if absf(velocity.x)>16: facing=int(signf(velocity.x))
		if buffered>0: attack(0)
		if jump_buffer>0 and coyote>0:
			velocity.y = -520
			jump_buffer = 0
			coyote = 0
			host.dust(position)
	elif state=="attack":
		velocity.x=move_toward(velocity.x,0,1800*dt)
		if elapsed>=STARTUP[combo] and elapsed<STARTUP[combo]+ACTIVE[combo]:
			if not swing_sent:
				swing_sent=true
				host.play_sound("attack",-22,0.9+combo*0.08)
		if elapsed>=DURATIONS[combo]:
			if (buffered>0 or combo_queued) and combo<2: attack(combo+1)
			else: state = "idle"
	elif state=="skill":
		velocity.x=move_toward(velocity.x,0,1800*dt)
		if elapsed>=0.26 and not skill_fired:
			skill_fired=true
			host.skill_burst()
		if elapsed>=0.68: state="idle"
	elif state=="hurt":
		velocity.x = move_toward(velocity.x,0,750*dt)
		if elapsed>0.32: state = "idle"
	elif state=="dash":
		velocity.x = facing*570
		velocity.y = minf(velocity.y,0)
		if elapsed>0.18: state = "idle"
	if state!="dash": velocity.y += 1300*dt
	var was_grounded: bool = is_on_floor()
	move_and_slide()
	position.x = clampf(position.x,60,1220)
	# Visual pose and its hand collider advance on this same physics tick.
	host.stage.sync(self,dt)
	if state=="attack" and elapsed>=STARTUP[combo] and elapsed<STARTUP[combo]+ACTIVE[combo]: host.resolve_attack(self)
	if is_on_floor() and not was_grounded: host.dust(position)
	changed.emit()

func dash() -> void:
	if dead or state=="hurt" or dash_cd>0 or stamina<32: return
	if state=="skill" and elapsed<0.3: return
	if state=="attack" and elapsed<STARTUP[combo]+ACTIVE[combo]: return
	stamina -= 32
	state = "dash"
	elapsed = 0
	dash_cd = 0.55
	invuln = 0.18
	host.play_sound("dash",-22,1.05)
	host.fx("dash",position+Vector2(0,-85),facing)
	changed.emit()

func skill() -> void:
	if dead or state in ["hurt","skill"]: return
	if Profile.level<2:
		host.toast("喂食升到 Lv.2 后解锁碎片冲击")
		return
	if focus<60:
		host.toast("命中积累专注，60 点可释放冲击")
		return
	focus -= 60
	invuln = maxf(invuln,0.45)
	state="skill"
	elapsed=0
	skill_fired=false
	changed.emit()

func take_hit(damage: int, direction: int) -> bool:
	if invuln>0 or dead: return false
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
