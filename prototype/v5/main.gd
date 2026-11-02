extends Node2D
const HERO = preload("res://v5/fighter.gd")
const FOE = preload("res://v5/enemy.gd")
const STAGE = preload("res://v5/stage.gd")
const UI = preload("res://v5/ui.gd")
const EFFECTS = preload("res://v5/effects.gd")
const SKILL_NAME:="碎片冲击"
var player: CharacterBody2D
var enemies: Array[Node] = []
var stage: Node2D
var view: Node2D
var hud: Control
var fx_node: Node2D
var enemy_fx: Node2D
var mode: String = "camp"
var prior_mode: String = "camp"
var prior_window_mode: int = DisplayServer.WINDOW_MODE_WINDOWED
var paused: bool = false
var over: bool = false
var won: bool = false
var wave: int = 0
var wait_wave: float = 0
var kills: int = 0
var round_id: int = 0
var elapsed: float = 0
var hitstop: float = 0
var trauma: float = 0
var effect_clock: float = 0
var effects: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []
var spore_field: Node
var boss_fields: Node
const CAMPAIGN = preload("res://campaign/levels.gd")
var level_index: int=0
var completed_levels: Dictionary={}
var route_open: bool=false
const ENCOUNTERS = preload("res://combat/encounters.gd")
var selected: Array[String] = []
var font: SystemFont
var toast_text: String = ""
var toast_time: float = 0
var sounds: Dictionary = {}
var channels: Array[AudioStreamPlayer] = []
var voice_index: int = 0
var battle_hud: Control
var hud_toast: Label
var feed_button: Button
var bridge_dir: String = ""
var owner_pid: int = 0
var bridge_last: String = ""
var bridge_clock: float = 0
var test_mode: bool = false
var reduce_motion: bool = false
var native_path: String
var enemy_sequence: int = 0
var audio_enabled: bool = true
var ui_focus: String = ""
var menu_section: String = "home"
var menu_entrance: bool = true
var menu_scroll: int = 0
var menu_transition: Control
var shop_filter: String="all"
var shop_selected: String="naiwa-original"
var run_reward_id: String=""
var clear_reward: Dictionary={}

