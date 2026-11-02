extends "res://v5/menu.gd"

func build() -> void:
	var i:=0
	for action in Preferences.DEFAULTS:
		var key: String=action
		var b:=sticker("Bind_"+key,Vector2(62+(i%2)*590,304+floori(i/2.0)*64),Vector2(560,56),Preferences.NAMES[key]+"    "+Preferences.key_name(key),"",func(): Preferences.begin_capture(key),PURPLE if Preferences.capture_action==key else INK)
		b.large=false
		i+=1
	sticker("ControlsBack",Vector2(61,672),Vector2(231,59),"返回设置","",func(): navigate("settings"),INK,"",0,"back")
	sticker("ResetKeys",Vector2(906,672),Vector2(305,59),"恢复默认键位","",Preferences.reset_bindings,PURPLE)
	for n in buttons.size():
		buttons[n].focus_next=buttons[n].get_path_to(buttons[(n+1)%buttons.size()])
		buttons[n].focus_previous=buttons[n].get_path_to(buttons[(n-1+buttons.size())%buttons.size()])
		buttons[n].focus_neighbor_bottom=buttons[n].focus_next
		buttons[n].focus_neighbor_top=buttons[n].focus_previous
	var count:=Preferences.DEFAULTS.size()
	for n in count:
		var peer:=n+1 if n%2==0 else n-1
		if peer>=count: peer=count
		buttons[n].focus_neighbor_left=buttons[n].get_path_to(buttons[peer])
		buttons[n].focus_neighbor_right=buttons[n].focus_neighbor_left
		buttons[n].focus_neighbor_top=buttons[n].get_path_to(buttons[n-2 if n>=2 else count+n])
		buttons[n].focus_neighbor_bottom=buttons[n].get_path_to(buttons[mini(n+2,count+1)])
	host.call_deferred("focus_control",buttons[0])
	host.menu_entrance=false

func paint() -> void:
	paint_logo()
	paint_profile()
	outlined("操作与按键",Vector2(60,245),46)
	label_at("点击操作后按新键；冲突键会互换。Esc 取消改键。",Vector2(64,283),18,PAPER)
	label_at(Preferences.message,Vector2(63,651),18,YELLOW,true)
	label_at("手柄：左摇杆移动 · A跳跃 · X普攻 · Y重击 · B闪避 · RB奥义 · LB交互 · R3觉醒",Vector2(62,755),16,PAPER)
	label_at("Start暂停 · Back营地；菜单始终保留 Esc / Tab / Enter。",Vector2(62,783),14,Color("bda9cd"))
