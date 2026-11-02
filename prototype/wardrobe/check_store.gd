extends SceneTree
const STORE=preload("res://wardrobe/store.gd")
var lines: Array[String]=[]
var failures:=0

func _initialize() -> void:
	call_deferred("run")

func verify(ok: bool, text: String) -> void:
	lines.append(("PASS " if ok else "FAIL ")+text)
	print(lines[-1])
	if not ok: failures+=1

func fixture(id: String, level: int, bytes: int, price: int) -> Dictionary:
	return {"id":id,"title":"Isolated test fixture","published":true,"original":false,"preview":"res://assets/menu-v2/pet/front-idle.png","combat_manifest":"res://assets/v6/side-frames.json","desktop_manifest":"res://assets/menu-v2/pet/original-motion.json","level":level,"bytes":bytes,"price":price,"growth":true,"coins":true}

func run() -> void:
	if "--slice-test" not in OS.get_cmdline_user_args(): quit(1); return
	var p: Node=root.get_node("Profile")
	verify(not p.save_enabled,"unit checks cannot touch the real profile or receipts")
	var a:=STORE.new()
	a.profile=p
	a.save_enabled=false
	verify(a.coins==0 and a.owned==[a.CATALOG.ORIGINAL] and a.equipped==a.CATALOG.ORIGINAL,"new store starts with zero coins and the original outfit")
	for id in ["reserved-01","reserved-02","reserved-03"]:
		verify(a.state(id)=="coming_soon" and not a.acquire(id,"coins").ok and not a.acquire(id,"growth").ok,"unpublished "+id+" cannot charge coins or unlock")
	var total:=0
	var index:=0
	for id in a.CATALOG.REWARDS:
		var run_id: String=("%032x" % index)
		var reward: Dictionary=a.award_clear(id,run_id)
		total+=a.CATALOG.REWARDS[id].first
		verify(reward.ok and reward.first and reward.amount==a.CATALOG.REWARDS[id].first and a.coins==total,id+" grants the first-clear amount once")
		verify(a.award_clear(id,run_id).amount==0 and a.coins==total,id+" rejects a duplicate completion event")
		index+=1
	verify(total==4050 and a.clears.size()==12,"twelve first clears yield 4050 coins and twelve saved badges")
	verify(a.CATALOG.REWARDS.moss.first+a.CATALOG.REWARDS.cavern.first+a.CATALOG.REWARDS.storm.first+a.CATALOG.REWARDS.forge.first==840,"original four first-clear amounts remain compatible")
	verify(a.award_clear("moss","%032x" % 100).amount==30 and a.coins==total+30,"a fresh replay grants 30 instead of repeating the first-clear bonus")
	verify(not a.award_clear("unknown","%032x" % 101).ok and not a.award_clear("moss","bad").ok,"invalid level and malformed run IDs cannot mint currency")
	p.reset_profile()
	var growth:=fixture("test-growth",3,1073741824,200)
	var purchase:=fixture("test-purchase",999,1073741824,250)
	a.catalog.append(growth)
	a.catalog.append(purchase)
	p.level=3
	p.recycle_bytes_total=0
	verify(not a.acquire(growth.id,"growth").ok,"level alone cannot unlock a growth outfit")
	p.level=1
	p.recycle_bytes_total=1073741824
	verify(not a.acquire(growth.id,"growth").ok,"recycle bytes alone cannot unlock a growth outfit")
	p.reset_profile()
	var feed_ids: Array[String]=["fragment-1","fragment-2"]
	p.feed(feed_ids)
	verify(p.recycle_bytes_total==0 and not a.acquire(growth.id,"growth").ok,"virtual inventory feeding cannot fabricate real recycled bytes")
	p.level=3
	p.recycle_bytes_total=1073741824
	verify(a.state(growth.id)=="free" and not a.acquire(growth.id,"coins").ok,"a free eligible outfit cannot accidentally charge the wallet")
	var balance: int=a.coins
	verify(a.acquire(growth.id,"growth").ok and a.coins==balance and p.recycle_bytes_total==1073741824,"meeting both thresholds unlocks permanently without consuming bytes or coins")
	p.reset_profile()
	verify(growth.id in a.owned,"earned outfits remain owned when current growth counters change")
	verify(a.acquire(purchase.id,"coins").ok and a.coins==balance-250 and a.spent==250,"stage currency buys an outfit without satisfying growth thresholds")
	balance=a.coins
	verify(a.acquire(purchase.id,"coins").duplicate and a.coins==balance,"repeat purchase cannot deduct currency twice")
	var expensive:=fixture("test-expensive",999,1073741824,1000000)
	a.catalog.append(expensive)
	verify(not a.acquire(expensive.id,"coins").ok and expensive.id not in a.owned and a.coins==balance,"insufficient balance leaves both ownership and wallet unchanged")
	verify(not a.equip(expensive.id) and a.equip(purchase.id) and a.equipped==purchase.id,"only owned and ready outfits can be selected")
	var automatic:=fixture("test-automatic",4,2147483648,300)
	a.catalog.append(automatic)
	p.level=4
	p.recycle_bytes_total=2147483648
	balance=a.coins
	verify(automatic.id in a.sync_growth_unlocks() and automatic.id in a.owned and a.coins==balance,"growth milestones automatically unlock ready outfits without an extra purchase")
	verify(a.sync_growth_unlocks().is_empty(),"automatic growth unlock is idempotent")
	var valid:=a.to_dict()
	for key in ["coins","earned","spent"]:
		var corrupt: Dictionary=valid.duplicate(true)
		corrupt[key]=-1
		verify(not a.valid(corrupt),"negative "+key+" is rejected")
	var corrupt: Dictionary=valid.duplicate(true)
	corrupt.coins+=1
	verify(not a.valid(corrupt),"wallet arithmetic must match earned minus spent")
	corrupt=valid.duplicate(true)
	corrupt.rewarded_runs.append(corrupt.rewarded_runs[0])
	verify(not a.valid(corrupt),"duplicate completion ledger entries are rejected")
	corrupt=valid.duplicate(true)
	corrupt.owned.append(corrupt.owned[0])
	verify(not a.valid(corrupt),"duplicate outfit ownership is rejected")
	corrupt=valid.duplicate(true)
	corrupt.equipped="not-owned"
	verify(not a.valid(corrupt),"an equipped outfit must be owned")
	DirAccess.make_dir_recursive_absolute("res://artifacts/shop-fixtures")
	a.save_path="res://artifacts/shop-fixtures/wardrobe.json"
	a.save_enabled=true
	verify(a.save_store(),"wallet and wardrobe save to an isolated versioned file")
	var b:=STORE.new()
	b.profile=p
	b.save_enabled=true
	b.save_path=a.save_path
	b.catalog=a.catalog.duplicate(true)
	verify(b.load_store() and b.to_dict()==a.to_dict(),"a fresh store instance restores coins, ownership, equipment and clear history")
	verify(b.award_clear("moss","%032x" % 100).duplicate,"duplicate completion protection survives restart")
	var snapshot:=b.to_dict()
	b.save_path="res://artifacts/shop-fixtures/missing-folder/wardrobe.json"
	verify(not b.award_clear("forge","%032x" % 200).ok and b.to_dict()==snapshot,"failed reward saving rolls back both balance and completion history")
	var another:=fixture("test-rollback",999,1073741824,20)
	b.catalog.append(another)
	verify(not b.acquire(another.id,"coins").ok and b.to_dict()==snapshot,"failed purchase saving cannot lose coins or create partial ownership")
	b.save_path=a.save_path
	verify(b.save_store(),"a previous save can be backed up and replaced on Windows")
	var damaged:=FileAccess.open(b.save_path,FileAccess.WRITE)
	damaged.store_string("{broken-save")
	damaged.close()
	var c:=STORE.new()
	c.profile=p
	c.save_enabled=true
	c.save_path=b.save_path
	verify(c.load_store() and c.to_dict()==snapshot,"a corrupted primary wallet recovers the last valid backup")
	var future:=FileAccess.open(b.save_path,FileAccess.WRITE)
	future.store_string('{"version":99}')
	future.close()
	var d:=STORE.new()
	d.profile=p
	d.save_enabled=true
	d.save_path=b.save_path
	verify(not d.load_store() and d.read_only and not d.save_store() and FileAccess.get_file_as_string(d.save_path)=='{"version":99}',"a newer schema is protected from downgrade and overwrite")
	for store in [a,b,c,d]: store.free()
	var file:=FileAccess.open("res://artifacts/shop-store-checks.txt",FileAccess.WRITE)
	file.store_string("\n".join(lines)+"\nFailures=%d\n" % failures)
	print("SHOP_STORE_CHECKS ",lines.size()," failures=",failures)
	quit(failures)
