extends Node
## Arrival pacing, per-map relic choices, and contact-confirmed precision dodges.
const CATALOG=preload("res://combat/enemy_catalog.gd")
const RELICS={
	"edge":{"title":"裂甲之牙","copy":"攻击伤害 +12%\n重击更易积累失衡","glyph":"heavy","color":Color("e6b778")},
	"wind":{"title":"追风羽印","copy":"闪避体力消耗 −4\n闪避冷却 −0.08 秒","glyph":"dash","color":Color("9eddf4")},
	"spring":{"title":"灵泉之心","copy":"药露额外回复\n15% 缺失生命","glyph":"health","color":Color("a2efc1")},
	"echo":{"title":"紫霆回响","copy":"精准闪避额外 +3 魔能\n反击增伤延长 0.6 秒","glyph":"skill","color":Color("d4a0ff")},
}
var host: Node
var entrance: Dictionary={}
var arrival_seen: Dictionary={}
var ranks: Dictionary={}
var offers: Array[String]=[]
var offer_focus: String=""
var offer_active:=false
var claimed: Dictionary={}
var riposte:=0.0
var evade_cd:=0.0
var perfect_count:=0
var visual: Node2D
var modal: Control
var presentations_enabled:=true

func _ready() -> void:
	var args:=OS.get_cmdline_user_args()
	var automated:=false
	for arg in args:
		if str(arg).ends_with("-review") or str(arg).contains("-check") or str(arg).ends_with("-balance") or str(arg).ends_with("-film"):
			automated=true
			break
	presentations_enabled=not (host.test_mode and automated) or "--rift-review" in args or "--rift-film" in args
	visual=preload("res://rift/visual.gd").new()
	visual.host=host
	visual.director=self
	host.add_child.call_deferred(visual)

func blocked() -> bool: return not entrance.is_empty() or offer_active
func rank(id: String) -> int: return int(ranks.get(id,0))
func attack_boost() -> float: return (1+rank("edge")*.12)*(1.35 if riposte>0 else 1.0)
func heal_fraction() -> float: return minf(.8,.50+rank("spring")*.15)

func reset_run() -> void:
	finish_arrival()
	ranks.clear()
	claimed.clear()
	arrival_seen.clear()
	riposte=0
	evade_cd=0
	offer_active=false
	offers.clear()
	offer_focus=""
	if is_instance_valid(modal): modal.queue_free()

func register(e: Node) -> void:
	if not e.boss or not presentations_enabled: return
	finish_arrival()
	var start: Vector2=e.position
	var side:=1 if start.x>=host.player.position.x else -1
	entrance={"actor":weakref(e),"age":0.0,"end":start,"side":side,"portal":start+Vector2(side*92,-190)}
	e.state="rift_arrive"
	e.velocity=Vector2.ZERO
	host.projectiles.clear()
	host.boss_fields.clear()
	host.view.visible=true
	host.player.buffered=0
	host.player.velocity=Vector2.ZERO
	host.play_sound("ultimate_charge",-17,.53)
	arrival_seen[e.kind]=true

func finish_arrival() -> void:
	if entrance.is_empty(): return
	host.hud.visible=true
	var e: Node=entrance.actor.get_ref()
	if is_instance_valid(e) and not e.dead:
		e.position=entrance.end
		e.cooldown=.7
		e.transition("approach")
		host.stage.sync(e,.001)
		var rig: Node=host.stage.actors.get(e.get_instance_id())
		if is_instance_valid(rig): rig.sprite.material=null; rig.modulate=Color.WHITE
	entrance.clear()

func skip() -> bool:
	if entrance.is_empty() or float(entrance.age)<.45: return false
	finish_arrival()
	return true

func _process(dt: float) -> void:
	if is_instance_valid(host.hud): host.hud.visible=entrance.is_empty() or host.paused or host.route_open or host.mode!="battle"
	if host.mode!="battle" or host.paused or host.route_open or host.over: return
	if not entrance.is_empty():
		entrance.age+=dt
		var e: Node=entrance.actor.get_ref()
		if not is_instance_valid(e) or e.dead: entrance.clear(); return
		var progress:=smoothstep(.55,1.90,float(entrance.age))
		e.position=Vector2(entrance.end)+Vector2(int(entrance.side)*105*(1-progress),0)
		e.velocity.x=-int(entrance.side)*100 if progress<1 else 0
		host.stage.sync(e,dt)
		visual.reveal_actor(e,progress)
		if entrance.age>=2.50:
			finish_arrival()
			host.play_sound("ultimate_hit",-18,.8)
	elif host.playing():
		riposte=maxf(0,riposte-dt)
		evade_cd=maxf(0,evade_cd-dt)

func perfect_evade() -> void:
	if evade_cd>0 or not host.playing(): return
	evade_cd=1.0
	perfect_count+=1
	riposte=1.15+rank("echo")*.6
	host.player.focus=minf(100,host.player.focus+12)
	if not host.ascension.visible_form(): Ascension.gain(2+rank("echo")*3)
	host.float_number(host.player.position+Vector2(0,-215),"精准闪避 · 反击 +35%",Color("b9faff"))
	if is_instance_valid(host.get("punch")): host.punch.evade()
	else: host.play_sound("feed",-19,1.6)
	host.refresh_hud()

func offer() -> void:
	var key: String=host.current_level().id
	if host.stage_index>=2 or claimed.has(key): return
	offers.assign(["edge","wind","spring"] if (host.level_index+host.stage_index)%2==0 else ["echo","edge","wind"])
	offer_active=true
	show_offer()

func pick(id: String) -> bool:
	if not offer_active or not id in offers: return false
	ranks[id]=rank(id)+1
	claimed[host.current_level().id]=id
	offer_active=false
	if is_instance_valid(modal): modal.queue_free()
	host.player.buffered=0
	host.player.jump_buffer=0
	host.toast("遗物已共鸣 · "+RELICS[id].title+" · 拾取药露后走右侧继续")
	host.refresh_hud()
	return true

func show_offer() -> void:
	if is_instance_valid(modal): modal.queue_free()
	modal=preload("res://rift/relic_menu.gd").new()
	modal.host=host
	modal.director=self
	host.hud.add_child(modal)
