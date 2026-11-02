extends SceneTree
## Consume only an already-produced live-test receipt. This script never recycles,
## moves, restores or deletes a file and never starts the native desktop process.
const PROFILE = preload("res://scripts/profile.gd")
const UNIT: int = 8*1024*1024
const SEEDED_BATTLE_XP: int = 59
var checks: Array[String] = []
var failures: int = 0
var fixture: String = ""
var reload_only: bool = false

func _initialize() -> void:
	call_deferred("run")

func verify(condition: bool, title: String) -> void:
	var line := ("PASS " if condition else "FAIL ")+title
	checks.append(line)
	print(line)
	if not condition: failures+=1

func hex_id(value: String, size: int) -> bool:
	if value.length()!=size: return false
	for character in value:
		if not character in "0123456789abcdef": return false
	return true

func finish() -> void:
	if not fixture.is_empty():
		var name := "game-restart-checks.txt" if reload_only else "game-import-checks.txt"
		var report := FileAccess.open(fixture.path_join(name),FileAccess.WRITE)
		if report!=null:
			report.store_string("INFO: The test seeds 59 existing battle XP; the real 8 MiB receipt supplies the final 1 XP for Lv.2.\n"+"\n".join(checks)+"\nFailures=%d\n" % failures)
			report.close()
	print("DROP_LIVE_PROFILE_RESTART_CHECKS " if reload_only else "DROP_LIVE_PROFILE_CHECKS ",checks.size()," failures=",failures)
	quit(failures)

