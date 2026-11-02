extends Node
## Independent kill-energy ledger. No desktop file operations occur here.
signal changed
const PATH:="user://ascension.json"
var storage_path:=PATH
var energy:=0
var total_kills:=0
var ledger: Array=[]
var save_enabled:=true
var future_version:=false
var dirty:=false

func _ready() -> void:
	save_enabled=get_node("/root/Profile").save_enabled
	if not save_enabled: return
	load_record()

func load_record() -> void:
	var d: Variant=read_record(storage_path)
	if not d is Dictionary: d=read_record(storage_path+".bak")
	if not d is Dictionary: return
	if int(d.get("version",0))>1:
		future_version=true
		return
	energy=clampi(int(d.get("energy",0)),0,100)
	total_kills=maxi(0,int(d.get("total_kills",0)))
	for id in d.get("ledger",[]):
		if id is String and id.length()<100 and not id in ledger: ledger.append(id)
	while ledger.size()>512: ledger.pop_front()

func read_record(path: String) -> Variant:
	if not FileAccess.file_exists(path): return null
	var d: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not d is Dictionary: return null
	if int(d.get("version",0))>1: return d
	if int(d.get("version",0))!=1 or not d.has_all(["energy","total_kills","ledger"]): return null
	if not d.energy is float and not d.energy is int: return null
	if not d.total_kills is float and not d.total_kills is int or not d.ledger is Array: return null
	return d

func reset() -> void:
	energy=0
	total_kills=0
	ledger=[]
	dirty=false
	changed.emit()

func record_kill(run_id: String, enemy_id: int, boss: bool) -> bool:
	var id:=run_id+":"+str(enemy_id)
	if run_id.is_empty() or enemy_id<=0 or id in ledger: return false
	ledger.append(id)
	while ledger.size()>512: ledger.pop_front()
	total_kills+=1
	energy=mini(100,energy+(10 if boss else 5))
	dirty=not save_record()
	changed.emit()
	return true

func gain(amount: int) -> void:
	energy=clampi(energy+amount,0,100)
	dirty=not save_record()
	changed.emit()

func consume() -> bool:
	if energy<100 or future_version: return false
	energy=0
	if not save_record():
		energy=100
		return false
	changed.emit()
	return true

func save_record() -> bool:
	if not save_enabled: return true
	if future_version: return false
	var data:={"version":1,"energy":energy,"total_kills":total_kills,"ledger":ledger}
	var f:=FileAccess.open(storage_path+".tmp",FileAccess.WRITE)
	if f==null: return false
	f.store_string(JSON.stringify(data))
	f.flush()
	var ok:=f.get_error()==OK
	f.close()
	if not ok: return false
	if FileAccess.file_exists(storage_path):
		if DirAccess.copy_absolute(storage_path,storage_path+".bak")!=OK: return false
	return DirAccess.rename_absolute(storage_path+".tmp",storage_path)==OK

func _exit_tree() -> void:
	if dirty: save_record()
