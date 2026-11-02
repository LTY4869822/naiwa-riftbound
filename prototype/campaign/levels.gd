extends RefCounted
## Four independent arenas. Each finishes only after its own guardian encounter.
const CONTENT=preload("res://biomes/content.gd")
const CATALOG=preload("res://combat/enemy_catalog.gd")
const LEVELS := [
	{"id":"moss","title":"苔光遗境","subtitle":"古林深处 · 叠叶与石门","boss":"boss","boss_name":"古树守卫","color":Color("8de4bf"),"background":"res://assets/biomes-v5/moss-1.png","floor_ratio":0.74074,
	"hint":"普攻积累失衡；抓住蓄力窗口重击破势，破势后有短暂保护"},
	{"id":"cavern","title":"荧菌洞窟","subtitle":"地下微光 · 菌冠苏醒","boss":"mycelium_boss","boss_name":"荧冠菌王","color":Color("c2a4ef"),"background":"res://assets/biomes-v5/cavern-1.png","floor_ratio":0.7459677419354839,
	"hint":"菌王会锁定三处孢环；趁抡臂后的空隙反击"},
	{"id":"storm","title":"风暴遗城","subtitle":"云海断塔 · 雷翼降临","boss":"tempest_boss","boss_name":"雷翼君王","color":Color("a5d8f3"),"background":"res://assets/biomes-v5/storm-1.png","floor_ratio":0.7419354838709677,
	"hint":"离开雷印避开落雷；掠翼突进后有反击窗口"},
	{"id":"forge","title":"熔火工坊","subtitle":"玄铁熔炉 · 炉心重燃","boss":"cinder_boss","boss_name":"熔炉巨像","color":Color("ffbe79"),"background":"res://assets/biomes-v5/forge-1.png","floor_ratio":0.7227822580645161,
	"hint":"避开重锤与地火；巨像过热恢复时承受更多伤害"},
]
static func get_level(index: int) -> Dictionary:
	index=clampi(index,0,LEVELS.size()-1)
	var d: Dictionary=LEVELS[index].duplicate(true)
	d.waves=CONTENT.waves(index,0)
	d.beats=["前哨遭遇","协同夹击","精锐围攻",d.boss_name]
	d.floor_ratio=CONTENT.FLOORS[index][0]
	return d

const STAGES:=3
const MYTHICS:=["zheng","zhuyin","yinglong","paoxiao"]
const MYTHIC_NAMES:=["裂岳·狰","幽烛·烛阴","天罚·应龙","吞焰·狍鸮"]
const CHAPTERS:=CONTENT.SCENES
static func get_stage(index: int, chapter: int=0) -> Dictionary:
	index=clampi(index,0,3)
	chapter=clampi(chapter,0,2)
	var d: Dictionary=get_level(index).duplicate(true)
	d["map_title"]=d.title
	d["chapter"]=chapter
	d["chapter_title"]=CONTENT.SCENES[index][chapter]
	d["title"]=d.title+" · "+str(chapter+1)+"/3"
	d["health_scale"]=[1.0,1.22,1.42][chapter]
	d["damage_scale"]=[1.0,1.10,1.22][chapter]
	d["skill_tier"]=chapter+1
	d["roster"]=CONTENT.ROSTERS[index].duplicate()
	d["boss"]=CONTENT.BOSSES[index][chapter]
	d["boss_name"]=CATALOG.title(d.boss)
	d["waves"]=CONTENT.waves(index,chapter)
	d["beats"]=["前哨遭遇","协同夹击","精锐围攻","终阵突围"]
	d.beats.resize(d.waves.size()-1)
	d.beats.append(CONTENT.SCENES[index][chapter]+" · "+str(d.boss_name))
	d["hint"]=["识别蓄力，重击破甲；击败守关者后向右前进","第三兵种加入战斗 · 留意追击与散射","连击、远近夹击全面强化 · 留好闪避体力"][chapter]
	d["floor_ratio"]=CONTENT.FLOORS[index][chapter]
	if chapter>0:
		d.id=str(d.id)+"-"+str(chapter+1)
		d.background="res://assets/biomes-v5/"+CONTENT.IDS[index]+"-"+str(chapter+1)+".png"
	return d

static func wave_count(index: int, chapter: int=0) -> int:
	return get_stage(index,chapter).waves.size()
