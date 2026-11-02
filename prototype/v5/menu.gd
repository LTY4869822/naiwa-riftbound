extends Control
## Scene-backed ink menu: rounded liquid actions, floating logo and frontal companion.
const STICKER = preload("res://v5/sticker_button.gd")
const PET = preload("res://v5/menu_pet.gd")
const INK := Color("17121f")
const PAPER := Color("fffef6")
const YELLOW := Color("d7ff31")
const MINT := Color("c5ff6b")
const PURPLE := Color("a449ee")
var host: Node
var canvas: Control
var pet: Control
var bold: SystemFont
var regular: Font
var clock := 0.0
var buttons: Array[Button] = []
var background_material: ShaderMaterial
var focus_box := Rect2()
var focus_initialized := false
var active_button: Button
var burst_clock := 10.0
var burst_point := Vector2.ZERO
var toast_active := false
var animate_logo := true

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	animate_logo=host.menu_entrance
	regular=host.font
	bold=SystemFont.new()
	bold.font_names=PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei"])
	bold.font_weight=900
	var background:=ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter=Control.MOUSE_FILTER_IGNORE
	background_material=ShaderMaterial.new()
	background_material.shader=preload("res://v5/menu_background.gdshader")
	background_material.set_shader_parameter("scene",load("res://assets/v4/forest.png"))
	background.material=background_material
	add_child(background)
	canvas=Control.new()
	canvas.mouse_filter=Control.MOUSE_FILTER_IGNORE
	canvas.size=Vector2(1280,800)
	add_child(canvas)
	canvas.draw.connect(paint)
	resized.connect(fit)
	fit()
	build()

func fit() -> void:
	if canvas==null: return
	var factor:=minf(size.x/1280.0,size.y/800.0)
	canvas.scale=Vector2.ONE*factor
	canvas.position=(size-Vector2(1280,800)*factor)/2

func _process(dt: float) -> void:
	clock+=dt
	burst_clock+=dt
	background_material.set_shader_parameter("clock",0.0 if host.reduce_motion else clock)
	var pointer:=get_local_mouse_position()/size-Vector2(0.5,0.5)
	background_material.set_shader_parameter("pointer",Vector2.ZERO if host.reduce_motion else pointer.clamp(Vector2(-0.5,-0.5),Vector2(0.5,0.5)))
	var target: Button=null
	for b in buttons:
		if not is_instance_valid(b) or b.disabled: continue
		if b.has_focus(): target=b
	for b in buttons:
		if is_instance_valid(b) and not b.disabled and b.is_hovered(): target=b
	if target!=null:
		var transform:=canvas.get_global_transform().affine_inverse()*target.get_global_transform()
		var lower:=transform*Vector2.ZERO
		var upper:=lower
		for corner in [Vector2(target.size.x,0),target.size,Vector2(0,target.size.y)]:
			var point: Vector2=transform*corner
			lower=lower.min(point)
			upper=upper.max(point)
		var goal:=Rect2(lower,upper-lower-Vector2(4,5))
		if not focus_initialized or host.reduce_motion:
			focus_box=goal
			focus_initialized=true
		else:
			focus_box.position=focus_box.position.lerp(goal.position,1-exp(-19*dt))
			focus_box.size=focus_box.size.lerp(goal.size,1-exp(-19*dt))
		active_button=target
	canvas.queue_redraw()

func style(fill: Color, border: Color = Color.TRANSPARENT, width: int = 0, radius: int = 18) -> StyleBoxFlat:
	var s:=StyleBoxFlat.new()
	s.bg_color=fill
	s.border_color=border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	return s

func label_at(value: String, at: Vector2, font_size: int, color: Color = PAPER, heavy: bool = false) -> void:
	var chosen_font: Font=bold if heavy else regular
	var target: int=Preferences.font_size(font_size)
	while target>font_size and chosen_font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,target).x>1255-at.x: target-=1
	canvas.draw_string(chosen_font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,target,color)

