extends RefCounted
static func run(h: Node) -> void:
	if not h.test_mode or Profile.save_enabled: h.get_tree().quit(1); return
	h.audio_enabled=true
	h.get_window().size=Vector2i(1280,800)
	preload("res://loot/demo.gd").setup(h)
	var events: Array=[]
	var first_frame:=Engine.get_process_frames()
	h.journey.pickup_audio.played.connect(func(kind: String, variant: int): events.append({"kind":kind,"variant":variant,"frame":Engine.get_process_frames(),"x":h.player.position.x}))
	var last_coins:=0
	var heal_shot:=false
	for i in 300:
		if i==15: await h.capture("loot-v3-field")
		if i==55: Input.action_press("move_right")
		if h.player.position.x>1120: Input.action_release("move_right")
		if h.journey.picked_coins>last_coins:
			last_coins=h.journey.picked_coins
			if last_coins<20: await h.capture("loot-v3-coin-pickup")
		if h.journey.picked_heals>0 and not heal_shot:
			heal_shot=true
			await h.capture("loot-v3-heal-pickup")
		await h.get_tree().process_frame
	Input.action_release("move_right")
	var data:={"events":events,"start_frame":first_frame,"end_frame":Engine.get_process_frames(),"coins_picked":h.journey.picked_coins,"heals_picked":h.journey.picked_heals,"hp":h.player.hp,"max_hp":Profile.max_health(),"audio_driver":AudioServer.get_driver_name(),"scenario":"Isolated seeded loot field, actual movement/proximity collection and real engine audio. Not a combat playthrough."}
	var f:=FileAccess.open("res://artifacts/loot-v3-film.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(data,"\t"))
	f.close()
	print("LOOT_FILM ",JSON.stringify(data))
	h.get_tree().quit(0 if events.size()==4 and h.journey.picked_coins==58 and h.journey.picked_heals==1 else 1)
