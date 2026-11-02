extends RefCounted
const PAPER := Color("eee8d8")
const INK := Color("263f3c")
const GOLD := Color("edc879")
const SOFT := Color("a4bcb3")

static func style(color: Color, border: Color = Color.TRANSPARENT, radius: int = 6) -> StyleBoxFlat:
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
	if h.mode=="camp":
		camp(h)
		return
	battle(h)

static func camp(h: Node) -> void:
	var menu: Control=(preload("res://wardrobe/shop.gd") if h.menu_section=="shop" else preload("res://remediation/controls_page.gd") if h.menu_section=="controls" else preload("res://v5/menu.gd")).new()
	menu.host = h
	h.hud.add_child(menu)

static func battle(h: Node) -> void:
	var display := preload("res://v5/battle_hud.gd").new()
	display.host = h
	h.hud.add_child(display)
	h.battle_hud = display
	if h.over or h.paused: overlay(h)

static func ink_button(parent: Node, title: String, action: Callable, h: Node, bold: Font, primary: bool = false, glyph: String = "") -> Button:
	var b:=preload("res://v5/sticker_button.gd").new()
	b.host=h
	b.title=title
	b.title_font=bold
	b.body_font=h.font
	b.primary=primary
	b.glyph=glyph
	b.custom_minimum_size=Vector2(0,65)
	b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	b.pressed.connect(action)
	parent.add_child(b)
	return b

static func overlay(h: Node) -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.045,0.025,0.075,0.82)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.hud.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.hud.add_child(center)
	var p := panel(center,Color("17121f"))
	var frame := style(Color("17121f"),Color("655071"),19)
	frame.set_border_width_all(2)
	frame.set_content_margin_all(28)
	frame.shadow_color=Color("09070e")
	frame.shadow_size=1
	frame.shadow_offset=Vector2(9,10)
	p.add_theme_stylebox_override("panel",frame)
	p.custom_minimum_size.x = 510
	var c := column(p,16)
	text(c,"NAIWA / TAKE A LITTLE BREAK",13,Color("d7ff31"))
	var heading := text(c,(h.current_level().map_title+" · 三段通关") if h.over and h.won else "再试一次" if h.over else "旅途暂停",32,Color("fffef6"))
	var bold := SystemFont.new()
	bold.font_names=h.font.font_names
	bold.font_weight=800
	heading.add_theme_font_override("font",bold)
	text(c,"击破 %d 个目标 · %d 秒" % [h.kills,h.elapsed] if h.over else "歇一下，冒险还在等你。",18,Color("c4b4d0"))
	if h.over and h.won and not h.clear_reward.is_empty():
		if h.clear_reward.get("ok",false):
			text(c,("首通奖励" if h.clear_reward.get("first",false) else "重游奖励")+"  +%d 金币" % int(h.clear_reward.get("amount",0)),19,Color("d7ff31"))
		else:
			text(c,"金币暂未保存，请重试领取。",16,Color("d7ff31"))
			ink_button(c,"重试保存通关奖励",h.retry_clear_reward,h,bold)
	var first := ink_button(c,("重游第一境" if h.level_index==3 else "前往下一境 →") if h.over and h.won else "重新挑战本地图" if h.over else "继续战斗",h.next_level if h.over and h.won else h.retry_map if h.over else h.toggle_pause,h,bold,true,"play")
	h.call_deferred("focus_control",first)
	ink_button(c,"皮肤商城 · %d 金币" % Wardrobe.coins,func(): h.menu_action(h.open_shop),h,bold,false,"shop")
	ink_button(c,"装备工坊 · 金币锻造",func(): h.menu_action(h.open_gear),h,bold,false,"gear")
	ink_button(c,"回营地 · 喂食补给",func(): h.menu_action(h.camp),h,bold,false,"feed")
	ink_button(c,"返回桌宠",func(): h.menu_action(h.return_pet),h,bold,false,"pet")
	var toggles := row(c)
	var motion := CheckButton.new()
	motion.text = "减少震动"
	motion.button_pressed = h.reduce_motion
	motion.add_theme_color_override("font_color",Color("fffef6"))
	motion.add_theme_color_override("font_hover_color",Color("fffef6"))
	motion.add_theme_color_override("font_pressed_color",Color("fffef6"))
	motion.toggled.connect(func(v: bool):
		h.reduce_motion = v
		h.save_menu_settings())
	toggles.add_child(motion)
	var sound := CheckButton.new()
	sound.text = "音效"
	sound.button_pressed = h.audio_enabled
	sound.add_theme_color_override("font_color",Color("fffef6"))
	sound.add_theme_color_override("font_hover_color",Color("fffef6"))
	sound.add_theme_color_override("font_pressed_color",Color("fffef6"))
	sound.toggled.connect(func(v: bool):
		h.audio_enabled = v
		if not v:
			for channel in h.channels: channel.stop()
		h.save_menu_settings())
	toggles.add_child(sound)
	text(c,"Esc 继续    P 桌宠",14,Color("b9a7c8"))