func outlined(value: String, at: Vector2, font_size: int, color: Color = PAPER) -> void:
	canvas.draw_string_outline(bold,at+Vector2(0,6),value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,13,Color("09070f"))
	canvas.draw_string_outline(bold,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,9,INK)
	canvas.draw_string(bold,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

func blob(at: Vector2, extent: Vector2, color: Color, phase: float = 0.0) -> void:
	var points:=PackedVector2Array()
	for i in 96:
		var a:=i*TAU/96
		var radius:=1.0+sin(a*5+phase)*0.14+sin(a*9+1.1)*0.075+sin(a*3-0.5)*0.10
		points.append(at+Vector2(cos(a),sin(a))*extent*radius)
	canvas.draw_colored_polygon(points,color)

func panel_at(r: Rect2) -> void:
	var shade:=style(Color(0.075,0.052,0.12,0.94),Color("514761"),1,19)
	shade.shadow_color=Color(0.02,0.01,0.035,0.6)
	shade.shadow_size=5
	shade.shadow_offset=Vector2(0,7)
	canvas.draw_style_box(shade,r)
	canvas.draw_line(r.position+Vector2(20,2),Vector2(r.end.x-20,r.position.y+2),Color(0.9,0.85,1,0.14),1)

func paint_logo() -> void:
	var progress:=1.0 if host.reduce_motion or not animate_logo else clampf(clock/0.8,0,1)
	var pop:=1.0-pow(1-progress,3)+sin(progress*PI)*0.12
	canvas.draw_set_transform(Vector2(247,94),lerpf(-0.2,0.0,progress),Vector2.ONE*pop)
	blob(Vector2(-20,-4),Vector2(154,52),PURPLE,0.6)
	blob(Vector2(-38,-26),Vector2(142,59),YELLOW,0.0)
	for i in 9:
		var a:=i*2.3
		var point:=Vector2(cos(a)*169,sin(a)*69-12)
		canvas.draw_circle(point,3.5+fmod(i*3.1,6),YELLOW if i%2==0 else PURPLE)
	for i in 2:
		var movement:=0.0 if host.reduce_motion else sin(clock*1.85+i*1.3)*2.0
		var letter_at:=Vector2(247,94)+Vector2(-121+i*82,-3+movement)*pop
		canvas.draw_set_transform(letter_at,deg_to_rad(-3.0 if i==0 else 2.0),Vector2.ONE*pop)
		outlined("奶" if i==0 else "蛙",Vector2(-39,0),77)
	canvas.draw_set_transform(Vector2(247,94),-0.035,Vector2.ONE*pop)
	var tag:=Rect2(-84,27,164,39)
	canvas.draw_style_box(style(INK,INK,3,9),Rect2(tag.position+Vector2(2,4),tag.size))
	canvas.draw_style_box(style(PURPLE,INK,3,9),tag)
	label_at("碎片巡游",Vector2(-69,56),27,PAPER,true)
	canvas.draw_set_transform(Vector2.ZERO)

func paint() -> void:
	var time:=0.0 if host.reduce_motion else clock
	# Ambient motion belongs to the world; UI text remains stable.
	for i in 24:
		var x:=580+fmod(i*113.0,664)+sin(time*0.32+i)*13
		var y:=185+fmod(i*77.0-time*7,520)
		canvas.draw_circle(Vector2(x,y),1.3+fmod(i*1.7,2),Color(0.83,1,0.35,0.10+0.13*sin(time+i)))
	paint_logo()
	paint_profile()
	if host.menu_section=="home": paint_home()
	else: paint_page()
	# A spring-following halo sits outside the body, as in the reference.
	if focus_initialized and active_button!=null and not active_button.disabled:
		var pulse:=0.0 if host.reduce_motion else (sin(clock*TAU/1.3)+1)*0.5
		canvas.draw_style_box(style(Color.TRANSPARENT,Color(YELLOW,0.10),8,25),focus_box.grow(10+pulse*2))
		canvas.draw_style_box(style(Color.TRANSPARENT,INK,5,22),focus_box.grow(7))
		canvas.draw_style_box(style(Color.TRANSPARENT,YELLOW,3,22),focus_box.grow(9+pulse))
	if burst_clock<0.65 and not host.reduce_motion:
		var t:=burst_clock/0.65
		for i in 13:
			var a:=i*TAU/13+0.23
			var p:=burst_point+Vector2(cos(a),sin(a))*(18+t*(50+fmod(i*31,65)))+Vector2(0,t*t*53)
			canvas.draw_circle(p,(3+fmod(i*1.7,5))*(1-t),Color(YELLOW if i%2==0 else PURPLE,1-t))
	canvas.draw_rect(Rect2(0,746,1280,54),Color(0.035,0.023,0.06,0.65))
	label_at("●  苔光遗境",Vector2(47,778),16,YELLOW,true)
	label_at("叶甲兽 · 灯蛾 · 古树守卫",Vector2(187,777),13,Color("bfb3ca"))
	if host.toast_time<=0:
		keycap("↑↓",Vector2(819,758),51)
		label_at("选择",Vector2(878,780),14)
		keycap("Enter",Vector2(935,758),59)
		label_at("确认",Vector2(1002,780),14)
		keycap("Esc",Vector2(1058,758),49)
		label_at("返回",Vector2(1116,780),14)
		keycap("P",Vector2(1166,758),30)
		label_at("桌宠",Vector2(1204,780),14)

func keycap(key: String, at: Vector2, width: float) -> void:
	canvas.draw_style_box(style(PAPER,Color("17121f"),2,7),Rect2(at,Vector2(width,30)))
	label_at(key,at+Vector2(8,22),15,INK,true)

func paint_profile() -> void:
	panel_at(Rect2(879,30,357,146))
	canvas.draw_circle(Vector2(917,67),17,YELLOW)
	canvas.draw_circle(Vector2(910,60),7,YELLOW)
	canvas.draw_circle(Vector2(924,60),7,YELLOW)
	canvas.draw_circle(Vector2(911,60),3,INK)
	canvas.draw_circle(Vector2(923,60),3,INK)
	label_at("奶蛙",Vector2(947,76),27,PAPER,true)
	label_at("档案旅者  /  伙伴在线",Vector2(947,101),13,Color("c6aff0"))
	canvas.draw_style_box(style(Color("3c344b"),Color.TRANSPARENT,0,5),Rect2(974,118,162,9))
	if Profile.xp>0: canvas.draw_style_box(style(YELLOW,Color.TRANSPARENT,0,5),Rect2(974,118,162*float(Profile.xp)/Profile.needed(),9))
	label_at("Lv.%02d" % Profile.level,Vector2(899,131),20,YELLOW,true)
	label_at("%d / %d XP" % [Profile.xp,Profile.needed()],Vector2(1146,127),11)
	label_at("胜利  %d       喂食  %d" % [Profile.wins,Profile.fed],Vector2(944,155),13,Color("c4bcd0"))

func paint_home() -> void:
	label_at("一点碎片，一起冒险。",Vector2(58,193),16,Color("d2c5dc"))
	blob(Vector2(888,658),Vector2(202,44),Color("130e25"),time_phase())
	blob(Vector2(911,664),Vector2(177,32),Color(0.37,0.10,0.65,0.78),1.7)
	canvas.draw_set_transform(Vector2(898,659),0,Vector2(1,0.28))
	canvas.draw_arc(Vector2.ZERO,184,0.1+clock*0.13,PI*1.58+clock*0.13,96,Color(YELLOW,0.45),2,true)
	canvas.draw_set_transform(Vector2.ZERO)
	panel_at(Rect2(1057,267,177,202))
	label_at("当前招式",Vector2(1076,300),13,Color("bda9d1"),true)
	label_at(host.SKILL_NAME,Vector2(1076,337),23,PAPER,true)
	label_at("U  /  消耗 60 专注" if Profile.level>=2 else "Lv.2 解锁",Vector2(1076,367),14,YELLOW,true)
	label_at("攻击  %d" % Profile.damage(),Vector2(1076,409),16)
	label_at("生命  %d" % Profile.max_health(),Vector2(1076,440),16)
	label_at("点击奶蛙，逗它笑。",Vector2(730,704),15,PAPER)

func time_phase() -> float:
	return 0.0 if host.reduce_motion else clock*0.12

func paint_page() -> void:
	var copy := {"feed":["吞噬成长","把不要的文件，喂成下一次冒险。"],"growth":["成长档案","吃得越多，就越厉害。"],"settings":["旅途设置","按你喜欢的节奏，陪奶蛙出发。"]}
	var text: Array=copy[host.menu_section]
	outlined(str(text[0]),Vector2(59,263),46)
	label_at(str(text[1]),Vector2(62,300),16,Color("dfd2e7"))
	blob(Vector2(290,644),Vector2(158,32),Color(0.25,0.06,0.43,0.9),time_phase())
	label_at("奶蛙  Lv.%02d" % Profile.level,Vector2(182,695),24,YELLOW,true)
	panel_at(Rect2(580,203,654,520))
	if host.menu_section=="feed":
		paint_file_growth()
	elif host.menu_section=="growth":
		label_at("一点一点，变厉害。",Vector2(610,252),29,PAPER,true)
		for i in 3:
			var names: Array=["巡游胜利","累计吞噬","距离下一级"]
			var values: Array=[str(Profile.wins)+" 次",String.humanize_size(Profile.recycle_bytes_total),String.humanize_size(bytes_to_next_level())]
			label_at(names[i],Vector2(612,312+i*53),17,Color("c5b4d5"))
			label_at(values[i],Vector2(1040,312+i*53),23,YELLOW,true)
			canvas.draw_line(Vector2(611,328+i*53),Vector2(1198,328+i*53),Color("44344e"),1)
		label_at("U  碎片冲击",Vector2(612,503),24,YELLOW,true)
		label_at("直接拖入桌宠 · 文件移入回收站，可还原",Vector2(612,467),14,Color("c5b4d5"))
		label_at("已解锁 · 消耗 60 专注" if Profile.level>=2 else "Lv.2 解锁 · 吞噬文件或巡游即可成长",Vector2(613,538),16)
		label_at("J 连击   K 重击   L / Shift 闪避",Vector2(613,580),16,Color("d2c4dc"))
		label_at("A D 移动   空格 跳跃   Tab 营地",Vector2(613,610),15,Color("bcaacb"))
	else:
		label_at("按你喜欢的节奏。",Vector2(610,253),29,PAPER,true)
		label_at("设置会保存在本机，下次出发继续生效。",Vector2(612,284),14,Color("c5b4d5"))
		label_at("桌宠的互动与音量可在原版托盘中调整。",Vector2(612,608),14,Color("bcaacb"))

func sticker(key: String, at: Vector2, dimensions: Vector2, title: String, subtitle: String, action: Callable, tint: Color = INK, serial: String = "", tilt: float = 0, icon: String = "") -> Button:
	var b:=STICKER.new()
	b.name=key
	b.title=title
	b.subtitle=subtitle
	b.tint=tint
	b.serial=serial
	b.glyph=icon
	b.primary=key in ["StartJourney","FeedSelected"]
	b.rest_tilt=tilt
	b.host=host
	b.title_font=bold
	b.body_font=regular
	b.position=at
	b.size=dimensions
	b.large=dimensions.y>100
	canvas.add_child(b)
	b.pressed.connect(func():
		host.play_sound("hit",-29,1.35)
		action.call())
	buttons.append(b)
	return b

func navigate(section: String) -> void:
	host.menu_navigate(section)

func make_pet(at: Vector2, dimensions: Vector2) -> void:
	pet=PET.new()
	pet.name="MenuCompanion"
	pet.host=host
	pet.position=at
	pet.size=dimensions
	canvas.add_child(pet)

func build() -> void:
	if host.menu_section=="home":
		make_pet(Vector2(686,180),Vector2(391,514))
		var continuing: bool=is_instance_valid(host.player) and not host.over
		sticker("StartJourney",Vector2(56,215),Vector2(490,112),"继续巡游" if continuing else "前往下一关" if host.over and host.won else "出发巡游",host.current_level().title+" · 横版冒险",func(): host.menu_action(host.enter_battle),YELLOW,"",-1.7,"play")
		sticker("OpenFeed",Vector2(62,347),Vector2(461,85),"吞噬成长","把不要的文件拖给奶蛙",func(): navigate("feed"),PURPLE,"",1.3,"feed")
		sticker("OpenGrowth",Vector2(61,451),Vector2(222,77),"成长档案","",func(): navigate("growth"),INK,"",-1.2,"growth")
		sticker("OpenShop",Vector2(300,451),Vector2(222,77),"皮肤商城","",func(): navigate("shop"),PURPLE,"",1.1,"shop")
		sticker("OpenSettings",Vector2(58,549),Vector2(461,77),"旅途设置","",func(): navigate("settings"),INK,"",1.1,"settings")
		sticker("ReturnPet",Vector2(62,647),Vector2(461,70),"返回桌宠","",func(): host.menu_action(host.return_pet),INK,"",-0.8,"pet")
		sticker("OpenRecycleHome",Vector2(1058,497),Vector2(177,49),"拖文件喂它","",host.open_recycle_feed,INK)
		sticker("OpenLevelRoute",Vector2(1058,559),Vector2(177,49),"关卡地图","",host.open_route,INK,"",0,"play")
		sticker("LaughCompanion",Vector2(940,684),Vector2(287,49),"逗它笑 · 捧腹大笑","",func():
			burst_point=Vector2(900,450)
			burst_clock=0
			pet.play_laugh(),PURPLE)
	else:
		make_pet(Vector2(138,325),Vector2(310,342))
		sticker("BackHome",Vector2(60,330),Vector2(148,50),"← 返回","",func(): navigate("home"),INK)
		sticker("ReturnPet",Vector2(1057,143),Vector2(177,45),"返回桌宠","",func(): host.menu_action(host.return_pet),INK)
		match host.menu_section:
			"feed": build_feed()
			"growth": sticker("GrowthFeed",Vector2(610,642),Vector2(597,64),"去喂奶蛙，让它成长","",func(): navigate("feed"),PURPLE,"",0,"feed")
			"settings": build_settings()
	# Explicit neighbors also include scroll items, avoiding geometry-based focus jumps.
	var ordered: Array[Button]=[]
	for b in buttons:
		if b.name not in ["ReturnPet","LaughCompanion"] and not b.disabled: ordered.append(b)
	for b in buttons:
		if b.name in ["ReturnPet","LaughCompanion"]: ordered.append(b)
	for i in range(ordered.size()):
		ordered[i].focus_neighbor_bottom=ordered[i].get_path_to(ordered[(i+1)%ordered.size()])
		ordered[i].focus_neighbor_top=ordered[i].get_path_to(ordered[(i-1+ordered.size())%ordered.size()])
	var focus: Control=ordered[0]
	if host.menu_section!="home" and ordered.size()>2: focus=ordered[1]
	for b in buttons:
		if str(b.name)==host.ui_focus: focus=b
	host.call_deferred("focus_control",focus)
	var message:=Label.new()
	message.position=Vector2(640,749)
	message.size=Vector2(584,48)
	message.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	message.add_theme_color_override("font_color",YELLOW)
	message.add_theme_font_size_override("font_size",14)
	message.mouse_filter=Control.MOUSE_FILTER_IGNORE
	canvas.add_child(message)
	host.hud_toast=message
	if host.menu_entrance and not host.reduce_motion:
		for i in range(buttons.size()):
			var b:=buttons[i]
			var destination:=b.position
			b.position.x-=70
			b.modulate.a=0
			var tween:=create_tween().set_parallel(true)
			tween.tween_property(b,"position",destination,0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.04+i*0.038)
			tween.tween_property(b,"modulate:a",1.0,0.24).set_delay(0.04+i*0.038)
	host.menu_entrance=false

func bytes_to_next_level() -> int:
	if Profile.level>=Profile.MAX_LEVEL: return 0
	return maxi(0,(Profile.needed()-Profile.xp)*Profile.RECYCLE_BYTES_PER_XP-Profile.recycle_remainder_bytes)

func paint_file_growth() -> void:
	label_at("一拖，就开饭。",Vector2(612,260),35,PAPER,true)
	label_at("无需分类，奶蛙按吞下的文件总大小成长。",Vector2(614,296),17,Color("c3afd2"))
	canvas.draw_style_box(style(Color("2c1d3b"),Color("6b487e"),1,18),Rect2(611,332,596,195))
	label_at("累计吞噬",Vector2(635,370),16,Color("c3afd2"))
	label_at(String.humanize_size(Profile.recycle_bytes_total),Vector2(635,420),39,YELLOW,true)
	label_at("Lv.%02d" % Profile.level,Vector2(1050,412),30,PAPER,true)
	var fraction:=1.0 if Profile.level>=Profile.MAX_LEVEL else clampf((Profile.xp*Profile.RECYCLE_BYTES_PER_XP+Profile.recycle_remainder_bytes)/float(Profile.needed()*Profile.RECYCLE_BYTES_PER_XP),0,1)
	canvas.draw_style_box(style(Color("493154"),Color.TRANSPARENT,0,7),Rect2(637,449,544,13))
	if fraction>0: canvas.draw_style_box(style(YELLOW,Color.TRANSPARENT,0,7),Rect2(637,449,maxf(13,544*fraction),13))
	label_at("已经满级啦！" if Profile.level>=Profile.MAX_LEVEL else "距离 Lv.%d 还差 %s" % [Profile.level+1,String.humanize_size(bytes_to_next_level())],Vector2(636,498),19,PAPER,true)
	label_at("01  返回桌宠，把不要的文件拖到奶蛙身上。",Vector2(617,563),17)
	label_at("02  张嘴吞下，大小自动累积，达标就升级。",Vector2(617,596),17)
	label_at("文件会移入 Windows 回收站，需要时可还原。",Vector2(617,710),13,Color("ada1b9"))

func build_feed() -> void:
	host.feed_button=null
	sticker("OpenRecycleFeed",Vector2(611,628),Vector2(595,59),"返回桌宠，拖文件喂它","",host.open_recycle_feed,YELLOW,"",0,"feed")

func build_settings() -> void:
	sticker("OpenControls",Vector2(611,581),Vector2(600,59),"操作与按键","",func(): navigate("controls"),PURPLE)
	sticker("LargeTextToggle",Vector2(611,649),Vector2(600,58),"大字显示："+("开启" if Preferences.large_text else "关闭"),"",Preferences.toggle_text,INK)
	sticker("SoundToggle",Vector2(611,328),Vector2(600,96),"游戏音效："+("开启" if host.audio_enabled else "关闭"),"战斗、喂食、菜单与奶蛙笑声",func():
		host.audio_enabled=not host.audio_enabled
		if not host.audio_enabled:
			for channel in host.channels: channel.stop()
		host.save_menu_settings()
		host.ui_focus="SoundToggle"
		host.build_ui(),PURPLE,"",0,"settings")
	sticker("MotionToggle",Vector2(611,461),Vector2(600,96),"减少动态："+("开启" if host.reduce_motion else "关闭"),"关闭漂浮、墨迹转场与战斗震动",func():
		host.reduce_motion=not host.reduce_motion
		host.save_menu_settings()
		host.ui_focus="MotionToggle"
		host.build_ui(),INK,"",0,"settings")
