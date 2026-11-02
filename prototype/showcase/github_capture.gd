extends Node
## Reproducible publication showcase. The normal game entry never loads this scene.
const QUIET=preload("res://echo/demo.gd")
const C=preload("res://biomes/content.gd")
var h: Node
var output: String
var shots: Array=[]
func _ready() -> void:
    output=ProjectSettings.globalize_path("res://../docs/media")
    call_deferred("run")
func frames(n: int) -> void:
    for i in n: await get_tree().process_frame
func action(name: String,down: bool=true) -> void:
    var e:=InputEventAction.new(); e.action=name; e.pressed=down
    Input.parse_input_event(e)
func shot(name: String) -> void:
    await RenderingServer.frame_post_draw
    var image:=get_viewport().get_texture().get_image()
    image.save_png(output.path_join(name+".png"))
    shots.append(name)
func setup(map: int,chapter: int=0) -> void:
    h.choose_level(map,chapter); QUIET.quiet(h)
    h.wait_wave=99999; h.player.invuln=10000; h.arena.enabled=false
    h.player.position=Vector2(220,640); h.toast_time=0; h.toast_text=""
    h.rift.presentations_enabled=false
func run() -> void:
    h=load("res://v6/slice.tscn").instantiate()
    add_child(h); await frames(12)
    h.get_window().size=Vector2i(1280,800)
    h.audio_enabled=false
    await frames(16); await shot("home-current")
    Profile.level=7; Ascension.energy=0
    for map in 4:
        setup(map,2)
        var boss: Node=h.spawn(C.BOSSES[map][2],1000)
        h.rift.finish_arrival(); boss.cooldown=999; boss.ult_cooldown=999
        boss.set_physics_process(false); boss.state="approach"
        for i in 3:
            var e: Node=h.spawn(C.ROSTERS[map][i],[540.0,720.0,850.0][i])
            e.cooldown=999; e.set_physics_process(false)
        h.refresh_hud(); await frames(24)
        await shot("realm-"+C.IDS[map])
    setup(0)
    var maker=load("res://punch/film.gd").new()
    maker.h=h
    var target: Node=maker.stage("melee")
    h.player.focus=100; await frames(12)
    DirAccess.make_dir_recursive_absolute(output.path_join("combat-frames"))
    for i in 150:
        if i in [2,18,42]: action("attack")
        if i in [3,19,43]: action("attack",false)
        if i==72: action("heavy")
        if i==73: action("heavy",false)
        if i==112: action("skill")
        if i==113: action("skill",false)
        await frames(1)
        if i%3==0: await shot("combat-frames/frame-%03d" % i)
        if i==85: await shot("impact-current")
        if i==143: await shot("ultimate-current")
    setup(0)
    h.player.position=Vector2(240,640); await frames(10)
    action("jump"); await frames(2); action("jump",false); await frames(10)
    action("jump"); await frames(2); action("jump",false); await frames(3)
    await shot("double-jump-current")
    await frames(60)
    setup(0)
    h.player.position=Vector2(410,640); Ascension.energy=100
    await frames(10); h.ascension.awaken()
    await frames(21); await shot("transformation-current")
    await frames(24); await shot("awakened-current")
    h.ascension.clear()
    QUIET.relics(h); await frames(40); await shot("relics-current")
    h.camp(); h.menu_section="shop"; h.build_ui()
    await frames(25); await shot("shop-current")
    FileAccess.open(output.path_join("capture-manifest.json"),FileAccess.WRITE).store_string(JSON.stringify({
        "date":"2026-11-02","source":"Current publication snapshot, same main script SHA as workspace",
        "mode":"--bridge-check; saves disabled; staged encounters, Level 7, invulnerable player",
        "shots":shots,"not_a_normal_playthrough":true,
        "normal_entry":"res://v6/slice.tscn"
    },"  "))
    get_tree().quit()
