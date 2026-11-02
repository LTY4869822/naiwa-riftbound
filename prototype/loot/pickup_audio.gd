extends Node
## Dedicated bounded voices: loot never steals an attack/hurt sound channel.
signal played(kind: String, variant: int)
const CLIPS={
	"coin":[preload("res://assets/loot-v3/audio/coin-1.wav"),preload("res://assets/loot-v3/audio/coin-2.wav")],
	"heal":[preload("res://assets/loot-v3/audio/heal-1.wav"),preload("res://assets/loot-v3/audio/heal-2.wav")],
}
var host: Node
var voices: Array[AudioStreamPlayer]=[]
var sequence: Dictionary={"coin":0,"heal":0}
var cooldown:=0.0
var count:=0
var voice_index:=0

func _ready() -> void:
	if AudioServer.get_bus_index("Pickups")<0:
		AudioServer.add_bus()
		var bus:=AudioServer.bus_count-1
		AudioServer.set_bus_name(bus,"Pickups")
		AudioServer.set_bus_send(bus,"Master")
		AudioServer.set_bus_volume_db(bus,-1.5)
	for i in 8:
		var voice:=AudioStreamPlayer.new()
		voice.bus="Pickups"
		add_child(voice)
		voices.append(voice)

func _process(dt: float) -> void:
	cooldown=maxf(0,cooldown-dt)
	if not host.audio_enabled:
		for voice in voices:
			if voice.playing: voice.stop()

func trigger(kind: String) -> bool:
	if not host.audio_enabled or not CLIPS.has(kind): return false
	if kind=="coin" and cooldown>0: return false
	var variant: int=int(sequence[kind])%2
	sequence[kind]+=1
	var voice: AudioStreamPlayer=voices[voice_index%voices.size()]
	voice_index+=1
	voice.stream=CLIPS[kind][variant]
	voice.volume_db=-8.5 if kind=="coin" else -7.0
	voice.pitch_scale=1.0+[-0.018,0.0,0.018][count%3] if kind=="coin" else 1.0
	voice.play()
	if kind=="coin": cooldown=.045
	count+=1
	played.emit(kind,variant)
	return true
