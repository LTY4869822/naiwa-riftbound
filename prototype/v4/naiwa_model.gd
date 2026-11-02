extends Node3D
## Identity-constrained 3D candidate. Continuous body surface; rigid articulated limbs.
## Original asset is retained separately. Not the upstream author's source model.
const A = preload("res://v4/art.gd")
const PROFILE := [
	Vector4(0.83,-0.10,0.28,0.25),Vector4(0.94,-0.10,0.48,0.35),
	Vector4(1.14,-0.08,0.63,0.45),Vector4(1.40,-0.03,0.67,0.47),
	Vector4(1.66,0.02,0.57,0.41),Vector4(1.91,0.06,0.43,0.33),
	Vector4(2.14,0.17,0.30,0.25),Vector4(2.36,0.28,0.28,0.235),
	Vector4(2.55,0.26,0.26,0.215),Vector4(2.69,0.22,0.17,0.145),
	Vector4(2.73,0.22,0.015,0.015)
]
var body: Node3D
var arms: Array[Dictionary] = []
var legs: Array[Dictionary] = []
var materials: Array[ShaderMaterial] = []
var phase: float = 0
var clock: float = 0
var last_direction: int = 0
var last_state: String = ""
var previous_position := Vector3.ZERO
var contact_error: float = 0
var drift_error: float = 0
var gait_speed: float = 0

func mat(kind: String, outline: float = 1.1) -> ShaderMaterial:
	var m := A.material(kind,outline)
	materials.append(m)
	return m

func section(y: float) -> Vector3:
	for i in range(PROFILE.size()-1):
		var a: Vector4 = PROFILE[i]
		var b: Vector4 = PROFILE[i+1]
		if y<=b.x:
			var t := clampf((y-a.x)/(b.x-a.x),0,1)
			# Catmull-Rom smooth profile retains authored extrema, without sphere seams.
			var pre: Vector4 = PROFILE[maxi(0,i-1)]
			var post: Vector4 = PROFILE[mini(PROFILE.size()-1,i+2)]
			var v := 0.5*((2*a)+(-pre+b)*t+(2*pre-5*a+4*b-post)*t*t+(-pre+3*a-3*b+post)*t*t*t)
			return Vector3(v.y,v.z,v.w)
	return Vector3(0.22,0.015,0.015)

func body_point(y: float, angle: float, push: float = 0) -> Vector3:
	var s := section(y)
	return Vector3(s.x+(s.y+push)*cos(angle),y,(s.z+push)*sin(angle))

func surface(m: Material, belly: bool = false) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: int = 36 if not belly else 16
	var sides: int = 48
	var points: Array[PackedVector3Array] = []
	for j in range(rings+1):
		var ring := PackedVector3Array()
		for i in range(sides+1):
			var angle := TAU*i/sides
			if belly:
				var radius: float = float(j)/rings
				var y := 1.48+sin(angle)*0.55*radius
				var phi := cos(angle)*1.45*radius
				ring.append(body_point(y,phi,0.012))
			else:
				var y := lerpf(0.83,2.73,float(j)/rings)
				ring.append(body_point(y,angle))
		points.append(ring)
	for j in range(rings):
		for i in range(sides):
			var indices := [Vector2i(j,i),Vector2i(j+1,i),Vector2i(j,i+1),Vector2i(j,i+1),Vector2i(j+1,i),Vector2i(j+1,i+1)]
			if not belly: indices.reverse()
			for q in indices: st.add_vertex(points[q.x][q.y])
	st.generate_normals()
	A.mesh(body,st.commit(),Vector3.ZERO,m)

