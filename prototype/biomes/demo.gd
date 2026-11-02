extends RefCounted
static func setup(h: Node) -> void:
	Profile.level=7
	Ascension.energy=0
	h.get_window().title="奶蛙 · 幻彩四境 / 十二关新版（隔离试玩）"
	h.get_window().size=Vector2i(1280,800)
	h.choose_level(0,0)
	h.open_route()
	h.toast("新版四境 · F1–F12 可直接预览十二关；首页地图可从第一关连续挑战")
static func room(h: Node, index: int) -> void:
	Ascension.energy=0
	h.choose_level(floori(index/3.0),index%3)
	h.toast("第 %d/12 关 · %s · 正常关卡配置" % [index+1,h.current_level().chapter_title])
