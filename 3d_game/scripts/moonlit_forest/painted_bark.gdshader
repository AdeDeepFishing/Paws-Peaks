shader_type spatial;
render_mode specular_disabled;

uniform sampler2D paint : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 emission_tint : source_color = vec4(0.0);
uniform float emission_strength = 0.0;
uniform vec2 paint_scale = vec2(1.0);
uniform vec2 paint_offset = vec2(0.0);

void fragment() {
	vec2 uv = UV * paint_scale + paint_offset;
	uv = 1.0 - abs(mod(uv, 2.0) - 1.0);
	vec3 pigment = texture(paint, uv).rgb;
	ALBEDO = pigment * tint.rgb * COLOR.rgb;
	EMISSION = pigment * emission_tint.rgb * emission_strength;
	ROUGHNESS = 1.0;
}
