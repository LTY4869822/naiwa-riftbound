shader_type spatial;
render_mode unshaded;
uniform vec4 shade : source_color = vec4(0.15, 0.24, 0.31, 1.0);
uniform vec4 base : source_color = vec4(0.24, 0.47, 0.50, 1.0);
uniform vec4 light : source_color = vec4(0.57, 0.73, 0.71, 1.0);
uniform vec3 key_direction = vec3(-0.55, 0.78, 0.48);
uniform float flash : hint_range(0.0, 1.0) = 0.0;
varying vec3 authored_normal;
void vertex() {
    authored_normal = MODEL_NORMAL_MATRIX * NORMAL;
}
void fragment() {
    float n = dot(normalize(authored_normal), normalize(key_direction));
    vec3 band = n < 0.18 ? shade.rgb : (n < 0.62 ? base.rgb : light.rgb);
    ALBEDO = mix(band, vec3(1.0, 0.953, 0.827), flash);
}
