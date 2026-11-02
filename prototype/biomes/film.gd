extends RefCounted
const C=preload("res://biomes/content.gd")
const U=preload("res://biomes/boss_skills.gd")
var h: Node
var scenes: Array=[]
func frames(n: int) -> void:
	for i in n: await h.get_tree().process_frame
func setup(map: int,chapter: int) -> void:
	h.choose_level(map,chapter)
	h.wait_wave=99999
	h.wave=h.current_level().waves.size()
	h.player.position=Vector2(240,640)
	h.player.invuln=10000
	h.arena.enabled=false
	h.toast_time=0
func run(host: Node) -> void:
	h=host
	h.rift.presentations_enabled=false
	h.audio_enabled=true
	Profile.level=7
	Ascension.energy=0
	for map in 4:
		for chapter in 3:
			setup(map,chapter)
			var boss: Node=h.spawn(C.BOSSES[map][chapter],1080)
			boss.cooldown=999; boss.ult_cooldown=999
			boss.set_physics_process(false)
			for i in 3:
				var e: Node=h.spawn(C.ROSTERS[map][i],[540.0,740.0,880.0][i])
				e.cooldown=.3+i*.3
			h.refresh_hud()
			await frames(60)
			scenes.append({"scene":h.current_level().id,"roster":C.ROSTERS[map],"boss":boss.kind})
	for map in 4:
		setup(map,1)
		var boss: Node=h.spawn(C.BOSSES[map][1],980)
		boss.cooldown=999; boss.ult_cooldown=999
		await frames(5)
		U.begin(boss)
		await frames(150)
	FileAccess.open("res://artifacts/biome-film.json",FileAccess.WRITE).store_string(JSON.stringify({"frames":Engine.get_process_frames(),"fps":30,"scenes":scenes,"scenario":"Staged in-engine showcase: twelve scenes show their biome's full three-species roster and guardian. Middle-boss ultimates are explicitly triggered. Player target is invulnerable, stage hazards disabled, no claim of a normal playthrough. All gameplay code and authored animation frames are live."},"\t"))
	h.get_tree().quit()
