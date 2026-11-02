extends Node

signal changed
signal recycle_imported(items: int, bytes: int, earned_xp: int, levels: int)

const SAVE_PATH := "user://profile.json"
const RECYCLE_BYTES_PER_XP: int = 8 * 1024 * 1024
const MAX_RECEIPT_BYTES: int = 32 * 1024 * 1024 * 1024
const MAX_RECEIPT_ITEMS: int = 1000
const MAX_RECEIPT_JSON: int = 256 * 1024
const MAX_JSON_INTEGER: int = 9007199254740991
const MAX_LEVEL: int = 1000
var save_path: String = SAVE_PATH
var xp: int = 0
var level: int = 1
var fed: int = 0
var wins: int = 0
var defeats: int = 0
var next_id: int = 1
var files: Array[Dictionary] = []
var consumed: Array[String] = []
var save_enabled: bool = true
var save_error: String = ""
# Real recycle-bin receipts have a separate ledger from virtual inventory feeds.
var recycle_bytes_total: int = 0
var recycle_xp_total: int = 0
var recycle_items_total: int = 0
var recycle_remainder_bytes: int = 0
var recycle_receipts: Array[String] = []
var recycle_consumed: Array[String] = []
var recycle_receipts_dir: String = ""
var recycle_error: String = ""
var recycle_last_import: Dictionary = {}
var _receipt_lookup: Dictionary = {}
var _recycle_item_lookup: Dictionary = {}
var _recycle_polling: bool = false
var _recycle_scan_cursor: int = 0

func _ready() -> void:
	save_enabled = not ("--smoke-test" in OS.get_cmdline_user_args() or "--visual-check" in OS.get_cmdline_user_args() or "--profile-test" in OS.get_cmdline_user_args() or "--recycle-test" in OS.get_cmdline_user_args() or "--pet-check" in OS.get_cmdline_user_args() or "--slice-test" in OS.get_cmdline_user_args() or "--slice-visual" in OS.get_cmdline_user_args() or "--bridge-check" in OS.get_cmdline_user_args() or "--balance-check" in OS.get_cmdline_user_args())
	if not load_profile():
		reset_profile()
	# Isolated modes never resolve or enumerate the user's real receipts directory.
	if save_enabled and OS.has_feature("windows"):
		var local_data := OS.get_environment("LOCALAPPDATA")
		if not local_data.is_empty():
			recycle_receipts_dir = local_data.path_join("NaiwaDesktopPet/recycle-feed/receipts")
			_start_recycle_polling()

func _start_recycle_polling() -> void:
	if not save_enabled or recycle_receipts_dir.is_empty() or get_node_or_null("RecycleReceiptTimer")!=null: return
	var timer := Timer.new()
	timer.name="RecycleReceiptTimer"
	timer.wait_time=1.0
	timer.timeout.connect(poll_recycle_receipts)
	add_child(timer)
	timer.start()
	call_deferred("poll_recycle_receipts")

func needed() -> int:
	return 60 + (level - 1) * 30

func damage() -> int:
	return 24 + (level - 1) * 7 + equipment_bonus("bracer",3)

func max_health() -> int:
	return 100 + (level - 1) * 12 + equipment_bonus("charm",16)

func equipment_bonus(id: String, per_rank: int) -> int:
	var store: Node=get_node_or_null("/root/Wardrobe")
	return store.gear_rank(id)*per_rank if store!=null and store.has_method("gear_rank") else 0

func add_xp(amount: int) -> int:
	var before: int = level
	xp += maxi(amount, 0)
	while xp >= needed() and level < MAX_LEVEL:
		xp -= needed()
		level += 1
	if level == MAX_LEVEL: xp = mini(xp, needed() - 1)
	changed.emit()
	return level - before

func reset_profile() -> void:
	xp = 0
	level = 1
	fed = 0
	wins = 0
	defeats = 0
	next_id = 1
	files.clear()
	consumed.clear()
	recycle_bytes_total = 0
	recycle_xp_total = 0
	recycle_items_total = 0
	recycle_remainder_bytes = 0
	recycle_receipts.clear()
	recycle_consumed.clear()
	_receipt_lookup.clear()
	_recycle_item_lookup.clear()
	recycle_error = ""
	recycle_last_import.clear()
	add_file("过期缓存.tmp", 35, "缓存碎片", "12.8 MB")
	add_file("旧截图.png", 45, "图像碎片", "3.2 MB")
	add_file("重复日志.log", 30, "日志碎片", "640 KB")
	changed.emit()

