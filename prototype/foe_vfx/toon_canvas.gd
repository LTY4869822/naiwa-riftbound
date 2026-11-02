extends "res://third_party/combat_vfx/vfx/magic/canvas.gd"
## Original cel-animation shapes: opaque silhouettes stay readable over detailed maps.
const ORB = preload("res://foe_vfx/shaders/chakra_orb.gdshader")
const FIRE_TEXTURE = preload("res://assets/foe-vfx-toon/fire-eruption-eight-frames.png")
const SPORE_TEXTURE = preload("res://assets/foe-vfx-toon/spore-eruption-eight-frames.png")
const LIGHTNING_TEXTURE = preload("res://assets/foe-vfx-toon/lightning-eight-frames.png")
const WIND_TEXTURE = preload("res://assets/foe-vfx-toon/wind-slash-eight-frames.png")
const FIST_TEXTURE = preload("res://assets/ultimates-v2/star-fist.png")
const ROOT_TEXTURE = preload("res://assets/ultimates-v2/root-crown.png")
const CLAW_TEXTURE = preload("res://assets/ascension/vfx/claw.png")
const ECLIPSE_TEXTURE = preload("res://assets/ascension/vfx/eclipse.png")
## The generated root crown's fifth frame is wider; use measured empty gutters
## rather than cutting the organic silhouette at a nominal quarter-sheet line.
const ROOT_REGIONS:=[Rect2(0,0,443,450),Rect2(443,0,444,450),Rect2(887,0,443,450),Rect2(1330,0,444,450),Rect2(0,450,535,437),Rect2(535,450,412,437),Rect2(947,450,423,437),Rect2(1370,450,404,437)]
const FLIPBOOK = preload("res://foe_vfx/shaders/cel_flipbook.gdshader")
var shapes: Array=[]
var ink: Node2D
var pools: Dictionary={}
var invalid_polygons:=0

class Ink extends Node2D:
	var commands: Array=[]
	func _draw() -> void:
		for cmd in commands:
			if cmd[0]=="poly":
				draw_set_transform(cmd[3])
				draw_colored_polygon(cmd[1],cmd[2])
				draw_set_transform(Vector2.ZERO)
			elif cmd[0]=="line":
				draw_polyline(cmd[1],cmd[2],cmd[3],true)
			elif cmd[0]=="ellipse":
				draw_set_transform(cmd[1],cmd[4],cmd[2])
				draw_circle(Vector2.ZERO,1.0,cmd[3],true,-1,true)
				draw_set_transform(Vector2.ZERO)

func _init() -> void:
	super()
	ink=Ink.new()
	ink.z_index=2
	add_child(ink)

func begin(seconds: float) -> void:
	super.begin(seconds)
	shapes=[]
	for key in pools: pools[key].used=0

func polygon(points: PackedVector2Array, color: Color) -> void:
	if points.size()>=3 and color.a>0.005:
		# Triangulate in local coordinates: tiny fading debris at world x=1000 loses
		# precision in the renderer's global-coordinate polygon triangulation.
		var low: Vector2=points[0]
		var high: Vector2=points[0]
		for p in points:
			low=low.min(p)
			high=high.max(p)
		if minf(high.x-low.x,high.y-low.y)<0.4: return
		var origin: Vector2=(low+high)*0.5
		var local:=PackedVector2Array()
		for p in points: local.append(p-origin)
		if Geometry2D.triangulate_polygon(local).is_empty():
			invalid_polygons+=1
			if invalid_polygons<=3: print("TOON_INVALID_POLYGON ",points)
			return
		shapes.append(["poly",local,color,origin])

func stroke(points: PackedVector2Array, color: Color, width: float) -> void:
	if points.size()>=2 and width>0.1 and color.a>0.005: shapes.append(["line",points,color,width])

func ellipse(at: Vector2, radius: Vector2, color: Color, angle: float=0.0) -> void:
	if radius.x>0.1 and radius.y>0.1 and color.a>0.005: shapes.append(["ellipse",at,radius,color,angle])

