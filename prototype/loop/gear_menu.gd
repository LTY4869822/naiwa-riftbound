extends "res://v5/menu.gd"
const GEAR=preload("res://loop/gear.gd")
const ICONS=preload("res://v5/hud_glyphs.gd")
var forging:=false
func build() -> void:
	var i:=0
	for id in GEAR.ITEMS:
		var key: String=id
		var d: Dictionary=GEAR.ITEMS[id]
		var rank:=Wardrobe.gear_rank(id)
		var title: String="已锻至满阶" if rank>=3 else ("购买并装备" if rank==0 else "锻造至 %d 阶" % (rank+1))+" · %d 金币" % int(d.costs[mini(rank,2)])
		var b:=sticker("Forge_"+id,Vector2(91+i*403,567),Vector2(362,69),title,"",func():
			if forging: return
			forging=true
			var result: Dictionary=Wardrobe.buy_gear(key)
			host.toast("装备已生效 · "+GEAR.ITEMS[key].title if result.get("ok",false) else "金币不足，去遗境里拾取更多金币" if result.get("reason","")=="insufficient" else "锻造暂未完成，请重试")
			host.build_ui(),PURPLE if rank<3 else INK)
		b.large=false
		b.disabled=rank>=3
		i+=1
	sticker("GearBack",Vector2(70,673),Vector2(210,58),"返回营地","",func(): navigate("home"),INK,"",0,"back")
	sticker("GearSkins",Vector2(456,673),Vector2(320,58),"皮肤商城","",host.open_shop,PURPLE,"",0,"shop")
	sticker("GearContinue",Vector2(916,673),Vector2(293,58),"继续当前旅程","",host.enter_battle,YELLOW,"",0,"play").primary=true
	for j in buttons.size():
		buttons[j].focus_next=buttons[j].get_path_to(buttons[(j+1)%buttons.size()])
		buttons[j].focus_neighbor_right=buttons[j].focus_next
		buttons[j].focus_previous=buttons[j].get_path_to(buttons[(j-1+buttons.size())%buttons.size()])
		buttons[j].focus_neighbor_left=buttons[j].focus_previous
	host.call_deferred("focus_control",buttons[0])

func paint() -> void:
	paint_logo()
	paint_profile()
	outlined("巡游装备工坊",Vector2(68,247),43)
	label_at("可用金币  %d" % Wardrobe.coins,Vector2(921,247),23,YELLOW,true)
	label_at("击败敌人后走近拾取金币；购买即装备，锻造可升至三阶。",Vector2(73,283),17,Color("d7cce2"))
	var i:=0
	for id in GEAR.ITEMS:
		var d: Dictionary=GEAR.ITEMS[id]
		var x: float=76+i*403
		var rank:=Wardrobe.gear_rank(id)
		panel_at(Rect2(x,315,376,337))
		canvas.draw_circle(Vector2(x+187,405),58,Color(d.color,0.13))
		canvas.draw_arc(Vector2(x+187,405),60,0,TAU,64,d.color,2,true)
		ICONS.draw_icon(canvas,d.glyph,Vector2(x+187,405),35,d.color)
		label_at(d.title,Vector2(x+91,492),28,PAPER,true)
		label_at(d.slot+" · "+("尚未获得" if rank==0 else "已装备 · %d阶" % rank),Vector2(x+105,525),16,d.color)
		label_at(d.copy,Vector2(x+94,552),16,Color("c9bad5"))
		i+=1