func _ready() -> void:
	Engine.max_fps = 60
	get_window().title = "奶蛙 · 碎片巡游"
	get_window().min_size = Vector2i(960,600)
	get_window().transparent = false
	get_window().transparent_bg = false
	get_window().close_requested.connect(quit_game)
	get_window().focus_exited.connect(func():
		if mode=="battle" and not over and not test_mode:
			paused = true
			build_ui())
	var args := OS.get_cmdline_user_args()
	test_mode = "--slice-test" in args or "--slice-visual" in args or "--bridge-check" in args or "--balance-check" in args
	if test_mode: get_window().title = "奶蛙 · 碎片巡游 | 隔离试玩（不保存）"
	for i in range(args.size()-1):
		if args[i]=="--bridge-dir": bridge_dir = args[i+1]
		if args[i]=="--owner-pid": owner_pid = int(args[i+1])
	native_path = ProjectSettings.globalize_path("res://../desktop/lin4run/奶蛙桌宠-联动版.exe")
	if test_mode:
		Profile.save_enabled = false
		Profile.reset_profile()
		Wardrobe.save_enabled=false
		Wardrobe.reset()
	sync_clear_history()
	load_menu_settings()
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei"])
	setup_input()
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(1800,100)
	shape.shape = rectangle
	shape.position = Vector2(640,690)
	floor_body.add_child(shape)
	add_child(floor_body)
	stage = STAGE.new()
	add_child(stage)
	view = stage
	fx_node = EFFECTS.new()
	fx_node.z_index = 10
	fx_node.host = self
	add_child(fx_node)
	enemy_fx=preload("res://foe_vfx/director.gd").new()
	enemy_fx.host=self
	fx_node.add_child(enemy_fx)
	spore_field=preload("res://combat/spore_field.gd").new()
	spore_field.host=self
	add_child(spore_field)
	boss_fields=preload("res://campaign/boss_fields.gd").new()
	boss_fields.host=self
	add_child(boss_fields)
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 18
	hud.theme = theme
	layer.add_child(hud)
	var transition_layer := CanvasLayer.new()
	transition_layer.layer=100
	add_child(transition_layer)
	menu_transition=preload("res://v5/menu_ink_fx.gd").new()
	menu_transition.host=self
	transition_layer.add_child(menu_transition)
	for name in ["attack","hit","heavy","hurt","dash","feed"]:
		sounds[name] = load("res://assets/v2/audio/%s.wav" % name)
	for i in range(10):
		var channel := AudioStreamPlayer.new()
		add_child(channel)
		channels.append(channel)
	Profile.changed.connect(func():
		if mode=="camp": call_deferred("build_ui")
		else: refresh_hud())
	Wardrobe.changed.connect(func():
		sync_clear_history()
		if mode=="camp": call_deferred("build_ui")
		else: refresh_hud())
	Wardrobe.growth_unlocked.connect(func(ids: Array[String]):
		if not ids.is_empty(): toast("新皮肤已解锁 · "+str(Wardrobe.skin(ids[0]).title)))
	Profile.recycle_imported.connect(func(items: int, bytes: int, earned_xp: int, levels: int):
		toast("奶蛙吞下%s · %s" % [String.humanize_size(bytes),"升级啦！Lv.%d" % Profile.level if levels>0 else "成长进度已保存"])
		if mode!="desktop": play_sound("feed",-18,1.0)
		refresh_hud())
	build_ui()
	write_bridge("active")
	if "--foe-vfx-review" in args and test_mode: call_deferred("run_foe_vfx_review")
	elif "--foe-vfx-film" in args and test_mode: call_deferred("run_foe_vfx_film")
	elif "--foe-vfx-lab" in args and test_mode: call_deferred("run_foe_vfx_lab")
	elif "--campaign-review" in args and test_mode: call_deferred("run_campaign_review")
	elif "--campaign-film" in args and test_mode: call_deferred("run_campaign_film")
	elif "--campaign-balance" in args and test_mode: call_deferred("run_campaign_balance")
	elif "--campaign-map" in args and test_mode: call_deferred("open_route")
	elif "--enemy-arena" in args and test_mode: call_deferred("run_enemy_arena")
	elif "--enemy-review" in args and test_mode: call_deferred("run_enemy_review")
	elif "--enemy-film" in args and test_mode: call_deferred("run_enemy_film")
	elif "--hud-film" in args and test_mode: call_deferred("run_hud_film")
	elif "--hud-review" in args and test_mode: call_deferred("run_hud_review")
	elif "--menu-film" in args and test_mode: call_deferred("run_menu_film")
	elif "--menu-review" in args and test_mode: call_deferred("run_menu_review")
	elif "--slice-test" in args: call_deferred("run_checks")
	if "--slice-visual" in args: call_deferred("visual_check")
	if "--balance-check" in args: call_deferred("run_balance_check")

func run_balance_check() -> void:
	await preload("res://v5/balance_check.gd").run(self)

func run_enemy_review() -> void:
	await load("res://combat/enemy_review.gd").run(self)

func run_campaign_review() -> void:
	await load("res://campaign/review.gd").run(self)

func run_foe_vfx_review() -> void:
	await load("res://foe_vfx/review.gd").run(self)

func run_foe_vfx_film() -> void:
	await load("res://foe_vfx/film.gd").run(self)

func run_foe_vfx_lab() -> void:
	var lab:=preload("res://foe_vfx/lab.gd").new()
	lab.host=self
	add_child(lab)

func run_campaign_film() -> void:
	await load("res://campaign/film.gd").run(self)

func run_campaign_balance() -> void:
	await load("res://campaign/balance.gd").run(self)

func current_level() -> Dictionary:
	return CAMPAIGN.get_level(level_index)

func open_route() -> void:
	if mode=="desktop": return
	route_open=true
	if mode=="battle": paused=true
	build_ui()

func close_route() -> void:
	route_open=false
	build_ui()

func choose_level(index: int) -> void:
	level_index=clampi(index,0,CAMPAIGN.LEVELS.size()-1)
	route_open=false
	start_battle()

func next_level() -> void:
	if not over or not won: return
	choose_level((level_index+1)%CAMPAIGN.LEVELS.size())

