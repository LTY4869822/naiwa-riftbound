shader_type canvas_item;
render_mode unshaded;
uniform float progress : hint_range(0.0,1.0)=1.0;
uniform bool outgoing=false;
varying vec2 world_position;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,0.0,1.0)).xy;}
void fragment(){
    vec2 block=floor(world_position/5.0);
    float noise=fract(sin(dot(block,vec2(127.1,311.7)))*43758.5453);
    float mask=step(noise,progress);
    if(outgoing){mask=1.0-mask;}
    vec4 tex=texture(TEXTURE,UV);
    COLOR=vec4(tex.rgb,tex.a*mask);
}