func add_file(title: String, value: int, kind: String = "战利品", size_text: String = "虚拟数据") -> String:
	var id := "fragment-%d" % next_id
	next_id += 1
	files.append({"id":id, "name":title, "xp":value, "kind":kind, "size":size_text})
	return id

func feed(ids: Array[String]) -> Dictionary:
	var total: int = 0
	var count: int = 0
	var previous_level: int = level
	for id in ids:
		if id in consumed:
			continue
		for i in range(files.size()):
			if str(files[i]["id"]) == id:
				total += int(files[i]["xp"])
				consumed.append(id)
				files.remove_at(i)
				count += 1
				break
	if count > 0:
		fed += count
		add_xp(total)
		save_profile()
	return {"count":count, "xp":total, "levels":level-previous_level}

func award_enemy(round_id: int, enemy_id: int, boss: bool = false) -> bool:
	var event_id := "battle-%d-%d" % [round_id, enemy_id]
	if event_id in consumed:
		return false
	consumed.append(event_id)
	add_xp(18 if boss else 8)
	if files.size() < 12:
		add_file("核心残片.bin" if boss else "数据残片_%02d.tmp" % enemy_id, 60 if boss else 20)
	changed.emit()
	save_profile()
	return true

func to_dict() -> Dictionary:
	return {"version":2,"xp":xp,"level":level,"fed":fed,"wins":wins,"defeats":defeats,"next_id":next_id,"files":files,"consumed":consumed,
		"recycle_bytes_total":recycle_bytes_total,"recycle_xp_total":recycle_xp_total,"recycle_items_total":recycle_items_total,
		"recycle_remainder_bytes":recycle_remainder_bytes,"recycle_receipts":recycle_receipts,"recycle_consumed":recycle_consumed}

func save_profile() -> bool:
	if not save_enabled:
		return true
	var data := to_dict()
	if not valid_data(data):
		save_error="角色存档数据无效，未写入。"
		return false
	var file := FileAccess.open(save_path + ".tmp", FileAccess.WRITE)
	if file == null:
		save_error = "存档写入失败，进度暂保留在当前会话"
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error!=OK:
		save_error="存档写入不完整，原存档保持不变。"
		return false
	if FileAccess.file_exists(save_path):
		if DirAccess.dir_exists_absolute(save_path+".bak"):
			save_error="存档备份路径不可用，原存档保持不变。"
			return false
		if DirAccess.copy_absolute(save_path, save_path + ".bak") != OK:
			save_error = "存档备份失败，保留旧存档与本次临时文件"
			return false
	var err := DirAccess.rename_absolute(save_path + ".tmp", save_path)
	save_error = "" if err == OK else "存档替换失败，旧存档与备份仍保留"
	return err == OK

func load_profile() -> bool:
	if not save_enabled:
		return false
	for path in [save_path, save_path + ".bak"]:
		if not FileAccess.file_exists(path):
			continue
		var parser := JSON.new()
		if parser.parse(FileAccess.get_file_as_string(path)) != OK:
			continue
		var data = parser.data
		if not valid_data(data):
			continue
		_apply_data(data)
		return true
	return false

func _apply_data(data: Dictionary) -> void:
	xp = int(data["xp"])
	level = int(data["level"])
	fed = int(data.get("fed",0))
	wins = int(data.get("wins",0))
	defeats = int(data.get("defeats",0))
	next_id = int(data["next_id"])
	files.clear()
	consumed.clear()
	for item in data["files"]: files.append(item.duplicate(true))
	for id in data["consumed"]: consumed.append(str(id))
	recycle_bytes_total = int(data.get("recycle_bytes_total",0))
	recycle_xp_total = int(data.get("recycle_xp_total",0))
	recycle_items_total = int(data.get("recycle_items_total",0))
	recycle_remainder_bytes = int(data.get("recycle_remainder_bytes",0))
	recycle_receipts.clear()
	recycle_consumed.clear()
	_receipt_lookup.clear()
	_recycle_item_lookup.clear()
	for receipt in data.get("recycle_receipts",[]):
		recycle_receipts.append(str(receipt))
		_receipt_lookup[str(receipt)] = true
	for item in data.get("recycle_consumed",[]):
		recycle_consumed.append(str(item))
		_recycle_item_lookup[str(item)] = true

