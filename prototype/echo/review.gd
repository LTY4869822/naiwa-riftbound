extends RefCounted
const DEMO=preload("res://echo/demo.gd")
var h: Node
var checks:=0
var failures: Array[String]=[]
var pointer_entered:=false
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); push_error(label)
func frames(n: int) -> void:
	for i in n: await h.get_tree().physics_frame
func wait(t: float) -> void: await h.get_tree().create_timer(t).timeout
func action(name: String,pressed: bool=true) -> void:
	var event:=InputEventAction.new()
	event.action=name; event.pressed=pressed
	Input.parse_input_event(event)
func pointer(at: Vector2,click: bool=false,pressed: bool=false) -> void:
	# Hidden native windows do not receive the OS mouse-enter notification.
	if not pointer_entered and h.get_viewport().gui_get_hovered_control()==null:
		h.get_viewport().notify_mouse_entered()
		pointer_entered=true
	if click:
		var e:=InputEventMouseButton.new()
		e.position=at; e.global_position=at; e.button_index=MOUSE_BUTTON_LEFT; e.pressed=pressed
		e.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0
		Input.parse_input_event(e)
	else:
		var e:=InputEventMouseMotion.new()
		e.position=at; e.global_position=at; e.relative=Vector2(20,0)
		Input.parse_input_event(e)
