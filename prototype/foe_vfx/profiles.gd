extends RefCounted
## Material identities. Gameplay reach/timing remain authoritative in enemy scripts.
const DATA := {
	"melee":{"name":"苔甲猎手","material":"leaf","palette":[Color("f4ffdb"),Color("b4f275"),Color("398f57"),Color("152f2b")]},
	"ranged":{"name":"灯蛾","material":"lantern","palette":[Color("fffad7"),Color("ffd34e"),Color("f47a24"),Color("542b39")]},
	"beetle":{"name":"荆背甲虫","material":"earth","palette":[Color("fff6d5"),Color("e9bf66"),Color("ae7144"),Color("44323b")]},
	"shaman":{"name":"孢灯术士","material":"spore","palette":[Color("fff0ff"),Color("e0aaff"),Color("924bb7"),Color("37264d")]},
	"raven":{"name":"夜羽鸦","material":"wind","palette":[Color("f5ffff"),Color("a1f3f4"),Color("4798cb"),Color("19334c")]},
	"boss":{"name":"古树守卫","material":"root","palette":[Color("f6ffd4"),Color("b5e878"),Color("698853"),Color("303a30")]},
	"mycelium_boss":{"name":"荧冠菌王","material":"mycelium","palette":[Color("fff0ff"),Color("e6bdff"),Color("995dc1"),Color("392449")]},
	"tempest_boss":{"name":"雷翼君王","material":"storm","palette":[Color("f5ffff"),Color("83e8ff"),Color("7761df"),Color("29284f")]},
	"cinder_boss":{"name":"熔炉巨像","material":"fire","palette":[Color("fff6be"),Color("ffc82f"),Color("f75b1c"),Color("542330")]},
}
const LEGACY := ["thorn_launch","thorn_dust","raven_launch","raven_trail","spore_cast","spore_burst","crown_cast","storm_cast","forge_slam","wing_cut","crown_sweep","boss_spore","boss_lightning","boss_eruption","armor_spark","boss_enrage","muzzle"]
static func profile(kind: String) -> Dictionary:
	return DATA.get(kind,DATA.melee)
