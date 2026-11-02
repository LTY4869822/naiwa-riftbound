extends RefCounted
var checks:=0
var failures: Array[String]=[]
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures.append(label); push_error(label)
func run(h: Node) -> void:
	if not h.test_mode or Profile.save_enabled or Wardrobe.save_enabled: h.get_tree().quit(1); return
	h.audio_enabled=true
	preload("res://loot/demo.gd").setup(h)
	await h.get_tree().process_frame
	var visual: Node=h.journey.presentation
	var audio: Node=h.journey.pickup_audio
	check(visual.atlas.coin.size()==8,"coin has eight measured rotation frames")
	check(visual.atlas.potion.size()==1,"medicine uses original transparent painted flask")
	check(audio.voices.size()==8 and AudioServer.get_bus_index("Pickups")>=0,"pickup voices are bounded and routed")
	var drop: Dictionary=h.journey.drops[0]
	var cash:=Wardrobe.coins
	check(h.journey.collect(drop) and Wardrobe.coins==cash+8,"real coin pickup credits its actual amount")
	check(audio.count==1 and visual.feedback_count==1,"successful coin pickup emits one sound and visual event")
	check(h.journey.collect(drop) and audio.count==1 and visual.feedback_count==1,"duplicate ledger replay is silent and has no duplicate burst")
	check(audio.voices[0].stream==audio.CLIPS.coin[0] and audio.voices[0].bus=="Pickups","coin event selects its real coin stream")
	h.player.hp=Profile.max_health()
	check(not h.journey.collect(h.journey.drops[3]) and audio.count==1,"full-health medicine neither consumes nor makes a pickup sound")
	h.player.hp=54
	check(h.journey.collect(h.journey.drops[3]) and h.player.hp==101,"medicine still restores exactly half the missing health")
	check(audio.count==2 and visual.feedback_count==2 and audio.voices[1].stream==audio.CLIPS.heal[0],"healing triggers the distinct liquid/chime sound")
	h.audio_enabled=false
	audio.cooldown=0
	check(h.journey.collect(h.journey.drops[1]) and audio.count==2 and visual.feedback_count==3,"mute preserves collection and particles while suppressing sound")
	audio._process(0)
	check(audio.voices.all(func(v): return not v.playing),"mute stops existing pickup tails")
	h.audio_enabled=true
	audio.cooldown=0
	audio.trigger("coin")
	check(audio.voices[2].stream==audio.CLIPS.coin[1],"repeated coins alternate samples")
	var n: int=audio.count
	check(not audio.trigger("coin") and audio.count==n,"same-frame pile collection cannot flood the mix")
	for i in 30:
		audio.cooldown=0
		audio.trigger("coin")
		visual.collected(drop)
	check(audio.voices.size()==8 and visual.bursts.size()<=24,"repeated pickups keep sound and effect pools bounded")
	h.audio_enabled=false
	h.journey.drops.clear()
	await h.get_tree().create_timer(1.0).timeout
	check(visual.bursts.is_empty(),"pickup particles expire without leaving scene objects")
	check(not Profile.save_enabled and not Wardrobe.save_enabled,"review cannot touch formal records")
	var f:=FileAccess.open("res://artifacts/loot-v3-checks.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	f.close()
	print("LOOT_CHECKS ",checks," failures=",failures.size())
	h.get_tree().quit(0 if failures.is_empty() else 1)
