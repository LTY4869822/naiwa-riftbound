extends Control
## Ink-sticker route map: native inputs, jelly surfaces and a shared focus spring.
const LEVELS = preload("res://campaign/levels.gd")
const CARD = preload("res://campaign/jelly_card.gd")
const INK := Color("17121f")
const PAPER := Color("fffdf1")
const ACID := Color("d7ff31")
const PURPLE := Color("a449ee")
var host: Node
var canvas: Control
var cards: Array[Button]=[]
var back: Button
var bold: SystemFont
var active_control: Control
var active_index := 0
var committing := false
var pending_level := -1
var pending_stage := 0
var activation_count := 0
var clock := 0.0
var focus_box := Rect2()
var focus_initialized := false
var follow_velocity := Vector2.ZERO
var size_velocity := Vector2.ZERO
var overlay: Control
var burst_age := 10.0
var burst_point := Vector2.ZERO
var background_material: ShaderMaterial
var activation_tween: Tween
var trial: Button

func _ready() -> void:
	name="LevelRoute"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_STOP
	bold=SystemFont.new()
	bold.font_names=PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei"])
	bold.font_weight=900
	var background:=ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter=Control.MOUSE_FILTER_IGNORE
	background_material=ShaderMaterial.new()
	background_material.shader=preload("res://v5/menu_background.gdshader")
	background_material.set_shader_parameter("scene",load(LEVELS.get_level(host.level_index).background))
	background.material=background_material
	add_child(background)
	var shade:=ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color=Color(0.055,0.025,0.09,0.65)
	shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	canvas=Control.new()
	canvas.size=Vector2(1280,800)
	canvas.mouse_filter=Control.MOUSE_FILTER_IGNORE
	canvas.draw.connect(paint)
	add_child(canvas)
	for i in LEVELS.LEVELS.size():
		var b:=CARD.new()
		b.name="ChooseLevel%d" % i
		b.host=host
		b.definition=LEVELS.get_level(i)
		b.index=i
		b.completed=host.completed_levels.has(i)
		b.title_font=bold
		b.body_font=host.font
		b.position=Vector2(64+(i%2)*594,165+floori(i/2.0)*266)
		b.size=Vector2(558,240)
		b.entrance_delay=0.045+i*0.055
		canvas.add_child(b)
		cards.append(b)
		b.mouse_entered.connect(func():
			if not committing: b.grab_focus())
		b.focus_entered.connect(func(): select_card(i))
		b.pressed.connect(func(): activate_level(i))
		for j in b.stage_buttons.size():
			var stage_button: Button=b.stage_buttons[j]
			stage_button.pressed.connect(func(): activate_level(i,j))
			stage_button.focus_entered.connect(func():
				select_card(i)
				active_control=stage_button)
	back=preload("res://v5/sticker_button.gd").new()
	back.name="CloseRoute"
	back.host=host
	back.title="返回"
	back.title_font=bold
	back.body_font=host.font
	back.glyph="back"
	back.tint=PURPLE
	back.position=Vector2(67,716)
	back.size=Vector2(172,59)
	canvas.add_child(back)
	back.pressed.connect(request_close)
	back.focus_entered.connect(func():
		active_control=back
		for b in cards: b.highlighted=false)
	back.mouse_entered.connect(func():
		if not committing: back.grab_focus())
	if host.get("trial_mode")!=null:
		trial=preload("res://v5/sticker_button.gd").new()
		trial.name="TrialMode"
		trial.host=host
		trial.title="同级试炼：开" if host.trial_mode else "成长冒险：开"
		trial.title_font=bold
		trial.body_font=host.font
		trial.tint=PURPLE if host.trial_mode else INK
		trial.position=Vector2(621,51)
		trial.size=Vector2(310,54)
		trial.tooltip_text="成长冒险：吞噬升级后可以更轻松通关。试炼：敌人强度随等级提升。两种模式共用通关奖励。"
		canvas.add_child(trial)
		trial.pressed.connect(func():
			host.trial_mode=not host.trial_mode
			host.save_menu_settings()
			trial.title="同级试炼：开" if host.trial_mode else "成长冒险：开"
			trial.tint=PURPLE if host.trial_mode else INK
			canvas.queue_redraw())
	wire_focus()
	overlay=Control.new()
	overlay.size=Vector2(1280,800)
	overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
	overlay.draw.connect(paint_focus)
	canvas.add_child(overlay)
	resized.connect(fit)
	fit()
	active_index=clampi(host.level_index,0,cards.size()-1)
	host.call_deferred("focus_control",cards[active_index])

