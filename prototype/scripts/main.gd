extends Node2D

const FIGHTER = preload("res://scripts/fighter.gd")
const ENEMY = preload("res://scripts/enemy.gd")
const PRESENTATION = preload("res://scripts/presentation.gd")
const FX = preload("res://scripts/fx.gd")
const INK := Color("102733")
const MUTED := Color("8fa6ab")
const CREAM := Color("f7eedb")
const GOLD := Color("edc16a")
const MINT := Color("a4cbb7")
var mode: String = "camp"
var previous_mode: String = "camp"
var player: CharacterBody2D
var arena: Node2D
var ui: Control
var layer: CanvasLayer
var font: SystemFont
var enemies: Array[Node] = []
var selected: Array[String] = []
var effects: Array[Dictionary] = []
var numbers: Array[Dictionary] = []
var idle: Texture2D = preload("res://assets/naiwa/idle.png")
var looks: Array[Texture2D] = []
var blinks: Array[Texture2D] = []
var laughs: Array[Texture2D] = []
var sounds: Dictionary = {}
var voice: AudioStreamPlayer
var clock: float = 0
var laugh_time: float = 0
var poke_time: float = 0
var toast_time: float = 0
var toast_text: String = ""
var toast_label: Label
var level_label: Label
var xp_bar: ProgressBar
var hp_bar: ProgressBar
var hp_label: Label
var wave_label: Label
var skill_label: Label
var kills_label: Label
var feed_button: Button
var file_buttons: Dictionary = {}
var wave: int = 0
var kills: int = 0
var round_id: int = 0
var enemy_id: int = 0
var wave_wait: float = 0
var round_time: float = 0
var battle_started: bool = false
var battle_over: bool = false
var paused: bool = false
var hitstop: float = 0
var shake: float = 0
var damage_flash: float = 0
var last_level: int = 1
var saved_window_size := Vector2i(1152,720)
var saved_window_pos := Vector2i(100,100)
var pet_position := Vector2i(-9999,-9999)
var dragging: bool = false
var drag_mouse := Vector2i.ZERO
var drag_window := Vector2i.ZERO
var smoke_mode: bool = false
var failure_count: int = 0
var test_lines: Array[String] = []
var background: Texture2D = preload("res://assets/v2/archive-background.png")
var fx_layer: Node2D
var pet_menu: PopupMenu
var boss_bar: ProgressBar
var boss_label: Label
var last_win: bool = false
var combo_hits: int = 0
var combo_life: float = 0
var impact_flash: float = 0
var wave_banner: float = 0
var voices: Array[AudioStreamPlayer] = []
var voice_index: int = 0
var pet_mask := PackedVector2Array()

func _ready() -> void:
	Engine.max_fps = 60
	smoke_mode = "--smoke-test" in OS.get_cmdline_user_args()
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei","Noto Sans CJK SC"])
	setup_input()
	for i in range(11):
		looks.append(load("res://assets/naiwa/look_%02d.png" % i))
	for i in range(7):
		blinks.append(load("res://assets/naiwa/blink_0_%02d.png" % i))
	for i in range(0,90,5):
		laughs.append(load("res://assets/naiwa/laugh_%04d.png" % i))
	for key in ["attack","hit","feed","heavy","hurt","dash"]:
		sounds[key] = load("res://assets/v2/audio/%s.wav" % key)
	voice = AudioStreamPlayer.new()
	voice.volume_db = -16
	add_child(voice)
	for i in range(8):
		var channel := AudioStreamPlayer.new()
		channel.volume_db = -17
		add_child(channel)
		voices.append(channel)
	build_arena()
	fx_layer = FX.new()
	fx_layer.host = self
	add_child(fx_layer)
	layer = CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 18
	ui.theme = theme
	layer.add_child(ui)
	last_level = Profile.level
	Profile.changed.connect(on_profile_changed)
	build_ui()
	get_window().title = "奶蛙 · 碎片巡游 | 本地可玩原型"
	get_window().min_size = Vector2i(960,600)
	pet_menu = PopupMenu.new()
	pet_menu.name = "PetActions"
	pet_menu.add_item("奶蛙 · Lv.%d" % Profile.level,90)
	pet_menu.set_item_disabled(0,true)
	pet_menu.add_separator()
	pet_menu.add_item("进入战斗",0)
	pet_menu.add_item("营地喂食",1)
	pet_menu.add_item("返回主界面",2)
	pet_menu.add_separator()
	pet_menu.add_item("退出奶蛙",3)
	pet_menu.id_pressed.connect(func(id: int):
		pet_menu.hide()
		match id:
			0: enter_battle()
			1: switch_mode("camp")
			2: switch_mode(previous_mode)
			3:
				Profile.save_profile()
				get_tree().quit()
	)
	add_child(pet_menu)
	var mask_data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/v2/pet-mask.json"))
	for point in mask_data:
		pet_mask.append(Vector2(point[0],point[1]))
	if smoke_mode:
		call_deferred("run_smoke_test")
	if "--visual-check" in OS.get_cmdline_user_args():
		call_deferred("run_visual_check")
	if "--pet-check" in OS.get_cmdline_user_args() or "--desktop" in OS.get_cmdline_user_args():
		call_deferred("switch_mode","pet")

