extends Node2D
## Complete, approved drawings. Fixed uniform scale; no skeletal/mesh deformation.
const DATA_PATH := "res://assets/v6/side-frames.json"
const SPRINT=preload("res://assets/sprint-v2/sprint-four-frames.png")
const SPRINT_SCALE:=0.46
const SPRINT_SOLES:=[491.0,461.0,468.0,449.0]
var sprint_frames: Array[AtlasTexture]=[]
var manifest: Dictionary
var textures: Array[Texture2D] = []
var sprite: Sprite2D
var state := "idle"
var frame_index := 0
var current_frame_id := -1
var cycle := 0.0
var direction := 1
var current: Dictionary = {}
var factor := 0.175
var ground_error := 0.0
var source_facing := 1
var settle_clip := ""
var settle_time := 0.0
var host: Node
var ascended: Node2D

func _ready() -> void:
	manifest = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	factor = float(manifest.scale)
	source_facing = int(manifest.get("source_facing",1))
	for entry in manifest.frames: textures.append(load(entry.texture))
	for i in 4:
		var atlas:=AtlasTexture.new()
		atlas.atlas=SPRINT
		atlas.region=Rect2((i%2)*768,floori(i/2.0)*512,768,512)
		atlas.filter_clip=true
		sprint_frames.append(atlas)
	sprite = Sprite2D.new()
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(sprite)
	show_frame(0)
	ascended=preload("res://ascension/poses.gd").new()
	ascended.rig=self
	add_child(ascended)
	ascended.clear()

func drive(dt: float, next: String, progress: float, facing: int, speed: float, _floor: float) -> void:
	if state != next:
		settle_clip=("settle_a" if frame_index<4 else "settle_b") if state=="run" and next=="idle" else ""
		settle_time=0
		cycle = 0
		state = next
	direction = facing
	if is_instance_valid(host) and host.ascension.visible_form():
		ascended.drive(host.ascension,dt,state,progress,speed)
		return
	ascended.clear()
	if state=="dash":
		show_sprint(progress)
		return
	var clip: Dictionary = manifest.clips.get(state,manifest.clips.idle)
	var clock: float
	if not settle_clip.is_empty():
		settle_time+=dt
		clip=manifest.clips[settle_clip]
		clock=minf(settle_time,float(clip.duration)-0.0001)
		if settle_time>=float(clip.duration): settle_clip=""
	elif state.begins_with("attack") or state in ["skill","hurt","dash","air"]:
		clock = clampf(progress,0,0.9999)*float(clip.duration)
	else:
		cycle += dt*(clampf(absf(speed)/235,0.1,1.6) if state=="run" else 1.0)
		clock = fmod(cycle,float(clip.duration))
	frame_index = clip.frames.size()-1
	var end := 0.0
	for i in clip.frames.size():
		end += float(clip.times[i])
		if clock<end:
			frame_index=i
			break
	show_frame(int(clip.frames[frame_index]))

func show_frame(id: int) -> void:
	current_frame_id=id
	current=manifest.frames[id]
	sprite.texture=textures[id]
	# Normal sprite reflection only; never scale X and Y by different magnitudes.
	sprite.scale=Vector2(direction*source_facing*factor,factor)
	sprite.position=Vector2(-direction*source_facing*float(current.anchor[0])*factor,-float(current.anchor[1])*factor)
	ground_error=absf((float(current.sole_y)-float(current.anchor[1])-float(current.get("support_depth",0)))*factor)

func show_sprint(progress: float) -> void:
	frame_index=clampi(floori(progress*4),0,3)
	current_frame_id=100+frame_index
	var sole: float=SPRINT_SOLES[frame_index]
	var units: float=SPRINT_SCALE/factor
	# Metadata uses the same world-unit convention as authored combat poses.
	current={"anchor":[390*units,sole*units],"hand":[310*units,210*units],"sole_y":sole*units,"support_depth":0,"grounded":true,"feet":[{"point":[390*units,sole*units],"depth":0,"width":26.0}]}
	sprite.texture=sprint_frames[frame_index]
	sprite.scale=Vector2(direction*SPRINT_SCALE,SPRINT_SCALE)
	sprite.position=Vector2(-direction*390,-sole)*SPRINT_SCALE
	ground_error=0

func hand_local() -> Vector2:
	return Vector2(direction*source_facing*(float(current.hand[0])-float(current.anchor[0])),float(current.hand[1])-float(current.anchor[1]))*factor

func hand_world() -> Vector2:
	return to_global(hand_local())

func sole_world() -> Vector2:
	return to_global(Vector2(0,(float(current.sole_y)-float(current.anchor[1]))*factor))
