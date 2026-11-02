extends Node
## Twelve preloaded takes and six bounded voices, independent of pickup/ultimate channels.
var host: Node
var clips: Dictionary={}
var takes: Dictionary={}
var voices: Array[AudioStreamPlayer]=[]
var count:=0
func _ready() -> void:
	if AudioServer.get_bus_index("Impacts")<0:
		AudioServer.add_bus()
		var bus:=AudioServer.bus_count-1
		AudioServer.set_bus_name(bus,"Impacts")
		AudioServer.set_bus_send(bus,"Master")
		AudioServer.set_bus_volume_db(bus,-2)
		var limiter:=AudioEffectLimiter.new()
		limiter.ceiling_db=-2
		AudioServer.add_bus_effect(bus,limiter)
	for role in ["light","heavy","break","hurt"]:
		clips[role]=[]; takes[role]=0
		for i in 3: clips[role].append(load("res://assets/pixelfx/audio/%s-%d.wav" % [role,i+1]))
	for i in 6:
		var voice:=AudioStreamPlayer.new()
		voice.bus="Impacts"
		add_child(voice); voices.append(voice)
func trigger(role: String) -> bool:
	if not host.audio_enabled or not clips.has(role): return false
	var n: int=int(takes[role]); takes[role]=n+1
	var voice: AudioStreamPlayer=voices[count%voices.size()]
	voice.stream=clips[role][n%3]
	voice.volume_db=-8 if role in ["heavy","break"] else -11 if role=="hurt" else -12
	voice.pitch_scale=[.975,1.015,1.0][n%3]
	voice.play(); count+=1
	return true
func _process(_dt: float) -> void:
	if not host.audio_enabled:
		for voice in voices:
			if voice.playing: voice.stop()
func clear() -> void:
	for voice in voices: voice.stop()
