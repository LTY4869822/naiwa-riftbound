extends SceneTree

const PROFILE_SCRIPT = preload("res://scripts/profile.gd")
var failures: int = 0
var lines: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func verify(condition: bool, text: String) -> void:
	var line := ("PASS " if condition else "FAIL ")+text
	print(line)
	lines.append(line)
	if not condition:
		failures += 1

func run() -> void:
	var a := PROFILE_SCRIPT.new()
	a.save_enabled = false
	a.reset_profile()
	var ids: Array[String] = [str(a.files[0]["id"]),str(a.files[1]["id"])]
	var result: Dictionary = a.feed(ids)
	verify(result["xp"]==80 and a.level==2,"real profile feeding yields exact level and XP")
	a.save_path = "res://artifacts/test-profile.json"
	a.save_enabled = true
	verify(a.save_profile(),"profile can be written to isolated test file")
	var b := PROFILE_SCRIPT.new()
	b.save_path = a.save_path
	verify(b.load_profile(),"new profile instance loads saved file")
	verify(b.level==2 and b.xp==20 and b.fed==2 and b.files.size()==1,"restart restores progression, inventory and feeding ledger")
	verify(b.feed(ids)["count"]==0 and b.xp==20,"reward dedup survives restart")
	b.add_xp(30)
	verify(b.save_profile(),"existing save can be replaced and backed up on Windows")
	var corrupt := FileAccess.open(b.save_path,FileAccess.WRITE)
	corrupt.store_string("{broken-save")
	corrupt.close()
	var c := PROFILE_SCRIPT.new()
	c.save_path = b.save_path
	verify(c.load_profile() and c.xp==20,"corrupt primary save recovers last valid backup")
	verify(not c.valid_data({"xp":0,"level":-1,"next_id":1,"files":[],"consumed":[]}),"invalid progression is rejected")
	a.free()
	b.free()
	c.free()
	var file := FileAccess.open("res://artifacts/profile-test.txt",FileAccess.WRITE)
	file.store_string("\n".join(lines))
	file.close()
	print("PROFILE_TEST_FAILURES=",failures)
	quit(0 if failures==0 else 1)
