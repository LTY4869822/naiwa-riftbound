extends Node2D
const HERO = preload("res://v6/fighter.gd")
const FOE = preload("res://v6/enemy.gd")
const STAGE = preload("res://v6/stage.gd")
const UI = preload("res://v6/ui.gd")
const EFFECTS = preload("res://v6/effects.gd")
const SKILL_NAME:="星核巨拳"
var player: CharacterBody2D
var enemies: Array[Node] = []
var stage: Node2D
var view: Node2D
var hud: Control
var fx_node: Node2D
var enemy_fx: Node2D
var ultimate: Node2D
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
const BIOME_CONTENT=preload("res://biomes/content.gd")
const CAMPAIGN = preload("res://campaign/levels.gd")
var level_index: int=0
var stage_index: int=0
var ascension: Node2D
var journey: Node2D
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
var spectacle: Node2D
var sprint_wind: Node2D
var arena: Node2D
var training: Node
var trial_mode:=false
var rift: Node
var punch: Node

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
		Ascension.save_enabled=false
		Ascension.reset()
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
	sprint_wind=preload("res://v6/sprint_wind.gd").new()
	sprint_wind.host=self
	sprint_wind.z_index=4
	stage.add_child(sprint_wind)
	fx_node = EFFECTS.new()
	fx_node.z_index = 10
	fx_node.host = self
	add_child(fx_node)
	punch=preload("res://punch/director.gd").new()
	punch.host=self
	add_child(punch)
	enemy_fx=preload("res://foe_vfx/director.gd").new()
	enemy_fx.host=self
	fx_node.add_child(enemy_fx)
	ultimate=preload("res://combat/ultimate.gd").new()
	ultimate.host=self
	fx_node.add_child(ultimate)
	spore_field=preload("res://combat/spore_field.gd").new()
	spore_field.host=self
	add_child(spore_field)
	boss_fields=preload("res://campaign/boss_fields.gd").new()
	boss_fields.host=self
	add_child(boss_fields)
	arena=preload("res://remediation/arena.gd").new()
	arena.host=self
	arena.z_index=2
	add_child(arena)
	training=preload("res://remediation/training.gd").new()
	training.host=self
	add_child(training)
	spectacle=preload("res://remediation/spectacle.gd").new()
	spectacle.host=self
	fx_node.add_child(spectacle)
	ascension=preload("res://ascension/power.gd").new()
	ascension.host=self
	add_child(ascension)
	Ascension.changed.connect(refresh_hud)
	journey=preload("res://loop/journey.gd").new()
	journey.host=self
	journey.z_index=11
	add_child(journey)
	rift=preload("res://rift/director.gd").new()
	rift.host=self
	add_child(rift)
	var repertoire_vfx:=preload("res://loop/boss_vfx.gd").new()
	repertoire_vfx.host=self
	repertoire_vfx.z_index=14
	add_child(repertoire_vfx)
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
	for name in ["ultimate_charge","ultimate_launch","ultimate_hit"]:
		sounds[name]=load("res://assets/ultimate/%s.wav" % name)
	for i in range(10):
		var channel := AudioStreamPlayer.new()
		add_child(channel)
		channels.append(channel)
	Profile.changed.connect(func():
		if mode=="camp": call_deferred("build_ui")
		else: refresh_hud())
	Preferences.changed.connect(func():
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
	if "--punch-review" in args and test_mode: call_deferred("run_punch_review")
	elif "--punch-film" in args and test_mode: call_deferred("run_punch_film")
	elif "--punch-demo" in args and test_mode: call_deferred("run_punch_demo")
	elif "--echo-review" in args and test_mode: call_deferred("run_echo_review")
	elif "--echo-film" in args and test_mode: call_deferred("run_echo_film")
	elif "--echo-demo" in args and test_mode: call_deferred("run_echo_demo")
	elif "--biome-review" in args and test_mode: call_deferred("run_biome_review")
	elif "--biome-ai-check" in args and test_mode: call_deferred("run_biome_ai")
	elif "--biome-film" in args and test_mode: call_deferred("run_biome_film")
	elif "--biome-demo" in args and test_mode: call_deferred("run_biome_demo")
	elif "--rift-review" in args and test_mode: call_deferred("run_rift_review")
	elif "--rift-ai-check" in args and test_mode: call_deferred("run_rift_ai")
	elif "--rift-balance" in args and test_mode: call_deferred("run_loop_balance")
	elif "--rift-film" in args and test_mode: call_deferred("run_rift_film")
	elif "--rift-demo" in args and test_mode: call_deferred("run_rift_demo")
	elif "--loot-review" in args and test_mode: call_deferred("run_loot_review")
	elif "--loot-film" in args and test_mode: call_deferred("run_loot_film")
	elif "--loot-demo" in args and test_mode: call_deferred("run_loot_demo")
	elif "--loop-review" in args and test_mode: call_deferred("run_loop_review")
	elif "--loop-ai-check" in args and test_mode: call_deferred("run_loop_ai_check")
	elif "--loop-demo" in args and test_mode: call_deferred("run_loop_demo")
	elif "--loop-film" in args and test_mode: call_deferred("run_loop_film")
	elif "--loop-balance" in args and test_mode: call_deferred("run_loop_balance")
	elif "--ascension-review" in args and test_mode: call_deferred("run_ascension_review")
	elif "--ascension-balance" in args and test_mode: call_deferred("run_ascension_balance")
	elif "--ascension-film" in args and test_mode: call_deferred("run_ascension_film")
	elif "--ascension-demo" in args and test_mode: call_deferred("run_ascension_demo")
	elif "--reaction-review" in args and test_mode: call_deferred("run_reaction_review")
	elif "--reaction-film" in args and test_mode: call_deferred("run_reaction_film")
	elif "--remediation-review" in args and test_mode: call_deferred("run_remediation_review")
	elif "--remediation-film" in args and test_mode: call_deferred("run_remediation_film")
	elif "--remediation-demo" in args and test_mode: call_deferred("run_remediation_demo")
	elif "--route-jelly-test" in args and test_mode: call_deferred("run_route_jelly_test")
	elif "--shop-review" in args and test_mode: call_deferred("run_shop_review")
	elif "--shop-demo" in args and test_mode: call_deferred("run_shop_demo")
	elif "--design-audit" in args and test_mode: call_deferred("run_design_audit")
	elif "--route-jelly-review" in args and test_mode: call_deferred("run_route_jelly_review")
	elif "--route-jelly-film" in args and test_mode: call_deferred("run_route_jelly_film")
	elif "--route-jelly-demo" in args and test_mode: call_deferred("run_route_jelly_demo")
	elif "--ultimate-check" in args and test_mode: call_deferred("run_ultimate_check")
	elif "--ultimate-review" in args and test_mode: call_deferred("run_ultimate_review")
	elif "--ultimate-film" in args and test_mode: call_deferred("run_ultimate_film")
	elif "--ultimate-demo" in args and test_mode: call_deferred("run_ultimate_demo")
	elif "--foe-vfx-review" in args and test_mode: call_deferred("run_foe_vfx_review")
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

func run_punch_review() -> void:
	await load("res://punch/review.gd").new().run(self)
func run_punch_film() -> void:
	await load("res://punch/film.gd").new().run(self)
func run_punch_demo() -> void:
	preload("res://punch/demo.gd").setup(self)

func run_balance_check() -> void:
	await preload("res://v6/balance_check.gd").run(self)

func run_ascension_review() -> void:
	await load("res://ascension/review.gd").new().run(self)

func run_loop_review() -> void:
	await load("res://loop/review.gd").new().run(self)

func run_loop_ai_check() -> void:
	await load("res://loop/ai_check.gd").run(self)

func run_loop_film() -> void:
	await load("res://loop/film.gd").new().run(self)

func run_loop_balance() -> void:
	await load("res://loop/balance.gd").run(self)

func run_loop_demo() -> void:
	Profile.level=5
	Ascension.reset()
	get_window().title="奶蛙 · 连战、战利品与招式重做（隔离试玩）"
	open_route()
	toast("三段连续冒险 · 金币锻造装备 · 药露回复一半缺失生命 · 重击可抓蓄力窗口破势")

func run_rift_review() -> void:
	await preload("res://rift/review.gd").new().run(self)

func run_biome_review() -> void:
	await preload("res://biomes/review.gd").new().run(self)

func run_echo_review() -> void:
	await preload("res://echo/review.gd").new().run(self)

func run_echo_demo() -> void:
	preload("res://echo/demo.gd").setup(self)

func run_echo_film() -> void:
	await preload("res://echo/film.gd").new().run(self)

func run_biome_demo() -> void:
	preload("res://biomes/demo.gd").setup(self)

func run_biome_ai() -> void:
	await preload("res://biomes/observe.gd").run(self)

func run_biome_film() -> void:
	await preload("res://biomes/film.gd").new().run(self)

func run_rift_ai() -> void:
	await preload("res://rift/observe.gd").run(self)

func run_rift_film() -> void:
	await preload("res://rift/film.gd").new().run(self)

func run_rift_demo() -> void:
	preload("res://rift/demo.gd").run(self)

func run_loot_demo() -> void:
	preload("res://loot/demo.gd").run(self)

func run_loot_film() -> void:
	await preload("res://loot/film.gd").run(self)

func run_loot_review() -> void:
	await preload("res://loot/review.gd").new().run(self)

func demo_repertoire(index: int) -> void:
	if not test_mode or "--loop-demo" not in OS.get_cmdline_user_args(): return
	choose_level(index,2)
	wave=CAMPAIGN.wave_count(index,2)
	wait_wave=999
	player.position=Vector2(260,640)
	spawn(current_level().boss,1000)
	toast("首领演武 · 四种常规招式与奥义；抓蓄力窗口重击破势 · 魔能从实战积攒")

func run_ascension_balance() -> void:
	await load("res://ascension/balance.gd").run(self)

func run_ascension_film() -> void:
	await load("res://ascension/film.gd").new().run(self)

func run_ascension_demo() -> void:
	run_loop_demo()

func demo_mythic(index: int) -> void:
	if not test_mode or "--ascension-demo" not in OS.get_cmdline_user_args(): return
	choose_level(index,2)
	wave=CAMPAIGN.wave_count(index,2)
	wait_wave=999
	player.position=Vector2(260,640)
	player.focus=100
	Ascension.energy=100
	var e: Node=spawn(current_level().boss,980)
	e.hp=roundi(e.maximum*0.9)
	e.combat_age=8
	e.ult_cooldown=2.0
	refresh_hud()
	toast("异兽演武 · R 魔神觉醒 / U 终极奥义；F6 补满魔能，关卡按钮可回正式关卡流程")

func run_remediation_review() -> void:
	await load("res://remediation/review.gd").new().run(self)

func run_reaction_review() -> void:
	await load("res://remediation/reaction_review.gd").new().run(self)

func run_reaction_film() -> void:
	await load("res://remediation/reaction_film.gd").new().run(self)

func run_remediation_film() -> void:
	await load("res://remediation/film.gd").new().run(self)

func run_remediation_demo() -> void:
	get_window().title="奶蛙 · 定向奥义与疾风冲刺（不保存）"
	Profile.level=3
	open_route()
	toast("奥义试玩 · F1～F4 直达四只首领 · U 星核巨拳 · K 重击破势")
	await get_tree().create_timer(0.8).timeout
	await capture("remediation-preview")

func demo_duel(index: int) -> void:
	if not test_mode or "--remediation-demo" not in OS.get_cmdline_user_args(): return
	choose_level(index)
	wave=CAMPAIGN.wave_count(index)
	wait_wave=999
	player.focus=100
	var e: Node=spawn(current_level().boss,940)
	e.hp=roundi(e.maximum*0.8)
	e.combat_age=8
	e.ult_cooldown=2
	training.beat()
	refresh_hud()
	toast("演武 · 首领即将释放奥义！注意攻击落点 · F1～F4 换首领 · U 大招")

func demo_sprint() -> void:
	if not test_mode or "--remediation-demo" not in OS.get_cmdline_user_args(): return
	choose_level(0)
	wave=CAMPAIGN.wave_count(0)
	wait_wave=999
	player.focus=100
	training.beat()
	refresh_hud()
	toast("疾风练习 · A/D 移动 · L/Shift 冲刺 · F1～F4 首领演武")

func run_shop_review() -> void:
	await load("res://wardrobe/review.gd").new().run(self)

func run_shop_demo() -> void:
	get_window().title="奶蛙 · 皮肤商城预览（不保存）"
	open_shop()
	await get_tree().create_timer(0.7).timeout
	await capture("shop-preview")

func run_design_audit() -> void:
	await load("res://wardrobe/design_probe.gd").new().run(self)

func run_route_jelly_test() -> void:
	await load("res://campaign/jelly_review.gd").new().run(self,false)

func run_route_jelly_review() -> void:
	await load("res://campaign/jelly_review.gd").new().run(self,true)

func run_route_jelly_film() -> void:
	await load("res://campaign/jelly_film.gd").new().run(self)

func run_route_jelly_demo() -> void:
	get_window().title="奶蛙 · 果冻关卡地图（不保存）"
	Profile.level=3
	open_route()

func run_ultimate_check() -> void:
	await load("res://combat/ultimate_check.gd").new().run(self)

func run_ultimate_review() -> void:
	await load("res://combat/ultimate_review.gd").new().run(self)

func run_ultimate_film() -> void:
	await load("res://combat/ultimate_film.gd").new().run(self)

func run_ultimate_demo() -> void:
	get_window().title="奶蛙 · 贯穿重拳试玩（不保存）"
	Profile.level=3
	start_battle()
	player.focus=100
	refresh_hud()
	toast("贯穿重拳试玩 · J / K 命中攒专注 · U 大招 · 60 专注 / 次")

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
	return CAMPAIGN.get_stage(level_index,stage_index)

func open_route() -> void:
	if mode=="desktop": return
	route_open=true
	if mode=="battle": paused=true
	build_ui()

func close_route() -> void:
	route_open=false
	build_ui()

func choose_level(index: int, chapter: int=0, keep_actor: bool=false) -> void:
	level_index=clampi(index,0,CAMPAIGN.LEVELS.size()-1)
	stage_index=clampi(chapter,0,2)
	route_open=false
	start_battle(keep_actor)

func next_level() -> void:
	if not over or not won: return
	choose_level((level_index+1)%CAMPAIGN.LEVELS.size(),0,true)

func continue_room() -> void:
	punch.clear(); hitstop=0; trauma=0
	stage_index=mini(stage_index+1,2)
	for e in enemies:
		if is_instance_valid(e):
			stage.remove_actor(e)
			e.queue_free()
	enemies.clear()
	projectiles.clear()
	boss_fields.clear()
	spore_field.clear()
	enemy_fx.clear()
	arena.reset(level_index,stage_index)
	stage.chapter_index=stage_index
	stage.queue_redraw()
	journey.drops.clear()
	journey.stage_rewarded=false
	player.position=Vector2(100,640)
	player.velocity=Vector2.ZERO
	player.buffered=0
	player.jump_buffer=0
	player.jumps_used=0
	stage.sync(player,0.001)
	run_reward_id=Crypto.new().generate_random_bytes(16).hex_encode()
	clear_reward={}
	wave=0
	wait_wave=0.8
	training.beat()
	build_ui()
	toast("第%d段 · %s · 生命与魔能继续保留" % [stage_index+1,current_level().chapter_title])

func complete_map() -> void:
	if over: return
	punch.clear()
	over=true
	won=true
	ultimate.clear()
	enemy_fx.clear()
	spectacle.clear()
	sprint_wind.clear()
	projectiles.clear()
	boss_fields.clear()
	spore_field.clear()
	Profile.save_profile()
	build_ui()

func open_gear() -> void:
	camp()
	menu_section="gear"
	build_ui()

func retry_map() -> void:
	choose_level(level_index,0)

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
	await preload("res://v6/menu_review.gd").run(self)

func load_menu_settings() -> void:
	if test_mode: return
	var config := ConfigFile.new()
	if config.load("user://menu_settings.cfg") == OK:
		audio_enabled = bool(config.get_value("journey","audio",true))
		reduce_motion = bool(config.get_value("journey","reduce_motion",false))
		trial_mode = bool(config.get_value("journey","trial",false))

func save_menu_settings() -> void:
	if test_mode: return
	var config := ConfigFile.new()
	config.set_value("journey","audio",audio_enabled)
	config.set_value("journey","reduce_motion",reduce_motion)
	config.set_value("journey","trial",trial_mode)
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
		if int(Wardrobe.clears.get(str(CAMPAIGN.LEVELS[i].id)+"-3",0))>0: completed_levels[i]=true

func open_shop() -> void:
	camp()
	menu_section="shop"
	ui_focus=""
	build_ui()

func retry_clear_reward() -> void:
	if not over or not won: return
	clear_reward=Wardrobe.award_clear(current_level().id,run_reward_id)
	build_ui()

func setup_input() -> void:
	Preferences.install()

func intro_training() -> bool:
	return Profile.level<=2 and not trial_mode and level_index==0 and stage_index==0 and wave>=1 and wave<=4 and int(Wardrobe.clears.get("moss",0))==0

func scaled_enemy_health(base: int, kind: String="") -> int:
	if intro_training():
		var practice: Dictionary={"melee":60,"beetle":34,"shaman":60,"raven":50,"ranged":48}
		if practice.has(kind): return mini(base,int(practice[kind]))
	var boss: bool=kind=="boss" or bool(preload("res://combat/enemy_catalog.gd").DATA.get(kind,{}).get("boss",false))
	var pressure: float=([1.8,1.95,2.1][stage_index]*(1+clampf((Profile.level-5)*.035,0,.35))) if boss else 1.15
	return maxi(1,roundi(base*float(current_level().health_scale)*pressure*(Profile.damage()/24.0*1.15 if trial_mode else 1.0)))

func scaled_enemy_damage(base: int) -> int:
	if intro_training(): return maxi(1,roundi(base*0.4))
	return maxi(1,roundi(base*float(current_level().damage_scale)*(Profile.max_health()/100.0*1.10 if trial_mode else 1.0)))

func playing() -> bool:
	return mode=="battle" and not paused and not over and not route_open and (journey==null or not journey.travelling) and (rift==null or not rift.blocked())

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
	elif is_instance_valid(rift) and rift.offer_active and mode=="battle" and not paused: rift.show_offer()

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
			"jumps_used":player.jumps_used,
			"energy":Ascension.energy,"power_phase":ascension.phase,"power_remaining":ascension.remaining,
			"skill_label":"紫霆·灭界" if ascension.visible_form() else SKILL_NAME,"skill_dash_cancel":player.SKILL_DASH_CANCEL,
			"skill_charge":clampf(player.elapsed/player.SKILL_RELEASE,0,1) if player.state=="skill" else -1.0,
			"boss_hp":boss.hp if boss!=null else 0,"boss_max":boss.maximum if boss!=null else 1,
			"boss_id":boss.get_instance_id() if boss!=null else 0,
			"boss_state":boss.state if boss!=null else "","boss_alive":boss!=null,
			"boss_name":preload("res://combat/enemy_catalog.gd").title(boss.kind) if boss!=null else "",
			"boss_enraged":boss.enraged if boss!=null else false,
			"boss_stagger":boss.stagger if boss!=null else 0,"boss_guard":boss.break_guard if boss!=null else 0,
			"boss_ult":str(boss.ult_data.get("title","")) if boss!=null else "","boss_timer":boss.timer if boss!=null else 0,
			"boss_move":str(boss.attack_data.get("name","")) if boss!=null else "",
			"boss_phase":boss.combat_phase if boss!=null else 1,
			"relics":rift.ranks if rift!=null else {},"riposte":rift.riposte if rift!=null else 0.0,
			"dash_cost":player.dash_cost(),"dash_limit":player.dash_limit(),
			"trial_mode":trial_mode,
			"level_title":current_level().title,"level_number":level_index*3+stage_index+1,
			"beat_title":current_level().beats[clampi(wave-1,0,current_level().beats.size()-1)],
			"wave_total":CAMPAIGN.wave_count(level_index,stage_index),
			"coins":Wardrobe.coins,"room_cleared":journey.cleared,"kills":kills,"wave":wave,"files":Profile.files.size(),
		})
		battle_hud.set_toast(toast_text if toast_time>0 else "")
	if hud_toast!=null:
		hud_toast.text = toast_text if toast_time>0 else ""

