extends Node2D
## Face and torso remain rigid. Only leg vertices receive local skinning weights.
const SOURCE = preload("res://assets/naiwa/idle.png")
const PATCH = preload("res://assets/v4/naiwa-underpaint.png")
const CUTOUT = preload("res://v5/cutout.gdshader")
const BLINK := [preload("res://assets/naiwa/blink_0_00.png"),preload("res://assets/naiwa/blink_0_01.png"),preload("res://assets/naiwa/blink_0_02.png"),preload("res://assets/naiwa/blink_0_03.png"),preload("res://assets/naiwa/blink_0_04.png"),preload("res://assets/naiwa/blink_0_05.png")]
const SIZE := 0.72
const SOLE := 351.0
const STRIDE := 22.0
const STANCE := 0.58
var root: Node2D
var arm: Polygon2D
var original: Sprite2D
var pieces: Node2D
var legs: Array[Dictionary] = []
var phase := 0.0
var last_x := 0.0
var last_direction := 0
var last_state := ""
var body_shift := Vector2.ZERO
var arm_angle := 0.0
var planted_points: Array[Vector2] = []
var ground_error := 0.0
var slide_error := 0.0
var reach_error := 0.0
var initialized := false
var skin: Polygon2D
var skin_source := PackedVector2Array()
var body_roll := 0.0
var body_transform := Transform2D.IDENTITY
var face_rigidity_error := 0.0
var settling := 0.0
var last_ankles: Array[Vector2] = [Vector2(129,322),Vector2(173,334)]
var time := 0.0
var settled_world: Array[Vector2] = []

func cut(parent: Node2D, points: Array, origin: Vector2, patch: bool=false) -> Polygon2D:
	var p := Polygon2D.new()
	var vertices := PackedVector2Array()
	var uvs := PackedVector2Array()
	for v in points:
		vertices.append(Vector2(v[0],v[1])-origin)
		uvs.append(Vector2(v[0],v[1]))
	p.polygon=vertices
	p.uv=uvs
	p.texture=SOURCE
	if patch:
		var material_ := ShaderMaterial.new()
		material_.shader=CUTOUT
		material_.set_shader_parameter("underpaint",PATCH)
		material_.set_shader_parameter("body_patch",true)
		p.material=material_
	parent.add_child(p)
	return p

func _ready() -> void:
	root=Node2D.new()
	add_child(root)
	pieces=Node2D.new()
	root.add_child(pieces)
	make_leg(Vector2(123,252),Vector2(127,291),Vector2(129,322),true)
	make_leg(Vector2(169,253),Vector2(177,297),Vector2(173,334),false)
	# A continuous skin across hips/knees avoids the visible card-cut seams.
	# Vertices above the hips have zero leg weights, so head/body remain rigid.
	skin=Polygon2D.new()
	skin.texture=SOURCE
	var faces: Array[PackedInt32Array]=[]
	for y in 47:
		for x in 37: skin_source.append(Vector2(x*8,y*8))
	for y in 46:
		for x in 36:
			var a := y*37+x
			faces.append(PackedInt32Array([a,a+1,a+38,a+37]))
	skin.polygon=skin_source
	skin.uv=skin_source
	skin.polygons=faces
	var skin_material := ShaderMaterial.new()
	skin_material.shader=CUTOUT
	skin_material.set_shader_parameter("underpaint",PATCH)
	skin_material.set_shader_parameter("body_patch",true)
	skin.material=skin_material
	pieces.add_child(skin)
	# The arm is one bent cutout: no elbow seam, fingers and proportions stay intact.
	arm=cut(pieces,[[166,138],[169,133],[176,132],[182,139],[187,149],[191,162],[187,177],[177,187],[157,197],[128,201],[115,207],[105,210],[94,205],[88,199],[91,193],[95,192],[91,187],[95,184],[96,180],[102,179],[113,186],[132,181],[149,174],[159,163],[160,144]],Vector2(174,140))
	original=Sprite2D.new()
	original.texture=SOURCE
	original.centered=false
	root.add_child(original)

func make_leg(hip: Vector2,knee: Vector2,ankle: Vector2,far: bool) -> void:
	var upper = [[98,247],[146,247],[144,283],[135,307],[124,309],[108,283]] if far else [[148,246],[204,246],[195,290],[183,313],[163,311],[150,279]]
	var lower = [[115,283],[141,283],[140,324],[125,331]] if far else [[160,286],[194,286],[185,335],[166,343]]
	var foot = [[81,312],[121,309],[146,315],[151,338],[79,339]] if far else [[145,323],[188,323],[201,340],[196,356],[142,356]]
	legs.append({"hip":hip,"knee":knee,"ankle":ankle,"upper":cut(pieces,upper,hip),"lower":cut(pieces,lower,knee),"foot":cut(pieces,foot,ankle),"l1":hip.distance_to(knee),"l2":knee.distance_to(ankle),"sole":12.0 if far else 17.0,"floor":334.0 if far else 351.0,"offset":0.5 if far else 0.0,"planted":false,"plant":Vector2.ZERO,"previous":Vector2.ZERO})
	for key in ["upper","lower","foot"]: legs[-1][key].visible=false

