extends Node
signal changed
var large_text:=false
var capture_action:=""
var message:=""
var enabled_saving:=true
const PATH:="user://controls.cfg"
const DEFAULTS:={"move_left":KEY_A,"move_right":KEY_D,"jump":KEY_SPACE,"attack":KEY_J,"heavy":KEY_K,"dash":KEY_L,"skill":KEY_U,"interact":KEY_E,"awaken":KEY_R}
const NAMES:={"move_left":"向左移动","move_right":"向右移动","jump":"跳跃","attack":"普攻连击","heavy":"重击破势","dash":"闪避冲刺","skill":"星核奥义","interact":"场地交互","awaken":"魔神觉醒"}
const PAD:={"jump":JOY_BUTTON_A,"attack":JOY_BUTTON_X,"heavy":JOY_BUTTON_Y,"dash":JOY_BUTTON_B,"skill":JOY_BUTTON_RIGHT_SHOULDER,"interact":JOY_BUTTON_LEFT_SHOULDER,"awaken":JOY_BUTTON_RIGHT_STICK,"pause":JOY_BUTTON_START,"camp":JOY_BUTTON_BACK}
var keys: Dictionary=DEFAULTS.duplicate()

func _ready() -> void:
	enabled_saving=get_node("/root/Profile").save_enabled
	if enabled_saving:
		var config:=ConfigFile.new()
		if config.load(PATH)==OK:
			large_text=bool(config.get_value("display","large_text",false))
			var seen: Dictionary={}
			var proposed: Dictionary={}
			for action in DEFAULTS:
				var value=config.get_value("keys",action,DEFAULTS[action])
				if value is int and value>0 and value not in [KEY_ESCAPE,KEY_TAB,KEY_P,KEY_ENTER,KEY_SHIFT,KEY_LEFT,KEY_RIGHT] and not seen.has(value):
					proposed[action]=value
					seen[value]=true
			# Preserve eight-action user bindings when adding awakening to old saves.
			if not proposed.has("awaken"):
				for fallback in [KEY_R,KEY_F,KEY_G,KEY_H,KEY_V,KEY_B]:
					if not seen.has(fallback):
						proposed["awaken"]=fallback
						break
			if proposed.size()==DEFAULTS.size(): keys=proposed
	install()

func install() -> void:
	var definitions: Dictionary=keys.duplicate()
	definitions.merge({"pause":KEY_ESCAPE,"camp":KEY_TAB,"pet":KEY_P})
	for action in definitions:
		if not InputMap.has_action(action): InputMap.add_action(action,0.22)
		InputMap.action_erase_events(action)
		var key:=InputEventKey.new()
		key.physical_keycode=definitions[action]
		InputMap.action_add_event(action,key)
		if action in ["move_left","move_right"]:
			var arrow:=InputEventKey.new()
			arrow.physical_keycode=KEY_LEFT if action=="move_left" else KEY_RIGHT
			InputMap.action_add_event(action,arrow)
			var axis:=InputEventJoypadMotion.new()
			axis.axis=JOY_AXIS_LEFT_X
			axis.axis_value=-1.0 if action=="move_left" else 1.0
			InputMap.action_add_event(action,axis)
		if PAD.has(action):
			var button:=InputEventJoypadButton.new()
			button.button_index=PAD[action]
			InputMap.action_add_event(action,button)

	var shift:=InputEventKey.new()
	shift.physical_keycode=KEY_SHIFT
	InputMap.action_add_event("dash",shift)

func font_size(base: int) -> int:
	return roundi(base*1.2) if large_text and base<=38 else base

func key_name(action: String) -> String:
	return OS.get_keycode_string(int(keys.get(action,KEY_ESCAPE)))

func begin_capture(action: String) -> void:
	if not DEFAULTS.has(action): return
	capture_action=action
	message="按下新的按键；Esc 取消。"
	changed.emit()

func rebind(action: String, code: int) -> bool:
	if not DEFAULTS.has(action) or code<=0 or code in [KEY_ESCAPE,KEY_TAB,KEY_P,KEY_ENTER,KEY_SHIFT,KEY_LEFT,KEY_RIGHT]:
		message="Esc / Tab / P / Enter 及方向键、Shift 已保留，请换一个键。"
		return false
	var previous: int=keys[action]
	for other in keys:
		if other!=action and keys[other]==code: keys[other]=previous
	keys[action]=code
	install()
	message="已绑定："+NAMES[action]+" → "+key_name(action)
	save_settings()
	changed.emit()
	return true

func _input(event: InputEvent) -> void:
	if capture_action.is_empty() or not event is InputEventKey or not event.pressed or event.echo: return
	get_viewport().set_input_as_handled()
	if event.keycode==KEY_ESCAPE:
		capture_action=""
		message="已取消改键。"
		changed.emit()
		return
	var action:=capture_action
	if rebind(action,int(event.physical_keycode if event.physical_keycode!=0 else event.keycode)): capture_action=""
	changed.emit()

func toggle_text() -> void:
	large_text=not large_text
	save_settings()
	changed.emit()

func reset_bindings() -> void:
	keys=DEFAULTS.duplicate()
	capture_action=""
	message="已恢复默认键位。"
	install()
	save_settings()
	changed.emit()

func save_settings() -> bool:
	if not enabled_saving: return true
	var config:=ConfigFile.new()
	config.set_value("display","large_text",large_text)
	for action in keys: config.set_value("keys",action,keys[action])
	if config.save(PATH)!=OK:
		message="设置暂未保存，本次会话继续生效。"
		return false
	return true
