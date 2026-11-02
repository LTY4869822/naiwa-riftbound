extends RefCounted
const QUIET=preload("res://echo/demo.gd")
var h: Node
var captions: Array[String]=[]
func frames(n: int) -> void:
	for i in n: await h.get_tree().process_frame
func action(name: String) -> void:
	var e:=InputEventAction.new(); e.action=name; e.pressed=true; Input.parse_input_event(e)
	await frames(1)
	e=InputEventAction.new(); e.action=name; e.pressed=false; Input.parse_input_event(e)
func stage(kind: String,map_index: int=0,left: bool=false) -> Node:
	h.choose_level(map_index,0); QUIET.quiet(h)
	h.player.position=Vector2(790 if left else 430,640)
	h.player.facing=-1 if left else 1
	var e: Node=h.spawn(kind,655 if left else 565)
	h.rift.finish_arrival()
	e.maximum=8000; e.hp=8000; e.facing=1 if left else -1
	e.velocity=Vector2(0,20); e.move_and_slide(); e.set_physics_process(false)
	var dummy:=preload("res://punch/dummy.gd").new(); dummy.host=h; dummy.target=weakref(e); h.add_child(dummy)
	e.state="approach"
	h.player.focus=100
	return e
func label(value: String) -> void:
	h.toast(value); captions.append(value)
func run(host: Node) -> void:
	h=host; h.rift.presentations_enabled=false; h.audio_enabled=true
	Profile.level=7; Ascension.energy=0
	var e:=stage("melee")
	label("节奏连击 · 金色火花 → 薄荷追击 → 重拳震地")
	await frames(15)
	await action("attack"); await frames(5); await action("attack"); await frames(11); await action("attack")
	await frames(11); await h.capture("punch-film-combo")
	await frames(42)
	# Resume the fixture between attacks so its real flash timer returns to normal.
	e.set_physics_process(true); e.cooldown=10; await frames(8)
	e=stage("beetle")
	label("重拳破甲 · 硬朗爆点、短暂停顿、碎石落地")
	await frames(15); await action("heavy"); await frames(8)
	await h.capture("punch-film-break"); await frames(13)
	await h.capture("punch-film-ring"); await frames(35)
	e=stage("crystal_crab",1,true)
	label("左右方向跟随命中 · 亮色地图保持清楚")
	await frames(15); await action("heavy"); await frames(9)
	await h.capture("punch-film-left"); await frames(43)
	e=stage("zheng")
	e.position=Vector2(765,640)
	label("星核巨拳 · 命中才绽放紫霆爆点")
	await frames(15); await action("skill"); await frames(28)
	await h.capture("punch-film-ultimate"); await frames(40)
	stage("melee",2); QUIET.quiet(h)
	h.player.position=Vector2(490,640)
	label("Boss 招式落地 · 保留预警，爆发后碎石与烟尘衰减")
	h.boss_fields.cast(999,Vector2(850,640),"repertoire_zheng",.70,10,115)
	await frames(25); await h.capture("punch-film-ground"); await frames(65)
	h.rift.evade_cd=0
	label("精准闪避 · 薄荷闪光与清脆反击提示")
	h.rift.perfect_evade(); await frames(6)
	await h.capture("punch-film-evade"); await frames(35)
	FileAccess.open("res://artifacts/punch-film.json",FileAccess.WRITE).store_string(JSON.stringify({"fps":30,"captions":captions,"scenario":"Actual Input.parse_input_event combo, heavy and ultimate attacks against staged high-HP targets. One seeded floor spell and a direct precision-dodge hook demonstrate presentation. Not a normal playthrough."},"\t"))
	h.get_tree().quit()
