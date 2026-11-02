shader_type canvas_item;
render_mode unshaded;
uniform vec4 region=vec4(0.0,0.0,0.25,0.5);
uniform float opacity=1.0;
uniform float plasma=0.0;
uniform float recolor=0.0;
uniform vec4 light_color : source_color=vec4(1.0);
uniform vec4 body_color : source_color=vec4(0.6,1.0,0.7,1.0);
uniform vec4 edge_color : source_color=vec4(0.1,0.4,0.3,1.0);
void fragment() {
	// Inset sampling prevents the adjacent cell leaking through linear filtering.
	vec2 texel=TEXTURE_PIXEL_SIZE*0.75;
	vec2 coords=clamp(region.xy+UV*region.zw,region.xy+texel,region.xy+region.zw-texel);
	vec4 sample_color=texture(TEXTURE,coords);
	float luma=dot(sample_color.rgb,vec3(0.2126,0.7152,0.0722));
	vec3 mapped=mix(edge_color.rgb,body_color.rgb,smoothstep(0.07,0.6,luma));
	mapped=mix(mapped,light_color.rgb,smoothstep(0.62,0.95,luma));
	float a=sample_color.a*opacity*mix(1.0,smoothstep(0.12,0.35,luma),plasma);
	// Let overflowing painted strokes dissolve before the atlas boundary;
	// enlarged ultimate plumes must not expose a hard rectangular cell edge.
	float feather=smoothstep(0.0,0.085,UV.x)*smoothstep(0.0,0.085,1.0-UV.x);
	feather*=smoothstep(0.0,0.055,UV.y)*smoothstep(0.0,0.025,1.0-UV.y);
	a*=feather;
	COLOR=vec4(mix(sample_color.rgb,mapped,recolor),a);
}
