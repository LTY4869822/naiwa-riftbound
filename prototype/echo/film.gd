extends RefCounted
const DEMO=preload("res://echo/demo.gd")
var h: Node
func frames(n: int) -> void:
	for i in n: await h.get_tree().process_frame
func jump_input(pressed: bool) -> void:
	var e:=InputEventAction.new(); e.action="jump"; e.pressed=pressed
	Input.parse_input_event(e)
func run(host: Node) -> void:
	h=host
	h.audio_enabled=true
	h.rift.presentations_enabled=false
	Profile.level=7
	h.ascension.clear()
	DEMO.jump(h); h.toast_time=0
	h.player.position=Vector2(180,640)
	await frames(12)
	Input.action_press("move_right")
	jump_input(true); await frames(2); jump_input(false)
	await frames(10)
	jump_input(true); await frames(2); jump_input(false)
	await frames(4)
	await h.capture("echo-film-air-jump")
	await frames(40)
	Input.action_release("move_right")
	DEMO.tiger(h); h.toast_time=0
	h.player.position=Vector2(220,640)
	h.player.invuln=10000
	var e: Node=h.enemies[-1]
	e.set_physics_process(false)
	e.position=Vector2(1040,640); e.state="approach"
	for i in 156:
		e.facing=-1 if i<78 else 1
		e.velocity=Vector2(e.facing*190,0)
		e.position.x+=e.velocity.x/30
		h.stage.sync(e,1.0/30)
		if i==47: await h.capture("echo-film-tiger")
		await h.get_tree().process_frame
	DEMO.relics(h); h.toast_time=0
	await frames(30)
	var menu: Node=h.rift.modal
	menu.buttons[1].grab_focus()
	await frames(35)
	menu.buttons[2].grab_focus()
	await frames(35)
	await h.capture("echo-film-relics")
	menu.activate(2)
	await frames(33)
	h.rift.offers.assign(["spring","edge","wind"])
	h.rift.offer_active=true; h.rift.show_offer()
	await frames(50)
	FileAccess.open("res://artifacts/echo-film.json",FileAccess.WRITE).store_string(JSON.stringify({"frames":Engine.get_process_frames(),"fps":30,"scenario":"Actual double-jump input events, then an explicitly staged two-direction tiger patrol for animation inspection. Relic focus and a real claim use the live UI; final healing option is seeded to show the fourth illustration. Invulnerable tiger target, no claim of a full playthrough."},"\t"))
	h.get_tree().quit()