func run(host: Node) -> void:
	h=host
	h.audio_enabled=false
	h.get_window().size=Vector2i(1280,800)
	h.rift.presentations_enabled=false
	h.arena.enabled=false
	Profile.level=7
	DEMO.jump(h)
	var p: Node=h.player
	p.position=Vector2(120,640)
	await frames(6)
	check(p.is_on_floor() and p.jumps_used==0,"ground starts with both jumps")
	Input.action_press("move_right")
	action("jump"); await frames(3); action("jump",false)
	print("ECHO_FIRST_JUMP ",p.position," ",p.velocity," used=",p.jumps_used," grounded=",p.is_on_floor())
	check(p.jumps_used==1 and p.velocity.y<0 and p.position.y<640,"first actual input launches from floor")
	await wait(.25)
	var vy: float=p.velocity.y
	action("jump"); await frames(2); action("jump",false)
	check(p.jumps_used==2 and p.velocity.y<vy-100,"second actual input relaunches in air")
	check(p.velocity.x>200,"air jump preserves horizontal movement")
	check(p.invuln==0,"air jump grants no damage immunity")
	var age: float=p.elapsed
	vy=p.velocity.y
	action("jump"); await frames(2); action("jump",false)
	check(p.jumps_used==2 and p.velocity.y>vy and p.elapsed>age,"third input cannot create another launch")
	Input.action_release("move_right")
	await wait(.15)
	await h.capture("echo-double-jump")
	await wait(1.0)
	check(p.is_on_floor() and p.jumps_used==0,"landing refills both jumps")
	action("jump"); await frames(2); action("jump",false)
	check(p.jumps_used==1 and p.velocity.y<0,"jump works again after landing")
	h.arena.platform(400,550,180,"wood")
	p.position=Vector2(400,420); p.velocity=Vector2.ZERO; p.jumps_used=2; p.state="idle"
	await wait(.7)
	check(p.is_on_floor() and absf(p.position.y-550)<1 and p.jumps_used==0,"landing on a one-way platform restores both jumps")
	Input.action_press("move_right"); await wait(.58); Input.action_release("move_right")
	check(not p.is_on_floor() and p.jumps_used==1,"walking off a real platform consumes ground jump after coyote time")
	action("jump"); await frames(3); action("jump",false)
	check(p.jumps_used==2 and p.velocity.y<0,"falling off a real platform still allows the air jump")
	p.set_physics_process(false)
	p.state="hurt"; p.jumps_used=1
	check(not p.try_jump() and p.jumps_used==1,"jump cannot cancel hitstun")
	p.state="idle"; p.jumps_used=0; p.coyote=.05
	check(p.try_jump() and p.jumps_used==1,"coyote jump leaves the second jump available")
	p.state="idle"; p.jumps_used=1; p.coyote=0
	check(p.try_jump() and p.jumps_used==2,"ledge fall retains one air jump")
	p.state="dash"; p.elapsed=.1; p.jumps_used=1; p.velocity.x=570
	check(p.try_jump() and p.velocity.x==570,"late dash can cancel into air jump without killing momentum")
	h.ascension.phase="empowered"; h.ascension.remaining=10
	p.state="idle"; p.jumps_used=1
	check(p.try_jump() and p.jumps_used==2,"awakened form can also double jump")
	h.ascension.clear()
	# New locomotion uses eight independent poses, one scale and complete alpha bounds.
	h.choose_level(0,2); DEMO.quiet(h)
	h.player.position=Vector2(180,640)
	var boss: Node=h.spawn("zheng",880)
	h.rift.finish_arrival(); boss.set_physics_process(false)
	var rig: Node=h.stage.actors[boss.get_instance_id()]
	check(rig.run_frames.size()==8 and rig.frames.size()==8,"tiger has dedicated eight-frame run and combat atlases")
	var textures: Array=[]
	for facing in [-1,1]:
		boss.facing=facing; boss.state="approach"; boss.velocity.x=facing*200
		for i in 8:
			rig.run_clock=i+.01
			rig.drive(.001,boss)
			check(is_equal_approx(absf(rig.sprite.scale.x),absf(rig.sprite.scale.y)),"tiger pose has equal horizontal and vertical scale")
			check(absf(rig.sprite.position.y+float(rig.run_frames[i].bottom)*rig.factor)<.001,"tiger run pose shares exact ground contact")
			if facing==-1: textures.append(rig.sprite.texture)
	check(textures.size()==8 and textures[0]!=textures[3] and textures[0]!=textures[7],"locomotion uses all authored run drawings")
	await h.capture("echo-tiger-run")
	# Live GUI navigation, focus-only preview, space commit and no gameplay bleed.
	DEMO.relics(h)
	await wait(.65)
	var menu: Node=h.rift.modal
	check(h.rift.offer_active and not h.playing() and menu.buttons.size()==3,"new UI uses real pending relic pause")
	check(menu.buttons[0].has_focus(),"first valid card owns keyboard focus")
	var ranks: Dictionary=h.rift.ranks.duplicate()
	action("ui_right"); await frames(2); action("ui_right",false)
	check(menu.focused==1 and menu.buttons[1].has_focus(),"right input moves focus exactly once")
	check(h.rift.ranks==ranks,"focus does not grant a relic")
	await wait(.35)
	await h.capture("echo-relics-1280")
	var focused_id: String=h.rift.offers[1]
	h.build_ui(); await wait(.1)
	menu=h.rift.modal
	check(menu.buttons[1].has_focus(),"remount restores focus by relic identity")
	action("jump"); await frames(3); action("jump",false)
	check(not h.rift.offer_active and h.rift.rank(focused_id)==1,"space confirms one real relic")
	check(h.player.jumps_used==0 and h.player.jump_buffer==0,"space confirmation cannot leak into a player jump")
	check(not h.rift.pick(focused_id) and h.rift.rank(focused_id)==1,"duplicate accept cannot grant another copy")
	# Actual pointer hit test on the animated full-card control.
	DEMO.relics(h); await wait(.65)
	menu=h.rift.modal
	var at: Vector2=menu.buttons[2].get_global_transform()*Vector2(180,280)
	pointer(at); await frames(3)
	print("ECHO_POINTER ",at," focus=",menu.focused," hovered=",h.get_viewport().gui_get_hovered_control())
	check(menu.buttons[2].has_focus(),"moving pointer and keyboard share one focus")
	var id: String=h.rift.offers[2]
	pointer(at,true,true); await frames(1)
	print("ECHO_PRESS down=",menu.buttons[2].down," native=",menu.buttons[2].button_pressed," cancelled=",menu.buttons[2].cancelled)
	pointer(at,true,false); await frames(2)
	print("ECHO_CLICK offer=",h.rift.offer_active," rank=",h.rift.rank(id))
	check(not h.rift.offer_active and h.rift.rank(id)==1,"full-card pointer release commits correct relic")
	DEMO.relics(h); await wait(.65)
	menu=h.rift.modal
	at=menu.buttons[0].get_global_transform()*Vector2(180,280)
	pointer(at); pointer(at,true,true); await frames(1)
	menu.clear_press()
	pointer(at,true,false); await frames(2)
	check(h.rift.offer_active and not menu.buttons[0].down,"window blur cancels a pending pointer press")
	h.reduce_motion=true; Preferences.large_text=true
	h.get_window().size=Vector2i(960,600)
	await wait(.15)
	for b in menu.buttons:
		check(b.rotation==0 and b.scale==Vector2.ONE and b.position==b.base,"reduced motion removes rotation, lift and scaling")
	await h.capture("echo-relics-960-large-reduced")
	Preferences.large_text=false; h.reduce_motion=false
	h.get_window().size=Vector2i(1920,1080)
	await wait(.25)
	await h.capture("echo-relics-1920")
	check(not Profile.save_enabled and not Wardrobe.save_enabled and not Ascension.save_enabled,"review never writes formal progress")
	FileAccess.open("res://artifacts/echo-checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"input_events":"Engine Input.parse_input_event, including actual mouse hit tests","images":["echo-double-jump.png","echo-tiger-run.png","echo-relics-1280.png","echo-relics-960-large-reduced.png","echo-relics-1920.png"]},"\t"))
	print("ECHO_CHECKS ",checks," failures=",failures.size())
	h.get_tree().quit(0 if failures.is_empty() else 1)
