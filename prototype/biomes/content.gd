extends RefCounted
## One authoritative roster for encounters, summons, previews and audits.
const ROSTERS:=[ ["melee","beetle","ranged"], ["crystal_crab","shaman","glow_jelly"], ["gale_sentinel","raven","storm_manta"], ["slag_hound","cinder_skitter","gear_gunner"] ]
const BOSSES:=[ ["boss","thorn_matriarch","zheng"], ["mycelium_boss","mirror_weaver","zhuyin"], ["tempest_boss","bell_colossus","yinglong"], ["cinder_boss","molten_wheel","paoxiao"] ]
const SCENES:=[ ["苔径初巡","古根廊桥","翡翠鹿坛"], ["菌灯引路","晶河穹窟","幽镜神殿"], ["断塔前哨","悬钟云桥","苍龙雷坛"], ["炉心初燃","齿轮铸坊","锁链炉心"] ]
const IDS:=["moss","cavern","storm","forge"]
const FLOORS:=[ [0.655,0.651,0.651], [0.654,0.654,0.637], [0.650,0.589,0.657], [0.657,0.633,0.651] ]
const CASTERS:=["ranged","shaman","glow_jelly","storm_manta","gear_gunner"]
const FLYERS:=["raven","glow_jelly","storm_manta"]
const NEW_KINDS:=["thorn_matriarch","mirror_weaver","bell_colossus","molten_wheel","crystal_crab","glow_jelly","gale_sentinel","storm_manta","slag_hound","gear_gunner","cinder_skitter"]
const SKILLS:={
	"melee":["枝刃横斩","踏步追斩","双枝连斩"],"beetle":["荆背冲撞","折返冲锋","棘刺震波"],"ranged":["灯羽直射","灯羽三散","追光点爆"],
	"crystal_crab":["晶钳重击","岩壳冲撞","碎晶震浪"],"shaman":["孢环锁定","双生孢环","孢雨散射"],"glow_jelly":["流光珠","三重幽光","触须雷池"],
	"gale_sentinel":["长戟横扫","风刃飞镰","回身连斩"],"raven":["俯冲啄击","旋羽追袭","逆羽三射"],"storm_manta":["天帆掠击","风压三刃","雷羽落印"],
	"slag_hound":["炉牙扑咬","连环跃扑","熔足震爆"],"cinder_skitter":["蛛刃突刺","熔芯散弹","过载冲锋"],"gear_gunner":["铳火直射","弧线榴弹","三连霰射"] }

static func waves(index: int, chapter: int) -> Array:
	var pool: Array=ROSTERS[index]
	var patterns: Array=[[[0,1],[1,0],[0,1]],[[0,1,2],[2,0,1],[1,2,0]],[[0,1,2],[2,0,1],[1,2,0],[0,2,1,0]]][chapter]
	var result: Array=[]
	for pattern in patterns:
		var wave: Array=[]
		for i in pattern.size(): wave.append([pool[pattern[i]], [690.0,860.0,1030.0,1170.0][i]])
		result.append(wave)
	result.append([[BOSSES[index][chapter],960.0]])
	return result

static func skill_tier(host: Node) -> int: return clampi(int(host.stage_index),0,2)
static func caster(kind: String) -> bool: return kind in CASTERS
static func flyer(kind: String) -> bool: return kind in FLYERS