func run_enemy_arena() -> void:
	Profile.level=3
	start_battle()
	wave=2
	spawn("beetle",730)
	spawn("shaman",1090)
	spawn("raven",920)
	build_ui()
	toast("新敌人试玩 · K 重击破甲，L 闪避冲撞 / 孢爆 / 俯冲")

func run_enemy_film() -> void:
	await load("res://combat/enemy_film.gd").run(self)

func run_menu_review() -> void:
	await preload("res://v5/menu_review.gd").run(self)

func run_menu_film() -> void:
	await load("res://v5/menu_film.gd").run(self)

func run_hud_review() -> void:
	await load("res://v5/hud_review.gd").run(self)

func run_hud_film() -> void:
	await load("res://v5/hud_film.gd").run(self)

func load_menu_settings() -> void:
	if test_mode: return
	var config := ConfigFile.new()
	if config.load("user://menu_settings.cfg") == OK:
		audio_enabled = bool(config.get_value("journey","audio",true))
		reduce_motion = bool(config.get_value("journey","reduce_motion",false))

func save_menu_settings() -> void:
	if test_mode: return
	var config := ConfigFile.new()
	config.set_value("journey","audio",audio_enabled)
	config.set_value("journey","reduce_motion",reduce_motion)
	if config.save("user://menu_settings.cfg") != OK: toast("设置暂未保存，将在当前旅途中生效。")

func menu_action(action: Callable) -> void:
	if is_instance_valid(menu_transition): menu_transition.change(action)
	else: action.call()

func menu_navigate(section: String) -> void:
	menu_action(func():
		menu_section=section
		menu_entrance=true
		ui_focus=""
		menu_scroll=0
		build_ui())

func sync_clear_history() -> void:
	for i in CAMPAIGN.LEVELS.size():
		if int(Wardrobe.clears.get(CAMPAIGN.LEVELS[i].id,0))>0: completed_levels[i]=true

func open_shop() -> void:
	camp()
	menu_section="shop"
	ui_focus=""
	build_ui()

func retry_clear_reward() -> void:
	if not over or not won: return
	clear_reward=Wardrobe.award_clear(current_level().id,run_reward_id)
	build_ui()

func open_recycle_feed() -> void:
	if test_mode:
		toast("隔离试玩：桌宠吞噬入口可用，未打开真实文件处理。")
		return
	if not OS.has_feature("windows"):
		toast("拖文件喂食目前支持Windows桌面版。")
		return
	if mode=="battle" and not paused:
		paused=true
		build_ui()
	if not bridge_dir.is_empty():
		var request:=FileAccess.open(bridge_dir.path_join("desktop-request.txt"),FileAccess.WRITE)
		if request==null:
			toast("未能唤回桌宠，请从托盘图标唤回奶蛙。")
			return
		request.store_string(str(Time.get_ticks_usec())+"|recycle")
		request.close()
	elif FileAccess.file_exists(native_path):
		OS.create_process(native_path,["--feed"])
	else:
		toast("请先启动奶蛙桌宠，再把不需要的文件拖给它。")

func setup_input() -> void:
	var bindings := {"move_left":[KEY_A,KEY_LEFT],"move_right":[KEY_D,KEY_RIGHT],"jump":[KEY_SPACE],"attack":[KEY_J],"heavy":[KEY_K],"dash":[KEY_L,KEY_SHIFT],"skill":[KEY_U],"pause":[KEY_ESCAPE],"camp":[KEY_TAB],"pet":[KEY_P]}
	for action in bindings:
		if not InputMap.has_action(action): InputMap.add_action(action)
		for key in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action,event)

func playing() -> bool:
	return mode=="battle" and not paused and not over and not route_open

func build_ui() -> void:
	for child in hud.get_children():
		hud.remove_child(child)
		child.queue_free()
	battle_hud = null
	hud_toast = null
	feed_button = null
	UI.build(self)
	refresh_hud()
	if route_open:
		var route:=preload("res://campaign/level_select.gd").new()
		route.host=self
		hud.add_child(route)

func focus_control(control) -> void:
	# Feeding can rebuild twice in one frame; a queued focus must ignore removed controls.
	if is_instance_valid(control) and control.is_inside_tree(): control.grab_focus()

