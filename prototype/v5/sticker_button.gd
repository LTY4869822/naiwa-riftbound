extends Button
## Rounded native ink button. The same transform drives drawing and the click target.
const INK := Color("17121f")
const ACID := Color("d7ff31")
const WHITE := Color("fffdf5")
var title := ""
var subtitle := ""
var serial := ""
var badge := ""
var tint := INK
var large := false
var chosen := false
var host: Node
var motion := 0.0
var velocity := 0.0
var title_font: Font
var body_font: Font
var primary := false
var glyph := ""
var rest_tilt := 0.0
var origin := Vector2(0.0,0.5)
var flood := 0.0
var clock := 0.0
var pressed_scale := 1.0
var _rounded := PackedVector2Array()
var _last_size := Vector2.ZERO

func _ready() -> void:
	text=""
	mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	for state in ["normal","hover","pressed","focus","disabled"]:
		add_theme_stylebox_override(state,StyleBoxEmpty.new())
	tooltip_text=title+(" · "+subtitle if not subtitle.is_empty() else "")
	if is_zero_approx(rest_tilt): rest_tilt=rotation_degrees
	mouse_entered.connect(func():
		if not disabled and is_instance_valid(host): host.play_sound("dash",-34,1.7))
	set_process(true)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		origin=Vector2(clampf(event.position.x/maxf(size.x,1),0,1),clampf(event.position.y/maxf(size.y,1),0,1))

func _process(dt: float) -> void:
	clock+=dt
	var target:=1.0 if (is_hovered() or has_focus()) and not disabled else 0.0
	var reduced: bool=is_instance_valid(host) and host.reduce_motion
	if reduced:
		motion=target
		flood=target
		pressed_scale=0.955 if button_pressed else 1.0
	else:
		var step:=minf(dt,0.033)
		velocity+=((target-motion)*190.0-velocity*20.5)*step
		motion+=velocity*step
		flood=move_toward(flood,target,dt/(0.43 if target>0 else 0.28))
		pressed_scale=move_toward(pressed_scale,0.955 if button_pressed else 1.0,dt/0.065)
	pivot_offset=size*0.5
	rotation_degrees=lerpf(rest_tilt,0.0,clampf(motion,0,1))
	scale=Vector2.ONE*(1.0+motion*0.045)*pressed_scale
	queue_redraw()

func rounded_rect(rect: Rect2, radius: float) -> PackedVector2Array:
	var points:=PackedVector2Array()
	var r:=minf(radius,minf(rect.size.x,rect.size.y)*0.5)
	var centers: Array[Vector2]=[rect.position+Vector2(r,r),Vector2(rect.end.x-r,rect.position.y+r),rect.end-Vector2(r,r),Vector2(rect.position.x+r,rect.end.y-r)]
	for corner in range(4):
		for part in range(9):
			var angle:=PI+float(corner)*PI*0.5+float(part)*PI/16.0
			points.append(centers[corner]+Vector2(cos(angle),sin(angle))*r)
	return points

func closed(points: PackedVector2Array) -> PackedVector2Array:
	var outline:=points.duplicate()
	if not outline.is_empty(): outline.append(outline[0])
	return outline

func draw_blob(center: Vector2, radius: float, color: Color, clip_polygon: PackedVector2Array) -> void:
	if radius<=0.1: return
	var points:=PackedVector2Array()
	for i in range(52):
		var a:=float(i)*TAU/52.0
		var wobble:=1.0+sin(a*3.0+0.8)*0.055+sin(a*5.0-0.6)*0.035
		points.append(center+Vector2(cos(a),sin(a))*radius*wobble)
	for clipped in Geometry2D.intersect_polygons(points,clip_polygon):
		if clipped.size()>=3: draw_colored_polygon(clipped,color)

