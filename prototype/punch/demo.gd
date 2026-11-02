extends RefCounted
const QUIET=preload("res://echo/demo.gd")
static func setup(h: Node) -> void:
	Profile.level=7; Ascension.energy=0
	h.get_window().title="奶蛙 · PixelFX 打击感升级（隔离试玩）"
	h.get_window().size=Vector2i(1280,800)
	practice(h)
static func practice(h: Node) -> void:
	h.choose_level(0,0); QUIET.quiet(h)
	h.player.position=Vector2(430,640)
	var e: Node=h.spawn("beetle",565)
	e.maximum=8000; e.hp=8000; e.facing=-1
	e.velocity=Vector2(0,20); e.move_and_slide(); e.set_physics_process(false)
	var dummy:=preload("res://punch/dummy.gd").new(); dummy.host=h; dummy.target=weakref(e); h.add_child(dummy)
	h.stage.sync(e,.001)
	h.player.focus=100
	h.toast("J 连击 · K 重击破甲 · U 奥义；F1 练手 / F2 狰 / F3 第四境 Boss / F4 正常连战")
static func duel(h: Node,map_index: int) -> void:
	h.choose_level(map_index,2); QUIET.quiet(h)
	h.spawn("zheng" if map_index==0 else "paoxiao",960)
	h.player.focus=100
	h.toast("实际 Boss AI · F1 练手 / F2 狰 / F3 狍鸮 / F4 正常四境连战")
static func shortcut(h: Node,key: int) -> void:
	if key==KEY_F1: practice(h)
	elif key==KEY_F2: duel(h,0)
	elif key==KEY_F3: duel(h,3)
	else: QUIET.route(h)