func _ready() -> void:
	var skin := mat("naiwa",1.15)
	var belly := mat("belly",0)
	var dark := mat("ink",0)
	body = Node3D.new()
	add_child(body)
	surface(skin)
	surface(belly,true)
	# The identity's small green eyes and short mouth are separate authored geometry.
	var iris := mat("bone",0.6)
	iris.set_shader_parameter("shade",Color("426847"))
	iris.set_shader_parameter("base",Color("7f9c50"))
	iris.set_shader_parameter("light",Color("b5c46c"))
	for side in [-1,1]:
		A.orb(body,Vector3(0.405,2.56,side*0.175),Vector3(0.178,0.183,0.058),mat("belly",0.7))
		A.orb(body,Vector3(0.414,2.561,side*0.205),Vector3(0.131,0.144,0.032),iris)
		A.orb(body,Vector3(0.435,2.565,side*0.221),Vector3(0.078,0.095,0.019),dark)
		A.orb(body,Vector3(0.447,2.59,side*0.233),Vector3.ONE*0.023,mat("paper",0))
		A.tube(body,[Vector3(0.549,2.382,side*0.12),Vector3(0.578,2.379,side*0.075),Vector3(0.584,2.38,0)],[0.008,0.010,0.005],dark,6)
	A.orb(body,Vector3(0.548,2.403,0),Vector3(0.14,0.052,0.23),skin)
	for i in range(2):
		var z: float = -0.25 if i==0 else 0.25
		var hip := Vector3(-0.13,0.98,z)
		var upper := A.orb(self,Vector3.ZERO,Vector3(0.35,0.64,0.34),skin)
		var lower := A.orb(self,Vector3.ZERO,Vector3(0.23,0.51,0.23),skin)
		var foot := Node3D.new()
		add_child(foot)
		A.orb(foot,Vector3(0.08,0,0),Vector3(0.44,0.14,0.29),skin)
		for toe in range(3): A.orb(foot,Vector3(0.23+sin(toe*PI/2)*0.03,-0.01,(toe-1)*0.072),Vector3(0.21,0.10,0.095),skin)
		legs.append({"hip":hip,"upper":upper,"lower":lower,"foot":foot,"plant":Vector3.ZERO,"stance":false,"last":Vector3.ZERO,"offset":0.0 if i==1 else 0.5})
		var arm_upper := A.orb(self,Vector3.ZERO,Vector3(0.31,0.50,0.31),skin)
		var arm_lower := A.orb(self,Vector3.ZERO,Vector3(0.32,0.49,0.31),skin)
		var hand := Node3D.new()
		add_child(hand)
		A.orb(hand,Vector3.ZERO,Vector3(0.30,0.25,0.16),skin)
		for finger in range(4):
			A.orb(hand,Vector3(0.11,0.073-finger*0.048,-0.01),Vector3(0.18,0.052,0.086),skin)
		A.orb(hand,Vector3(0.0,0.125,0),Vector3(0.12,0.07,0.09),skin)
		arms.append({"upper":arm_upper,"lower":arm_lower,"hand":hand,"z":z})
	previous_position = global_position
	drive(0.016,Vector2.ZERO,"idle",0,1,0)

func segment(node: Node3D, a: Vector3, b: Vector3, thickness: float) -> void:
	node.position = (a+b)*0.5
	node.quaternion = Quaternion(Vector3.UP,(b-a).normalized())
	node.scale = Vector3(thickness,(b-a).length()+thickness*0.37,thickness)

func joint(a: Vector3, b: Vector3, l1: float, l2: float, bend: float = 1) -> Vector3:
	var v := Vector2(b.x-a.x,b.y-a.y)
	var distance := clampf(v.length(),0.01,l1+l2-0.002)
	var along := (l1*l1-l2*l2+distance*distance)/(2*distance)
	var h := sqrt(maxf(0,l1*l1-along*along))
	var axis := v.normalized()
	var k := Vector2(a.x,a.y)+axis*along+Vector2(-axis.y,axis.x)*h*bend
	return Vector3(k.x,k.y,(a.z+b.z)*0.5)

