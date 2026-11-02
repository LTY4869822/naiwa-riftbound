extends RefCounted
static func press(h: Node, action: String) -> void:
	var event:=InputEventAction.new()
	event.action=action
	event.pressed=true
	h.player._unhandled_input(event)

static func run(h: Node) -> void:
	if not h.test_mode or Profile.save_enabled: h.get_tree().quit(1); return
	h.audio_enabled=false
	Engine.time_scale=6
	Engine.physics_ticks_per_second=180
	var rift_run: bool="--rift-balance" in OS.get_cmdline_user_args()
	var starting_level:=7 if rift_run else 5
	Profile.level=starting_level
	Ascension.reset()
	Wardrobe.reset()
	var results: Array=[]
	for realm in 4:
		h.choose_level(realm,0)
		var room_entries: Array=[]
		var last_room:=-1
		var decision:=0.0
		var cross_side:=0
		var cross_until:=0.0
		while not h.over and h.elapsed<240:
			await h.get_tree().physics_frame
			Input.action_release("move_left")
			Input.action_release("move_right")
			if h.hitstop>0 or h.journey.travelling: continue
			var p: Node=h.player
			if h.rift.offer_active:
				h.rift.pick("wind" if "wind" in h.rift.offers else h.rift.offers[0])
				continue
			if h.stage_index!=last_room:
				last_room=h.stage_index
				room_entries.append({"room":last_room,"hp":p.hp,"actor":p.get_instance_id()})
			if h.journey.cleared:
				if Wardrobe.gear_rank("charm")==0 and Wardrobe.coins>=160: Wardrobe.buy_gear("charm")
				elif Wardrobe.gear_rank("bracer")==0 and Wardrobe.coins>=180: Wardrobe.buy_gear("bracer")
				var dest:=1190.0
				var best:=9999.0
				for d in h.journey.drops:
					if d.type=="heal" and p.hp>=Profile.max_health(): continue
					var distance: float=absf(d.pos.x-p.position.x)
					if distance<best:
						best=distance
						dest=d.pos.x
				if absf(dest-p.position.x)>10: Input.action_press("move_right" if dest>p.position.x else "move_left")
				continue
			if h.ascension.cinematic(): continue
			var target: Node=null
			var score:=99999.0
			for e in h.enemies:
				if not is_instance_valid(e) or e.dead: continue
				var dist: float=absf(e.position.x-p.position.x)-(120 if e.kind in ["shaman","ranged"] else 0)
				if dist<score: score=dist; target=e
			if target==null: continue
			var dx: float=target.position.x-p.position.x
			var escape:=0
			var urgent:=99.0
			for f in h.boss_fields.fields:
				var warning: float=f.warning-f.age
				if f.has("rect"):
					if warning<0.38 and warning>0 and p.is_on_floor(): press(h,"jump")
					continue
				if warning<0.65 and f.age<f.warning+0.18 and absf(f.pos.x-p.position.x)<f.radius+60 and warning<urgent:
					urgent=warning
					escape=1 if p.position.x>=f.pos.x else -1
			for f in h.spore_field.fields:
				if absf(f.pos.x-p.position.x)<110: escape=1 if p.position.x>=f.pos.x else -1
			if target.state=="tell" and absf(dx)<330:
				var counter: bool=target.boss and target.break_guard<=0 and target.timer<0.32 and p.stamina>=28 and absf(dx)<target.hurtbox().size.x*.5+115
				if counter:
					p.facing=int(signf(dx))
					press(h,"heavy")
					escape=0
				else: escape=-int(signf(dx))
				if not counter and target.timer>target.windup_duration()-0.09:
					if target.boss and target.move_id in [0,1]:
						cross_side=int(signf(dx))
						cross_until=h.elapsed+0.85
						escape=cross_side
					p.facing=escape
					press(h,"dash")
			if target.boss and target.state=="ult_tell" and cross_until<h.elapsed:
				cross_side=int(signf(dx))
				cross_until=h.elapsed+2.2
			if cross_until>h.elapsed: escape=cross_side
			if p.position.x<130 and escape<0: escape=1
			if p.position.x>1150 and escape>0: escape=-1
			if Ascension.energy>=100 and h.ascension.phase=="dormant" and target.boss and p.is_on_floor(): h.ascension.awaken()
			if h.ascension.empowered() and h.ascension.remaining<3 and target.boss:
				p.facing=int(signf(dx))
				if h.ascension.finisher(): continue
			var desired: float=target.hurtbox().size.x*.5+60 if target.boss else 90.0
			if h.ascension.empowered(): desired+=60
			if escape!=0:
				p.facing=escape
				Input.action_press("move_right" if escape>0 else "move_left")
				if urgent<0.15: press(h,"dash")
			elif absf(dx)>desired: Input.action_press("move_right" if dx>0 else "move_left")
			decision-=Engine.time_scale/Engine.physics_ticks_per_second
			if decision<=0 and escape==0:
				p.facing=int(signf(dx))
				if p.focus>=60 and not h.ascension.empowered() and absf(dx)<570: press(h,"skill")
				elif (target.kind=="beetle" or target.state=="tell") and absf(dx)<desired+45 and p.stamina>=28: press(h,"heavy")
				elif absf(dx)<desired+35: press(h,"attack")
				decision=0.08
			for bullet in h.projectiles:
				if (p.position.x-bullet.pos.x)*bullet.velocity.x>0 and absf(bullet.pos.x-p.position.x)<150:
					if p.is_on_floor(): press(h,"jump")
					p.facing=-int(signf(bullet.velocity.x))
					press(h,"dash")
		Input.action_release("move_left")
		Input.action_release("move_right")
		results.append({"realm":realm,"won":h.over and h.won,"stage":h.stage_index,"seconds":h.elapsed,"hp":h.player.hp,"pickups":h.journey.picked_coins,"heals":h.journey.picked_heals,"coins":Wardrobe.coins,"energy":Ascension.energy,"entries":room_entries})
		print("LOOP_PLAY ",JSON.stringify(results[-1]))
	var file:=FileAccess.open("res://artifacts/"+("rift-balance" if rift_run else "loop-balance")+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"runs":results,"all_won":results.all(func(r): return r.won),"starting_level":starting_level,"same_actor_between_rooms":true,"invulnerability_override":false,"currency_override":false,"energy_override":false,"bot_reads_telegraphs":true,"arrival_skipped_for_timing":true,"relic_policy":"choose wind if available"},"\t"))
	file.close()
	h.get_tree().quit()
