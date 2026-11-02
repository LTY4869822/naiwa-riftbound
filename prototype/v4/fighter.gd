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
const DURATIONS := [0.42,0.48,0.70]
const STARTUP := [0.13,0.17,0.27]
const ACTIVE := [0.10,0.12,0.13]

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
	if state=="attack": return "attack%d" % combo
	if state in ["hurt","dash"]: return "hurt" if state=="hurt" else "run"
	if not is_on_floor() and position.y<638: return "air"
	return "run" if absf(velocity.x)>25 else "idle"

func visual_progress() -> float:
	return elapsed/DURATIONS[combo] if state=="attack" else 0.0

func hurtbox() -> Rect2:
	return Rect2(position+Vector2(-28,-173),Vector2(56,173))

func attackbox() -> Rect2:
	var reach: float = [126,139,151][combo]
	return Rect2(position+Vector2(18 if facing>0 else -reach,-157 if combo<2 else -131),Vector2(reach-18,94))

func attack(step: int) -> void:
	if dead: return
	state = "attack"
	combo = step
	elapsed = 0
	buffered = 0
	hit_ids.clear()
	host.play_sound("attack",-22,0.9+step*0.08)
	changed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not host.playing(): return
	if event.is_action_pressed("attack") and not event.is_echo(): buffered = 0.16
	if event.is_action_pressed("jump"): jump_buffer = 0.14
	if event.is_action_pressed("heavy") and state!="hurt" and state!="dash" and stamina>=28 and (state!="attack" or elapsed>DURATIONS[combo]-0.12):
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
		if absf(move)>0.1: facing = int(signf(move))
		velocity.x = move_toward(velocity.x,move*310,1900*dt)
		if buffered>0: attack(0)
		if jump_buffer>0 and coyote>0:
			velocity.y = -580
			jump_buffer = 0
			coyote = 0
			host.dust(position)
	elif state=="attack":
		velocity.x = move_toward(velocity.x,facing*(38 if combo<2 else 65),1800*dt)
		if elapsed>=STARTUP[combo] and elapsed<STARTUP[combo]+ACTIVE[combo]:
			host.resolve_attack(self)
		if elapsed>=DURATIONS[combo]:
			if buffered>0 and combo<2: attack(combo+1)
			else: state = "idle"
	elif state=="hurt":
		velocity.x = move_toward(velocity.x,0,750*dt)
		if elapsed>0.32: state = "idle"
	elif state=="dash":
		velocity.x = facing*780
		velocity.y = minf(velocity.y,0)
		if elapsed>0.18: state = "idle"
	if state!="dash": velocity.y += 1700*dt
	var was_grounded: bool = is_on_floor()
	move_and_slide()
	position.x = clampf(position.x,60,1220)
	if is_on_floor() and not was_grounded: host.dust(position)
	changed.emit()

func dash() -> void:
	if dead or state=="hurt" or dash_cd>0 or stamina<32: return
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
	if dead or state=="hurt": return
	if Profile.level<2:
		host.toast("喂食升到 Lv.2 后解锁碎片冲击")
		return
	if focus<60:
		host.toast("命中积累专注，60 点可释放冲击")
		return
	focus -= 60
	invuln = maxf(invuln,0.30)
	host.skill_burst()
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
