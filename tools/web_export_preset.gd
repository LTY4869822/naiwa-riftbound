extends SceneTree
## Generate platform defaults through the same native factory used by the editor.
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var platform:=EditorExportPlatformWeb.new()
	var preset:=platform.create_preset()
	var config:=ConfigFile.new()
	var base:={"name":"Web","platform":"Web","runnable":true,"advanced_options":true,"dedicated_server":false,"custom_features":"browser_edition","export_filter":"all_resources","include_filter":"*.json,*.txt,*.ttf,*.tres","exclude_filter":"artifacts/*,tests/*","export_path":"../../web/dist/naiwa.html","script_export_mode":2}
	for key in base: config.set_value("preset.0",key,base[key])
	var names: Array[String]=[]
	for property in preset.get_property_list():
		var key: String=property.name
		if key.contains("/") and property.usage&PROPERTY_USAGE_STORAGE:
			config.set_value("preset.0.options",key,preset.get(key)); names.append(key)
	config.set_value("preset.0.options","custom_template/release",ProjectSettings.globalize_path("res://../../tools/web-templates-4.7.2/web_nothreads_release.zip"))
	config.set_value("preset.0.options","variant/thread_support",false)
	config.set_value("preset.0.options","html/canvas_resize_policy",2)
	config.set_value("preset.0.options","progressive_web_app/enabled",false)
	config.set_value("preset.0.options","vram_texture_compression/for_desktop",false)
	config.set_value("preset.0.options","vram_texture_compression/for_mobile",false)
	var result:=config.save("res://export_presets.cfg")
	print("WEB_PRESET_FACTORY options=",names.size()," status=",result)
	quit(result)
