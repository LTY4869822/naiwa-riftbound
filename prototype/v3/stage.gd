extends Node3D
const RIG = preload("res://v3/enemy_rig.gd")
const NAIWA = preload("res://v3/naiwa_visual.gd")
var camera: Camera3D
var actors: Dictionary = {}
var time: float = 0.0
var visual_offset := Vector2.ZERO

func mat(color: String, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color)
	m.roughness = 0.85
	m.metallic = metal
	return m

func block(p: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	n.mesh = b
	n.position = p
	n.material_override = material
	add_child(n)
	return n

func _ready() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("102c31")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("a4bfbc")
	env.environment.ambient_light_energy = 0.26
	env.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38,-35,0)
	sun.light_color = Color("ffdf9b")
	sun.light_energy = 0.82
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 40
	add_child(sun)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20,155,0)
	rim.light_color = Color("69b9b6")
	rim.light_energy = 0.42
	add_child(rim)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 10
	camera.position = Vector3(0,6.059412,15)
	add_child(camera)
	camera.look_at(Vector3(0,3.059412,0))
	camera.current = true
	var stone := mat("60736b")
	var dark := mat("28464a")
	var trim := mat("8c9479")
	var gold := mat("c3a46a",0.4)
	block(Vector3(0,-0.22,0),Vector3(22,0.44,7),stone)
	block(Vector3(0,-0.48,2.8),Vector3(22,0.24,0.25),dark)
	for x in range(-11,12):
		block(Vector3(x,-0.005,1.0),Vector3(0.018,0.018,5.5),dark)
	for z in range(-3,4):
		block(Vector3(0,0.005,z),Vector3(22,0.018,0.02),dark)
	block(Vector3(0,5.0,-6),Vector3(25,11,0.5),dark)
	for x in [-9,-5,0,5,9]:
		block(Vector3(x,2.5,-3.5),Vector3(0.55,5,0.6),stone)
		block(Vector3(x,0.2,-3.5),Vector3(0.85,0.4,0.9),trim)
		block(Vector3(x,4.85,-3.5),Vector3(0.9,0.27,0.9),trim)
		if x<9:
			for i in range(13):
				var a: float = PI*i/12
				var b := block(Vector3(x+2.5+cos(a)*2.05,3.0+sin(a)*2.05,-3.5),Vector3(0.55,0.40,0.6),stone)
				b.rotation.z = a+PI/2
		for shelf in range(4):
			block(Vector3(x+1.75,0.8+shelf*0.72,-5.25),Vector3(2.25,0.10,0.9),stone)
			for j in range(7):
				var b := block(Vector3(x+0.8+j*0.29,1.04+shelf*0.72,-5.1),Vector3(0.19,0.39+sin(j*3+shelf)*0.08,0.35),mat(["4c655f","7c8770","a39a75","3b5960"][(j+shelf)%4]))
				b.rotation.z = sin(j+shelf)*0.08
	for x in [-6.8,6.8]:
		block(Vector3(x,2.15,-2),Vector3(0.045,4.3,0.045),dark)
		block(Vector3(x,4.3,-2),Vector3(1.5,0.05,0.05),gold)
		for side in [-1,1]:
			block(Vector3(x+side*0.60,3.8,-2),Vector3(0.035,0.9,0.035),gold)
			var lamp := block(Vector3(x+side*0.60,3.31,-2),Vector3(0.27,0.30,0.27),mat("edc97b"))
			lamp.material_override.emission_enabled = true
			lamp.material_override.emission = Color("d7a55d")*0.5
		var light := OmniLight3D.new()
		light.position = Vector3(x,2.5,0)
		light.light_color = Color("ffd390")
		light.light_energy = 0.42
		light.omni_range = 5
		add_child(light)
	for i in range(25):
		var x: float = sin(i*3.7)*10
		var b := block(Vector3(x,0.15,-2.0+cos(i)*0.5),Vector3(0.13,0.8+sin(i)*0.4,0.05),mat("456d5d"))
		b.rotation.z = sin(i*2)*0.5

func actor(node: Node, kind: String) -> Node:
	if kind=="hero":
		var original := NAIWA.new()
		get_parent().get_parent().add_child(original)
		actors[node.get_instance_id()] = original
		return original
	var r := RIG.new()
	r.kind = kind
	if kind=="boss": r.scale = Vector3.ONE*1.28
	elif kind!="hero": r.scale = Vector3.ONE*0.90
	add_child(r)
	actors[node.get_instance_id()] = r
	return r

func sync(node: Node, dt: float) -> void:
	var id: int = node.get_instance_id()
	if not actors.has(id): return
	var r: Node = actors[id]
	if r is Node2D: r.position = node.position+visual_offset
	else: r.position = Vector3((node.position.x-640)/80.0,(640-node.position.y)/(80*0.9805807),0)
	r.drive(dt,node.velocity,node.visual_state(),node.visual_progress(),node.facing,node.flash)
	if node.dead: r.scale *= maxf(0,1-dt*5)

func remove_actor(node: Node) -> void:
	var id: int = node.get_instance_id()
	if actors.has(id):
		actors[id].queue_free()
		actors.erase(id)

func reset() -> void:
	for r in actors.values(): r.queue_free()
	actors.clear()