func wire_focus() -> void:
	var ordered: Array[Button]=cards.duplicate()
	for c in cards:
		for stage_button in c.stage_buttons: ordered.append(stage_button)
	ordered.append(back)
	if is_instance_valid(trial): ordered.append(trial)
	for i in cards.size():
		var b: Button=cards[i]
		b.focus_neighbor_left=b.get_path_to(cards[i-1 if i%2==1 else i+1])
		b.focus_neighbor_right=b.get_path_to(cards[i+1 if i%2==0 else i-1])
		b.focus_neighbor_top=b.get_path_to(cards[i-2] if i>=2 else back)
		b.focus_neighbor_bottom=b.get_path_to(cards[i+2] if i<2 else back)
	for i in ordered.size():
		ordered[i].focus_next=ordered[i].get_path_to(ordered[(i+1)%ordered.size()])
		ordered[i].focus_previous=ordered[i].get_path_to(ordered[(i-1+ordered.size())%ordered.size()])
	back.focus_neighbor_top=back.get_path_to(cards[maxi(2,active_index)])
	back.focus_neighbor_bottom=back.get_path_to(cards[0])
	if is_instance_valid(trial):
		trial.focus_neighbor_bottom=trial.get_path_to(cards[0])
		trial.focus_neighbor_top=trial.get_path_to(back)

func select_card(index: int) -> void:
	if committing: return
	var changed: bool=active_control!=cards[index]
	active_index=index
	active_control=cards[index]
	for i in cards.size(): cards[i].highlighted=i==index
	back.focus_neighbor_top=back.get_path_to(cards[maxi(2,index)])
	if changed and clock>0.2: host.play_sound("dash",-34,1.65)

func activate_level(index: int, chapter: int=0) -> void:
	if committing or host.menu_transition.busy: return
	select_card(index)
	committing=true
	pending_level=index
	pending_stage=chapter
	activation_count+=1
	cards[index].confirm()
	burst_point=cards[index].position+Vector2(cards[index].size.x-94,183)
	burst_age=0
	for b in cards:
		b.disabled=true
		for stage_button in b.stage_buttons: stage_button.disabled=true
	back.disabled=true
	if is_instance_valid(trial): trial.disabled=true
	host.play_sound("feed",-28,1.35)
	if host.reduce_motion:
		host.choose_level(index,chapter)
		return
	# The node-bound delay dies with this screen, preventing a stale activation.
	activation_tween=create_tween()
	activation_tween.tween_interval(0.13)
	activation_tween.tween_callback(func():
		host.menu_action(func(): host.choose_level(index,chapter)))

func request_close() -> void:
	if host.menu_transition.busy: return
	if is_instance_valid(activation_tween): activation_tween.kill()
	pending_level=-1
	committing=true
	for b in cards: b.disabled=true
	back.disabled=true
	host.menu_action(host.close_route)

func _process(dt: float) -> void:
	clock+=dt
	burst_age+=dt
	background_material.set_shader_parameter("clock",0.0 if host.reduce_motion else clock*0.35)
	if is_instance_valid(active_control):
		var transform:=canvas.get_global_transform().affine_inverse()*active_control.get_global_transform()
		var lower: Vector2=transform*Vector2.ZERO
		var upper:=lower
		for corner in [Vector2(active_control.size.x,0),active_control.size,Vector2(0,active_control.size.y)]:
			var point: Vector2=transform*corner
			lower=lower.min(point)
			upper=upper.max(point)
		var goal:=Rect2(lower,upper-lower).grow(2)
		if not focus_initialized or host.reduce_motion:
			focus_box=goal
			follow_velocity=Vector2.ZERO
			size_velocity=Vector2.ZERO
			focus_initialized=true
		else:
			var remaining:=minf(dt,0.10)
			while remaining>0.00001:
				var step:=minf(remaining,1.0/120)
				follow_velocity+=((goal.position-focus_box.position)*320-follow_velocity*30)*step
				size_velocity+=((goal.size-focus_box.size)*320-size_velocity*30)*step
				focus_box.position+=follow_velocity*step
				focus_box.size+=size_velocity*step
				remaining-=step
	overlay.queue_redraw()

