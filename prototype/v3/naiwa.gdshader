shader_type canvas_item;
uniform vec2 rear_foot = vec2(0.0);
uniform vec2 front_foot = vec2(0.0);
uniform vec2 palm = vec2(0.0);
uniform float lean = 0.0;
uniform float flash = 0.0;
void vertex() {
    vec2 p = VERTEX;
    // The head and torso retain the supplied pixels. Only bounded limb motion is skinned.
    float legs = smoothstep(263.0, 287.0, p.y);
    float front = smoothstep(137.0, 151.0, p.x);
    vec2 foot = mix(rear_foot, front_foot, front);
    float sole = smoothstep(308.0, 329.0, p.y);
    VERTEX += foot * legs * mix(0.72, 1.0, sole);
    float upper = 1.0 - smoothstep(250.0, 275.0, p.y);
    VERTEX.x += lean * upper;
    float hand = (1.0 - smoothstep(116.0,174.0,p.x)) * smoothstep(165.0,185.0,p.y) * (1.0-smoothstep(210.0,224.0,p.y));
    VERTEX += palm * hand;
}
void fragment() {
    vec4 c = texture(TEXTURE, UV);
    COLOR = vec4(mix(c.rgb, vec3(1.0,0.95,0.80), flash*0.55), c.a);
}
