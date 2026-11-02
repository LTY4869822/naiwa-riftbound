extends Node2D
const HERO = preload("res://v4/fighter.gd")
const FOE = preload("res://v4/enemy.gd")
const STAGE = preload("res://v4/stage.gd")
const UI = preload("res://v4/ui.gd")
const EFFECTS = preload("res://v4/effects.gd")
var player: CharacterBody2D
var enemies: Array[Node] = []
var stage: Node3D
var viewport3d: SubViewport
var view: TextureRect
var hud: Control
var fx_node: Node2D
var mode: String = "camp"
var prior_mode: String = "camp"
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
var selected: Array[String] = []
var font: SystemFont
var toast_text: String = ""
var toast_time: float = 0
var sounds: Dictionary = {}
var channels: Array[AudioStreamPlayer] = []
var voice_index: int = 0
var hud_hp: ProgressBar
var hud_stamina: ProgressBar
var hud_focus: ProgressBar
var hud_health: Label
var hud_boss: ProgressBar
var hud_boss_text: Label
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
var camp_page: String = ""

func _ready() -> void:
	Engine.max_fps = 60
	get_window().title = "奶蛙 · 碎片巡游"
	get_window().min_size = Vector2i(960,600)
	get_window().transparent = false
	get_window().transparent_bg = false
	get_window().close_requested.connect(quit_game)
	get_window().focus_exited.connect(func():
		if mode=="battle" and not over:
			paused = true
			build_ui())
	var args := OS.get_cmdline_user_args()
	test_mode = "--slice-test" in args or "--slice-visual" in args or "--bridge-check" in args or "--balance-check" in args
	if test_mode: get_window().title = "奶蛙 · 碎片巡游 | 隔离试玩（不保存）"
	for i in range(args.size()-1):
		if args[i]=="--bridge-dir": bridge_dir = args[i+1]
		if args[i]=="--owner-pid": owner_pid = int(args[i+1])
	native_path = ProjectSettings.globalize_path("res://../desktop/奶蛙桌宠.exe")
	if test_mode:
		Profile.save_enabled = false
		Profile.reset_profile()
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
	viewport3d = SubViewport.new()
	viewport3d.size = Vector2i(1280,800)
	viewport3d.own_world_3d = true
	viewport3d.msaa_3d = Viewport.MSAA_2X
	viewport3d.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport3d)
	stage = STAGE.new()
	viewport3d.add_child(stage)
	view = TextureRect.new()
	view.texture = viewport3d.get_texture()
	view.size = Vector2(1280,800)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(view)
	fx_node = EFFECTS.new()
	fx_node.z_index = 10
	fx_node.host = self
	add_child(fx_node)
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 22
	hud.theme = theme
	layer.add_child(hud)
	for name in ["attack","hit","heavy","hurt","dash","feed"]:
		sounds[name] = load("res://assets/v2/audio/%s.wav" % name)
	for i in range(10):
		var channel := AudioStreamPlayer.new()
		add_child(channel)
		channels.append(channel)
	Profile.changed.connect(func():
		if mode=="camp": call_deferred("build_ui"))
	build_ui()
	write_bridge("active")
	if "--slice-test" in args: call_deferred("run_checks")
	if "--slice-visual" in args: call_deferred("visual_check")
	if "--balance-check" in args: call_deferred("run_balance_check")

func run_balance_check() -> void:
	await preload("res://v4/balance_check.gd").run(self)

func setup_input() -> void:
	var bindings := {"move_left":[KEY_A,KEY_LEFT],"move_right":[KEY_D,KEY_RIGHT],"jump":[KEY_SPACE],"attack":[KEY_J],"heavy":[KEY_K],"dash":[KEY_L,KEY_SHIFT],"skill":[KEY_U],"pause":[KEY_ESCAPE],"camp":[KEY_TAB],"pet":[KEY_P]}
	for action in bindings:
		if not InputMap.has_action(action): InputMap.add_action(action)
		for key in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action,event)

func playing() -> bool:
	return mode=="battle" and not paused and not over

func build_ui() -> void:
	stage.set_battle_visible(mode=="battle")
	view.visible = mode!="desktop"
	for child in hud.get_children():
		hud.remove_child(child)
		child.queue_free()
	hud_hp = null
	hud_stamina = null
	hud_focus = null
	hud_health = null
	hud_boss = null
	hud_boss_text = null
	feed_button = null
	UI.build(self)
	refresh_hud()