func solve(a: Vector2,b: Vector2,l1: float,l2: float) -> Vector2:
	var d := clampf(a.distance_to(b),absf(l1-l2)+0.01,l1+l2-0.001)
	var along := (l1*l1-l2*l2+d*d)/(2*d)
	var h := sqrt(maxf(0,l1*l1-along*along))
	var axis := (b-a).normalized()
	return a+axis*along+Vector2(axis.y,-axis.x)*h

func drive(dt: float,state: String,progress: float,direction: int,speed: float,ground_y: float) -> void:
	if dt<=0: return
	time+=dt
	var reset := not initialized or last_direction!=direction or absf(position.x-last_x)>60
	if not initialized:
		last_x=position.x
		initialized=true
	root.scale=Vector2(-direction*SIZE,SIZE)
	root.position=Vector2(direction*144*SIZE,-SOLE*SIZE)
	var running := state=="run"
	var attack := state.begins_with("attack")
	var attack_id := int(state[-1]) if state.length()>6 and attack else 0
	var airborne := state in ["air","dash"] or position.y<ground_y-0.1
	var moving := running or attack or state=="hurt" or airborne
	var travel := absf(position.x-last_x) if not reset else 0.0
	last_x=position.x
	if running: phase+=travel/(2*STRIDE*SIZE/STANCE)
	var windup := smoothstep(0.0,0.22,progress)*(1-smoothstep(0.22,0.34,progress)) if attack else 0.0
	var strike := smoothstep(0.22,0.34,progress)*(1-smoothstep(0.47,0.94,progress)) if attack else 0.0
	if last_state=="run" and not running and not airborne:
		settling=0.26
		settled_world.clear()
		for point in last_ankles: settled_world.append(to_stage(point))
	if reset or running or airborne: settling=0.0
	settling=maxf(0,settling-dt)
	var target := Vector2.ZERO
	if running: target=Vector2(0,6.0+absf(sin(phase*TAU))*0.8)
	if settling>0: target.y=6.0*settling/0.26
	if attack: target=Vector2(2*windup-2*strike,4+strike*2)
	if state=="hurt": target=Vector2(5,4)
	if airborne and not attack: target=Vector2(0,2)
	body_shift=body_shift.lerp(target,1-exp(-dt*30))
	if running: body_shift.y=maxf(body_shift.y,6.0)
	if state=="hurt": body_shift.y=maxf(body_shift.y,4.0)
	var target_roll := -0.018*minf(1,absf(speed)/150) if running else 0.0
	if attack: target_roll=0.012*windup-0.021*strike
	if state=="hurt": target_roll=0.018
	body_roll=lerpf(body_roll,target_roll,1-exp(-dt*18))
	var pivot := Vector2(150,240)
	body_transform=Transform2D(body_roll,body_shift+pivot-pivot.rotated(body_roll))
	# Keep one continuous visual; double exposed sprites caused ghost limbs at transitions.
	original.visible=false
	pieces.modulate.a=1.0
	ground_error=0
	slide_error=0
	reach_error=0
	planted_points.clear()
	for leg_index in legs.size():
		var leg: Dictionary=legs[leg_index]
		var hip: Vector2=body_transform*leg.hip
		var u := fposmod(phase+float(leg.offset),1.0)
		var stance := not airborne and (not running or u<STANCE) and settling<=0
		var ankle: Vector2=leg.ankle
		var same_contact: bool=leg.planted and not reset and last_state==state
		if stance:
			if not same_contact:
				if running: ankle.x+=lerpf(-STRIDE,STRIDE,u/STANCE)
				leg.plant=to_stage(ankle+Vector2(0,leg.sole))
				leg.plant.y=ground_y-(SOLE-float(leg.floor))*SIZE
			ankle=from_stage(leg.plant)-Vector2(0,leg.sole)
		elif settling>0:
			# One foot finishes its small settling step while the other remains planted.
			var settle_u := clampf((1-settling/0.26-leg_index*0.45)/0.55,0,1)
			ankle=from_stage(settled_world[leg_index]).lerp(leg.ankle,smoothstep(0,1,settle_u))
			ankle.y-=sin(settle_u*PI)*4
		elif running:
			var swing := (u-STANCE)/(1-STANCE)
			ankle+=Vector2(lerpf(STRIDE,-STRIDE,smoothstep(0,1,swing)),-sin(swing*PI)*9)
		else:
			ankle+=Vector2(-3 if leg.offset==0 else 5,-6 if leg.offset==0 else -8)
		var reach: float=hip.distance_to(ankle)-(leg.l1+leg.l2)
		reach_error=maxf(reach_error,maxf(0,reach)*SIZE)
		# Preserve limb lengths even at exceptional targets; never stretch pixels.
		ankle=hip+(ankle-hip).limit_length(leg.l1+leg.l2-0.001)
		var joint := solve(hip,ankle,leg.l1,leg.l2)
		leg.upper.position=hip
		leg.upper.rotation=(joint-hip).angle()-(leg.knee-leg.hip).angle()
		leg.lower.position=joint
		leg.lower.rotation=(ankle-joint).angle()-(leg.ankle-leg.knee).angle()
		leg.foot.position=ankle
		leg.foot.rotation=0
		last_ankles[leg_index]=ankle
		var actual: Vector2=leg.foot.to_global(Vector2(0,leg.sole))-get_parent().global_position
		if stance:
			ground_error=maxf(ground_error,absf(actual.y-leg.plant.y))
			if same_contact: slide_error=maxf(slide_error,actual.distance_to(leg.previous))
			planted_points.append(actual)
		leg.previous=actual
		leg.planted=stance
	var deformed := PackedVector2Array()
	face_rigidity_error=0
	for v in skin_source:
		var base := body_transform*v
		if v.y>244:
			var leg: Dictionary=legs[0 if v.x<145 else 1]
			var hip_w := smoothstep(244,279,v.y)
			var knee_w := smoothstep(leg.knee.y-14,leg.knee.y+14,v.y)
			var foot_w := smoothstep(leg.ankle.y-12,leg.ankle.y+1,v.y)
			var transforms: Array[Transform2D]=[body_transform,leg.upper.transform*Transform2D(0,-leg.hip),leg.lower.transform*Transform2D(0,-leg.knee),leg.foot.transform*Transform2D(0,-leg.ankle)]
			var weights := [1-hip_w,hip_w*(1-foot_w)*(1-knee_w),hip_w*(1-foot_w)*knee_w,hip_w*foot_w]
			base=blend_rigid(v,transforms,weights)
		deformed.append(base)
	skin.polygon=deformed
	# This monitors shape preservation of a face triangle in rendered mesh coordinates.
	var a := 8*37+15
	var b := 8*37+17
	var c := 11*37+15
	face_rigidity_error=maxf(absf(deformed[a].distance_to(deformed[b])-skin_source[a].distance_to(skin_source[b])),absf(deformed[a].distance_to(deformed[c])-skin_source[a].distance_to(skin_source[c])))
	var target_angle := 0.0
	if running: target_angle=sin(phase*TAU-0.35)*0.10
	if attack: target_angle=-windup*0.14+strike*[0.48,0.68,0.82][mini(attack_id,2)]
	if state=="hurt": target_angle=-0.2
	if airborne and not attack: target_angle=0.14
	arm_angle=lerpf(arm_angle,target_angle,1-exp(-dt*38))
	arm.position=body_transform*Vector2(174,140)
	arm.rotation=arm_angle+body_roll
	var blink_time := fmod(time+1.1,5.7)
	var face_texture: Texture2D=BLINK[mini(5,int(blink_time*25))] if blink_time<0.24 else SOURCE
	skin.texture=face_texture
	original.texture=face_texture
	if not moving and settling<=0 and body_shift.length()<0.08 and absf(arm_angle)<0.002 and absf(body_roll)<0.0005:
		original.visible=true
		pieces.modulate.a=0
	last_direction=direction
	last_state=state

