extends RefCounted

func run(h: Node) -> void:
	Profile.level=3
	h.start_battle()
	h.set_process(false)
	h.ultimate.set_process(false)
	h.player.set_physics_process(false)
	h.wait_wave=10000
	h.toast_time=0
	h.toast_text=""
	h.player.focus=100
	h.player.position=Vector2(300,640)
	var beetle: Node=h.spawn("beetle",610)
	var mage: Node=h.spawn("shaman",970)
	for e in h.enemies:
		e.set_physics_process(false)
		h.stage.sync(e,0.001)
	await h.get_tree().process_frame
	var p: Node=h.player
	var u: Node=h.ultimate
	p.skill()
	p.step(0.34)
	u.advance(0.01)
	h.refresh_hud()
	h.fx_node.queue_redraw()
	await h.capture("ultimate-01-charge")
	p.step(0.15)
	u.advance(0.07)
	h.refresh_hud()
	await h.capture("ultimate-02-release")
	for i in 4:
		h.hitstop=0
		u.advance(0.025)
	u.queue_redraw()
	h.refresh_hud()
	h.fx_node.queue_redraw()
	await h.capture("ultimate-03-impact")
	for i in 5:
		h.hitstop=0
		u.advance(0.025)
	h.refresh_hud()
	await h.capture("ultimate-04-pierce")
	u.clear()
	h.hitstop=0
	p.position.x=1060
	p.facing=-1
	p.state="idle"
	p.focus=100
	p.skill()
	p.step(0.49)
	u.advance(0.11)
	h.refresh_hud()
	await h.capture("ultimate-05-left")
	print("ULTIMATE_REVIEW captured charge, release, impact, travel, mirrored cast")
	h.get_tree().quit()
