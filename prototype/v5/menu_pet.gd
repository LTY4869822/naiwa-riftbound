extends Control
## Frontal menu companion plus the complete, untrimmed original Naiwa laugh.
## The source animation intentionally turns and falls; it is not all-frontal.
signal laugh_started
signal laugh_finished

const BANK := "res://assets/menu-v2/pet/"
const FRAME_COUNT := 422
const FRAME_RATE := 30.0
const CACHE_LIMIT := 16
const INTRO_DURATION := 0.48
const REST_DURATION := 0.8
const RECOVER_DURATION := 0.5

var host: Node
var display_mode: String = "idle"
var current_frame: int = -1
var laugh_duration: float = FRAME_COUNT / FRAME_RATE
var elapsed := 0.0
var clock := 0.0
var front_texture: Texture2D
var front_laugh_texture: Texture2D
var front_bounds := Rect2i()
var front_laugh_bounds := Rect2i()
var source_bounds := Rect2i()
var has_front_asset := false
var audio: AudioStreamPlayer
var archive := ZIPReader.new()
var archive_open := false
var frame_cache: Dictionary = {}
var frame_order: Array[int] = []
var _audio_started := false
var _base_texture: Texture2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = "点击奶蛙 · 播放原版捧腹大笑"
	custom_minimum_size = Vector2(280,350)
	archive_open = archive.open(BANK+"original-laugh.nwp")==OK
	_base_texture = _frame(0) if archive_open else load("res://assets/naiwa/idle.png")
	source_bounds = _base_texture.get_image().get_used_rect()
	has_front_asset = ResourceLoader.exists(BANK+"front-idle.png")
	front_texture = load(BANK+"front-idle.png") if has_front_asset else _base_texture
	front_bounds = _solid_bounds(front_texture)
	if ResourceLoader.exists(BANK+"front-laugh.png"):
		front_laugh_texture = load(BANK+"front-laugh.png")
		front_laugh_bounds = _solid_bounds(front_laugh_texture)
	audio = AudioStreamPlayer.new()
	audio.name = "OriginalLaughAudio"
	audio.volume_db = -15
	if ResourceLoader.exists(BANK+"original-laugh.wav"):
		audio.stream = load(BANK+"original-laugh.wav")
	add_child(audio)
	resized.connect(queue_redraw)
	queue_redraw()

func _exit_tree() -> void:
	if archive_open: archive.close()

func _solid_bounds(texture: Texture2D) -> Rect2i:
	# Generated transparent plates may contain a very faint outer halo (and their
	# maximum alpha can be 254). Fit to the visible body, not to that almost-clear
	# margin. This changes only placement, never the source image's pixels.
	var bitmap := texture.get_image()
	var step := 4 if bitmap.get_height()>700 else 1
	var low := Vector2i(bitmap.get_width(),bitmap.get_height())
	var high := Vector2i(-1,-1)
	for y in range(0,bitmap.get_height(),step):
		for x in range(0,bitmap.get_width(),step):
			if bitmap.get_pixel(x,y).a>=0.12:
				low=low.min(Vector2i(x,y))
				high=high.max(Vector2i(x,y))
	if high.x<0: return bitmap.get_used_rect()
	return Rect2i(low,high-low+Vector2i.ONE*step)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		play_laugh()
		accept_event()

func play_laugh() -> bool:
	if display_mode!="idle" or not archive_open: return false
	display_mode = "laugh"
	current_frame = 0
	elapsed = 0
	_audio_started = false
	laugh_started.emit()
	queue_redraw()
	return true

func play_idle() -> void:
	display_mode = "idle"
	current_frame = -1
	elapsed = 0
	_audio_started = false
	if is_instance_valid(audio): audio.stop()
	queue_redraw()

func _reduced() -> bool:
	return host!=null and bool(host.reduce_motion)

func _sound_enabled() -> bool:
	return host==null or bool(host.audio_enabled)

