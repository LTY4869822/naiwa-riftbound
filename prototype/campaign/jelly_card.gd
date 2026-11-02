extends Button
## A stable native hit target with a springy, separately deforming card surface.
## Text is drawn outside the squash layer and keeps its authored proportions.
const INK := Color("17121f")
const PAPER := Color("fffdf1")
var host: Node
var definition: Dictionary
var index := 0
var completed := false
var title_font: Font
var body_font: Font
var face: ColorRect
var paint: ShaderMaterial
var highlighted := false
var held := false
var confirmed := false
var hover := 0.0
var hover_velocity := 0.0
var press := 0.0
var press_velocity := 0.0
var flood := 0.0
var entrance := 0.0
var entrance_delay := 0.0
var origin := Vector2(0.15,0.75)
var rest_position := Vector2.ZERO
var rest_tilt := 0.0
var clock := 0.0
var confirm_age := 10.0
var stage_buttons: Array[Button]=[]

func _ready() -> void:
	text=""
	focus_mode=Control.FOCUS_ALL
	mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	for state in ["normal","hover","pressed","focus","disabled"]:
		add_theme_stylebox_override(state,StyleBoxEmpty.new())
	rest_position=position
	rest_tilt=[-0.7,0.65,0.55,-0.6][index]
	pivot_offset=size*0.5
	face=ColorRect.new()
	face.size=size
	face.pivot_offset=size*0.5
	face.mouse_filter=Control.MOUSE_FILTER_IGNORE
	face.show_behind_parent=true
	paint=ShaderMaterial.new()
	paint.shader=preload("res://campaign/jelly_card.gdshader")
	var image: Texture2D=load(definition.background)
	paint.set_shader_parameter("preview",image)
	paint.set_shader_parameter("preview_size",Vector2(image.get_size()))
	paint.set_shader_parameter("accent",definition.color)
	paint.set_shader_parameter("extent",size)
	face.material=paint
	add_child(face)
	button_down.connect(func(): held=true)
	button_up.connect(func():
		held=false
		if not host.reduce_motion: press_velocity-=2.8)
	tooltip_text=definition.hint+"。确认后重新挑战该关，等级与成长共用。"
	if host.get("stage_index")!=null and host.get("journey")==null:
		for chapter in 3:
			var b:=Button.new()
			b.name="Stage%d" % (chapter+1)
			b.position=Vector2(325+chapter*70,158)
			b.size=Vector2(64,57)
			var d: Dictionary=preload("res://campaign/levels.gd").get_stage(index,chapter)
			var cleared: bool=int(Wardrobe.clears.get(d.id,0))>0
			b.text=("✓ " if cleared else "")+str(chapter+1)+"关"
			var reward: Dictionary=preload("res://wardrobe/catalog.gd").REWARDS[d.id]
			b.tooltip_text=d.chapter_title+" · 守关者："+d.boss_name+(" · 重游奖励 " if cleared else " · 首通奖励 ")+str(reward["repeat" if cleared else "first"])+" 金币"
			b.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
			b.add_theme_font_override("font",body_font)
			b.add_theme_font_size_override("font_size",16)
			b.add_theme_color_override("font_color",PAPER)
			b.add_theme_color_override("font_hover_color",INK)
			b.add_theme_stylebox_override("normal",panel(Color("392449") if chapter<2 else Color("642a93"),Color(definition.color,0.6),1,11))
			b.add_theme_stylebox_override("hover",panel(definition.color,INK,2,11))
			b.add_theme_stylebox_override("pressed",panel(Color("ab72e1"),INK,2,11))
			b.add_theme_stylebox_override("focus",panel(Color.TRANSPARENT,Color("d7ff31"),2,11))
			add_child(b)
			stage_buttons.append(b)
	if host.reduce_motion: entrance=1
	else:
		var tween:=create_tween()
		tween.tween_property(self,"entrance",1.0,0.52).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(entrance_delay)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		origin=(event.position/size).clamp(Vector2.ZERO,Vector2.ONE)

func confirm() -> void:
	confirmed=true
	held=false
	highlighted=true
	confirm_age=0
	if not host.reduce_motion: press_velocity=-5.0

func _process(dt: float) -> void:
	clock+=dt
	confirm_age+=dt
	var target:=1.0 if highlighted else 0.0
	if host.reduce_motion:
		hover=target
		hover_velocity=0
		press=0
		press_velocity=0
		flood=target
		entrance=1
	else:
		# Small integration steps preserve the same bounce at 30, 60 and 144 Hz.
		var remaining:=minf(dt,0.10)
		while remaining>0.00001:
			var step:=minf(remaining,1.0/120)
			hover_velocity+=((target-hover)*260-hover_velocity*22)*step
			hover+=hover_velocity*step
			press_velocity+=(((1.0 if held else 0.0)-press)*400-press_velocity*18)*step
			press+=press_velocity*step
			remaining-=step
		flood=move_toward(flood,target,dt/(0.43 if target>0 else 0.28))
	var hover_amount:=clampf(hover,0,1.12)
	scale=Vector2.ONE*(lerpf(0.90,1.0,entrance)*(1+hover_amount*0.023))
	rotation_degrees=0.0 if host.reduce_motion else rest_tilt*(1-clampf(hover,0,1))
	position=rest_position+Vector2(0,(1-entrance)*25-hover_amount*3)
	modulate.a=clampf(entrance*2,0,1)
	# Only the glossy frame and landscape compress. All text remains uniformly scaled.
	var squash:=clampf(press,-0.4,1.15)
	face.scale=Vector2(1+squash*0.022,1-squash*0.055)
	paint.set_shader_parameter("flood",flood)
	paint.set_shader_parameter("focus",clampf(hover,0,1))
	paint.set_shader_parameter("ink_origin",origin)
	paint.set_shader_parameter("clock",0.0 if host.reduce_motion else clock)
	queue_redraw()

