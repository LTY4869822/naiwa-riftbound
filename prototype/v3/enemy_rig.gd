extends Node3D
## Articulated archive sentries. This model is never used for Naiwa.
var kind: String = "melee"
var body: Node3D
var head: Node3D
var limbs: Array = []
var feet: Array = []
var hands: Array = []
var materials: Array = []
var phase: float = 0.0
var facing: int = 1
var smooth_lean: float = 0.0
var t: float = 0.0
var contact_error: float = 0.0

func material(color: String, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color)
	m.roughness = 0.68
	m.metallic = metal
	materials.append([m,m.albedo_color])
	return m

func ellipsoid(parent: Node3D, p: Vector3, dimensions: Vector3, mat: Material) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1
	mesh.radial_segments = 20
	mesh.rings = 12
	n.mesh = mesh
	n.material_override = mat
	n.position = p
	n.scale = dimensions
	parent.add_child(n)
	return n

func box(parent: Node3D, p: Vector3, dimensions: Vector3, mat: Material) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	n.mesh = mesh
	n.material_override = mat
	n.position = p
	parent.add_child(n)
	return n

func segment(parent: Node3D, a: Vector3, b: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = 1.0
	mesh.radial_segments = 12
	mesh.rings = 5
	n.mesh = mesh
	n.material_override = mat
	parent.add_child(n)
	place_segment(n,a,b)
	return n

func place_segment(n: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var d := b-a
	n.position = (a+b)*0.5
	n.quaternion = Quaternion(Vector3.UP,d.normalized())
	n.scale = Vector3(1,maxf(0.01,d.length()),1)

func _ready() -> void:
	var skin := material("345b63",0.35)
	var shade := material("213d45")
	var cream := material("91b5ad",0.3)
	var black := material("1d302a")
	var eye := material("efb366")
	body = Node3D.new()
	add_child(body)
	box(body,Vector3(0,1.18,0),Vector3(0.77,0.93,0.64),skin)
	var chest := box(body,Vector3(0.09,1.38,0.12),Vector3(0.71,0.64,0.61),shade)
	chest.rotation.z = -0.12
	head = Node3D.new()
	body.add_child(head)
	ellipsoid(head,Vector3(0.05,1.96,0),Vector3(0.72,0.69,0.62),cream)
	for z in [-0.30,0.30]:
		box(head,Vector3(0.22,2.0,z),Vector3(0.40,0.13,0.045),black)
		box(head,Vector3(0.27,2.02,z*1.08),Vector3(0.25,0.046,0.02),eye)
	for z in [-0.36,0.36]:
		box(body,Vector3(-0.02,1.66,z),Vector3(0.46,0.24,0.32),cream)
	if kind=="boss":
		for z in [-0.22,0.22]:
			var horn := box(head,Vector3(-0.12,2.42,z),Vector3(0.13,0.47,0.14),eye)
			horn.rotation.z = 0.3
		box(body,Vector3(0.43,1.32,0.20),Vector3(0.035,0.48,0.36),cream)
	if kind=="ranged":
		var halo := MeshInstance3D.new()
		var ring := TorusMesh.new()
		ring.inner_radius = 0.36
		ring.outer_radius = 0.40
		halo.mesh = ring
		halo.material_override = eye
		halo.position = Vector3(-0.2,2.27,0)
		halo.rotation_degrees.x = 90
		head.add_child(halo)
	for i in range(2):
		var z: float = -0.25 if i==0 else 0.25
		var upper := segment(self,Vector3(0,0.89,z),Vector3(0.05,0.48,z),0.10,skin)
		var lower := segment(self,Vector3(0.05,0.48,z),Vector3(0.10,0.10,z),0.105,shade)
		var foot := Node3D.new()
		add_child(foot)
		ellipsoid(foot,Vector3(0.12,0,0),Vector3(0.49,0.16,0.24),shade)
		limbs.append([upper,lower])
		feet.append(foot)
		var arm_a := segment(self,Vector3(0,1.8,z*1.6),Vector3(0.1,1.3,z*1.8),0.15,skin)
		var arm_b := segment(self,Vector3(0.1,1.3,z*1.8),Vector3(0.45,1.25,z*1.9),0.135,skin)
		var hand := Node3D.new()
		add_child(hand)
		ellipsoid(hand,Vector3.ZERO,Vector3(0.28,0.28,0.18),cream)
		for f in range(4):
			ellipsoid(hand,Vector3(0.105,-0.085+f*0.052,0.01),Vector3(0.16,0.045,0.095),cream)
		hands.append([arm_a,arm_b,hand])
	drive(0.1,Vector2.ZERO,"idle",0,1,0)

func knee_between(a: Vector3, b: Vector3, l1: float, l2: float, bend: float) -> Vector3:
	var v := Vector2(b.x-a.x,b.y-a.y)
	var d: float = clampf(v.length(),0.015,l1+l2-0.005)
	var along: float = (l1*l1-l2*l2+d*d)/(2*d)
	var h: float = sqrt(maxf(0,l1*l1-along*along))
	var direction := v.normalized()
	var q := Vector2(a.x,a.y)+direction*along+Vector2(-direction.y,direction.x)*h*bend
	return Vector3(q.x,q.y,(a.z+b.z)*0.5)

func drive(dt: float, velocity: Vector2, state: String, progress: float, direction: int, flash: float) -> void:
	if body==null: return
	t += dt
	facing = direction
	rotation.y = 0 if direction>0 else PI
	var running: bool = state=="run"
	var air: bool = state=="air"
	if running: phase += absf(velocity.x)*dt/70.0*PI
	var attack: bool = state.begins_with("attack")
	var step: int = int(state[-1]) if attack else 0
	var strike: float = sin(clampf((progress-0.12)/0.62,0,1)*PI) if attack else 0
	var extension: float = smoothstep(0.12,0.35,progress)*(1-smoothstep(0.60,1.0,progress)) if attack else 0
	var lean: float = (0.10 if running else 0.0)+strike*(0.11 if step<2 else -0.12)
	if state=="hurt": lean = -0.16
	smooth_lean = lerpf(smooth_lean,lean,1-exp(-dt*20))
	body.rotation.z = -smooth_lean
	body.position.y = sin(phase*2)*0.022 if running else sin(t*2.4)*0.008
	body.position.x = strike*0.09
	head.rotation.z = smooth_lean*0.3
	contact_error = 0
	for i in range(2):
		var z: float = -0.25 if i==0 else 0.25
		var p: float = fposmod(phase+i*PI,TAU)
		var foot := Vector3(-0.03 if i==0 else 0.18,0.08,z)
		if running:
			# Half a cycle is planted stance. Its ground-relative speed opposes the body.
			var u: float = p/PI
			foot.x = lerpf(0.38,-0.38,u) if u<=1 else lerpf(-0.38,0.38,u-1)
			foot.y = 0.08 if u<=1 else 0.08+sin((u-1)*PI)*0.23
		if air:
			foot = Vector3(0.14 if i==0 else -0.24,0.26 if i==0 else 0.40,z)
		if attack and step==2 and i==1:
			foot = foot.lerp(Vector3(1.08,1.19,z),extension)
		var foot_node: Node3D = feet[i]
		foot_node.position = foot_node.position.lerp(foot,1-exp(-dt*30))
		if not air and (not running or foot.y<=0.081) and not (attack and step==2 and i==1):
			foot_node.position.y = 0.08
			contact_error = maxf(contact_error,absf(foot_node.position.y-0.08))
		foot_node.rotation.z = extension*0.25 if attack and step==2 and i==1 else 0
		var hip := Vector3(-0.02+body.position.x,0.88+body.position.y,z)
		var k := knee_between(hip,foot_node.position,0.48,0.47,1)
		place_segment(limbs[i][0],hip,k)
		place_segment(limbs[i][1],k,foot_node.position)
		var shoulder := Vector3(-0.04+body.position.x,1.78+body.position.y,z*1.6)
		var target := Vector3(0.39,1.23,z*1.9)
		if running: target += Vector3(sin(p+PI)*0.24,cos(p)*0.08,0)
		if attack and step<2 and i==(1 if step==0 else 0):
			target = target.lerp(Vector3(1.02,1.69 if step==0 else 1.91,z*1.6),extension)
		elif attack:
			target = target.lerp(Vector3(0.10,1.72,z*1.8),strike)
		if state=="hurt": target += Vector3(-0.20,0.24,0)
		var hand: Node3D = hands[i][2]
		hand.position = hand.position.lerp(target,1-exp(-dt*26))
		hand.rotation.z = -extension*0.18
		var elbow := knee_between(shoulder,hand.position,0.54,0.50,-1)
		place_segment(hands[i][0],shoulder,elbow)
		place_segment(hands[i][1],elbow,hand.position)
	for pair in materials:
		pair[0].albedo_color = pair[1].lerp(Color("fff3ce"),flash)