func focus_control(control) -> void:
	# Feeding can rebuild twice in one frame; a queued focus must ignore removed controls.
	if is_instance_valid(control) and control.is_inside_tree(): control.grab_focus()

func refresh_hud() -> void:
	if hud_hp!=null and is_instance_valid(player):
		hud_hp.max_value = Profile.max_health()
		hud_hp.value = player.hp
		hud_stamina.value = player.stamina
		hud_focus.value = player.focus
		hud_health.text = "%d / %d" % [player.hp,Profile.max_health()]
	if hud_boss!=null:
		var boss: Node = null
		for e in enemies:
			if is_instance_valid(e) and not e.dead and e.boss: boss = e
		hud_boss.visible = boss!=null
		hud_boss_text.visible = boss!=null
		if boss!=null:
			hud_boss.max_value = boss.maximum
			hud_boss.value = boss.hp
	if hud_toast!=null:
		hud_toast.text = toast_text if toast_time>0 else ""

func start_battle() -> void:
	for e in enemies:
		if is_instance_valid(e): e.queue_free()
	enemies.clear()
	if is_instance_valid(player): player.queue_free()
	stage.reset()
	effects.clear()
	projectiles.clear()
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
	elapsed = 0
	over = false
	paused = false
	won = false
	wait_wave = 0.65
	mode = "battle"
	build_ui()
	toast("J 节奏连击 · K 重击破势 · L 闪避，注意橙色攻击预警")

func spawn(kind: String, x: float) -> Node:
	var e := FOE.new()
	e.host = self
	e.kind = kind
	enemy_sequence += 1
	e.eid = enemy_sequence
	e.position = Vector2(x,640)
	add_child(e)
	enemies.append(e)
	stage.actor(e,kind)
	return e

func next_wave() -> void:
	wave += 1
	if wave==1:
		spawn("melee",730)
		spawn("melee",910)
		spawn("ranged",1130)
		toast("第一节 · 刃叶与灯翅    先解决远程单位")
	else:
		spawn("boss",930)
		spawn("ranged",1140)
		player.hp = mini(Profile.max_health(),player.hp+25)
		toast("第二节 · 折页守卫    蓄力时抗轻击，重击可破势")
	build_ui()

func attack_budget(actor: Node) -> bool:
	var count: int = 0
	for e in enemies:
		if is_instance_valid(e) and e!=actor and e.state in ["tell","active"]: count += 1
	return count<(1 if actor.kind=="ranged" else 2)

func resolve_attack(actor: Node) -> void:
	for e in enemies:
		if not is_instance_valid(e) or e.dead or e.eid in actor.hit_ids: continue
		if actor.attackbox().intersects(e.hurtbox()):
			actor.hit_ids.append(e.eid)
			var damage: int = int(Profile.damage()*[0.80,0.95,1.55][actor.combo])
			e.take_hit(damage,actor.facing,actor.combo==2)
			actor.focus = minf(100,actor.focus+12)
			var point := Vector2(clampf(actor.position.x+actor.facing*100,e.position.x-35,e.position.x+35),actor.position.y-125)
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

func shoot(origin: Vector2, target: Vector2, facing: int) -> void:
	var direction := (target-origin).normalized()
	if absf(direction.x)<0.5: direction = Vector2(facing,0)
	projectiles.append({"pos":origin,"velocity":direction*350,"life":4.0})
	fx("muzzle",origin,facing,0.25)

func enemy_down(e: Node) -> void:
	kills += 1
	Profile.award_enemy(round_id,e.eid,e.boss)
	fx("death",e.position+Vector2(0,-100),1,0.5)
	float_number(e.position+Vector2(0,-170),"+碎片",Color("a3d9c5"))

func finish(win: bool) -> void:
	if over: return
	over = true
	won = win
	if win:
		Profile.wins += 1
		Profile.add_file("守卫的档案匣.dat",75,"样片奖励")
	else: Profile.defeats += 1
	Profile.save_profile()
	build_ui()

func camp() -> void:
	mode = "camp"
	paused = false
	build_ui()

