shader_type spatial;
render_mode cull_disabled, specular_disabled;

uniform sampler2D paint : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 emission_tint : source_color = vec4(0.0);
uniform float emission_strength = 0.0;
uniform vec2 paint_scale = vec2(1.0);
uniform vec2 paint_offset = vec2(0.0);
uniform float alpha_cutoff = 0.25;
uniform float wind_strength = 1.0;

void vertex() {
	// Preserve the delivery's UV-rooted deformation before applying atlas UVs.
	float phase = VERTEX.x * 0.38 + VERTEX.z * 0.27;
	float anchor = pow(clamp(UV.y, 0.0, 1.0), 1.7);
	VERTEX.x += anchor * (sin(TIME * 1.3 + phase) * 0.18
		+ sin(TIME * 2.4 + phase * 1.4) * 0.06) * wind_strength;
	VERTEX.z += anchor * sin(TIME * 0.95 + phase + 1.8) * 0.12 * wind_strength;
	UV = UV * paint_scale + paint_offset;
}

void fragment() {
	vec4 pigment = texture(paint, UV);
	ALBEDO = pigment.rgb * tint.rgb * COLOR.rgb;
	ALPHA = pigment.a * tint.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cutoff;
	EMISSION = pigment.rgb * emission_tint.rgb * emission_strength;
	ROUGHNESS = 1.0;
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}
