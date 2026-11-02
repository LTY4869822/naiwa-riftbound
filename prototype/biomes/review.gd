extends RefCounted
const C=preload("res://biomes/content.gd")
const LEVELS=preload("res://campaign/levels.gd")
const BRAIN=preload("res://loop/boss_brain.gd")
const T=preload("res://biomes/tactics.gd")
const U=preload("res://biomes/boss_skills.gd")
var h: Node
var checks:=0
var failures: Array[String]=[]
var rooms: Array=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); push_error(label)
func quiet() -> void:
	h.rift.finish_arrival()
	h.wait_wave=99999
	h.projectiles.clear()
	h.boss_fields.clear()
	for e in h.enemies:
		if is_instance_valid(e): h.stage.remove_actor(e); e.queue_free()
	h.enemies.clear()
func wait(t: float) -> void: await h.get_tree().create_timer(t).timeout
func duel(map: int,kind: String) -> Node:
	h.choose_level(map,1); quiet()
	h.player.set_physics_process(false)
	h.player.position=Vector2(400,640)
	h.player.invuln=0
	var actor: Node=h.spawn(kind,960)
	actor.set_physics_process(false)
	actor.facing=-1
	return actor
func buttons(node: Node) -> Array:
	var result: Array=[]
	if node is Button: result.append(node.title if node.get_script()==preload("res://v5/sticker_button.gd") else node.text)
	for child in node.get_children(): result.append_array(buttons(child))
	return result
