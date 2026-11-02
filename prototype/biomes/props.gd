extends RefCounted
static var frames: Array=[]
static var meta: Dictionary={}
static func paint(canvas: Node2D,index: int,r: Rect2) -> void:
	if frames.is_empty():
		var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/biomes-v5/manifest.json"))
		meta=manifest.ledges
		var source: Texture2D=load(meta.file)
		for f in meta.frames:
			var a:=AtlasTexture.new()
			a.atlas=source
			a.region=Rect2(f.region[0],f.region[1],f.region[2],f.region[3])
			a.filter_clip=true
			frames.append(a)
	var f: Dictionary=meta.frames[index]
	var scale_factor: float=(r.size.x+12)/float(f.region[2])
	var rect:=Rect2(r.position.x-6,r.position.y-f.contact_y*scale_factor,float(f.region[2])*scale_factor,float(f.region[3])*scale_factor)
	canvas.draw_texture_rect(frames[index],rect,false)