func start_battle(keep_actor: bool=false) -> void:
	if is_instance_valid(punch): punch.clear()
	hitstop=0; trauma=0
	if is_instance_valid(rift): rift.reset_run()
	journey.reset()
	ascension.clear(true)
	route_open=false
	ultimate.clear()
	if is_instance_valid(spectacle): spectacle.clear()
	if is_instance_valid(sprint_wind): sprint_wind.clear()
	for e in enemies:
		if is_instance_valid(e): e.queue_free()
	enemies.clear()
	if not keep_actor and is_instance_valid(player): player.queue_free()
	stage.reset()
	arena.reset(level_index,stage_index)
	stage.chapter_index=stage_index
	enemy_fx.clear()
	stage.level_index=level_index
	stage.queue_redraw()
	effects.clear()
	projectiles.clear()
	spore_field.clear()
	boss_fields.clear()
	if not keep_actor or not is_instance_valid(player):
		player = HERO.new()
		player.host = self
		add_child(player)
		player.changed.connect(refresh_hud)
	player.position = Vector2(155,640)
	player.velocity=Vector2.ZERO
	player.jump_buffer=0
	player.jumps_used=0
	player.state="idle"
	player.elapsed=0
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
	training.beat()
	build_ui()
	toast("%s · %s    %s" % [current_level().title,current_level().chapter_title,current_level().hint])

