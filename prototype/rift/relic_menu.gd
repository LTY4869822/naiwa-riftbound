extends Control
const T=preload("res://echo/ink.gd")
const CARD=preload("res://echo/relic_card.gd")
var host: Node
var director: Node
var buttons: Array[Button]=[]
var bold: SystemFont
var canvas: Control
var focused:=0
var committing:=false
var accept_ready:=true
var last_nav_ms: int=0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_STOP
	z_index=20
	bold=SystemFont.new()
	bold.font_names=PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei"])
	bold.font_weight=900
	canvas=Control.new()
	canvas.size=Vector2(1280,800)
	canvas.mouse_filter=Control.MOUSE_FILTER_IGNORE
	canvas.draw.connect(paint)
	add_child(canvas)
	for i in director.offers.size():
		var b:=CARD.new()
		b.host=host; b.menu=self; b.relic_id=director.offers[i]; b.index=i
		b.base=Vector2(80+i*384,246)
		b.position=b.base; b.size=Vector2(352,430)
		canvas.add_child(b)
		buttons.append(b)
	for i in buttons.size():
		buttons[i].focus_neighbor_left=buttons[i].get_path_to(buttons[(i+buttons.size()-1)%buttons.size()])
		buttons[i].focus_neighbor_right=buttons[i].get_path_to(buttons[(i+1)%buttons.size()])
		buttons[i].focus_next=buttons[i].focus_neighbor_right
		buttons[i].focus_previous=buttons[i].focus_neighbor_left
		buttons[i].focus_neighbor_top=buttons[i].focus_neighbor_left
		buttons[i].focus_neighbor_bottom=buttons[i].focus_neighbor_right
	var saved: int=director.offers.find(director.offer_focus)
	focused=maxi(0,saved)
	accept_ready=not Input.is_action_pressed("ui_accept") and not Input.is_action_pressed("jump")
	host.call_deferred("focus_control",buttons[focused])
	resized.connect(layout)
	host.get_window().focus_exited.connect(clear_press)
	layout()
	queue_redraw()

func _exit_tree() -> void:
	if is_instance_valid(host) and host.get_window().focus_exited.is_connected(clear_press): host.get_window().focus_exited.disconnect(clear_press)

func layout() -> void:
	if not is_instance_valid(canvas): return
	var available: Vector2=get_viewport_rect().size
	var factor: float=minf(available.x/1280,available.y/800)
	canvas.scale=Vector2.ONE*factor
	canvas.position=(available-Vector2(1280,800)*factor)*.5
	queue_redraw()

func clear_press() -> void:
	for b in buttons:
		b.down=false
		b.cancelled=true
		b.set_pressed_no_signal(false)

func focus_card(index: int) -> void:
	if focused!=index:
		focused=index
		host.play_sound("dash",-34,1.7)
	director.offer_focus=director.offers[index]
	canvas.queue_redraw()

func activate(index: int) -> void:
	if committing or is_queued_for_deletion() or not director.offer_active: return
	var id: String=director.offers[index]
	if not director.pick(id): return
	committing=true
	host.play_sound("feed",-20,1.15)
	var stamp:=preload("res://echo/claim_stamp.gd").new()
	stamp.host=host; stamp.bold=bold; stamp.title=director.RELICS[id].title
	host.hud.add_child(stamp)

func _input(event: InputEvent) -> void:
	if committing or is_queued_for_deletion() or not director.offer_active or not is_visible_in_tree(): return
	if host.test_mode and "--echo-demo" in OS.get_cmdline_user_args() and event is InputEventKey and event.keycode in [KEY_F1,KEY_F2,KEY_F3,KEY_F4]: return
	if event is InputEventMouse: return
	if event.is_action("ui_accept") or event.is_action("jump"):
		get_viewport().set_input_as_handled()
		if not event.is_pressed(): accept_ready=true
		elif accept_ready and not event.is_echo(): activate(focused)
		return
	var direction:=0
	if event.is_action_pressed("ui_left") or event.is_action_pressed("move_left"): direction=-1
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("move_right"): direction=1
	elif event.is_action_pressed("ui_up"): direction=-1
	elif event.is_action_pressed("ui_down"): direction=1
	elif event is InputEventKey and event.pressed and event.keycode==KEY_TAB: direction=-1 if event.shift_pressed else 1
	if direction!=0:
		get_viewport().set_input_as_handled()
		var now: int=Time.get_ticks_msec()
		if event is InputEventJoypadMotion and now-last_nav_ms<170: return
		last_nav_ms=now
		buttons[posmod(focused+direction,buttons.size())].grab_focus()
		return
	if event.is_action("pause") or event.is_action("pet"): return
	get_viewport().set_input_as_handled()

func _draw() -> void:
	draw_rect(get_viewport_rect(),Color(.045,.030,.075,.94))

func paint() -> void:
	var ink:=T.color("ink")
	var paper:=T.color("paper")
	T.splat(canvas,Vector2(1267,265),Vector2(190,250),Color("47355d"),1)
	T.splat(canvas,Vector2(15,686),Vector2(170,136),Color("243d3a"),2)
	for row in 9:
		for col in 18: canvas.draw_circle(Vector2(1000+col*14,22+row*14),1.4,Color(.77,.68,.85,.12))
	canvas.draw_set_transform(Vector2(78,77),0 if host.reduce_motion else -.035)
	canvas.draw_colored_polygon(T.ticket(Rect2(0,0,161,29)),T.color("focus"))
	T.words(canvas,bold,"关 卡 突 破",Vector2(15,23),18,ink)
	canvas.draw_set_transform(Vector2.ZERO)
	T.splat(canvas,Vector2(389,145),Vector2(260,47),Color("564364"),1.5)
	T.words(canvas,bold,"胜利的余响",Vector2(78,169),50,paper,650,false,9)
	T.words(canvas,host.font,"选一件遗物，把你的打法带进下一关。",Vector2(82,209),20,Color("d9cfe5"),850)
	canvas.draw_set_transform(Vector2(957,82),0 if host.reduce_motion else .03)
	canvas.draw_colored_polygon(T.ticket(Rect2(6,7,240,91)),ink)
	canvas.draw_colored_polygon(T.ticket(Rect2(0,0,240,91)),paper)
	T.words(canvas,bold,str(host.current_level().map_title),Vector2(19,32),20,ink,205)
	T.words(canvas,bold,"%02d / 03  已完成" % (host.stage_index+1),Vector2(19,66),22,ink,205)
	canvas.draw_set_transform(Vector2.ZERO)
	var keys: Array=[["← →",80,90],["Tab",200,58],["Enter",422,72]]
	for k in keys:
		canvas.draw_colored_polygon(T.ticket(Rect2(k[1],718,k[2],32)),paper)
		T.words(canvas,bold,k[0],Vector2(k[1]+k[2]*.5,742),15,ink,k[2]-8,true)
	T.words(canvas,host.font,"切换",Vector2(276,741),17,paper)
	T.words(canvas,host.font,"确认共鸣",Vector2(511,741),17,paper)
	T.words(canvas,host.font,"也可直接点击整张票券",Vector2(800,742),17,Color("d9cfe5"),400)
	T.words(canvas,host.font,"遗物在本次地图旅程内保留 · 选好后拾取药露，向右继续",Vector2(82,779),15,Color("bdb0cd"),1100)
