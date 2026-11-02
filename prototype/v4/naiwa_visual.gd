extends Node2D
## Temporary original-image cutout rig. NOT a completed 3D Naiwa asset.
## Rigid limb rotations replace the previous full-image vertex distortion.
const SIZE := 0.72
const SOLE := 351.0
const SOURCE = preload("res://assets/naiwa/idle.png")
const SHADER = preload("res://v4/naiwa_cutout.gdshader")
var root: Node2D
var torso: Node2D
var limbs: Array[Dictionary] = []
var arms: Array[Dictionary] = []
var materials: Array[ShaderMaterial] = []
var clock: float = 0
var phase: float = 0
var last_direction: int = 0
var last_state: String = ""
var contact_error: float = 0
var drift_error: float = 0
var shoulder_shift := Vector2.ZERO
var body_shift := Vector2.ZERO
var previous_position := Vector2.ZERO

func cut(parent: Node2D, points: PackedVector2Array, origin: Vector2, patch: bool = false) -> Polygon2D:
	var p := Polygon2D.new()
	var vertices := PackedVector2Array()
	for v in points: vertices.append(v-origin)
	p.polygon = vertices
	p.uv = points
	p.texture = SOURCE
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("underpaint",load("res://assets/v4/naiwa-underpaint.png"))
	m.set_shader_parameter("body_patch",patch)
	p.material = m
	materials.append(m)
	parent.add_child(p)
	return p

func _ready() -> void:
	z_index = 5
	root = Node2D.new()
	add_child(root)
	root.position = Vector2(144,-SOLE)*SIZE
	root.scale = Vector2(-SIZE,SIZE)
	# Back leg then torso then near leg; every polygon samples original pixels.
	make_leg(Vector2(123,252),Vector2(127,291),Vector2(129,322),true)
	torso = Node2D.new()
	root.add_child(torso)
	cut(torso,PackedVector2Array([Vector2(0,0),Vector2(288,0),Vector2(288,258),Vector2(204,272),Vector2(106,271),Vector2(0,252)]),Vector2.ZERO,true)
	make_leg(Vector2(169,253),Vector2(177,297),Vector2(173,334),false)
	make_arm(Vector2(174,140),Vector2(174,171),Vector2(115,194))
	previous_position = position
	drive(0.016,Vector2.ZERO,"idle",0,1,0)

func make_leg(hip: Vector2, knee_point: Vector2, ankle: Vector2, far: bool) -> void:
	var upper_points := PackedVector2Array([Vector2(99,248),Vector2(145,248),Vector2(144,284),Vector2(135,309),Vector2(123,308),Vector2(109,285)]) if far else PackedVector2Array([Vector2(149,248),Vector2(201,247),Vector2(194,290),Vector2(184,315),Vector2(164,312),Vector2(151,280)])
	var lower_points := PackedVector2Array([Vector2(115,285),Vector2(140,284),Vector2(139,325),Vector2(124,330)]) if far else PackedVector2Array([Vector2(161,289),Vector2(193,288),Vector2(183,334),Vector2(166,343)])
	var foot_points := PackedVector2Array([Vector2(83,314),Vector2(122,310),Vector2(145,316),Vector2(150,335),Vector2(80,339)]) if far else PackedVector2Array([Vector2(147,325),Vector2(187,325),Vector2(202,340),Vector2(196,356),Vector2(143,356)])
	var upper := cut(root,upper_points,hip)
	var lower := cut(root,lower_points,knee_point)
	var foot := cut(root,foot_points,ankle)
	var sole_offset: float = 12 if far else 17
	limbs.append({"hip":hip,"knee":knee_point,"ankle":ankle,"upper":upper,"lower":lower,"foot":foot,"sole":sole_offset,"l1":hip.distance_to(knee_point),"l2":knee_point.distance_to(ankle),"plant":Vector2.ZERO,"stance":false,"last":Vector2.ZERO,"offset":0.5 if far else 0.0})

func make_arm(shoulder: Vector2, elbow: Vector2, wrist: Vector2) -> void:
	var upper := cut(root,PackedVector2Array([Vector2(157,126),Vector2(174,127),Vector2(186,140),Vector2(193,157),Vector2(188,177),Vector2(169,189),Vector2(156,172),Vector2(160,151)]),shoulder)
	var lower := cut(root,PackedVector2Array([Vector2(168,158),Vector2(186,170),Vector2(179,189),Vector2(155,201),Vector2(113,208),Vector2(109,184),Vector2(144,176)]),elbow)
	var hand := cut(root,PackedVector2Array([Vector2(109,176),Vector2(127,183),Vector2(126,203),Vector2(111,211),Vector2(95,209),Vector2(87,202),Vector2(88,190),Vector2(95,187),Vector2(96,178)]),wrist)
	arms.append({"shoulder":shoulder,"elbow":elbow,"wrist":wrist,"upper":upper,"lower":lower,"hand":hand,"l1":shoulder.distance_to(elbow),"l2":elbow.distance_to(wrist)})

