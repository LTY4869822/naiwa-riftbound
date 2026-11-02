extends RefCounted
static var data: Dictionary={}
static var art: Dictionary={}
static func settings() -> Dictionary:
	if data.is_empty(): data=JSON.parse_string(FileAccess.get_file_as_string("res://echo/theme.json"))
	return data
static func color(role: String) -> Color: return Color(settings()[role])
static func emblem(id: String) -> Texture2D:
	if art.is_empty():
		var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/echo-v6/manifest.json"))
		var d: Dictionary=manifest["relic-emblems"]
		var source: Texture2D=load(d.file)
		for i in d.ids.size():
			var f: Dictionary=d.frames[i]
			var a:=AtlasTexture.new()
			a.atlas=source
			a.region=Rect2(f.region[0],f.region[1],f.region[2],f.region[3])
			a.filter_clip=true
			art[d.ids[i]]=a
	return art[id]
static func outline(points: PackedVector2Array) -> PackedVector2Array:
	var p:=points.duplicate()
	p.append(p[0])
	return p
static func ticket(r: Rect2) -> PackedVector2Array:
	var cut: float=minf(14,minf(r.size.x*.15,r.size.y*.22))
	return PackedVector2Array([r.position+Vector2(0,cut),r.position+Vector2(cut,0),Vector2(r.end.x-cut*1.4,r.position.y),Vector2(r.end.x,r.position.y+cut*1.3),r.end-Vector2(0,cut),r.end-Vector2(cut,0),Vector2(r.position.x+cut,r.end.y),Vector2(r.position.x,r.end.y-cut)])
static func splat(c: CanvasItem,at: Vector2,extent: Vector2,fill: Color,seed_value: float=0) -> void:
	var p:=PackedVector2Array()
	for i in 72:
		var a: float=i*TAU/72
		var radius: float=.85+.11*sin(a*5+seed_value)+.07*sin(a*9-seed_value)
		p.append(at+Vector2(cos(a),sin(a))*extent*radius)
	c.draw_colored_polygon(p,fill)
static func words(c: CanvasItem,font: Font,value: String,at: Vector2,fs: int,fill: Color,width: float=-1,center: bool=false,stroke: int=0) -> void:
	fs=Preferences.font_size(fs)
	if width>0:
		while fs>12 and font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x>width: fs-=1
	var pos:=at
	if center: pos.x-=font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x*.5
	if stroke>0: c.draw_string_outline(font,pos+Vector2(0,2),value,HORIZONTAL_ALIGNMENT_LEFT,-1,fs,stroke,color("ink"))
	c.draw_string(font,pos,value,HORIZONTAL_ALIGNMENT_LEFT,-1,fs,fill)
