extends Node3D
## Original three-dimensional leaf constructs. Gameplay remains in the 2D plane.
const A = preload("res://v4/art.gd")
var kind: String = "melee"
var body: Node3D
var head: Node3D
var wings: Array[Node3D] = []
var legs: Array[Dictionary] = []
var arms: Array[Node3D] = []
var materials: Array[ShaderMaterial] = []
var clock: float = 0
var phase: float = 0
var last_direction: int = 0
var contact_error: float = 0
var drift_error: float = 0
var last_state: String = ""
var pose: float = 0
var previous_position := Vector3.ZERO

func mat(kind_name: String, edge: float = 1.3) -> ShaderMaterial:
	var m := A.material(kind_name,edge)
	materials.append(m)
	return m

func _ready() -> void:
	body = Node3D.new()
	add_child(body)
	head = Node3D.new()
	body.add_child(head)
	if kind=="ranged": build_moth()
	elif kind=="boss": build_guardian()
	else: build_hunter()
	drive(0.016,Vector2.ZERO,"idle",0,-1,0)

func build_hunter() -> void:
	var dark := mat("leaf")
	var bone := mat("bone")
	var core := mat("gold",0.7)
	A.orb(body,Vector3(-0.12,0.98,0),Vector3(1.12,0.72,0.62),dark)
	for i in range(3):
		A.leaf(body,Vector3(-0.45+i*0.32,1.10,0),0.88-i*0.08,0.46,-0.8+i*0.16,dark)
	A.plate(head,PackedVector2Array([Vector2(-0.22,1.66),Vector2(0.43,1.82),Vector2(0.92,1.34),Vector2(0.59,1.05),Vector2(0.22,1.11)]),0.30,Vector3.ZERO,bone)
	for z in [-0.28,0.28]:
		A.plate(head,PackedVector2Array([Vector2(0.35,1.42),Vector2(0.70,1.42),Vector2(0.48,1.30)]),0.025,Vector3(0,0,z),mat("ink",0))
		A.plate(head,PackedVector2Array([Vector2(0.43,1.40),Vector2(0.65,1.39),Vector2(0.49,1.34)]),0.03,Vector3(0,0,z*1.08),core)
		A.leaf(head,Vector3(0.0,1.64,z*0.6),0.55,0.20,0.65,dark)
	for i in range(4):
		add_leg(Vector3(0.20 if i<2 else -0.47,0.90,0.27 if i%2==0 else -0.27),0.52,0.52,dark,bone,i)
	for side in [-1,1]:
		var arm := Node3D.new()
		arm.position = Vector3(0.25,1.10,side*0.36)
		body.add_child(arm)
		A.plate(arm,PackedVector2Array([Vector2(0,0.1),Vector2(0.40,-0.12),Vector2(0.74,-0.48),Vector2(0.85,-0.15),Vector2(0.48,0.18)]),0.07,Vector3.ZERO,bone)
		arms.append(arm)

func build_moth() -> void:
	var dark := mat("leaf")
	var shell := mat("bone")
	var gold := mat("gold",0.8)
	A.orb(body,Vector3(0,1.34,0),Vector3(0.42,0.83,0.35),dark)
	A.orb(head,Vector3(0.06,1.75,0),Vector3(0.45,0.40,0.38),shell)
	A.orb(body,Vector3(0.13,1.38,0.20),Vector3(0.23,0.38,0.10),gold)
	for side in [-1,1]:
		var wing := Node3D.new()
		wing.position = Vector3(0,1.52,side*0.09)
		body.add_child(wing)
		var shape := PackedVector2Array([Vector2(0,0),Vector2(-0.95,0.63),Vector2(-1.02,0.06),Vector2(-0.62,-0.35),Vector2(-0.87,-0.75),Vector2(-0.20,-0.49)])
		A.plate(wing,shape,0.06,Vector3.ZERO,dark)
		A.plate(wing,PackedVector2Array([Vector2(-0.25,0.08),Vector2(-0.79,0.43),Vector2(-0.75,0.02),Vector2(-0.53,-0.17)]),0.012,Vector3(0,0,side*0.075),shell)
		A.plate(wing,PackedVector2Array([Vector2(-0.45,-0.24),Vector2(-0.66,-0.58),Vector2(-0.28,-0.40)]),0.013,Vector3(0,0,side*0.075),gold)
		wings.append(wing)
		A.rod(head,Vector3(0,1.83,side*0.1),Vector3(0.22,2.14,side*0.17),0.025,dark,0.01)
		A.orb(head,Vector3(0.22,2.14,side*0.17),Vector3.ONE*0.09,gold)
		A.orb(head,Vector3(0.23,1.78,side*0.15),Vector3(0.08,0.12,0.06),gold)
		A.rod(body,Vector3(0.10,1.30,side*0.14),Vector3(0.40,1.1,side*0.20),0.024,dark)
	A.leaf(body,Vector3(-0.06,1.05,0),0.60,0.16,2.8,shell)

