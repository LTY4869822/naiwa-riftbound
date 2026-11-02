extends RefCounted
static func quiet(h: Node) -> void:
	h.rift.finish_arrival()
	h.wait_wave=99999
	for e in h.enemies:
		if is_instance_valid(e): h.stage.remove_actor(e); e.queue_free()
	h.enemies.clear()
	h.projectiles.clear(); h.boss_fields.clear()
static func setup(h: Node) -> void:
	Profile.level=7
	Ascension.energy=0
	h.get_window().title="奶蛙 · 二段跳 / 狰动作 / 墨印遗物（隔离试玩）"
	h.get_window().size=Vector2i(1280,800)
	relics(h)
static func relics(h: Node) -> void:
	h.choose_level(0,1); quiet(h)
	h.wave=h.current_level().waves.size()
	h.finish(true)
static func jump(h: Node) -> void:
	h.choose_level(0,0); quiet(h)
	h.toast("连续按两次跳跃键 · 二段跳；F1 狰 / F3 遗物 / F4 正常连战")
static func tiger(h: Node) -> void:
	h.choose_level(0,2); quiet(h)
	h.wave=h.current_level().waves.size()
	h.spawn("zheng",960)
	h.toast("狰 · 新八帧奔跑与战斗姿势；F2 空地练二段跳 / F3 遗物 / F4 正常连战")
static func route(h: Node) -> void:
	h.choose_level(0,0)
	h.open_route()
