extends Node
## Versioned cosmetic economy, separate from legacy profile writers and pet receipts.
signal changed
signal growth_unlocked(ids: Array[String])
const CATALOG=preload("res://wardrobe/catalog.gd")
const SAVE_PATH:="user://wardrobe.json"
const MAX_AMOUNT:=2000000000
var save_path:=SAVE_PATH
var save_enabled:=true
var read_only:=false
var save_error:=""
var catalog: Array=CATALOG.SKINS.duplicate(true)
var coins:=0
var earned:=0
var spent:=0
var clears: Dictionary={}
var rewarded_runs: Array[String]=[]
var owned: Array[String]=[CATALOG.ORIGINAL]
var equipped:=CATALOG.ORIGINAL
var _claimed: Dictionary={}
var profile: Node
const GEAR=preload("res://loop/gear.gd")
var loot_ledger: Array=[]
var gear_ranks: Dictionary={}

func _ready() -> void:
	profile=get_node("/root/Profile")
	save_enabled=profile.save_enabled
	if save_enabled: load_store()
	profile.changed.connect(sync_growth_unlocks)
	if save_enabled: call_deferred("sync_growth_unlocks")

func skin(id: String) -> Dictionary:
	for item in catalog:
		if item.id==id: return item
	return {}

func reset() -> void:
	coins=0
	earned=0
	spent=0
	clears.clear()
	rewarded_runs.clear()
	_claimed.clear()
	owned=[CATALOG.ORIGINAL]
	equipped=CATALOG.ORIGINAL
	read_only=false
	save_error=""
	loot_ledger=[]
	gear_ranks={}

func growth_ready(item: Dictionary) -> bool:
	return is_instance_valid(profile) and item.get("growth",false) and profile.level>=int(item.get("level",MAX_AMOUNT)) and profile.recycle_bytes_total>=int(item.get("bytes",9007199254740991))

func sync_growth_unlocks() -> Array[String]:
	var unlocked: Array[String]=[]
	if read_only: return unlocked
	var before:=to_dict()
	for item in catalog:
		if item.id not in owned and CATALOG.assets_ready(item) and growth_ready(item):
			owned.append(item.id)
			unlocked.append(item.id)
	if not unlocked.is_empty():
		if not commit(before): unlocked.clear()
		else: growth_unlocked.emit(unlocked)
	return unlocked

func state(id: String) -> String:
	var item:=skin(id)
	if item.is_empty(): return "missing"
	if id in owned: return "equipped" if id==equipped else "owned"
	if not CATALOG.assets_ready(item): return "coming_soon"
	if growth_ready(item): return "free"
	if item.get("coins",false) and int(item.get("price",0))>0: return "buy" if coins>=int(item.price) else "insufficient"
	return "locked"

func acquire(id: String, method: String) -> Dictionary:
	var item:=skin(id)
	if item.is_empty(): return {"ok":false,"reason":"missing"}
	if id in owned: return {"ok":true,"duplicate":true,"cost":0}
	if not CATALOG.assets_ready(item): return {"ok":false,"reason":"coming_soon"}
	var cost:=0
	if method=="growth":
		if not growth_ready(item): return {"ok":false,"reason":"growth_locked"}
	elif method=="coins":
		if growth_ready(item): return {"ok":false,"reason":"available_free"}
		if not item.get("coins",false) or int(item.get("price",0))<=0: return {"ok":false,"reason":"not_for_sale"}
		cost=int(item.price)
		if coins<cost: return {"ok":false,"reason":"insufficient"}
	else: return {"ok":false,"reason":"invalid_method"}
	var before:=to_dict()
	coins-=cost
	spent+=cost
	owned.append(id)
	if not commit(before): return {"ok":false,"reason":"save_failed"}
	return {"ok":true,"duplicate":false,"cost":cost}

func equip(id: String) -> bool:
	if id not in owned or not CATALOG.assets_ready(skin(id)): return false
	if equipped==id: return true
	var before:=to_dict()
	equipped=id
	return commit(before)

func award_clear(level_id: String, run_id: String) -> Dictionary:
	if not CATALOG.REWARDS.has(level_id) or not valid_id(run_id,32): return {"ok":false,"reason":"invalid_run"}
	if _claimed.has(run_id): return {"ok":true,"duplicate":true,"amount":0,"first":false}
	var first: bool=int(clears.get(level_id,0))==0
	var amount: int=CATALOG.REWARDS[level_id]["first" if first else "repeat"]
	if earned>MAX_AMOUNT-amount: return {"ok":false,"reason":"wallet_full"}
	var before:=to_dict()
	coins+=amount
	earned+=amount
	clears[level_id]=int(clears.get(level_id,0))+1
	rewarded_runs.append(run_id)
	_claimed[run_id]=true
	if not commit(before): return {"ok":false,"reason":"save_failed","amount":0,"first":first}
	return {"ok":true,"duplicate":false,"amount":amount,"first":first,"level":level_id}

func commit(before: Dictionary) -> bool:
	if not save_store():
		apply(before)
		return false
	changed.emit()
	return true

func award_loot(run_id: String, drop_id: int, amount: int) -> Dictionary:
	if not valid_id(run_id,32) or drop_id<=0 or amount<=0 or amount>1000: return {"ok":false}
	var key:=run_id+"-"+str(drop_id)
	if key in loot_ledger: return {"ok":true,"duplicate":true,"amount":0}
	if earned>MAX_AMOUNT-amount: return {"ok":false}
	var before:=to_dict()
	coins+=amount
	earned+=amount
	loot_ledger.append(key)
	while loot_ledger.size()>2048: loot_ledger.pop_front()
	if not commit(before): return {"ok":false,"reason":"save_failed"}
	return {"ok":true,"amount":amount}

