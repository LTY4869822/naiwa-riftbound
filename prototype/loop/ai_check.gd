extends RefCounted
const BRAIN=preload("res://loop/boss_brain.gd")
static func run(h: Node) -> void:
	Engine.time_scale=6
	Engine.physics_ticks_per_second=180
	h.audio_enabled=false
	var results: Array=[]
	for kind in BRAIN.NAMES:
		h.choose_level(0)
		h.wait_wave=999
		h.wave=1
		h.player.position=Vector2(320,640)
		h.player.invuln=1000
		var e: Node=h.spawn(kind,960)
		e.ult_cooldown=999
		while e.action_count<9 and h.elapsed<34:
			await h.get_tree().physics_frame
			if e.action_count%3==2: h.player.position.x=260
			elif e.action_count%3==0: h.player.position.x=650
		var seen: Array=[]
		for move in e.move_history:
			if not move in seen: seen.append(move)
		results.append({"kind":kind,"moves":seen,"history":e.move_history.duplicate(),"count":e.action_count,"has_four":seen.size()==4})
		print("BOSS_ROTATION ",JSON.stringify(results[-1]))
	var f:=FileAccess.open("res://artifacts/loop-ai-check.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"runs":results,"all_four":results.all(func(r): return r.has_four),"target_invulnerable_for_observation":true,"forced_attack_selection":false},"\t"))
	f.close()
	h.get_tree().quit()