func spawn(kind: String, x: float) -> Node:
	var e := FOE.new()
	e.host = self
	e.kind = kind
	enemy_sequence += 1
	e.eid = enemy_sequence
	e.position = Vector2(x,640)
	if BIOME_CONTENT.flyer(kind): e.position.y=600
	add_child(e)
	enemies.append(e)
	e.changed.connect(refresh_hud)
	stage.actor(e,kind)
	if e.boss and is_instance_valid(rift): rift.register(e)
	return e

func next_wave() -> void:
	wave += 1
	ENCOUNTERS.spawn_wave(self)

func attack_budget(actor: Node) -> bool:
	var melee_count:=0
	var caster_count:=0
	for e in enemies:
		if not is_instance_valid(e) or e.dead or e==actor: continue
		if e.state in ["ult_tell","ult_active","phase_shift","rift_arrive"]: return false
		if e.state not in ["tell","active"]: continue
		if BIOME_CONTENT.caster(e.kind): caster_count+=1
		else: melee_count+=1
	if melee_count+caster_count>=2: return false
	return caster_count<1 if BIOME_CONTENT.caster(actor.kind) else melee_count<1

func resolve_attack(actor: Node) -> void:
	var accepted:=0
	for e in enemies:
		if not is_instance_valid(e) or e.dead or e.eid in actor.hit_ids: continue
		if actor.attackbox().intersects(e.hurtbox()):
			actor.hit_ids.append(e.eid)
			var damage: int = int(Profile.damage()*[0.80,0.95,1.55][actor.combo])
			if ascension.empowered(): damage=roundi(damage*1.45)
			damage=roundi(damage*rift.attack_boost())
			var prior_hp: int=e.hp
			var prior_state: String=e.state
			var guarded: bool=e.kind in ["beetle","crystal_crab"] and actor.combo!=2 and actor.facing==-e.facing and e.state in ["approach","tell","active"]
			e.take_hit(damage,actor.facing,actor.combo==2)
			damage=prior_hp-e.hp
			if damage<=0: continue
			training.complete("heavy" if actor.combo==2 and e.kind=="beetle" else "combo")
			if actor.combo==2 and actor.hit_ids.size()==1 and not ascension.visible_form(): Ascension.gain(1)
			if not e.dead: stage.sync(e,0.001)
			actor.focus = minf(100,actor.focus+12)
			var hand: Vector2=stage.strike_position(actor)
			var body: Rect2=e.hurtbox()
			var point := Vector2(clampf(hand.x,body.position.x+12,body.end.x-12),clampf(hand.y,body.position.y+24,body.end.y-24))
			var broke: bool=actor.combo==2 and (e.kind in ["beetle","crystal_crab"] or e.boss and e.state=="stunned" and prior_state!="stunned")
			var style: String="break" if broke or guarded else "ultimate" if ascension.empowered() else "heavy" if actor.combo==2 else "hit-mint" if actor.combo==1 else "hit-gold"
			impact(point,actor.facing,actor.combo==2,false,style,accepted==0)
			if actor.combo==2 and accepted==0 and actor.is_on_floor() and e.is_on_floor(): punch.floor_hit(Vector2(point.x,actor.position.y),actor.facing)
			float_number(point+Vector2(0,-24),str(damage),Color("a1ffe0") if broke else Color("ffe0a0"))
			accepted+=1
			refresh_hud()

