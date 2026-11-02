extends RefCounted
## Root coordinates are feet on the ground, or the raven's hovering root.
const DATA := {
	"thorn_matriarch":{"name":"棘冠鹿后","boss":true,"biome":true,"hp":840,"height":275.0,"body":Vector2(130,210),"hurt":Rect2(-146,-250,292,250),"color":Color("9de2bf")},
	"mirror_weaver":{"name":"镜丝蛛后","boss":true,"biome":true,"hp":940,"height":250.0,"body":Vector2(128,190),"hurt":Rect2(-148,-230,296,230),"color":Color("c9b1ff")},
	"bell_colossus":{"name":"鸣钟巨灵","boss":true,"biome":true,"hp":1020,"height":280.0,"body":Vector2(110,220),"hurt":Rect2(-128,-265,256,265),"color":Color("a1eaff")},
	"molten_wheel":{"name":"熔轮暴君","boss":true,"biome":true,"hp":1120,"height":255.0,"body":Vector2(126,210),"hurt":Rect2(-140,-240,280,240),"color":Color("ffb365")},
	"crystal_crab":{"name":"晶壳岩蟹","biome":true,"hp":145,"windup":.58,"height":126.0,"body":Vector2(82,90),"hurt":Rect2(-86,-120,172,120),"color":Color("cba6ff")},
	"glow_jelly":{"name":"悬灯水母","biome":true,"hp":92,"windup":.62,"height":148.0,"body":Vector2(50,65),"hurt":Rect2(-55,-140,110,140),"color":Color("a7ecff")},
	"gale_sentinel":{"name":"风刃卫","biome":true,"hp":124,"windup":.58,"height":172.0,"body":Vector2(46,138),"hurt":Rect2(-54,-162,108,162),"color":Color("a4defa")},
	"storm_manta":{"name":"天帆鳐","biome":true,"hp":98,"windup":.62,"height":128.0,"body":Vector2(64,65),"hurt":Rect2(-90,-122,180,122),"color":Color("91e6ff")},
	"slag_hound":{"name":"炉渣猎犬","biome":true,"hp":120,"windup":.58,"height":122.0,"body":Vector2(78,88),"hurt":Rect2(-82,-118,164,118),"color":Color("ffac6c")},
	"gear_gunner":{"name":"齿轮铳兵","biome":true,"hp":108,"windup":.64,"height":150.0,"body":Vector2(58,115),"hurt":Rect2(-64,-142,128,142),"color":Color("ffcf87")},
	"cinder_skitter":{"name":"熔芯蛛","biome":true,"hp":96,"windup":.56,"height":115.0,"body":Vector2(66,75),"hurt":Rect2(-78,-110,156,110),"color":Color("ffc482")},
	"zheng":{"name":"裂岳·狰","boss":true,"mythic":true,"hp":1120,"height":315.0,"body":Vector2(140,220),"hurt":Rect2(-155,-285,310,285),"color":Color("ffb074")},
	"zhuyin":{"name":"幽烛·烛阴","boss":true,"mythic":true,"hp":1240,"height":345.0,"body":Vector2(140,240),"hurt":Rect2(-150,-325,300,325),"color":Color("f683bc")},
	"yinglong":{"name":"天罚·应龙","boss":true,"mythic":true,"hp":1360,"height":325.0,"body":Vector2(145,230),"hurt":Rect2(-160,-305,320,305),"color":Color("83e9ff")},
	"paoxiao":{"name":"吞焰·狍鸮","boss":true,"mythic":true,"hp":1480,"height":320.0,"body":Vector2(160,235),"hurt":Rect2(-150,-295,300,295),"color":Color("ffb659")},
	"mycelium_boss":{"name":"荧冠菌王","boss":true,"hp":620,"height":286.0,"body":Vector2(92,225),"hurt":Rect2(-83,-265,166,265),"color":Color("c2a4ef")},
	"tempest_boss":{"name":"雷翼君王","boss":true,"hp":680,"height":294.0,"body":Vector2(84,217),"hurt":Rect2(-80,-262,160,262),"color":Color("a5d8f3")},
	"cinder_boss":{"name":"熔炉巨像","boss":true,"hp":760,"height":284.0,"body":Vector2(100,222),"hurt":Rect2(-92,-268,184,268),"color":Color("ffbe79")},
	"beetle":{"name":"荆背甲虫","hp":132,"windup":0.52,"height":116.0,"body":Vector2(82,82),"hurt":Rect2(-80,-112,160,112),"color":Color("e4b66b")},
	"shaman":{"name":"孢灯术士","hp":86,"windup":0.66,"height":170.0,"body":Vector2(44,136),"hurt":Rect2(-47,-165,94,165),"color":Color("d6a1d9")},
	"raven":{"name":"夜羽鸦","hp":74,"windup":0.48,"height":142.0,"body":Vector2(44,54),"hurt":Rect2(-48,-139,96,112),"color":Color("91d9e6")},
}
static func expanded(kind: String) -> bool:
	return DATA.has(kind)

static func title(kind: String) -> String:
	return DATA[kind].name if expanded(kind) else "古树守卫" if kind=="boss" else "灯蛾" if kind=="ranged" else "苔甲猎手"
