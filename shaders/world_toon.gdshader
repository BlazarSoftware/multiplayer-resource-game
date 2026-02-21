shader_type spatial;
render_mode diffuse_toon, specular_disabled;

// Kawaii world toon shader for Synty/low-poly assets
// Accepts albedo texture (Synty palette atlas) OR flat color
// Matches the aesthetic of toon_icon.gdshader but tuned for 3D world rendering

uniform vec4 albedo_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform bool use_texture = true;

// Pastel blend: soften colors toward white for kawaii feel
uniform float pastel_blend : hint_range(0.0, 1.0) = 0.08;

// Cel shading
uniform vec4 shadow_color : source_color = vec4(0.6, 0.5, 0.65, 1.0);
uniform float shadow_threshold : hint_range(0.0, 1.0) = 0.3;
uniform float shadow_smoothness : hint_range(0.0, 0.3) = 0.08;

// Rim light (subtler for world objects than icons)
uniform vec4 rim_color : source_color = vec4(1.0, 0.95, 0.97, 1.0);
uniform float rim_power : hint_range(0.5, 8.0) = 3.5;
uniform float rim_intensity : hint_range(0.0, 1.0) = 0.2;

// Saturation
uniform float saturation : hint_range(0.0, 2.0) = 0.95;

// Ambient boost for outdoor scenes
uniform float ambient_boost : hint_range(0.0, 0.5) = 0.15;

// Alpha cutoff for foliage/fences with alpha textures
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 base_color = albedo_color;
	if (use_texture) {
		base_color *= texture(albedo_texture, UV);
	}

	// Alpha scissor for cutout transparency (leaves, fences, etc.)
	if (alpha_scissor_threshold > 0.0 && base_color.a < alpha_scissor_threshold) {
		discard;
	}

	// Pastel remap
	vec3 pastel = mix(base_color.rgb, vec3(1.0), pastel_blend);

	// Saturation adjustment
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

	// Ambient fill so shadows aren't too dark outdoors
	shaded += ALBEDO * ambient_boost;

	// Rim light
	float rim = 1.0 - dot(NORMAL, VIEW);
	rim = pow(rim, rim_power) * rim_intensity;
	vec3 rim_contribution = rim_color.rgb * rim;

	DIFFUSE_LIGHT += (shaded + rim_contribution) * ATTENUATION * LIGHT_COLOR;
}
