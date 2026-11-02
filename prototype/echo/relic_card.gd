extends Button
const T=preload("res://echo/ink.gd")
var host: Node
var menu: Control
var relic_id: String
var index:=0
var base:=Vector2.ZERO
var title: String=""
var age:=0.0
var focus_amount:=0.0
var press_amount:=0.0
var down:=false
var cancelled:=false
var font: Font
var bold: Font
var picture: Texture2D
var accent: Color
const ACCENTS={"edge":"gold","wind":"cyan","spring":"mint","echo":"violet"}
const CATEGORIES={"edge":"攻击强化","wind":"机动强化","spring":"治疗强化","echo":"反击蓄能"}

func _ready() -> void:
	text=""
	font=host.font; bold=menu.bold
	title=menu.director.RELICS[relic_id].title
	picture=T.emblem(relic_id)
	accent=T.color(ACCENTS[relic_id])
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	mouse_filter=Control.MOUSE_FILTER_STOP
	for state_name in ["normal","hover","pressed","focus","disabled"]: add_theme_stylebox_override(state_name,StyleBoxEmpty.new())
	focus_entered.connect(func(): menu.focus_card(index))
	focus_exited.connect(func(): down=false)
	button_down.connect(func(): down=true; cancelled=false)
	button_up.connect(func(): down=false)
	pressed.connect(press_activate)
	tooltip_text=""
	pivot_offset=size*.5

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.relative.length_squared()>.5 and not has_focus(): grab_focus()

func press_activate() -> void:
	if not cancelled: menu.activate(index)

func _process(dt: float) -> void:
	age+=dt
	var reduced: bool=host.reduce_motion
	var ease: float=1-exp(-minf(dt,.05)*19)
	focus_amount=float(has_focus()) if reduced else lerpf(focus_amount,float(has_focus()),ease)
	press_amount=float(down) if reduced else lerpf(press_amount,float(down),1-exp(-minf(dt,.05)*35))
	var entry: float=1 if reduced else clampf((age-index*float(T.settings().entry_stagger))/float(T.settings().entry_seconds),0,1)
	var u: float=entry-1
	var arrival: float=1+2.1*u*u*u+1.1*u*u
	position=base+Vector2(0,(1-arrival)*45-(0 if reduced else focus_amount*10))
	rotation_degrees=0 if reduced else lerpf([-1.6,1.2,-1.1][index],0,focus_amount)
	scale=Vector2.ONE if reduced else Vector2.ONE*(lerpf(.94,1,arrival)+focus_amount*.015-press_amount*.035)
	modulate.a=clampf(entry*2,0,1)
	queue_redraw()

func _draw() -> void:
	if picture==null: return
	var ink:=T.color("ink")
	var paper:=T.color("paper")
	var focus_color:=T.color("focus")
	var p:=T.ticket(Rect2(Vector2.ZERO,size))
	var shadow:=p.duplicate()
	for i in shadow.size(): shadow[i]+=Vector2(9,12)
	draw_colored_polygon(shadow,ink)
	if has_focus(): draw_polyline(T.outline(p),focus_color,24,true)
	draw_polyline(T.outline(p),ink,16,true)
	draw_polyline(T.outline(p),Color.WHITE,9,true)
	draw_colored_polygon(p,paper)
	for row in 6:
		for col in 9:
			var at:=Vector2(242+col*10,50+row*10)
			if at.x<330: draw_circle(at,1.6,Color(accent,.25))
	T.splat(self,Vector2(176,131),Vector2(119,95),accent,index*.8)
	for side in [-1,1]:
		draw_circle(Vector2(176+side*117,117-side*39),5,accent)
		draw_circle(Vector2(176+side*108,170+side*22),3,ink)
	var extent: Vector2=picture.get_size()
	var factor: float=minf(213/extent.x,185/extent.y)
	extent*=factor
	draw_texture_rect(picture,Rect2(Vector2(176,135)-extent*.5,extent),false)
	draw_set_transform(Vector2(23,20),-.035)
	draw_rect(Rect2(-2,3,125,27),ink)
	T.words(self,bold,CATEGORIES[relic_id],Vector2(9,23),15,paper)
	draw_set_transform(Vector2.ZERO)
	T.words(self,bold,"0"+str(index+1),Vector2(302,42),25,ink,44,true)
	T.words(self,bold,title,Vector2(176,247),32,ink,300,true)
	var lines: PackedStringArray=str(menu.director.RELICS[relic_id].copy).split("\n")
	for i in lines.size(): T.words(self,font,lines[i],Vector2(27,285+i*29),18,T.color("text"),298)
	for i in 18: draw_line(Vector2(20+i*18,335),Vector2(28+i*18,335),Color(ink,.22),1.5,true)
	var action:=Rect2(20,352,312,56)
	draw_colored_polygon(T.ticket(action),ink)
	if focus_amount>.005:
		var flood:=action
		flood.size.x*=clampf(focus_amount,0,1)
		if flood.size.x>40: draw_colored_polygon(T.ticket(flood),Color(focus_color,focus_amount))
	if has_focus():
		var label_color: Color=ink if focus_amount>.5 else paper
		draw_colored_polygon(PackedVector2Array([Vector2(36,368),Vector2(36,392),Vector2(54,380)]),label_color)
		T.words(self,bold,"确认共鸣",Vector2(173,389),23,label_color,190,true)
		draw_rect(Rect2(274,369,45,23),ink)
		T.words(self,bold,"Enter",Vector2(297,385),11,paper,40,true)
	else: T.words(self,bold,"与此遗物共鸣",Vector2(176,389),22,paper,280,true)
