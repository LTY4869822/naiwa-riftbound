extends SceneTree
## UI wiring only. Requires --bridge-check and a new explicit workspace fixture.
## Never instantiate the real recycle adapter or leave a native executable target.

const ISOLATED_TOAST := "隔离试玩：桌宠吞噬入口可用，未打开真实文件处理。"
var checks: Array[String] = []
var failures: int = 0
var fixture: String = ""

func _initialize() -> void:
	call_deferred("run")

func verify(condition: bool, title: String) -> void:
	var line := ("PASS " if condition else "FAIL ")+title
	checks.append(line)
	print(line)
	if not condition: failures+=1

func finish() -> void:
	if not fixture.is_empty():
		var output := FileAccess.open(fixture.path_join("ui-checks.txt"),FileAccess.WRITE)
		if output!=null:
			output.store_string("\n".join(checks)+"\nFailures=%d\n" % failures)
			output.close()
	print("RECYCLE_UI_CHECKS ",checks.size()," failures=",failures)
	quit(failures)

func activate(host: Node, button_name: String, bridge: String) -> void:
	var control := host.find_child(button_name,true,false) as Button
	verify(control!=null and not control.disabled,button_name+" exists and is enabled")
	if control==null: return
	verify(str(control.get("title")) in ["拖文件喂它","返回桌宠，拖文件喂它"],button_name+" exposes direct desktop feeding")
	host.set("toast_text","")
	control.pressed.emit()
	verify(host.get("toast_text")==ISOLATED_TOAST and float(host.get("toast_time"))>0,button_name+" invokes the isolated toast branch")
	verify(not FileAccess.file_exists(bridge.path_join("desktop-request.txt")),button_name+" creates no desktop IPC request")

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var requested_fixture := ""
	var bridge := ""
	for index in range(args.size()-1):
		if args[index]=="--fixture-root": requested_fixture=args[index+1].simplify_path()
		if args[index]=="--bridge-dir": bridge=args[index+1].simplify_path()
	var allowed := ProjectSettings.globalize_path("res://artifacts/recycle-ui-tests/").simplify_path()+"/"
	# Fail closed before scene instantiation if any isolation precondition is absent.
	if not "--bridge-check" in args or "--slice-test" in args or "--slice-visual" in args or "--balance-check" in args or "--menu-review" in args or "--menu-film" in args or "--hud-review" in args or "--hud-film" in args or requested_fixture.is_empty() or not requested_fixture.begins_with(allowed) or bridge!=requested_fixture.path_join("bridge"):
		push_error("UI checks require --bridge-check, an explicit workspace fixture, and its isolated bridge directory")
		quit(1)
		return
	if FileAccess.get_file_as_string(requested_fixture.path_join("fixture.marker")).strip_edges()!="recycle-ui-test-only" or not DirAccess.dir_exists_absolute(bridge):
		push_error("Missing isolated fixture marker or bridge directory")
		quit(1)
		return
	fixture=requested_fixture
	var profile := root.get_node_or_null("Profile")
	var isolated: bool=profile!=null and not bool(profile.get("save_enabled")) and str(profile.get("recycle_receipts_dir")).is_empty() and profile.get_node_or_null("RecycleReceiptTimer")==null
	verify(isolated,"autoload disables profile IO and never resolves or polls the real receipts inbox")
	verify(not FileAccess.file_exists(bridge.path_join("desktop-request.txt")),"isolated bridge has no pre-existing desktop request")
	if not isolated or failures>0:
		finish()
		return
	profile.set("save_path",fixture.path_join("must-not-create-profile.json"))
	var packed := load("res://v5/slice.tscn") as PackedScene
	if packed==null:
		verify(false,"formal v5 scene loads")
		finish()
		return
	var host: Node=packed.instantiate()
	root.add_child(host)
	await process_frame
	var safe_host: bool=bool(host.get("test_mode")) and not bool(profile.get("save_enabled")) and str(profile.get("recycle_receipts_dir")).is_empty()
	verify(safe_host,"formal scene and autoload remain in isolated mode")
	if not safe_host:
		host.free()
		finish()
		return
	# Any accidental native-launch fallback sees only a nonexistent workspace path.
	var blocked_native := fixture.path_join("NO-NATIVE-PROCESS-MAY-BE-LAUNCHED.exe")
	verify(not FileAccess.file_exists(blocked_native),"native executable target is an absent workspace sentinel")
	if FileAccess.file_exists(blocked_native):
		host.free()
		finish()
		return
	host.set("native_path",blocked_native)
	host.set("reduce_motion",true)
	host.set("audio_enabled",false)
	verify(str(host.get("bridge_dir")).simplify_path()==bridge and FileAccess.get_file_as_string(bridge.path_join("state"))=="active","scene uses only the explicit workspace bridge")
	verify(host.get("mode")=="camp" and host.get("player")==null and int(host.get("wave"))==0,"bridge-check does not run battle checks automatically")
	var before: Dictionary=profile.call("to_dict").duplicate(true)
	activate(host,"OpenRecycleHome",bridge)
	# Use the real home navigation button to reach the supply page.
	var feed_navigation := host.find_child("OpenFeed",true,false) as Button
	verify(feed_navigation!=null,"home exposes supply-page navigation")
	if feed_navigation!=null:
		feed_navigation.pressed.emit()
		await process_frame
		verify(host.get("menu_section")=="feed","home navigation builds the supply page")
		activate(host,"OpenRecycleFeed",bridge)
		# Exercise the no-bridge path without ever allowing a real executable target.
		host.set("bridge_dir","")
		host.set("toast_text","")
		var feed_action := host.find_child("OpenRecycleFeed",true,false) as Button
		if feed_action!=null: feed_action.pressed.emit()
		verify(host.get("toast_text")==ISOLATED_TOAST,"no-bridge click also stops at the isolated toast before native launch")
		host.set("bridge_dir",bridge)
	await process_frame
	verify(profile.call("to_dict")==before,"menu actions do not alter game progress")
	verify(not FileAccess.file_exists(str(profile.get("save_path"))) and not FileAccess.file_exists(str(profile.get("save_path"))+".tmp"),"menu actions do not create a profile or staging save")
	verify(not FileAccess.file_exists(bridge.path_join("desktop-request.txt")),"all tested clicks leave the isolated bridge without desktop requests")
	verify(DirAccess.get_files_at(bridge)==PackedStringArray(["state"]),"only the normal isolated bridge state file exists")
	verify(not bool(profile.get("save_enabled")) and str(profile.get("recycle_receipts_dir")).is_empty() and profile.get_node_or_null("RecycleReceiptTimer")==null,"profile and recycle polling stay isolated through teardown")
	host.free()
	finish()
