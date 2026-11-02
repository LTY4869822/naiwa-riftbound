extends Control
const T=preload("res://echo/ink.gd")
var host: Node
var title: String
var bold: Font
var age:=0.0
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	position=Vector2(-195,270); size=Vector2(390,70); pivot_offset=size*.5
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	z_index=25
func _process(dt: float) -> void:
	age+=dt
	modulate.a=1-smoothstep(.65,.95,age)
	scale=Vector2.ONE if host.reduce_motion else Vector2.ONE*(1+.10*exp(-age*12)*cos(age*24))
	rotation_degrees=0 if host.reduce_motion else -2
	queue_redraw()
	if age>.95: queue_free()
func _draw() -> void:
	draw_colored_polygon(T.ticket(Rect2(5,7,380,64)),T.color("ink"))
	draw_colored_polygon(T.ticket(Rect2(0,0,380,64)),T.color("focus"))
	T.words(self,bold,"共鸣成功 · "+title,Vector2(190,42),25,T.color("ink"),350,true)