func skill_burst() -> void:
	ultimate.launch(stage.strike_position(player),player.facing,player.position.x)
	refresh_hud()

func shoot(origin: Vector2, target: Vector2, facing: int, owner_id: int=0) -> void:
	var direction := (target-origin).normalized()
	if absf(direction.x)<0.5: direction = Vector2(facing,0)
	projectiles.append({"pos":origin,"velocity":direction*390,"life":4.0,"owner":owner_id,"enemy_vfx":true})
	fx("muzzle",origin,facing,0.25)

func enemy_down(e: Node) -> void:
	kills += 1
	if not ascension.visible_form(): Ascension.record_kill(run_reward_id,e.eid,e.boss)
	journey.drop_enemy(e)
	enemy_fx.cancel(e.eid)
	spectacle.cancel(e.eid)
	spore_field.cancel(e.eid)
	boss_fields.cancel(e.eid)
	for i in range(projectiles.size()-1,-1,-1):
		if int(projectiles[i].get("owner",0))==e.eid: projectiles.remove_at(i)
	Profile.award_enemy(round_id,e.eid,e.boss)
	fx("death",e.position+Vector2(0,-100),1,0.5)
	float_number(e.position+Vector2(0,-170),"+碎片",Color("a3d9c5"))
	refresh_hud()

