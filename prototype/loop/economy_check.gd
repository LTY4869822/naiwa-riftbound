extends SceneTree
const STORE=preload("res://wardrobe/store.gd")
var count:=0
var failed: Array=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	count+=1
	if not ok: failed.append(label); push_error(label)
func run() -> void:
	if "--slice-test" not in OS.get_cmdline_user_args(): quit(1); return
	var folder: String="user://loot-qa-"+str(Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(folder)
	var path:=folder+"/wallet.json"
	var run_id:=Crypto.new().generate_random_bytes(16).hex_encode()
	var a:=STORE.new()
	a.profile=root.get_node("Profile")
	a.save_path=path
	check(a.award_loot(run_id,1,40).ok and a.coins==40,"ground pickup durable credit")
	check(a.award_loot(run_id,1,40).amount==0 and a.coins==40,"replayed pickup cannot mint twice")
	check(not a.award_loot(run_id,0,30).ok and not a.award_loot(run_id,2,-4).ok,"invalid drops rejected")
	check(not a.buy_gear("charm").ok and a.coins==40,"insufficient cash retains equipment state")
	a.award_loot(run_id,2,200)
	check(a.buy_gear("charm").ok and a.gear_rank("charm")==1 and a.coins==80,"purchase equips first rank and spends exact cost")
	var b:=STORE.new()
	b.profile=a.profile
	b.save_path=path
	check(b.load_store() and b.gear_rank("charm")==1 and b.coins==80,"new wallet restores equipment and cash")
	check(b.award_loot(run_id,2,200).amount==0,"pickup dedup survives restart")
	var invalid:=a.to_dict()
	invalid.gear_ranks.charm=4
	check(not a.valid(invalid),"equipment rank over cap is rejected")
	a.award_loot(run_id,3,400)
	var before:=a.to_dict()
	a.save_path=folder
	check(not a.buy_gear("bracer").ok and a.to_dict()==before,"failed equipment write rolls back cash and ranks")
	check(not a.award_loot(run_id,4,50).ok and a.to_dict()==before,"failed pickup write rolls back ledger and cash")
	a.save_path=path
	var legacy:=a.to_dict()
	legacy.erase("gear_ranks")
	legacy.erase("loot_ledger")
	check(a.valid(legacy),"old wallet remains valid without new fields")
	a.apply(legacy)
	check(a.gear_ranks.is_empty() and a.loot_ledger.is_empty(),"old wallet loads empty equipment defaults")
	a.free()
	b.free()
	for f in [path,path+".bak",path+".tmp",folder+".tmp"]:
		if FileAccess.file_exists(f): DirAccess.remove_absolute(f)
	DirAccess.remove_absolute(folder)
	var f:=FileAccess.open("res://artifacts/loop-economy-check.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":count,"failures":failed,"isolated_fixture":true},"\t"))
	f.close()
	print("LOOT_ECONOMY_CHECKS ",count," failures=",failed.size())
	quit(0 if failed.is_empty() else 1)
