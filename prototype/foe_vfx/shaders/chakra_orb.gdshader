shader_type canvas_item;
render_mode unshaded;
uniform float clock=0.0;
uniform float opacity=1.0;
uniform float seed_id=0.0;
uniform vec4 light_color : source_color=vec4(0.95,1.0,1.0,1.0);
uniform vec4 body_color : source_color=vec4(0.22,0.87,1.0,1.0);
uniform vec4 edge_color : source_color=vec4(0.13,0.34,0.9,1.0);
uniform vec4 ink_color : source_color=vec4(0.04,0.06,0.2,1.0);
void fragment() {
	vec2 p=(UV-0.5)*2.3;
	float r=length(p);
	float a=atan(p.y,p.x);
	float warp=sin(a*5.0+r*13.0-clock*9.0+seed_id)*0.025;
	float rim=r+warp;
	float aa=max(fwidth(r),0.003);
	float alpha=1.0-smoothstep(0.96,0.96+aa,rim);
	vec3 col=ink_color.rgb;
	col=mix(col,edge_color.rgb,1.0-smoothstep(0.90-aa,0.90,rim));
	col=mix(col,body_color.rgb,1.0-smoothstep(0.72-aa,0.72,rim));
	float curl=abs(sin(a*2.0+r*11.0-clock*8.0));
	float streak=(1.0-smoothstep(0.08,0.17,curl))*smoothstep(0.10,0.36,r)*(1.0-smoothstep(0.70,0.85,r));
	col=mix(col,light_color.rgb,max(streak,1.0-smoothstep(0.13,0.37,r)));
	COLOR=vec4(col,alpha*opacity);
}