func flipbook(key: String, ground: Vector2, size: Vector2, frame: float, alpha: float, angle: float=0.0, side: int=1, palette: Array=[]) -> void:
	var texture: Texture2D=CLAW_TEXTURE if key=="claw" else ECLIPSE_TEXTURE if key=="eclipse" else FIST_TEXTURE if key=="fist" else ROOT_TEXTURE if key=="roots" else FIRE_TEXTURE if key=="fire" else LIGHTNING_TEXTURE if key=="lightning" else WIND_TEXTURE if key=="wind" else SPORE_TEXTURE
	var index: int=clampi(floori(frame),0,7)
	var pool_key: String="sprite_"+key
	if not pools.has(pool_key): pools[pool_key]={"nodes":[],"used":0}
	var pool: Dictionary=pools[pool_key]
	if pool.used>=pool.nodes.size():
		var created:=MeshInstance2D.new()
		created.mesh=Art.unit_quad()
		created.material=ShaderMaterial.new()
		created.material.shader=FLIPBOOK
		created.texture=texture
		created.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
		created.z_index=1
		add_child(created)
		pool.nodes.append(created)
	var node: MeshInstance2D=pool.nodes[pool.used]
	pool.used+=1
	node.visible=true
	var pivot: float=0.5 if key in ["wind","fist","claw","eclipse"] else 0.96
	node.position=ground+Vector2(-size.x*0.5*side,-size.y*pivot).rotated(angle)
	node.rotation=angle
	node.scale=Vector2(size.x*side,size.y)
	var mat: ShaderMaterial=node.material
	mat.set_shader_parameter("region",Vector4(float(index%4)/4,float(floori(float(index)/4))/2,0.25,0.5))
	if key=="roots":
		var region: Rect2=ROOT_REGIONS[index]
		var extent:=Vector2(ROOT_TEXTURE.get_width(),ROOT_TEXTURE.get_height())
		mat.set_shader_parameter("region",Vector4(region.position.x/extent.x,region.position.y/extent.y,region.size.x/extent.x,region.size.y/extent.y))
	mat.set_shader_parameter("opacity",alpha)
	mat.set_shader_parameter("plasma",1.0 if key=="lightning" else 0.0)
	mat.set_shader_parameter("recolor",1.0 if not palette.is_empty() else 0.0)
	if not palette.is_empty():
		mat.set_shader_parameter("light_color",palette[0])
		mat.set_shader_parameter("body_color",palette[1])
		mat.set_shader_parameter("edge_color",palette[2])

func cel_quad(key: String, at: Vector2, size: Vector2, seconds: float, alpha: float, palette: Array, angle: float=0.0, seed_id: float=0.0) -> void:
	if key=="flame":
		flipbook("fire",at+Vector2(0,size.y*0.48).rotated(angle),size,2+fposmod(seconds*15+seed_id,3),alpha,angle)
		return
	if not pools.has(key): pools[key]={"nodes":[],"used":0}
	var pool: Dictionary=pools[key]
	if pool.used>=pool.nodes.size():
		var node:=MeshInstance2D.new()
		node.mesh=Art.unit_quad()
		var mat:=ShaderMaterial.new()
		mat.shader=ORB
		node.material=mat
		node.z_index=1
		add_child(node)
		pool.nodes.append(node)
	var node: MeshInstance2D=pool.nodes[pool.used]
	pool.used+=1
	node.visible=true
	node.position=at-Vector2(size.x/2,size.y/2).rotated(angle)
	node.rotation=angle
	node.scale=size
	var mat: ShaderMaterial=node.material
	mat.set_shader_parameter("clock",seconds)
	mat.set_shader_parameter("opacity",alpha)
	mat.set_shader_parameter("seed_id",seed_id)
	mat.set_shader_parameter("light_color",palette[0])
	mat.set_shader_parameter("body_color",palette[1])
	mat.set_shader_parameter("edge_color",palette[2])
	mat.set_shader_parameter("ink_color",palette[3])

func finish() -> void:
	super.finish()
	ink.commands=shapes
	ink.queue_redraw()
	for key in pools:
		var pool: Dictionary=pools[key]
		for i in range(pool.used,pool.nodes.size()): pool.nodes[i].visible=false
