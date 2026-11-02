extends RefCounted
const TITLES := ["苔径巡游","荆棘孢林","夜羽回廊","古树守卫"]
const WAVES := [
	[["melee",730.0],["melee",910.0],["ranged",1130.0]],
	[["beetle",770.0],["shaman",1090.0],["melee",940.0]],
	[["raven",830.0],["beetle",1030.0],["ranged",1140.0]],
	[["boss",900.0],["shaman",1140.0]],
]
const HINTS := ["灯蛾会远程投射，注意瞄准线","甲虫冲撞前会压低角；离开孢子圆环避开爆发","夜羽鸦锁定位置后俯冲，侧移或闪避后反击","守卫蓄力时抗轻击，重击可破势；先处理术士"]
static func spawn_wave(h: Node) -> void:
	var level: Dictionary=h.current_level()
	var index: int=clampi(h.wave-1,0,level.waves.size()-1)
	for spec in level.waves[index]: h.spawn(spec[0],spec[1])
	if is_instance_valid(h.get("training")): h.training.beat()
	h.toast("%s · %s    %s" % [level.title,level.beats[index],level.hint if index==level.waves.size()-1 else "击退守军，迎战本关守护者"])
	h.build_ui()
