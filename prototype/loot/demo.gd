extends RefCounted
## Explicitly seeded, isolated presentation area; actual pickup/economy path.
static func setup(h: Node) -> void:
	if not h.test_mode or Profile.save_enabled: return
	Profile.level=5
	h.choose_level(0)
	h.wait_wave=9999
	h.wave=1
	h.player.position=Vector2(200,640)
	h.player.hp=54
	h.training.objective=""
	h.training.hint_time=9999
	h.training.label.text="A / D 走近拾取 · 金币叮响 / 药露回复 · F5 补充展示 · Tab 返回营地"
	h.journey.next_drop=4
	for i in 3:
		h.journey.drops.append({"id":i+1,"run":h.run_reward_id,"type":"coin","amount":[8,10,40][i],"pos":Vector2(460+i*170,617),"velocity":Vector2.ZERO,"age":1.0,"retry":0.0})
	h.journey.drops.append({"id":4,"run":h.run_reward_id,"type":"heal","pos":Vector2(1040,590),"velocity":Vector2.ZERO,"age":1.0,"retry":0.0})
	h.toast("拾取展示场 · 这里预置了掉落物；Tab 可回营地进入正常三段连战")
	h.refresh_hud()

static func run(h: Node) -> void:
	h.get_window().title="奶蛙 · 金币与翡翠药露拾取展示（隔离试玩）"
	setup(h)
