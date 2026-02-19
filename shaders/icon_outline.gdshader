shader_type spatial;
render_mode cull_front, unshaded;

// Inverted hull outline shader for kawaii cartoon border
// Applied as next_pass on the toon shader material

uniform vec4 outline_color : source_color = vec4(0.35, 0.25, 0.3, 1.0); // soft purple-brown
uniform float outline_width : hint_range(0.0, 0.1) = 0.018;

void vertex() {
	// Push vertices outward along normals
	VERTEX += NORMAL * outline_width;
}

void fragment() {
	ALBEDO = outline_color.rgb;
	ALPHA = outline_color.a;
}
