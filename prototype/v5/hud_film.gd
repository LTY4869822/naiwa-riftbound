extends RefCounted
## Real GPU capture of deliberate HUD states, not a claim of autonomous combat play.
const FPS:=30
const DIR:="res://artifacts/hud-demo-frames/"

static func mark(state: Dictionary, name: String) -> void:
	state.events.append({"name":name,"frame":state.frame,"seconds":float(state.frame)/FPS})

static func tick_presented_states(h: Node) -> void:
	# Actor movement/AI is frozen for a steady composition. Only existing timers are
	# advanced here so cooldowns and short protection display their real duration.
	var actor: Node=h.player
	actor.invuln=maxf(0,actor.invuln-1.0/FPS)
	actor.dash_cd=maxf(0,actor.dash_cd-1.0/FPS)
	actor.elapsed+=1.0/FPS
	if actor.state=="dash" and actor.elapsed>0.18: actor.state="idle"
	if actor.state=="hurt" and actor.elapsed>0.32: actor.state="idle"
	actor.changed.emit()
	h.stage.sync(actor,1.0/FPS)
	for enemy in h.enemies:
		if not is_instance_valid(enemy): continue
		enemy.timer+=1.0/FPS
		if enemy.state=="stunned" and enemy.timer>0.32: enemy.transition("approach")
		h.stage.sync(enemy,1.0/FPS)
	for i in range(h.effects.size()-1,-1,-1):
		h.effects[i].life-=1.0/FPS
		if h.effects[i].life<=0: h.effects.remove_at(i)
	h.fx_node.queue_redraw()

static func record(h: Node, state: Dictionary, seconds: float) -> void:
	for i in range(roundi(seconds*FPS)):
		tick_presented_states(h)
		await RenderingServer.frame_post_draw
		var bitmap: Image=h.get_viewport().get_texture().get_image()
		bitmap.save_jpg(DIR+"frame_%05d.jpg" % state.frame,0.91)
		state.image=bitmap
		state.frame+=1

static func shot(state: Dictionary, name: String) -> void:
	if state.image!=null: state.image.save_png("res://artifacts/hud-demo-"+name+".png")

static func run(h: Node) -> void:
	if not h.test_mode or Profile.save_enabled:
		push_error("HUD film requires --slice-test isolation")
		h.get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	h.audio_enabled=false
	h.reduce_motion=false
	Profile.level=3
	h.start_battle()
	await h.get_tree().physics_frame
	h.set_process(false)
	h.player.set_physics_process(false)
	h.player.position=Vector2(330,640)
	h.player.velocity=Vector2.ZERO
	h.player.hp=Profile.max_health()
	h.player.stamina=100
	h.player.focus=36
	h.player.state="idle"
	h.player.invuln=0
	h.wave=1
	for spec in [["melee",740.0],["melee",920.0],["ranged",1120.0]]:
		var enemy: Node=h.spawn(spec[0],spec[1])
		enemy.set_physics_process(false)
		h.stage.sync(enemy,1.0/FPS)
	h.stage.sync(h.player,1.0/FPS)
	h.view.visible=true
	h.view.position=Vector2.ZERO
	h.toast_time=0
	h.refresh_hud()
	var state: Dictionary={"frame":0,"events":[],"image":null}
	mark(state,"full_health_and_normal_focus")
	await record(h,state,0.7)
	shot(state,"full")
	mark(state,"real_take_hit_31_damage_delayed_trail")
	assert(h.player.take_hit(31,-1))
	await record(h,state,0.17)
	shot(state,"damage")
	await record(h,state,1.23)
	mark(state,"real_take_hit_to_low_health")
	assert(h.player.take_hit(60,-1))
	await record(h,state,0.8)
	shot(state,"low")
	mark(state,"present_recovered_health_via_actor_changed")
	h.player.hp=Profile.max_health()
	h.player.state="idle"
	h.player.invuln=0
	h.player.changed.emit()
	await record(h,state,0.9)
	mark(state,"real_dash_spends_stamina_and_starts_actual_cooldown")
	h.player.stamina=55
	h.player.dash_cd=0
	h.player.state="idle"
	h.player.dash()
	await record(h,state,0.17)
	shot(state,"dash")
	await record(h,state,0.63)
	mark(state,"focus_59_not_ready")
	h.player.stamina=92
	h.player.focus=59
	h.player.changed.emit()
	await record(h,state,0.4)
	mark(state,"focus_60_ready_glow_and_ring")
	h.player.focus=60
	h.player.changed.emit()
	await record(h,state,0.85)
	shot(state,"ready")
	for enemy in h.enemies.duplicate():
		if is_instance_valid(enemy):
			h.stage.remove_actor(enemy)
			enemy.queue_free()
	h.enemies.clear()
	h.wave=2
	h.kills=3
	h.player.position=Vector2(555,640)
	h.player.focus=82
	h.player.stamina=94
	h.stage.sync(h.player,1.0/FPS)
	var boss: Node=h.spawn("boss",935)
	boss.set_physics_process(false)
	h.stage.sync(boss,1.0/FPS)
	h.refresh_hud()
	mark(state,"boss_instruments_present_for_actual_boss")
	await record(h,state,0.7)
	mark(state,"boss_real_begin_attack_windup")
	boss.begin_attack()
	await record(h,state,0.6)
	shot(state,"boss")
	mark(state,"boss_real_heavy_hit_break_and_delayed_trail")
	boss.take_hit(96,1,true)
	await record(h,state,0.17)
	shot(state,"break")
	await record(h,state,1.23)
	mark(state,"settled_end_state")
	await record(h,state,0.9)
	shot(state,"end")
	var metadata: Dictionary={
		"label":"HUD state demonstration",
		"capture":"Every frame is a Godot GPU viewport readback. Actor movement and AI are frozen for composition; damage and dash use real actor methods, and health/focus recovery is presented through explicit state signals.",
		"fps":FPS,"frames":state.frame,"duration_seconds":float(state.frame)/FPS,
		"width":state.image.get_width(),"height":state.image.get_height(),
		"profile_save_enabled":Profile.save_enabled,"events":state.events,
	}
	var file:=FileAccess.open("res://artifacts/hud-demo-metadata.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(metadata,"\t"))
	file.close()
	print("HUD_FILM frames=",state.frame," fps=",FPS," duration=",float(state.frame)/FPS)
	h.get_tree().quit()
