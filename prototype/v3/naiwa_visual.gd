extends Node2D
## Original Naiwa bitmap, with bounded limb skinning. No replacement head/body model.
var mesh: MeshInstance2D
var shader: ShaderMaterial
var phase: float = 0
var clock: float = 0
var contact_error: float = 0
var front := Vector2.ZERO
var rear := Vector2.ZERO
var palm := Vector2.ZERO
var lean: float = 0

func _ready() -> void:
	z_index = 5
	mesh = MeshInstance2D.new()
	mesh.texture = load("res://assets/naiwa/idle.png")
	var vertices := PackedVector2Array()
	var uv := PackedVector2Array()
	var indices := PackedInt32Array()
	var nx: int = 36
	var ny: int = 46
	for y in range(ny+1):
		for x in range(nx+1):
			vertices.append(Vector2(x*8,y*8))
			uv.append(Vector2(float(x)/nx,float(y)/ny))
			if x<nx and y<ny:
				var i: int = y*(nx+1)+x
				indices.append_array(PackedInt32Array([i,i+1,i+nx+1,i+1,i+nx+2,i+nx+1]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = indices
	var surface := ArrayMesh.new()
	surface.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	mesh.mesh = surface
	shader = ShaderMaterial.new()
	shader.shader = preload("res://v3/naiwa.gdshader")
	mesh.material = shader
	mesh.position = Vector2(-144,-351)
	add_child(mesh)
	scale = Vector2(-0.72,0.72)

func drive(dt: float, velocity: Vector2, state: String, progress: float, direction: int, flash: float) -> void:
	if mesh==null: return
	clock += dt
	scale = Vector2(-direction*0.72,0.72)
	var target_front := Vector2.ZERO
	var target_rear := Vector2.ZERO
	var target_palm := Vector2.ZERO
	var target_lean: float = 0
	if state=="run":
		phase += absf(velocity.x)*dt/42.0*PI
		for i in range(2):
			var p: float = fposmod(phase+i*PI,TAU)
			var u: float = p/PI
			var foot := Vector2(lerpf(-18,18,u) if u<=1 else lerpf(18,-18,u-1),0 if u<=1 else -sin((u-1)*PI)*14)
			if i==0: target_front = foot
			else: target_rear = foot
		target_lean = -3
	elif state=="air":
		target_front = Vector2(-8,-12)
		target_rear = Vector2(8,-9)
		target_palm = Vector2(0,-5)
	elif state.begins_with("attack"):
		var step: int = int(state[-1])
		var extension: float = smoothstep(0.12,0.34,progress)*(1-smoothstep(0.54,1.0,progress))
		target_lean = -5*extension
		target_palm = Vector2(-16,-7 if step==0 else -14)*extension
		if step==2:
			target_front = Vector2(-25,-23)*extension
			target_palm = Vector2(3,-3)*extension
	elif state=="hurt":
		target_lean = 5
		target_palm = Vector2(4,-5)
	var weight: float = 1-exp(-dt*26)
	front = front.lerp(target_front,weight)
	rear = rear.lerp(target_rear,weight)
	palm = palm.lerp(target_palm,weight)
	lean = lerpf(lean,target_lean,weight)
	if target_front.y==0: front.y = 0
	if target_rear.y==0: rear.y = 0
	contact_error = minf(absf(front.y),absf(rear.y))
	shader.set_shader_parameter("front_foot",front)
	shader.set_shader_parameter("rear_foot",rear)
	shader.set_shader_parameter("palm",palm)
	shader.set_shader_parameter("lean",lean)
	shader.set_shader_parameter("flash",flash)
