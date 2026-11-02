extends RefCounted
static func run(h: Node) -> void:
	Profile.level=7
	Ascension.reset()
	h.get_window().title="奶蛙 · 裂界荒神与遗物连战（隔离试玩）"
	h.open_route()
	h.toast("荒神三阶段 · 关间遗物三选一 · 精准闪避后反击 · F1～F4 直达异兽")

static func duel(h: Node, index: int) -> void:
	if not h.test_mode: return
	h.choose_level(index,2)
	h.wave=h.CAMPAIGN.wave_count(index,2)
	h.wait_wave=9999
	h.player.position=Vector2(240,640)
	h.spawn(h.current_level().boss,960)
	h.build_ui()
