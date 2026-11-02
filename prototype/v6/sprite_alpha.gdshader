shader_type canvas_item;
render_mode unshaded;
void fragment() {
	vec4 pixel = texture(TEXTURE, UV);
	// Remove low-alpha matting specks without resampling or deforming the drawing.
	pixel.a *= smoothstep(0.24, 0.60, pixel.a);
	COLOR *= pixel;
}
