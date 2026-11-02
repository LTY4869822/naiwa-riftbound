extends RefCounted

static func press(h: Node, action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	h.player._unhandled_input(event)

static func run(h: Node) -> void:
	h.audio_enabled = false
	Profile.level = 3
	Engine.time_scale = 6
	h.start_battle()
	while not h.over and h.elapsed<75:
		await h.get_tree().physics_frame
	var passive_defeat: bool = h.over and not h.won
	var passive_time: float = h.elapsed
	h.start_battle()
	var decision_time: float = 0
	while not h.over and h.elapsed<120:
		await h.get_tree().physics_frame
		if h.hitstop>0: continue
		var p: Node = h.player
		var target: Node = null
		var nearest: float = 99999
		for e in h.enemies:
			if not is_instance_valid(e) or e.dead: continue
			var score: float = absf(e.position.x-p.position.x)-(180 if e.kind=="ranged" else 0)
			if score<nearest:
				nearest = score
				target = e
		Input.action_release("move_left")
		Input.action_release("move_right")
		if target==null: continue
		var dx: float = target.position.x-p.position.x
		if absf(dx)>90:
			Input.action_press("move_right" if dx>0 else "move_left")
		else:
			p.facing = 1 if dx>0 else -1
		decision_time -= 1.0/60
		if target.state=="tell" and target.timer>target.windup_duration()*0.65:
			if p.state!="attack": press(h,"dash")
		if decision_time<=0:
			if p.focus>=60: press(h,"skill")
			elif target.boss and target.state=="tell" and p.stamina>=28: press(h,"heavy")
			else: press(h,"attack")
			decision_time = 0.11
		for bullet in h.projectiles:
			if absf(bullet.pos.x-p.position.x)<140 and p.is_on_floor(): press(h,"jump")
	Input.action_release("move_left")
	Input.action_release("move_right")
	var active_win: bool = h.over and h.won
	var text: String = "Passive defeat=%s; time=%.1fs\nActive controller victory=%s; time=%.1fs; hp=%d; wave=%d; kills=%d\n" % [passive_defeat,passive_time,active_win,h.elapsed,h.player.hp,h.wave,h.kills]
	var file := FileAccess.open("res://artifacts/v3-balance.txt",FileAccess.WRITE)
	file.store_string(text)
	print(text)
	h.get_tree().quit(0 if passive_defeat and active_win else 1)