func box(fill: Color, border: Color=Color.TRANSPARENT, width: int=0, radius: int=18) -> StyleBoxFlat:
	var style:=StyleBoxFlat.new()
	style.bg_color=fill
	style.border_color=border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	return style

func text(value: String, at: Vector2, fs: int, color: Color=PAPER, heavy: bool=false) -> void:
	canvas.draw_string(bold if heavy else host.font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,fs,color)

func paint() -> void:
	canvas.draw_set_transform(Vector2(177,58),-0.045)
	canvas.draw_style_box(box(PURPLE,INK,4,19),Rect2(-118,-32,244,67))
	canvas.draw_set_transform(Vector2.ZERO)
	canvas.draw_string_outline(bold,Vector2(65,91),"四境巡游",HORIZONTAL_ALIGNMENT_LEFT,-1,49,10,INK)
	text("四境巡游",Vector2(65,91),49,PAPER,true)
	text("每境三段连续战斗 · 生命与收集一路保留。",Vector2(69,132),18,Color("d0c4dc"))
	if is_instance_valid(trial): text("等级适配 · 奖励共用" if host.trial_mode else "吞噬成长 · 变强再挑战",Vector2(647,132),15,Color("d0c4dc"))
	var explored:=0
	for i in cards.size():
		for chapter in 3:
			if int(Wardrobe.clears.get(LEVELS.get_stage(i,chapter).id,0))>0: explored+=1
	canvas.draw_style_box(box(Color("2c203d"),Color("766184"),1,20),Rect2(966,53,248,48))
	canvas.draw_circle(Vector2(991,77),5,ACID)
	text("已通关  %02d / 12" % explored,Vector2(1009,84),18,PAPER,true)
	canvas.draw_line(Vector2(270,735),Vector2(270,766),Color("5b456f"),2,true)
	text("Tab 切换关卡按钮    Enter 出发    Esc 返回",Vector2(296,740),16,PAPER)
	var footer: String="F1～F4 首领演武 · F5 疾跑练习 · L/Shift 冲刺 · U 奥义" if "--remediation-demo" in OS.get_cmdline_user_args() else "等级与成长共用 · 选择关卡会重新开始该关"
	if "--ascension-demo" in OS.get_cmdline_user_args(): footer="R 魔神觉醒 · U 紫霆灭界 · F1～F4 异兽演武 · F6 补能"
	if "--loop-demo" in OS.get_cmdline_user_args(): footer="金币可锻造装备 · 关间拾取药露 · F1～F4首领演武 · R觉醒需蓄能"
	text(footer,Vector2(296,768),15,Color("bca9cb"))
	canvas.draw_set_transform(Vector2(1156,746),-0.05)
	canvas.draw_style_box(box(ACID,INK,3,11),Rect2(-55,-22,110,42))
	text("去冒险！",Vector2(-38,7),19,INK,true)
	canvas.draw_set_transform(Vector2.ZERO)

func paint_focus() -> void:
	if focus_initialized:
		var pulse:=0.0 if host.reduce_motion else sin(clock*TAU/1.3)*0.75
		overlay.draw_style_box(box(Color.TRANSPARENT,INK,5,27),focus_box.grow(5))
		overlay.draw_style_box(box(Color.TRANSPARENT,ACID,2,28),focus_box.grow(8+pulse))
		overlay.draw_style_box(box(Color.TRANSPARENT,PAPER,2,25),focus_box.grow(1))
	if burst_age<0.55 and not host.reduce_motion:
		var t:=burst_age/0.55
		for i in 10:
			var angle:=TAU*i/10.0+0.2
			var p:=burst_point+Vector2.from_angle(angle)*(12+t*(30+i%4*12))+Vector2(0,32*t*t)
			overlay.draw_circle(p,(3+i%3*1.4)*(1-t),ACID if i%2==0 else PURPLE)

func fit() -> void:
	if canvas==null: return
	var factor: float=minf(size.x/1280.0,size.y/800.0)
	canvas.scale=Vector2.ONE*factor
	canvas.position=(size-Vector2(1280,800)*factor)/2
