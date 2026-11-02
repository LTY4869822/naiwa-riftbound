extends RefCounted
const A = preload("res://v4/art.gd")
const BACKDROP = preload("res://v4/ui_art.gd")

static func style(color: Color, border: Color = Color.TRANSPARENT, padding: int = 16) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(2)
	s.set_content_margin_all(padding)
	if border.a>0:
		s.border_color = border
		s.set_border_width_all(2)
	return s

static func text(parent: Node, value: String, size: int = 22, color: Color = A.PAPER) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

static func at(parent: Node, value: String, pos: Vector2, size: int = 22, color: Color = A.PAPER) -> Label:
	var label := text(parent,value,size,color)
	label.position = pos
	return label

static func button(parent: Node, title: String, action: Callable, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = title
	b.custom_minimum_size.y = 60
	b.add_theme_font_size_override("font_size",22)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	for state in ["font_color","font_focus_color"]: b.add_theme_color_override(state,A.INK if primary else A.PAPER)
	for state in ["font_hover_color","font_pressed_color"]: b.add_theme_color_override(state,A.INK)
	b.add_theme_color_override("font_disabled_color",A.DISTANT)
	b.add_theme_stylebox_override("normal",style(A.GOLD if primary else A.INK))
	b.add_theme_stylebox_override("hover",style(A.PAPER))
	b.add_theme_stylebox_override("pressed",style(A.CYAN))
	var focus := style(Color.TRANSPARENT,A.CYAN)
	focus.expand_margin_left = 5
	focus.expand_margin_right = 5
	focus.expand_margin_top = 5
	focus.expand_margin_bottom = 5
	b.add_theme_stylebox_override("focus",focus)
	b.add_theme_stylebox_override("disabled",style(A.SHADOW))
	b.pressed.connect(action)
	parent.add_child(b)
	return b

static func action(parent: Node, title: String, pos: Vector2, width: float, callback: Callable, primary: bool = false) -> Button:
	var b := button(parent,title,callback,primary)
	b.position = pos
	b.size.x = width
	return b

static func bar(parent: Node, value: float, maximum: float, color: Color, height: int = 10) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.max_value = maximum
	b.value = value
	b.custom_minimum_size = Vector2(0,height)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_theme_stylebox_override("background",style(A.SHADOW,Color.TRANSPARENT,0))
	b.add_theme_stylebox_override("fill",style(color,Color.TRANSPARENT,0))
	parent.add_child(b)
	return b

static func column(parent: Node, spacing: int = 12) -> VBoxContainer:
	var c := VBoxContainer.new()
	c.add_theme_constant_override("separation",spacing)
	parent.add_child(c)
	return c

static func row(parent: Node, spacing: int = 12) -> HBoxContainer:
	var c := HBoxContainer.new()
	c.add_theme_constant_override("separation",spacing)
	parent.add_child(c)
	return c

static func rect(parent: Node, p: Vector2, size: Vector2, color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.position = p
	r.size = size
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r

static func build(h: Node) -> void:
	if h.mode=="desktop": return
	if h.mode=="camp": camp(h)
	else: battle(h)
	var toast := at(h.hud,"",Vector2(40,684 if h.mode=="battle" else 748),20,A.PAPER)
	toast.size.x = 1200
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_theme_color_override("font_shadow_color",A.INK)
	toast.add_theme_constant_override("shadow_offset_x",2)
	toast.add_theme_constant_override("shadow_offset_y",2)
	h.hud_toast = toast

static func camp(h: Node) -> void:
	var art := BACKDROP.new()
	h.hud.add_child(art)
	at(h.hud,"NAIWA  /  FRAGMENT JOURNEY",Vector2(60,40),18,A.CYAN)
	at(h.hud,"碎片\n巡游",Vector2(56,103),82)
	at(h.hud,"把遗落的碎片，变成下一程的力量。",Vector2(64,325),22,A.DISTANT)
	var first := action(h.hud,"出发    →" if not is_instance_valid(h.player) or h.over else "继续巡游    →",Vector2(64,397),318,h.enter_battle,true)
	first.add_theme_font_size_override("font_size",32)
	first.custom_minimum_size.y = 76
	first.rotation = -0.024
	action(h.hud,"碎片背包     %02d" % Profile.files.size(),Vector2(69,493),304,func(): h.camp_page="feed"; h.build_ui())
	action(h.hud,"操作与设置",Vector2(75,565),292,func(): h.camp_page="settings"; h.build_ui())
	action(h.hud,"返回桌宠    ↗",Vector2(81,637),280,h.return_pet)
	at(h.hud,"01",Vector2(1134,40),60,A.INK)
	at(h.hud,"林间回廊",Vector2(1040,116),22,A.INK)
	var portrait := TextureRect.new()
	portrait.texture = load("res://assets/naiwa/idle.png")
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.position = Vector2(722,178)
	portrait.size = Vector2(385,490)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.hud.add_child(portrait)
	at(h.hud,"奶蛙",Vector2(744,640),34)
	at(h.hud,"Lv.%02d" % Profile.level,Vector2(1010,650),24,A.GOLD)
	var xp := bar(h.hud,Profile.xp,Profile.needed(),A.GOLD,6)
	xp.position = Vector2(744,704)
	xp.size.x = 350
	at(h.hud,"%d / %d XP     ·     碎片冲击 %s" % [Profile.xp,Profile.needed(),"已解锁" if Profile.level>=2 else "Lv.2 解锁"],Vector2(744,716),18)
	if h.camp_page=="feed": inventory(h)
	elif h.camp_page=="settings": settings(h)
	else: h.call_deferred("focus_control",first)

static func sheet(h: Node, title: String, subtitle: String) -> VBoxContainer:
	var cover := rect(h.hud,Vector2.ZERO,Vector2(1280,800),Color(0.02,0.05,0.09,0.73))
	cover.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel := PanelContainer.new()
	panel.position = Vector2(507,34)
	panel.size = Vector2(735,700)
	panel.add_theme_stylebox_override("panel",style(A.INK,A.FOREST,28))
	h.hud.add_child(panel)
	var c := column(panel,16)
	var head := row(c)
	var label := text(head,title,34)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button(head,"关闭  ×",func(): h.camp_page=""; h.build_ui())
	text(c,subtitle,22,A.DISTANT)
	return c

static func inventory(h: Node) -> void:
	var c := sheet(h,"碎片背包","喂给奶蛙，准备下一次巡游。")
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	c.add_child(scroll)
	var items := column(scroll,10)
	items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var first: Button = null
	for item in Profile.files:
		var id: String = str(item.id)
		var checked: bool = id in h.selected
		var b := button(items,("◆  " if checked else "◇  ")+str(item.name)+"   +%d XP" % item.xp,func(): h.toggle_file(id),checked)
		b.clip_text = true
		b.tooltip_text = "%s · %s" % [item.kind,item.size]
		if first==null: first = b
		if h.ui_focus==id: h.call_deferred("focus_control",b)
	if Profile.files.is_empty(): text(items,"背包空了。去回廊找些新碎片吧。",22)
	var total: int = 0
	for item in Profile.files:
		if str(item.id) in h.selected: total += int(item.xp)
	text(c,"游戏内虚拟文件 · 生命 %d · 攻击 %d" % [Profile.max_health(),Profile.damage()],20,A.DISTANT)
	h.feed_button = button(c,"选好碎片再喂食" if total==0 else "喂食 %d 份    +%d XP   →" % [h.selected.size(),total],h.feed,true)
	h.feed_button.disabled = total==0
	if h.ui_focus.is_empty() and first!=null: h.call_deferred("focus_control",first)

static func settings(h: Node) -> void:
	var c := sheet(h,"操作与设置","出手有节奏，闪避留余地。")
	for line in ["A / D    移动        空格    跳跃","J    连击        K    重击破势","L / Shift    闪避        U    碎片冲击","Tab    补给        Esc    暂停        P    桌宠"]: text(c,line,22)
	text(c,"敌人亮起珊瑚色提示时，先闪避再反击。\n重击能打断守卫；命中积累大招专注。",22,A.DISTANT)
	toggles(h,c)
	var back := button(c,"准备好了    →",func(): h.camp_page=""; h.build_ui(),true)
	h.call_deferred("focus_control",back)

static func toggles(h: Node, c: Node) -> void:
	var r := row(c,28)
	var motion := CheckButton.new()
	motion.text = "减少震动"
	motion.custom_minimum_size.y = 60
	motion.button_pressed = h.reduce_motion
	motion.toggled.connect(func(v: bool): h.reduce_motion=v)
	r.add_child(motion)
	var sound := CheckButton.new()
	sound.text = "音效"
	sound.custom_minimum_size.y = 60
	sound.button_pressed = h.audio_enabled
	sound.toggled.connect(func(v: bool): h.audio_enabled=v)
	r.add_child(sound)

static func battle(h: Node) -> void:
	rect(h.hud,Vector2(24,22),Vector2(330,109),A.INK)
	rect(h.hud,Vector2(24,22),Vector2(4,109),A.GOLD)
	at(h.hud,"奶蛙",Vector2(44,30),24)
	at(h.hud,"Lv.%02d" % Profile.level,Vector2(113,37),18,A.GOLD)
	h.hud_health = at(h.hud,"",Vector2(246,37),18)
	h.hud_hp = bar(h.hud,100,100,A.CREAM,12)
	h.hud_hp.position = Vector2(44,77)
	h.hud_hp.size.x = 288
	h.hud_stamina = bar(h.hud,100,100,A.CYAN,5)
	h.hud_stamina.position = Vector2(44,103)
	h.hud_stamina.size.x = 288
	at(h.hud,"林间回廊",Vector2(564,29),24,A.INK)
	at(h.hud,"第 %02d 节 / 02" % maxi(1,h.wave),Vector2(579,65),18,A.INK)
	action(h.hud,"暂停",Vector2(1028,26),96,h.toggle_pause).focus_mode = Control.FOCUS_NONE
	action(h.hud,"桌宠 ↗",Vector2(1138,26),116,h.return_pet).focus_mode = Control.FOCUS_NONE
	h.hud_boss_text = at(h.hud,"折页守卫",Vector2(445,119),22)
	h.hud_boss_text.size.x = 390
	h.hud_boss_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.hud_boss_text.add_theme_color_override("font_shadow_color",A.INK)
	h.hud_boss_text.add_theme_constant_override("shadow_offset_y",2)
	h.hud_boss = bar(h.hud,510,510,A.DANGER,7)
	h.hud_boss.position = Vector2(445,158)
	h.hud_boss.size.x = 390
	rect(h.hud,Vector2(0,728),Vector2(1280,72),A.INK)
	at(h.hud,"A D  移动   /   空格  跳跃",Vector2(30,743),20)
	at(h.hud,"J  连击    K  重击    L  闪避",Vector2(422,743),20)
	at(h.hud,"U  碎片冲击" if Profile.level>=2 else "U  Lv.2 解锁",Vector2(1010,734),20,A.CYAN)
	h.hud_focus = bar(h.hud,0,100,A.CYAN,6)
	h.hud_focus.position = Vector2(1010,773)
	h.hud_focus.size.x = 240
	if h.over or h.paused: overlay(h)

static func overlay(h: Node) -> void:
	var cover := rect(h.hud,Vector2.ZERO,Vector2(1280,800),Color(0.02,0.05,0.09,0.83))
	cover.mouse_filter = Control.MOUSE_FILTER_STOP
	var c := column(h.hud,15)
	c.position = Vector2(416,190)
	c.size.x = 448
	text(c,"巡游完成" if h.over and h.won else "再来一次" if h.over else "旅途暂停",52)
	text(c,"击破 %d 个目标 · %d 秒" % [h.kills,h.elapsed] if h.over else "留意前摇，闪开后再出手。",22,A.DISTANT)
	var first := button(c,"重新挑战   →" if h.over else "继续巡游   →",h.start_battle if h.over else h.toggle_pause,true)
	h.call_deferred("focus_control",first)
	button(c,"回营地 · 碎片补给",func(): h.camp_page="feed"; h.camp())
	button(c,"返回桌宠",h.return_pet)
	toggles(h,c)