func finish(win: bool) -> void:
	if over: return
	if win:
		journey.clear_room()
		return
	over = true
	enemy_fx.clear()
	ultimate.clear()
	if is_instance_valid(spectacle): spectacle.clear()
	if is_instance_valid(sprint_wind): sprint_wind.clear()
	spore_field.clear()
	boss_fields.clear()
	projectiles.clear()
	won = win
	if win:
		if stage_index==0: completed_levels[level_index]=true
		clear_reward=Wardrobe.award_clear(current_level().id,run_reward_id)
		Profile.wins += 1
		Profile.add_file(current_level().title+"的档案匣.dat",75,"守关奖励")
	else:
		Profile.defeats += 1
		ascension.clear()
	Profile.save_profile()
	build_ui()

func camp() -> void:
	cancel_ultimate()
	if is_instance_valid(punch): punch.clear()
	view.position=Vector2.ZERO; fx_node.position=Vector2.ZERO
	mode = "camp"
	paused = false
	menu_section = "home"
	menu_entrance = true
	ui_focus = ""
	build_ui()

func cancel_ultimate() -> void:
	ultimate.clear()
	if is_instance_valid(spectacle): spectacle.clear()
	if is_instance_valid(sprint_wind): sprint_wind.clear()
	if is_instance_valid(player) and player.state=="skill":
		player.state="idle"
		player.elapsed=0
		stage.sync(player,0.001)
	for channel in channels:
		if channel.playing and channel.stream==sounds.get("ultimate_charge"): channel.stop()

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
	if test_mode and "--punch-demo" in OS.get_cmdline_user_args() and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_F1,KEY_F2,KEY_F3,KEY_F4]:
			preload("res://punch/demo.gd").shortcut(self,event.keycode)
			get_viewport().set_input_as_handled()
			return
	if test_mode and "--echo-demo" in OS.get_cmdline_user_args() and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_F1,KEY_F2,KEY_F3,KEY_F4]:
			if event.keycode==KEY_F1: preload("res://echo/demo.gd").tiger(self)
			elif event.keycode==KEY_F2: preload("res://echo/demo.gd").jump(self)
			elif event.keycode==KEY_F3: preload("res://echo/demo.gd").relics(self)
			else: preload("res://echo/demo.gd").route(self)
			get_viewport().set_input_as_handled()
			return
	if test_mode and "--biome-demo" in OS.get_cmdline_user_args() and event is InputEventKey and event.pressed and not event.echo and event.keycode>=KEY_F1 and event.keycode<=KEY_F12:
		preload("res://biomes/demo.gd").room(self,event.keycode-KEY_F1)
		get_viewport().set_input_as_handled()
		return
	if test_mode and "--rift-demo" in OS.get_cmdline_user_args() and event is InputEventKey and event.pressed and not event.echo and event.keycode>=KEY_F1 and event.keycode<=KEY_F4:
		preload("res://rift/demo.gd").duel(self,event.keycode-KEY_F1)
		get_viewport().set_input_as_handled()
		return
	if is_instance_valid(rift) and not rift.entrance.is_empty() and event.is_action_pressed("jump"):
		rift.skip()
		get_viewport().set_input_as_handled()
		return
	if test_mode and "--loot-demo" in OS.get_cmdline_user_args() and event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_F5:
		preload("res://loot/demo.gd").setup(self)
		get_viewport().set_input_as_handled()
		return
	if test_mode and "--loop-demo" in OS.get_cmdline_user_args() and event is InputEventKey and event.pressed and not event.echo and event.keycode>=KEY_F1 and event.keycode<=KEY_F4:
		demo_repertoire(event.keycode-KEY_F1)
		get_viewport().set_input_as_handled()
		return
	if test_mode and "--ascension-demo" in OS.get_cmdline_user_args() and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode>=KEY_F1 and event.keycode<=KEY_F4:
			demo_mythic(event.keycode-KEY_F1)
			get_viewport().set_input_as_handled()
			return
		if event.keycode==KEY_F6:
			Ascension.energy=100
			if not ascension.cinematic(): ascension.clear()
			refresh_hud()
			toast("试玩魔能已补满 · 落地按 R 觉醒")
			get_viewport().set_input_as_handled()
			return
	if test_mode and "--remediation-demo" in OS.get_cmdline_user_args() and event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_F5:
		demo_sprint()
		get_viewport().set_input_as_handled()
		return
	if test_mode and "--remediation-demo" in OS.get_cmdline_user_args() and event is InputEventKey and event.pressed and not event.echo and event.keycode>=KEY_F1 and event.keycode<=KEY_F4:
		demo_duel(event.keycode-KEY_F1)
		get_viewport().set_input_as_handled()
		return
	if route_open:
		if event.is_action_pressed("pause"):
			var route:=hud.find_child("LevelRoute",true,false)
			if is_instance_valid(route): route.request_close()
			else: close_route()
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
	var offset:=Vector2((effects.size()%3-1)*12,-5)
	effects.append({"type":"text","pos":point+offset,"origin":point+offset,"text":text,"color":color,"life":0.8,"max":0.8})

