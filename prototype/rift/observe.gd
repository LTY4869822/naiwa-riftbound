extends RefCounted
const BRAIN=preload("res://loop/boss_brain.gd")
static func run(h: Node) -> void:
	if not h.test_mode or Profile.save_enabled: h.get_tree().quit(1); return
	h.audio_enabled=false
	h.rift.presentations_enabled=false
	Engine.time_scale=6
	Engine.physics_ticks_per_second=180
	Profile.level=7
	var runs: Array=[]
	for kind in BRAIN.NAMES:
		h.choose_level(0,2)
		h.wait_wave=9999
		h.wave=3
		h.player.invuln=10000
		var e: Node=h.spawn(kind,960)
		e.combat_phase=3
		e.hp=roundi(e.maximum*.29)
		e.enraged=true
		e.ult_cooldown=9999
		while e.action_count<14 and h.elapsed<65:
			await h.get_tree().physics_frame
			if e.state=="approach": h.player.position.x=[240.0,650.0,1030.0][e.action_count%3]
		var seen: Array=[]
		for move in e.move_history:
			if not move in seen: seen.append(move)
		var no_repeat:=true
		for i in range(1,e.move_history.size()):
			if e.move_history[i]==e.move_history[i-1]: no_repeat=false
		runs.append({"kind":kind,"moves":seen,"history":e.move_history.duplicate(),"six_moves":seen.size()==6,"no_consecutive_repeat":no_repeat,"maximum_hp":e.maximum,"seconds":h.elapsed})
		print("RIFT_AI ",JSON.stringify(runs[-1]))
	var all_six: bool=runs.all(func(r): return r.six_moves and r.no_consecutive_repeat)
	var f:=FileAccess.open("res://artifacts/rift-ai.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"runs":runs,"all_six":all_six,"target_invulnerable_for_observation":true,"phase_three_fixture":true,"forced_move_selection":false,"level":7},"\t"))
	f.close()
	h.get_tree().quit(0 if all_six else 1)