func _draw() -> void:
	if size.x<20 or size.y<15: return
	var is_primary:=primary or large
	var compact:=size.y<58
	var face:=Rect2(3,2,size.x-7,size.y-10)
	var radius:=17.0 if is_primary else 13.0 if not compact else 11.0
	if size!=_last_size:
		_rounded=rounded_rect(face,radius)
		_last_size=size
	var base:=ACID if is_primary else tint
	if chosen: base=ACID
	if disabled: base=Color("342e40")
	var is_purple:=base.b>0.48 and base.r>0.35 and base.g<0.5
	var flood_tint:=ACID if chosen else WHITE
	var amount:=clampf(flood,0.0,1.0)
	var shadow:=rounded_rect(Rect2(face.position+Vector2(0,7),face.size),radius)
	draw_colored_polygon(shadow,Color("0d0a12"))
	draw_polyline(closed(shadow),Color(0.04,0.025,0.065,0.8),3.5,true)
	draw_colored_polygon(_rounded,base)
	if is_purple and not disabled:
		var drift:=0.0 if is_instance_valid(host) and host.reduce_motion else fmod(clock*7.3,22.0)
		for x in range(18,int(size.x)-8,18):
			for y in range(14,int(size.y)-10,18):
				var point:=Vector2(x+drift,y-drift*0.5)
				if face.grow(-9).has_point(point): draw_circle(point,1.25,Color(1,1,1,0.13))
	if amount>0.002:
		draw_blob(face.position+origin*face.size,face.size.length()*1.13*amount,flood_tint,_rounded)
	draw_polyline(closed(_rounded),Color(1,1,1,0.14 if not disabled else 0.06),2,true)
	var top:=rounded_rect(face.grow(-3),maxf(2,radius-3))
	if amount>0.01: draw_polyline(closed(top),Color(WHITE,amount*0.92),2,true)
	else:
		draw_line(Vector2(face.position.x+radius,face.position.y+3),Vector2(face.end.x-radius,face.position.y+3),Color(1,1,1,0.16),1.5,true)
	var initial_fg:=INK if is_primary or chosen else WHITE
	var fg:=initial_fg.lerp(INK,clampf(amount*2.0,0,1))
	if disabled: fg=Color("90869e")
	var display_font: Font=title_font if title_font!=null else get_theme_default_font()
	var copy_font: Font=body_font if body_font!=null else display_font
	var icon_space:=0.0
	if not glyph.is_empty():
		icon_space=32 if compact else 63 if is_primary else 56
		var icon_center:=Vector2(27 if compact else 47 if is_primary else 41,face.get_center().y)
		var icon_scale:=0.48 if compact else 1.1 if is_primary else 0.87
		draw_set_transform(icon_center,deg_to_rad(-8*clampf(motion,0,1)),Vector2.ONE*icon_scale*(1+0.12*motion))
		draw_icon(glyph,fg,base.lerp(flood_tint,amount))
		draw_set_transform(Vector2.ZERO)
	var left:=17.0+icon_space
	if not serial.is_empty():
		draw_string(display_font,Vector2(left,face.get_center().y+7),serial,HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color(fg,0.55))
		left+=44
	var reserve:=52.0 if not badge.is_empty() else 21.0
	var available:=maxf(12,face.end.x-left-reserve)
	var font_size:=18 if compact else 38 if is_primary else 26
	var minimum:=15 if compact else 28 if is_primary else 20
	while font_size>minimum and display_font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x>available:
		font_size-=1
	var has_sub:=not subtitle.is_empty() and not compact
	var baseline:=face.position.y+face.size.y*0.47 if has_sub else face.get_center().y+font_size*0.35
	draw_string(display_font,Vector2(left,baseline),title,HORIZONTAL_ALIGNMENT_LEFT,available,font_size,fg)
	if has_sub:
		var copy_size:=14
		while copy_size>11 and copy_font.get_string_size(subtitle,HORIZONTAL_ALIGNMENT_LEFT,-1,copy_size).x>available:
			copy_size-=1
		draw_string(copy_font,Vector2(left,baseline+25),subtitle,HORIZONTAL_ALIGNMENT_LEFT,available,copy_size,Color(fg,0.78))
	if not badge.is_empty():
		draw_string(display_font,Vector2(face.end.x-43,face.get_center().y+7),badge,HORIZONTAL_ALIGNMENT_LEFT,36,21,fg)

func draw_icon(kind: String, color: Color, cut: Color) -> void:
	match kind:
		"play", "start":
			draw_colored_polygon(PackedVector2Array([Vector2(-14,-20),Vector2(19,0),Vector2(-14,20)]),color)
		"feed", "file":
			var paper:=PackedVector2Array([Vector2(-15,-20),Vector2(5,-20),Vector2(16,-9),Vector2(16,21),Vector2(-15,21)])
			draw_colored_polygon(paper,color)
			draw_polyline(PackedVector2Array([Vector2(4,-18),Vector2(4,-7),Vector2(14,-7)]),cut,3,true)
			draw_line(Vector2(-8,1),Vector2(8,1),cut,3,true)
			draw_line(Vector2(-8,9),Vector2(4,9),cut,3,true)
		"growth", "stats":
			for i in range(3): draw_rect(Rect2(-18+i*13,10-i*12,9,14+i*12),color)
		"shop":
			draw_arc(Vector2(0,-16),7,-PI*0.85,PI*0.5,18,color,3,true)
			draw_line(Vector2(0,-9),Vector2(0,-3),color,3,true)
			draw_polyline(PackedVector2Array([Vector2(0,-3),Vector2(-24,15),Vector2(-24,21),Vector2(24,21),Vector2(24,15),Vector2(0,-3)]),color,4,true)
		"settings", "gear":
			var teeth:=PackedVector2Array()
			for i in range(32):
				var a:=float(i)*TAU/32
				teeth.append(Vector2(cos(a),sin(a))*(22 if i%4<2 else 16))
			draw_colored_polygon(teeth,color)
			draw_circle(Vector2.ZERO,8,cut)
		"pet", "frog":
			draw_circle(Vector2(-11,-10),11,color)
			draw_circle(Vector2(11,-10),11,color)
			var body:=PackedVector2Array()
			for i in range(36):
				var a:=float(i)*TAU/36
				body.append(Vector2(cos(a)*23,5+sin(a)*17))
			draw_colored_polygon(body,color)
			draw_circle(Vector2(-10,-10),4.4,cut)
			draw_circle(Vector2(10,-10),4.4,cut)
			draw_arc(Vector2(0,-1),12,0.25,PI-0.25,18,cut,3,true)
		"back":
			draw_polyline(PackedVector2Array([Vector2(7,-17),Vector2(-11,0),Vector2(7,17)]),color,7,true)
			draw_line(Vector2(-9,0),Vector2(20,0),color,7,true)
		_:
			draw_circle(Vector2.ZERO,16,color)
