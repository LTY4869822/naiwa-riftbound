shader_type canvas_item;
render_mode blend_add, unshaded;
varying vec4 particle_color;
void vertex() {
    particle_color = COLOR;
}
void fragment() {
    vec4 source = texture(TEXTURE, UV);
    float intensity = max(source.r, max(source.g, source.b)) * source.a;
    // Source parts include tiling strips: soften ALL borders when used as sprites.
    vec2 edge = smoothstep(vec2(0.0), vec2(0.16), UV)
              * (1.0 - smoothstep(vec2(0.84), vec2(1.0), UV));
    COLOR = vec4(particle_color.rgb, particle_color.a * intensity * edge.x * edge.y);
}