func run(host: Node) -> void:
	h=host
	h.audio_enabled=false
	h.set_process(false)
	h.rift.presentations_enabled=false
	h.arena.enabled=false
	Profile.level=7
	Ascension.energy=0
	var bosses: Array=[]
	var backgrounds: Array=[]
	var all_rosters: Array=[]
	for m in 4:
		var prior_count:=0
		for kind in C.ROSTERS[m]:
			check(not kind in all_rosters,"minion exclusive to one biome: "+kind)
			all_rosters.append(kind)
		for chapter in 3:
			var d: Dictionary=LEVELS.get_stage(m,chapter)
			check(not d.boss in bosses,"unique guardian: "+str(d.boss))
			bosses.append(d.boss)
			check(not d.background in backgrounds and ResourceLoader.exists(d.background),"unique scene exists: "+str(d.id))
			backgrounds.append(d.background)
			var count:=0
			for wave in d.waves:
				for spec in wave:
					if spec[0]==d.boss: continue
					check(spec[0] in C.ROSTERS[m],"actual wave uses biome roster: "+str(d.id))
					count+=1
			check(count>prior_count and count==[6,9,13][chapter],"strict encounter escalation: "+str(d.id))
			prior_count=count
			check(d.waves[-1][0][0]==d.boss,"stage finishes with its own guardian")
			h.choose_level(m,chapter)
			quiet()
			h.player.set_physics_process(false)
			h.player.position=Vector2(180,640)
			check(h.stage.chapter_index==chapter,"scenery chapter is applied")
			var boss: Node=h.spawn(d.boss,1040)
			boss.set_physics_process(false)
			check(boss.boss,"catalog recognizes guardian: "+str(d.boss))
			var rig: Node=h.stage.actors[boss.get_instance_id()]
			check(rig.frames.size()==8 and rig.factor>0,"guardian has complete animation atlas")
			for id in 6:
				BRAIN.begin(boss,id)
				check(not boss.attack_data.name.is_empty(),"named guardian move "+str(id))
				boss.transition("active")
				BRAIN.release(boss)
				for summon in h.enemies:
					if is_instance_valid(summon) and not summon.boss: check(summon.kind in C.ROSTERS[m],"summon stays in guardian biome")
				h.projectiles.clear(); h.boss_fields.clear()
			boss.transition("approach")
			if U.TITLES.has(boss.kind):
				U.begin(boss)
				check(boss.state=="ult_tell" and not boss.ult_data.title.is_empty(),"unique middle guardian ultimate starts")
				boss.timer=1.51
				U.step(boss,.016)
				check(boss.state=="ult_active","ultimate reaches active state")
				boss.timer=3.0; U.step(boss,.016)
				boss.timer=.81; U.step(boss,.016)
				check(boss.state=="approach","ultimate recovers into live combat")
				boss.position=Vector2(1040,640)
			quiet()
			boss=h.spawn(d.boss,1060)
			boss.set_physics_process(false)
			boss.transition("approach")
			for i in 3:
				var e: Node=h.spawn(C.ROSTERS[m][i],[480.0,680.0,840.0][i])
				e.set_physics_process(false)
				e.transition("approach")
				var er: Node=h.stage.actors[e.get_instance_id()]
				check(er.frames.size()==8,"minion complete animation: "+e.kind)
				var seen: Array=[]
				for j in (chapter+1)*2:
					T.begin(e)
					if not e.move_id in seen: seen.append(e.move_id)
					T.release(e)
					e.transition("approach")
				check(seen.size()==chapter+1,"skill count escalates by room: "+e.kind)
				h.projectiles.clear(); h.boss_fields.clear()
				h.stage.sync(e,.016)
				h.stage.sync(boss,.016)
			h.wave=d.waves.size()
			h.refresh_hud()
			await wait(.08)
			await h.capture("biome-"+str(d.id))
			rooms.append({"id":d.id,"scene":d.background,"boss":d.boss,"minions":count,"skill_tier":chapter+1,"screenshot":"biome-"+str(d.id)+".png"})
	# Real player damage path and once-per-hit guard for a new melee creature.
	h.choose_level(1,2); quiet()
	h.player.set_physics_process(false)
	h.player.position=Vector2(400,640)
	h.player.invuln=0
	h.player.state="idle"
	var e: Node=h.spawn("crystal_crab",480)
	e.set_physics_process(false)
	e.facing=-1
	var before: int=h.player.hp
	T.contact(e,0,140,18)
	check(h.player.hp<before,"new creature contact damages real fighter")
	before=h.player.hp
	T.contact(e,0,140,18)
	check(h.player.hp==before,"same attack contact cannot damage twice")
	# New ultimate fields and projectiles use the actual live damage paths.
	e=duel(0,"thorn_matriarch")
	U.begin(e)
	before=h.player.hp
	h.boss_fields.advance(1.49)
	check(h.player.hp==before,"deer ultimate warning cannot damage")
	h.boss_fields.advance(.75)
	check(h.player.hp<before,"deer delayed center thorn damages its locked target")
	e=duel(1,"mirror_weaver")
	U.begin(e)
	before=h.player.hp
	h.boss_fields.advance(1.51)
	check(h.player.hp<before,"mirror low beam damages standing fighter")
	h.boss_fields.clear(); h.player.invuln=0
	h.player.position.y=530
	U.begin(e)
	before=h.player.hp
	h.boss_fields.advance(1.51)
	check(h.player.hp==before,"jump avoids mirror low beam")
	h.boss_fields.advance(1.05)
	check(h.player.hp<before,"mirror high beam punishes remaining airborne")
	e=duel(2,"bell_colossus")
	h.player.position.x=800
	U.begin(e); e.timer=1.51; U.step(e,.016)
	e.timer=.01; U.step(e,.016)
	check(h.projectiles.size()==2,"bell starts two physical ground waves")
	before=h.player.hp
	h.set_process(true); await wait(.22); h.set_process(false)
	check(h.player.hp<before,"bell wave damages through live projectile processing")
	e=duel(3,"molten_wheel")
	U.begin(e)
	e.set_physics_process(true)
	before=h.player.hp
	h.set_process(true); await wait(2.8)
	check(h.player.hp<before,"wheel outbound pass reaches and damages distant target")
	h.player.invuln=0
	before=h.player.hp
	await wait(1.1)
	check(h.player.hp<before,"wheel return pass has its own contact")
	h.set_process(false)
	e=duel(3,"gear_gunner")
	e.position.x=800
	e.target=h.player.position+Vector2(0,-95)
	T.bolt(e,0,330,true)
	before=h.player.hp
	h.set_process(true); await wait(2.1); h.set_process(false)
	check(h.player.hp<before,"gunner grenade lands, warns and damages through live processing")
	T.bolt(e)
	e.take_hit(99999,1,true)
	check(h.projectiles.is_empty() and h.boss_fields.fields.is_empty(),"death cancels owned projectiles and delayed fields")
	# Actual room transition keeps actor health and changes scene chapter.
	h.choose_level(0,0); quiet()
	h.player.hp=73
	var actor_id: int=h.player.get_instance_id()
	h.continue_room()
	check(h.stage_index==1 and h.stage.chapter_index==1 and h.player.hp==73 and h.player.get_instance_id()==actor_id,"connected room keeps health and changes scenery")
	h.over=true; h.won=false; h.build_ui()
	var labels: Array=buttons(h.hud)
	var has_map:=false
	for label in labels:
		if "关卡地图" in str(label): has_map=true
	check(not has_map,"defeat popup has no duplicate map selector")
	await wait(.08)
	await h.capture("biome-defeat-menu")
	var result:={"checks":checks,"failures":failures,"rooms":rooms,"boss_count":bosses.size(),"disjoint_minions":all_rosters.size(),"save_isolated":h.test_mode}
	FileAccess.open("res://artifacts/biome-checks.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("BIOME CHECKS ",checks," FAILURES ",failures.size())
	h.get_tree().quit(0 if failures.is_empty() else 1)
