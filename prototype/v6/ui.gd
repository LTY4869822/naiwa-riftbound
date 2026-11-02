extends RefCounted
const BASE=preload("res://v5/ui.gd")
static func build(h: Node) -> void:
	if h.mode=="desktop": return
	if h.mode=="camp":
		var menu: Control=(preload("res://loop/gear_menu.gd") if h.menu_section=="gear" else preload("res://wardrobe/shop.gd") if h.menu_section=="shop" else preload("res://remediation/controls_page.gd") if h.menu_section=="controls" else preload("res://v6/menu.gd")).new()
		menu.host=h
		h.hud.add_child(menu)
	else: BASE.battle(h)
