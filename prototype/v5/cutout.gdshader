shader_type canvas_item;
uniform sampler2D underpaint : source_color;
uniform bool body_patch = false;
float capsule(vec2 p, vec2 a, vec2 b) {
    vec2 d = b-a;
    return length(p-a-d*clamp(dot(p-a,d)/dot(d,d),0.0,1.0));
}
void fragment() {
    vec4 c = texture(TEXTURE,UV);
    vec2 p = UV*vec2(288.,368.);
    if (body_patch) {
        float d = min(capsule(p,vec2(174.,141.),vec2(174.,172.)),capsule(p,vec2(174.,176.),vec2(106.,195.)));
        // Cover the arm's baked cast shadow too; leaving it produces a false stripe.
        float mask = (1.-smoothstep(21.,29.,d))*smoothstep(120.,133.,p.y)*smoothstep(83.,94.,p.x);
        vec4 patch = texture(underpaint,UV);
        c = mix(c,patch,mask);
    }
    COLOR = c;
}
