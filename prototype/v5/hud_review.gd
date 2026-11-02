extends RefCounted
## Isolated verification of the native battle instruments, using real actor signals.
static func settle(h: Node, seconds: float = 0.2) -> void:
	await h.get_tree().create_timer(seconds).timeout

static func note(checks: Array[String], condition: bool, text: String) -> void:
	checks.append(("PASS " if condition else "FAIL ")+text)

static func publish(h: Node, checks: Array[String]) -> void:
	var failed:=0
	for line in checks:
		print(line)
		if line.begins_with("FAIL"): failed+=1
	var file:=FileAccess.open("res://artifacts/hud-checks.txt",FileAccess.WRITE)
	file.store_string("\n".join(checks)+"\nFailures=%d\n" % failed)
	print("HUD_CHECKS ",checks.size()," failures=",failed)
	h.get_tree().quit(failed)

static func signal_player(h: Node) -> void:
	h.player.changed.emit()

static func reset_actor(h: Node) -> void:
	h.player.state="idle"
	h.player.dead=false
	h.player.invuln=0
	h.player.elapsed=0
	h.player.combo=0
	h.player.dash_cd=0
	h.player.velocity=Vector2.ZERO

static func run(h: Node) -> void:
	var checks: Array[String]=[]
	if not h.test_mode or Profile.save_enabled:
		note(checks,false,"review requires isolated profile")
		publish(h,checks)
		return
	h.audio_enabled=false
	h.reduce_motion=false
	Profile.level=3
	h.start_battle()
	await h.get_tree().physics_frame
	h.set_process(false)
	h.player.set_physics_process(false)
	h.player.position=Vector2(330,640)
	reset_actor(h)
	h.player.focus=36
	h.player.stamina=100
	h.wave=1
	for spec in [["melee",740.0],["melee",920.0],["ranged",1120.0]]:
		var enemy: Node=h.spawn(spec[0],spec[1])
		enemy.set_physics_process(false)
		h.stage.sync(enemy,1.0/60.0)
	h.stage.sync(h.player,1.0/60.0)
	h.view.visible=true
	h.view.position=Vector2.ZERO
	h.toast_time=0
	h.refresh_hud()
	await settle(h,0.45)
	var widget: Node=h.battle_hud
	note(checks,is_instance_valid(widget),"native battle HUD is mounted")
	if not is_instance_valid(widget):
		publish(h,checks)
		return
	await h.capture("hud-battle")
	note(checks,int(widget.snapshot.hp)==h.player.hp and int(widget.snapshot.max_hp)==Profile.max_health(),"initial health binds to actual profile and actor")
	note(checks,absf(widget.hp_display-1.0)<0.002 and absf(widget.hp_trail-1.0)<0.002,"initial health has no false damage animation")
	var original_hp: int=h.player.hp
	var accepted: bool=h.player.take_hit(24,-1)
	await settle(h,0.16)
	note(checks,accepted and int(widget.snapshot.hp)==original_hp-24,"real take_hit signal updates displayed health")
	note(checks,widget.hp_trail>widget.hp_display+0.02,"damage leaves a delayed trailing segment")
	await h.capture("hud-damage")
	await settle(h,1.8)
	var target: float=float(h.player.hp)/Profile.max_health()
	note(checks,absf(widget.hp_display-target)<0.003 and absf(widget.hp_trail-target)<0.003,"health and trail converge to exact real ratio")
	reset_actor(h)
	h.player.hp=int(floor(Profile.max_health()*0.30))
	signal_player(h)
	await settle(h,0.35)
	note(checks,widget.low_health,"low health activates at thirty percent")
	await h.capture("hud-low-health")
	h.player.hp=int(floor(Profile.max_health()*0.30))+1
	signal_player(h)
	note(checks,not widget.low_health,"low-health warning clears above threshold")
	h.player.hp=Profile.max_health()
	for stamina in [27.9,28.0,31.9,32.0]:
		h.player.stamina=stamina
		signal_player(h)
		note(checks,widget.heavy_ready==(stamina>=28.0) and widget.dash_ready==(stamina>=32.0),"real stamina thresholds at %.1f" % stamina)
	h.player.stamina=100
	Profile.level=1
	h.player.hp=Profile.max_health()
	h.player.focus=100
	signal_player(h)
	note(checks,widget.skill_locked and not widget.skill_ready,"level-one skill stays locked with full focus")
	Profile.level=3
	h.player.hp=Profile.max_health()
	h.player.focus=59.9
	signal_player(h)
	note(checks,not widget.skill_locked and not widget.skill_ready,"focus below sixty is not ready")
	h.player.focus=60
	signal_player(h)
	note(checks,widget.skill_ready,"sixty focus readies the unlocked skill")
	for state in ["hurt","skill"]:
		h.player.state=state
		signal_player(h)
		note(checks,not widget.skill_ready,"skill cannot be shown ready while "+state)
	reset_actor(h)
	h.player.focus=82
	h.player.stamina=88
	signal_player(h)
	await settle(h,0.7)
	await h.capture("hud-ready")
	h.player.stamina=100
	h.player.dash()
	note(checks,absf(h.player.dash_cd-0.55)<0.001 and not widget.dash_ready,"real dash starts its half-second cooldown")
	await settle(h,0.1)
	await h.capture("hud-dash")
	reset_actor(h)
	h.player.state="attack"
	for combo in 3:
		h.player.combo=combo
		var heavy_threshold: float=h.player.DURATIONS[combo]-0.12
		h.player.elapsed=heavy_threshold-0.01
		signal_player(h)
		var before: bool=widget.heavy_ready
		h.player.elapsed=heavy_threshold+0.01
		signal_player(h)
		note(checks,not before and widget.heavy_ready,"heavy readiness matches combo %d recovery window" % combo)
		var dash_threshold: float=h.player.STARTUP[combo]+h.player.ACTIVE[combo]
		h.player.elapsed=dash_threshold-0.01
		signal_player(h)
		before=widget.dash_ready
		h.player.elapsed=dash_threshold+0.01
		signal_player(h)
		note(checks,not before and widget.dash_ready,"dash readiness matches combo %d active window" % combo)
	reset_actor(h)
	h.player.state="skill"
	var cancel_at: float=h.player.SKILL_DASH_CANCEL if h.player.get("SKILL_DASH_CANCEL")!=null else 0.3
	h.player.elapsed=cancel_at-0.01
	signal_player(h)
	var dash_before: bool=widget.dash_ready
	h.player.dash()
	var actual_before: bool=h.player.state=="skill"
	h.player.elapsed=cancel_at+0.01
	signal_player(h)
	var dash_after: bool=widget.dash_ready
	h.player.dash()
	note(checks,not dash_before and actual_before and dash_after and h.player.state=="dash","dash readiness matches the actual skill cancellation boundary")
	reset_actor(h)
	h.player.hp=Profile.max_health()
	h.player.stamina=94
	h.player.focus=82
	h.player.position=Vector2(555,640)
	h.stage.sync(h.player,1.0/60.0)
	for e in h.enemies.duplicate():
		if is_instance_valid(e):
			h.stage.remove_actor(e)
			e.queue_free()
	h.enemies.clear()
	h.wave=2
	h.kills=3
	var boss: Node=h.spawn("boss",935)
	boss.set_physics_process(false)
	boss.cooldown=100
	h.stage.sync(boss,1.0/60.0)
	h.refresh_hud()
	await settle(h,0.5)
	note(checks,widget.parts.boss.visible and widget.snapshot.boss_alive and int(widget.snapshot.boss_max)==boss.maximum,"boss bar appears only for an actual boss")
	boss.begin_attack()
	await settle(h,0.15)
	note(checks,widget.snapshot.boss_state=="tell","boss windup state updates by signal")
	await h.capture("hud-boss")
	boss.take_hit(82,1,true)
	await settle(h,0.15)
	note(checks,int(widget.snapshot.boss_hp)==boss.hp and widget.snapshot.boss_state=="stunned","boss damage and break state are real")
	note(checks,widget.boss_trail>widget.boss_display+0.01,"boss damage has a delayed trailing segment")
	await h.capture("hud-boss-break")
	boss.dead=true
	h.refresh_hud()
	note(checks,not widget.parts.boss.visible and not widget.snapshot.boss_alive,"boss instruments hide when the boss is gone")
	boss.dead=false
	h.refresh_hud()
	h.reduce_motion=true
	h.player.hp=40
	signal_player(h)
	await settle(h,0.1)
	note(checks,absf(widget.hp_display-widget.hp_trail)<0.001,"reduced motion removes the delayed health trail")
	h.reduce_motion=false
	h.player.hp=Profile.max_health()
	signal_player(h)
	var hero: Node=h.player
	var before_hp: int=h.player.hp
	h.toggle_pause()
	await settle(h,0.2)
	await h.capture("hud-pause")
	h.toggle_pause()
	widget=h.battle_hud
	note(checks,h.player==hero and h.player.hp==before_hp and h.mode=="battle" and not h.paused,"pause resumes the same actor and health")
	h.camp()
	await settle(h,0.3)
	h.enter_battle()
	h.view.visible=true
	widget=h.battle_hud
	await settle(h,0.3)
	note(checks,h.player==hero and h.player.hp==before_hp and widget.snapshot.hp==before_hp,"camp and continue preserve the same actor and vitals")
	for dimensions in [Vector2i(1120,630),Vector2i(960,600)]:
		h.get_window().size=dimensions
		await settle(h,0.4)
		widget=h.battle_hud
		var all_fit:=true
		var root_rect:=Rect2(Vector2(-1,-1),widget.size+Vector2(2,2))
		for name in ["vitals","location","boss","dock","help","loot"]:
			var part: Control=widget.parts[name]
			if not root_rect.encloses(Rect2(part.position,part.size)): all_fit=false
		note(checks,h.get_window().size==dimensions and all_fit,"anchored instruments fit %dx%d" % [dimensions.x,dimensions.y])
		await h.capture("hud-"+("wide" if dimensions.x==1120 else "small"))
	note(checks,not Profile.save_enabled and h.test_mode,"review cannot change the formal profile or preferences")
	publish(h,checks)