func panel(fill: Color, border: Color=Color.TRANSPARENT, width: int=0, radius: int=10) -> StyleBoxFlat:
	var s:=StyleBoxFlat.new()
	s.bg_color=fill
	s.border_color=border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	return s

func copy(value: String, at: Vector2, fs: int, color: Color, bold: bool=false, guard: bool=false) -> void:
	var font: Font=title_font if bold else body_font
	# During the liquid wipe a label can straddle dark and light areas. A temporary
	# opposing keyline keeps it legible until the surface finishes filling.
	if guard and flood>0.01 and flood<0.99:
		draw_string_outline(font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,fs,1,INK if color.r>0.5 else PAPER)
	draw_string(font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,fs,color)

func readable_on(fill: Color) -> Color:
	var light: float=PAPER.srgb_to_linear().get_luminance()+0.05
	var dark: float=INK.srgb_to_linear().get_luminance()+0.05
	var base: float=fill.srgb_to_linear().get_luminance()+0.05
	return PAPER if light/base>=base/dark else INK

func reward_label() -> String:
	var rewards: Dictionary=preload("res://wardrobe/catalog.gd").REWARDS.get(definition.get("id",""),{})
	if rewards.is_empty(): return ""
	if not stage_buttons.is_empty() or host.get("journey")!=null:
		var values: Array[String]=[]
		for chapter in 3:
			var id: String=str(definition.id)+("" if chapter==0 else "-"+str(chapter+1))
			var reward: Dictionary=preload("res://wardrobe/catalog.gd").REWARDS[id]
			values.append(str(reward["repeat" if int(Wardrobe.clears.get(id,0))>0 else "first"]))
		return "三段关奖 · "+" / ".join(values)+" 金币"
	return ("重游奖励" if completed else "首通奖励")+" · %d 金币" % int(rewards["repeat" if completed else "first"])

func _draw() -> void:
	if definition.is_empty(): return
	var fg:=PAPER.lerp(INK,clampf(flood*2.2,0,1))
	var sub:=Color("b9aec8").lerp(Color("665a73"),clampf(flood*2.2,0,1))
	var accent: Color=definition.color
	var badge_at:=Vector2(43,113)
	draw_set_transform(badge_at,deg_to_rad(-6)*(1-clampf(hover,0,1)))
	draw_style_box(panel(INK),Rect2(-23,-21,49,36))
	draw_style_box(panel(accent,INK,2,9),Rect2(-25,-25,49,36))
	copy("%02d" % [index+1],Vector2(-16,1),25,INK,true)
	draw_set_transform(Vector2.ZERO)
	draw_string_outline(title_font,Vector2(84,128),definition.title,HORIZONTAL_ALIGNMENT_LEFT,-1,29,5,Color(INK,0.9))
	copy(definition.title,Vector2(84,128),29,PAPER,true)
	copy("压轴",Vector2(26,174),14,sub,false,true)
	copy(preload("res://campaign/levels.gd").MYTHIC_NAMES[index] if host.get("journey")!=null or not stage_buttons.is_empty() else definition.boss_name,Vector2(75,176),22,fg,true,true)
	copy(definition.subtitle,Vector2(26,202),17,sub,false,true)
	copy(reward_label(),Vector2(26,222),14,fg,true,true)
	if host.get("journey")!=null:
		if completed: copy("✓",Vector2(size.x-54,40),21,accent,true)
		for j in 3:
			var at:=Vector2(337+j*65,163)
			draw_style_box(panel(Color("472461") if j<2 else Color("803eb3"),Color(accent,0.7),1,8),Rect2(at,Vector2(50,32)))
			copy(["I","II","III"][j],at+Vector2(16,23),19,PAPER,true)
			if j<2: copy("›",at+Vector2(54,23),20,accent,true)
		copy("三段连战 →",Vector2(350,218),16,fg,true,true)
		return
	if not stage_buttons.is_empty():
		if completed: copy("✓",Vector2(size.x-54,40),21,accent,true)
		return
	var pill:=Rect2(size.x-161,158,133,53)
	var fill: Color=accent.lerp(INK,clampf(flood*2,0,1))
	draw_style_box(panel(Color("0b0812"),Color.TRANSPARENT,0,13),Rect2(pill.position+Vector2(0,4),pill.size))
	draw_style_box(panel(fill),pill)
	var text_color: Color=readable_on(fill)
	copy("已通关" if completed else "去挑战",pill.position+Vector2(16,32),18,text_color,true)
	var arrow:=pill.position+Vector2(109,27)
	draw_line(arrow-Vector2(12,0),arrow+Vector2(6,0),text_color,2.5,true)
	draw_polyline(PackedVector2Array([arrow+Vector2(0,-6),arrow+Vector2(6,0),arrow+Vector2(0,6)]),text_color,2.5,true)
	if completed:
		copy("✓",Vector2(size.x-54,40),21,accent,true)
