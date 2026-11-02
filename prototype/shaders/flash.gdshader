shader_type canvas_item;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
varying vec4 vertex_tint;
void vertex() { vertex_tint = COLOR; }
void fragment() {
    vec4 sample_color = texture(TEXTURE, UV);
    float grain = fract(sin(dot(floor(UV * 96.0), vec2(12.9898,78.233))) * 43758.5453);
    float keep = step(dissolve, grain + 0.001);
    COLOR = vec4(mix(sample_color.rgb, vec3(1.0,0.96,0.82),flash),sample_color.a * keep) * vertex_tint;
}
