shader_type spatial;
render_mode diffuse_toon, specular_disabled;

// Kawaii toon cel shader for icon baking
// Applies pastel color remap, two-tone cel shading, and rim light

uniform vec4 albedo_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform bool use_texture = true;

// Pastel blend: how much white to mix in (0.0 = original, 1.0 = full white)
uniform float pastel_blend : hint_range(0.0, 1.0) = 0.12;

// Cel shading
uniform vec4 shadow_color : source_color = vec4(0.65, 0.55, 0.7, 1.0); // deeper lavender shadow
uniform float shadow_threshold : hint_range(0.0, 1.0) = 0.35;
uniform float shadow_smoothness : hint_range(0.0, 0.2) = 0.06;

// Rim light
uniform vec4 rim_color : source_color = vec4(1.0, 0.92, 0.95, 1.0); // soft pink-white
uniform float rim_power : hint_range(0.5, 8.0) = 3.0;
uniform float rim_intensity : hint_range(0.0, 1.0) = 0.35;

// Saturation adjustment
uniform float saturation : hint_range(0.0, 2.0) = 1.0;

void fragment() {
	vec4 base_color = albedo_color;
	if (use_texture) {
		base_color *= texture(albedo_texture, UV);
	}

	// Pastel remap: blend toward white
	vec3 pastel = mix(base_color.rgb, vec3(1.0), pastel_blend);

	// Saturation reduction for cozy feel
	float luma = dot(pastel, vec3(0.299, 0.587, 0.114));
	pastel = mix(vec3(luma), pastel, saturation);

	ALBEDO = pastel;
	ALPHA = base_color.a;
}

void light() {
	// Two-tone cel shading
	float ndotl = dot(NORMAL, LIGHT);
	float cel = smoothstep(shadow_threshold - shadow_smoothness, shadow_threshold + shadow_smoothness, ndotl);
	vec3 shaded = mix(shadow_color.rgb * ALBEDO, ALBEDO, cel);

	// Rim light
	float rim = 1.0 - dot(NORMAL, VIEW);
	rim = pow(rim, rim_power) * rim_intensity;
	vec3 rim_contribution = rim_color.rgb * rim;

	DIFFUSE_LIGHT += (shaded + rim_contribution) * ATTENUATION * LIGHT_COLOR;
}
