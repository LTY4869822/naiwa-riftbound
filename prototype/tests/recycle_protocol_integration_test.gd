extends SceneTree
const PROFILE = preload("res://scripts/profile.gd")
const UNIT: int = 8*1024*1024
var checks: Array[String] = []
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func verify(condition: bool, title: String) -> void:
	var line := ("PASS " if condition else "FAIL ")+title
	checks.append(line)
	print(line)
	if not condition: failures+=1

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var fixture := ""
	for index in range(args.size()-1):
		if args[index]=="--fixture-root": fixture=args[index+1]
	var allowed := ProjectSettings.globalize_path("res://artifacts/recycle-protocol-fixtures/").simplify_path()+"/"
	fixture=fixture.simplify_path()
	if not "--profile-test" in args or not "--recycle-test" in args or fixture.is_empty() or not fixture.begins_with(allowed):
		push_error("Protocol integration requires an explicit workspace fixture and isolated flags")
		quit(1)
		return
	verify(not root.get_node("Profile").save_enabled and root.get_node("Profile").recycle_receipts_dir.is_empty(),"autoload test mode does not resolve the real user's inbox")
	var manifest: Variant=JSON.parse_string(FileAccess.get_file_as_string(fixture.path_join("manifest.json")))
	if not manifest is Dictionary or manifest.get("kind","")!="isolated_recycle_protocol_fixture":
		push_error("Missing safe C# producer manifest")
		quit(1)
		return
	verify(manifest.real_windows_store_created==false and int(manifest.native_successful_fake_items)==5,"producer manifest records only fake-store operations")
	if "--reload-only" in args:
		var persisted := PROFILE.new()
		persisted.save_path=fixture.path_join("game-profile.json")
		persisted.recycle_receipts_dir=fixture.path_join("native/receipts")
		persisted.save_enabled=true
		var saved_bytes:=FileAccess.get_file_as_bytes(persisted.save_path)
		verify(persisted.load_profile() and persisted.level==2 and persisted.xp==1,"separate Godot process reloads level two with one residual XP")
		verify(persisted.recycle_xp_total==61 and persisted.recycle_bytes_total==61*UNIT and persisted.recycle_items_total==5 and persisted.recycle_receipts.size()==5 and persisted.recycle_consumed.size()==5,"separate process restores totals and both deduplication ledgers")
		var before: Dictionary=persisted.to_dict().duplicate(true)
		var polled: Dictionary=persisted.poll_recycle_receipts()
		verify(int(polled.receipts)==0 and int(polled.xp)==0 and persisted.to_dict()==before,"separate-process startup polling cannot award the native receipts again")
		var replay: Dictionary=persisted.import_recycle_receipt(persisted.recycle_receipts_dir.path_join(str(manifest.phases[-1].receipt_file)))
		verify(replay.ok and replay.duplicate and persisted.to_dict()==before,"separate-process explicit replay remains a no-op")
		verify(saved_bytes==FileAccess.get_file_as_bytes(persisted.save_path),"replayed receipts do not rewrite the committed save")
		verify(DirAccess.get_files_at(persisted.recycle_receipts_dir).size()==5,"separate process preserves native source receipts")
		var restart_report:=FileAccess.open(fixture.path_join("godot-restart-checks.txt"),FileAccess.WRITE)
		restart_report.store_string("\n".join(checks)+"\nFailures=%d\n" % failures)
		restart_report.close()
		persisted.free()
		print("RECYCLE_PROTOCOL_RESTART_CHECKS ",checks.size()," failures=",failures)
		quit(failures)
		return
	var profile := PROFILE.new()
	profile.save_path=fixture.path_join("game-profile.json")
	profile.recycle_receipts_dir=fixture.path_join("native/receipts")
	profile.save_enabled=true
	profile.reset_profile()
	var earned: Array[int]=[1,0,1,58,1]
	var levels: Array[int]=[1,1,1,2,2]
	var xp: Array[int]=[1,1,2,0,1]
	var remainder: Array[int]=[0,UNIT/2,0,0,0]
	for index in manifest.phases.size():
		var phase: Dictionary=manifest.phases[index]
		var path: String=profile.recycle_receipts_dir.path_join(str(phase.receipt_file))
		var result: Dictionary=profile.import_recycle_receipt(path)
		verify(result.ok and int(result.items)==1 and int(result.bytes)==int(phase.bytes),"Godot accepts exact production C# receipt: "+str(phase.name))
		verify(int(result.xp)==earned[index] and profile.level==levels[index] and profile.xp==xp[index] and profile.recycle_remainder_bytes==remainder[index],"cross-language XP, carry and level are exact: "+str(phase.name))
	verify(profile.recycle_xp_total==61 and profile.recycle_bytes_total==61*UNIT and profile.recycle_items_total==5,"partial native cancellation and failure do not enter game totals")
	profile.free()
	var restarted := PROFILE.new()
	restarted.save_path=fixture.path_join("game-profile.json")
	restarted.recycle_receipts_dir=fixture.path_join("native/receipts")
	restarted.save_enabled=true
	verify(restarted.load_profile() and restarted.level==2 and restarted.xp==1 and restarted.recycle_xp_total==61 and restarted.recycle_bytes_total==61*UNIT and restarted.recycle_items_total==5 and restarted.recycle_receipts.size()==5 and restarted.recycle_consumed.size()==5,"a fresh Godot instance restores the committed native-feed level")
	# JSON normalizes numeric Variant types in the untouched virtual inventory.
	# Compare against the loaded state, after independently checking every real-feed
	# total and both ledgers above, to detect replay mutations rather than int/float types.
	var state: Dictionary=restarted.to_dict().duplicate(true)
	var poll: Dictionary=restarted.poll_recycle_receipts()
	verify(int(poll.receipts)==0 and int(poll.xp)==0 and restarted.to_dict()==state,"restart polling leaves all acknowledged C# receipts unrewarded")
	var last: String=str(manifest.phases[-1].receipt_file)
	var duplicate: Dictionary=restarted.import_recycle_receipt(restarted.recycle_receipts_dir.path_join(last))
	verify(duplicate.ok and duplicate.duplicate and restarted.to_dict()==state,"explicit replay of a production receipt cannot grant duplicate XP")
	var files: PackedStringArray=DirAccess.get_files_at(restarted.recycle_receipts_dir)
	verify(files.size()==5,"game leaves every native receipt intact as durable source evidence")
	var report := FileAccess.open(fixture.path_join("godot-checks.txt"),FileAccess.WRITE)
	report.store_string("\n".join(checks)+"\nFailures=%d\n" % failures)
	report.close()
	restarted.free()
	print("RECYCLE_PROTOCOL_CHECKS ",checks.size()," failures=",failures)
	quit(failures)