func refresh_hud() -> void:
	if is_instance_valid(battle_hud) and is_instance_valid(player):
		var boss: Node = null
		for e in enemies:
			if is_instance_valid(e) and not e.dead and e.boss: boss = e
		battle_hud.set_state({
			"has_player":true,"hp":player.hp,"max_hp":Profile.max_health(),
			"level":Profile.level,"xp":Profile.xp,"needed":Profile.needed(),
			"stamina":player.stamina,"focus":player.focus,"invuln":player.invuln,
			"state":player.state,"combo":player.combo,"elapsed":player.elapsed,
			"dash_cd":player.dash_cd,"dead":player.dead,
			"boss_hp":boss.hp if boss!=null else 0,"boss_max":boss.maximum if boss!=null else 1,
			"boss_id":boss.get_instance_id() if boss!=null else 0,
			"boss_state":boss.state if boss!=null else "","boss_alive":boss!=null,
			"boss_name":preload("res://combat/enemy_catalog.gd").title(boss.kind) if boss!=null else "",
			"boss_enraged":boss.enraged if boss!=null else false,
			"level_title":current_level().title,"level_number":level_index+1,
			"beat_title":current_level().beats[clampi(wave-1,0,current_level().beats.size()-1)],
			"wave_total":CAMPAIGN.wave_count(level_index),
			"kills":kills,"wave":wave,"files":Profile.files.size(),
		})
		battle_hud.set_toast(toast_text if toast_time>0 else "")
	if hud_toast!=null:
		hud_toast.text = toast_text if toast_time>0 else ""

func start_battle() -> void:
	route_open=false
	for e in enemies:
		if is_instance_valid(e): e.queue_free()
	enemies.clear()
	if is_instance_valid(player): player.queue_free()
	stage.reset()
	enemy_fx.clear()
	stage.level_index=level_index
	effects.clear()
	projectiles.clear()
	spore_field.clear()
	boss_fields.clear()
	player = HERO.new()
	player.host = self
	player.position = Vector2(245,640)
	add_child(player)
	player.changed.connect(refresh_hud)
	stage.actor(player,"hero")
	wave = 0
	kills = 0
	enemy_sequence = 0
	round_id = int(Time.get_unix_time_from_system()*1000)
	run_reward_id=Crypto.new().generate_random_bytes(16).hex_encode()
	clear_reward={}
	elapsed = 0
	over = false
	paused = false
	won = false
	wait_wave = 0.65
	mode = "battle"
	build_ui()
	toast("第 %d 关 · %s    %s" % [level_index+1,current_level().title,current_level().hint])

func spawn(kind: String, x: float) -> Node:
	var e := FOE.new()
	e.host = self
	e.kind = kind
	enemy_sequence += 1
	e.eid = enemy_sequence
	e.position = Vector2(x,640)
	if kind=="raven": e.position.y=600
	add_child(e)
	enemies.append(e)
	e.changed.connect(refresh_hud)
	stage.actor(e,kind)
	return e

func next_wave() -> void:
	wave += 1
	ENCOUNTERS.spawn_wave(self)

func attack_budget(actor: Node) -> bool:
	var count: int = 0
	for e in enemies:
		if is_instance_valid(e) and not e.dead and e!=actor and e.state in ["tell","active"]: count += 1
	return count<(1 if actor.kind in ["ranged","shaman"] else 2)

func resolve_attack(actor: Node) -> void:
	for e in enemies:
		if not is_instance_valid(e) or e.dead or e.eid in actor.hit_ids: continue
		if actor.attackbox().intersects(e.hurtbox()):
			actor.hit_ids.append(e.eid)
			var damage: int = int(Profile.damage()*[0.80,0.95,1.55][actor.combo])
			var prior_hp: int=e.hp
			e.take_hit(damage,actor.facing,actor.combo==2)
			damage=prior_hp-e.hp
			actor.focus = minf(100,actor.focus+12)
			var hand: Vector2=stage.hand_position(actor)
			var body: Rect2=e.hurtbox()
			var point := Vector2(clampf(hand.x,body.position.x+12,body.end.x-12),clampf(hand.y,body.position.y+24,body.end.y-24))
			impact(point,actor.facing,actor.combo==2)
			float_number(point+Vector2(0,-24),str(damage),Color("ffe0a0"))
			play_sound("heavy" if actor.combo==2 else "hit",-17 if actor.combo==2 else -20,randf_range(0.94,1.07))
			refresh_hud()

