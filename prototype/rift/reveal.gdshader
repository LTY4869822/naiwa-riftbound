shader_type canvas_item;
uniform float progress : hint_range(0.0,1.0)=0.0;
uniform float center_x=0.0;
uniform float half_width=200.0;
uniform float side=1.0;
varying vec2 world_point;
void vertex(){ world_point=(MODEL_MATRIX*vec4(VERTEX,0.0,1.0)).xy; }
void fragment(){
	vec4 original=COLOR;
	float n=fract(sin(dot(floor(world_point/5.0),vec2(12.9898,78.233)))*43758.5453);
	float axis=(world_point.x-center_x)*side;
	float front=(progress*2.0-1.0)*half_width;
	float mask=1.0-smoothstep(front-5.0+n*4.0,front+5.0+n*4.0,axis);
	if(progress<0.001){mask=0.0;}
	if(progress>0.999){mask=1.0;}
	float rim=(1.0-abs(mask*2.0-1.0))*0.7;
	COLOR=vec4(mix(original.rgb,vec3(.73,.46,1.0),rim),original.a*mask);
}
