extends RefCounted
const C=preload("res://biomes/content.gd")
static func run(h: Node) -> void:
	if not h.test_mode or Profile.save_enabled: h.get_tree().quit(1); return
	h.audio_enabled=false
	h.rift.presentations_enabled=false
	h.arena.enabled=false
	Engine.time_scale=6
	Engine.physics_ticks_per_second=180
	Profile.level=7
	var runs: Array=[]
	for map in 4:
		for chapter in 3:
			for kind in C.ROSTERS[map]:
				h.choose_level(map,chapter)
				h.wait_wave=99999
				h.wave=1
				h.player.position=Vector2(350,640)
				h.player.invuln=10000
				var e: Node=h.spawn(kind,640)
				while e.action_count<6 and h.elapsed<30:
					await h.get_tree().physics_frame
					if e.state=="approach" and absf(e.position.x-h.player.position.x)>620: h.player.position.x=clampf(e.position.x-e.facing*300,120,1160)
				var seen: Array=[]
				for id in e.move_history:
					if not id in seen: seen.append(id)
				var result:={"map":map,"chapter":chapter,"kind":kind,"actions":e.action_count,"variants":seen,"seconds":h.elapsed,"passed":seen.size()==chapter+1 and e.action_count>=6}
				runs.append(result)
				print("BIOME_AI ",JSON.stringify(result))
	var passed: bool=runs.all(func(r): return r.passed)
	FileAccess.open("res://artifacts/biome-ai.json",FileAccess.WRITE).store_string(JSON.stringify({"runs":runs,"passed":passed,"invulnerable_target_for_observation":true,"forced_move_selection":false},"\t"))
	h.get_tree().quit(0 if passed else 1)
