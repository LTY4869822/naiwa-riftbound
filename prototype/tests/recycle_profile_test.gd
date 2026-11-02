extends SceneTree
const PROFILE = preload("res://scripts/profile.gd")
const UNIT: int = 8*1024*1024
var failures := 0
var lines: Array[String] = []
var fixture: String
var inbox: String

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, title: String) -> void:
	var line := ("PASS " if condition else "FAIL ")+title
	lines.append(line)
	print(line)
	if not condition: failures+=1

func receipt(number: int, entries: Array) -> Dictionary:
	var count: int = 0
	for entry in entries: count+=int(entry.bytes)
	return {"version":1,"id":"%032x" % number,"kind":"recycle_feed","completed_utc":"2026-10-28T06:12:00.1234567Z","items":entries,"completed_bytes":count}

func write_text(path: String, content: String) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	assert(file!=null)
	file.store_string(content)
	file.close()

func put(data: Dictionary, base: String = "") -> String:
	var path := (inbox if base.is_empty() else base).path_join(str(data.id)+".json")
	write_text(path,JSON.stringify(data))
	return path

func actor() -> Node:
	var profile := PROFILE.new()
	profile.save_path=fixture.path_join("profile.json")
	profile.recycle_receipts_dir=inbox
	profile.save_enabled=true
	return profile

