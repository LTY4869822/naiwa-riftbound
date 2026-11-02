extends "res://v5/sticker_button.gd"
var item: Dictionary
var selected:=false
var preview: Texture2D

func _ready() -> void:
	super._ready()
	if item.get("original",false):
		var source: Texture2D=load(item.preview)
		var atlas:=AtlasTexture.new()
		atlas.atlas=source
		atlas.region=source.get_image().get_used_rect()
		preview=atlas
	tooltip_text=item.title+" · "+("原初外观，已拥有" if item.get("original",false) else "皮肤待上架，上架后支持成长解锁或巡游币购买")

func _draw() -> void:
	var rect:=Rect2(3,2,size.x-7,size.y-10)
	var box:=StyleBoxFlat.new()
	box.bg_color=Color("271436") if selected else Color("181221")
	box.border_color=ACID if selected else Color("55405f")
	box.set_border_width_all(2 if selected else 1)
	box.set_corner_radius_all(19)
	box.shadow_color=Color("0a0710")
	box.shadow_size=1
	box.shadow_offset=Vector2(2,6)
	draw_style_box(box,rect)
	if selected or has_focus():
		box.bg_color=Color.TRANSPARENT
		box.border_color=ACID
		box.set_border_width_all(2)
		draw_style_box(box,rect.grow(4))
	var original: bool=item.get("original",false)
	var fg:=WHITE
	if preview!=null:
		var factor: float=minf(77/preview.get_size().x,123/preview.get_size().y)
		var dimensions: Vector2=preview.get_size()*factor
		draw_circle(Vector2(60,84),46,Color("3d234e"))
		draw_texture_rect(preview,Rect2(Vector2(60,84)-dimensions/2,dimensions),false)
	else:
		draw_circle(Vector2(61,84),43,Color("362140"))
		draw_set_transform(Vector2(61,84),0,Vector2.ONE*0.85)
		draw_icon("shop",Color("796385"),Color("362140"))
		draw_set_transform(Vector2.ZERO)
	var display_font: Font=title_font if title_font!=null else get_theme_default_font()
	var copy_font: Font=body_font if body_font!=null else display_font
	draw_string(display_font,Vector2(122,42),"原初收藏" if original else "COMING SOON",HORIZONTAL_ALIGNMENT_LEFT,210,12,ACID if original else Color("b996cc"))
	draw_string(display_font,Vector2(122,78),item.title,HORIZONTAL_ALIGNMENT_LEFT,size.x-143,21,fg)
	draw_string(copy_font,Vector2(123,106),"一直陪着你的第一位伙伴" if original else "新外观即将登场",HORIZONTAL_ALIGNMENT_LEFT,size.x-143,14,Color("c8b8d4"))
	var state: String=Wardrobe.state(item.id)
	draw_string(display_font,Vector2(123,139),"穿着中" if state=="equipped" else "已拥有" if state=="owned" else "成长解锁  /  巡游兑换",HORIZONTAL_ALIGNMENT_LEFT,size.x-143,14,ACID if original else Color("c09cdb"))