func skill_burst() -> void:
	fx("ring",player.position+Vector2(0,-55),player.facing,0.45)
	for e in enemies:
		if is_instance_valid(e) and not e.dead and absf(e.position.x-player.position.x)<310:
			e.take_hit(Profile.damage()*2,int(signf(e.position.x-player.position.x)),true)
	hitstop = 0.075
	trauma = 0.6
	play_sound("heavy",-16,0.75)
	refresh_hud()

func shoot(origin: Vector2, target: Vector2, facing: int, owner_id: int=0) -> void:
	var direction := (target-origin).normalized()
	if absf(direction.x)<0.5: direction = Vector2(facing,0)
	projectiles.append({"pos":origin,"velocity":direction*350,"life":4.0,"owner":owner_id,"enemy_vfx":true})
	fx("muzzle",origin,facing,0.25)

func enemy_down(e: Node) -> void:
	kills += 1
	enemy_fx.cancel(e.eid)
	spore_field.cancel(e.eid)
	boss_fields.cancel(e.eid)
	Profile.award_enemy(round_id,e.eid,e.boss)
	fx("death",e.position+Vector2(0,-100),1,0.5)
	float_number(e.position+Vector2(0,-170),"+碎片",Color("a3d9c5"))
	refresh_hud()

func finish(win: bool) -> void:
	if over: return
	over = true
	enemy_fx.clear()
	spore_field.clear()
	boss_fields.clear()
	projectiles.clear()
	won = win
	if win:
		completed_levels[level_index]=true
		clear_reward=Wardrobe.award_clear(current_level().id,run_reward_id)
		Profile.wins += 1
		Profile.add_file(current_level().title+"的档案匣.dat",75,"守关奖励")
	else: Profile.defeats += 1
	Profile.save_profile()
	build_ui()

func camp() -> void:
	mode = "camp"
	paused = false
	menu_section = "home"
	menu_entrance = true
	ui_focus = ""
	build_ui()

func enter_battle() -> void:
	if over and won: next_level()
	elif not is_instance_valid(player) or over: start_battle()
	else:
		mode = "battle"
		paused = false
		build_ui()

func toggle_pause() -> void:
	if mode!="battle" or over: return
	paused = not paused
	build_ui()

func toggle_file(id: String) -> void:
	ui_focus = id
	if id in selected: selected.erase(id)
	else: selected.append(id)
	build_ui()

func feed() -> void:
	var result: Dictionary = Profile.feed(selected.duplicate())
	selected.clear()
	if int(result.count)>0:
		play_sound("feed",-17,1)
		if is_instance_valid(player): player.hp = mini(Profile.max_health(),player.hp+int(result.count)*8)
		toast("吞下 %d 份虚拟碎片 · +%d XP%s" % [result.count,result.xp," · 升到 Lv.%d" % Profile.level if result.levels>0 else ""])
	build_ui()

func _unhandled_input(event: InputEvent) -> void:
	if route_open:
		if event.is_action_pressed("pause"):
			close_route()
			get_viewport().set_input_as_handled()
		return
	if is_instance_valid(menu_transition) and menu_transition.busy:
		get_viewport().set_input_as_handled()
		return
	if mode=="camp" and event.is_action_pressed("pause"):
		if menu_section!="home":
			menu_navigate("home")
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause"): toggle_pause()
	if event.is_action_pressed("camp"):
		if mode=="camp": enter_battle()
		else: camp()
	if event.is_action_pressed("pet"): return_pet()

func toast(text: String) -> void:
	toast_text = text
	toast_time = 4.5
	refresh_hud()

func play_sound(name: String, volume: float = -20, pitch: float = 1.0) -> void:
	if not audio_enabled or channels.is_empty(): return
	var channel: AudioStreamPlayer = channels[voice_index%channels.size()]
	voice_index += 1
	channel.stream = sounds[name]
	channel.volume_db = volume
	channel.pitch_scale = pitch
	channel.play()

