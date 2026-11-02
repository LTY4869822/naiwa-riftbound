extends "res://v5/menu.gd"
## One visual family with the ink menu; items flow in a GridContainer.
const CARD=preload("res://wardrobe/skin_card.gd")
const CATALOG=preload("res://wardrobe/catalog.gd")
var cards: Array[Button]=[]
var current: Dictionary={}

func build() -> void:
	name="SkinShop"
	current=Wardrobe.skin(host.shop_selected)
	if current.is_empty(): current=Wardrobe.skin(CATALOG.ORIGINAL)
	make_pet(Vector2(99,390),Vector2(282,237))
	pet.custom_minimum_size=Vector2.ZERO
	pet.size=Vector2(282,237)
	var filters: Array=[["all","全部皮肤"],["growth","成长解锁"],["coins","巡游兑换"],["owned","我的衣橱"]]
	for i in filters.size():
		var key: String=filters[i][0]
		var b:=sticker("ShopFilter_"+key,Vector2(444+i*197,218),Vector2(184,57),filters[i][1],"",func(): change_filter(key),PURPLE)
		b.chosen=host.shop_filter==key
	var grid:=GridContainer.new()
	grid.name="SkinGrid"
	grid.columns=2
	grid.position=Vector2(446,294)
	grid.size=Vector2(780,354)
	grid.add_theme_constant_override("h_separation",20)
	grid.add_theme_constant_override("v_separation",18)
	canvas.add_child(grid)
	for item in Wardrobe.catalog:
		var include: bool=host.shop_filter=="all" or host.shop_filter=="owned" and item.id in Wardrobe.owned or host.shop_filter in ["growth","coins"] and item.get(host.shop_filter,false)
		if not include: continue
		var b:=CARD.new()
		b.name="Skin_"+item.id
		b.host=host
		b.item=item
		b.selected=item.id==current.id
		b.title_font=bold
		b.body_font=regular
		b.custom_minimum_size=Vector2(376,166)
		b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		grid.add_child(b)
		buttons.append(b)
		cards.append(b)
		b.pressed.connect(func(): select_skin(item.id))
	sticker("ShopBack",Vector2(58,696),Vector2(165,56),"返回营地","",func(): navigate("home"),INK,"",0,"back")
	sticker("ShopFeedPet",Vector2(236,696),Vector2(171,56),"投喂桌宠","",func(): host.menu_action(host.return_pet),PURPLE,"",0,"pet")
	sticker("ShopEarn",Vector2(751,682),Vector2(211,57),"去巡游攒币","",host.open_route,INK,"",0,"play")
	var state: String=Wardrobe.state(current.id)
	var title: String={"equipped":"正在穿着","owned":"穿上这套","coming_soon":"尚未上架","free":"免费领取","buy":"购买 · %d 币" % int(current.get("price",0)),"insufficient":"金币不足","locked":"成长条件未满足","missing":"尚未上架"}[state]
	var action:=sticker("ShopAcquire",Vector2(980,682),Vector2(247,57),title,"",activate,YELLOW)
	action.disabled=state not in ["owned","free","buy"] or Wardrobe.read_only
	var enabled: Array[Button]=[]
	for b in buttons:
		if not b.disabled: enabled.append(b)
	for i in enabled.size():
		enabled[i].focus_next=enabled[i].get_path_to(enabled[(i+1)%enabled.size()])
		enabled[i].focus_previous=enabled[i].get_path_to(enabled[(i-1+enabled.size())%enabled.size()])
		enabled[i].focus_neighbor_bottom=enabled[i].focus_next
		enabled[i].focus_neighbor_top=enabled[i].focus_previous
	for i in cards.size():
		cards[i].focus_neighbor_left=cards[i].get_path_to(cards[maxi(0,i-1)])
		cards[i].focus_neighbor_right=cards[i].get_path_to(cards[mini(cards.size()-1,i+1)])
	var focus: Button=buttons[0]
	for b in enabled:
		if str(b.name)==host.ui_focus: focus=b
	host.call_deferred("focus_control",focus)
	host.menu_entrance=false

func change_filter(key: String) -> void:
	host.shop_filter=key
	for item in Wardrobe.catalog:
		if key=="all" or key=="owned" and item.id in Wardrobe.owned or key in ["growth","coins"] and item.get(key,false):
			host.shop_selected=item.id
			break
	host.ui_focus="ShopFilter_"+key
	host.build_ui()

func select_skin(id: String) -> void:
	host.shop_selected=id
	host.ui_focus="Skin_"+id
	host.build_ui()

func activate() -> void:
	var state: String=Wardrobe.state(current.id)
	var ok:=false
	if state=="owned": ok=Wardrobe.equip(current.id)
	elif state in ["free","buy"]:
		var result: Dictionary=Wardrobe.acquire(current.id,"growth" if state=="free" else "coins")
		ok=result.ok
	host.ui_focus="ShopAcquire"
	host.build_ui()
	host.toast("衣橱已更新" if ok else Wardrobe.save_error if not Wardrobe.save_error.is_empty() else "尚未满足获取条件")

func paint_profile() -> void:
	panel_at(Rect2(879,30,357,146))
	canvas.draw_circle(Vector2(920,79),23,YELLOW)
	label_at("币",Vector2(905,89),27,INK,true)
	label_at("金币",Vector2(960,64),15,Color("c5afd6"),true)
	label_at(str(Wardrobe.coins),Vector2(956,111),36,YELLOW,true)
	label_at("通关攒币，收藏喜欢的样子。",Vector2(901,153),15,PAPER)

func paint() -> void:
	paint_logo()
	paint_profile()
	outlined("皮肤商城",Vector2(58,247),46)
	label_at("把成长，穿在身上。",Vector2(62,278),17,Color("d9c7e6"))
	panel_at(Rect2(58,304,348,375))
	label_at("当前穿着",Vector2(83,338),15,Color("c5b1d4"),true)
	blob(Vector2(237,627),Vector2(116,23),Color("6931a0"),time_phase())
	label_at("奶蛙 · 原初",Vector2(155,660),22,YELLOW,true)
	label_at("Lv.%02d" % Profile.level,Vector2(303,340),17,YELLOW,true)
	label_at("累计吞噬  "+String.humanize_size(Profile.recycle_bytes_total),Vector2(82,370),15,Color("bcadd0"))
	# The pet occupies the panel; keep every piece of copy outside its face/body.
	panel_at(Rect2(446,660,780,83))
	var state: String=Wardrobe.state(current.id)
	var description: String="外观待公布 · 获取条件待公布"
	if state=="equipped": description="原初奶蛙 · 已拥有，正在穿着。"
	elif state=="owned": description="已经收入衣橱，随时换上。"
	elif state!="coming_soon":
		description="Lv.%d + 吞噬 %s 可免费领取" % [current.level,String.humanize_size(int(current.bytes))]
	label_at(description,Vector2(464,693),14,Color("ded1e8"))
	label_at("成长达标自动解锁  /  通关攒币购买",Vector2(464,722),12,Color("baa5ca"))
	if not Wardrobe.save_error.is_empty(): label_at(Wardrobe.save_error,Vector2(464,758),13,YELLOW)
	elif host.toast_time>0: label_at(host.toast_text,Vector2(464,763),13,YELLOW)
	canvas.draw_rect(Rect2(0,772,1280,28),Color(0.035,0.023,0.06,0.7))
	label_at("↑↓ / Tab 选择    Enter 确认    Esc 返回",Vector2(60,791),13,PAPER)
	label_at("成长免费解锁  +  金币兑换",Vector2(957,791),13,YELLOW,true)
