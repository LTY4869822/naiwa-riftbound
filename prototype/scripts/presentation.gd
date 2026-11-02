extends RefCounted

const PAPER := Color("f1ebdf")
const INK := Color("28362f")
const SOFT := Color("6c7867")
const GOLD := Color("dfb673")
const WHITE := Color("f6efdd")

static func build(h: Node) -> void:
	if h.mode=="camp":
		camp(h)
	else:
		battle(h)
	h.toast_label = h.label_at(h.toast_text if h.toast_time>0 else "",Vector2(290,654),16,Color("f4d9a2"),700)
	h.toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if h.mode=="camp":
		h.toast_label.position = Vector2(500,674)
		h.toast_label.add_theme_color_override("font_color",Color("65775c"))
	h.refresh_stats()

static func camp(h: Node) -> void:
	h.label_at("碎片巡游",Vector2(44,30),22,WHITE)
	h.label_at("FRAGMENT JOURNEY  /  FIELD NOTES 01",Vector2(46,66),10,Color("9eaaa2"))
	h.label_at("奶蛙",Vector2(42,116),58,WHITE)
	h.label_at("档案旅者  /  NAIWA",Vector2(46,194),13,GOLD)
	h.label_at("每一份被遗忘的碎片，\n都会成为下一次出发的力量。",Vector2(46,250),18,Color("b6bfb0"))
	h.level_label = h.label_at("Lv.%02d" % Profile.level,Vector2(44,568),38,WHITE)
	h.label_at("攻击 %d   /   生命 %d" % [Profile.damage(),Profile.max_health()],Vector2(47,625),16,GOLD)
	h.label_at("%d / %d XP" % [Profile.xp,Profile.needed()],Vector2(47,664),13,Color("abb7a8"))
	h.xp_bar = h.progress_at(Rect2(46,695,365,5),GOLD,Profile.needed())
	h.xp_bar.value = Profile.xp
	h.button_at("继续探索   ↗" if h.battle_started and not h.battle_over else "进入档案遗境   ↗",Rect2(44,727,367,46),h.enter_battle,true)
	h.label_at("营地  /  碎片补给",Vector2(514,35),15,SOFT)
	h.button_at("桌面陪伴  ↗",Rect2(1066,24,168,42),func(): h.switch_mode("pet"))
	h.label_at("碎片补给",Vector2(510,112),38,INK)
	h.label_at("把虚拟文件喂给奶蛙，积累经验，带着新能力回到战场。",Vector2(513,174),16,SOFT)
	h.label_at("背包   %02d" % Profile.files.size(),Vector2(513,224),14,INK)
	h.button_at("全选 / 取消",Rect2(1080,210,153,37),h.toggle_all)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(510,264)
	scroll.size = Vector2(722,390)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	h.ui.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation",9)
	scroll.add_child(rows)
	for i in range(Profile.files.size()):
		var item: Dictionary = Profile.files[i]
		var id: String = str(item["id"])
		var b: Button = h.button_at("",Rect2(0,0,722,55),func(): h.toggle_file(id))
		h.ui.remove_child(b)
		b.custom_minimum_size = Vector2(0,55)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rows.add_child(b)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size",16)
		b.tooltip_text = "模拟碎片 · 点击选择；不会操作真实文件"
		h.file_buttons[id] = b
		h.set_file_card(id)
	if Profile.files.is_empty():
		h.label_at("补给已经吃光了。",Vector2(547,362),26,INK)
		h.label_at("前往遗境击败损坏档案，就能带回新的碎片。",Vector2(547,410),17,SOFT)
	h.feed_button = h.button_at("",Rect2(510,711,722,54),h.feed_selected,true)
	h.label_at("虚拟文件模式  ·  %d 次喂食 / %d 次胜利" % [Profile.fed,Profile.wins],Vector2(512,776),12,SOFT)
	h.update_feed_button()

static func battle(h: Node) -> void:
	h.label_at("档案遗境",Vector2(41,29),20,WHITE)
	h.label_at("THE FORGOTTEN CONSERVATORY",Vector2(42,61),10,Color("a1b3ac"))
	h.wave_label = h.label_at("",Vector2(485,28),18,WHITE,310)
	h.wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.kills_label = h.label_at("",Vector2(1050,31),17,GOLD)
	h.button_at("Ⅱ",Rect2(1190,22,48,44),h.toggle_pause)
	# Corner HUD keeps the central action space free. Text remains code-native.
	h.panel_at(Rect2(28,699,346,81),Color(0.035,0.075,0.08,0.86),6)
	h.level_label = h.label_at("Lv.%02d" % Profile.level,Vector2(44,708),15,GOLD)
	h.hp_label = h.label_at("",Vector2(195,708),15,WHITE)
	h.hp_bar = h.progress_at(Rect2(44,742,310,10),Color("9db7a1"),Profile.max_health())
	h.xp_bar = h.progress_at(Rect2(44,763,310,3),GOLD,Profile.needed())
	h.xp_bar.value = Profile.xp
	var names := ["近身连击","瞬步","碎片冲击"]
	var keys := ["J","L","U"]
	for i in range(3):
		var x: float = 627+i*205
		h.panel_at(Rect2(x,709,190,66),Color(0.035,0.075,0.08,0.86),5)
		h.label_at(keys[i],Vector2(x+15,721),26,GOLD)
		var title: Label = h.label_at(names[i],Vector2(x+57,723),15,WHITE)
		if i==2:
			h.skill_label = title
		h.label_at("三段 / 持续按键" if i==0 else "闪避 / 无敌" if i==1 else "Lv.2 解锁" if Profile.level<2 else "范围冲击",Vector2(x+57,749),11,Color("a1b3ac"))
	h.label_at("A D 移动   空格 跳跃   Tab 补给   P 桌宠",Vector2(407,780),11,Color("a9b5aa"))
	h.boss_label = h.label_at("档案守卫  /  THE WARDEN",Vector2(390,86),13,Color("e9b3a0"),500)
	h.boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.boss_bar = h.progress_at(Rect2(390,113,500,5),Color("d88876"),280)
	h.boss_label.visible = false
	h.boss_bar.visible = false
	if h.paused and not h.battle_over:
		pause(h)
	elif h.battle_over:
		result(h)

static func pause(h: Node) -> void:
	h.panel_at(Rect2(0,0,1280,800),Color(0.01,0.025,0.03,0.63),0)
	h.label_at("暂停探索",Vector2(492,255),42,WHITE)
	h.label_at("奶蛙在这里等你。",Vector2(519,320),18,Color("afbaae"))
	h.button_at("继续",Rect2(450,390,380,54),h.toggle_pause,true)
	h.button_at("回营地补给",Rect2(450,460,380,49),func(): h.switch_mode("camp"))
	h.button_at("桌面陪伴",Rect2(450,522,380,49),func(): h.switch_mode("pet"))

static func result(h: Node) -> void:
	h.panel_at(Rect2(0,0,1280,800),Color(0.01,0.025,0.03,0.71),0)
	h.label_at("探索完成" if h.last_win else "暂别遗境",Vector2(464,242),48,WHITE)
	h.label_at("击破 %d 个目标  ·  %d 秒  ·  成长已保存" % [h.kills,int(h.round_time)],Vector2(430,325),18,GOLD)
	h.label_at("带回的每一片碎片，都会成为新的力量。",Vector2(429,369),18,Color("aebbad"))
	h.button_at("返回营地 · 喂食",Rect2(430,439,420,57),func(): h.switch_mode("camp"),true)
	h.button_at("再次探索",Rect2(430,515,420,49),h.start_battle)