func solve(a: Vector2, b: Vector2, l1: float, l2: float, bend: float) -> Vector2:
	var delta := b-a
	var distance := clampf(delta.length(),0.1,l1+l2-0.01)
	var along := (l1*l1-l2*l2+distance*distance)/(2*distance)
	var height := sqrt(maxf(0,l1*l1-along*along))
	var axis := delta.normalized()
	return a+axis*along+Vector2(-axis.y,axis.x)*height*bend

func drive(dt: float, velocity: Vector2, state: String, progress: float, direction: int, flash: float) -> void:
	if root==null: return
	clock += dt
	var turned: bool = direction!=last_direction
	last_direction = direction
	root.scale = Vector2(-direction*SIZE,SIZE)
	root.position = Vector2(direction*144*SIZE,-SOLE*SIZE)
	var running: bool = state=="run"
	# Advance from actual displacement. Pauses and collisions cannot run the feet in place.
	var travel: float = absf(position.x-previous_position.x)
	previous_position = position
	if running and dt>0: phase += minf(travel,absf(velocity.x)*dt+2)/50.0
	var airborne: bool = state=="air" or (state=="hurt" and position.y<639)
	var attack: bool = state.begins_with("attack")
	var step: int = int(state[-1]) if attack else 0
	var windup := smoothstep(0.0,0.27,progress) if attack else 0.0
	var strike := smoothstep(0.29,0.40,progress)*(1-smoothstep(0.56,0.98,progress)) if attack else 0.0
	var target_body := Vector2(0,4.0+absf(sin(phase*TAU))*2.5) if running else Vector2(0,0)
	if attack: target_body = Vector2(windup*2-strike*4,3*windup)
	if state=="hurt": target_body = Vector2(5,2)
	body_shift = body_shift.lerp(target_body,1-exp(-dt*22))
	torso.position = body_shift
	contact_error = 0
	drift_error = 0
	for leg in limbs:
		var hip: Vector2 = leg.hip+body_shift+Vector2(0,17 if leg.offset==0.5 else 0)
		var u: float = fposmod(phase+float(leg.offset),1.0)
		var stance: bool = not running or u<0.56
		var ankle: Vector2 = leg.ankle
		ankle.y = SOLE-float(leg.sole)
		if airborne:
			ankle += Vector2(7 if leg.offset==0 else -7,-12)
			stance = false
		elif attack and step==2 and leg.offset==0 and strike>0.01:
			ankle += Vector2(-39,-36)*strike
			stance = false
		elif stance:
			if not leg.stance or turned or last_state!=state:
				leg.plant = root.to_global(ankle+Vector2(-14 if running else 0,leg.sole))
				leg.plant.y = position.y
			ankle = root.to_local(leg.plant)-Vector2(0,leg.sole)
		else:
			var swing: float = (u-0.56)/0.44
			ankle += Vector2(lerpf(24,-14,smoothstep(0,1,swing)),-sin(swing*PI)*16)
		var joint := solve(hip,ankle,leg.l1,leg.l2,-1)
		leg.upper.position = hip
		leg.upper.rotation = (joint-hip).angle()-(leg.knee-leg.hip).angle()
		leg.lower.position = joint
		leg.lower.rotation = (ankle-joint).angle()-(leg.ankle-leg.knee).angle()
		leg.foot.position = ankle
		leg.foot.rotation = -strike*0.18 if attack and step==2 and leg.offset==0 else 0.0
		var actual: Vector2 = leg.foot.to_global(Vector2(0,leg.sole))
		if stance:
			contact_error = maxf(contact_error,absf(actual.y-position.y))
			if leg.stance and last_state==state and not turned: drift_error = maxf(drift_error,actual.distance_to(leg.last))
		leg.last = actual
		leg.stance = stance
	for arm in arms:
		var shoulder: Vector2 = arm.shoulder+body_shift
		var wrist: Vector2 = arm.wrist+body_shift
		if running: wrist += Vector2(sin(phase*TAU)*10,cos(phase*TAU)*5-4)
		if attack: wrist += Vector2(16,-13)*windup+Vector2(-48,-24 if step==0 else -41)*strike
		if state=="hurt": wrist += Vector2(13,-16)
		if airborne: wrist += Vector2(-4,-13)
		# Clamp the target to physical arm length: no stretched upper arm.
		wrist = shoulder+(wrist-shoulder).limit_length(arm.l1+arm.l2-0.5)
		var joint := solve(shoulder,wrist,arm.l1,arm.l2,-1)
		arm.upper.position = shoulder
		arm.upper.rotation = (joint-shoulder).angle()-(arm.elbow-arm.shoulder).angle()
		arm.lower.position = joint
		arm.lower.rotation = (wrist-joint).angle()-(arm.wrist-arm.elbow).angle()
		arm.hand.position = wrist
		arm.hand.rotation = arm.lower.rotation*0.6
	for m in materials: m.set_shader_parameter("flash",flash)
	last_state = state
