extends "res://v5/menu.gd"
## Keep the current menu art and pet interactions; this combat slice feeds virtual cards.

func build() -> void:
	super.build()
	if host.menu_section=="home":
		sticker("OpenGear",Vector2(1058,620),Vector2(177,49),"装备工坊","",host.open_gear,PURPLE,"",0,"shop")
	for b in buttons:
		if b.name=="OpenFeed":
			b.title="碎片补给"
			b.subtitle="喂食虚拟碎片，提升巡游等级"
		if b.name=="OpenRecycleHome": b.title="虚拟补给"
		b.tooltip_text=b.title+(" · "+b.subtitle if not b.subtitle.is_empty() else "")

func paint_page() -> void:
	if host.menu_section=="settings":
		super.paint_page()
		return
	outlined("碎片补给" if host.menu_section=="feed" else "成长档案",Vector2(59,263),46)
	label_at("把旅途中拾到的碎片，喂成下一次冒险。",Vector2(62,300),16,Color("dfd2e7"))
	blob(Vector2(290,644),Vector2(158,32),Color(0.25,0.06,0.43,0.9),time_phase())
	label_at("奶蛙  Lv.%02d" % Profile.level,Vector2(182,695),24,YELLOW,true)
	panel_at(Rect2(580,203,654,520))
	if host.menu_section=="feed":
		paint_file_growth()
	else:
		label_at("一点一点，变厉害。",Vector2(610,252),29,PAPER,true)
		var names: Array=["巡游胜利","累计喂食","距离下一级"]
		var values: Array=[str(Profile.wins)+" 次",str(Profile.fed)+" 份虚拟碎片",str(maxi(0,Profile.needed()-Profile.xp))+" XP"]
		for i in 3:
			label_at(names[i],Vector2(612,312+i*53),17,Color("c5b4d5"))
			label_at(values[i],Vector2(970,312+i*53),21,YELLOW,true)
			canvas.draw_line(Vector2(611,328+i*53),Vector2(1198,328+i*53),Color("44344e"),1)
		label_at("U  "+host.SKILL_NAME,Vector2(612,503),24,YELLOW,true)
		label_at("已解锁 · 消耗 60 专注" if Profile.level>=2 else "Lv.2 解锁 · 喂食虚拟碎片即可成长",Vector2(613,538),16)
		label_at("J 连击   K 重击   L / Shift 闪避",Vector2(613,580),16,Color("d2c4dc"))
		label_at("A D 移动   空格 跳跃   Tab 营地",Vector2(613,610),15,Color("bcaacb"))

func paint_file_growth() -> void:
	label_at("挑几份，开饭。",Vector2(612,260),32,PAPER,true)
	label_at("Lv.%02d  ·  %d / %d XP" % [Profile.level,Profile.xp,Profile.needed()],Vector2(614,296),17,Color("c3afd2"))
	var pages: int=maxi(1,ceili(Profile.files.size()/4.0))
	label_at("第 %d / %d 页 · 剩余 %d 份" % [mini(host.menu_scroll+1,pages),pages,Profile.files.size()],Vector2(797,604),15,Color("c3afd2"))
	label_at("卡片均为游戏内虚拟数据，不对应电脑上的真实文件。",Vector2(617,710),13,Color("ada1b9"))
	if Profile.files.is_empty(): label_at("背包空了，去遗境里找些新碎片吧。",Vector2(613,392),20,PAPER,true)

func build_feed() -> void:
	var pages: int=maxi(1,ceili(Profile.files.size()/4.0))
	host.menu_scroll=clampi(host.menu_scroll,0,pages-1)
	var visible_files: Array=Profile.files.slice(host.menu_scroll*4,host.menu_scroll*4+4)
	for i in visible_files.size():
		var item: Dictionary=visible_files[i]
		var id: String=str(item.id)
		var title: String=str(item.name)
		if title.length()>12: title=title.left(11)+"…"
		var b:=sticker(id,Vector2(611+(i%2)*301,325+floori(i/2.0)*122),Vector2(286,105),title,"%s · +%d XP" % [item.size,item.xp],func(): host.toggle_file(id),PURPLE)
		b.large=false
		b.chosen=id in host.selected
		b.tooltip_text=str(item.name)+" · 游戏内虚拟碎片"
	sticker("PreviousCards",Vector2(611,575),Vector2(76,40),"←","",func(): change_page(-1),INK).disabled=host.menu_scroll==0
	sticker("NextCards",Vector2(701,575),Vector2(76,40),"→","",func(): change_page(1),INK).disabled=host.menu_scroll>=pages-1
	var total:=0
	for item in Profile.files:
		if str(item.id) in host.selected: total+=int(item.xp)
	host.feed_button=sticker("FeedSelected",Vector2(611,637),Vector2(595,57),"喂给奶蛙 · +%d XP" % total if total>0 else "先选择几份虚拟碎片","",host.feed,YELLOW,"",0,"feed")
	host.feed_button.disabled=total<=0

func change_page(delta: int) -> void:
	host.menu_scroll+=delta
	host.ui_focus=""
	host.build_ui()
