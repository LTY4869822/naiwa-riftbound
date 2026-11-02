extends Node3D
const A = preload("res://v4/art.gd")
const CREATURE = preload("res://v4/creature.gd")
const NAIWA = preload("res://v4/naiwa_model.gd")
var camera: Camera3D
var actors: Dictionary = {}
var visual_offset := Vector2.ZERO
var plants: Array[Node3D] = []
var time: float = 0
var battle_visible: bool = false

func _ready() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = A.DISTANT
	add_child(env)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 10
	camera.position = Vector3(0,6.059412,15)
	add_child(camera)
	camera.look_at(Vector3(0,3.059412,0))
	camera.current = true
	build_world()

func tree(root: Vector3, height: float, depth: int, material: Material) -> void:
	var bend: float = sin(root.x*1.7)*0.7
	var points: Array[Vector3] = []
	var radii: Array[float] = []
	for i in range(9):
		points.append(root+Vector3(bend*i*0.24+sin(i*0.48)*0.16,height*i/8.0,0))
		radii.append((0.53-i*0.055)*(1.0 if depth==0 else 0.7))
	A.tube(self,points,radii,material,14)
	for side in [-1,1]:
		var start := root+Vector3(bend*0.4,height*0.47,0)
		var end := start+Vector3(side*(1.5+depth*0.25),height*0.30,0)
		A.tube(self,[start,start.lerp(end,0.5)+Vector3(0,-0.18,0),end],[0.20,0.12,0.015],material)
		for i in range(3):
			A.orb(self,end+Vector3(side*i*0.51,0.25+sin(i)*0.22,-0.15),Vector3(2.1,1.0,1.1),material,8)

func build_world() -> void:
	var far := A.material("far_tree")
	var mid := A.material("leaf",0.6)
	var bark := A.material("bark",0.7)
	var stone := A.material("stone",0.5)
	var bone := A.material("bone",0.55)
	var grass := A.material("cyan",0.7)
	var moon := A.material("paper")
	A.orb(self,Vector3(2.6,6.8,-10),Vector3(3.3,3.3,0.08),moon,24)
	for x in [-13,-10,-7,-3,1,5,8,12]: tree(Vector3(x,0,-9),7.4+sin(x)*1.5,2,far)
	# Ruined aqueduct: a single recognizable arch instead of a repeated tile wall.
	for i in range(17):
		var angle: float = PI*i/16.0
		var block := A.box(self,Vector3(1.5+cos(angle)*3.2,1.15+sin(angle)*3.2,-5),Vector3(0.72,0.42,0.8),stone)
		block.rotation.z = angle+PI/2
	for side in [-1,1]:
		A.box(self,Vector3(1.5+side*3.2,0.56,-5),Vector3(0.65,1.15,0.8),stone)
		A.box(self,Vector3(1.5+side*3.2,0.12,-5),Vector3(1.05,0.24,1.1),bone)
	for x in [-9.0,-6.9,7.9,10.4]: tree(Vector3(x,0,-4.2),6.6+cos(x)*0.8,0,A.material("near_tree",0.55))
	# Ground is flat at world y=0, exactly matching the collision plane.
	A.box(self,Vector3(0,-0.39,0),Vector3(22,0.58,3.6),stone)
	A.box(self,Vector3(0,-0.05,0),Vector3(22,0.10,3.7),bone)
	A.box(self,Vector3(0,-0.55,1.86),Vector3(22,0.30,0.06),A.material("bark"))
	for i in range(19):
		var x: float = -10+i*1.14
		var slab := A.box(self,Vector3(x,-0.28,1.82),Vector3(1.1,0.40,0.13),stone)
		slab.rotation.z = sin(i*7.3)*0.045
		if i%3==0:
			A.plate(self,PackedVector2Array([Vector2(0,0),Vector2(0.25,-0.4),Vector2(-0.14,-0.24)]),0.05,Vector3(x,-0.5,1.91),bark)
	for i in range(24):
		var x: float = -11+i*0.97
		var z: float = -2.2-fmod(i*0.43,1.6)
		var cluster := Node3D.new()
		cluster.position = Vector3(x,0,z)
		add_child(cluster)
		for j in range(3):
			A.leaf(cluster,Vector3(j*0.07,0,0),0.24+fmod(i*0.17+j*0.21,0.32),0.12,(j-1)*0.56+sin(i)*0.16,grass if i%4==0 else mid)
		plants.append(cluster)
	for x in [-6.0,6.0]:
		A.box(self,Vector3(x,0.38,-2.5),Vector3(0.60,0.75,0.65),stone)
		A.plate(self,PackedVector2Array([Vector2(0,0.63),Vector2(-0.19,0.94),Vector2(0,1.24),Vector2(0.19,0.94)]),0.13,Vector3(x,0,-2.5),A.material("gold",0.9))
	# Foreground framing stays outside the playable central silhouette band.
	for side in [-1,1]:
		for i in range(4):
			A.leaf(self,Vector3(side*(8.4+i*0.2),-0.6,2.1),1.1+i*0.32,0.48,side*(0.45+i*0.17),bark)

func animate(dt: float) -> void:
	time += dt
	for i in range(plants.size()): plants[i].rotation.z = sin(time*0.8+i*1.7)*0.025

func set_battle_visible(value: bool) -> void:
	battle_visible = value
	for r in actors.values():
		if is_instance_valid(r): r.visible = value

func actor(node: Node, kind: String) -> Node:
	var r: Node
	if kind=="hero":
		r = NAIWA.new()
		add_child(r)
	else:
		r = CREATURE.new()
		r.kind = kind
		add_child(r)
	actors[node.get_instance_id()] = r
	r.visible = battle_visible
	return r

func sync(node: Node, dt: float) -> void:
	var id: int = node.get_instance_id()
	if not actors.has(id): return
	var r: Node = actors[id]
	if r is Node2D: r.position = node.position+visual_offset
	else: r.position = Vector3((node.position.x-640)/80.0,(640-node.position.y)/(80*0.9805807),0)
	r.drive(dt,node.velocity,node.visual_state(),node.visual_progress(),node.facing,node.flash)

func remove_actor(node: Node) -> void:
	var id: int = node.get_instance_id()
	if actors.has(id):
		actors[id].queue_free()
		actors.erase(id)

func reset() -> void:
	for r in actors.values(): r.queue_free()
	actors.clear()