func build_guardian() -> void:
	var bark := mat("bark",1.6)
	var shell := mat("bone",1.5)
	var gold := mat("gold",1.0)
	A.orb(body,Vector3(-0.16,1.40,0),Vector3(1.60,1.60,1.0),bark)
	for side in [-1,1]:
		for i in range(3):
			var page := A.plate(body,PackedVector2Array([Vector2(-0.86,1.10),Vector2(-0.58,2.12),Vector2(0.06,2.51),Vector2(0.39,2.00),Vector2(0.30,1.26)]),0.10,Vector3(-i*0.12,-i*0.04,side*(0.31+i*0.10)),shell)
			page.rotation.y = side*0.18
		A.plate(body,PackedVector2Array([Vector2(-0.66,1.23),Vector2(-0.49,1.84),Vector2(-0.10,2.10),Vector2(-0.05,1.67)]),0.018,Vector3(0,0,side*0.64),gold)
	A.plate(head,PackedVector2Array([Vector2(0.16,2.38),Vector2(0.71,2.60),Vector2(1.07,2.16),Vector2(0.87,1.59),Vector2(0.42,1.52),Vector2(0.23,1.93)]),0.37,Vector3.ZERO,shell)
	for z in [-0.38,0.38]:
		A.plate(head,PackedVector2Array([Vector2(0.49,2.17),Vector2(0.86,2.20),Vector2(0.76,2.04),Vector2(0.52,2.02)]),0.025,Vector3(0,0,z),bark)
		A.plate(head,PackedVector2Array([Vector2(0.55,2.14),Vector2(0.83,2.16),Vector2(0.75,2.09),Vector2(0.55,2.08)]),0.03,Vector3(0,0,z*1.05),gold)
		A.leaf(head,Vector3(0.27,2.36,z*0.6),0.65,0.25,0.7,shell)
	for i in range(4):
		add_leg(Vector3(0.26 if i<2 else -0.55,1.02,0.42 if i%2==0 else -0.42),0.62,0.58,bark,shell,i)
	for side in [-1,1]:
		var arm := Node3D.new()
		arm.position = Vector3(0.30,1.72,side*0.60)
		body.add_child(arm)
		A.rod(arm,Vector3.ZERO,Vector3(0.28,-0.54,0),0.16,bark)
		A.plate(arm,PackedVector2Array([Vector2(0.05,-0.32),Vector2(0.53,-0.23),Vector2(0.94,-0.65),Vector2(0.65,-1.10),Vector2(0.26,-0.98)]),0.22,Vector3.ZERO,shell)
		A.plate(arm,PackedVector2Array([Vector2(0.35,-0.40),Vector2(0.49,-0.37),Vector2(0.78,-0.67),Vector2(0.65,-0.82)]),0.025,Vector3(0,0,side*0.23),gold)
		arms.append(arm)

