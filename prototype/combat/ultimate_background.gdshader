// Adapted from shizu0817/godot-shockwave-shader, Copyright (c) 2023 Czu, MIT.
// See assets/notices/SHOCKWAVE-MIT.txt. Drawn BEFORE all actors and the HUD.
shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform vec2 center = vec2(0.5);
uniform vec2 canvas_size = vec2(1280.0, 800.0);
uniform float radius_px = 0.0;
uniform float strength = 0.0;
uniform float dimming = 0.0;
void fragment() {
    vec2 delta = (SCREEN_UV - center) * canvas_size;
    float distance_px = length(delta);
    float ring = smoothstep(radius_px - 20.0, radius_px, distance_px)
               * (1.0 - smoothstep(radius_px, radius_px + 28.0, distance_px));
    vec2 direction = delta / max(distance_px, 0.001);
    vec2 offset = -direction * ring * strength * 4.5 / canvas_size;
    vec2 uv = clamp(SCREEN_UV + offset, vec2(0.001), vec2(0.999));
    vec4 background = texture(screen_texture, uv);
    COLOR = vec4(background.rgb * (1.0 - dimming), background.a);
}
