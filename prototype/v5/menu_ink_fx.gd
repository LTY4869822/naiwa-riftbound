extends Control
## Persistent organic ink transition. Put this above the rebuilt HUD in its own CanvasLayer.
## change(callable) starts the transition; the callable executes once under complete cover.

const COVER_TIME := 0.32
const HOLD_TIME := 0.075
const REVEAL_TIME := 0.42
const LIQUID_SHADER := """
shader_type canvas_item;
render_mode unshaded;
uniform vec2 extent = vec2(1280.0, 800.0);
uniform vec2 origin = vec2(0.26, 0.45);
uniform float radius = 0.0;
uniform float clock = 0.0;
uniform int stage = 0;
uniform vec4 ink : source_color = vec4(0.085, 0.058, 0.135, 1.0);
uniform vec4 purple : source_color = vec4(0.43, 0.22, 0.83, 1.0);
uniform vec4 acid : source_color = vec4(0.79, 0.96, 0.19, 1.0);

void fragment() {
    vec2 p = (UV - origin) * extent;
    float angle = atan(p.y, p.x);
    float wave = 0.052 * sin(angle * 7.0 + clock * 2.0)
               + 0.034 * sin(angle * 11.0 - clock * 2.9)
               + 0.019 * sin(angle * 19.0 + 1.6);
    float d = length(p) / (1.0 + wave);
    float edge = radius - d;
    float coat = 1.0 - smoothstep(-2.0, 2.0, -edge);
    float alpha = coat;
    if (stage == 1) alpha = 1.0;
    if (stage == 2) alpha = 1.0 - coat;
    // A glossy purple layer follows the acid-green leading liquid edge.
    float lip = 1.0 - smoothstep(10.0, 38.0, abs(edge));
    float shoulder = 1.0 - smoothstep(32.0, 95.0, abs(edge));
    vec3 color = mix(ink.rgb, purple.rgb, shoulder * 0.86);
    color = mix(color, acid.rgb, lip * 0.97);
    float glint = (1.0 - smoothstep(0.0, 3.2, abs(edge - 19.0))) * 0.65;
    color = mix(color, vec3(0.96, 1.0, 0.76), glint);
    // Printed halftone dots stay within the liquid and do not replace the animated mask.
    vec2 cell = mod(UV * extent, vec2(17.0)) - vec2(8.5);
    float dot = 1.0 - smoothstep(1.0, 1.9, length(cell));
    color += vec3(0.045, 0.035, 0.065) * dot;
    COLOR = vec4(color, alpha);
}
"""

var host: Node
var busy := false
var phase: String = "idle"
var clock := 0.0
var progress := 0.0
var action_called := false
var action_count := 0
var surface: ColorRect
var material_ink: ShaderMaterial
var pending_action: Callable
var origin := Vector2(0.26, 0.45)
var radius := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = LIQUID_SHADER
	material_ink = ShaderMaterial.new()
	material_ink.shader = shader
	surface = ColorRect.new()
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.material = material_ink
	add_child(surface)
	visible = false
	set_process(false)

func change(action: Callable) -> void:
	if busy or not action.is_valid(): return
	if is_instance_valid(host) and host.reduce_motion:
		action.call()
		return
	pending_action = action
	action_called = false
	busy = true
	phase = "cover"
	clock = 0.0
	progress = 0.0
	origin = Vector2(0.26,0.45)
	radius = 0.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = true
	set_process(true)
	update_material()
	queue_redraw()

func _input(event: InputEvent) -> void:
	if busy and (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton):
		get_viewport().set_input_as_handled()

func _process(dt: float) -> void:
	if not busy: return
	clock += dt
	match phase:
		"cover":
			progress = clampf(clock/COVER_TIME,0.0,1.0)
			radius = size.length()*1.16*ease(progress,-2.2)
			if clock >= COVER_TIME:
				phase = "hold"
				clock = 0.0
				progress = 1.0
				# Set the fully opaque material before invoking code that rebuilds the HUD.
				update_material()
				if not action_called:
					action_called = true
					action_count += 1
					var action := pending_action
					pending_action = Callable()
					if action.is_valid(): action.call()
		"hold":
			if clock >= HOLD_TIME:
				phase = "reveal"
				clock = 0.0
				progress = 0.0
				origin = Vector2(0.68,0.49)
				radius = 0.0
		"reveal":
			progress = clampf(clock/REVEAL_TIME,0.0,1.0)
			radius = size.length()*1.16*ease(progress,-2.0)
			if clock >= REVEAL_TIME:
				busy = false
				phase = "idle"
				visible = false
				mouse_filter = Control.MOUSE_FILTER_IGNORE
				set_process(false)
	update_material()
	queue_redraw()

func update_material() -> void:
	if material_ink == null: return
	material_ink.set_shader_parameter("extent",size.max(Vector2.ONE))
	material_ink.set_shader_parameter("origin",origin)
	material_ink.set_shader_parameter("radius",radius)
	material_ink.set_shader_parameter("clock",clock)
	material_ink.set_shader_parameter("stage",1 if phase=="hold" else 2 if phase=="reveal" else 0)

func _draw() -> void:
	if not busy or phase=="hold": return
	var center := origin*size
	var fade := 1.0-progress if phase=="reveal" else 1.0
	for i in range(18):
		var angle := float(i)*TAU/18.0 + sin(float(i)*2.18)*0.13
		var direction := Vector2(cos(angle),sin(angle))
		var distance := radius*(1.02+0.065*sin(float(i)*4.7)) + 20.0+float(i%4)*12.0
		var at := center+direction*distance+Vector2(0,progress*progress*25)
		var droplet_radius := (4.0+float(i%5)*2.1)*fade
		draw_set_transform(at,angle,Vector2(1.55,1.0))
		draw_circle(Vector2.ZERO,droplet_radius+1.5,Color("241336"))
		draw_circle(Vector2.ZERO,droplet_radius,Color("c9f331") if i%3!=0 else Color("7944d6"))
		draw_set_transform(Vector2.ZERO)
