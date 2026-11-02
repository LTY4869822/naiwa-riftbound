extends Node2D
const HUNTER = preload("res://assets/v4/hunter.png")
const MOTH = preload("res://assets/v5/lantern-moth.png")
const WARDEN = preload("res://assets/v5/root-warden.png")
const CATALOG = preload("res://combat/enemy_catalog.gd")
const EXPANSION := {
	"zheng":preload("res://assets/echo-v6/zheng-combat.png"),
	"zhuyin":preload("res://assets/ascension/bosses/zhuyin-clean.png"),
	"yinglong":preload("res://assets/ascension/bosses/yinglong.png"),
	"paoxiao":preload("res://assets/ascension/bosses/paoxiao.png"),
	"mycelium_boss":preload("res://assets/campaign/bosses/mycelium_boss.png"),
	"tempest_boss":preload("res://assets/campaign/bosses/tempest_boss.png"),
	"cinder_boss":preload("res://assets/campaign/bosses/cinder_boss.png"),
	"beetle":preload("res://assets/enemies-expansion/thornback-beetle.png"),
	"shaman":preload("res://assets/enemies-expansion/sporelamp-shaman.png"),
	"raven":preload("res://assets/enemies-expansion/nightplume-raven.png"),
}
var kind := "melee"
var sprite: Sprite2D
var clock := 0.0
var gait := 0.0
var last_position := Vector2.ZERO
var factor := 1.0
var phase_frame := 0
var source: Texture2D
static var atlas_cache: Dictionary = {}
const BOUNDS := {
	"melee":[Rect2i(21,166,419,237),Rect2i(16,165,416,237),Rect2i(7,167,422,240),Rect2i(3,178,437,201),Rect2i(20,146,418,230),Rect2i(33,127,397,249),Rect2i(6,135,436,232),Rect2i(53,105,337,270)],
	"ranged":[Rect2i(29,4,413,421),Rect2i(21,112,422,310),Rect2i(0,157,443,270),Rect2i(0,4,409,424),Rect2i(32,0,408,406),Rect2i(0,108,443,292),Rect2i(0,12,443,380),Rect2i(0,48,429,312)],
	"boss":[Rect2i(23,4,373,425),Rect2i(24,4,343,425),Rect2i(16,3,361,426),Rect2i(18,1,388,429),Rect2i(29,4,385,418),Rect2i(57,1,386,420),Rect2i(0,40,443,379),Rect2i(12,74,407,337)]
}
var frames: Array = []
var current_rotation := 0.0
var run_frames: Array=[]
var run_clock:=0.0

func _ready() -> void:
	source=WARDEN if kind=="boss" else MOTH if kind=="ranged" else HUNTER
	if CATALOG.expanded(kind):
		prepare_expansion()
		return
	if not atlas_cache.has(kind):
		var entries: Array=[]
		var cell := Vector2i(source.get_width()/4,source.get_height()/2)
		for row in 2:
			for col in 4:
				var rect := Rect2i(Vector2i(col,row)*cell,cell)
				# Alpha fringe in generated sheets is not a meaningful contact point.
				# These UV bounds were checked against alpha >=64, without changing the PNG.
				var bounds: Rect2i=BOUNDS[kind][row*4+col]
				var atlas := AtlasTexture.new()
				atlas.atlas=source
				atlas.region=Rect2(rect.position+bounds.position,bounds.size)
				atlas.filter_clip=true
				entries.append({"texture":atlas,"bottom":bounds.size.y,"center":bounds.size.x/2.0,"height":bounds.size.y})
		atlas_cache[kind]=entries
	frames=atlas_cache[kind]
	factor=(268.0 if kind=="boss" else 132.0 if kind=="ranged" else 112.0)/float(frames[0].height)
	sprite=Sprite2D.new()
	sprite.centered=false
	add_child(sprite)
	set_frame(0,-1)
	last_position=position

func prepare_expansion() -> void:
	if kind=="zheng":
		prepare_zheng()
		return
	if bool(CATALOG.DATA[kind].get("biome",false)):
		prepare_biome()
		return
	source=EXPANSION[kind]
	if not atlas_cache.has(kind):
		var file: String="res://assets/campaign/bosses/sprites.json" if bool(CATALOG.DATA[kind].get("boss",false)) else "res://assets/enemies-expansion/sprites.json"
		var metadata: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(file))
		var entries: Array=[]
		var poses: Array=[]
		if bool(CATALOG.DATA[kind].get("mythic",false)):
			metadata=JSON.parse_string(FileAccess.get_file_as_string("res://assets/ascension/manifest.json"))
			poses=metadata.assets["bosses/"+kind+("-clean" if kind=="zhuyin" else "")+".png"].frames
			if kind=="zhuyin": poses=[poses[0],poses[0],poses[0],poses[0],poses[1],poses[3],poses[2],poses[0]]
		else: poses=metadata[kind].frames
		for frame in poses:
			var region: Array=frame.region
			var atlas := AtlasTexture.new()
			atlas.atlas=source
			atlas.region=Rect2(region[0],region[1],region[2],region[3])
			atlas.filter_clip=true
			entries.append({"texture":atlas,"bottom":frame.pivot[1],"center":frame.pivot[0],"height":region[3]})
		atlas_cache[kind]=entries
	frames=atlas_cache[kind]
	factor=float(CATALOG.DATA[kind].height)/float(frames[0].height)
	sprite=Sprite2D.new()
	sprite.centered=false
	add_child(sprite)
	set_frame(0,-1)
	last_position=position

