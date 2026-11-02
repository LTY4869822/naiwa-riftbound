extends SceneTree
var checked:=0
var failed: Array[String]=[]
func _initialize() -> void:
	call_deferred("run")
func scan(folder: String) -> void:
	var dir:=DirAccess.open(folder)
	if dir==null: failed.append(folder); return
	for sub in dir.get_directories(): scan(folder.path_join(sub))
	for name in dir.get_files():
		if name.get_extension() not in ["gd","gdshader","tscn","png","wav"]: continue
		var path: String=folder.path_join(name)
		checked+=1
		if ResourceLoader.load(path)==null: failed.append(path)
func run() -> void:
	for dir in ["v5","v6","combat","campaign","foe_vfx","wardrobe","remediation","ascension","loop","loot","rift","biomes","echo","punch","assets/pixelfx","assets/echo-v6","assets/biomes-v5","assets/rift-v4","assets/loot-v3","assets/loop-v2","assets/ascension","assets/ultimates-v2"]: scan("res://"+dir)
	print("REMEDIATION_RESOURCES ",checked," failures=",failed.size())
	var f:=FileAccess.open("res://artifacts/remediation-resources.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"checked":checked,"failed":failed},"\t"))
	quit(0 if failed.is_empty() else 1)