func actor(save: String, inbox: String) -> Node:
	var profile := PROFILE.new()
	profile.save_path=save
	profile.recycle_receipts_dir=inbox
	profile.save_enabled=true
	return profile

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var requested := ""
	for index in range(args.size()-1):
		if args[index]=="--fixture-root": requested=args[index+1].simplify_path().trim_suffix("/")
	var allowed := ProjectSettings.globalize_path("res://artifacts/drop-live").simplify_path().trim_suffix("/")
	# Validate flags and exact direct-child GUID before any fixture file is read.
	if not "--profile-test" in args or not "--recycle-test" in args or requested.get_base_dir()!=allowed or not hex_id(requested.get_file(),32) or not DirAccess.dir_exists_absolute(requested):
		push_error("Drop integration requires --profile-test --recycle-test and artifacts/drop-live/<32-lowercase-GUID>")
		quit(1)
		return
	fixture=requested
	reload_only="--reload-only" in args
	var global_profile: Node=root.get_node_or_null("Profile")
	verify(global_profile!=null and not bool(global_profile.get("save_enabled")) and str(global_profile.get("recycle_receipts_dir")).is_empty() and global_profile.get_node_or_null("RecycleReceiptTimer")==null,"autoload never reads the real game save or native inbox")
	if failures>0:
		finish()
		return
	var evidence: Variant=JSON.parse_string(FileAccess.get_file_as_string(fixture.path_join("result.json")))
	verify(evidence is Dictionary and evidence.get("status","")=="PASS" and evidence.get("real_user_files_touched",true)==false and evidence.get("preview_exact",false)==true and int(evidence.get("expected_bytes",0))==UNIT and int(evidence.get("completed_items",0))==1 and int(evidence.get("completed_bytes",0))==UNIT and evidence.get("receipt_saved",false)==true and evidence.get("source_absent",false)==true,"native live report proves one successful 8 MiB fixture recycle without touching user files")
	if failures>0:
		finish()
		return
	var inbox := fixture.path_join("native/receipts")
	verify(str(evidence.get("receipt_root","")).simplify_path()==inbox,"receipt source is confined to this live-test fixture")
	var files := DirAccess.get_files_at(inbox)
	verify(files.size()==1 and files[0].get_extension()=="json" and hex_id(files[0].get_basename(),32),"live service produced exactly one named immutable receipt")
	if failures>0:
		finish()
		return
	var receipt_file: String=files[0]
	var source := inbox.path_join(receipt_file)
	var source_bytes := FileAccess.get_file_as_bytes(source)
	verify(source_bytes.size()>0 and source_bytes.size()<=256*1024,"actual source receipt stays within the importer byte limit")
	if failures>0:
		finish()
		return
	var source_text := FileAccess.get_file_as_string(source)
	var parsed: Variant=JSON.parse_string(source_text)
	var save := fixture.path_join("game-profile.json")
	var proof := fixture.path_join("game-import-proof.json")
	var profile := actor(save,inbox)
	verify(profile.valid_recycle_receipt(parsed) and parsed.id==receipt_file.get_basename() and int(parsed.completed_bytes)==UNIT,"game validates the actual C# file or folder receipt protocol")
	if failures>0:
		profile.free()
		finish()
		return
	if reload_only:
		var earlier: Variant=JSON.parse_string(FileAccess.get_file_as_string(proof))
		verify(earlier is Dictionary and earlier.get("kind","")=="drop_live_profile_import" and int(earlier.get("seeded_battle_xp",-1))==SEEDED_BATTLE_XP and earlier.get("receipt_file","")==receipt_file and earlier.get("source_receipt_text","")==source_text,"separate process matches the initial live import proof and unchanged receipt")
		var saved_bytes := FileAccess.get_file_as_bytes(save)
		verify(profile.load_profile() and profile.level==2 and profile.xp==0,"separate Godot process reloads the real-receipt level two result")
		verify(profile.recycle_bytes_total==UNIT and profile.recycle_xp_total==1 and profile.recycle_items_total==1 and profile.recycle_remainder_bytes==0 and profile.recycle_receipts.size()==1 and profile.recycle_consumed.size()==1,"separate process restores exact byte totals and both replay ledgers")
		verify(profile.damage()==31 and profile.max_health()==112,"separate process restores the upgraded combat stats")
		var before: Dictionary=profile.to_dict().duplicate(true)
		var polled: Dictionary=profile.poll_recycle_receipts()
		verify(int(polled.receipts)==0 and int(polled.xp)==0 and profile.to_dict()==before,"separate-process receipt polling cannot grant duplicate growth")
		var duplicate: Dictionary=profile.import_recycle_receipt(source)
		verify(duplicate.ok and duplicate.duplicate and profile.to_dict()==before,"separate-process explicit replay is a no-op")
		verify(saved_bytes==FileAccess.get_file_as_bytes(save),"restart and replay preserve the committed game save byte for byte")
		verify(FileAccess.get_file_as_bytes(source)==source_bytes and DirAccess.get_files_at(inbox)==files,"restart preserves native receipt evidence in place")
		profile.free()
		finish()
		return
	verify(not FileAccess.file_exists(save) and not FileAccess.file_exists(proof),"first import only initializes a new fixture profile")
	if failures>0:
		profile.free()
		finish()
		return
	profile.reset_profile()
	profile.add_xp(SEEDED_BATTLE_XP)
	verify(profile.level==1 and profile.xp==SEEDED_BATTLE_XP and profile.recycle_bytes_total==0,"fixture explicitly seeds 59 battle XP and no garbage growth")
	verify(profile.save_profile(),"seeded fixture profile is saved only under the allowed live-test directory")
	var imported: Dictionary=profile.import_recycle_receipt(source)
	verify(imported.ok and not imported.duplicate and int(imported.items)==1 and int(imported.bytes)==UNIT and int(imported.xp)==1 and int(imported.levels)==1,"actual C# receipt supplies exactly one XP and one level-up")
	verify(profile.level==2 and profile.xp==0 and profile.recycle_bytes_total==UNIT and profile.recycle_xp_total==1 and profile.recycle_items_total==1 and profile.recycle_remainder_bytes==0,"one live 8 MiB receipt commits exact progression and cumulative bytes")
	verify(profile.damage()==31 and profile.max_health()==112,"shared level upgrades actual combat damage to 31 and maximum health to 112")
	verify(profile.recycle_receipts==[receipt_file.get_basename()] and profile.recycle_consumed.size()==1,"receipt and successful-item deduplication commit with the new level")
	profile.free()
	var restarted := actor(save,inbox)
	verify(restarted.load_profile() and restarted.level==2 and restarted.xp==0 and restarted.recycle_bytes_total==UNIT,"a fresh profile instance reloads the committed live-feed result")
	var before: Dictionary=restarted.to_dict().duplicate(true)
	var saved_bytes := FileAccess.get_file_as_bytes(save)
	var polled: Dictionary=restarted.poll_recycle_receipts()
	var replay: Dictionary=restarted.import_recycle_receipt(source)
	verify(int(polled.receipts)==0 and int(polled.xp)==0 and replay.ok and replay.duplicate and restarted.to_dict()==before,"same-process reload, polling and replay cannot duplicate the growth")
	verify(saved_bytes==FileAccess.get_file_as_bytes(save),"duplicate imports leave the committed save unchanged")
	verify(source_bytes==FileAccess.get_file_as_bytes(source) and DirAccess.get_files_at(inbox)==files,"game never modifies or removes the native source receipt")
	if failures==0:
		var report := FileAccess.open(proof,FileAccess.WRITE)
		if report!=null:
			report.store_string(JSON.stringify({"kind":"drop_live_profile_import","seeded_battle_xp":SEEDED_BATTLE_XP,"real_receipt_bytes":UNIT,"receipt_file":receipt_file,"source_receipt_text":source_text,"native_fixture_is_directory":bool(evidence.get("is_directory",false)),"level":2,"xp":0,"real_recycle_operation_performed_by_this_script":false},"\t"))
			report.close()
		else:
			verify(false,"initial import proof can be saved inside its fixture")
	restarted.free()
	finish()