func drive(dt: float, velocity: Vector2, state: String, progress: float, direction: int, flash: float) -> void:
	if body==null: return
	clock += dt
	var travel: float = absf(global_position.x-previous_position.x)
	var turned: bool = direction!=last_direction or travel>0.85
	last_direction = direction
	rotation.y = 0 if direction>0 else PI
	var running := state=="run"
	var airborne := state=="air" or (state=="hurt" and global_position.y>0.015)
	previous_position = global_position
	if running and dt>0: phase += minf(travel,absf(velocity.x)*dt/80+0.01)/0.92
	var attack := state.begins_with("attack")
	var step: int = int(state[-1]) if attack else 0
	var windup := smoothstep(0,0.28,progress) if attack else 0.0
	var strike := smoothstep(0.29,0.40,progress)*(1-smoothstep(0.56,1.0,progress)) if attack else 0.0
	var recoil := -0.10 if state=="hurt" else 0.0
	body.position.y = lerpf(body.position.y,-0.04-absf(sin(phase*TAU))*0.025 if running else -windup*0.035,1-exp(-dt*20))
	body.rotation.z = lerpf(body.rotation.z,(0.025*windup-0.035*strike+recoil),1-exp(-dt*24))
	contact_error = 0
	drift_error = 0
	for leg in legs:
		var u: float = fposmod(phase+float(leg.offset),1)
		var stance: bool = not running or u<0.56
		var hip: Vector3 = leg.hip+body.position
		var target := Vector3(0.02,0.075,hip.z)
		if airborne:
			target += Vector3(0.18 if leg.offset==0 else -0.15,0.24,0)
			stance = false
		elif attack and step==2 and leg.offset==0 and strike>0.01:
			target += Vector3(0.73,0.73,0)*strike
			stance = false
		elif stance:
			if not leg.stance or turned or last_state!=state:
				leg.plant = to_global(target+Vector3(0.20 if running else 0,0,0))
				leg.plant.y = global_position.y+0.075
			target = to_local(leg.plant)
		else:
			var swing: float = (u-0.56)/0.44
			target += Vector3(lerpf(-0.31,0.20,smoothstep(0,1,swing)),sin(swing*PI)*0.20,0)
		var k := joint(hip,target,0.51,0.48)
		segment(leg.upper,hip,k,0.35)
		segment(leg.lower,k,target,0.22)
		leg.foot.position = target
		leg.foot.rotation.z = strike*0.28 if attack and step==2 and leg.offset==0 else 0
		var actual: Vector3 = leg.foot.global_position
		if stance:
			contact_error = maxf(contact_error,absf(actual.y-global_position.y-0.075)*80)
			if leg.stance and not turned and last_state==state: drift_error = maxf(drift_error,actual.distance_to(leg.last)*80)
		leg.last = actual
		leg.stance = stance
	for i in range(arms.size()):
		var arm: Dictionary = arms[i]
		var z: float = float(arm.z)*1.5
		var shoulder := Vector3(0.04,1.92,z)+body.position
		var hand := Vector3(0.61,1.46,z*0.84)+body.position
		if running: hand += Vector3(sin(phase*TAU+i*PI)*0.18,cos(phase*TAU+i*PI)*0.08,0)
		if attack and i==(1 if step==0 else 0): hand += Vector3(-0.13,0.14,0)*windup+Vector3(0.32,0.15 if step==0 else 0.40,0)*strike
		if airborne: hand += Vector3(-0.10,0.18,0)
		if state=="hurt": hand += Vector3(-0.20,0.25,0)
		hand = shoulder+(hand-shoulder).limit_length(0.89)
		var elbow := joint(shoulder,hand,0.46,0.44,-1)
		segment(arm.upper,shoulder,elbow,0.28)
		segment(arm.lower,elbow,hand,0.27)
		arm.hand.position = hand
		arm.hand.rotation.z = strike*0.18
	for m in materials: m.set_shader_parameter("flash",flash*0.8)
	last_state = state