func impact(point: Vector2, facing: int, heavy: bool, hurt: bool = false, style: String="", pulse: bool=true) -> void:
	punch.contact(point,facing,heavy,hurt,style,pulse)

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
	view.position = punch.camera_offset()
	fx_node.position = view.position
	for i in range(effects.size()-1,-1,-1):
		effects[i].life -= dt
		if effects[i].type=="text":
			var age: float=1-float(effects[i].life)/float(effects[i].max)
			effects[i].pos=effects[i].origin+Vector2(0,-44*(1-pow(1-clampf(age,0,1),3)))
		if effects[i].life<=0: effects.remove_at(i)
	if hitstop<=0:
		for i in range(projectiles.size()-1,-1,-1):
			var p: Dictionary = projectiles[i]
			var previous: Vector2=p.pos
			p.velocity.y+=float(p.get("gravity",0))*dt
			p.pos += p.velocity*dt
			p.life -= dt
			if p.get("biome_bomb",false) and p.pos.y>=620:
				boss_fields.cast(int(p.owner),Vector2(p.pos.x,640),"biome_gear_gunner",.70,21,66)
				projectiles.remove_at(i)
				continue
			var hit: bool = not p.get("biome_bomb",false) and projectile_hits(p,previous)
			if hit:
				var accepted: bool=player.take_hit(int(p.get("damage",scaled_enemy_damage(17))),int(signf(p.velocity.x)))
				if accepted and not over and p.get("enemy_vfx",false): enemy_fx.projectile_contact(p)
			if over: break
			if hit or p.life<=0 or p.pos.x<0 or p.pos.x>1280: projectiles.remove_at(i)
	var living: int = 0
	for e in enemies:
		if is_instance_valid(e) and not e.dead: living += 1
	if living==0 and not journey.cleared and not ascension.cinematic():
		wait_wave -= dt
		if wait_wave<=0:
			if wave>=CAMPAIGN.wave_count(level_index,stage_index): finish(true)
			else:
				wait_wave = 1.3
				next_wave()
	fx_node.queue_redraw()

