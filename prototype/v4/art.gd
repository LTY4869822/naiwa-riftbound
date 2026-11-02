extends RefCounted
## Locked palette and authored ramps. See docs/ART_BIBLE_CEL.md.
const INK := Color("111b2b")
const SHADOW := Color("263c50")
const FOREST := Color("234c57")
const LEAF := Color("3c7980")
const DISTANT := Color("92b9b4")
const GOLD := Color("f3ce4f")
const CREAM := Color("fbe7aa")
const PAPER := Color("fff3d3")
const CYAN := Color("64d4cf")
const DANGER := Color("ee6676")
const CEL = preload("res://v4/cel.gdshader")
const OUTLINE = preload("res://v4/outline.gdshader")

static func material(kind: String = "stone", outline: float = 0.0) -> ShaderMaterial:
	var ramps := {
		"stone":[SHADOW,LEAF,DISTANT], "leaf":[INK,FOREST,LEAF],
		"bone":[SHADOW,DISTANT,PAPER], "gold":[Color("967335"),GOLD,CREAM],
		"cyan":[FOREST,LEAF,CYAN], "danger":[Color("70384c"),DANGER,CREAM],
		"bark":[INK,SHADOW,FOREST], "far":[LEAF,DISTANT,DISTANT],
		"sky":[DISTANT,DISTANT,DISTANT], "ink":[INK,INK,INK],
		"near_tree":[FOREST,FOREST,LEAF], "far_tree":[Color("719c9e"),Color("719c9c"),DISTANT],
		"naiwa":[Color("c59a35"),GOLD,CREAM], "belly":[Color("b99d5e"),CREAM,PAPER],
		"paper":[PAPER,PAPER,PAPER], "signal":[CYAN,CYAN,CREAM]
	}
	var ramp: Array = ramps.get(kind,ramps.stone)
	var m := ShaderMaterial.new()
	m.shader = CEL
	m.set_shader_parameter("shade",ramp[0])
	m.set_shader_parameter("base",ramp[1])
	m.set_shader_parameter("light",ramp[2])
	if outline>0:
		var edge := ShaderMaterial.new()
		edge.shader = OUTLINE
		edge.set_shader_parameter("ink",INK)
		edge.set_shader_parameter("width",outline)
		m.next_pass = edge
	return m

static func mesh(parent: Node3D, resource: Mesh, p: Vector3, m: Material) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = resource
	n.material_override = m
	n.position = p
	parent.add_child(n)
	return n

static func box(parent: Node3D, p: Vector3, size: Vector3, m: Material) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return mesh(parent,b,p,m)

static func orb(parent: Node3D, p: Vector3, size: Vector3, m: Material, rings: int = 10) -> MeshInstance3D:
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 20
	sphere.rings = rings
	var n := mesh(parent,sphere,p,m)
	n.scale = size
	return n

static func rod(parent: Node3D, a: Vector3, b: Vector3, radius: float, m: Material, tip: float = -1.0) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = radius if tip<0 else tip
	c.bottom_radius = radius
	c.height = 1
	c.radial_segments = 8
	var n := mesh(parent,c,Vector3.ZERO,m)
	place_rod(n,a,b)
	return n

static func place_rod(n: Node3D, a: Vector3, b: Vector3) -> void:
	var delta := b-a
	n.position = (a+b)*0.5
	n.quaternion = Quaternion(Vector3.UP,delta.normalized())
	n.scale.y = maxf(delta.length(),0.001)

static func plate(parent: Node3D, points: PackedVector2Array, depth: float, p: Vector3, m: Material) -> MeshInstance3D:
	# A closed, bevel-like folded plate with a central ridge; authored silhouette.
	var vertices := PackedVector3Array()
	var center := Vector2.ZERO
	for v in points: center += v
	center /= points.size()
	for i in range(points.size()):
		var a := points[i]
		var b := points[(i+1)%points.size()]
		vertices.append_array(PackedVector3Array([Vector3(center.x,center.y,depth),Vector3(a.x,a.y,0),Vector3(b.x,b.y,0),Vector3(center.x,center.y,-depth),Vector3(b.x,b.y,0),Vector3(a.x,a.y,0)]))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for v in vertices: st.add_vertex(v)
	st.generate_normals()
	return mesh(parent,st.commit(),p,m)

static func leaf(parent: Node3D, p: Vector3, length: float, width: float, angle: float, m: Material) -> MeshInstance3D:
	var points := PackedVector2Array([Vector2(0,0),Vector2(-width*0.5,length*0.32),Vector2(-width*0.35,length*0.7),Vector2(0,length),Vector2(width*0.44,length*0.55),Vector2(width*0.42,length*0.2)])
	var n := plate(parent,points,width*0.12,p,m)
	n.rotation.z = angle
	return n

static func tube(parent: Node3D, points: Array[Vector3], radii: Array[float], m: Material, sides: int = 12) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ring_points: Array[PackedVector3Array] = []
	for j in range(points.size()):
		var direction: Vector3 = points[mini(j+1,points.size()-1)]-points[maxi(0,j-1)]
		var rotation := Quaternion(Vector3.UP,direction.normalized())
		var ring := PackedVector3Array()
		for i in range(sides):
			var angle := TAU*i/sides
			ring.append(points[j]+rotation*Vector3(cos(angle)*radii[j],0,sin(angle)*radii[j]))
		ring_points.append(ring)
	for j in range(points.size()-1):
		for i in range(sides):
			var k: int = (i+1)%sides
			for v in [ring_points[j][i],ring_points[j][k],ring_points[j+1][i],ring_points[j][k],ring_points[j+1][k],ring_points[j+1][i]]: st.add_vertex(v)
	st.generate_normals()
	return mesh(parent,st.commit(),Vector3.ZERO,m)