func run() -> void:
	fixture=ProjectSettings.globalize_path("res://artifacts/recycle-profile-tests/run-%d" % Time.get_ticks_usec())
	inbox=fixture.path_join("receipts")
	DirAccess.make_dir_recursive_absolute(inbox)
	var a := actor()
	a.reset_profile()
	var virtual_ids: Array[String]=[str(a.files[0].id),str(a.files[1].id)]
	a.save_enabled=false
	a.feed(virtual_ids)
	var legacy: Dictionary=a.to_dict().duplicate(true)
	for key in ["recycle_bytes_total","recycle_xp_total","recycle_items_total","recycle_remainder_bytes","recycle_receipts","recycle_consumed"]: legacy.erase(key)
	legacy.version=1
	write_text(a.save_path,JSON.stringify(legacy))
	a.free()
	var b := actor()
	check(b.load_profile() and b.level==2 and b.xp==20 and b.fed==2 and b.files.size()==1,"legacy profile keeps level, XP, virtual inventory and feeding")
	check(b.recycle_bytes_total==0 and b.recycle_receipts.is_empty(),"legacy profile migrates to empty real-feed ledger")
	var notifications: Dictionary={"changed":0,"recycle":0}
	b.changed.connect(func(): notifications.changed+=1)
	b.recycle_imported.connect(func(_items,_bytes,_xp,_levels): notifications.recycle+=1)
	var first := receipt(1,[{"id":"a".repeat(64),"bytes":UNIT/2}])
	var first_path := put(first)
	var result: Dictionary=b.import_recycle_receipt(first_path)
	check(result.ok and result.xp==0 and b.xp==20 and b.recycle_remainder_bytes==UNIT/2,"sub-unit bytes carry forward without per-file XP")
	check(b.recycle_items_total==1 and b.recycle_bytes_total==UNIT/2,"only successful unique items enter real-feed totals")
	var second_path := put(receipt(2,[{"id":"b".repeat(64),"bytes":UNIT/2}]))
	result=b.import_recycle_receipt(second_path)
	check(result.ok and result.xp==1 and b.xp==21 and b.recycle_remainder_bytes==0 and b.recycle_xp_total==1,"two half-units produce exactly one XP")
	var duplicate_state: Dictionary=b.to_dict().duplicate(true)
	result=b.import_recycle_receipt(second_path)
	check(result.ok and result.duplicate and b.to_dict()==duplicate_state,"same receipt never awards twice")
	result=b.import_recycle_receipt(put(receipt(3,first.items)))
	check(result.ok and result.items==0 and result.bytes==0 and result.xp==0 and b.recycle_items_total==2,"same item in a new receipt is deduplicated")
	result=b.import_recycle_receipt(put(receipt(4,[{"id":"c".repeat(64),"bytes":UNIT*70}])))
	check(result.ok and result.xp==70 and result.levels==1 and b.level==3 and b.xp==1,"real recycled bytes use the existing level curve")
	check(b.fed==2 and b.files.size()==1 and b.consumed.size()==2,"real feeding does not consume virtual inventory or its ledger")
	var c := actor()
	check(c.load_profile() and c.recycle_xp_total==71 and c.level==3 and c.xp==1,"restart restores real feeding and shared progression")
	check(c.poll_recycle_receipts().receipts==0 and c.xp==1,"restart skips already committed source receipts")
	result=c.import_recycle_receipt(put(receipt(5,[{"id":"a".repeat(64),"bytes":UNIT/2},{"id":"d".repeat(64),"bytes":UNIT}])))
	check(result.ok and result.items==1 and result.bytes==UNIT and result.xp==1,"mixed duplicate receipt rewards only its new item")
	var zero := receipt(6,[{"id":"e".repeat(64),"bytes":0}])
	result=c.import_recycle_receipt(put(zero))
	check(result.ok and result.items==1 and result.xp==0,"zero-byte items cannot farm experience")
	var failure_path := put(receipt(7,[{"id":"f".repeat(64),"bytes":UNIT*10}]))
	var before_failure: Dictionary=c.to_dict().duplicate(true)
	var valid_save_path: String=c.save_path
	c.save_path=fixture.path_join("missing-folder/profile.json")
	result=c.import_recycle_receipt(failure_path)
	check(not result.ok and c.to_dict()==before_failure and FileAccess.file_exists(failure_path),"failed save rolls back both XP and receipt acknowledgement")
	c.save_path=valid_save_path
	result=c.import_recycle_receipt(failure_path)
	check(result.ok and result.xp==10 and c.xp==12,"retry after save failure grants XP exactly once")
	var d := actor()
	check(d.load_profile() and d.xp==12 and d.import_recycle_receipt(failure_path).duplicate,"committed retry remains deduplicated after restart")
	var blocked_backup := fixture.path_join("blocked-backup.json")
	write_text(blocked_backup,JSON.stringify(c.to_dict()))
	DirAccess.make_dir_absolute(blocked_backup+".bak")
	var protected_bytes := FileAccess.get_file_as_bytes(blocked_backup)
	var receipt_backup_path := put(receipt(8,[{"id":"1".repeat(64),"bytes":UNIT*2}]))
	c.save_path=blocked_backup
	before_failure=c.to_dict().duplicate(true)
	result=c.import_recycle_receipt(receipt_backup_path)
	check(not result.ok and c.to_dict()==before_failure and FileAccess.get_file_as_bytes(blocked_backup)==protected_bytes,"backup failure preserves primary save and in-memory XP")
	c.save_path=valid_save_path
	result=c.import_recycle_receipt(receipt_backup_path)
	check(result.ok and result.xp==2 and c.xp==14,"backup failure leaves receipt retryable")
	var invalid: Dictionary=receipt(9,[{"id":"2".repeat(64),"bytes":1}])
	invalid.items[0].bytes=1.25
	check(not c.valid_recycle_receipt(invalid),"fractional byte counts are rejected")
	invalid=receipt(9,[{"id":"2".repeat(64),"bytes":1}])
	invalid.completed_bytes=2
	check(not c.valid_recycle_receipt(invalid),"receipt total must equal the item byte sum")
	invalid=receipt(9,[{"id":"2".repeat(64),"bytes":1},{"id":"2".repeat(64),"bytes":2}])
	check(not c.valid_recycle_receipt(invalid),"duplicate IDs inside one receipt invalidate the receipt")
	invalid=receipt(9,[{"id":"2".repeat(64),"bytes":PROFILE.MAX_RECEIPT_BYTES+1}])
	check(not c.valid_recycle_receipt(invalid),"over-limit byte amounts are rejected before awarding")
	invalid=receipt(9,[{"id":"2".repeat(64),"bytes":1}])
	invalid.completed_utc="2026-02-30T10:30:00Z"
	check(not c.valid_recycle_receipt(invalid),"invalid calendar date is rejected")
	invalid.completed_utc="2026-10-28T10:30:00+00:00"
	check(c.valid_recycle_receipt(invalid),"UTC offset and C# round-trip timestamps are supported")
	invalid.items[0].bytes=NAN
	check(not c.valid_recycle_receipt(invalid),"non-finite byte amounts are rejected")
	var stale_id := receipt(10,[{"id":"2".repeat(64),"bytes":UNIT}])
	var mismatch_path:=inbox.path_join("%032x.json" % 11)
	write_text(mismatch_path,JSON.stringify(stale_id))
	before_failure=c.to_dict().duplicate(true)
	check(not c.import_recycle_receipt(mismatch_path).ok and c.to_dict()==before_failure,"filename and receipt ID must match")
	var outside := put(receipt(12,[{"id":"3".repeat(64),"bytes":UNIT}]),fixture)
	check(not c.import_recycle_receipt(outside).ok,"receipt outside the configured inbox is not read")
	var malformed_path:=inbox.path_join("%032x.json" % 13)
	write_text(malformed_path,"{partial")
	check(not c.import_recycle_receipt(malformed_path).ok,"partial or invalid JSON cannot grant XP")
	var oversized_path:=inbox.path_join("%032x.json" % 14)
	write_text(oversized_path," ".repeat(PROFILE.MAX_RECEIPT_JSON+1))
	check(not c.import_recycle_receipt(oversized_path).ok,"oversized receipt text is not parsed")
	var bom_data := receipt(20,[{"id":"7".repeat(64),"bytes":0}])
	var bom_path := inbox.path_join(str(bom_data.id)+".json")
	write_text(bom_path,String.chr(0xfeff)+JSON.stringify(bom_data))
	check(c.import_recycle_receipt(bom_path).ok,"UTF-8 BOM receipts from .NET writers are supported")
	var test_off := actor()
	test_off.reset_profile()
	test_off.save_enabled=false
	check(not test_off.import_recycle_receipt(first_path).ok and test_off.poll_recycle_receipts().receipts==0 and test_off.recycle_bytes_total==0,"save-disabled tests never enumerate or import inboxes")
	var batch := actor()
	batch.reset_profile()
	batch.save_path=fixture.path_join("batch-profile.json")
	batch.recycle_receipts_dir=fixture.path_join("batch-inbox")
	DirAccess.make_dir_recursive_absolute(batch.recycle_receipts_dir)
	for index in range(40):
		write_text(batch.recycle_receipts_dir.path_join("%032x.json" % (100+index)),"{broken")
	var queued:=receipt(200,[{"id":"4".repeat(64),"bytes":UNIT}])
	put(queued,batch.recycle_receipts_dir)
	for index in range(3): batch.poll_recycle_receipts()
	check(batch.recycle_xp_total==1,"bounded scan rotates past malformed receipts without starving valid ones")
	var invalid_save: Dictionary=c.to_dict().duplicate(true)
	invalid_save.recycle_remainder_bytes=1
	check(not c.valid_data(invalid_save),"corrupt cumulative remainder is rejected on load")
	invalid_save=c.to_dict().duplicate(true)
	invalid_save.recycle_receipts.append(invalid_save.recycle_receipts[0])
	check(not c.valid_data(invalid_save),"duplicate persistent receipt ledger entries are rejected")
	var cap := actor()
	cap.reset_profile()
	cap.level=PROFILE.MAX_LEVEL
	cap.xp=cap.needed()-2
	cap.save_enabled=false
	cap.add_xp(10000)
	check(cap.level==PROFILE.MAX_LEVEL and cap.xp<cap.needed() and cap.valid_data(cap.to_dict()),"maximum level cannot produce an unloadable profile")
	check(notifications.changed==4 and notifications.recycle==4,"only committed receipt imports emit game updates")
	# Exercise the same timer used by production, but only after explicitly replacing
	# both storage locations with new fixture directories. _ready ran in test mode.
	var live := PROFILE.new()
	live.save_path=fixture.path_join("timer-profile.json")
	root.add_child(live)
	await process_frame
	live.recycle_receipts_dir=fixture.path_join("timer-inbox")
	live.save_enabled=true
	DirAccess.make_dir_recursive_absolute(live.recycle_receipts_dir)
	put(receipt(300,[{"id":"8".repeat(64),"bytes":UNIT}]),live.recycle_receipts_dir)
	live._start_recycle_polling()
	await create_timer(0.1).timeout
	check(live.recycle_xp_total==1 and live.xp==1 and FileAccess.file_exists(live.save_path),"startup receipt import commits into the explicit fixture save")
	put(receipt(301,[{"id":"9".repeat(64),"bytes":UNIT}]),live.recycle_receipts_dir)
	await create_timer(1.1).timeout
	check(live.recycle_xp_total==2 and live.xp==2 and live.recycle_receipts.size()==2,"one-second timer imports receipts arriving while the game is running")
	live.free()
	for profile in [b,c,d,test_off,batch,cap]: profile.free()
	var output:=FileAccess.open("res://artifacts/recycle-profile-checks.txt",FileAccess.WRITE)
	output.store_string("\n".join(lines)+"\nFailures=%d\n" % failures)
	output.close()
	print("RECYCLE_PROFILE_CHECKS ",lines.size()," failures=",failures)
	quit(failures)