func _valid_integer(value: Variant, minimum: int = 0, maximum: int = MAX_JSON_INTEGER) -> bool:
	if not value is int and not value is float: return false
	var number := float(value)
	return is_finite(number) and number >= minimum and number <= maximum and floor(number) == number

func _hex_identifier(value: Variant, length: int) -> bool:
	if not value is String or value.length() != length: return false
	for c in value:
		if not c in "0123456789abcdef": return false
	return true

func _valid_utc(value: Variant) -> bool:
	if not value is String or value.length()<20 or value.length()>40: return false
	var pattern := RegEx.new()
	pattern.compile("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\\.[0-9]{1,7})?(Z|\\+00:00)$")
	if pattern.search(value) == null: return false
	var year := int(value.substr(0,4))
	var month := int(value.substr(5,2))
	var day := int(value.substr(8,2))
	if year<1970 or month<1 or month>12 or int(value.substr(11,2))>23 or int(value.substr(14,2))>59 or int(value.substr(17,2))>59: return false
	var days: Array[int] = [31,29 if year%4==0 and (year%100!=0 or year%400==0) else 28,31,30,31,30,31,31,30,31,30,31]
	return day>=1 and day<=days[month-1]

func valid_recycle_receipt(data: Variant) -> bool:
	if not data is Dictionary or not data.has_all(["version","id","kind","completed_utc","items","completed_bytes"]): return false
	if not _valid_integer(data.version,1,1) or data.kind != "recycle_feed" or not _hex_identifier(data.id,32) or not _valid_utc(data.completed_utc): return false
	if not data.items is Array or data.items.is_empty() or data.items.size()>MAX_RECEIPT_ITEMS or not _valid_integer(data.completed_bytes,0,MAX_RECEIPT_BYTES): return false
	var sum: int = 0
	var seen: Dictionary = {}
	for item in data.items:
		if not item is Dictionary or not item.has_all(["id","bytes"]) or not _hex_identifier(item.id,64) or not _valid_integer(item.bytes,0,MAX_RECEIPT_BYTES): return false
		if seen.has(item.id): return false
		seen[item.id] = true
		sum += int(item.bytes)
		if sum>MAX_RECEIPT_BYTES: return false
	return sum==int(data.completed_bytes)

func import_recycle_receipt(path: String, emit_change: bool = true) -> Dictionary:
	var result := {"ok":false,"duplicate":false,"items":0,"bytes":0,"xp":0,"levels":0}
	# This early return also forbids file reads in isolated game/visual test modes.
	if not save_enabled or recycle_receipts_dir.is_empty(): return result
	var filename := path.get_file()
	if filename.get_extension() != "json" or not _hex_identifier(filename.get_basename(),32): return result
	var allowed := ProjectSettings.globalize_path(recycle_receipts_dir).simplify_path()
	var actual := ProjectSettings.globalize_path(path).simplify_path()
	if actual.get_base_dir() != allowed: return result
	if _receipt_lookup.has(filename.get_basename()):
		result.ok = true
		result.duplicate = true
		return result
	var file := FileAccess.open(actual,FileAccess.READ)
	if file==null: return result
	if file.get_length()>MAX_RECEIPT_JSON:
		file.close()
		recycle_error="回收站喂食记录过大，未导入。"
		return result
	var parser := JSON.new()
	var raw := file.get_as_text()
	file.close()
	if raw.begins_with(String.chr(0xfeff)): raw=raw.substr(1)
	if parser.parse(raw)!=OK or not valid_recycle_receipt(parser.data):
		recycle_error="回收站喂食记录无效，未导入。"
		return result
	var data: Dictionary = parser.data
	if data.id != filename.get_basename():
		recycle_error="回收站喂食记录标识不一致，未导入。"
		return result
	var unique_items: Array[String] = []
	var bytes: int = 0
	for item in data.items:
		if not _recycle_item_lookup.has(item.id):
			unique_items.append(item.id)
			bytes += int(item.bytes)
	if recycle_bytes_total>MAX_JSON_INTEGER-bytes or recycle_items_total>MAX_JSON_INTEGER-unique_items.size():
		recycle_error="回收站累计记录已达到支持范围，未导入。"
		return result
	var before := to_dict().duplicate(true)
	var before_level := level
	var earned: int = int((recycle_remainder_bytes+bytes)/RECYCLE_BYTES_PER_XP)
	recycle_bytes_total += bytes
	recycle_remainder_bytes = (recycle_remainder_bytes+bytes)%RECYCLE_BYTES_PER_XP
	recycle_xp_total += earned
	recycle_items_total += unique_items.size()
	recycle_receipts.append(data.id)
	_receipt_lookup[data.id] = true
	for id in unique_items:
		recycle_consumed.append(id)
		_recycle_item_lookup[id] = true
	# Do not emit changed until progression and deduplication commit together.
	xp += earned
	while xp>=needed() and level<MAX_LEVEL:
		xp -= needed()
		level += 1
	if level==MAX_LEVEL: xp=mini(xp,needed()-1)
	if not save_profile():
		_apply_data(before)
		recycle_error="回收站成长暂未写入存档，将在下次自动重试。"
		return result
	result={"ok":true,"duplicate":false,"items":unique_items.size(),"bytes":bytes,"xp":earned,"levels":level-before_level}
	recycle_last_import=result.duplicate()
	recycle_error=""
	if emit_change:
		changed.emit()
		recycle_imported.emit(result.items,result.bytes,result.xp,result.levels)
	# The source receipt deliberately remains unchanged: the durable ledger is its ack.
	return result

