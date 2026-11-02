shader_type canvas_item;
uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 hit_color : source_color = vec4(1.0, 0.97, 0.82, 1.0);
void fragment() {
	vec4 tex = COLOR;
	COLOR = vec4(mix(tex.rgb, hit_color.rgb, amount), tex.a);
}
