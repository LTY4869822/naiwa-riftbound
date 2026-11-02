extends CanvasLayer
## Browser touch controls send the same actions as the keyboard.
var host: Node
var pad: Control
var held: Dictionary={}
var report_clock:=0.0
var tracked_player:=0
var max_x:=0.0
var min_y:=640.0
func _ready() -> void:
	layer=90
	pad=Control.new(); pad.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(pad)
	var controls: Array=[['move_left','←',24],['move_right','→',104],['awaken','觉',650],['skill','奥',730],['attack','攻',810],['heavy','重',890],['dash','闪',970],['jump','跳',1130]]
	for entry in controls:
		var b:=TouchScreenButton.new(); b.position=Vector2(entry[2],711)
		var shape:=RectangleShape2D.new(); shape.size=Vector2(68,68)
		b.shape=shape; b.shape_centered=false; b.action=entry[0]
		b.draw.connect(paint_button.bind(b,str(entry[1])))
		b.pressed.connect(b.queue_redraw); b.released.connect(b.queue_redraw)
		pad.add_child(b)
func paint_button(button: TouchScreenButton,label: String) -> void:
	var style:=StyleBoxFlat.new()
	style.bg_color=Color(.27,.42,.24,.9) if button.is_pressed() else Color(.06,.09,.12,.78)
	style.border_color=Color('bded85'); style.set_border_width_all(2); style.set_corner_radius_all(20)
	button.draw_style_box(style,Rect2(0,0,68,68))
	var font: Font=preload('res://web_assets/bold.tres')
	var width: float=font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,26).x
	button.draw_string(font,Vector2((68-width)*.5,44),label,HORIZONTAL_ALIGNMENT_LEFT,-1,26,Color('efffcf'))
func send(name: String,down: bool) -> void:
	held[name]=down
	var event:=InputEventAction.new(); event.action=name; event.pressed=down
	Input.parse_input_event(event)
func _process(_dt: float) -> void:
	var active: bool=OS.has_feature('web') and DisplayServer.is_touchscreen_available() and host.playing()
	if pad.visible and not active:
		for name in held:
			if held[name]: send(name,false)
	pad.visible=active
	var extent: Vector2=host.get_viewport_rect().size
	var factor:=minf(extent.x/1280.0,extent.y/800.0)
	pad.scale=Vector2.ONE*factor; pad.position=(extent-Vector2(1280,800)*factor)*.5
	if not OS.has_feature('web'): return
	report_clock+=_dt
	if report_clock<.25: return
	report_clock=0
	var status: Dictionary={'mode':host.mode,'paused':host.paused,'level':Profile.level,'coins':Wardrobe.coins,'kills':host.kills,'contacts':host.punch.confirmed}
	if is_instance_valid(host.player):
		var p: Node=host.player
		if tracked_player!=p.get_instance_id(): tracked_player=p.get_instance_id(); max_x=p.position.x; min_y=p.position.y
		max_x=maxf(max_x,p.position.x); min_y=minf(min_y,p.position.y)
		status.player={'x':p.position.x,'y':p.position.y,'hp':p.hp,'state':p.state,'jumps':p.jumps_used,'max_x':max_x,'min_y':min_y}
	JavaScriptBridge.eval('if(window.__naiwa){window.__naiwa.snapshot='+JSON.stringify(status)+';document.getElementById("canvas").dataset.gameState=JSON.stringify(window.__naiwa.snapshot);}',true)
