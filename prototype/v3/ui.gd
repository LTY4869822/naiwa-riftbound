extends RefCounted
const PAPER := Color("eee8d8")
const INK := Color("263f3c")
const GOLD := Color("edc879")
const SOFT := Color("a4bcb3")

static func style(color: Color, border: Color = Color.TRANSPARENT, radius: int = 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(16)
	if border.a>0:
		s.border_color = border
		s.set_border_width_all(1)
	return s

static func text(parent: Node, value: String, size: int = 18, color: Color = PAPER) -> Label:
	var l := Label.new()
	l.text = value
	l.add_theme_color_override("font_color",color)
	l.add_theme_font_size_override("font_size",size)
	parent.add_child(l)
	return l

static func button(parent: Node, title: String, action: Callable, primary: bool = false, light: bool = false) -> Button:
	var b := Button.new()
	b.text = title
	b.custom_minimum_size.y = 48
	b.add_theme_font_size_override("font_size",18)
	var fill: Color = GOLD if primary else Color("dedfce") if light else Color("294b4b")
	b.add_theme_color_override("font_color",INK if primary or light else PAPER)
	b.add_theme_color_override("font_hover_color",INK)
	b.add_theme_color_override("font_pressed_color",INK)
	b.add_theme_color_override("font_focus_color",INK if primary or light else PAPER)
	b.add_theme_color_override("font_disabled_color",Color("88958a"))
	b.add_theme_stylebox_override("normal",style(fill))
	b.add_theme_stylebox_override("hover",style(Color("e6d8af")))
	b.add_theme_stylebox_override("pressed",style(Color("c4d2b5")))
	b.add_theme_stylebox_override("focus",style(Color.TRANSPARENT,GOLD))
	b.add_theme_stylebox_override("disabled",style(Color("d9dccd") if light else Color("29413f")))
	b.pressed.connect(action)
	parent.add_child(b)
	return b

static func bar(parent: Node, value: float, maximum: float, color: Color, height: int = 9) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.max_value = maximum
	b.value = value
	b.custom_minimum_size = Vector2(0,height)
	var empty := style(Color("213c3c"),Color.TRANSPARENT,3)
	empty.set_content_margin_all(0)
	var fill := style(color,Color.TRANSPARENT,3)
	fill.set_content_margin_all(0)
	b.add_theme_stylebox_override("background",empty)
	b.add_theme_stylebox_override("fill",fill)
	parent.add_child(b)
	return b

static func margin(parent: Node, amount: int) -> MarginContainer:
	var m := MarginContainer.new()
	for side in ["left","right","top","bottom"]: m.add_theme_constant_override("margin_"+side,amount)
	parent.add_child(m)
	return m

static func panel(parent: Node, color: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel",style(color))
	parent.add_child(p)
	return p

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

static func spacer(parent: Node) -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(c)
	return c

static func build(h: Node) -> void:
	if h.mode=="desktop": return
	if h.mode=="camp": camp(h)
	else: battle(h)
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size",17)
	l.add_theme_color_override("font_color",GOLD if h.mode=="battle" else Color("d6cfad"))
	l.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	l.offset_top = -119 if h.mode=="battle" else -48
	l.offset_bottom = -85 if h.mode=="battle" else -18
	h.hud.add_child(l)
	h.hud_toast = l

static func camp(h: Node) -> void:
	var bg := ColorRect.new()
	bg.color = Color("163736")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.hud.add_child(bg)
	var m := margin(h.hud,28)
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.add_theme_constant_override("margin_bottom",64)
	var root := column(m,20)
	var header := row(root)
	text(header,"碎片巡游",27)
	text(header,"  /  奶蛙的档案旅程",16,SOFT)
	spacer(header)
	button(header,"返回桌宠  ↗",h.return_pet)
	var content := row(root,24)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var left := panel(content,Color("1f4541"))
	left.custom_minimum_size.x = 375
	var lc := column(left,8)
	var name_row := row(lc)
	text(name_row,"奶蛙",32)
	spacer(name_row)
	text(name_row,"Lv.%02d" % Profile.level,25,GOLD)
	text(lc,"档案旅者 · 出发前补给",16,SOFT)
	var portrait := TextureRect.new()
	portrait.texture = load("res://assets/naiwa/idle.png")
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
	portrait.custom_minimum_size = Vector2(250,280)
	lc.add_child(portrait)
	text(lc,"经验   %d / %d" % [Profile.xp,Profile.needed()],16,GOLD)
	bar(lc,Profile.xp,Profile.needed(),GOLD,6)
	text(lc,"攻击 %d    生命 %d" % [Profile.damage(),Profile.max_health()],17)
	text(lc,"碎片冲击已解锁 · 命中积累专注" if Profile.level>=2 else "Lv.2 解锁碎片冲击",15,SOFT)
	var start := button(lc,"继续战斗   →" if is_instance_valid(h.player) and not h.over else "进入档案遗境   →",h.enter_battle,true)
	h.call_deferred("focus_control",start)
	var right := panel(content,PAPER)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var rc := column(right,14)
	text(rc,"碎片补给",30,INK)
	text(rc,"选择虚拟文件，喂食升级；战斗也能带回新碎片。",17,Color("65786a"))
	var stats := row(rc)
	text(stats,"背包  %02d" % Profile.files.size(),16,INK)
	spacer(stats)
	text(stats,"胜利 %d  ·  喂食 %d" % [Profile.wins,Profile.fed],15,Color("65786a"))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rc.add_child(scroll)
	var items := column(scroll,9)
	items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for item in Profile.files:
		var id: String = str(item.id)
		var b := button(items,("✓  " if id in h.selected else "+  ")+str(item.name)+"     +%d XP" % item.xp,func(): h.toggle_file(id),false,true)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.tooltip_text = "%s · %s · %s" % [item.name,item.size,item.kind]
		if id in h.selected: b.add_theme_stylebox_override("normal",style(Color("cbd8bd"),Color("8ba17e")))
		if h.ui_focus==id: h.call_deferred("focus_control",b)
	if Profile.files.is_empty():
		text(items,"背包空了，去遗境找些新碎片吧。",19,INK)
	var total: int = 0
	for item in Profile.files:
		if str(item.id) in h.selected: total += int(item.xp)
	text(rc,"仅使用游戏内虚拟文件，不读取或删除电脑文件。",14,Color("65786a"))
	h.feed_button = button(rc,"选择碎片后喂食" if total==0 else "喂食 %d 份   ·   +%d XP   →" % [h.selected.size(),total],h.feed,true,true)
	h.feed_button.disabled = total==0
	text(rc,"升级提升攻击与生命；每次喂食还会恢复少量生命。",14,Color("65786a"))

static func battle(h: Node) -> void:
	var top := margin(h.hud,26)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	var r := row(top,20)
	var hero_panel := panel(r,Color(0.06,0.16,0.16,0.94))
	hero_panel.custom_minimum_size.x = 290
	var c := column(hero_panel,7)
	var hr := row(c)
	text(hr,"奶蛙  Lv.%02d" % Profile.level,18,GOLD)
	spacer(hr)
	h.hud_health = text(hr,"",16)
	h.hud_hp = bar(c,100,100,Color("b4d7a0"),11)
	h.hud_stamina = bar(c,100,100,GOLD,4)
	spacer(r)
	var title := column(r,3)
	text(title,"档案遗境",24)
	text(title,"残卷巡卫" if h.wave<2 else "档案守卫",15,SOFT)
	spacer(r)
	button(r,"暂停  Ⅱ",h.toggle_pause).focus_mode = Control.FOCUS_NONE
	button(r,"桌宠  ↗",h.return_pet).focus_mode = Control.FOCUS_NONE
	var boss := VBoxContainer.new()
	boss.position = Vector2(430,111)
	boss.size.x = 420
	h.hud.add_child(boss)
	h.hud_boss_text = text(boss,"档案守卫 · 蓄力时抗轻击",16,Color("eeb49a"))
	h.hud_boss_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.hud_boss = bar(boss,510,510,Color("d58b70"),7)
	var bottom := margin(h.hud,24)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -104
	var br := row(bottom,14)
	var hint := column(br,3)
	text(hint,"A D 移动    空格 跳跃",16)
	text(hint,"Tab 补给    P 返回桌宠",14,SOFT)
	spacer(br)
	for entry in [["J","节奏连击"],["K","重击破势"],["L","闪避 · 耗体力"]]:
		var p := panel(br,Color(0.07,0.17,0.17,0.94))
		var cr := row(p,12)
		text(cr,entry[0],24,GOLD)
		text(cr,entry[1],16)
	var focus := panel(br,Color(0.07,0.17,0.17,0.94))
	focus.custom_minimum_size.x = 186
	var fc := column(focus,5)
	text(fc,"U  碎片冲击" if Profile.level>=2 else "U  Lv.2 解锁",16,GOLD)
	h.hud_focus = bar(fc,0,100,Color("87d2c5"),5)
	if h.over or h.paused: overlay(h)

static func overlay(h: Node) -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.025,0.07,0.075,0.83)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.hud.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.hud.add_child(center)
	var p := panel(center,Color("1c403e"))
	p.custom_minimum_size.x = 420
	var c := column(p,16)
	text(c,"遗境已净化" if h.over and h.won else "再试一次" if h.over else "旅途暂停",38)
	text(c,"击破 %d 个目标 · %d 秒" % [h.kills,h.elapsed] if h.over else "观察前摇，闪开后再出手。",18,SOFT)
	var first := button(c,"重新挑战" if h.over else "继续战斗",h.start_battle if h.over else h.toggle_pause,true)
	h.call_deferred("focus_control",first)
	button(c,"回营地 · 喂食补给",h.camp)
	button(c,"返回原版桌宠",h.return_pet)
	var toggles := row(c)
	var motion := CheckButton.new()
	motion.text = "减少震动"
	motion.button_pressed = h.reduce_motion
	motion.toggled.connect(func(v: bool): h.reduce_motion = v)
	toggles.add_child(motion)
	var sound := CheckButton.new()
	sound.text = "音效"
	sound.button_pressed = h.audio_enabled
	sound.toggled.connect(func(v: bool): h.audio_enabled = v)
	toggles.add_child(sound)