func fx(type: String, point: Vector2, facing: int = 1, duration: float = 0.25) -> void:
	if is_instance_valid(enemy_fx) and enemy_fx.legacy(type,point,facing): return
	effects.append({"type":type,"pos":point,"facing":facing,"life":duration,"max":duration})

func dust(point: Vector2) -> void:
	fx("dust",point,1,0.3)

func float_number(point: Vector2, text: String, color: Color) -> void:
	effects.append({"type":"text","pos":point,"text":text,"color":color,"life":0.8,"max":0.8})

func impact(point: Vector2, facing: int, heavy: bool, hurt: bool = false) -> void:
	effects.append({"type":"hit","pos":point,"facing":facing,"heavy":heavy,"hurt":hurt,"life":0.24,"max":0.24})
	hitstop = maxf(hitstop,0.070 if heavy else 0.035)
	trauma = minf(1,trauma+(0.50 if heavy else 0.23))

func _process(dt: float) -> void:
	bridge_clock += dt
	if bridge_clock>0.12:
		bridge_clock = 0
		poll_bridge()
	if mode=="desktop": return
	toast_time = maxf(0,toast_time-dt)
	if is_instance_valid(battle_hud): battle_hud.set_toast(toast_text if toast_time>0 else "")
	elif hud_toast!=null: hud_toast.text=toast_text if toast_time>0 else ""
	if not playing():
		if mode=="camp": view.visible = false
		return
	view.visible = true
	elapsed += dt
	effect_clock += dt
	hitstop = maxf(0,hitstop-dt)
	trauma = maxf(0,trauma-dt*2.3)
	var shake: float = 0 if reduce_motion else trauma*trauma*9
	view.position = Vector2(sin(effect_clock*43),cos(effect_clock*37))*shake
	fx_node.position = view.position
	for i in range(effects.size()-1,-1,-1):
		effects[i].life -= dt
		if effects[i].type=="text": effects[i].pos.y -= 38*dt
		if effects[i].life<=0: effects.remove_at(i)
	if hitstop<=0:
		for i in range(projectiles.size()-1,-1,-1):
			var p: Dictionary = projectiles[i]
			p.pos += p.velocity*dt
			p.life -= dt
			var hit: bool = is_instance_valid(player) and player.hurtbox().has_point(p.pos)
			if hit:
				var accepted: bool=player.take_hit(17,int(signf(p.velocity.x)))
				if accepted and not over: enemy_fx.projectile_contact(p)
			if over: break
			if hit or p.life<=0 or p.pos.x<0 or p.pos.x>1280: projectiles.remove_at(i)
	var living: int = 0
	for e in enemies:
		if is_instance_valid(e) and not e.dead: living += 1
	if living==0:
		wait_wave -= dt
		if wait_wave<=0:
			if wave>=CAMPAIGN.wave_count(level_index): finish(true)
			else:
				wait_wave = 1.3
				next_wave()
	fx_node.queue_redraw()

func write_bridge(value: String) -> void:
	if bridge_dir.is_empty(): return
	var file := FileAccess.open(bridge_dir.path_join("state"),FileAccess.WRITE)
	if file!=null: file.store_string(value)

func poll_bridge() -> void:
	if bridge_dir.is_empty(): return
	var heartbeat: String = bridge_dir.path_join("owner-alive")
	if FileAccess.file_exists(heartbeat) and Time.get_unix_time_from_system()-FileAccess.get_modified_time(heartbeat)>8:
		print("BRIDGE_OWNER_TIMEOUT")
		quit_game()
		return
	var path: String = bridge_dir.path_join("command.txt")
	if not FileAccess.file_exists(path): return
	var command := FileAccess.get_file_as_string(path).strip_edges()
	if command==bridge_last or command.find("|")<0: return
	bridge_last = command
	print("BRIDGE_COMMAND ",command)
	match command.get_slice("|",1):
		"resume":
			mode = prior_mode if mode=="desktop" else mode
			DisplayServer.window_set_mode(prior_window_mode)
			get_window().grab_focus()
			Engine.max_fps = 60
			write_bridge("active")
			build_ui()
		"pet": return_pet()
		"quit": quit_game()

