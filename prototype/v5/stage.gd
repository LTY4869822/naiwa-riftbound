extends Node2D
const NAIWA = preload("res://v5/naiwa.gd")
const FOE_VISUAL = preload("res://v5/foe_visual.gd")
const FOREST = preload("res://assets/v4/forest.png")
var actors: Dictionary = {}
var time := 0.0
var level_index: int=0

func _process(dt: float) -> void:
	if visible:
		time+=dt
		queue_redraw()

func _draw() -> void:
	preload("res://campaign/scenery.gd").paint(self,level_index,time)
	# The painted platform's top is at y=640; actors share this collision baseline.
	for i in 14:
		var p := Vector2(70+i*88+sin(time*0.4+i)*12,270+fmod(i*83,310)+sin(time*0.65+i*2)*11)
		draw_circle(p,1.4,Color(0.96,0.86,0.56,0.12+0.12*sin(time+i)))
	for id in actors:
		var r: Node2D=actors[id]
		var width := 43.0 if r is NAIWA else 54.0
		var height := maxf(0,640-r.position.y)
		draw_set_transform(Vector2(r.position.x,640),0,Vector2(1,0.13))
		draw_circle(Vector2.ZERO,width,Color(0.025,0.06,0.055,0.35*clampf(1-height/170,0.15,1)))
		draw_set_transform(Vector2.ZERO)

func actor(node: Node,kind: String) -> Node:
	var r: Node2D=NAIWA.new() if kind=="hero" else FOE_VISUAL.new()
	if kind!="hero": r.kind=kind
	add_child(r)
	r.position=node.position
	if kind=="hero":
		r.z_index=5
		r.drive(1.0/120,"idle",0,node.facing,0,640)
	else: r.z_index=3
	actors[node.get_instance_id()]=r
	return r

func sync(node: Node,dt: float) -> void:
	var id: int=node.get_instance_id()
	if not actors.has(id): return
	var r: Node2D=actors[id]
	r.position=node.position
	if r is NAIWA:
		var state: String=node.visual_state()
		if node.state=="dash": state="dash"
		r.drive(dt,state,node.visual_progress(),node.facing,node.velocity.x,640)
	else: r.drive(dt,node)

func hand_position(node: Node) -> Vector2:
	var r: Node2D=actors.get(node.get_instance_id())
	if r==null or not r is NAIWA: return node.position+Vector2(node.facing*72,-140)
	return r.hand_world()-position

func remove_actor(node: Node) -> void:
	var id: int=node.get_instance_id()
	if actors.has(id):
		actors[id].queue_free()
		actors.erase(id)

func reset() -> void:
	for r in actors.values(): r.queue_free()
	actors.clear()