func setup_input() -> void:
	var bindings := {"move_left":[KEY_A,KEY_LEFT],"move_right":[KEY_D,KEY_RIGHT],"jump":[KEY_SPACE,KEY_K],"attack":[KEY_J],"dash":[KEY_L,KEY_SHIFT],"skill":[KEY_U],"pause":[KEY_ESCAPE],"camp":[KEY_TAB],"pet":[KEY_P]}
	for action in bindings:
		InputMap.add_action(action)
		for key in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action,event)

func build_arena() -> void:
	arena = Node2D.new()
	add_child(arena)
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(1800,100)
	shape.shape = rect
	shape.position = Vector2(640,690)
	floor_body.add_child(shape)
	arena.add_child(floor_body)
	arena.visible = false

func style(color: Color, radius: int = 14, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	if border.a>0:
		box.border_color = border
		box.set_border_width_all(1)
	box.content_margin_left = 16
	box.content_margin_right = 16
	return box

func label_at(text: String, pos: Vector2, size_px: int = 18, color: Color = CREAM, width: float = 0) -> Label:
	var item := Label.new()
	item.text = text
	item.position = pos
	item.add_theme_font_size_override("font_size",size_px)
	item.add_theme_color_override("font_color",color)
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if width>0:
		item.size.x = width
	ui.add_child(item)
	return item

func button_at(text: String, rect: Rect2, callback: Callable, primary: bool = false) -> Button:
	var item := Button.new()
	item.text = text
	item.position = rect.position
	item.size = rect.size
	var paper: bool = mode=="camp"
	item.add_theme_font_size_override("font_size",18)
	item.add_theme_color_override("font_color",CREAM if primary and paper else INK if paper or primary else CREAM)
	item.add_theme_color_override("font_hover_color",CREAM if primary and paper else INK)
	item.add_theme_color_override("font_pressed_color",CREAM if primary and paper else INK)
	item.add_theme_color_override("font_disabled_color",Color("697b7d"))
	item.add_theme_stylebox_override("normal",style(Color("344d3b") if primary and paper else Color("e3e1d5") if paper else GOLD if primary else Color(0.05,0.09,0.1,0.68),5))
	item.add_theme_stylebox_override("hover",style(Color("496449") if primary and paper else Color("d4ddca") if paper else Color("ead4ac"),5))
	item.add_theme_stylebox_override("pressed",style(Color("283e2e") if primary and paper else MINT,5))
	item.add_theme_stylebox_override("disabled",style(Color("dbddd0") if paper else Color("263a43"),5))
	item.add_theme_stylebox_override("focus",style(Color(0,0,0,0),5,GOLD))
	item.pressed.connect(callback)
	ui.add_child(item)
	return item

func panel_at(rect: Rect2, color: Color, radius: int = 16) -> Panel:
	var item := Panel.new()
	item.position = rect.position
	item.size = rect.size
	item.add_theme_stylebox_override("panel",style(color,radius))
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(item)
	return item

func progress_at(rect: Rect2, color: Color, maximum: float) -> ProgressBar:
	var item := ProgressBar.new()
	item.position = rect.position
	item.size = rect.size
	item.max_value = maximum
	item.show_percentage = false
	item.add_theme_stylebox_override("background",style(Color("233d46"),5))
	item.add_theme_stylebox_override("fill",style(color,5))
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(item)
	item.size = rect.size
	return item

func clear_ui() -> void:
	for child in ui.get_children():
		ui.remove_child(child)
		child.queue_free()
	file_buttons.clear()
	level_label = null
	xp_bar = null
	hp_bar = null
	toast_label = null
	feed_button = null
	boss_bar = null
	boss_label = null

func build_ui() -> void:
	clear_ui()
	if mode == "pet":
		build_pet_ui()
		return
	PRESENTATION.build(self)

func build_camp_ui() -> void:
	PRESENTATION.camp(self)

func set_file_card(id: String) -> void:
	if not file_buttons.has(id):
		return
	var item: Dictionary = {}
	for f in Profile.files:
		if f["id"] == id:
			item = f
	if item.is_empty():
		return
	var b: Button = file_buttons[id]
	var picked: bool = id in selected
	b.text = ("✓   " if picked else "+   ")+str(item["name"])+"    /    "+str(item["size"])+"    ·    +%d XP" % item["xp"]
	b.add_theme_stylebox_override("normal",style(Color("d7dfce") if picked else Color("e8e5da"),4,Color("83977b") if picked else Color("deded0")))
	b.add_theme_color_override("font_color",Color("344334"))

func toggle_file(id: String) -> void:
	if id in selected:
		selected.erase(id)
	else:
		selected.append(id)
	set_file_card(id)
	update_feed_button()

func toggle_all() -> void:
	if selected.size()==Profile.files.size():
		selected.clear()
	else:
		selected.clear()
		for i in range(Profile.files.size()):
			selected.append(str(Profile.files[i]["id"]))
	for id in file_buttons:
		set_file_card(str(id))
	update_feed_button()

func update_feed_button() -> void:
	if feed_button==null:
		return
	var total: int = 0
	for file in Profile.files:
		if str(file["id"]) in selected:
			total += int(file["xp"])
	feed_button.text = "选好碎片，喂给奶蛙" if total==0 else "喂食 %d 份碎片    +%d XP  ↗" % [selected.size(),total]
	feed_button.disabled = total==0

func feed_selected() -> void:
	var result: Dictionary = Profile.feed(selected.duplicate())
	selected.clear()
	if int(result["count"])==0:
		return
	laugh_time = 2.4
	play_sfx("feed")
	build_ui()
	toast("吞下 %d 份碎片，获得 %d XP%s" % [result["count"],result["xp"]," · Lv.%d！解锁碎片冲击（U）" % Profile.level if result["levels"]>0 and Profile.level==2 else " · 升级了！" if result["levels"]>0 else ""])
	for i in range(20):
		burst(Vector2(230,430),GOLD,1)

func build_battle_ui() -> void:
	PRESENTATION.battle(self)

func build_pet_ui() -> void:
	# The pet has no permanent HUD or toolbar. Right-click opens native actions.
	pass

func refresh_stats() -> void:
	if level_label!=null:
		level_label.text = "Lv.%02d" % Profile.level
	if xp_bar!=null:
		xp_bar.max_value = Profile.needed()
		xp_bar.value = Profile.xp

func on_profile_changed() -> void:
	if player!=null and is_instance_valid(player) and Profile.level>last_level:
		player.hp = mini(Profile.max_health(),player.hp+(Profile.level-last_level)*12)
		toast("Lv.%d！攻击提升%s" % [Profile.level," · U 解锁碎片冲击" if Profile.level==2 else ""])
	last_level = Profile.level
	if level_label!=null:
		level_label.text = "Lv.%02d" % Profile.level
	if xp_bar!=null:
		xp_bar.max_value = Profile.needed()
		xp_bar.value = Profile.xp

func enter_battle() -> void:
	if not battle_started or battle_over:
		start_battle()
	else:
		switch_mode("battle")

func start_battle() -> void:
	for e in enemies:
		if is_instance_valid(e):
			e.queue_free()
	enemies.clear()
	if player!=null and is_instance_valid(player):
		player.queue_free()
	player = FIGHTER.new()
	player.host = self
	arena.add_child(player)
	player.position = Vector2(240,640)
	wave = 0
	kills = 0
	enemy_id = 0
	round_id = int(Time.get_unix_time_from_system()*1000)
	round_time = 0
	battle_started = true
	battle_over = false
	paused = false
	combo_hits = 0
	combo_life = 0
	wave_wait = 0.5
	effects.clear()
	numbers.clear()
	switch_mode("battle")
	toast("击退三波损坏数据，把碎片带回营地！")

func spawn_wave() -> void:
	wave += 1
	wave_banner = 1.5
	var count: int = 3 if wave==1 else 4 if wave==2 else 3
	for i in range(count):
		spawn_enemy(Vector2(810+i*117,640),wave==3 and i==1)
	toast("第 %d / 3 波%s" % [wave," · 缓存聚合体出现" if wave==3 else " · 损坏数据接入"])

func spawn_enemy(pos: Vector2, is_boss: bool = false) -> Node:
	var e := ENEMY.new()
	e.host = self
	e.boss = is_boss
	enemy_id += 1
	e.eid = enemy_id
	e.position = pos
	arena.add_child(e)
	enemies.append(e)
	return e

func melee_hit(actor: CharacterBody2D, step: int) -> void:
	var connected: bool = false
	for e in enemies:
		if not is_instance_valid(e) or e.dead:
			continue
		var dx: float = e.position.x-actor.position.x
		if dx*actor.facing > -28 and dx*actor.facing < 150+step*20 and absf(e.position.y-actor.position.y)<145:
			e.take_hit(Profile.damage()+(8 if step==2 else 0),actor.facing*(410+step*65))
			connected = true
			combo_hits += 1
			combo_life = 2.2
			impact(e.position+Vector2(0,-95 if e.boss else -50),actor.facing,step==2,GOLD)
	if connected:
		hitstop = maxf(hitstop,0.052 if step<2 else 0.095)
		shake = maxf(shake,3.5 if step<2 else 7)
		impact_flash = 0.025 if step==2 else 0.0
		play_sfx("heavy" if step==2 else "hit")

func shockwave(pos: Vector2) -> void:
	effects.append({"type":"ring","pos":pos,"life":0.55,"max":0.55})
	for e in enemies:
		if is_instance_valid(e) and not e.dead and absf(e.position.x-pos.x)<330:
			e.take_hit(Profile.damage()*3,signf(e.position.x-pos.x)*650)
	shake = 8
	impact_flash = 0.045
	play_sfx("heavy")
	toast("碎片冲击！")

func on_enemy_down(e: Node) -> void:
	kills += 1
	Profile.award_enemy(round_id,e.eid,e.boss)
	burst(e.position+Vector2(0,-35),GOLD,25 if e.boss else 14)
	float_text(e.position+Vector2(0,-95),"+碎片  +XP",MINT)
	impact(e.position+Vector2(0,-50),1,e.boss,GOLD)

func finish_battle(win: bool) -> void:
	if battle_over:
		return
	battle_over = true
	last_win = win
	if win:
		Profile.wins += 1
		Profile.add_file("通关补给.dat",65,"通关奖励")
	else:
		Profile.defeats += 1
	Profile.save_profile()
	build_ui()

func switch_mode(next_mode: String) -> void:
	if next_mode=="battle" and (not battle_started or battle_over):
		start_battle()
		return
	if mode=="pet" and next_mode!="pet":
		Engine.max_fps = 60
		pet_position = get_window().position
		dragging = false
		get_window().mouse_passthrough_polygon = PackedVector2Array()
		get_window().always_on_top = false
		get_window().unresizable = false
		get_window().borderless = false
		# Keep the native alpha-capable window alive; normal scenes paint opaque.
		get_window().transparent_bg = true
		get_window().transparent = true
		get_window().content_scale_size = Vector2i(1280,800)
		get_window().min_size = Vector2i(960,600)
		get_window().size = saved_window_size
		get_window().position = saved_window_pos
	if next_mode=="pet" and mode!="pet":
		Engine.max_fps = 30
		previous_mode = mode
		saved_window_size = get_window().size
		saved_window_pos = get_window().position
		get_window().mode = Window.MODE_WINDOWED
		get_window().min_size = Vector2i(240,320)
		get_window().size = Vector2i(240,320)
		get_window().content_scale_size = Vector2i(240,320)
		get_window().borderless = true
		get_window().unresizable = true
		get_window().transparent = true
		get_window().transparent_bg = true
		get_window().always_on_top = true
		var area: Rect2i = DisplayServer.screen_get_usable_rect(get_window().current_screen)
		if pet_position.x == -9999:
			pet_position = area.end-Vector2i(265,345)
		pet_position = Vector2i(clampi(pet_position.x,area.position.x,area.end.x-240),clampi(pet_position.y,area.position.y,area.end.y-320))
		get_window().position = pet_position
		get_window().mouse_passthrough_polygon = pet_mask
	mode = next_mode
	arena.visible = mode=="battle"
	build_ui()
	queue_redraw()

func toggle_pause() -> void:
	if mode=="pet":
		switch_mode("camp")
	elif mode=="battle" and not battle_over:
		paused = not paused
		build_ui()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		toggle_pause()
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("camp"):
		if mode=="camp" and battle_started and not battle_over:
			switch_mode("battle")
		else:
			switch_mode("camp")
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("pet") and mode!="pet":
		switch_mode("pet")
		get_viewport().set_input_as_handled()
	if mode=="pet" and event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed and event.position.y>5 and event.position.y<315:
			dragging = true
			drag_mouse = DisplayServer.mouse_get_position()
			drag_window = get_window().position
			if event.double_click:
				laugh_time = 2.8
				play_sfx("feed")
			else:
				poke_time = 0.55
		elif not event.pressed:
			dragging = false
	if mode=="pet" and event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:
		dragging = false
		pet_menu.set_item_text(0,"奶蛙 · Lv.%d" % Profile.level)
		pet_menu.position = DisplayServer.mouse_get_position()
		pet_menu.popup()

func _process(delta: float) -> void:
	clock += delta
	laugh_time = maxf(0,laugh_time-delta)
	poke_time = maxf(0,poke_time-delta)
	toast_time = maxf(0,toast_time-delta)
	combo_life = maxf(0,combo_life-delta)
	if combo_life<=0:
		combo_hits = 0
	impact_flash = maxf(0,impact_flash-delta)
	wave_banner = maxf(0,wave_banner-delta)
	if toast_label!=null:
		toast_label.text = toast_text if toast_time>0 else ""
	if mode=="pet" and dragging:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			var desired := drag_window+DisplayServer.mouse_get_position()-drag_mouse
			var work: Rect2i = DisplayServer.screen_get_usable_rect(get_window().current_screen)
			get_window().position = Vector2i(clampi(desired.x,work.position.x,work.end.x-240),clampi(desired.y,work.position.y,work.end.y-320))
		else:
			dragging = false
	for effect in effects:
		effect["life"] -= delta
		if effect["type"]=="particle":
			effect["pos"] += effect["velocity"]*delta
			effect["velocity"].y += delta*500
	for n in numbers:
		n["life"] -= delta
		n["pos"].y -= delta*35
	effects = effects.filter(func(e): return e["life"]>0)
	numbers = numbers.filter(func(n): return n["life"]>0)
	if mode=="battle" and player!=null:
		hp_bar.max_value = Profile.max_health()
		hp_bar.value = player.hp
		hp_label.text = "%d / %d" % [player.hp,Profile.max_health()]
		wave_label.text = "第 %02d / 03 波" % maxi(1,wave)
		kills_label.text = "击破  %02d" % kills
		skill_label.text = "碎片冲击" if Profile.level<2 else "碎片冲击 · 就绪" if player.skill_cd<=0 else "冲击 · %.1fs" % player.skill_cd
		if boss_bar!=null:
			var active_boss: Node = null
			for e in enemies:
				if is_instance_valid(e) and not e.dead and e.boss:
					active_boss = e
			boss_bar.visible = active_boss!=null
			boss_label.visible = active_boss!=null
			if active_boss!=null:
				boss_bar.max_value = active_boss.maximum
				boss_bar.value = active_boss.hp
		if not battle_over and not paused:
			hitstop = maxf(0,hitstop-delta)
			round_time += delta
			enemies = enemies.filter(func(e): return is_instance_valid(e) and not e.dead)
			if enemies.is_empty():
				wave_wait -= delta
				if wave_wait<=0:
					if wave>=3:
						finish_battle(true)
					else:
						spawn_wave()
						wave_wait = 1.4
	shake = maxf(0,shake-delta*23)
	damage_flash = maxf(0,damage_flash-delta)
	arena.position = Vector2(sin(clock*61)*shake,cos(clock*53)*shake*0.5) if mode=="battle" else Vector2.ZERO
	queue_redraw()

func current_pet_texture() -> Texture2D:
	if laugh_time>0:
		return laughs[clampi(int((2.8-laugh_time)*6),0,laughs.size()-1)]
	var blink_clock: float = fmod(clock,5.3)
	if blink_clock<0.23:
		return blinks[mini(6,int(blink_clock*30))]
	if mode=="pet":
		var x: float = DisplayServer.mouse_get_position().x-get_window().position.x
		return looks[clampi(int(x/240*10),0,10)]
	return idle

func _draw() -> void:
	if font==null:
		return
	if mode=="pet":
		var bounce: float = sin(poke_time*15)*poke_time*9
		draw_texture_rect(current_pet_texture(),Rect2(0,4+bounce,240,307),false)
		return
	draw_rect(Rect2(0,0,1280,800),Color("0e2027"))
	if mode=="camp":
		draw_texture_rect(background,Rect2(0,0,1280,800),false)
		draw_rect(Rect2(0,0,466,800),Color(0.035,0.075,0.065,0.78))
		draw_rect(Rect2(466,0,814,800),Color("f1ebdf"))
		draw_line(Vector2(466,0),Vector2(466,800),Color("aaa589"),1)
		draw_line(Vector2(46,101),Vector2(410,101),Color("5b6655"),1)
		draw_set_transform(Vector2(230,555),0,Vector2(1,0.15))
		draw_circle(Vector2.ZERO,70,Color(0.02,0.03,0.03,0.45))
		draw_set_transform(Vector2.ZERO)
		draw_texture_rect(current_pet_texture(),Rect2(105,268+sin(clock*2)*2,240,307),false)
	else:
		draw_battle_background()

func draw_battle_background() -> void:
	var offset := Vector2(sin(clock*61)*shake*0.25,cos(clock*53)*shake*0.1)
	draw_texture_rect(background,Rect2(offset+Vector2(0,48),Vector2(1280,800)),false)
	for i in range(26):
		var x: float = fposmod(i*71+clock*7,1280)
		var y: float = 190+fposmod(i*73-clock*9,380)
		draw_circle(Vector2(x,y),1.2,Color(1,0.8,0.45,0.15+sin(clock+i)*0.1))
	for i in range(14):
		draw_rect(Rect2(0,674+i*9,1280,10),Color(0.015,0.035,0.035,float(i)/14*0.82))
	draw_rect(Rect2(0,0,1280,87),Color(0.02,0.04,0.04,0.33))

func burst(pos: Vector2, color: Color, count: int) -> void:
	for i in range(count):
		effects.append({"type":"particle","pos":pos,"velocity":Vector2(randf_range(-150,150),randf_range(-220,-30)),"life":0.6,"max":0.6,"color":color,"size":randf_range(2,5)})

func slash_effect(pos: Vector2, facing: int, step: int) -> void:
	effects.append({"type":"slash","pos":pos+Vector2(facing*20,-86),"facing":facing,"angle":[-0.18,0.25,-0.4][step],"strong":step==2,"life":0.23,"max":0.23})
	if step==2:
		ghost(pos-Vector2(facing*25,0),facing,player.sprite.sprite_frames.get_frame_texture(player.sprite.animation,player.sprite.frame))

func enemy_slash(pos: Vector2, facing: int, boss: bool) -> void:
	effects.append({"type":"enemy_slash","pos":pos+Vector2(facing*20,-65),"facing":facing,"angle":0.25,"strong":boss,"life":0.23,"max":0.23})
	if boss:
		dust(pos)

func impact(pos: Vector2, facing: int, strong: bool, color: Color) -> void:
	effects.append({"type":"impact","pos":pos,"facing":facing,"strong":strong,"color":color,"seed":randf()*TAU,"life":0.27,"max":0.27})

func dust(pos: Vector2) -> void:
	effects.append({"type":"dust","pos":pos,"life":0.32,"max":0.32})

func ghost(pos: Vector2, facing: int, texture: Texture2D = null) -> void:
	effects.append({"type":"ghost","pos":pos,"facing":facing,"texture":texture if texture!=null else preload("res://assets/v2/hero/idle.png"),"life":0.22,"max":0.22})

func float_text(pos: Vector2, text: String, color: Color) -> void:
	numbers.append({"pos":pos,"text":text,"color":color,"life":0.8})

func toast(text: String) -> void:
	toast_text = text
	toast_time = 4.0
	if toast_label!=null:
		toast_label.text = text

func play_sfx(key: String) -> void:
	if sounds.has(key) and not voices.is_empty():
		var channel: AudioStreamPlayer = voices[voice_index%voices.size()]
		voice_index += 1
		channel.stream = sounds[key]
		channel.pitch_scale = randf_range(0.92,1.08) if key!="feed" else 1.0
		channel.play()

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST:
		Profile.save_profile()
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT and mode=="battle" and battle_started and not battle_over:
		paused = true
		build_ui()

func check(condition: bool, text: String) -> void:
	test_lines.append(("PASS " if condition else "FAIL ")+text)
	print(test_lines[-1])
	if not condition:
		failure_count += 1

func run_smoke_test() -> void:
	Profile.reset_profile()
	var ids: Array[String] = [str(Profile.files[0]["id"]),str(Profile.files[1]["id"])]
	var result: Dictionary = Profile.feed(ids)
	check(result["xp"]==80 and Profile.level==2 and Profile.xp==20,"feed gives exact XP, levels up and carries remainder")
	check(Profile.feed(ids)["count"]==0 and Profile.xp==20,"duplicate feed cannot repeat reward")
	check(Profile.damage()==31 and Profile.max_health()==112,"level changes combat stats")
	check(not Profile.valid_data({"level":"broken"}),"invalid profile is rejected")
	start_battle()
	await get_tree().create_timer(0.7).timeout
	paused = false
	check(wave==1 and enemies.size()==3,"round spawns first enemy wave")
	var start_x: float = player.position.x
	var key := InputEventKey.new()
	key.physical_keycode = KEY_D
	key.pressed = true
	Input.parse_input_event(key)
	await get_tree().create_timer(0.16).timeout
	key = InputEventKey.new()
	key.physical_keycode = KEY_D
	key.pressed = false
	Input.parse_input_event(key)
	check(player.position.x>start_x+20,"D key binding moves actual physics character")
	check(player.sprite.animation=="run" and player.sprite.frame>0,"movement advances real running animation frames")
	key = InputEventKey.new()
	key.physical_keycode = KEY_SPACE
	key.pressed = true
	Input.parse_input_event(key)
	await get_tree().create_timer(0.12).timeout
	key = InputEventKey.new()
	key.physical_keycode = KEY_SPACE
	key.pressed = false
	Input.parse_input_event(key)
	check(player.position.y<620,"space key binding triggers jump")
	var target: Node = enemies[0]
	target.position = player.position+Vector2(90,0)
	player.facing = 1
	var health_before: int = target.hp
	target.cooldown = 5
	player.attack()
	await get_tree().create_timer(0.03).timeout
	check(target.hp==health_before,"attack windup does not deal premature damage")
	await get_tree().create_timer(0.15).timeout
	check(target.hp<health_before,"melee range produces actual enemy damage")
	check(player.sprite.animation.begins_with("attack"),"attack damage is driven alongside attack animation")
	player.skill()
	check(player.skill_cd>0,"Lv.2 unlocks skill with cooldown")
	player.invuln = 0
	player.take_hit(1,1)
	await get_tree().create_timer(0.08).timeout
	check(player.sprite.animation=="hurt" and player.hurt_timer>0,"taking damage interrupts attack and selects hurt frames")
	var same_player: Node = player
	var same_level: int = Profile.level
	switch_mode("camp")
	await get_tree().process_frame
	check(player==same_player and not arena.visible,"camp pauses and preserves existing fight")
	switch_mode("pet")
	await get_tree().process_frame
	if DisplayServer.get_name()=="headless":
		check(mode=="pet","headless mode switches to pet logic")
	else:
		check(mode=="pet" and get_window().borderless and get_window().always_on_top,"desktop mode uses actual borderless topmost window")
	check(ui.get_child_count()==0,"pet has no permanent status bar, frame or toolbar")
	check(get_window().transparent_bg and ProjectSettings.get_setting("display/window/size/transparent"),"pet alpha is enabled from project startup and viewport")
	pet_menu.id_pressed.emit(1)
	check(mode=="camp","pet native menu opens feeding camp")
	switch_mode("pet")
	switch_mode("battle")
	check(player==same_player and Profile.level==same_level and arena.visible,"return restores same fighter and progression")
	paused = false
	for step in range(4):
		for e in enemies.duplicate():
			if is_instance_valid(e) and not e.dead:
				e.take_hit(999,0)
		await get_tree().create_timer(1.65).timeout
	check(battle_over and Profile.wins==1 and wave==3,"three waves resolve into victory and reward")
	check(Profile.files.size()>1,"enemy kills return virtual feeding loot")
	start_battle()
	player.invuln = 0
	player.take_hit(999,1)
	check(battle_over and Profile.defeats==1,"defeat resolves and supports restart")
	var report_name: String = "smoke-headless.txt" if DisplayServer.get_name()=="headless" else "smoke-test.txt"
	var report := FileAccess.open("res://artifacts/"+report_name,FileAccess.WRITE)
	if report!=null:
		report.store_string("\n".join(test_lines))
		report.close()
	print("SMOKE_FAILURES=",failure_count)
	get_tree().quit(0 if failure_count==0 else 1)

func capture_frame(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)

func run_visual_check() -> void:
	Profile.reset_profile()
	await get_tree().create_timer(0.8).timeout
	await capture_frame("res://artifacts/camp-v2.png")
	Profile.add_xp(80)
	start_battle()
	await get_tree().create_timer(0.7).timeout
	paused = false
	var key := InputEventKey.new()
	key.physical_keycode = KEY_D
	key.pressed = true
	Input.parse_input_event(key)
	await get_tree().create_timer(0.16).timeout
	await capture_frame("res://artifacts/run-v2.png")
	key = InputEventKey.new()
	key.physical_keycode = KEY_D
	key.pressed = false
	Input.parse_input_event(key)
	var target: Node = spawn_enemy(player.position+Vector2(125,0))
	target.cooldown = 5
	spawn_enemy(Vector2(1070,640),true)
	wave = 3
	wave_banner = 0
	toast_time = 0
	player.combo = 1
	player.last_attack = player.clock
	player.facing = 1
	player.attack()
	await get_tree().create_timer(0.2).timeout
	await capture_frame("res://artifacts/battle-v2.png")
	await get_tree().create_timer(0.6).timeout
	player.invuln = 0
	player.take_hit(9,1)
	await get_tree().create_timer(0.13).timeout
	await capture_frame("res://artifacts/hurt-v2.png")
	switch_mode("pet")
	await get_tree().create_timer(0.8).timeout
	await capture_frame("res://artifacts/pet-v2.png")
	switch_mode("camp")
	get_tree().quit()