func return_pet() -> void:
	print("BRIDGE_RETURN ",bridge_dir)
	Profile.save_profile()
	if bridge_dir.is_empty():
		if FileAccess.file_exists(native_path): OS.create_process(native_path,[])
		get_tree().quit()
		return
	if mode!="desktop":
		prior_mode = mode
		var current_window_mode := DisplayServer.window_get_mode()
		if current_window_mode!=DisplayServer.WINDOW_MODE_MINIMIZED: prior_window_mode = current_window_mode
	mode = "desktop"
	write_bridge("pet")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	print("BRIDGE_HIDDEN")
	Engine.max_fps = 15
	for channel in channels: channel.stop()

func quit_game() -> void:
	Profile.save_profile()
	write_bridge("closed")
	get_tree().quit()

func run_checks() -> void:
	var checks: Array[String] = []
	var failed: int = 0
	start_battle()
	await get_tree().physics_frame
	await get_tree().physics_frame
	paused = true
	player.set_physics_process(false)
	var e: Node = spawn("melee",player.position.x+110)
	e.set_physics_process(false)
	player.attack(0)
	var before: int = e.hp
	player.elapsed = 0.05
	# Resolution must be driven only inside the active interval.
	player.step(0.01)
	checks.append("PASS startup has no damage" if e.hp==before else "FAIL startup has no damage")
	player.elapsed = 0.14
	player.step(0.01)
	var hit_hp: int = e.hp
	checks.append("PASS active hit connects" if hit_hp<before else "FAIL active hit connects")
	player.step(0.01)
	checks.append("PASS one hit per target per move" if e.hp==hit_hp else "FAIL one hit per target per move")
	player.stamina = 100
	player.state = "idle"
	player.dash()
	var health: int = player.hp
	player.take_hit(18,1)
	checks.append("PASS dash invulnerability and stamina cost" if player.hp==health and player.stamina==68 else "FAIL dash invulnerability and stamina cost")
	player.invuln = 0
	player.take_hit(18,1)
	checks.append("PASS hit interrupts attack and damages" if player.state=="hurt" and player.hp==health-18 else "FAIL hit interrupts attack and damages")
	player.state = "idle"
	player.elapsed = 0
	player.buffered = 0
	Input.action_press("attack")
	player.step(0.01)
	checks.append("PASS holding attack alone does not auto chain" if player.state=="idle" else "FAIL holding attack alone does not auto chain")
	Input.action_release("attack")
	var rig: Node = stage.actors[player.get_instance_id()]
	var worst_ground := 0.0
	var worst_face := 0.0
	var worst_slide := 0.0
	var contact_samples := 0
	rig.position=Vector2(245,640)
	rig.initialized=false
	rig.phase=0
	for i in range(180):
		stage.position=Vector2(sin(i*0.37)*4,cos(i*0.21)*2)
		rig.position.x+=175.0/60
		rig.drive(1.0/60,"run",0,1,175,640)
		if not rig.planted_points.is_empty(): contact_samples+=1
		worst_ground=maxf(worst_ground,rig.ground_error)
		worst_face=maxf(worst_face,rig.face_rigidity_error)
		worst_slide=maxf(worst_slide,rig.slide_error)
	checks.append("PASS planted foot grounded" if worst_ground<0.5 and contact_samples==180 else "FAIL planted foot grounded %.3f contacts=%d" % [worst_ground,contact_samples])
	checks.append("PASS face retains shape" if worst_face<0.001 else "FAIL face retains shape %.4f" % worst_face)
	checks.append("PASS stance foot does not skate" if worst_slide<0.5 else "FAIL stance foot does not skate %.3f" % worst_slide)
	for i in range(25): rig.drive(1.0/60,"idle",0,1,0,640)
	checks.append("PASS stop settles before restoring original" if rig.settling==0 else "FAIL stop settles before restoring original")
	stage.position=Vector2.ZERO
	rig.position.y=540
	rig.drive(1.0/60,"attack0",0.4,1,0,640)
	checks.append("PASS airborne attack does not pin feet to ground" if rig.planted_points.is_empty() and rig.legs[1].foot.global_position.y<590 else "FAIL airborne attack does not pin feet to ground")
	rig.position=player.position
	print("MOTION_METRICS ground=",worst_ground," slide=",worst_slide," face=",worst_face)
	var boss: Node = spawn("boss",900)
	boss.set_physics_process(false)
	boss.begin_attack()
	boss.take_hit(1,1,false)
	checks.append("PASS boss armor resists light stun" if boss.state=="tell" else "FAIL boss armor resists light stun")
	boss.take_hit(1,1,true)
	checks.append("PASS heavy attack breaks boss stance" if boss.state=="stunned" else "FAIL heavy attack breaks boss stance")
	var p_before: int = projectiles.size()
	shoot(Vector2(1000,520),Vector2(250,520),-1)
	checks.append("PASS ranged projectile spawned" if projectiles.size()==p_before+1 else "FAIL ranged projectile spawned")
	camp()
	selected = [str(Profile.files[0].id),str(Profile.files[1].id)]
	feed()
	await get_tree().process_frame
	await get_tree().process_frame
	checks.append("PASS feeding unlocks level two with valid UI focus" if Profile.level==2 and Profile.xp==20 else "FAIL feeding unlocks level two with valid UI focus")
	player.position=Vector2(245,640)
	player.velocity=Vector2.ZERO
	player.state="idle"
	player.focus=100
	player.skill()
	player.step(0.10)
	checks.append("PASS ultimate waits for casting pose" if player.state=="skill" and not player.skill_fired and player.focus==40 else "FAIL ultimate waits for casting pose")
	player.step(0.17)
	var rings_before: int=effects.filter(func(item): return item.type=="ring").size()
	player.step(0.03)
	checks.append("PASS ultimate fires exactly once" if player.skill_fired and rings_before==1 and effects.filter(func(item): return item.type=="ring").size()==1 else "FAIL ultimate fires exactly once")
	checks.append("PASS tests cannot write player save" if not Profile.save_enabled else "FAIL tests cannot write player save")
	for line in checks:
		if line.begins_with("FAIL"): failed += 1
	var file := FileAccess.open("res://artifacts/v5-checks.txt",FileAccess.WRITE)
	file.store_string("\n".join(checks)+"\nFailures=%d\n" % failed)
	print("V5_CHECKS ",checks.size()," failures=",failed)
	get_tree().quit(failed)

