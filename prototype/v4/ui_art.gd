extends Control
const A = preload("res://v4/art.gd")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _draw() -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(0,0),Vector2(568,0),Vector2(451,800),Vector2(0,800)]),A.INK)
	draw_colored_polygon(PackedVector2Array([Vector2(568,0),Vector2(598,0),Vector2(481,800),Vector2(451,800)]),A.CYAN)
	draw_colored_polygon(PackedVector2Array([Vector2(598,0),Vector2(609,0),Vector2(492,800),Vector2(481,800)]),A.INK)
	draw_colored_polygon(PackedVector2Array([Vector2(700,628),Vector2(1132,628),Vector2(1101,749),Vector2(679,749)]),A.INK)
	for i in range(4):
		var p := Vector2(438+i*19,76)
		draw_colored_polygon(PackedVector2Array([p,p+Vector2(10,0),p+Vector2(2,24),p+Vector2(-8,24)]),A.CYAN)
	draw_arc(Vector2(924,444),199,-1.05,1.20,60,A.PAPER,2,true)
	draw_arc(Vector2(924,444),209,2.0,4.12,60,A.CYAN,2,true)
	for i in range(3):
		var p := Vector2(651+i*24,215+i*40)
		draw_colored_polygon(PackedVector2Array([p+Vector2(0,-12),p+Vector2(9,0),p+Vector2(0,12),p+Vector2(-9,0)]),A.PAPER)
