extends SceneTree
## Run with --headless --path prototype --script res://assets/menu-v2/pet/smoke_pet.gd.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var pet: Control = load("res://v5/menu_pet.gd").new()
	root.add_child(pet)
	pet.size=Vector2(400,500)
	await process_frame
	var failures := 0
	var checks: Array[String] = []
	checks.append("PASS frontal idle asset loaded" if pet.has_front_asset else "FAIL frontal idle asset")
	checks.append("PASS untrimmed original duration is 422/30 seconds" if absf(pet.laugh_duration-422.0/30.0)<0.000001 else "FAIL source duration")
	checks.append("PASS laugh starts once" if pet.play_laugh() and not pet.play_laugh() else "FAIL overlapping playback")
	pet._process(4.49)
	checks.append("PASS source time drives original frame" if pet.current_frame in [120,121] else "FAIL source frame timing")
	for index in range(422):
		var frame: Texture2D=pet._frame(index)
		if frame==null or frame.get_size()!=Vector2(288,368):
			checks.append("FAIL original frame %d" % index)
			break
	checks.append("PASS original frame cache stays bounded" if pet.frame_cache.size()<=16 else "FAIL cache limit")
	pet._process(10.08)
	checks.append("PASS original reaches last frame and resting pose" if pet.current_frame==421 and pet.display_mode=="rest" else "FAIL resting pose")
	pet._process(0.81)
	checks.append("PASS recovery crossfade follows full clip" if pet.display_mode=="recover" else "FAIL recovery")
	pet._process(0.6)
	checks.append("PASS returns to frontal idle" if pet.display_mode=="idle" and pet.current_frame==-1 else "FAIL return to front")
	var front: Rect2=pet._portrait_rect(pet.front_texture,pet.front_bounds,false)
	var original: Rect2=pet._portrait_rect(pet._base_texture,pet.source_bounds,true)
	var front_scale: float=front.size.y/pet.front_texture.get_height()
	var original_scale: float=original.size.y/pet._base_texture.get_height()
	var foot_error := absf((front.position.y+pet.front_bounds.end.y*front_scale)-(original.position.y+pet.source_bounds.end.y*original_scale))
	checks.append("PASS source and front share foot baseline" if foot_error<0.01 else "FAIL foot baseline")
	for result in checks:
		print(result)
		if result.begins_with("FAIL"): failures+=1
	print("PET_SMOKE failures=",failures," front_bounds=",pet.front_bounds," source_bounds=",pet.source_bounds)
	pet.queue_free()
	await process_frame
	quit(failures)