func gear_rank(id: String) -> int: return int(gear_ranks.get(id,0))

func buy_gear(id: String) -> Dictionary:
	if not GEAR.ITEMS.has(id): return {"ok":false,"reason":"missing"}
	var rank:=gear_rank(id)
	if rank>=3: return {"ok":false,"reason":"max_rank"}
	var cost: int=GEAR.ITEMS[id].costs[rank]
	if coins<cost: return {"ok":false,"reason":"insufficient"}
	var before:=to_dict()
	coins-=cost
	spent+=cost
	gear_ranks[id]=rank+1
	if not commit(before): return {"ok":false,"reason":"save_failed"}
	return {"ok":true,"rank":rank+1,"cost":cost}

func to_dict() -> Dictionary:
	return {"version":1,"coins":coins,"earned":earned,"spent":spent,"clears":clears.duplicate(true),"rewarded_runs":rewarded_runs.duplicate(),"owned":owned.duplicate(),"equipped":equipped,"loot_ledger":loot_ledger.duplicate(),"gear_ranks":gear_ranks.duplicate()}

func apply(data: Dictionary) -> void:
	coins=int(data.coins)
	earned=int(data.earned)
	spent=int(data.spent)
	clears.clear()
	for id in data.clears: clears[id]=int(data.clears[id])
	rewarded_runs.assign(data.rewarded_runs)
	owned.assign(data.owned)
	equipped=data.equipped
	loot_ledger=data.get("loot_ledger",[]).duplicate()
	gear_ranks=data.get("gear_ranks",{}).duplicate()
	_claimed.clear()
	for id in rewarded_runs: _claimed[id]=true

func valid_integer(value: Variant, maximum: int=MAX_AMOUNT) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)>=0 and float(value)<=maximum and floor(float(value))==float(value)

func valid_id(value: Variant, length: int=0) -> bool:
	if not value is String or value.is_empty() or value.length()>80: return false
	if length>0 and value.length()!=length: return false
	for c in value:
		if c not in ("0123456789abcdef" if length>0 else "abcdefghijklmnopqrstuvwxyz0123456789-_"): return false
	return true

func valid(data: Variant) -> bool:
	if not data is Dictionary or not data.has_all(["version","coins","earned","spent","clears","rewarded_runs","owned","equipped"]): return false
	if not valid_integer(data.version,1) or int(data.version)!=1: return false
	for key in ["coins","earned","spent"]:
		if not valid_integer(data[key]): return false
	if int(data.earned)-int(data.spent)!=int(data.coins): return false
	if not data.clears is Dictionary or not data.owned is Array or not data.rewarded_runs is Array: return false
	for key in data.clears:
		if not CATALOG.REWARDS.has(key) or not valid_integer(data.clears[key]): return false
	for key in ["owned","rewarded_runs"]:
		var seen: Dictionary={}
		for id in data[key]:
			if not valid_id(id,32 if key=="rewarded_runs" else 0) or seen.has(id): return false
			seen[id]=true
	if not data.get("loot_ledger",[]) is Array or not data.get("gear_ranks",{}) is Dictionary: return false
	var loot_seen: Dictionary={}
	for id in data.get("loot_ledger",[]):
		if not valid_id(id) or loot_seen.has(id): return false
		loot_seen[id]=true
	for id in data.get("gear_ranks",{}):
		if not GEAR.ITEMS.has(id) or not valid_integer(data.gear_ranks[id],3): return false
	return CATALOG.ORIGINAL in data.owned and data.equipped in data.owned

func save_store() -> bool:
	if read_only:
		save_error="商城存档来自更新版本，请先更新游戏。"
		return false
	if not save_enabled: return true
	var data:=to_dict()
	if not valid(data):
		save_error="商城数据未通过校验，本次操作未保存。"
		return false
	var file:=FileAccess.open(save_path+".tmp",FileAccess.WRITE)
	if file==null:
		save_error="商城进度暂未保存，请稍后重试。"
		return false
	file.store_string(JSON.stringify(data,"\t"))
	file.flush()
	var error:=file.get_error()
	file.close()
	if error!=OK:
		save_error="商城写入未完成，原进度保持不变。"
		return false
	if FileAccess.file_exists(save_path) and DirAccess.copy_absolute(save_path,save_path+".bak")!=OK:
		save_error="商城备份失败，原进度保持不变。"
		return false
	if DirAccess.rename_absolute(save_path+".tmp",save_path)!=OK:
		save_error="商城存档替换失败，请稍后重试。"
		return false
	save_error=""
	return true

func load_store() -> bool:
	if not save_enabled: return false
	var had_file:=false
	for path in [save_path,save_path+".bak"]:
		if not FileAccess.file_exists(path): continue
		had_file=true
		var parser:=JSON.new()
		if parser.parse(FileAccess.get_file_as_string(path))!=OK: continue
		var raw=parser.data
		if raw is Dictionary and raw.get("version",0) is float and float(raw.version)>1:
			read_only=true
			save_error="商城存档来自更新版本，请先更新游戏。"
			return false
		if valid(raw):
			apply(raw)
			save_error="" if path==save_path else "已恢复上一次保存的商城进度。"
			return true
	if had_file:
		read_only=true
		save_error="商城存档与备份均无法读取，已保留原文件。"
	return false