func blend_rigid(v: Vector2,transforms: Array[Transform2D],weights: Array) -> Vector2:
	# 2D dual-quaternion blending: normalize rotation rather than averaging scaled points.
	# Linear skinning thinned the knee whenever two bone rotations opposed each other.
	var q := Vector2.ZERO
	var dual := Vector2.ZERO
	for i in weights.size():
		var weight: float=weights[i]
		if weight<=0: continue
		var transform_: Transform2D=transforms[i]
		var half_angle := transform_.get_rotation()*0.5
		var cs := cos(half_angle)
		var sn := sin(half_angle)
		q+=Vector2(cs,sn)*weight
		var translation := transform_.origin
		dual+=Vector2(translation.x*cs+translation.y*sn,translation.y*cs-translation.x*sn)*(weight*0.5)
	var norm := maxf(q.length(),0.00001)
	q/=norm
	dual/=norm
	var translation := Vector2(dual.x*q.x-dual.y*q.y,dual.x*q.y+dual.y*q.x)*2
	return v.rotated(atan2(q.y,q.x)*2)+translation

func hand_world() -> Vector2:
	return arm.to_global(Vector2(101,196)-Vector2(174,140))

func to_stage(point: Vector2) -> Vector2:
	return root.to_global(point)-get_parent().global_position

func from_stage(point: Vector2) -> Vector2:
	return root.to_local(point+get_parent().global_position)
