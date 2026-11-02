extends RefCounted
## An input-driven survival smoke test, not a human difficulty/fun evaluation.
const LEVELS=preload("res://campaign/levels.gd")
static func press(h: Node, action: String) -> void:
	var e:=InputEventAction.new()
	e.action=action
	e.pressed=true
	h.player._unhandled_input(e)

static func run(h: Node) -> void:
	if not h.test_mode or Profile.save_enabled: h.get_tree().quit(1); return
	h.audio_enabled=false
	Engine.time_scale=4
	Ascension.reset()
	var results: Array=[]
	for realm in 4:
		for chapter in 3:
			Profile.level=5
			Profile.xp=0
			h.choose_level(realm,chapter)
			var casts:=0
			var finishers:=0
			var decision:=0.0
			while not h.over and h.elapsed<210:
				await h.get_tree().physics_frame
				if h.hitstop>0: continue
				var p: Node=h.player
				Input.action_release("move_left")
				Input.action_release("move_right")
				if h.ascension.cinematic(): continue
				var target: Node=null
				var score:=99999.0
				for e in h.enemies:
					if not is_instance_valid(e) or e.dead: continue
					var dist: float=absf(e.position.x-p.position.x)-(130 if e.kind in ["shaman","ranged"] else 0)
					if dist<score:
						score=dist
						target=e
				if target==null: continue
				var dx: float=target.position.x-p.position.x
				var escape:=0
				for f in h.boss_fields.fields:
					if f.age<f.warning+0.15 and f.warning-f.age<0.7 and absf(f.pos.x-p.position.x)<f.radius+55:
						escape=1 if p.position.x>=f.pos.x else -1
						if p.position.x>1100: escape=-1
						if p.position.x<170: escape=1
				for f in h.spore_field.fields:
					if absf(f.pos.x-p.position.x)<100: escape=1 if p.position.x>=f.pos.x else -1
				if Ascension.energy>=100 and h.ascension.phase=="dormant" and (target.boss or p.hp<Profile.max_health()*0.70) and p.is_on_floor():
					if h.ascension.awaken(): casts+=1
				if h.ascension.empowered() and target.boss and absf(dx)<900 and (target.hp<=Profile.damage()*32 or h.ascension.remaining<7):
					p.facing=1 if dx>0 else -1
					if h.ascension.finisher(): finishers+=1
					continue
				var desired:=205.0 if target.kind in LEVELS.MYTHICS else 100.0
				if h.ascension.empowered(): desired+=65
				if escape!=0:
					p.facing=escape
					Input.action_press("move_right" if escape>0 else "move_left")
					if p.state=="idle": press(h,"dash")
				elif absf(dx)>desired: Input.action_press("move_right" if dx>0 else "move_left")
				else: p.facing=1 if dx>0 else -1
				decision-=Engine.time_scale/Engine.physics_ticks_per_second
				if escape==0 and decision<=0:
					p.facing=1 if dx>0 else -1
					if not h.ascension.empowered() and p.focus>=60 and absf(dx)<380: press(h,"skill")
					elif (target.kind=="beetle" or target.boss and target.state=="tell") and absf(dx)<desired+90 and p.stamina>=28: press(h,"heavy")
					elif target.kind!="beetle" and absf(dx)<desired+35: press(h,"attack")
					decision=0.10
				if target.state=="tell" and target.timer>target.windup_duration()*0.74 and absf(dx)<240 and not h.ascension.empowered(): press(h,"dash")
				if h.level_index==3 and absf(p.position.x-640)<105 and p.focus<80: press(h,"interact")
			Input.action_release("move_left")
			Input.action_release("move_right")
			var alive: Array=[]
			for e in h.enemies:
				if is_instance_valid(e) and not e.dead: alive.append({"kind":e.kind,"hp":e.hp,"position":str(e.position),"state":e.state})
			results.append({"id":h.current_level().id,"won":h.over and h.won,"seconds":h.elapsed,"hp":h.player.hp,"wave":h.wave,"kills":h.kills,"awakenings":casts,"finishers":finishers,"remaining_energy":Ascension.energy,"alive":alive})
			print("ASCENSION_PLAY ",JSON.stringify(results[-1]))
	var success: bool=results.all(func(r): return r.won)
	var f:=FileAccess.open("res://artifacts/ascension-balance.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"all_won":success,"starting_level_each_stage":5,"invulnerability_override":false,"energy_start":0,"energy_override":false,"simulation_time_scale":4,"input_bot_reads_telegraphs":true,"runs":results},"\t"))
	f.close()
	h.get_tree().quit(0 if success else 1)