func add_leg(hip: Vector3, upper_length: float, lower_length: float, dark: Material, shell: Material, index: int) -> void:
	var upper := A.rod(self,hip,hip+Vector3(0,-0.4,0),0.105 if kind=="melee" else 0.17,dark)
	var lower := A.rod(self,hip,hip+Vector3(0,-0.4,0),0.075 if kind=="melee" else 0.12,shell,0.045)
	var foot := A.orb(self,Vector3.ZERO,Vector3(0.32,0.12,0.23) if kind=="melee" else Vector3(0.45,0.16,0.34),dark)
	legs.append({"hip":hip,"upper":upper,"lower":lower,"foot":foot,"l1":upper_length,"l2":lower_length,"offset":0.0 if index in [0,3] else 0.5,"plant":Vector3.ZERO,"stance":false,"last":Vector3.ZERO})

func knee(a: Vector3, b: Vector3, l1: float, l2: float) -> Vector3:
	var d2 := Vector2(b.x-a.x,b.y-a.y)
	var distance := clampf(d2.length(),0.01,l1+l2-0.002)
	var along := (l1*l1-l2*l2+distance*distance)/(2*distance)
	var height := sqrt(maxf(0,l1*l1-along*along))
	var axis := d2.normalized()
	var k := Vector2(a.x,a.y)+axis*along+Vector2(-axis.y,axis.x)*height
	return Vector3(k.x,k.y,a.z)

func drive(dt: float, velocity: Vector2, state: String, progress: float, direction: int, flash: float) -> void:
	if body==null: return
	clock += dt
	var turned := last_direction!=direction or global_position.distance_to(previous_position)>0.85
	previous_position = global_position
	last_direction = direction
	rotation.y = 0 if direction>0 else PI
	var running := state=="run"
	if running: phase += absf(velocity.x)*dt/88.0
	var attack := state.begins_with("attack")
	var prepared := smoothstep(0.0,0.25,progress) if attack else 0.0
	var release := smoothstep(0.26,0.39,progress)*(1-smoothstep(0.58,0.99,progress)) if attack else 0.0
	var target_pose := prepared*0.18-release*0.67 if attack else -0.25 if state=="hurt" else 0.0
	pose = lerpf(pose,target_pose,1-exp(-dt*24))
	body.position.y = sin(clock*2.2)*0.012 if not running else absf(sin(phase*TAU))*0.035
	body.rotation.z = pose*0.20
	head.rotation.z = -pose*0.12
	for i in range(arms.size()):
		arms[i].rotation.z = pose*(1.4 if i==0 else 0.7)+(sin(phase*TAU+i*PI)*0.10 if running else 0.0)
	if kind=="ranged":
		body.position.y = sin(clock*3.5)*0.09+(0.12 if attack else 0.0)
		for i in range(wings.size()):
			var side: float = -1 if i==0 else 1
			wings[i].rotation.y = side*(0.55+sin(clock*9)*0.50+prepared*0.70-release*1.1)
			wings[i].rotation.z = side*0.08
	contact_error = 0
	drift_error = 0
	for leg in legs:
		var u: float = fposmod(phase+float(leg.offset),1.0)
		var stance: bool = not running or u<0.58
		var hip: Vector3 = leg.hip+body.position
		var local_foot := Vector3(hip.x+0.10,0.07,hip.z)
		if state=="air" or state=="hurt":
			local_foot += Vector3(0,0.12,0)
			stance = false
		elif stance:
			if not leg.stance or turned or last_state!=state:
				leg.plant = to_global(local_foot+Vector3(0.22 if running else 0,0,0))
				leg.plant.y = global_position.y+0.07
			local_foot = to_local(leg.plant)
		else:
			var swing: float = (u-0.58)/0.42
			local_foot.x += lerpf(-0.39,0.22,smoothstep(0,1,swing))
			local_foot.y += sin(swing*PI)*0.22
		var j := knee(hip,local_foot,leg.l1,leg.l2)
		A.place_rod(leg.upper,hip,j)
		A.place_rod(leg.lower,j,local_foot)
		leg.foot.position = local_foot
		var actual: Vector3 = leg.foot.global_position
		if stance:
			contact_error = maxf(contact_error,absf(actual.y-global_position.y-0.07))
			if leg.stance and not turned and last_state==state: drift_error = maxf(drift_error,actual.distance_to(leg.last))
		leg.last = actual
		leg.stance = stance
	last_state = state
	for m in materials: m.set_shader_parameter("flash",flash*0.8)
