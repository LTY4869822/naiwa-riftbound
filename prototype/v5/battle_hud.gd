extends Control
## Event-fed battle instruments. Animation reads the cached model, never the actors.
const GLYPHS = preload("res://v5/hud_glyphs.gd")
const PAPER := Color("f5f1df")
const GOLD := Color("d7b978")
const GOLD_LIGHT := Color("fff0b2")
const MINT := Color("8de4bf")
const EMERALD := Color("44b9a1")
const MUTED := Color("a5bcb6")
const DARK := Color("101e26")
const ROSE := Color("df9a8b")
var host: Node
var snapshot: Dictionary = {}
var parts: Dictionary = {}
var hp_display := 1.0
var hp_trail := 1.0
var stamina_display := 1.0
var focus_display := 0.0
var boss_display := 1.0
var boss_trail := 1.0
var low_health := false
var skill_ready := false
var skill_locked := true
var dash_ready := true
var heavy_ready := true
var clock := 0.0
var hp_flash := 0.0
var ready_flash := 0.0
var hp_delay := 0.0
var boss_delay := 0.0
var toast_text := ""
var font: Font
var bold: SystemFont
var portrait: TextureRect
var toast_label: Label
var tooltip_regions: Array[Control] = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	font=host.font
	bold=SystemFont.new()
	bold.font_names=PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei"])
	bold.font_weight=700
	part("vitals",Control.PRESET_TOP_LEFT,Rect2(27,23,400,139),paint_vitals)
	part("power",Control.PRESET_TOP_LEFT,Rect2(29,171,286,58),paint_power)
	part("location",Control.PRESET_CENTER_TOP,Rect2(-150,24,300,73),paint_location)
	part("boss",Control.PRESET_CENTER_TOP,Rect2(-258,115,516,102),paint_boss)
	part("dock",Control.PRESET_CENTER_BOTTOM,Rect2(-267,-127,534,117),paint_dock)
	part("help",Control.PRESET_BOTTOM_LEFT,Rect2(29,-91,274,73),paint_help)
	part("loot",Control.PRESET_BOTTOM_RIGHT,Rect2(-202,-82,174,64),paint_loot)
	parts.boss.visible=false
	build_portrait()
	build_actions()
	build_toast()
	for i in 4:
		var region:=Control.new()
		region.position=Vector2([10,117,224,375][i],0)
		region.size=Vector2(89 if i<3 else 146,117)
		region.mouse_filter=Control.MOUSE_FILTER_PASS
		parts.dock.add_child(region)
		tooltip_regions.append(region)

func part(key: String, preset: int, rect: Rect2, painter: Callable) -> void:
	var c:=Control.new()
	c.name=key.capitalize()
	c.set_anchors_and_offsets_preset(preset)
	c.offset_left=rect.position.x
	c.offset_top=rect.position.y
	c.offset_right=rect.end.x
	c.offset_bottom=rect.end.y
	c.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(c)
	c.draw.connect(func(): painter.call(c))
	parts[key]=c

func box(fill: Color, border: Color = Color.TRANSPARENT, width: int = 0, radius: int = 9) -> StyleBoxFlat:
	var s:=StyleBoxFlat.new()
	s.bg_color=fill
	s.border_color=border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	return s