func _process(dt: float) -> void:
	clock += dt
	if is_instance_valid(audio) and audio.playing and not _sound_enabled(): audio.stop()
	if display_mode=="idle":
		if not _reduced(): queue_redraw()
		return
	elapsed += dt
	var source_time := elapsed-INTRO_DURATION
	if source_time>=0 and not _audio_started:
		_audio_started = true
		if _sound_enabled() and audio.stream!=null: audio.play()
	if source_time<laugh_duration:
		display_mode="laugh"
		current_frame=clampi(int(maxf(source_time,0)*FRAME_RATE),0,FRAME_COUNT-1)
		_frame(current_frame)
	elif source_time<laugh_duration+REST_DURATION:
		display_mode="rest"
		current_frame=FRAME_COUNT-1
	elif source_time<laugh_duration+REST_DURATION+RECOVER_DURATION:
		display_mode="recover"
		current_frame=FRAME_COUNT-1
	else:
		play_idle()
		laugh_finished.emit()
	queue_redraw()

func _frame(index: int) -> Texture2D:
	index = clampi(index,0,FRAME_COUNT-1)
	if frame_cache.has(index): return frame_cache[index]
	if not archive_open: return _base_texture
	var data := archive.read_file("laugh/%04d.png" % index)
	var bitmap := Image.new()
	if bitmap.load_png_from_buffer(data)!=OK: return _base_texture
	var texture := ImageTexture.create_from_image(bitmap)
	frame_cache[index]=texture
	frame_order.append(index)
	while frame_order.size()>CACHE_LIMIT:
		frame_cache.erase(frame_order.pop_front())
	return texture

func _portrait_rect(texture: Texture2D, bounds: Rect2i, original: bool) -> Rect2:
	# All original frames use the same source-canvas transform. In particular, do
	# not rescale each moving frame's alpha bounds, which would create rubbery motion.
	var scale_factor := minf(size.y*0.79/maxf(bounds.size.y,1),size.x*0.82/maxf(bounds.size.x,1))
	if original:
		scale_factor=minf(size.y*0.79/maxf(source_bounds.size.y,1),size.x*0.82/maxf(source_bounds.size.x,1))
		bounds=source_bounds
	var anchor := Vector2(bounds.position.x+bounds.size.x*0.5,bounds.end.y)
	var target := Vector2(size.x*0.5,size.y*0.93)
	if display_mode=="idle" and not _reduced(): target.y+=sin(clock*1.7)*1.6
	return Rect2(target-anchor*scale_factor,texture.get_size()*scale_factor)

func _front(opacity: float, laughing: bool = false) -> void:
	var texture: Texture2D = front_laugh_texture if laughing and front_laugh_texture!=null else front_texture
	var bounds := front_laugh_bounds if laughing and front_laugh_texture!=null else front_bounds
	if texture!=null and opacity>0:
		draw_texture_rect(texture,_portrait_rect(texture,bounds,false),false,Color(1,1,1,opacity))

func _original(opacity: float) -> void:
	var texture := _frame(maxi(current_frame,0))
	if texture!=null and opacity>0:
		draw_texture_rect(texture,_portrait_rect(texture,source_bounds,true),false,Color(1,1,1,opacity))

func _draw() -> void:
	if front_texture==null: return
	match display_mode:
		"idle": _front(1)
		"laugh":
			if elapsed<0.18:
				var blend := elapsed/0.18
				_front(1-blend)
				_front(blend,true)
			elif elapsed<INTRO_DURATION:
				var blend := (elapsed-0.18)/(INTRO_DURATION-0.18)
				_front(1-blend,true)
				_original(blend)
			else: _original(1)
		"rest": _original(1)
		"recover":
			var blend := clampf((elapsed-INTRO_DURATION-laugh_duration-REST_DURATION)/RECOVER_DURATION,0,1)
			_original(1-blend)
			_front(blend)
