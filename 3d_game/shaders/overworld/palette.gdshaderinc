uniform sampler2D day_pigment : source_color, filter_linear_mipmap_anisotropic, repeat_enable, hint_default_white;
uniform sampler2D sunset_pigment : source_color, filter_linear_mipmap_anisotropic, repeat_enable, hint_default_white;
uniform sampler2D night_pigment : source_color, filter_linear_mipmap_anisotropic, repeat_enable, hint_default_white;
uniform vec4 day_color = vec4(1.0);
uniform vec4 sunset_color = vec4(1.0);
uniform vec4 night_color = vec4(1.0);
uniform vec3 weights = vec3(1.0, 0.0, 0.0);
uniform float cutoff = 0.0;
uniform bool nocturnal = false;

vec4 pigment(vec2 uv, vec4 tint) {
	// Embedded GLB pigments already use the exported UV orientation.
	vec4 day = texture(day_pigment, uv);
	vec3 color = day.rgb * day_color.rgb * weights.x
		+ texture(sunset_pigment, uv).rgb * sunset_color.rgb * weights.y
		+ texture(night_pigment, uv).rgb * night_color.rgb * weights.z;
	// One fixed alpha silhouette at every time; never overlay duplicate maps.
	float alpha = day.a * day_color.a * tint.a;
	if (nocturnal) { alpha *= weights.z; }
	return vec4(color * tint.rgb, alpha);
}