func text(c: CanvasItem, value: String, at: Vector2, fs: int = 16, color: Color = PAPER, heavy: bool = false, width: float = -1, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	fs=Preferences.font_size(fs)
	var selected: Font=bold if heavy else font
	if width>0:
		while fs>10 and selected.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x>width: fs-=1
	c.draw_string_outline(selected,at+Vector2(0,1),value,align,width,fs,3,Color(0.025,0.055,0.07,0.85))
	c.draw_string(selected,at,value,align,width,fs,color)

func diamond(c: CanvasItem, at: Vector2, radius: float, fill: Color, border: Color = Color.TRANSPARENT, thickness: float = 1.0) -> void:
	var points:=PackedVector2Array([at+Vector2(0,-radius),at+Vector2(radius,0),at+Vector2(0,radius),at+Vector2(-radius,0)])
	if fill.a>0: c.draw_colored_polygon(points,fill)
	if border.a>0:
		points.append(points[0])
		c.draw_polyline(points,border,thickness,true)

func line(c: CanvasItem, a: Vector2, b: Vector2, color: Color = GOLD, thickness: float = 1) -> void:
	c.draw_line(a,b,color,thickness,true)

func build_portrait() -> void:
	portrait=TextureRect.new()
	portrait.name="CompanionPortrait"
	portrait.position=Vector2(7,7)
	portrait.size=Vector2(74,74)
	portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	portrait.texture=load("res://assets/menu-v2/pet/front-idle.png")
	portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var shader:=Shader.new()
	shader.code="""
shader_type canvas_item;
render_mode unshaded;
void fragment() {
    vec2 uv=vec2(0.215,0.035)+UV*vec2(0.57,0.38);
    vec4 face=texture(TEXTURE,uv);
    float mask=1.0-smoothstep(0.474,0.495,length(UV-vec2(0.5)));
    COLOR=vec4(face.rgb,face.a*mask);
}
"""
	var material_face:=ShaderMaterial.new()
	material_face.shader=shader
	portrait.material=material_face
	parts.vitals.add_child(portrait)

func build_actions() -> void:
	var root:=HBoxContainer.new()
	root.name="BattleActions"
	root.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	root.offset_left=-480
	root.offset_right=-27
	root.offset_top=29
	root.offset_bottom=65
	root.add_theme_constant_override("separation",11)
	add_child(root)
	for entry in [["◇  地图","三段连战",host.open_route],["Ⅱ  暂停","Esc",host.toggle_pause],["⚒  装备","金币锻造",host.open_gear],["↗  桌宠","P",host.return_pet]]:
		var b:=Button.new()
		b.text=entry[0]
		b.tooltip_text=entry[1]+"  "+str(entry[0])
		b.custom_minimum_size=Vector2(104,36)
		b.focus_mode=Control.FOCUS_NONE
		b.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
		b.add_theme_font_size_override("font_size",15)
		b.add_theme_color_override("font_color",PAPER)
		b.add_theme_color_override("font_hover_color",GOLD_LIGHT)
		b.add_theme_color_override("font_pressed_color",GOLD_LIGHT)
		b.add_theme_stylebox_override("normal",box(Color(0.045,0.09,0.12,0.78),Color(0.55,0.66,0.62,0.26),1,6))
		b.add_theme_stylebox_override("hover",box(Color(0.07,0.16,0.18,0.94),GOLD,1,6))
		b.add_theme_stylebox_override("pressed",box(Color("244649"),GOLD_LIGHT,1,6))
		b.pressed.connect(entry[2])
		root.add_child(b)

func build_toast() -> void:
	var root:=PanelContainer.new()
	root.name="JourneyNotice"
	root.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	root.offset_left=-340
	root.offset_right=340
	root.offset_top=218
	root.offset_bottom=256
	var surface:=box(Color(0.03,0.085,0.11,0.88),Color(0.72,0.65,0.40,0.32),1,6)
	surface.content_margin_left=17
	surface.content_margin_right=17
	surface.content_margin_top=6
	surface.content_margin_bottom=6
	root.add_theme_stylebox_override("panel",surface)
	root.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(root)
	toast_label=Label.new()
	toast_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	toast_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	toast_label.add_theme_font_size_override("font_size",15)
	toast_label.add_theme_color_override("font_color",GOLD_LIGHT)
	toast_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	root.add_child(toast_label)
	root.visible=false

func set_toast(value: String) -> void:
	if value==toast_text: return
	toast_text=value
	if is_instance_valid(toast_label):
		toast_label.text=value
		toast_label.get_parent().visible=not value.is_empty()

func set_state(data: Dictionary) -> void:
	if data==snapshot: return
	var first:=snapshot.is_empty()
	var hp_ratio:=clampf(float(data.hp)/maxf(1,data.max_hp),0,1)
	var boss_ratio:=clampf(float(data.boss_hp)/maxf(1,data.boss_max),0,1)
	var was_ready:=skill_ready
	if first:
		hp_display=hp_ratio
		hp_trail=hp_ratio
		stamina_display=float(data.stamina)/100
		focus_display=float(data.focus)/100
	elif data.hp<snapshot.hp:
		hp_delay=0.42
		hp_flash=1.0
		hp_trail=maxf(hp_trail,hp_display)
	elif data.hp>snapshot.hp:
		hp_trail=maxf(hp_trail,hp_ratio)
	if first or data.boss_id!=snapshot.boss_id:
		boss_display=boss_ratio
		boss_trail=boss_ratio
	elif data.boss_hp<snapshot.boss_hp:
		boss_delay=0.34
		boss_trail=maxf(boss_trail,boss_display)
	snapshot=data.duplicate()
	low_health=hp_ratio<=0.3 and not data.dead
	var empowered: bool=str(data.get("power_phase","dormant"))=="empowered"
	var cinematic: bool=str(data.get("power_phase","dormant")) in ["ignite","finisher","dissolve"]
	skill_locked=int(data.level)<2 and str(data.get("power_phase","dormant"))=="dormant"
	skill_ready=not skill_locked and (empowered or float(data.focus)>=60) and data.state not in ["hurt","skill","dash"] and not data.dead and not cinematic
	var combo_index:=clampi(int(data.combo),0,2)
	var heavy_windows: Array[float]=[0.26,0.32,0.44]
	var dash_windows: Array[float]=[0.18,0.23,0.29]
	var can_dash_window: bool=not (data.state=="skill" and float(data.elapsed)<float(data.get("skill_dash_cancel",0.3))) and not (data.state=="attack" and float(data.elapsed)<dash_windows[combo_index])
	dash_ready=float(data.stamina)>=float(data.get("dash_cost",32)) and float(data.dash_cd)<=0 and data.state!="hurt" and can_dash_window and not data.dead
	heavy_ready=float(data.stamina)>=28 and data.state not in ["hurt","dash","skill"] and (data.state!="attack" or float(data.elapsed)>heavy_windows[combo_index]) and not data.dead
	if cinematic:
		dash_ready=false
		heavy_ready=false
	if skill_ready and not was_ready and not first: ready_flash=1.0
	if parts.has("boss"): parts.boss.visible=bool(data.boss_alive)
	if tooltip_regions.size()==4:
		tooltip_regions[0].tooltip_text=Preferences.key_name("attack")+" 节奏连击 · 按节奏接三段攻击"
		tooltip_regions[1].tooltip_text=Preferences.key_name("heavy")+" 重击破势 · 消耗28体力，没有独立冷却"
		tooltip_regions[2].tooltip_text=Preferences.key_name("dash")+" / Shift 闪避 · 消耗%d体力，冷却%.2f秒" % [int(data.get("dash_cost",32)),float(data.get("dash_limit",.55))]
		var skill_name: String=str(data.get("skill_label","碎片冲击"))
		tooltip_regions[3].tooltip_text="Lv.2 解锁"+skill_name if skill_locked else Preferences.key_name("skill")+" "+skill_name+" · 消耗60专注，向面前贯穿攻击，命中积累专注"
		if empowered: tooltip_regions[3].tooltip_text=Preferences.key_name("skill")+" 紫霆·灭界 · 三段终极巨爪，释放后结束觉醒"
	for c in parts.values(): c.queue_redraw()

func _process(dt: float) -> void:
	if snapshot.is_empty(): return
	clock+=dt
	hp_flash=maxf(0,hp_flash-dt*3.1)
	ready_flash=maxf(0,ready_flash-dt*1.3)
	hp_delay=maxf(0,hp_delay-dt)
	boss_delay=maxf(0,boss_delay-dt)
	var hp_target:=float(snapshot.hp)/maxf(1,snapshot.max_hp)
	var boss_target:=float(snapshot.boss_hp)/maxf(1,snapshot.boss_max)
	if host.reduce_motion:
		hp_display=hp_target
		hp_trail=hp_target
		boss_display=boss_target
		boss_trail=boss_target
	else:
		hp_display=lerpf(hp_display,hp_target,1-exp(-22*dt))
		boss_display=lerpf(boss_display,boss_target,1-exp(-20*dt))
		if hp_delay<=0: hp_trail=move_toward(hp_trail,hp_target,dt*0.53)
		if boss_delay<=0: boss_trail=move_toward(boss_trail,boss_target,dt*0.45)
	stamina_display=lerpf(stamina_display,float(snapshot.stamina)/100,1-exp(-20*dt))
	focus_display=lerpf(focus_display,float(snapshot.focus)/100,1-exp(-15*dt))
	for c in parts.values():
		if c.visible: c.queue_redraw()

func meter(c: CanvasItem, r: Rect2, amount: float, tint: Color, trailing: float = 0.0, frame: Color = GOLD) -> void:
	c.draw_style_box(box(Color(0.025,0.06,0.075,0.94),Color(frame,0.7),1,3),r.grow(3))
	var inner:=r.grow(-1)
	if trailing>amount:
		c.draw_style_box(box(Color("756d60"),Color.TRANSPARENT,0,2),Rect2(inner.position,Vector2(inner.size.x*clampf(trailing,0,1),inner.size.y)))
	var extent:=inner.size.x*clampf(amount,0,1)
	if extent>0.3:
		c.draw_style_box(box(tint.darkened(0.20),Color.TRANSPARENT,0,2),Rect2(inner.position,Vector2(extent,inner.size.y)))
		c.draw_rect(Rect2(inner.position+Vector2(0,1),Vector2(extent,maxf(1,inner.size.y*0.46))),tint)
		line(c,inner.position+Vector2(1,1),inner.position+Vector2(maxf(1,extent-1),1),Color(1,1,0.92,0.48))
		if extent>4:
			line(c,inner.position+Vector2(extent-1,1),inner.position+Vector2(extent-1,inner.size.y-1),Color(0.85,1,0.88,0.65))
			if trailing>amount+0.01:
				line(c,inner.position+Vector2(extent,-1),inner.position+Vector2(extent,inner.size.y+1),GOLD_LIGHT,1.2)
	for i in range(1,5):
		var x:=r.position.x+r.size.x*i/5.0
		line(c,Vector2(x,r.position.y),Vector2(x,r.end.y),Color(0.025,0.09,0.1,0.24),1)

func paint_vitals(c: Control) -> void:
	if snapshot.is_empty(): return
	var plate:=PackedVector2Array([Vector2(45,13),Vector2(370,13),Vector2(393,32),Vector2(382,101),Vector2(99,101),Vector2(45,75)])
	c.draw_colored_polygon(plate,Color(0.035,0.085,0.11,0.82))
	line(c,Vector2(90,17),Vector2(368,17),Color(GOLD,0.55))
	line(c,Vector2(100,102),Vector2(367,102),Color(GOLD,0.25))
	var center:=Vector2(44,44)
	for i in range(5,0,-1): c.draw_circle(center,39+i*2,Color(0.5,0.76,0.58,0.018))
	c.draw_circle(center,41,Color("13292c"))
	c.draw_arc(center,42,0,TAU,80,GOLD,1.8,true)
	c.draw_arc(center,38,0,TAU,80,Color("546f66"),1,true)
	for i in 4: diamond(c,center+Vector2(cos(i*PI/2),sin(i*PI/2))*44,3.0,GOLD)
	if hp_flash>0 and not host.reduce_motion:
		c.draw_arc(center,44,0,TAU,72,Color(1,0.44,0.30,hp_flash*0.8),3,true)
	text(c,"奶蛙",Vector2(101,35),22,PAPER,true)
	text(c,"Lv.%02d" % snapshot.level,Vector2(232,33),14,GOLD_LIGHT,true)
	text(c,"%d / %d" % [snapshot.hp,snapshot.max_hp],Vector2(286,34),16,PAPER,true,92,HORIZONTAL_ALIGNMENT_RIGHT)
	var health_tint:=Color("e9a494") if low_health else MINT
	meter(c,Rect2(101,48,277,13),hp_display,health_tint,hp_trail)
	diamond(c,Vector2(94,54),3,GOLD)
	diamond(c,Vector2(386,54),4,Color("183531"),GOLD,1)
	GLYPHS.draw_icon(c,"stamina",Vector2(105,81),7,GOLD)
	meter(c,Rect2(120,77,258,5),stamina_display,GOLD_LIGHT,0,Color("758876"))
	text(c,"体力",Vector2(121,101),12,MUTED)
	text(c,"%d" % roundi(snapshot.stamina),Vector2(337,101),12,MUTED,false,41,HORIZONTAL_ALIGNMENT_RIGHT)
	var tag: String="生命危急" if low_health else "短暂保护" if float(snapshot.invuln)>0 else "体力不足" if float(snapshot.stamina)<28 else ""
	if not tag.is_empty():
		var col:=ROSE if low_health else GOLD_LIGHT
		c.draw_style_box(box(Color(0.04,0.085,0.105,0.84),Color(col,0.38),1,4),Rect2(102,113,109,23))
		GLYPHS.draw_icon(c,"health" if low_health else "shield" if float(snapshot.invuln)>0 else "stamina",Vector2(113,124),7,col)
		text(c,tag,Vector2(128,129),12,col)
	if low_health and not host.reduce_motion:
		var alpha: float=0.13+0.08*sin(clock*2.8)
		c.draw_arc(center,47,0,TAU,72,Color(0.95,0.48,0.35,alpha),2,true)

func paint_power(c: Control) -> void:
	if snapshot.is_empty(): return
	var phase: String=str(snapshot.get("power_phase","dormant"))
	var active: bool=phase!="dormant"
	var energy: float=float(snapshot.get("energy",0))
	var remaining: float=float(snapshot.get("power_remaining",0))
	var purple:=Color("d4a0ff")
	c.draw_style_box(box(Color(0.065,0.035,0.11,0.88),Color(purple,0.45),1,7),Rect2(0,0,280,55))
	diamond(c,Vector2(22,27),14,Color("33154f"),purple,1.4)
	text(c,"魔",Vector2(13,33),16,purple,true)
	text(c,"魔神觉醒" if not active else "魔神 · 玄甲紫霆",Vector2(44,20),14,purple,true)
	text(c,"终结释放" if phase=="finisher" else "退形中" if phase=="dissolve" else ("%.1fs" % remaining) if active else "%d / 100" % energy,Vector2(187,20),13,PAPER,true,79,HORIZONTAL_ALIGNMENT_RIGHT)
	meter(c,Rect2(45,29,215,6),remaining/14 if active else energy/100,purple,0,Color("8058a4"))
	var hint: String=Preferences.key_name("awaken")+" 觉醒就绪" if energy>=100 else "击杀蓄能 · 满值后 "+Preferences.key_name("awaken")+" 觉醒"
	if active: hint=Preferences.key_name("skill")+" 释放紫霆·灭界" if phase=="empowered" else "玄甲凝聚" if phase=="ignite" else "紫霆灭界" if phase=="finisher" else "魔能散尽"
	text(c,hint,Vector2(45,50),11,PAPER if active or energy>=100 else MUTED)

func paint_location(c: Control) -> void:
	if snapshot.is_empty(): return
	text(c,"%02d  %s" % [int(snapshot.get("level_number",1)),snapshot.get("level_title","苔光遗境")],Vector2(0,27),23,PAPER,true,c.size.x,HORIZONTAL_ALIGNMENT_CENTER)
	line(c,Vector2(21,36),Vector2(120,36),Color(GOLD,0.45))
	line(c,Vector2(180,36),Vector2(279,36),Color(GOLD,0.45))
	for i in 2: diamond(c,Vector2(139+i*22,36),2.4,GOLD)
	var section: int=maxi(1,int(snapshot.wave))
	c.draw_style_box(box(Color(0.035,0.085,0.11,0.62),Color(0.68,0.66,0.48,0.18),1,5),Rect2(43,41,214,25))
	var total: int=int(snapshot.get("wave_total",4))
	text(c,"%d / %d 战  ·  %s" % [section,total,snapshot.get("beat_title","苔径巡游")],Vector2(0,58),13,MUTED,false,c.size.x,HORIZONTAL_ALIGNMENT_CENTER)
	for i in total: diamond(c,Vector2(150+(i-(total-1)/2.0)*26,75),3,Color(GOLD,0.75) if section>i else Color(0.45,0.55,0.52,0.5))

func paint_boss(c: Control) -> void:
	if snapshot.is_empty() or not snapshot.boss_alive: return
	GLYPHS.draw_icon(c,"crown",Vector2(c.size.x*0.5,4),10,GOLD)
	text(c,str(snapshot.get("boss_name","古树守卫"))+"  ·  "+["I","II","III"][clampi(int(snapshot.get("boss_phase",1))-1,0,2)],Vector2(0,31),21,PAPER,true,c.size.x,HORIZONTAL_ALIGNMENT_CENTER)
	var r:=Rect2(15,42,c.size.x-30,12)
	meter(c,r,boss_display,ROSE,boss_trail,Color("ba9582"))
	for x in [3.0,c.size.x-3]: diamond(c,Vector2(x,47),6,Color("302b2e"),GOLD,1.5)
	var status: String="破势 · 进攻时机" if snapshot.boss_state=="stunned" else "蓄力 · 重击可破势" if snapshot.boss_state=="tell" else "攻击中 · 留意闪避" if snapshot.boss_state=="active" else "观察前摇，寻找空隙"
	if snapshot.boss_state=="ult_tell": status=str(snapshot.get("boss_ult","奥义"))+(" · 重击可打断" if float(snapshot.get("boss_timer",0))<0.45 else " · 霸体蓄力，离开攻击落点")
	elif snapshot.boss_state=="ult_active": status=str(snapshot.get("boss_ult","奥义"))+" · 移动躲避后续攻击"
	elif snapshot.boss_state=="ult_recover": status="奥义收招 · 反击窗口"
	elif float(snapshot.get("boss_guard",0))>0: status="破势保护 · 仍可造成伤害"
	var phase: int=int(snapshot.get("boss_phase",1))
	if phase>1: status=("二阶·封印崩解" if phase==2 else "三阶·裂界暴走")+"  /  "+status
	if snapshot.boss_state=="rift_arrive": status="裂缝开启 · 荒神降临"
	elif snapshot.boss_state=="phase_shift": status="封印破碎 · 新招式即将解锁"
	if snapshot.boss_state=="tell" and not str(snapshot.get("boss_move","")).is_empty(): status=str(snapshot.boss_move)+" · 蓄势，准备规避"
	var width:=font.get_string_size(status,HORIZONTAL_ALIGNMENT_LEFT,-1,Preferences.font_size(12)).x+24
	c.draw_style_box(box(Color(0.035,0.085,0.11,0.8),Color(0.68,0.66,0.48,0.19),1,5),Rect2((c.size.x-width)/2,75,width,22))
	text(c,status,Vector2(0,90),12,MINT if snapshot.boss_state in ["stunned","ult_recover"] else GOLD if snapshot.boss_state in ["tell","active","ult_tell","ult_active"] else MUTED,false,c.size.x,HORIZONTAL_ALIGNMENT_CENTER)
	if snapshot.has("boss_stagger"):
		meter(c,Rect2(139,63,238,3),float(snapshot.boss_stagger)/100,MINT,0,Color("49655f"))
		text(c,"失衡",Vector2(99,68),10,MUTED)
	text(c,"%d / %d" % [snapshot.boss_hp,snapshot.boss_max],Vector2(387,68),10,MUTED,false,115,HORIZONTAL_ALIGNMENT_RIGHT)
	for threshold in [.65,.30]:
		var x: float=r.position.x+r.size.x*threshold
		line(c,Vector2(x,r.position.y-2),Vector2(x,r.end.y+2),Color("fff0c4"),1.5)

func paint_dock(c: Control) -> void:
	if snapshot.is_empty(): return
	# The dock is a floating instrument rail, with the game space left unobstructed.
	var centers: Array[Vector2]=[Vector2(52,43),Vector2(158,43),Vector2(264,43),Vector2(422,43)]
	var names: Array[String]=["节奏连击","重击破势","闪避",str(snapshot.get("skill_label","碎片冲击"))]
	var kinds: Array[String]=["slash","heavy","dash","skill"]
	var keys: Array[String]=[Preferences.key_name("attack"),Preferences.key_name("heavy"),Preferences.key_name("dash"),Preferences.key_name("skill")]
	line(c,Vector2(50,44),Vector2(422,44),Color(0.42,0.55,0.52,0.4))
	for i in 4:
		var at: Vector2=centers[i]
		var radius:=35.0 if i==3 else 28.0
		var ready: bool=not snapshot.dead if i==0 else heavy_ready if i==1 else dash_ready if i==2 else skill_ready
		var awakened: bool=str(snapshot.get("power_phase","dormant"))!="dormant"
		var accent: Color=(Color("d4a0ff") if awakened else MINT) if i==3 else GOLD
		var active: bool=(snapshot.state=="attack" and ((i==0 and snapshot.combo<2) or (i==1 and snapshot.combo==2))) or (i==2 and snapshot.state=="dash") or (i==3 and snapshot.state=="skill")
		if i==3 and skill_ready:
			var glow:=0.09 if host.reduce_motion else 0.09+0.045*sin(clock*2.5)
			for n in range(5,0,-1): diamond(c,at,radius+n*2,Color(0.4,1,0.78,glow*0.36))
		diamond(c,at+Vector2(0,4),radius+3,Color(0.025,0.05,0.065,0.65))
		diamond(c,at,radius+2,Color(0.04,0.095,0.12,0.97),Color(accent,0.8 if ready else 0.28),1.5)
		diamond(c,at,radius-4,Color(0.12,0.23,0.24,0.75) if active or (i==3 and skill_ready) else Color(0.025,0.07,0.09,0.82),Color(accent,0.2),1)
		if active: diamond(c,at,radius+5,Color.TRANSPARENT,GOLD_LIGHT,1.3)
		GLYPHS.draw_icon(c,kinds[i],at,18.0 if i<3 else 22.0,accent if ready or active else Color("677e7c"))
		if i==2 and float(snapshot.dash_cd)>0:
			var remaining:=clampf(float(snapshot.dash_cd)/float(snapshot.get("dash_limit",.55)),0,1)
			c.draw_arc(at,radius+5,-PI/2,-PI/2+TAU*(1-remaining),48,Color(GOLD,0.9),1.8,true)
			c.draw_circle(at,15,Color(0.03,0.07,0.09,0.88))
			text(c,"%.1f" % snapshot.dash_cd,at+Vector2(-18,6),15,PAPER,true,36,HORIZONTAL_ALIGNMENT_CENTER)
		if i==3:
			if skill_locked:
				text(c,"Lv.2",at+Vector2(-22,6),16,MUTED,true,44,HORIZONTAL_ALIGNMENT_CENTER)
			else:
				c.draw_arc(at,radius+6,-PI/2,-PI/2+TAU*clampf(float(snapshot.get("power_remaining",0))/14 if awakened else focus_display/0.60,0,1),72,Color(accent,0.95),2.2,true)
				text(c,"觉醒" if awakened else "专注",Vector2(478,28),12,MUTED)
				text(c,"%02d" % ceili(float(snapshot.get("power_remaining",0))) if awakened else "%02d" % roundi(snapshot.focus),Vector2(476,53),22,accent,true)
				text(c,"秒" if awakened else "/ 100",Vector2(478,72),11,MUTED)
			if skill_ready: text(c,"就绪",Vector2(at.x-22,3),12,GOLD_LIGHT,true,44,HORIZONTAL_ALIGNMENT_CENTER)
			elif snapshot.state=="skill" and snapshot.has("skill_charge"):
				var progress: float=float(snapshot.skill_charge)
				c.draw_arc(at,radius+9,-PI/2,-PI/2+TAU*maxf(0.001,progress),64,GOLD_LIGHT,2.5,true)
				text(c,"蓄力" if progress<1 else "释放",Vector2(at.x-22,3),12,GOLD_LIGHT,true,44,HORIZONTAL_ALIGNMENT_CENTER)
			if ready_flash>0 and not host.reduce_motion:
				c.draw_arc(at,radius+9+(1-ready_flash)*13,0,TAU,64,Color(MINT,ready_flash*0.6),1.5,true)
		var key_rect:=Rect2(at+Vector2(-11,radius-6),Vector2(23,21))
		c.draw_style_box(box(Color("172d32"),Color(accent,0.7),1,4),key_rect)
		text(c,keys[i],key_rect.position+Vector2(0,16),13,PAPER,true,23,HORIZONTAL_ALIGNMENT_CENTER)
		text(c,names[i],Vector2(at.x-48,109),15,PAPER if ready or i==0 else MUTED,false,96,HORIZONTAL_ALIGNMENT_CENTER)

func paint_help(c: Control) -> void:
	text(c,"%s / %s 移动  %s 二段跳" % [Preferences.key_name("move_left"),Preferences.key_name("move_right"),Preferences.key_name("jump")],Vector2(0,23),14,Color("c6d2c5"),false,270)
	if not snapshot.is_empty():
		for i in 2:
			var ready: bool=i>=int(snapshot.get("jumps_used",0)) and not snapshot.dead
			diamond(c,Vector2(11+i*22,-3),7,MINT if ready else Color("35484f"),PAPER if ready else MUTED,1)
		text(c,"空中再按 · 落地补充",Vector2(47,2),12,MUTED,false,215)
	text(c,Preferences.key_name("interact")+" 交互   Tab 补给   P 桌宠",Vector2(0,49),12,MUTED,false,270)
	line(c,Vector2(0,60),Vector2(128,60),Color(GOLD,0.24))

func paint_loot(c: Control) -> void:
	if snapshot.is_empty(): return
	GLYPHS.draw_icon(c,"bag",Vector2(17,15),13,GOLD)
	text(c,"金币  %d" % int(snapshot.get("coins",0)),Vector2(41,23),16,GOLD_LIGHT,true)
	var progress:=float(snapshot.xp)/maxf(1,snapshot.needed)
	line(c,Vector2(3,40),Vector2(165,40),Color(0.4,0.55,0.53,0.55),2)
	if progress>0: line(c,Vector2(3,40),Vector2(3+162*progress,40),GOLD,2)
	text(c,"%d / %d XP" % [snapshot.xp,snapshot.needed],Vector2(0,58),11,MUTED,false,169,HORIZONTAL_ALIGNMENT_RIGHT)
	var relics: Dictionary=snapshot.get("relics",{})
	var i:=0
	for id in relics:
		var d: Dictionary=preload("res://rift/director.gd").RELICS[id]
		GLYPHS.draw_icon(c,d.glyph,Vector2(18+i*38,-18),10,d.color)
		i+=1
	if float(snapshot.get("riposte",0))>0: text(c,"精准反击 +35%",Vector2(-7,-38),13,MINT,true)
