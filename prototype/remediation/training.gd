extends Node
## Teach core actions in the first room. Lessons use the durable XP ledger.
var host: Node
var label: Label
var objective:=""
var hint_time:=7.0
const COPY:={"combo":"练习连击：普攻命中目标，连续按攻击键衔接三段。","heavy":"练习破甲：甲虫正面有护甲，用重击抓住蓄力窗口。","dash":"练习闪避：离开冲撞路线，或在攻击命中前使用闪避。","ultimate":"奥义就绪：攻击积累60专注，释放星核巨拳。"}

func _ready() -> void:
	var layer:=CanvasLayer.new()
	layer.layer=4
	add_child(layer)
	label=Label.new()
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	label.position=Vector2(-360,262)
	label.size=Vector2(720,60)
	label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",18)
	label.add_theme_constant_override("outline_size",6)
	label.add_theme_color_override("font_outline_color",Color("132735"))
	label.add_theme_color_override("font_color",Color("ecf5cf"))
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	layer.add_child(label)

func beat() -> void:
	hint_time=7
	objective=""
	if host.level_index==0 and host.stage_index==0 and host.intro_training():
		objective="combo" if host.wave==1 else "heavy" if host.wave==2 else "dash" if host.wave==3 else "ultimate" if host.wave==4 else ""
	update_text()

func complete(key: String) -> void:
	if host.level_index!=0 or host.stage_index!=0 or key!=objective: return
	var id: String="lesson-moss-"+key
	if id in Profile.consumed: return
	Profile.consumed.append(id)
	Profile.add_xp(12)
	Profile.save_profile()
	hint_time=2.5
	host.toast("训练完成 · +12 XP"+" · 升级啦" if Profile.level>=2 and key=="dash" else "训练完成 · +12 XP")
	host.play_sound("feed",-23,1.3)
	update_text()

func update_text() -> void:
	if label==null: return
	label.add_theme_font_size_override("font_size",Preferences.font_size(18))
	label.text=COPY.get(objective,"")
	if host.intro_training() and not objective.is_empty(): label.text="初次巡游 · 基础练习  "+label.text
	if "lesson-moss-"+objective in Profile.consumed and not objective.is_empty(): label.text="✓ 已掌握  "+label.text
	if host.level_index==1: label.text="靠近净化灯，按交互键驱散附近的孢圈。"
	elif host.level_index==2: label.text="跳上高台躲避地面雷潮；空中仍需留意首领落雷。"
	elif host.level_index==3: label.text="左右区域交替过热；中间散热台可补充专注。"

func _process(dt: float) -> void:
	if label==null: return
	if host.playing() and host.hitstop<=0: hint_time=maxf(0,hint_time-dt)
	var boss_ult:=false
	for e in host.enemies:
		if is_instance_valid(e) and not e.dead and e.state in ["ult_tell","ult_active"]: boss_ult=true
	var pending: bool=not objective.is_empty() and "lesson-moss-"+objective not in Profile.consumed
	label.visible=host.mode=="battle" and not host.over and not host.route_open and not host.paused and not boss_ult and (pending or hint_time>0) and (not is_instance_valid(host.get("spectacle")) or host.spectacle.cutin_age>=0.72)
	if is_instance_valid(host.get("ascension")) and host.ascension.cinematic(): label.visible=false
	if is_instance_valid(host.get("journey")) and host.journey.cleared: label.visible=false
	if is_instance_valid(host.get("rift")) and host.rift.blocked(): label.visible=false
