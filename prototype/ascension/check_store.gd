extends SceneTree
const STORE=preload("res://ascension/store.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool, text: String) -> void:
	checks+=1
	if not ok: failures.append(text); push_error(text)
func write(path: String, data: Dictionary) -> void:
	var f:=FileAccess.open(path,FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
func run() -> void:
	if "--slice-test" not in OS.get_cmdline_user_args(): quit(1); return
	var folder: String="user://ascension-qa-"+str(Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(folder)
	var file:=folder+"/energy.json"
	var a:=STORE.new()
	a.storage_path=file
	a.save_enabled=true
	check(a.record_kill("one",1,false) and a.energy==5,"ordinary kill saved")
	check(a.record_kill("one",2,true) and a.energy==15,"boss awards 10")
	check(not a.record_kill("one",2,true) and a.total_kills==2,"duplicate rejected")
	var b:=STORE.new()
	b.storage_path=file
	b.load_record()
	check(b.energy==15 and b.total_kills==2,"kill energy restored from disk")
	check(not b.record_kill("one",1,false),"ledger restored after restart")
	for i in 17: a.record_kill("two",i+1,false)
	check(a.energy==100,"meter caps at 100")
	check(a.consume() and a.energy==0,"atomic awakening consume")
	check(not a.consume(),"cannot consume twice")
	b.load_record()
	check(b.energy==0,"consumed energy survives restart")
	write(file,{"version":1})
	b.load_record()
	check(b.energy==100,"invalid main file recovers previous valid backup")
	write(file,{"version":2,"unfamiliar_future_schema":true})
	var future:=FileAccess.get_file_as_string(file)
	b.load_record()
	check(b.future_version and not b.consume() and not b.save_record(),"future schema protected")
	check(FileAccess.get_file_as_string(file)==future,"future save not overwritten")
	a.storage_path=folder
	a.energy=100
	check(not a.consume() and a.energy==100,"failed write rolls back spend")
	a.storage_path=file
	a.save_enabled=false
	var before:=FileAccess.get_file_as_string(file)
	a.record_kill("isolated",9,false)
	check(FileAccess.get_file_as_string(file)==before,"disabled saving leaves disk unchanged")
	for item in [file,file+".bak",file+".tmp",folder+".tmp"]:
		if FileAccess.file_exists(item): DirAccess.remove_absolute(item)
	DirAccess.remove_absolute(folder)
	a.free()
	b.free()
	var f:=FileAccess.open("res://artifacts/ascension-store-checks.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"failures":failures,"isolated_fixture":true},"\t"))
	f.close()
	print("ASCENSION_STORE_CHECKS ",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
