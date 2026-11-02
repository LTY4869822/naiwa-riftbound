shader_type canvas_item;
render_mode unshaded;
uniform sampler2D scene : source_color, filter_linear;
uniform float clock = 0.0;
uniform vec2 pointer = vec2(0.0);
void fragment() {
	vec2 uv=UV*0.955+vec2(0.018,0.02);
	uv+=vec2(sin(clock*0.09)*0.005,cos(clock*0.07)*0.003)+pointer*0.004;
	vec3 forest=texture(scene,uv).rgb;
	forest=mix(forest,forest*vec3(0.67,0.68,1.12),0.45);
	float left_scrim=1.0-smoothstep(0.0,0.67,UV.x);
	vec3 col=mix(forest,vec3(0.055,0.035,0.09),0.80*left_scrim+0.10);
	float vignette=1.0-smoothstep(0.25,0.84,length((UV-vec2(0.64,0.45))*vec2(0.8,1.0)));
	col*=0.62+0.38*vignette;
	float light=exp(-length((UV-vec2(0.72,0.50))*vec2(1.3,1.0))*5.5);
	col+=vec3(0.10,0.09,0.035)*light;
	col=mix(col,vec3(0.055,0.035,0.085),smoothstep(0.84,1.02,UV.y)*0.83);
	COLOR=vec4(col,1.0);
}
