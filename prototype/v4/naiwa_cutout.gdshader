shader_type canvas_item;
uniform sampler2D underpaint : source_color;
uniform bool body_patch = false;
uniform float flash = 0.0;
float capsule(vec2 p, vec2 a, vec2 b) {
    vec2 d = b-a;
    return length(p-a-d*clamp(dot(p-a,d)/dot(d,d),0.0,1.0));
}
void fragment() {
    vec4 c = texture(TEXTURE,UV);
    vec2 pixel = UV * vec2(288.0,368.0);
    if (body_patch) {
        float arm = min(capsule(pixel,vec2(174.,144.),vec2(172.,174.)),capsule(pixel,vec2(172.,174.),vec2(111.,195.)));
        float mask = (1.0-smoothstep(16.,21.,arm)) * step(126.,pixel.y);
        vec4 patch = texture(underpaint,UV);
        c.rgb = mix(c.rgb,patch.rgb,mask*patch.a);
    }
    // Transitional cutout only. Exact face pixels remain untouched; no vertex warping.
    if (pixel.y>94.) {
        float brightness = dot(c.rgb,vec3(0.299,0.587,0.114));
        vec3 yellow = brightness>0.72 ? vec3(0.953,0.808,0.310) : (brightness>0.43 ? vec3(0.83,0.62,0.20) : vec3(0.43,0.36,0.16));
        bool belly = c.b>0.31 && c.r-c.g<0.18 && brightness>0.48;
        if (belly) yellow = brightness>0.7 ? vec3(0.984,0.906,0.667) : vec3(0.80,0.71,0.44);
        c.rgb = yellow;
    }
    COLOR = vec4(mix(c.rgb,vec3(1.,0.953,0.827),flash*0.8),c.a);
}