func poll_recycle_receipts() -> Dictionary:
	var summary := {"items":0,"bytes":0,"xp":0,"levels":0,"receipts":0}
	if not save_enabled or _recycle_polling or recycle_receipts_dir.is_empty() or not DirAccess.dir_exists_absolute(recycle_receipts_dir): return summary
	_recycle_polling=true
	var attempted := 0
	var filenames := DirAccess.get_files_at(recycle_receipts_dir)
	var start: int = _recycle_scan_cursor%maxi(1,filenames.size())
	for offset in filenames.size():
		var filename: String = filenames[(start+offset)%filenames.size()]
		if filename.get_extension() != "json" or not _hex_identifier(filename.get_basename(),32) or _receipt_lookup.has(filename.get_basename()): continue
		var result := import_recycle_receipt(recycle_receipts_dir.path_join(filename),false)
		attempted += 1
		if result.ok and not result.duplicate:
			for key in ["items","bytes","xp","levels"]: summary[key] += int(result[key])
			summary.receipts += 1
		if attempted>=32:
			_recycle_scan_cursor=(start+offset+1)%filenames.size()
			break
		if offset==filenames.size()-1: _recycle_scan_cursor=0
	_recycle_polling=false
	if summary.receipts>0:
		recycle_last_import=summary.duplicate()
		changed.emit()
		recycle_imported.emit(summary.items,summary.bytes,summary.xp,summary.levels)
	return summary

func valid_data(data: Variant) -> bool:
	if not data is Dictionary:
		return false
	for key in ["xp","level","next_id","files","consumed"]:
		if not data.has(key):
			return false
	if not data["xp"] is float and not data["xp"] is int:
		return false
	if not data["level"] is float and not data["level"] is int:
		return false
	if not data["next_id"] is float and not data["next_id"] is int:
		return false
	if int(data["level"]) < 1 or int(data["level"]) > 1000 or int(data["xp"]) < 0:
		return false
	if not data["files"] is Array or not data["consumed"] is Array:
		return false
	for item in data["files"]:
		if not item is Dictionary or not item.has_all(["id","name","xp","kind","size"]):
			return false
		if not item["xp"] is float and not item["xp"] is int:
			return false
		if int(item["xp"]) < 0 or int(item["xp"]) > 10000:
			return false
	for key in ["recycle_bytes_total","recycle_xp_total","recycle_items_total","recycle_remainder_bytes"]:
		if not _valid_integer(data.get(key,0)): return false
	if int(data.get("recycle_remainder_bytes",0)) != int(data.get("recycle_bytes_total",0))%RECYCLE_BYTES_PER_XP: return false
	if int(data.get("recycle_xp_total",0)) != int(int(data.get("recycle_bytes_total",0))/RECYCLE_BYTES_PER_XP): return false
	for key in ["recycle_receipts","recycle_consumed"]:
		if not data.get(key,[]) is Array: return false
		var seen: Dictionary = {}
		for id in data.get(key,[]):
			if not _hex_identifier(id,32 if key=="recycle_receipts" else 64) or seen.has(id): return false
			seen[id] = true
	if int(data.get("recycle_items_total",0)) != data.get("recycle_consumed",[]).size(): return false
	return true
