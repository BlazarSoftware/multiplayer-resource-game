shader_type spatial;
render_mode diffuse_toon, specular_disabled;

// Low-poly animated water shader for Cast Iron Cove
// Kawaii style: soft blues, gentle waves, subtle foam

uniform vec4 water_color : source_color = vec4(0.4, 0.7, 0.85, 0.85);
uniform vec4 deep_color : source_color = vec4(0.2, 0.45, 0.65, 0.9);
uniform vec4 foam_color : source_color = vec4(0.9, 0.95, 1.0, 0.6);

// Wave parameters
uniform float wave_speed : hint_range(0.1, 3.0) = 0.8;
uniform float wave_height : hint_range(0.0, 1.0) = 0.15;
uniform float wave_frequency : hint_range(0.5, 5.0) = 2.0;
uniform float wave2_frequency : hint_range(0.5, 5.0) = 3.0;

// Foam
uniform float foam_threshold : hint_range(0.0, 1.0) = 0.6;
uniform float foam_width : hint_range(0.01, 0.2) = 0.08;

// Cel shading
uniform float shadow_threshold : hint_range(0.0, 1.0) = 0.35;
uniform float shadow_smoothness : hint_range(0.0, 0.3) = 0.1;

// Fresnel edge highlight
uniform float fresnel_power : hint_range(0.5, 5.0) = 2.0;
uniform float fresnel_intensity : hint_range(0.0, 0.5) = 0.2;

void vertex() {
	float time = TIME * wave_speed;
	float wave1 = sin(VERTEX.x * wave_frequency + time) * cos(VERTEX.z * wave_frequency * 0.7 + time * 0.8);
	float wave2 = sin(VERTEX.z * wave2_frequency + time * 1.2) * 0.5;
	VERTEX.y += (wave1 + wave2) * wave_height;

	// Recalculate normal for wave deformation
	float dx = cos(VERTEX.x * wave_frequency + time) * wave_frequency * wave_height;
	float dz = cos(VERTEX.z * wave2_frequency + time * 1.2) * wave2_frequency * wave_height * 0.5;
	NORMAL = normalize(vec3(-dx, 1.0, -dz));
}

void fragment() {
	float time = TIME * wave_speed;

	// Blend between shallow and deep based on wave pattern
	float wave_factor = sin(UV.x * wave_frequency * 3.0 + time) * 0.5 + 0.5;
	vec3 color = mix(deep_color.rgb, water_color.rgb, wave_factor * 0.6 + 0.4);

	// Foam lines at wave peaks
	float foam_wave = sin(UV.x * wave_frequency * 5.0 + time * 1.5) * 0.5 + 0.5;
	float foam = smoothstep(foam_threshold, foam_threshold + foam_width, foam_wave);
	color = mix(color, foam_color.rgb, foam * 0.3);

	// Fresnel edge for depth feel
	float fresnel = pow(1.0 - abs(dot(NORMAL, VIEW)), fresnel_power) * fresnel_intensity;
	color += vec3(fresnel);

	ALBEDO = color;
	ALPHA = water_color.a;
}

void light() {
	float ndotl = dot(NORMAL, LIGHT);
	float cel = smoothstep(shadow_threshold - shadow_smoothness, shadow_threshold + shadow_smoothness, ndotl);
	vec3 shaded = mix(ALBEDO * 0.7, ALBEDO, cel);

	DIFFUSE_LIGHT += shaded * ATTENUATION * LIGHT_COLOR;
}
