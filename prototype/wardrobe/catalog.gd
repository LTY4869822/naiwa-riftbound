extends RefCounted
## Configure real skins here when their menu, combat and desktop assets are supplied.
const ORIGINAL:="naiwa-original"
const REWARDS:={"moss":{"first":120,"repeat":30},"moss-2":{"first":190,"repeat":48},"moss-3":{"first":300,"repeat":75},"cavern":{"first":180,"repeat":45},"cavern-2":{"first":270,"repeat":68},"cavern-3":{"first":420,"repeat":105},"storm":{"first":240,"repeat":60},"storm-2":{"first":360,"repeat":90},"storm-3":{"first":540,"repeat":135},"forge":{"first":300,"repeat":75},"forge-2":{"first":450,"repeat":112},"forge-3":{"first":680,"repeat":170}}
const SKINS:=[
	{"id":ORIGINAL,"title":"奶蛙 · 原初","published":true,"original":true,"preview":"res://assets/menu-v2/pet/front-idle.png","level":1,"bytes":0,"price":0,"growth":false,"coins":false},
	{"id":"reserved-01","title":"下一份惊喜","published":false,"original":false,"preview":"","level":0,"bytes":0,"price":0,"growth":true,"coins":true},
	{"id":"reserved-02","title":"新的冒险搭档","published":false,"original":false,"preview":"","level":0,"bytes":0,"price":0,"growth":true,"coins":true},
	{"id":"reserved-03","title":"留给未来的收藏","published":false,"original":false,"preview":"","level":0,"bytes":0,"price":0,"growth":true,"coins":true},
]

static func assets_ready(skin: Dictionary) -> bool:
	if not skin.get("published",false): return false
	if skin.get("original",false): return true
	for key in ["preview","combat_manifest","desktop_manifest"]:
		if str(skin.get(key,"")).is_empty() or not FileAccess.file_exists(str(skin[key])): return false
	return true