func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://artifacts/"+name+".png")

func visual_check() -> void:
	Profile.level=3
	build_ui()
	await get_tree().create_timer(0.4).timeout
	await capture("v5-camp")
	start_battle()
	player.invuln=100
	await get_tree().create_timer(0.9).timeout
	Input.action_press("move_right")
	await get_tree().create_timer(0.45).timeout
	await capture("v5-run")
	Input.action_release("move_right")
	await get_tree().create_timer(0.12).timeout
	await capture("v5-stop")
	player.position.x=520
	await get_tree().create_timer(0.3).timeout
	await capture("v5-battle")
	player.attack(0)
	await get_tree().create_timer(0.20).timeout
	await capture("v5-jab")
	await get_tree().create_timer(0.6).timeout
	player.attack(2)
	await get_tree().create_timer(0.30).timeout
	await capture("v5-heavy")
	await get_tree().create_timer(0.6).timeout
	player.focus=100
	player.skill()
	await get_tree().create_timer(0.36).timeout
	await capture("v5-skill")
	await get_tree().create_timer(0.5).timeout
	player.invuln=0
	player.take_hit(18,-1)
	await get_tree().create_timer(0.12).timeout
	await capture("v5-hurt")
	for e in enemies:
		if is_instance_valid(e):
			stage.remove_actor(e)
			e.queue_free()
	enemies.clear()
	player.position=Vector2(610,640)
	player.invuln=100
	player.state="idle"
	wave=2
	var boss: Node=spawn("boss",940)
	boss.cooldown=10
	spawn("ranged",1160)
	build_ui()
	await get_tree().create_timer(0.3).timeout
	await capture("v5-boss")
	camp()
	selected=[str(Profile.files[0].id),str(Profile.files[1].id)]
	feed()
	await get_tree().create_timer(0.2).timeout
	await capture("v5-feed")
	get_tree().quit()
