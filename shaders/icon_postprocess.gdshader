shader_type canvas_item;

// Post-processing shader for icon baking
// Soft bloom on highlights, circular vignette fade, color grading

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

// Color grading
uniform float brightness : hint_range(0.8, 1.2) = 1.05;
uniform float contrast : hint_range(0.8, 1.2) = 0.95;
uniform float post_saturation : hint_range(0.5, 1.5) = 0.85;

// Circular vignette (fade to transparent at edges)
uniform bool enable_vignette = true;
uniform float vignette_radius : hint_range(0.2, 0.8) = 0.45;
uniform float vignette_softness : hint_range(0.05, 0.5) = 0.15;

// Soft bloom
uniform bool enable_bloom = true;
uniform float bloom_threshold : hint_range(0.5, 1.0) = 0.7;
uniform float bloom_intensity : hint_range(0.0, 1.0) = 0.3;

void fragment() {
	vec4 color = texture(TEXTURE, UV);

	// Color grading
	vec3 graded = color.rgb;

	// Brightness
	graded *= brightness;

	// Contrast (pivot at 0.5)
	graded = (graded - 0.5) * contrast + 0.5;

	// Saturation
	float luma = dot(graded, vec3(0.299, 0.587, 0.114));
	graded = mix(vec3(luma), graded, post_saturation);

	// Simple bloom: brighten areas above threshold
	if (enable_bloom) {
		float bloom_luma = dot(graded, vec3(0.299, 0.587, 0.114));
		float bloom_amount = max(bloom_luma - bloom_threshold, 0.0) * bloom_intensity;
		graded += bloom_amount;
	}

	graded = clamp(graded, 0.0, 1.0);

	// Circular vignette fade to transparent
	float alpha = color.a;
	if (enable_vignette) {
		vec2 center = UV - 0.5;
		float dist = length(center);
		float vignette = 1.0 - smoothstep(vignette_radius, vignette_radius + vignette_softness, dist);
		alpha *= vignette;
	}

	COLOR = vec4(graded, alpha);
}
