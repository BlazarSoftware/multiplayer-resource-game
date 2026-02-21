shader_type canvas_item;

// Diamond-wipe battle transition shader.
// progress=0 → fully transparent, progress=1 → fully covered.
// Uses a diamond (Manhattan distance) pattern from screen center.

uniform vec4 cover_color : source_color = vec4(0.15, 0.12, 0.1, 1.0);
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float edge_width : hint_range(0.0, 0.15) = 0.04;
uniform vec4 edge_color : source_color = vec4(0.85, 0.75, 0.55, 1.0);

void fragment() {
	// Diamond distance from center (Manhattan distance, aspect-corrected)
	vec2 centered = UV - vec2(0.5);
	float diamond = abs(centered.x) + abs(centered.y);

	// Map progress so 0 = nothing visible, 1 = fully covered
	// diamond ranges from 0 (center) to 1.0 (corners)
	float threshold = progress * 1.2; // overshoot slightly to ensure full coverage

	float alpha = smoothstep(threshold - edge_width, threshold, diamond);
	alpha = 1.0 - alpha; // invert: covered area is opaque

	// Edge highlight (golden rim at the wipe boundary)
	float edge = smoothstep(threshold - edge_width, threshold, diamond) - smoothstep(threshold, threshold + edge_width, diamond);

	vec3 final_color = mix(cover_color.rgb, edge_color.rgb, edge * 0.8);
	COLOR = vec4(final_color, alpha);
}
