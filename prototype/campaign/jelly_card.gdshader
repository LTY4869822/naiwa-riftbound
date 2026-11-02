shader_type canvas_item;
render_mode unshaded;
uniform sampler2D preview : source_color, filter_linear;
uniform vec2 preview_size = vec2(1536.0, 1024.0);
uniform vec2 extent = vec2(558.0, 240.0);
uniform vec4 accent : source_color = vec4(0.55, 0.9, 0.75, 1.0);
uniform vec2 ink_origin = vec2(0.12, 0.7);
uniform float flood = 0.0;
uniform float focus = 0.0;
uniform float clock = 0.0;

float rounded_box(vec2 p, vec2 center, vec2 half_size, float radius) {
    vec2 q = abs(p - center) - half_size + radius;
    return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
}
void fragment() {
    vec2 p = UV * extent;
    vec2 center = extent * 0.5 - vec2(0.0, 5.0);
    vec2 half_size = extent * 0.5 - vec2(8.0, 10.0);
    float edge = rounded_box(p, center, half_size, 23.0);
    float face = 1.0 - smoothstep(-0.75, 0.75, edge);
    float shadow = 1.0 - smoothstep(-0.9, 0.9,
        rounded_box(p - vec2(0.0, 8.0), center, half_size, 23.0));
    vec3 ink = vec3(0.080, 0.061, 0.12);
    vec3 paper = vec3(0.965, 0.975, 0.935);
    vec2 flow = (p - ink_origin * extent) / vec2(1.0, 0.88);
    float angle = atan(flow.y, flow.x);
    float rim = 1.0 + sin(angle * 3.0 + 0.8) * 0.065 + sin(angle * 5.0) * 0.035;
    float spread = length(extent) * 1.18 * flood;
    float fill = (1.0 - smoothstep(spread - 3.0, spread + 2.0, length(flow) / rim)) * step(0.001, flood);
    vec3 color = mix(ink, paper, fill);
    // Subtle printed dots stay in the bottom corner, below all copy.
    vec2 dot_cell = mod(p, vec2(13.0)) - vec2(6.5);
    float dots = (1.0 - smoothstep(0.7, 1.5, length(dot_cell)))
        * smoothstep(extent.x * 0.61, extent.x * 0.95, p.x) * step(151.0, p.y);
    color = mix(color, accent.rgb, dots * mix(0.13, 0.20, fill));
    vec2 photo_size = vec2(extent.x - 30.0, 135.0);
    vec2 photo_uv = (p - vec2(15.0, 10.0)) / photo_size;
    float photo = (1.0 - smoothstep(-0.7, 0.7, rounded_box(p,
        vec2(extent.x * 0.5, 77.5), photo_size * 0.5, 16.0)));
    float image_aspect = preview_size.x / preview_size.y;
    float target_aspect = photo_size.x / photo_size.y;
    vec2 crop = vec2(min(1.0, target_aspect / image_aspect), min(1.0, image_aspect / target_aspect));
    vec2 image_uv = (photo_uv - vec2(0.5)) * crop + vec2(0.5, 0.44);
    vec3 scene = texture(preview, clamp(image_uv, vec2(0.001), vec2(0.999))).rgb;
    scene *= 1.0 - smoothstep(0.37, 1.0, photo_uv.y) * 0.68;
    color = mix(color, scene, photo);
    float border = smoothstep(-3.5, -1.5, edge);
    color = mix(color, mix(vec3(0.24, 0.21, 0.31), accent.rgb, focus * 0.8), border);
    float top_gloss = (1.0 - smoothstep(0.0, 2.2, abs(edge + 5.0)))
        * (1.0 - smoothstep(21.0, 50.0, p.y));
    color = mix(color, vec3(1.0), top_gloss * (0.14 + focus * 0.15));
    COLOR = vec4(mix(vec3(0.025, 0.015, 0.04), color, face), max(face, shadow * 0.92));
}
