extends RefCounted
const LEVELS = preload("res://campaign/levels.gd")
static var textures: Dictionary={}

static func texture(index: int, chapter: int=0) -> Texture2D:
	var path: String=LEVELS.get_stage(index,chapter).background
	if not textures.has(path): textures[path]=load(path)
	return textures[path]

static func paint(canvas: Node2D, index: int, clock: float, chapter: int=0) -> void:
	var definition: Dictionary=LEVELS.get_stage(index,chapter)
	var image: Texture2D=texture(index,chapter)
	var height: float=640.0/float(definition.floor_ratio)
	var width: float=height*image.get_width()/image.get_height()
	canvas.draw_texture_rect(image,Rect2((1280-width)/2,0,width,height),false)
	var calm: bool=bool(canvas.get_parent().reduce_motion)
	if calm: return
	if index==1:
		for i in 18:
			var p := Vector2(fmod(i*117.1+sin(clock*0.3+i)*18,1280),280+fmod(i*69-clock*11+10000,330))
			canvas.draw_circle(p,1.5,Color(0.68,0.65,1,0.22+0.13*sin(clock+i)))
	elif index==2:
		for i in 24:
			var p := Vector2(fmod(i*91.7-clock*84+100000,1390)-50,fmod(i*117.7+clock*350,640))
			canvas.draw_line(p,p+Vector2(-9,26),Color(0.76,0.85,0.96,0.13),1,true)
	elif index==3:
		for i in 22:
			var p := Vector2(fmod(i*99.3+sin(clock+i)*12,1280),640-fmod(i*41+clock*(14+i%4),420))
			canvas.draw_line(p,p+Vector2(2,-4),Color(1,0.61,0.24,0.30),1.5,true)
