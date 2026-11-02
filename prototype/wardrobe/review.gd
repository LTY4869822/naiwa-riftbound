extends RefCounted
var lines: Array[String]=[]
var failures:=0

func verify(ok: bool, text: String) -> void:
	lines.append(("PASS " if ok else "FAIL ")+text)
	print(lines[-1])
	if not ok: failures+=1

func button(h: Node, key: String) -> Button:
	return h.hud.find_child(key,true,false) as Button

func settle(h: Node) -> void:
	await h.get_tree().process_frame
	await h.get_tree().process_frame
	await h.get_tree().create_timer(0.08).timeout

func press(h: Node, action: String) -> void:
	for down in [true,false]:
		var event:=InputEventAction.new()
		event.action=action
		event.pressed=down
		h.get_viewport().push_input(event,true)
		await h.get_tree().process_frame

func run(h: Node) -> void:
	if not h.test_mode or Profile.save_enabled or Wardrobe.save_enabled: h.get_tree().quit(1); return
	h.audio_enabled=false
	h.reduce_motion=true
	h.menu_entrance=false
	h.camp()
	await settle(h)
	verify(button(h,"OpenShop")!=null,"home has a skin-shop entry in the existing ink menu")
	await h.capture("shop-home")
	button(h,"OpenShop").pressed.emit()
	await settle(h)
	verify(h.menu_section=="shop" and h.hud.find_child("SkinShop",true,false)!=null,"home entry opens the real shop screen")
	verify(button(h,"ShopFilter_all").has_focus(),"shop starts with a visible keyboard focus")
	verify(button(h,"ShopAcquire").disabled,"current original outfit cannot be purchased again")
	button(h,"Skin_reserved-01").pressed.emit()
	await settle(h)
	verify(button(h,"ShopAcquire").disabled and Wardrobe.coins==0,"a coming-soon item never exposes a charge action")
	for filter in ["growth","coins","owned","all"]:
		button(h,"ShopFilter_"+filter).pressed.emit()
		await settle(h)
		var grid: GridContainer=h.hud.find_child("SkinGrid",true,false)
		verify(grid.get_child_count()==(1 if filter=="owned" else 4 if filter=="all" else 3),filter+" filter shows the corresponding catalogue entries")
	await press(h,"ui_right")
	verify(button(h,"ShopFilter_growth").has_focus(),"keyboard right moves to the growth tab")
	await press(h,"ui_accept")
	await settle(h)
	verify(h.shop_filter=="growth","keyboard confirm switches the filter")
	for dimensions in [Vector2i(1280,800),Vector2i(960,600),Vector2i(1280,720)]:
		h.get_window().size=dimensions
		await settle(h)
		var rect: Rect2=h.get_viewport().get_visible_rect()
		var inside:=true
		for b in h.hud.find_children("*","Button",true,false):
			if b.visible and not rect.has_point(b.get_global_rect().get_center()): inside=false
		verify(inside,"shop actions stay inside viewport at %dx%d" % [dimensions.x,dimensions.y])
		await h.capture("shop-%dx%d" % [dimensions.x,dimensions.y])
	button(h,"ShopEarn").pressed.emit()
	await settle(h)
	verify(h.route_open and not h.playing(),"earn-currency route opens above the shop and blocks combat input")
	verify(h.hud.find_child("LevelRoute",true,false).cards[0].reward_label().contains("120"),"the map displays the available first-clear coin reward")
	h.close_route()
	await settle(h)
	verify(h.menu_section=="shop" and not h.route_open,"closing the route returns to the shop")
	await press(h,"pause")
	await settle(h)
	verify(h.menu_section=="home","Escape returns from the shop to home")
	Wardrobe.reset()
	h.choose_level(0)
	h.finish(false)
	verify(Wardrobe.coins==0 and Wardrobe.clears.is_empty(),"defeat awards no shop currency")
	h.choose_level(0)
	h.finish(true)
	var amount: int=Wardrobe.coins
	h.finish(true)
	verify(amount==120 and Wardrobe.coins==120 and Wardrobe.clears.moss==1,"actual victory hook grants first-clear currency exactly once")
	await settle(h)
	await h.capture("shop-clear-reward")
	h.choose_level(0)
	h.finish(true)
	verify(Wardrobe.coins==150 and Wardrobe.clears.moss==2,"a new run grants the replay amount")
	for index in [1,2,3]:
		h.choose_level(index)
		h.finish(true)
	verify(Wardrobe.coins==870 and Wardrobe.clears.size()==4,"each of the four real levels has its own first-clear reward")
	h.completed_levels.clear()
	h.sync_clear_history()
	verify(h.completed_levels.is_empty(),"first-room clears cannot mark connected maps complete")
	for index in 4:
		Wardrobe.award_clear(str(h.CAMPAIGN.LEVELS[index].id)+"-3",Crypto.new().generate_random_bytes(16).hex_encode())
	h.sync_clear_history()
	verify(h.completed_levels.size()==4,"final-room completion restores all four map badges")
	h.open_route()
	await settle(h)
	verify(h.hud.find_child("LevelRoute",true,false).cards[0].reward_label().contains("30"),"a completed map displays the replay reward instead of a new first-clear bonus")
	await h.capture("shop-reward-route")
	h.close_route()
	h.open_shop()
	await settle(h)
	h.get_window().size=Vector2i(1280,800)
	h.shop_filter="all"
	h.shop_selected="reserved-01"
	h.build_ui()
	await settle(h)
	await h.capture("shop-wallet")
	var fixture: Dictionary={"id":"test-growth-signal","title":"Isolated fixture","original":false,"published":true,"preview":"res://assets/menu-v2/pet/front-idle.png","combat_manifest":"res://assets/v6/side-frames.json","desktop_manifest":"res://assets/menu-v2/pet/original-motion.json","growth":true,"coins":true,"level":3,"bytes":1073741824,"price":100}
	Wardrobe.catalog.append(fixture)
	Profile.level=3
	Profile.recycle_bytes_total=1073741824
	Profile.changed.emit()
	verify(fixture.id in Wardrobe.owned and Wardrobe.coins==2810,"real profile-change signal automatically unlocks growth outfits for free")
	verify(not Profile.save_enabled and not Wardrobe.save_enabled,"UI review never saves the real player or wallet")
	var file:=FileAccess.open("res://artifacts/shop-ui-checks.txt",FileAccess.WRITE)
	file.store_string("\n".join(lines)+"\nFailures=%d\n" % failures)
	print("SHOP_UI_CHECKS ",lines.size()," failures=",failures)
	h.get_tree().quit(failures)