func enter_battle() -> void:
	camp_page = ""
	if not is_instance_valid(player) or over: start_battle()
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
	if event.is_action_pressed("pause"):
		if mode=="camp" and not camp_page.is_empty():
			camp_page = ""
			build_ui()
		else: toggle_pause()
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
	stage.animate(dt if not paused else 0)
	toast_time = maxf(0,toast_time-dt)
	refresh_hud()
	if not playing():
		return
	view.visible = true
	elapsed += dt
	effect_clock += dt
	hitstop = maxf(0,hitstop-dt)
	trauma = maxf(0,trauma-dt*2.3)
	var shake: float = 0 if reduce_motion else trauma*trauma*9
	view.position = Vector2(sin(effect_clock*43),cos(effect_clock*37))*shake
	fx_node.position = view.position
	stage.visual_offset = view.position
	var animate_dt: float = 0 if hitstop>0 else dt
	if is_instance_valid(player): stage.sync(player,animate_dt)
	for e in enemies:
		if is_instance_valid(e): stage.sync(e,animate_dt)
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
			if hit: player.take_hit(17,int(signf(p.velocity.x)))
			if hit or p.life<=0 or p.pos.x<0 or p.pos.x>1280: projectiles.remove_at(i)
	var living: int = 0
	for e in enemies:
		if is_instance_valid(e) and not e.dead: living += 1
	if living==0:
		wait_wave -= dt
		if wait_wave<=0:
			if wave>=2: finish(true)
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
			get_window().show()
			get_window().grab_focus()
			Engine.max_fps = 60
			viewport3d.render_target_update_mode = SubViewport.UPDATE_ALWAYS
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
	if mode!="desktop": prior_mode = mode
	mode = "desktop"
	write_bridge("pet")
	get_window().hide()
	print("BRIDGE_HIDDEN")
	viewport3d.render_target_update_mode = SubViewport.UPDATE_DISABLED
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
	var max_drift: float = 0
	var max_height: float = 0
	for i in range(90):
		rig.position.x += 310.0/60.0/80.0 if rig is Node3D else 310.0/60.0
		rig.drive(1.0/60,Vector2(310,0),"run",0,1,0)
		max_drift = maxf(max_drift,rig.drift_error)
		max_height = maxf(max_height,rig.contact_error)
	checks.append("PASS rendered sole world lock %.4f px / %.4f px height" % [max_drift,max_height] if max_drift<1.5 and max_height<1 else "FAIL rendered sole world lock %.4f / %.4f" % [max_drift,max_height])
	var ground_y: float = stage.camera.unproject_position(Vector3.ZERO).y
	checks.append("PASS render ground matches physics" if absf(ground_y-640)<1 else "FAIL render ground matches physics")
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
	camp_page = "feed"
	selected = [str(Profile.files[0].id),str(Profile.files[1].id)]
	feed()
	await get_tree().process_frame
	await get_tree().process_frame
	checks.append("PASS feeding unlocks level two with valid UI focus" if Profile.level==2 and Profile.xp==20 else "FAIL feeding unlocks level two with valid UI focus")
	checks.append("PASS tests cannot write player save" if not Profile.save_enabled else "FAIL tests cannot write player save")
	for line in checks:
		if line.begins_with("FAIL"): failed += 1
	var file := FileAccess.open("res://artifacts/v4-checks.txt",FileAccess.WRITE)
	file.store_string("\n".join(checks)+"\nFailures=%d\n" % failed)
	print("V4_CHECKS ",checks.size()," failures=",failed)
	get_tree().quit(failed)

func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://artifacts/"+name+".png")

func visual_check() -> void:
	Profile.level = 3
	build_ui()
	await get_tree().create_timer(0.5).timeout
	await capture("v4-camp")
	camp_page = "feed"
	build_ui()
	await get_tree().create_timer(0.3).timeout
	await capture("v4-inventory")
	camp_page = ""
	start_battle()
	await get_tree().create_timer(1.0).timeout
	player.position.x = 470
	for e in enemies:
		if is_instance_valid(e): e.position.x += 10
	await get_tree().create_timer(0.25).timeout
	await capture("v4-battle")
	player.attack(2)
	await get_tree().create_timer(0.30).timeout
	await capture("v4-kick")
	await get_tree().create_timer(0.7).timeout
	player.invuln = 0
	player.take_hit(18,-1)
	await get_tree().create_timer(0.12).timeout
	await capture("v4-hurt")
	for e in enemies:
		if is_instance_valid(e):
			stage.remove_actor(e)
			e.queue_free()
	enemies.clear()
	player.position = Vector2(280,640)
	player.invuln = 100
	spawn("boss",850)
	spawn("ranged",1120)
	wave = 2
	build_ui()
	await get_tree().create_timer(0.5).timeout
	await capture("v4-boss")
	get_tree().quit()

