extends Node
const PROFILES = preload("res://foe_vfx/profiles.gd")
const KINDS := ["melee","ranged","beetle","shaman","raven","boss","mycelium_boss","tempest_boss","cinder_boss"]
const MAPS := [0,0,0,1,2,0,1,2,3]
var host: Node
var selected:=0
var opponent: Node
var instructions: Label

func _ready() -> void:
	Profile.level=3
	host.get_window().title="奶蛙 · 忍术风攻击演武（不保存）" if "--toon-lab" in OS.get_cmdline_user_args() else "奶蛙 · 敌人攻击演武（隔离试玩，不保存）"
	var layer:=CanvasLayer.new()
	layer.layer=3
	add_child(layer)
	instructions=Label.new()
	instructions.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	instructions.position=Vector2(160,263)
	instructions.size=Vector2(960,40)
	instructions.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	instructions.add_theme_font_size_override("font_size",15)
	instructions.add_theme_color_override("font_color",Color("fff0bf"))
	instructions.add_theme_color_override("font_outline_color",Color("12222a"))
	instructions.add_theme_constant_override("outline_size",5)
	instructions.mouse_filter=Control.MOUSE_FILTER_IGNORE
	layer.add_child(instructions)
	choose(8 if "--toon-lab" in OS.get_cmdline_user_args() else 0)

func choose(index: int) -> void:
	selected=clampi(index,0,8)
	host.choose_level(MAPS[selected])
	host.wave=host.CAMPAIGN.wave_count(host.level_index)
	opponent=host.spawn(KINDS[selected],830)
	host.build_ui()
	instructions.text="1 猎手  2 灯蛾  3 甲虫  4 术士  5 夜鸦  6 古树  7 菌王  8 雷翼  9 熔炉  ·  R 重试  T 换招"
	host.toast(PROFILES.profile(KINDS[selected]).name+" · 正常战斗规则，J / K 攻击，L 闪避")

func _process(_dt: float) -> void:
	instructions.visible=host.mode=="battle"

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or host.mode=="desktop": return
	if event.keycode>=KEY_1 and event.keycode<=KEY_9:
		choose(event.keycode-KEY_1)
		get_viewport().set_input_as_handled()
	elif event.keycode==KEY_R:
		choose(selected)
		get_viewport().set_input_as_handled()
	elif event.keycode==KEY_T and is_instance_valid(opponent) and not opponent.dead and host.playing():
		opponent.begin_attack()
		host.toast(PROFILES.profile(opponent.kind).name+" · 下一招")
		get_viewport().set_input_as_handled()
