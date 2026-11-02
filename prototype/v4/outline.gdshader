shader_type spatial;
render_mode unshaded, cull_front;
uniform vec4 ink : source_color = vec4(0.067, 0.106, 0.169, 1.0);
uniform float width : hint_range(0.0, 3.0) = 1.25;
void vertex() {
    vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
    vec3 normal_view = MODELVIEW_NORMAL_MATRIX * NORMAL;
    vec2 outward = (PROJECTION_MATRIX * vec4(normal_view, 0.0)).xy;
    float depth = abs((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z);
    float distance_weight = 1.0 - smoothstep(17.0, 27.0, depth);
    clip.xy += outward / max(length(outward), 0.001) * width * distance_weight * 2.0 / VIEWPORT_SIZE * clip.w;
    POSITION = clip;
}
void fragment() { ALBEDO = ink.rgb; }
