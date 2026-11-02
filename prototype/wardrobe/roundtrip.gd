extends SceneTree
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var args:=OS.get_cmdline_user_args()
	if "--slice-test" not in args: quit(1); return
	var store: Node=root.get_node("Wardrobe")
	var profile: Node=root.get_node("Profile")
	if profile.save_enabled: quit(1); return
	store.save_path="res://artifacts/shop-fixtures/process-roundtrip.json"
	store.save_enabled=true
	var fixture: Dictionary={"id":"test-process-outfit","title":"Isolated fixture","original":false,"published":true,"preview":"res://assets/menu-v2/pet/front-idle.png","combat_manifest":"res://assets/v6/side-frames.json","desktop_manifest":"res://assets/menu-v2/pet/original-motion.json","growth":false,"coins":true,"price":100}
	store.catalog.append(fixture)
	var ok:=true
	if "--shop-roundtrip-write" in args:
		DirAccess.make_dir_recursive_absolute("res://artifacts/shop-fixtures")
		store.reset()
		for i in 4:
			ok=bool(store.award_clear(["moss","cavern","storm","forge"][i],"%032x" % (i+500)).ok) and ok
		ok=bool(store.acquire(fixture.id,"coins").ok) and store.equip(fixture.id) and ok
		print("ROUNDTRIP_WRITE ",JSON.stringify(store.to_dict()))
	else:
		ok=store.load_store()
		ok=ok and store.coins==740 and store.earned==840 and store.spent==100 and store.clears.size()==4 and fixture.id in store.owned and store.equipped==fixture.id
		ok=ok and store.award_clear("moss","%032x" % 500).duplicate
		print("ROUNDTRIP_READ ",JSON.stringify(store.to_dict()))
	print("SHOP_PROCESS_ROUNDTRIP ","PASS" if ok else "FAIL")
	quit(0 if ok else 1)