func prepare_biome() -> void:
	var metadata: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/biomes-v5/manifest.json"))
	source=load(metadata[kind].file)
	if not atlas_cache.has(kind):
		var entries: Array=[]
		for f in metadata[kind].frames:
			var a:=AtlasTexture.new()
			a.atlas=source
			a.region=Rect2(f.region[0],f.region[1],f.region[2],f.region[3])
			a.filter_clip=true
			entries.append({"texture":a,"bottom":f.pivot[1],"center":f.pivot[0],"height":f.region[3]})
		atlas_cache[kind]=entries
	frames=atlas_cache[kind]
	factor=float(CATALOG.DATA[kind].height)/float(frames[0].height)
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite=Sprite2D.new()
	sprite.centered=false
	add_child(sprite)
	set_frame(0,-1)
	last_position=position

func prepare_zheng() -> void:
	var metadata: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/echo-v6/manifest.json"))
	for clip in ["zheng-combat","zheng-run"]:
		if not atlas_cache.has(clip):
			var entries: Array=[]
			var d: Dictionary=metadata[clip]
			var tex: Texture2D=load(d.file)
			for f in d.frames:
				var a:=AtlasTexture.new()
				a.atlas=tex; a.region=Rect2(f.region[0],f.region[1],f.region[2],f.region[3]); a.filter_clip=true
				entries.append({"texture":a,"bottom":f.pivot[1],"center":f.pivot[0],"height":f.height})
			atlas_cache[clip]=entries
	frames=atlas_cache["zheng-combat"]
	run_frames=atlas_cache["zheng-run"]
	factor=float(metadata["zheng-combat"].scale)
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite=Sprite2D.new(); sprite.centered=false; add_child(sprite)
	set_frame(0,-1)
	last_position=position

func set_frame(index: int,facing: int) -> void:
	apply_frame(frames[clampi(index,0,7)],facing)

func apply_frame(data: Dictionary,facing: int) -> void:
	sprite.texture=data.texture
	sprite.scale=Vector2(-facing*factor,factor)
	sprite.position=Vector2(facing*data.center*factor,-data.bottom*factor)
	if kind=="ranged": sprite.position.y-=64

func drive(dt: float,node: Node) -> void:
	if dt<=0: return
	clock+=dt
	var distance := absf(position.x-last_position.x)
	last_position=position
	gait+=distance/22
	var frame := 0
	var lift := 0.0
	var tilt := 0.0
	if kind in ["ranged","raven","glow_jelly","storm_manta","bell_colossus"]:
		frame=([0,1,2,3] if kind=="raven" else [0,1,2,1])[int(clock*10)%4]
		lift=sin(clock*3)*3
	else:
		if absf(node.velocity.x)>10: frame=int(gait)%4
	if node.state in ["tell","ult_tell"]:
		var p: float=node.timer/(1.5 if node.state=="ult_tell" else node.windup_duration())
		frame=4 if p<0.55 else 5
		tilt=-node.facing*0.025*smoothstep(0,1,p)
	elif node.state in ["active","ult_active"]:
		frame=6
		if kind=="beetle": frame=5 if int(clock*18)%2==0 else 6
		if kind=="raven" and node.timer>0.40: frame=7
		tilt=node.facing*0.035*(1-minf(1,node.timer/0.26))
	elif node.state in ["recover","ult_recover"]: frame=7 if node.timer<0.12 else 0
	elif node.state=="stunned": frame=7
	if node.boss and not node.attack_data.is_empty():
		if node.state=="tell" and node.move_id==1: frame=3 if node.timer<node.windup_duration()*.65 else 5
		elif node.state=="active":
			if node.move_id==0:
				var u: float=fmod(node.timer,0.34)
				frame=6 if u<0.20 else 5
			elif node.move_id==1: frame=[3,6,2,1][clampi(floori(node.timer/0.18),0,3)]
			elif node.move_id==2: frame=6 if node.timer<0.25 else 5 if node.timer<0.5 else 0
			else: frame=7 if node.timer<0.28 else 6 if node.timer<0.55 else 0
	if node.state=="rift_arrive": frame=[1,2,3,2][int(clock*8)%4]
	elif node.state=="phase_shift": frame=5
	if bool(CATALOG.DATA.get(kind,{}).get("biome",false)) and not node.boss and node.state=="active":
		frame=6 if kind in ["glow_jelly","gear_gunner"] or node.move_id==2 else 5
	if kind=="molten_wheel" and node.state in ["active","ult_active"] and absf(node.velocity.x)>100:
		frame=[1,2,3,2][int(gait)%4]
	set_frame(frame,node.facing)
	if kind=="zheng" and (node.state in ["approach","recover","ult_recover","rift_arrive"] or node.state=="active" and node.move_id==1):
		if absf(node.velocity.x)>15: run_clock+=dt*clampf(absf(node.velocity.x)/25,7,16)
		var run_index: int=int(run_clock)%8 if absf(node.velocity.x)>15 else 0
		apply_frame(run_frames[run_index],node.facing)
		tilt=0
	sprite.position.y+=lift
	current_rotation=lerpf(current_rotation,tilt,1-exp(-dt*25))
	rotation=current_rotation
	modulate=Color.WHITE.lerp(Color(1.6,1.45,1.1),minf(1,node.flash)*0.8)
	if node.enraged and node.flash<=0: modulate=Color(1.08,1.0,1.05)