func projectile_hits(p: Dictionary, previous: Vector2) -> bool:
	if not is_instance_valid(player): return false
	var r: Rect2=player.hurtbox().grow(float(p.get("radius",0)))
	if r.has_point(p.pos) or r.has_point(previous): return true
	var points: Array=[r.position,Vector2(r.end.x,r.position.y),r.end,Vector2(r.position.x,r.end.y)]
	for i in 4:
		if Geometry2D.segment_intersects_segment(previous,p.pos,points[i],points[(i+1)%4])!=null: return true
	return false

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
	cancel_ultimate()
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
	await preload("res://v6/checks.gd").new().run(self)

func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://artifacts/"+name+".png")

func visual_check() -> void:
	Profile.level=3
	build_ui()
	await get_tree().create_timer(0.4).timeout
	await capture("v6-camp")
	start_battle()
	player.invuln=100
	await get_tree().create_timer(0.9).timeout
	Input.action_press("move_right")
	await get_tree().create_timer(0.45).timeout
	await capture("v6-run")
	Input.action_release("move_right")
	Input.action_press("move_left")
	await get_tree().create_timer(0.45).timeout
	await capture("v6-run-left")
	Input.action_release("move_left")
	Input.action_press("move_right")
	await get_tree().create_timer(0.25).timeout
	Input.action_release("move_right")
	await get_tree().create_timer(0.12).timeout
	await capture("v6-stop")
	player.position.x=520
	await get_tree().create_timer(0.3).timeout
	await capture("v6-battle")
	player.attack(0)
	await get_tree().create_timer(0.20).timeout
	await capture("v6-jab")
	await get_tree().create_timer(0.6).timeout
	player.attack(1)
	await get_tree().create_timer(0.22).timeout
	await capture("v6-cross")
	await get_tree().create_timer(0.6).timeout
	player.attack(2)
	await get_tree().create_timer(0.30).timeout
	await capture("v6-heavy")
	await get_tree().create_timer(0.6).timeout
	player.focus=100
	player.skill()
	await get_tree().create_timer(0.36).timeout
	await capture("v6-skill")
	await get_tree().create_timer(0.5).timeout
	Input.action_press("jump")
	player.jump_buffer=0.14
	await get_tree().create_timer(0.24).timeout
	Input.action_release("jump")
	await capture("v6-air")
	await get_tree().create_timer(0.65).timeout
	player.invuln=0
	player.take_hit(18,-1)
	await get_tree().create_timer(0.12).timeout
	await capture("v6-hurt")
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
	await capture("v6-boss")
	camp()
	menu_section="feed"
	build_ui()
	await get_tree().create_timer(0.2).timeout
	await capture("v6-virtual-inventory")
	selected=[str(Profile.files[0].id),str(Profile.files[1].id)]
	feed()
	await get_tree().create_timer(0.2).timeout
	await capture("v6-feed")
	get_tree().quit()

func open_recycle_feed() -> void:
	menu_navigate("feed")

func run_menu_film() -> void:
	await load("res://v5/menu_film.gd").run(self)


func run_hud_review() -> void:
	await load("res://v5/hud_review.gd").run(self)


func run_hud_film() -> void:
	await load("res://v5/hud_film.gd").run(self)

